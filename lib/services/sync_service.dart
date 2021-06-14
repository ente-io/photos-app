import 'dart:async';
import 'dart:io';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/core/errors.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/core/network.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/events/collection_updated_event.dart';
import 'package:photos/events/local_photos_updated_event.dart';
import 'package:photos/events/permission_granted_event.dart';
import 'package:photos/events/sync_status_update_event.dart';
import 'package:photos/events/subscription_purchased_event.dart';
import 'package:photos/events/trigger_logout_event.dart';
import 'package:photos/models/file_type.dart';
import 'package:photos/services/collections_service.dart';
import 'package:photos/services/local_sync_service.dart';
import 'package:photos/services/notification_service.dart';
import 'package:photos/utils/diff_fetcher.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/utils/file_uploader.dart';
import 'package:photos/utils/file_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:photos/models/file.dart';

import 'package:photos/core/configuration.dart';

class SyncService {
  final _logger = Logger("SyncService");
  final _localSyncService = LocalSyncService.instance;
  final _dio = Network.instance.getDio();
  final _db = FilesDB.instance;
  final _uploader = FileUploader.instance;
  final _collectionsService = CollectionsService.instance;
  final _diffFetcher = DiffFetcher();
  bool _syncStopRequested = false;
  Completer<bool> _existingSync;
  SharedPreferences _prefs;
  SyncStatusUpdate _lastSyncStatusEvent;
  int _completedUploads = 0;

