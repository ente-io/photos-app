import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/core/network.dart';
import 'package:photos/db/trash_db.dart';
import 'package:photos/events/force_reload_trash_page_event.dart';
import 'package:photos/models/file.dart';
import 'package:photos/models/ignored_file.dart';
import 'package:photos/models/trash_file.dart';
import 'package:photos/models/trash_item_request.dart';
import 'package:photos/services/ignored_files_service.dart';
import 'package:photos/utils/trash_diff_fetcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrashSyncService {
  final _logger = Logger("TrashSyncService");
  final _diffFetcher = TrashDiffFetcher();
  final _trashDB = TrashDB.instance;
  static const kLastTrashSyncTime = "last_trash_sync_time";
  late SharedPreferences _prefs;

  TrashSyncService._privateConstructor();

  static final TrashSyncService instance =
      TrashSyncService._privateConstructor();
  final _dio = Network.instance.getDio();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> syncTrash() async {
    final lastSyncTime = _getSyncTime();
    _logger.fine('sync trash sinceTime : $lastSyncTime');
    final diff = await _diffFetcher.getTrashFilesDiff(lastSyncTime);
    if (diff.trashedFiles.isNotEmpty) {
      _logger.fine("inserting ${diff.trashedFiles.length} items in trash");
      await _trashDB.insertMultiple(diff.trashedFiles);
    }
    if (diff.deletedFiles.isNotEmpty) {
      _logger.fine("discard ${diff.deletedFiles.length} deleted items");
      await _trashDB
          .delete(diff.deletedFiles.map((e) => e.uploadedFileID).toList());
    }
    if (diff.restoredFiles.isNotEmpty) {
      _logger.fine("discard ${diff.restoredFiles.length} restored items");
      await _trashDB
          .delete(diff.restoredFiles.map((e) => e.uploadedFileID).toList());
    }

    await _updateIgnoredFiles(diff);

    if (diff.lastSyncedTimeStamp != 0) {
      await _setSyncTime(diff.lastSyncedTimeStamp);
    }
    if (diff.hasMore!) {
      return await syncTrash();
    }
  }

  Future<void> _updateIgnoredFiles(Diff diff) async {
    final ignoredFiles = <IgnoredFile>[];
    for (TrashFile t in diff.trashedFiles) {
      final file = IgnoredFile.fromTrashItem(t);
      if (file != null) {
        ignoredFiles.add(file);
      }
    }
    for (TrashFile t in diff.deletedFiles) {
      final file = IgnoredFile.fromTrashItem(t);
      if (file != null) {
        ignoredFiles.add(file);
      }
    }
    if (ignoredFiles.isNotEmpty) {
      _logger.fine('updating ${ignoredFiles.length} ignored files ');
      await IgnoredFilesService.instance.cacheAndInsert(ignoredFiles);
    }
  }

  Future<bool> _setSyncTime(int time) async {
    return _prefs.setInt(kLastTrashSyncTime, time);
  }

  int _getSyncTime() {
    return _prefs.getInt(kLastTrashSyncTime) ?? 0;
  }

  Future<dynamic> trashFilesOnServer(
      List<TrashRequest> trashRequestItems) async {
    final params = <String, dynamic>{};
    final includedFileIDs = <int>{};
    params["items"] = [];
    for (final item in trashRequestItems) {
      if (!includedFileIDs.contains(item.fileID)) {
        params["items"].add(item.toJson());
        includedFileIDs.add(item.fileID);
      }
    }
    return await _dio.post(
      Configuration.instance.getHttpEndpoint() + "/files/trash",
      options: Options(
        headers: {
          "X-Auth-Token": Configuration.instance.getToken(),
        },
      ),
      data: params,
    );
  }

  Future<void> deleteFromTrash(List<File> files) async {
    final params = <String, dynamic>{};
    final uniqueFileIds = files.map((e) => e.uploadedFileID).toSet().toList();
    params["fileIDs"] = [];
    for (final fileID in uniqueFileIds) {
      params["fileIDs"].add(fileID);
    }
    try {
      await _dio.post(
        Configuration.instance.getHttpEndpoint() + "/trash/delete",
        options: Options(
          headers: {
            "X-Auth-Token": Configuration.instance.getToken(),
          },
        ),
        data: params,
      );
      _trashDB.delete(uniqueFileIds);
    } catch (e, s) {
      _logger.severe("failed to delete from trash", e, s);
      rethrow;
    }
  }

  Future<void> emptyTrash() async {
    final params = <String, dynamic>{};
    params["lastUpdatedAt"] = _getSyncTime();
    try {
      await _dio.post(
        Configuration.instance.getHttpEndpoint() + "/trash/empty",
        options: Options(
          headers: {
            "X-Auth-Token": Configuration.instance.getToken(),
          },
        ),
        data: params,
      );
      await _trashDB.clearTable();
      Bus.instance.fire(ForceReloadTrashPageEvent());
    } catch (e, s) {
      _logger.severe("failed to empty trash", e, s);
      rethrow;
    }
  }
}
