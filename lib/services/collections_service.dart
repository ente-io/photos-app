import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sodium/flutter_sodium.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/errors.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/core/network.dart';
import 'package:photos/db/collections_db.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/db/trash_db.dart';
import 'package:photos/events/collection_updated_event.dart';
import 'package:photos/events/files_updated_event.dart';
import 'package:photos/events/force_reload_home_gallery_event.dart';
import 'package:photos/events/local_photos_updated_event.dart';
import 'package:photos/models/collection.dart';
import 'package:photos/models/collection_file_item.dart';
import 'package:photos/models/file.dart';
import 'package:photos/services/remote_sync_service.dart';
import 'package:photos/utils/crypto_util.dart';
import 'package:photos/utils/file_download_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CollectionsService {
  static final _collectionSyncTimeKeyPrefix = "collection_sync_time_";
  static final _collectionsSyncTimeKey = "collections_sync_time";

  static const int kMaximumWriteAttempts = 5;

  final _logger = Logger("CollectionsService");

  late CollectionsDB _db;
  late FilesDB _filesDB;
  late Configuration _config;
  late SharedPreferences _prefs;
  Future<List<File>>? _cachedLatestFiles;
  final _dio = Network.instance.getDio();
  final _localCollections = <String, Collection>{};
  final _collectionIDToCollections = <int?, Collection>{};
  final _cachedKeys = <int?, Uint8List>{};

  CollectionsService._privateConstructor() {
    _db = CollectionsDB.instance;
    _filesDB = FilesDB.instance;
    _config = Configuration.instance;
  }

  static final CollectionsService instance =
      CollectionsService._privateConstructor();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final collections = await _db.getAllCollections();
    for (final collection in collections) {
      _cacheCollectionAttributes(collection);
    }
    Bus.instance.on<LocalPhotosUpdatedEvent>().listen((event) {
      _cachedLatestFiles = null;
      getLatestCollectionFiles();
    });
    Bus.instance.on<CollectionUpdatedEvent>().listen((event) {
      _cachedLatestFiles = null;
      getLatestCollectionFiles();
    });
  }

  Future<List<Collection>> sync() async {
    _logger.info("Syncing collections");
    final lastCollectionUpdationTime =
        _prefs.getInt(_collectionsSyncTimeKey) ?? 0;

    // Might not have synced the collection fully
    final fetchedCollections =
        await _fetchCollections(lastCollectionUpdationTime);
    final updatedCollections = <Collection>[];
    int? maxUpdationTime = lastCollectionUpdationTime;
    final ownerID = _config.getUserID();
    for (final collection in fetchedCollections) {
      if (collection.isDeleted) {
        await _filesDB.deleteCollection(collection.id);
        await setCollectionSyncTime(collection.id, null);
        Bus.instance.fire(LocalPhotosUpdatedEvent(List<File>.empty()));
      }
      // remove reference for incoming collections when unshared/deleted
      if (collection.isDeleted && ownerID != collection.owner?.id) {
        await _db.deleteCollection(collection.id);
      } else {
        // keep entry for deletedCollection as collectionKey may be used during
        // trash file decryption
        updatedCollections.add(collection);
      }
      maxUpdationTime = collection.updationTime! > maxUpdationTime!
          ? collection.updationTime
          : maxUpdationTime;
    }
    await _updateDB(updatedCollections);
    _prefs.setInt(_collectionsSyncTimeKey, maxUpdationTime!);
    final collections = await _db.getAllCollections();
    for (final collection in collections) {
      _cacheCollectionAttributes(collection);
    }
    if (fetchedCollections.isNotEmpty) {
      _logger.info("Collections updated");
      Bus.instance.fire(CollectionUpdatedEvent(null, List<File>.empty()));
    }
    return collections;
  }

  void clearCache() {
    _localCollections.clear();
    _collectionIDToCollections.clear();
    _cachedKeys.clear();
  }

  Future<List<Collection>> getCollectionsToBeSynced() async {
    final collections = await _db.getAllCollections();
    final updatedCollections = <Collection>[];
    for (final c in collections) {
      if (c.updationTime! > getCollectionSyncTime(c.id) && !c.isDeleted) {
        updatedCollections.add(c);
      }
    }
    return updatedCollections;
  }

  int getCollectionSyncTime(int? collectionID) {
    return _prefs
            .getInt(_collectionSyncTimeKeyPrefix + collectionID.toString()) ??
        0;
  }

  Future<List<File>>? getLatestCollectionFiles() {
    _cachedLatestFiles ??= _filesDB.getLatestCollectionFiles();
    return _cachedLatestFiles;
  }

  Future<bool> setCollectionSyncTime(int? collectionID, int? time) async {
    final key = _collectionSyncTimeKeyPrefix + collectionID.toString();
    if (time == null) {
      return _prefs.remove(key);
    }
    return _prefs.setInt(key, time);
  }

  Collection? getCollectionForPath(String? path) {
    return _localCollections[path!];
  }

  // getActiveCollections returns list of collections which are not deleted yet
  List<Collection> getActiveCollections() {
    return _collectionIDToCollections.values
        .toList()
        .where((element) => !element.isDeleted)
        .toList();
  }

  Future<List<User>> getSharees(int? collectionID) {
    return _dio
        .get(
      Configuration.instance.getHttpEndpoint() + "/collections/sharees",
      queryParameters: {
        "collectionID": collectionID,
      },
      options:
          Options(headers: {"X-Auth-Token": Configuration.instance.getToken()}),
    )
        .then((response) {
      _logger.info(response.toString());
      final sharees = <User>[];
      for (final user in response.data["sharees"]) {
        sharees.add(User.fromMap(user));
      }
      return sharees;
    });
  }

  Future<void> share(int collectionID, String email, String publicKey) async {
    final encryptedKey = CryptoUtil.sealSync(
        getCollectionKey(collectionID)!, Sodium.base642bin(publicKey));
    try {
      await _dio.post(
        Configuration.instance.getHttpEndpoint() + "/collections/share",
        data: {
          "collectionID": collectionID,
          "email": email,
          "encryptedKey": Sodium.bin2base64(encryptedKey),
        },
        options: Options(
            headers: {"X-Auth-Token": Configuration.instance.getToken()}),
      );
    } on DioError catch (e) {
      if (e.response!.statusCode == 402) {
        throw SharingNotPermittedForFreeAccountsError();
      }
      rethrow;
    }
    RemoteSyncService.instance.sync(silently: true);
  }

  Future<void> unshare(int collectionID, String email) async {
    try {
      await _dio.post(
        Configuration.instance.getHttpEndpoint() + "/collections/unshare",
        data: {
          "collectionID": collectionID,
          "email": email,
        },
        options: Options(
            headers: {"X-Auth-Token": Configuration.instance.getToken()}),
      );
      _collectionIDToCollections[collectionID]!
          .sharees!
          .removeWhere((user) => user.email == email);
      _db.insert([_collectionIDToCollections[collectionID]]);
    } catch (e) {
      _logger.severe(e);
      rethrow;
    }
    RemoteSyncService.instance.sync(silently: true);
  }

  Uint8List? getCollectionKey(int? collectionID) {
    if (!_cachedKeys.containsKey(collectionID)) {
      final collection = _collectionIDToCollections[collectionID];
      if (collection == null) {
        // Async fetch for collection. A collection might be
        // missing from older clients when we used to delete the collection
        // from db. For trashed files, we need collection data for decryption.
        fetchCollectionByID(collectionID);
        throw AssertionError('collectionID $collectionID is not cached');
      }
      _cachedKeys[collectionID] = _getDecryptedKey(collection);
    }
    return _cachedKeys[collectionID];
  }

  Uint8List _getDecryptedKey(Collection collection) {
    final encryptedKey = Sodium.base642bin(collection.encryptedKey);
    if (collection.owner!.id == _config.getUserID()) {
      return CryptoUtil.decryptSync(encryptedKey, _config.getKey(),
          Sodium.base642bin(collection.keyDecryptionNonce));
    } else {
      return CryptoUtil.openSealSync(
          encryptedKey,
          Sodium.base642bin(_config.getKeyAttributes()!.publicKey!),
          _config.getSecretKey()!);
    }
  }

  Future<void> rename(Collection collection, String newName) async {
    try {
      final encryptedName = CryptoUtil.encryptSync(
          utf8.encode(newName) as Uint8List?, getCollectionKey(collection.id));
      await _dio.post(
        Configuration.instance.getHttpEndpoint() + "/collections/rename",
        data: {
          "collectionID": collection.id,
          "encryptedName": Sodium.bin2base64(encryptedName.encryptedData!),
          "nameDecryptionNonce": Sodium.bin2base64(encryptedName.nonce!)
        },
        options: Options(
            headers: {"X-Auth-Token": Configuration.instance.getToken()}),
      );
      // trigger sync to fetch the latest name from server
      sync();
    } catch (e, s) {
      _logger.severe("failed to rename collection", e, s);
      rethrow;
    }
  }

  Future<List<Collection>> _fetchCollections(int sinceTime) async {
    try {
      final response = await _dio.get(
        Configuration.instance.getHttpEndpoint() + "/collections",
        queryParameters: {
          "sinceTime": sinceTime,
        },
        options: Options(
            headers: {"X-Auth-Token": Configuration.instance.getToken()}),
      );
      final List<Collection> collections = [];
      final c = response.data["collections"];
      for (final collection in c) {
        collections.add(Collection.fromMap(collection));
      }
      return collections;
    } catch (e) {
      if (e is DioError && e.response?.statusCode == 401) {
        throw UnauthorizedError();
      }
      rethrow;
    }
  }

  Collection? getCollectionByID(int? collectionID) {
    return _collectionIDToCollections[collectionID];
  }

  Future<Collection> createAlbum(String albumName) async {
    final key = CryptoUtil.generateKey();
    final encryptedKeyData = CryptoUtil.encryptSync(key, _config.getKey());
    final encryptedName =
        CryptoUtil.encryptSync(utf8.encode(albumName) as Uint8List?, key);
    final collection = await createAndCacheCollection(Collection(
      null,
      null,
      Sodium.bin2base64(encryptedKeyData.encryptedData!),
      Sodium.bin2base64(encryptedKeyData.nonce!),
      null,
      Sodium.bin2base64(encryptedName.encryptedData!),
      Sodium.bin2base64(encryptedName.nonce!),
      CollectionType.album,
      CollectionAttributes(),
      null,
      null,
    ));
    return collection;
  }

  Future<Collection> fetchCollectionByID(int? collectionID) async {
    try {
      _logger.fine('fetching collectionByID $collectionID');
      final response = await _dio.get(
        Configuration.instance.getHttpEndpoint() + "/collections/$collectionID",
        options: Options(
            headers: {"X-Auth-Token": Configuration.instance.getToken()}),
      );
      assert(response != null && response.data != null);
      final collection = Collection.fromMap(response.data["collection"]);
      await _db.insert(List.from([collection]));
      _cacheCollectionAttributes(collection);
      return collection;
    } catch (e) {
      if (e is DioError && e.response?.statusCode == 401) {
        throw UnauthorizedError();
      }
      _logger.severe('failed to fetch collection: $collectionID', e);
      rethrow;
    }
  }

  Future<Collection?> getOrCreateForPath(String? path) async {
    if (_localCollections.containsKey(path) &&
        _localCollections[path!]!.owner!.id == _config.getUserID()) {
      return _localCollections[path];
    }
    final key = CryptoUtil.generateKey();
    final encryptedKeyData = CryptoUtil.encryptSync(key, _config.getKey());
    final encryptedPath =
        CryptoUtil.encryptSync(utf8.encode(path!) as Uint8List?, key);
    final collection = await createAndCacheCollection(Collection(
      null,
      null,
      Sodium.bin2base64(encryptedKeyData.encryptedData!),
      Sodium.bin2base64(encryptedKeyData.nonce!),
      null,
      Sodium.bin2base64(encryptedPath.encryptedData!),
      Sodium.bin2base64(encryptedPath.nonce!),
      CollectionType.folder,
      CollectionAttributes(
        encryptedPath: Sodium.bin2base64(encryptedPath.encryptedData!),
        pathDecryptionNonce: Sodium.bin2base64(encryptedPath.nonce!),
        version: 1,
      ),
      null,
      null,
    ));
    return collection;
  }

  Future<void> addToCollection(int? collectionID, List<File?> files) async {
    final containsUploadedFile = files.firstWhere(
            (element) => element!.uploadedFileID != null,
            orElse: () => null) !=
        null;
    if (containsUploadedFile) {
      final existingFileIDsInCollection =
          await FilesDB.instance.getUploadedFileIDs(collectionID);
      files.removeWhere((element) =>
          element!.uploadedFileID != null &&
          existingFileIDsInCollection.contains(element.uploadedFileID));
      if (files.isEmpty) {
        _logger.info("nothing to add to the collection");
        return;
      }
    }

    final params = <String, dynamic>{};
    params["collectionID"] = collectionID;
    for (final file in files) {
      final key = decryptFileKey(file!);
      file.generatedID = null; // So that a new entry is created in the FilesDB
      file.collectionID = collectionID;
      final encryptedKeyData =
          CryptoUtil.encryptSync(key, getCollectionKey(collectionID));
      file.encryptedKey = Sodium.bin2base64(encryptedKeyData.encryptedData!);
      file.keyDecryptionNonce = Sodium.bin2base64(encryptedKeyData.nonce!);
      if (params["files"] == null) {
        params["files"] = [];
      }
      params["files"].add(CollectionFileItem(
              file.uploadedFileID, file.encryptedKey, file.keyDecryptionNonce)
          .toMap());
    }

    try {
      await _dio.post(
        Configuration.instance.getHttpEndpoint() + "/collections/add-files",
        data: params,
        options: Options(
            headers: {"X-Auth-Token": Configuration.instance.getToken()}),
      );
      await _filesDB.insertMultiple(files);
      Bus.instance.fire(CollectionUpdatedEvent(collectionID, files));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> restore(int? toCollectionID, List<File> files) async {
    final params = <String, dynamic>{};
    params["collectionID"] = toCollectionID;
    params["files"] = [];
    final toCollectionKey = getCollectionKey(toCollectionID);
    for (final file in files) {
      final key = decryptFileKey(file);
      file.generatedID = null; // So that a new entry is created in the FilesDB
      file.collectionID = toCollectionID;
      final encryptedKeyData = CryptoUtil.encryptSync(key, toCollectionKey);
      file.encryptedKey = Sodium.bin2base64(encryptedKeyData.encryptedData!);
      file.keyDecryptionNonce = Sodium.bin2base64(encryptedKeyData.nonce!);
      params["files"].add(CollectionFileItem(
              file.uploadedFileID, file.encryptedKey, file.keyDecryptionNonce)
          .toMap());
    }
    try {
      await _dio.post(
        Configuration.instance.getHttpEndpoint() + "/collections/restore-files",
        data: params,
        options: Options(
            headers: {"X-Auth-Token": Configuration.instance.getToken()}),
      );
      await _filesDB.insertMultiple(files);
      await TrashDB.instance
          .delete(files.map((e) => e.uploadedFileID).toList());
      Bus.instance.fire(CollectionUpdatedEvent(toCollectionID, files));
      Bus.instance.fire(FilesUpdatedEvent(files));
      // Remove imported local files which are imported but not uploaded.
      // This handles the case where local file was trashed -> imported again
      // but not uploaded automatically as it was trashed.
      final localIDs = files
          .where((e) => e.localID != null)
          .map((e) => e.localID)
          .toSet()
          .toList();
      if (localIDs.isNotEmpty) {
        await _filesDB.deleteUnSyncedLocalFiles(localIDs);
      }
      // Force reload home gallery to pull in the restored files
      Bus.instance.fire(ForceReloadHomeGalleryEvent());
    } catch (e, s) {
      _logger.severe("failed to restore files", e, s);
      rethrow;
    }
  }

  Future<void> move(
      int toCollectionID, int? fromCollectionID, List<File> files) async {
    _validateMoveRequest(toCollectionID, fromCollectionID, files);
    final existingUploadedIDs =
        await FilesDB.instance.getUploadedFileIDs(toCollectionID);
    files.removeWhere((element) =>
        element.uploadedFileID != null &&
        existingUploadedIDs.contains(element.uploadedFileID));
    if (files.isEmpty) {
      _logger.info("nothing to move to collection");
      return;
    }
    final params = <String, dynamic>{};
    params["toCollectionID"] = toCollectionID;
    params["fromCollectionID"] = fromCollectionID;
    params["files"] = [];
    for (final file in files) {
      final fileKey = decryptFileKey(file);
      file.generatedID = null; // So that a new entry is created in the FilesDB
      file.collectionID = toCollectionID;
      final encryptedKeyData =
          CryptoUtil.encryptSync(fileKey, getCollectionKey(toCollectionID));
      file.encryptedKey = Sodium.bin2base64(encryptedKeyData.encryptedData!);
      file.keyDecryptionNonce = Sodium.bin2base64(encryptedKeyData.nonce!);
      params["files"].add(CollectionFileItem(
              file.uploadedFileID, file.encryptedKey, file.keyDecryptionNonce)
          .toMap());
    }
    return _dio
        .post(
      Configuration.instance.getHttpEndpoint() + "/collections/move-files",
      data: params,
      options:
          Options(headers: {"X-Auth-Token": Configuration.instance.getToken()}),
    )
        .then((value) async {
      // insert files to new collection
      await _filesDB.insertMultiple(files);
      // remove files from old collection
      await _filesDB.removeFromCollection(
          fromCollectionID, files.map((e) => e.uploadedFileID).toList());
      Bus.instance.fire(CollectionUpdatedEvent(toCollectionID, files));
      Bus.instance.fire(CollectionUpdatedEvent(fromCollectionID, files,
          type: EventType.deletedFromRemote));
    });
  }

  void _validateMoveRequest(
      int? toCollectionID, int? fromCollectionID, List<File> files) {
    if (toCollectionID == fromCollectionID) {
      throw AssertionError("can't move to same album");
    }
    for (final file in files) {
      if (file.uploadedFileID == null) {
        throw AssertionError("can only move uploaded memories");
      }
      if (file.collectionID != fromCollectionID) {
        throw AssertionError("all memories should belong to the same album");
      }
      if (file.ownerID != Configuration.instance.getUserID()) {
        throw AssertionError("can only move memories uploaded by you");
      }
    }
  }

  Future<void> removeFromCollection(int? collectionID, List<File> files) async {
    final params = <String, dynamic>{};
    params["collectionID"] = collectionID;
    for (final file in files) {
      if (params["fileIDs"] == null) {
        params["fileIDs"] = <int>[];
      }
      params["fileIDs"].add(file.uploadedFileID);
    }
    await _dio.post(
      Configuration.instance.getHttpEndpoint() + "/collections/v2/remove-files",
      data: params,
      options:
          Options(headers: {"X-Auth-Token": Configuration.instance.getToken()}),
    );
    await _filesDB.removeFromCollection(collectionID, params["fileIDs"]);
    Bus.instance.fire(CollectionUpdatedEvent(collectionID, files));
    Bus.instance.fire(LocalPhotosUpdatedEvent(files));
    RemoteSyncService.instance.sync(silently: true);
  }

  Future<Collection> createAndCacheCollection(Collection collection) async {
    return _dio
        .post(
      Configuration.instance.getHttpEndpoint() + "/collections",
      data: collection.toMap(),
      options:
          Options(headers: {"X-Auth-Token": Configuration.instance.getToken()}),
    )
        .then((response) {
      final collection = Collection.fromMap(response.data["collection"]);
      return _cacheCollectionAttributes(collection);
    });
  }

  Collection _cacheCollectionAttributes(Collection collection) {
    final collectionWithDecryptedName =
        _getCollectionWithDecryptedName(collection);
    if (collection.attributes.encryptedPath != null &&
        !(collection.isDeleted)) {
      _localCollections[decryptCollectionPath(collection)] =
          collectionWithDecryptedName;
    }
    _collectionIDToCollections[collection.id] = collectionWithDecryptedName;
    return collectionWithDecryptedName;
  }

  String decryptCollectionPath(Collection collection) {
    final key = collection.attributes.version == 1
        ? _getDecryptedKey(collection)
        : _config.getKey();
    return utf8.decode(CryptoUtil.decryptSync(
        Sodium.base642bin(collection.attributes.encryptedPath!),
        key,
        Sodium.base642bin(collection.attributes.pathDecryptionNonce!)));
  }

  bool hasSyncedCollections() {
    return _prefs.containsKey(_collectionsSyncTimeKey);
  }

  Collection _getCollectionWithDecryptedName(Collection collection) {
    if (collection.encryptedName != null &&
        collection.encryptedName!.isNotEmpty) {
      String name;
      try {
        final result = CryptoUtil.decryptSync(
            Sodium.base642bin(collection.encryptedName!),
            _getDecryptedKey(collection),
            Sodium.base642bin(collection.nameDecryptionNonce!));
        name = utf8.decode(result);
      } catch (e, s) {
        _logger.severe(
            "Error while decrypting collection name: " +
                collection.id.toString(),
            e,
            s);
        name = "Unknown Album";
      }
      return collection.copyWith(name: name);
    } else {
      return collection;
    }
  }

  Future _updateDB(List<Collection> collections, {int attempt = 1}) async {
    try {
      await _db.insert(collections);
    } catch (e) {
      if (attempt < kMaximumWriteAttempts) {
        return _updateDB(collections, attempt: ++attempt);
      } else {
        rethrow;
      }
    }
  }
}

class AddFilesRequest {
  final int collectionID;
  final List<CollectionFileItem> files;

  AddFilesRequest(
    this.collectionID,
    this.files,
  );

  AddFilesRequest copyWith({
    required int collectionID,
    List<CollectionFileItem>? files,
  }) {
    return AddFilesRequest(
      collectionID,
      files ?? this.files,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'collectionID': collectionID,
      'files': files.map((x) => x.toMap()).toList(),
    };
  }

  static fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;

    return AddFilesRequest(
      map['collectionID'],
      List<CollectionFileItem>.from(
          map['files']?.map((x) => CollectionFileItem.fromMap(x))),
    );
  }

  String toJson() => json.encode(toMap());

  factory AddFilesRequest.fromJson(String source) =>
      AddFilesRequest.fromMap(json.decode(source));

  @override
  String toString() =>
      'AddFilesRequest(collectionID: $collectionID, files: $files)';

  @override
  bool operator ==(Object o) {
    if (identical(this, o)) return true;

    return o is AddFilesRequest &&
        o.collectionID == collectionID &&
        listEquals(o.files, files);
  }

  @override
  int get hashCode => collectionID.hashCode ^ files.hashCode;
}

class SharingNotPermittedForFreeAccountsError extends Error {}