  static const kLastStorageLimitExceededNotificationPushTime =
      "last_storage_limit_exceeded_notification_push_time";
  static const kLastBackgroundUploadDetectedTime =
      "last_background_upload_detected_time";
  static const kDiffLimit = 2500;
  static const kBackgroundUploadPollFrequency = Duration(seconds: 1);

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

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (Platform.isIOS) {
      _logger.info("Clearing file cache");
      await PhotoManager.clearFileCache();
      _logger.info("Cleared file cache");
    }
  }

  Future<bool> existingSync() async {
    return _existingSync.future;
  }

  Future<bool> sync() async {
    _syncStopRequested = false;
    if (_existingSync != null) {
      _logger.warning("Sync already in progress, skipping.");
      return _existingSync.future;
    }
    _existingSync = Completer<bool>();
    bool successful = false;
    try {
      await _doSync();
      if (_lastSyncStatusEvent != null &&
          _lastSyncStatusEvent.status !=
              SyncStatus.completed_first_gallery_import &&
          _lastSyncStatusEvent.status != SyncStatus.completed_backup) {
        Bus.instance.fire(SyncStatusUpdate(SyncStatus.completed_backup));
      }
      successful = true;
    } on WiFiUnavailableError {
      _logger.warning("Not uploading over mobile data");
      Bus.instance.fire(
          SyncStatusUpdate(SyncStatus.paused, reason: "waiting for WiFi..."));
    } on SyncStopRequestedError {
      _syncStopRequested = false;
      Bus.instance.fire(
          SyncStatusUpdate(SyncStatus.completed_backup, wasStopped: true));
    } on NoActiveSubscriptionError {
      Bus.instance.fire(SyncStatusUpdate(SyncStatus.error,
          error: NoActiveSubscriptionError()));
    } on StorageLimitExceededError {
      _showStorageLimitExceededNotification();
      Bus.instance.fire(SyncStatusUpdate(SyncStatus.error,
          error: StorageLimitExceededError()));
    } on UnauthorizedError {
      _logger.info("Logging user out");
      Bus.instance.fire(TriggerLogoutEvent());
    } catch (e, s) {
      if (e is DioError) {
        if (e.type == DioErrorType.connectTimeout ||
            e.type == DioErrorType.sendTimeout ||
            e.type == DioErrorType.receiveTimeout ||
            e.type == DioErrorType.other) {
          Bus.instance.fire(SyncStatusUpdate(SyncStatus.paused,
              reason: "waiting for network..."));
          return false;
        }
      }
      _logger.severe("backup failed", e, s);
      Bus.instance.fire(SyncStatusUpdate(SyncStatus.error));
      throw e;
    } finally {
      _existingSync.complete(successful);
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

  bool hasCompletedFirstImport() {
    return _prefs.getBool(LocalSyncService.kHasCompletedFirstImportKey) ??
        false;
  }

  bool isSyncInProgress() {
    return _existingSync != null;
  }

  SyncStatusUpdate getLastSyncStatusEvent() {
    return _lastSyncStatusEvent;
  }

  bool hasGrantedPermissions() {
    return _prefs.getBool(LocalSyncService.kHasGrantedPermissionsKey) ?? false;
  }

  Future<void> onPermissionGranted() async {
    await _prefs.setBool(LocalSyncService.kHasGrantedPermissionsKey, true);
    Bus.instance.fire(PermissionGrantedEvent());
    _doSync();
  }

  Future<void> onFoldersAdded(List<String> paths) async {
    if (_existingSync != null) {
      await _existingSync.future;
    }
    return sync();
  }

  void onFoldersRemoved(List<String> paths) {
    _uploader.removeFromQueueWhere((file) {
      return paths.contains(file.deviceFolder);
    }, UserCancelledUploadError());
  }

  Future<void> _doSync() async {
    await _localSyncService.sync();
    if (hasCompletedFirstImport()) {
      await syncWithRemote();
    }
  }

  Future<void> syncWithRemote({bool silently = false}) async {
    if (!Configuration.instance.hasConfiguredAccount()) {
      _logger.info("Skipping remote sync since account is not configured");
      return;
    }
    await _collectionsService.sync();
    final updatedCollections =
        await _collectionsService.getCollectionsToBeSynced();

    if (updatedCollections.isNotEmpty && !silently) {
      Bus.instance.fire(SyncStatusUpdate(SyncStatus.applying_remote_diff));
    }
    for (final c in updatedCollections) {
      await _syncCollectionDiff(c.id);
      _collectionsService.setCollectionSyncTime(c.id, c.updationTime);
    }
    bool hasUploadedFiles = await _uploadDiff();
    if (hasUploadedFiles) {
      syncWithRemote(silently: true);
    }
  }

  Future<void> _syncCollectionDiff(int collectionID) async {
    final diff = await _diffFetcher.getEncryptedFilesDiff(
      collectionID,
      _collectionsService.getCollectionSyncTime(collectionID),
      kDiffLimit,
    );
    if (diff.updatedFiles.isNotEmpty) {
      await _storeDiff(diff.updatedFiles, collectionID);
      _logger.info("Updated " +
          diff.updatedFiles.length.toString() +
          " files in collection " +
          collectionID.toString());
      Bus.instance.fire(LocalPhotosUpdatedEvent(diff.updatedFiles));
      Bus.instance
          .fire(CollectionUpdatedEvent(collectionID, diff.updatedFiles));
      if (diff.fetchCount == kDiffLimit) {
        return await _syncCollectionDiff(collectionID);
      }
    }
  }

  Future<bool> _uploadDiff() async {
    final foldersToBackUp = Configuration.instance.getPathsToBackUp();
    var filesToBeUploaded =
        await _db.getFilesToBeUploadedWithinFolders(foldersToBackUp);
    if (kDebugMode) {
      filesToBeUploaded
          .removeWhere((element) => element.fileType == FileType.video);
    }
    _logger.info(
        filesToBeUploaded.length.toString() + " new files to be uploaded.");

    final updatedFileIDs = await _db.getUploadedFileIDsToBeUpdated();
    _logger.info(updatedFileIDs.length.toString() + " files updated.");

    final editedFiles = await _db.getEditedRemoteFiles();
    _logger.info(editedFiles.length.toString() + " files edited.");

    _completedUploads = 0;
    int toBeUploaded =
        filesToBeUploaded.length + updatedFileIDs.length + editedFiles.length;

    if (toBeUploaded > 0) {
      Bus.instance.fire(SyncStatusUpdate(SyncStatus.preparing_for_upload));
    }
    final alreadyUploaded = await FilesDB.instance.getNumberOfUploadedFiles();
    final futures = List<Future>();
    for (final uploadedFileID in updatedFileIDs) {
      final file = await _db.getUploadedFileInAnyCollection(uploadedFileID);
      final future = _uploader.upload(file, file.collectionID).then(
          (uploadedFile) async => await _onFileUploaded(
              uploadedFile, alreadyUploaded, toBeUploaded));
      futures.add(future);
    }

    for (final file in filesToBeUploaded) {
      final collectionID = (await CollectionsService.instance
              .getOrCreateForPath(file.deviceFolder))
          .id;
      final future = _uploader.upload(file, collectionID).then(
          (uploadedFile) async => await _onFileUploaded(
              uploadedFile, alreadyUploaded, toBeUploaded));
      futures.add(future);
    }

    for (final file in editedFiles) {
      final future = _uploader.upload(file, file.collectionID).then(
          (uploadedFile) async => await _onFileUploaded(
              uploadedFile, alreadyUploaded, toBeUploaded));
      futures.add(future);
    }

    try {
      await Future.wait(futures);
    } on InvalidFileError {
      // Do nothing
    } on FileSystemException {
      // Do nothing since it's caused mostly due to concurrency issues
      // when the foreground app deletes temporary files, interrupting a background
      // upload
    } on LockAlreadyAcquiredError {
      // Do nothing
    } on SilentlyCancelUploadsError {
      // Do nothing
    } on UserCancelledUploadError {
      // Do nothing
    } catch (e) {
      throw e;
    }
    return _completedUploads > 0;
  }

  Future<void> _onFileUploaded(
      File file, int alreadyUploaded, int toBeUploadedInThisSession) async {
    Bus.instance.fire(CollectionUpdatedEvent(file.collectionID, [file]));
    _completedUploads++;
    final completed =
        await FilesDB.instance.getNumberOfUploadedFiles() - alreadyUploaded;
    if (completed == toBeUploadedInThisSession) {
      return;
    }
    Bus.instance.fire(SyncStatusUpdate(SyncStatus.in_progress,
        completed: completed, total: toBeUploadedInThisSession));
  }

  Future _storeDiff(List<File> diff, int collectionID) async {
    int existing = 0,
        updated = 0,
        remote = 0,
        localButUpdatedOnRemote = 0,
        localButAddedToNewCollectionOnRemote = 0;
    List<File> toBeInserted = [];
    for (File file in diff) {
      final existingFiles = file.deviceFolder == null
          ? null
          : await _db.getMatchingFiles(file.title, file.deviceFolder);
      if (existingFiles == null) {
        // File uploaded from a different device
        file.localID = null;
        toBeInserted.add(file);
        remote++;
      } else {
        // File exists on device
        file.localID = existingFiles[0]
            .localID; // File should ideally have the same localID
        bool wasUploadedOnAPreviousInstallation =
            existingFiles.length == 1 && existingFiles[0].collectionID == null;
        if (wasUploadedOnAPreviousInstallation) {
          file.generatedID = existingFiles[0].generatedID;
          if (file.modificationTime != existingFiles[0].modificationTime) {
            // File was updated since the app was uninstalled
            _logger.info("Updated since last installation: " +
                file.uploadedFileID.toString());
            file.updationTime = null;
            updated++;
          } else {
            existing++;
          }
          toBeInserted.add(file);
        } else {
          bool foundMatchingCollection = false;
          for (final existingFile in existingFiles) {
            if (file.collectionID == existingFile.collectionID &&
                file.uploadedFileID == existingFile.uploadedFileID) {
              // File was updated on remote
              foundMatchingCollection = true;
              file.generatedID = existingFile.generatedID;
              toBeInserted.add(file);
              clearCache(file);
              localButUpdatedOnRemote++;
              break;
            }
          }
          if (!foundMatchingCollection) {
            // Added to a new collection
            toBeInserted.add(file);
            localButAddedToNewCollectionOnRemote++;
          }
        }
      }
    }
    await _db.insertMultiple(toBeInserted);
    if (toBeInserted.length > 0) {
      await _collectionsService.setCollectionSyncTime(
          collectionID, toBeInserted[toBeInserted.length - 1].updationTime);
    }
    _logger.info(
      "Diff to be deduplicated was: " +
          diff.length.toString() +
          " out of which \n" +
          existing.toString() +
          " was uploaded from device, \n" +
          updated.toString() +
          " was uploaded from device, but has been updated since and should be reuploaded, \n" +
          remote.toString() +
          " was uploaded from remote, \n" +
          localButUpdatedOnRemote.toString() +
          " was uploaded from device but updated on remote, and \n" +
          localButAddedToNewCollectionOnRemote.toString() +
          " was uploaded from device but added to a new collection on remote.",
    );
  }

  Future<void> deleteFilesOnServer(List<int> fileIDs) async {
    return await _dio
        .post(Configuration.instance.getHttpEndpoint() + "/files/delete",
            options: Options(
              headers: {
                "X-Auth-Token": Configuration.instance.getToken(),
              },
            ),
            data: {
          "fileIDs": fileIDs,
        });
  }

  void _showStorageLimitExceededNotification() async {
    final lastNotificationShownTime =
        _prefs.getInt(kLastStorageLimitExceededNotificationPushTime) ?? 0;
    final now = DateTime.now().microsecondsSinceEpoch;
    if ((now - lastNotificationShownTime) > MICRO_SECONDS_IN_DAY) {
      await _prefs.setInt(kLastStorageLimitExceededNotificationPushTime, now);
      NotificationService.instance.showNotification(
          "storage limit exceeded", "sorry, we had to pause your backups");
    }
  }
}
