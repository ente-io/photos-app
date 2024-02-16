import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import "package:photos/core/configuration.dart";
import "package:photos/core/network/network.dart";
import "package:photos/db/entities_db.dart";
import "package:photos/db/files_db.dart";
import "package:photos/gateways/entity_gw.dart";
import "package:photos/models/api/entity/data.dart";
import "package:photos/models/api/entity/key.dart";
import "package:photos/models/api/entity/type.dart";
import "package:photos/models/local_entity_data.dart";
import "package:photos/utils/crypto_util.dart";
import 'package:shared_preferences/shared_preferences.dart';

class EntityService {
  static const int fetchLimit = 500;
  final _logger = Logger((EntityService).toString());
  final _config = Configuration.instance;
  late SharedPreferences _prefs;
  late EntityGateway _gateway;
  late FilesDB _db;

  EntityService._privateConstructor();

  static final EntityService instance = EntityService._privateConstructor();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _db = FilesDB.instance;
    _gateway = EntityGateway(NetworkClient.instance.enteDio);
  }

  String _getEntityKeyPrefix(EntityType type) {
    return "entity_key_" + type.typeToString();
  }

  String _getEntityHeaderPrefix(EntityType type) {
    return "entity_key_header_" + type.typeToString();
  }

  String _getEntityLastSyncTimePrefix(EntityType type) {
    return "entity_last_sync_time_" + type.typeToString();
  }

  Future<List<LocalEntityData>> getEntities(EntityType type) async {
    return await _db.getEntities(type);
  }

  Future<LocalEntityData> addOrUpdate(
    EntityType type,
    String plainText, {
    String? id,
  }) async {
    final key = await getOrCreateEntityKey(type);
    final encryptedKeyData = await CryptoUtil.encryptChaCha(
      utf8.encode(plainText) as Uint8List,
      key,
    );
    final String encryptedData =
        CryptoUtil.bin2base64(encryptedKeyData.encryptedData!);
    final String header = CryptoUtil.bin2base64(encryptedKeyData.header!);
    debugPrint("Adding entity of type: " + type.typeToString());
    final EntityData data = id == null
        ? await _gateway.createEntity(type, encryptedData, header)
        : await _gateway.updateEntity(type, id, encryptedData, header);
    final LocalEntityData localData = LocalEntityData(
      id: data.id,
      type: type,
      data: plainText,
      ownerID: data.userID,
      updatedAt: data.updatedAt,
    );
    await _db.upsertEntities([localData]);
    syncEntities().ignore();
    return localData;
  }

  Future<void> deleteEntry(String id) async {
    await _gateway.deleteEntity(id);
    await _db.deleteEntities([id]);
  }

  Future<void> syncEntities() async {
    try {
      await _remoteToLocalSync(EntityType.location);
    } catch (e) {
      _logger.severe("Failed to sync entities", e);
    }
  }

  Future<void> _remoteToLocalSync(EntityType type) async {
    final int lastSyncTime =
        _prefs.getInt(_getEntityLastSyncTimePrefix(type)) ?? 0;
    final List<EntityData> result = await _gateway.getDiff(
      type,
      lastSyncTime,
      limit: fetchLimit,
    );
    if (result.isEmpty) {
      debugPrint("No $type entries to sync");
      return;
    }
    final bool hasMoreItems = result.length == fetchLimit;
    _logger.info("${result.length} entries of type $type fetched");
    final maxSyncTime = result.map((e) => e.updatedAt).reduce(max);
    final List<String> deletedIDs =
        result.where((element) => element.isDeleted).map((e) => e.id).toList();
    if (deletedIDs.isNotEmpty) {
      _logger.info("${deletedIDs.length} entries of type $type deleted");
      await _db.deleteEntities(deletedIDs);
    }
    result.removeWhere((element) => element.isDeleted);
    if (result.isNotEmpty) {
      final entityKey = await getOrCreateEntityKey(type);
      final List<LocalEntityData> entities = [];
      for (EntityData e in result) {
        try {
          final decryptedValue = await CryptoUtil.decryptChaCha(
            CryptoUtil.base642bin(e.encryptedData!),
            entityKey,
            CryptoUtil.base642bin(e.header!),
          );
          final String plainText = utf8.decode(decryptedValue);
          entities.add(
            LocalEntityData(
              id: e.id,
              type: type,
              data: plainText,
              ownerID: e.userID,
              updatedAt: e.updatedAt,
            ),
          );
        } catch (e, s) {
          _logger.severe("Failed to decrypted data for key $type", e, s);
        }
      }
      if (entities.isNotEmpty) {
        await _db.upsertEntities(entities);
      }
    }
    await _prefs.setInt(_getEntityLastSyncTimePrefix(type), maxSyncTime);
    if (hasMoreItems) {
      _logger.info("Diff limit reached, pulling again");
      await _remoteToLocalSync(type);
    }
  }

  Future<Uint8List> getOrCreateEntityKey(EntityType type) async {
    late String encryptedKey;
    late String header;
    try {
      if (_prefs.containsKey(_getEntityKeyPrefix(type)) &&
          _prefs.containsKey(_getEntityHeaderPrefix(type))) {
        encryptedKey = _prefs.getString(_getEntityKeyPrefix(type))!;
        header = _prefs.getString(_getEntityHeaderPrefix(type))!;
      } else {
        final EntityKey response = await _gateway.getKey(type);
        encryptedKey = response.encryptedKey;
        header = response.header;
        await _prefs.setString(_getEntityKeyPrefix(type), encryptedKey);
        await _prefs.setString(_getEntityHeaderPrefix(type), header);
      }
      final entityKey = CryptoUtil.decryptSync(
        CryptoUtil.base642bin(encryptedKey),
        _config.getKey()!,
        CryptoUtil.base642bin(header),
      );
      return entityKey;
    } on EntityKeyNotFound {
      _logger.info("EntityKeyNotFound generating key for type $type");
      final key = CryptoUtil.generateKey();
      final encryptedKeyData = CryptoUtil.encryptSync(key, _config.getKey()!);
      encryptedKey = CryptoUtil.bin2base64(encryptedKeyData.encryptedData!);
      header = CryptoUtil.bin2base64(encryptedKeyData.nonce!);
      await _gateway.createKey(type, encryptedKey, header);
      await _prefs.setString(_getEntityKeyPrefix(type), encryptedKey);
      await _prefs.setString(_getEntityHeaderPrefix(type), header);
      return key;
    } catch (e, s) {
      _logger.severe("Failed to getOrCreateKey for type $type", e, s);
      rethrow;
    }
  }
}
