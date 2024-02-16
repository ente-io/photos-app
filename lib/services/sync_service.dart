import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/core/errors.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/core/network/network.dart';
import 'package:photos/db/device_files_db.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/events/permission_granted_event.dart';
import 'package:photos/events/subscription_purchased_event.dart';
import 'package:photos/events/sync_status_update_event.dart';
import 'package:photos/events/trigger_logout_event.dart';
import 'package:photos/models/backup_status.dart';
import 'package:photos/models/file/file_type.dart';
import "package:photos/services/files_service.dart";
import 'package:photos/services/local_sync_service.dart';
import 'package:photos/services/notification_service.dart';
import 'package:photos/services/remote_sync_service.dart';
import 'package:photos/utils/file_uploader.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  final _logger = Logger("SyncService");
  final _localSyncService = LocalSyncService.instance;
  final _remoteSyncService = RemoteSyncService.instance;
  final _enteDio = NetworkClient.instance.enteDio;
  final _uploader = FileUploader.instance;
  bool _syncStopRequested = false;
  Completer<bool>? _existingSync;
  late SharedPreferences _prefs;
  SyncStatusUpdate? _lastSyncStatusEvent;

  static const kLastStorageLimitExceededNotificationPushTime =
      "last_storage_limit_exceeded_notification_push_time";

  SyncService._privateConstructor() {
    Bus.instance.on<SubscriptionPurchasedEvent>().listen((event) {
      _uploader.clearQueue(SilentlyCancelUploadsError());
      sync();
    });

    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _logger.info("Connectivity change detected " + result.toString());
      if (Configuration.instance.hasConfiguredAccount()) {
        sync();
      }
    });

    Bus.instance.on<SyncStatusUpdate>().listen((event) {
      _logger.info("Sync status received " + event.toString());
      _lastSyncStatusEvent = event;
    });
  }

  static final SyncService instance = SyncService._privateConstructor();

  Future<void> init(SharedPreferences preferences) async {
    _prefs = preferences;
    if (Platform.isIOS) {
      _logger.info("Clearing file cache");
      await PhotoManager.clearFileCache();
      _logger.info("Cleared file cache");
    }
  }

  // Note: Do not use this future for anything except log out.
  // This is prone to bugs due to any potential race conditions
  Future<bool> existingSync() async {
    return _existingSync?.future ?? Future.value(true);
  }

  Future<bool> sync() async {
    _syncStopRequested = false;
    if (_existingSync != null) {
      _logger.warning("Sync already in progress, skipping.");
      return _existingSync!.future;
    }
    _existingSync = Completer<bool>();
    bool successful = false;
    try {
      await _doSync();
      if (_lastSyncStatusEvent != null &&
          _lastSyncStatusEvent!.status !=
              SyncStatus.completedFirstGalleryImport &&
          _lastSyncStatusEvent!.status != SyncStatus.completedBackup) {
        Bus.instance.fire(SyncStatusUpdate(SyncStatus.completedBackup));
      }
      successful = true;
    } on WiFiUnavailableError {
      _logger.warning("Not uploading over mobile data");
      Bus.instance.fire(
        SyncStatusUpdate(SyncStatus.paused, reason: "Waiting for WiFi..."),
      );
    } on SyncStopRequestedError {
      _syncStopRequested = false;
      Bus.instance.fire(
        SyncStatusUpdate(SyncStatus.completedBackup, wasStopped: true),
      );
    } on NoActiveSubscriptionError {
      Bus.instance.fire(
        SyncStatusUpdate(
          SyncStatus.error,
          error: NoActiveSubscriptionError(),
        ),
      );
    } on StorageLimitExceededError {
      _showStorageLimitExceededNotification();
      Bus.instance.fire(
        SyncStatusUpdate(
          SyncStatus.error,
          error: StorageLimitExceededError(),
        ),
      );
    } on UnauthorizedError {
      _logger.info("Logging user out");
      Bus.instance.fire(TriggerLogoutEvent());
    } catch (e) {
      if (e is DioError) {
        if (e.type == DioErrorType.connectTimeout ||
            e.type == DioErrorType.sendTimeout ||
            e.type == DioErrorType.receiveTimeout ||
            e.type == DioErrorType.other) {
          Bus.instance.fire(
            SyncStatusUpdate(
              SyncStatus.paused,
              reason: "Waiting for network...",
            ),
          );
          _logger.severe("unable to connect", e, StackTrace.current);
          return false;
        }
      }
      _logger.severe("backup failed", e, StackTrace.current);
      Bus.instance.fire(SyncStatusUpdate(SyncStatus.error));
      rethrow;
    } finally {
      _existingSync?.complete(successful);
      _existingSync = null;
      _lastSyncStatusEvent = null;
      _logger.info("Syncing completed");
    }
    return successful;
  }

  void stopSync() {
    _logger.info("Sync stop requested");
    _syncStopRequested = true;
  }

  bool shouldStopSync() {
    return _syncStopRequested;
  }

  bool isSyncInProgress() {
    return _existingSync != null;
  }

  SyncStatusUpdate? getLastSyncStatusEvent() {
    return _lastSyncStatusEvent;
  }

  Future<void> onPermissionGranted(PermissionState state) async {
    _logger.info("Permission granted " + state.toString());
    await _localSyncService.onPermissionGranted(state);
    Bus.instance.fire(PermissionGrantedEvent());
    _doSync().ignore();
  }

  void onDeviceCollectionSet(Set<int> collectionIDs) {
    _uploader.removeFromQueueWhere(
      (file) {
        return !collectionIDs.contains(file.collectionID);
      },
      UserCancelledUploadError(),
    );
  }

  void onVideoBackupPaused() {
    _uploader.removeFromQueueWhere(
      (file) {
        return file.fileType == FileType.video;
      },
      UserCancelledUploadError(),
    );
  }

  Future<BackupStatus> getBackupStatus({String? pathID}) async {
    BackedUpFileIDs ids;
    final bool hasMigratedSize = await FilesService.instance.hasMigratedSizes();
    if (pathID == null) {
      ids = await FilesDB.instance.getBackedUpIDs();
    } else {
      ids = await FilesDB.instance.getBackedUpForDeviceCollection(
        pathID,
        Configuration.instance.getUserID()!,
      );
    }
    late int size;
    if (hasMigratedSize) {
      size = ids.localSize;
    } else {
      size = await _getFileSize(ids.uploadedIDs);
    }
    return BackupStatus(ids.localIDs, size);
  }

  Future<int> _getFileSize(List<int> fileIDs) async {
    try {
      final response = await _enteDio.post(
        "/files/size",
        data: {"fileIDs": fileIDs},
      );
      return response.data["size"];
    } catch (e) {
      _logger.severe(e);
      rethrow;
    }
  }

  Future<void> _doSync() async {
    await _localSyncService.sync();
    if (_localSyncService.hasCompletedFirstImport()) {
      await _remoteSyncService.sync();
      final shouldSync = await _localSyncService.syncAll();
      if (shouldSync) {
        await _remoteSyncService.sync();
      }
    }
  }

  void _showStorageLimitExceededNotification() async {
    final lastNotificationShownTime =
        _prefs.getInt(kLastStorageLimitExceededNotificationPushTime) ?? 0;
    final now = DateTime.now().microsecondsSinceEpoch;
    if ((now - lastNotificationShownTime) > microSecondsInDay) {
      await _prefs.setInt(kLastStorageLimitExceededNotificationPushTime, now);
      // ignore: unawaited_futures
      NotificationService.instance.showNotification(
        "Storage limit exceeded",
        "Sorry, we had to pause your backups",
      );
    }
  }
}
