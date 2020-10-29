import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sodium/flutter_sodium.dart';
import 'package:logging/logging.dart';

import 'package:photos/core/configuration.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/db/collections_db.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/events/collection_updated_event.dart';
import 'package:photos/models/collection.dart';
import 'package:photos/models/collection_file_item.dart';
import 'package:photos/models/file.dart';
import 'package:photos/utils/crypto_util.dart';
import 'package:photos/utils/file_util.dart';

class CollectionsService {
  final _logger = Logger("CollectionsService");

  CollectionsDB _db;
  Configuration _config;
  final _localCollections = Map<String, Collection>();
  final _collectionIDToCollections = Map<int, Collection>();
  final _cachedKeys = Map<int, Uint8List>();

  CollectionsService._privateConstructor() {
    _db = CollectionsDB.instance;
    _config = Configuration.instance;
  }

  static final CollectionsService instance =
      CollectionsService._privateConstructor();

  Future<void> init() async {
    final collections = await _db.getAllCollections();
    for (final collection in collections) {
      _cacheCollectionAttributes(collection);
    }
  }

  Future<void> sync() async {
    final lastCollectionCreationTime =
        await _db.getLastCollectionCreationTime();
    var collections = await _fetchCollections(lastCollectionCreationTime ?? 0);
    await _db.insert(collections);
    collections = await _db.getAllCollections();
    for (final collection in collections) {
      _cacheCollectionAttributes(collection);
    }
  }

  Collection getCollectionForPath(String path) {
    return _localCollections[path];
  }

  List<Collection> getCollections() {
    return _collectionIDToCollections.values.toList();
  }

