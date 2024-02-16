import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/core/configuration.dart';
import "package:photos/core/errors.dart";
import 'package:photos/core/event_bus.dart';
import 'package:photos/db/device_files_db.dart';
import 'package:photos/db/file_updation_db.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/events/backup_folders_updated_event.dart';
import 'package:photos/events/local_photos_updated_event.dart';
import 'package:photos/events/sync_status_update_event.dart';
import 'package:photos/extensions/stop_watch.dart';
import 'package:photos/models/file/file.dart';
import "package:photos/models/ignored_file.dart";
import 'package:photos/services/app_lifecycle_service.dart';
import "package:photos/services/ignored_files_service.dart";
import 'package:photos/services/local/local_sync_util.dart';
import "package:photos/utils/debouncer.dart";
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tuple/tuple.dart';

class LocalSyncService {
  final _logger = Logger("LocalSyncService");
  final _db = FilesDB.instance;
  late SharedPreferences _prefs;
  Completer<void>? _existingSync;
  late Debouncer _changeCallbackDebouncer;

  static const kDbUpdationTimeKey = "db_updation_time";
  static const kHasCompletedFirstImportKey = "has_completed_firstImport";
  static const kHasGrantedPermissionsKey = "has_granted_permissions";
  static const kPermissionStateKey = "permission_state";

  // Adding `_2` as a suffic to pull files that were earlier ignored due to permission errors
  // See https://github.com/CaiJingLong/flutter_photo_manager/issues/589
  static const kInvalidFileIDsKey = "invalid_file_ids_2";

  LocalSyncService._privateConstructor();

  static final LocalSyncService instance =
      LocalSyncService._privateConstructor();

  Future<void> init(SharedPreferences preferences) async {
    _prefs = preferences;
    if (!AppLifecycleService.instance.isForeground) {
      await PhotoManager.setIgnorePermissionCheck(true);
    }
    if (hasGrantedPermissions()) {
      _registerChangeCallback();
    }
  }

  Future<void> sync() async {
    if (!_prefs.containsKey(kHasGrantedPermissionsKey)) {
      _logger.info("Skipping local sync since permission has not been granted");
      return;
    }
    if (Platform.isAndroid && AppLifecycleService.instance.isForeground) {
      final permissionState = await PhotoManager.requestPermissionExtend();
      if (permissionState != PermissionState.authorized) {
        _logger.severe(
          "sync requested with invalid permission",
          permissionState.toString(),
        );
        return;
      }
    }
    if (_existingSync != null) {
      _logger.warning("Sync already in progress, skipping.");
      return _existingSync!.future;
    }
    _existingSync = Completer<void>();
    final int ownerID = Configuration.instance.getUserID()!;
    final existingLocalFileIDs = await _db.getExistingLocalFileIDs(ownerID);
    _logger.info("${existingLocalFileIDs.length} localIDs were discovered");

    final syncStartTime = DateTime.now().microsecondsSinceEpoch;
    final lastDBUpdationTime = _prefs.getInt(kDbUpdationTimeKey) ?? 0;
    final startTime = DateTime.now().microsecondsSinceEpoch;
    if (lastDBUpdationTime != 0) {
      await _loadAndStoreDiff(
        existingLocalFileIDs,
        fromTime: lastDBUpdationTime,
        toTime: syncStartTime,
      );
    } else {
      // Load from 0 - 01.01.2010
      Bus.instance.fire(SyncStatusUpdate(SyncStatus.startedFirstGalleryImport));
      var startTime = 0;
      var toYear = 2010;
      var toTime = DateTime(toYear).microsecondsSinceEpoch;
      while (toTime < syncStartTime) {
        await _loadAndStoreDiff(
          existingLocalFileIDs,
          fromTime: startTime,
          toTime: toTime,
        );
        startTime = toTime;
        toYear++;
        toTime = DateTime(toYear).microsecondsSinceEpoch;
      }
      await _loadAndStoreDiff(
        existingLocalFileIDs,
        fromTime: startTime,
        toTime: syncStartTime,
      );
    }
    if (!hasCompletedFirstImport()) {
      await _prefs.setBool(kHasCompletedFirstImportKey, true);
      await _refreshDeviceFolderCountAndCover(isFirstSync: true);
      _logger.fine("first gallery import finished");
      Bus.instance
          .fire(SyncStatusUpdate(SyncStatus.completedFirstGalleryImport));
    }
    final endTime = DateTime.now().microsecondsSinceEpoch;
    final duration = Duration(microseconds: endTime - startTime);
    _logger.info("Load took " + duration.inMilliseconds.toString() + "ms");
    _existingSync?.complete();
    _existingSync = null;
  }

