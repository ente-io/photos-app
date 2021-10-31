import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_sodium/flutter_sodium.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/core/network.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/events/files_updated_event.dart';
import 'package:photos/events/force_reload_home_gallery_event.dart';
import 'package:photos/events/local_photos_updated_event.dart';
import 'package:photos/models/file.dart';
import 'package:photos/models/magic_metadata.dart';
import 'package:photos/services/remote_sync_service.dart';
import 'package:photos/utils/crypto_util.dart';
import 'package:photos/utils/file_download_util.dart';

class FileMagicService {
  final _logger = Logger("FileMagicService");
  late Dio _dio;
  late FilesDB _filesDB;

  FileMagicService._privateConstructor() {
    _filesDB = FilesDB.instance;
    _dio = Network.instance.getDio();
  }

  static final FileMagicService instance =
      FileMagicService._privateConstructor();

  Future<void> changeVisibility(List<File> files, int visibility) async {
    Map<String, dynamic> update = {kMagicKeyVisibility: visibility};
    await _updateMagicData(files, update);
    if (visibility == kVisibilityVisible) {
      // Force reload home gallery to pull in the now unarchived files
      Bus.instance.fire(ForceReloadHomeGalleryEvent());
      Bus.instance
          .fire(LocalPhotosUpdatedEvent(files, type: EventType.unarchived));
    } else {
      Bus.instance
          .fire(LocalPhotosUpdatedEvent(files, type: EventType.archived));
    }
  }

  Future<void> updatePublicMagicMetadata(
      List<File> files, Map<String, dynamic> newMetadataUpdate) async {
    final params = <String, dynamic>{};
    params['metadataList'] = [];
    final int? ownerID = Configuration.instance.getUserID();
    try {
      for (final file in files) {
        if (file.uploadedFileID == null) {
          throw AssertionError(
              "operation is only supported on backed up files");
        } else if (file.ownerID != ownerID) {
          throw AssertionError("cannot modify memories not owned by you");
        }
        // read the existing magic metadata and apply new updates to existing data
        // current update is simple replace. This will be enhanced in the future,
        // as required.
        Map<String, dynamic> jsonToUpdate = jsonDecode(file.pubMmdEncodedJson!);
        newMetadataUpdate.forEach((key, value) {
          jsonToUpdate[key] = value;
        });

        // update the local information so that it's reflected on UI
        file.pubMmdEncodedJson = jsonEncode(jsonToUpdate);
        file.pubMagicMetadata = PubMagicMetadata.fromJson(jsonToUpdate);

        final fileKey = decryptFileKey(file);
        final encryptedMMd = await CryptoUtil.encryptChaCha(
            utf8.encode(jsonEncode(jsonToUpdate)) as Uint8List?, fileKey);
        params['metadataList'].add(UpdateMagicMetadataRequest(
            id: file.uploadedFileID,
            magicMetadata: MetadataRequest(
              version: file.pubMmdVersion,
              count: jsonToUpdate.length,
              data: Sodium.bin2base64(encryptedMMd.encryptedData!),
              header: Sodium.bin2base64(encryptedMMd.header!),
            )));
        file.pubMmdVersion = file.pubMmdVersion! + 1;
      }

      await _dio.put(
        Configuration.instance.getHttpEndpoint() +
            "/files/public-magic-metadata",
        data: params,
        options: Options(
            headers: {"X-Auth-Token": Configuration.instance.getToken()}),
      );
      // update the state of the selected file. Same file in other collection
      // should be eventually synced after remote sync has completed
      await _filesDB.insertMultiple(files);
      RemoteSyncService.instance.sync(silently: true);
    } on DioError catch (e) {
      if (e.response != null && e.response!.statusCode == 409) {
        RemoteSyncService.instance.sync(silently: true);
      }
      rethrow;
    } catch (e, s) {
      _logger.severe("failed to sync magic metadata", e, s);
      rethrow;
    }
  }

  Future<void> _updateMagicData(
      List<File> files, Map<String, dynamic> newMetadataUpdate) async {
    final params = <String, dynamic>{};
    params['metadataList'] = [];
    final int? ownerID = Configuration.instance.getUserID();
    try {
      for (final file in files) {
        if (file.uploadedFileID == null) {
          throw AssertionError(
              "operation is only supported on backed up files");
        } else if (file.ownerID != ownerID) {
          throw AssertionError("cannot modify memories not owned by you");
        }
        // read the existing magic metadata and apply new updates to existing data
        // current update is simple replace. This will be enhanced in the future,
        // as required.
        Map<String, dynamic> jsonToUpdate = jsonDecode(file.mMdEncodedJson!);
        newMetadataUpdate.forEach((key, value) {
          jsonToUpdate[key] = value;
        });

        // update the local information so that it's reflected on UI
        file.mMdEncodedJson = jsonEncode(jsonToUpdate);
        file.magicMetadata = MagicMetadata.fromJson(jsonToUpdate);

        final fileKey = decryptFileKey(file);
        final encryptedMMd = await CryptoUtil.encryptChaCha(
            utf8.encode(jsonEncode(jsonToUpdate)) as Uint8List?, fileKey);
        params['metadataList'].add(UpdateMagicMetadataRequest(
            id: file.uploadedFileID,
            magicMetadata: MetadataRequest(
              version: file.mMdVersion,
              count: jsonToUpdate.length,
              data: Sodium.bin2base64(encryptedMMd.encryptedData!),
              header: Sodium.bin2base64(encryptedMMd.header!),
            )));
        file.mMdVersion = file.mMdVersion! + 1;
      }

      await _dio.put(
        Configuration.instance.getHttpEndpoint() + "/files/magic-metadata",
        data: params,
        options: Options(
            headers: {"X-Auth-Token": Configuration.instance.getToken()}),
      );
      // update the state of the selected file. Same file in other collection
      // should be eventually synced after remote sync has completed
      await _filesDB.insertMultiple(files);
      RemoteSyncService.instance.sync(silently: true);
    } on DioError catch (e) {
      if (e.response != null && e.response!.statusCode == 409) {
        RemoteSyncService.instance.sync(silently: true);
      }
      rethrow;
    } catch (e, s) {
      _logger.severe("failed to sync magic metadata", e, s);
      rethrow;
    }
  }
}

class UpdateMagicMetadataRequest {
  final int? id;
  final MetadataRequest? magicMetadata;

  UpdateMagicMetadataRequest({this.id, this.magicMetadata});

  factory UpdateMagicMetadataRequest.fromJson(dynamic json) {
    return UpdateMagicMetadataRequest(
        id: json['id'],
        magicMetadata: json['magicMetadata'] != null
            ? MetadataRequest.fromJson(json['magicMetadata'])
            : null);
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    if (magicMetadata != null) {
      map['magicMetadata'] = magicMetadata!.toJson();
    }
    return map;
  }
}

class MetadataRequest {
  int? version;
  int? count;
  String? data;
  String? header;

  MetadataRequest({this.version, this.count, this.data, this.header});

  MetadataRequest.fromJson(dynamic json) {
    version = json['version'];
    count = json['count'];
    data = json['data'];
    header = json['header'];
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    map['version'] = version;
    map['count'] = count;
    map['data'] = data;
    map['header'] = header;
    return map;
  }
}