  Future<List<String>> getSharees(int collectionID) {
    return Dio()
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
      final emails = List<String>();
      for (final email in response.data["emails"]) {
        emails.add(email);
      }
      return emails;
    });
  }

  Future<void> share(int collectionID, String email, String publicKey) {
    final encryptedKey = CryptoUtil.sealSync(
        getCollectionKey(collectionID), Sodium.base642bin(publicKey));
    return Dio().post(
      Configuration.instance.getHttpEndpoint() + "/collections/share",
      data: {
        "collectionID": collectionID,
        "email": email,
        "encryptedKey": Sodium.bin2base64(encryptedKey),
      },
      options:
          Options(headers: {"X-Auth-Token": Configuration.instance.getToken()}),
    );
  }

  Uint8List getCollectionKey(int collectionID) {
    if (!_cachedKeys.containsKey(collectionID)) {
      final collection = _collectionIDToCollections[collectionID];
      var key;
      if (collection.ownerID == _config.getUserID()) {
        final encryptedKey = Sodium.base642bin(collection.encryptedKey);
        key = CryptoUtil.decryptSync(encryptedKey, _config.getKey(),
            Sodium.base642bin(collection.keyDecryptionNonce));
      } else {
        final encryptedKey = Sodium.base642bin(collection.encryptedKey);
        key = CryptoUtil.openSealSync(
            encryptedKey,
            Sodium.base642bin(_config.getKeyAttributes().publicKey),
            _config.getSecretKey());
      }
      _cachedKeys[collectionID] = key;
    }
    return _cachedKeys[collectionID];
  }

  Future<List<Collection>> _fetchCollections(int sinceTime) {
    return Dio()
        .get(
      Configuration.instance.getHttpEndpoint() + "/collections/",
      queryParameters: {
        "sinceTime": sinceTime,
      },
      options:
          Options(headers: {"X-Auth-Token": Configuration.instance.getToken()}),
    )
        .then((response) {
      final collections = List<Collection>();
      if (response != null) {
        final c = response.data["collections"];
        for (final collection in c) {
          collections.add(Collection.fromMap(collection));
        }
      }
      return collections;
    });
  }

  Collection getCollectionByID(int collectionID) {
    return _collectionIDToCollections[collectionID];
  }

  Future<Collection> createAlbum(String albumName) async {
    final key = CryptoUtil.generateKey();
    final encryptedKeyData = CryptoUtil.encryptSync(key, _config.getKey());
    final collection = await createAndCacheCollection(Collection(
      null,
      null,
      Sodium.bin2base64(encryptedKeyData.encryptedData),
      Sodium.bin2base64(encryptedKeyData.nonce),
      albumName,
      CollectionType.album,
      CollectionAttributes(),
      null,
    ));
    return collection;
  }

  Future<Collection> getOrCreateForPath(String path) async {
    if (_localCollections.containsKey(path)) {
      return _localCollections[path];
    }
    final key = CryptoUtil.generateKey();
    final encryptedKeyData = CryptoUtil.encryptSync(key, _config.getKey());
    final encryptedPath =
        CryptoUtil.encryptSync(utf8.encode(path), _config.getKey());
    final collection = await createAndCacheCollection(Collection(
      null,
      null,
      Sodium.bin2base64(encryptedKeyData.encryptedData),
      Sodium.bin2base64(encryptedKeyData.nonce),
      path,
      CollectionType.folder,
      CollectionAttributes(
          encryptedPath: Sodium.bin2base64(encryptedPath.encryptedData),
          pathDecryptionNonce: Sodium.bin2base64(encryptedPath.nonce)),
      null,
    ));
    return collection;
  }

  Future<void> addToCollection(int collectionID, List<File> files) {
    final params = Map<String, dynamic>();
    params["collectionID"] = collectionID;
    for (final file in files) {
      final key = decryptFileKey(file);
      file.collectionID = collectionID;
      final encryptedKeyData =
          CryptoUtil.encryptSync(key, getCollectionKey(collectionID));
      file.encryptedKey = Sodium.bin2base64(encryptedKeyData.encryptedData);
      file.keyDecryptionNonce = Sodium.bin2base64(encryptedKeyData.nonce);
      if (params["files"] == null) {
        params["files"] = [];
      }
      params["files"].add(CollectionFileItem(
              file.uploadedFileID, file.encryptedKey, file.keyDecryptionNonce)
          .toMap());
    }
    return Dio()
        .post(
      Configuration.instance.getHttpEndpoint() + "/collections/add-files",
      data: params,
      options:
          Options(headers: {"X-Auth-Token": Configuration.instance.getToken()}),
    )
        .then((value) async {
      await FilesDB.instance.insertMultiple(files);
      Bus.instance.fire(CollectionUpdatedEvent(collectionID));
    });
  }

  Future<void> removeFromCollection(int collectionID, List<File> files) async {
    final params = Map<String, dynamic>();
    params["collectionID"] = collectionID;
    for (final file in files) {
      if (params["fileIDs"] == null) {
        params["fileIDs"] = [];
      }
      params["fileIDs"].add(file.uploadedFileID);
    }
    await Dio().post(
      Configuration.instance.getHttpEndpoint() + "/collections/remove-files",
      data: params,
      options:
          Options(headers: {"X-Auth-Token": Configuration.instance.getToken()}),
    );
    await FilesDB.instance
        .removeFromCollection(collectionID, params["fileIDs"]);
    Bus.instance.fire(CollectionUpdatedEvent(collectionID));
  }

  Future<Collection> createAndCacheCollection(Collection collection) async {
    return Dio()
        .post(
      Configuration.instance.getHttpEndpoint() + "/collections/",
      data: collection.toMap(),
      options:
          Options(headers: {"X-Auth-Token": Configuration.instance.getToken()}),
    )
        .then((response) {
      final collection = Collection.fromMap(response.data["collection"]);
      _cacheCollectionAttributes(collection);
      return collection;
    });
  }

  void _cacheCollectionAttributes(Collection collection) {
    if (collection.attributes.encryptedPath != null) {
      _localCollections[decryptCollectionPath(collection)] = collection;
    }
    _collectionIDToCollections[collection.id] = collection;
  }

  String decryptCollectionPath(Collection collection) {
    return utf8.decode(CryptoUtil.decryptSync(
        Sodium.base642bin(collection.attributes.encryptedPath),
        _config.getKey(),
        Sodium.base642bin(collection.attributes.pathDecryptionNonce)));
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
    int collectionID,
    List<CollectionFileItem> files,
  }) {
    return AddFilesRequest(
      collectionID ?? this.collectionID,
      files ?? this.files,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'collectionID': collectionID,
      'files': files?.map((x) => x?.toMap())?.toList(),
    };
  }

  factory AddFilesRequest.fromMap(Map<String, dynamic> map) {
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