  Future<bool> _refreshDeviceFolderCountAndCover({
    bool isFirstSync = false,
  }) async {
    final List<Tuple2<AssetPathEntity, String>> result =
        await getDeviceFolderWithCountAndCoverID();
    final bool hasUpdated = await _db.updateDeviceCoverWithCount(
      result,
      shouldBackup: Configuration.instance.hasSelectedAllFoldersForBackup(),
    );
    // do not fire UI update event during first sync. Otherwise the next screen
    // to shop the backup folder is skipped
    if (hasUpdated && !isFirstSync) {
      Bus.instance.fire(BackupFoldersUpdatedEvent());
    }
    return hasUpdated;
  }

  Future<bool> syncAll() async {
    if (!Configuration.instance.isLoggedIn()) {
      _logger.warning("syncCall called when user is not logged in");
      return false;
    }
    final stopwatch = EnteWatch("localSyncAll")..start();

    final localAssets = await getAllLocalAssets();
    _logger.info(
      "Loading allLocalAssets ${localAssets.length} took ${stopwatch.elapsedMilliseconds}ms ",
    );
    await _refreshDeviceFolderCountAndCover();
    _logger.info(
      "refreshDeviceFolderCountAndCover + allLocalAssets took ${stopwatch.elapsedMilliseconds}ms ",
    );
    final int ownerID = Configuration.instance.getUserID()!;
    final existingLocalFileIDs = await _db.getExistingLocalFileIDs(ownerID);
    final Map<String, Set<String>> pathToLocalIDs =
        await _db.getDevicePathIDToLocalIDMap();
    final invalidIDs = _getInvalidFileIDs().toSet();
    final localDiffResult = await getDiffWithLocal(
      localAssets,
      existingLocalFileIDs,
      pathToLocalIDs,
      invalidIDs,
    );
    bool hasAnyMappingChanged = false;
    if (localDiffResult.newPathToLocalIDs?.isNotEmpty ?? false) {
      await _db
          .insertPathIDToLocalIDMapping(localDiffResult.newPathToLocalIDs!);
      hasAnyMappingChanged = true;
    }
    if (localDiffResult.deletePathToLocalIDs?.isNotEmpty ?? false) {
      await _db
          .deletePathIDToLocalIDMapping(localDiffResult.deletePathToLocalIDs!);
      hasAnyMappingChanged = true;
    }
    final bool hasUnsyncedFiles =
        localDiffResult.uniqueLocalFiles?.isNotEmpty ?? false;
    if (hasUnsyncedFiles) {
      await _db.insertMultiple(
        localDiffResult.uniqueLocalFiles!,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      _logger.info(
        "Inserted ${localDiffResult.uniqueLocalFiles?.length} "
        "un-synced files",
      );
    }
    debugPrint(
      "syncAll: mappingChange : $hasAnyMappingChanged, "
      "unSyncedFiles: $hasUnsyncedFiles",
    );
    if (hasAnyMappingChanged || hasUnsyncedFiles) {
      Bus.instance.fire(
        LocalPhotosUpdatedEvent(
          localDiffResult.uniqueLocalFiles,
          source: "syncAllChange",
        ),
      );
    }
    _logger.info("syncAll took ${stopwatch.elapsed.inMilliseconds}ms ");
    return hasUnsyncedFiles;
  }

  Future<void> ignoreUpload(EnteFile file, InvalidFileError error) async {
    if (file.localID == null ||
        file.deviceFolder == null ||
        file.title == null) {
      _logger.warning('Invalid file received for ignoring: $file');
      return;
    }
    final ignored = IgnoredFile(
      file.localID,
      file.title,
      file.deviceFolder,
      error.reason.name,
    );
    await IgnoredFilesService.instance.cacheAndInsert([ignored]);
  }

  @Deprecated(
    "remove usage after few releases as we will switch to ignored files. Keeping it now to clear the invalid file ids from shared prefs",
  )
  List<String> _getInvalidFileIDs() {
    if (_prefs.containsKey(kInvalidFileIDsKey)) {
      _prefs.remove(kInvalidFileIDsKey);
      return <String>[];
    } else {
      return <String>[];
    }
  }

  bool hasGrantedPermissions() {
    return _prefs.getBool(kHasGrantedPermissionsKey) ?? false;
  }

  bool hasGrantedLimitedPermissions() {
    return _prefs.getString(kPermissionStateKey) ==
        PermissionState.limited.toString();
  }

  bool hasGrantedFullPermission() {
    return (_prefs.getString(kPermissionStateKey) ?? '') ==
        PermissionState.authorized.toString();
  }

  Future<void> onUpdatePermission(PermissionState state) async {
    await _prefs.setBool(kHasGrantedPermissionsKey, true);
    await _prefs.setString(kPermissionStateKey, state.toString());
  }

  Future<void> onPermissionGranted(PermissionState state) async {
    await _prefs.setBool(kHasGrantedPermissionsKey, true);
    await _prefs.setString(kPermissionStateKey, state.toString());
    if (state == PermissionState.limited) {
      // when limited permission is granted, by default mark all folders for
      // backup
      await Configuration.instance.setSelectAllFoldersForBackup(true);
    }
    _registerChangeCallback();
  }

  bool hasCompletedFirstImport() {
    return _prefs.getBool(kHasCompletedFirstImportKey) ?? false;
  }

  // Warning: resetLocalSync should only be used for testing imported related
  // changes
  Future<void> resetLocalSync() async {
    assert(kDebugMode, "only available in debug mode");
    await FilesDB.instance.deleteDB();
    for (var element in [
      kHasCompletedFirstImportKey,
      kDbUpdationTimeKey,
      "has_synced_edit_time",
      "has_selected_all_folders_for_backup",
    ]) {
      await _prefs.remove(element);
    }
  }

  Future<void> _loadAndStoreDiff(
    Set<String> existingLocalDs, {
    required int fromTime,
    required int toTime,
  }) async {
    final Tuple2<List<LocalPathAsset>, List<EnteFile>> result =
        await getLocalPathAssetsAndFiles(fromTime, toTime);

    final List<EnteFile> files = result.item2;
    if (files.isNotEmpty) {
      // Update the mapping for device path_id to local file id. Also, keep track
      // of newly discovered device paths
      await FilesDB.instance.insertLocalAssets(
        result.item1,
        shouldAutoBackup:
            Configuration.instance.hasSelectedAllFoldersForBackup(),
      );

      _logger.info(
        "Loaded ${files.length} photos from " +
            DateTime.fromMicrosecondsSinceEpoch(fromTime).toString() +
            " to " +
            DateTime.fromMicrosecondsSinceEpoch(toTime).toString(),
      );
      await _trackUpdatedFiles(files, existingLocalDs);
      // keep reference of all Files for firing LocalPhotosUpdatedEvent
      final List<EnteFile> allFiles = [];
      allFiles.addAll(files);
      // remove existing files and insert newly imported files in the table
      files.removeWhere((file) => existingLocalDs.contains(file.localID));
      await _db.insertMultiple(
        files,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      _logger.info('Inserted ${files.length} files');
      Bus.instance.fire(
        LocalPhotosUpdatedEvent(allFiles, source: "loadedPhoto"),
      );
    }
    await _prefs.setInt(kDbUpdationTimeKey, toTime);
  }

  Future<void> _trackUpdatedFiles(
    List<EnteFile> files,
    Set<String> existingLocalFileIDs,
  ) async {
    final List<String> updatedLocalIDs = files
        .where(
          (file) =>
              file.localID != null &&
              existingLocalFileIDs.contains(file.localID),
        )
        .map((e) => e.localID!)
        .toList();
    if (updatedLocalIDs.isNotEmpty) {
      await FileUpdationDB.instance.insertMultiple(
        updatedLocalIDs,
        FileUpdationDB.modificationTimeUpdated,
      );
    }
  }

  void _registerChangeCallback() {
    _changeCallbackDebouncer = Debouncer(const Duration(milliseconds: 500));
    // In case of iOS limit permission, this call back is fired immediately
    // after file selection dialog is dismissed.
    PhotoManager.addChangeCallback((value) async {
      _logger.info("Something changed on disk");
      _changeCallbackDebouncer.run(() async {
        unawaited(checkAndSync());
      });
    });
    PhotoManager.startChangeNotify();
  }

  Future<void> checkAndSync() async {
    if (_existingSync != null) {
      await _existingSync!.future;
    }
    if (hasGrantedLimitedPermissions()) {
      unawaited(syncAll());
    } else {
      unawaited(sync().then((value) => _refreshDeviceFolderCountAndCover()));
    }
  }
}
