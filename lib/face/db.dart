import 'dart:async';
import "dart:math";
import "dart:typed_data";

import 'package:logging/logging.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:photos/face/db_fields.dart';
import "package:photos/face/db_model_mappers.dart";
import "package:photos/face/model/face.dart";
import "package:photos/generated/protos/ente/common/vector.pb.dart";
import 'package:sqflite/sqflite.dart';

/// Stores all data for the ML-related features. The database can be accessed by `MlDataDB.instance.database`.
///
/// This includes:
/// [facesTable] - Stores all the detected faces and its embeddings in the images.
/// [peopleTable] - Stores all the clusters of faces which are considered to be the same person.
class FaceMLDataDB {
  static final Logger _logger = Logger("FaceMLDataDB");

  static const _databaseName = "ente.face_ml_db.db";
  static const _databaseVersion = 1;

  FaceMLDataDB._privateConstructor();

  static final FaceMLDataDB instance = FaceMLDataDB._privateConstructor();

  static Future<Database>? _dbFuture;

  Future<Database> get database async {
    _dbFuture ??= _initDatabase();
    return _dbFuture!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final String databaseDirectory =
        join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      databaseDirectory,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute(createFacesTable);
    await db.execute(createPeopleTable);
  }

  // bulkInsertFaces inserts the faces in the database in batches of 1000.
  // This is done to avoid the error "too many SQL variables" when inserting
  // a large number of faces.
  Future<void> bulkInsertFaces(List<Face> faces) async {
    final db = await instance.database;
    const batchSize = 500;
    final numBatches = (faces.length / batchSize).ceil();
    for (int i = 0; i < numBatches; i++) {
      final start = i * batchSize;
      final end = min((i + 1) * batchSize, faces.length);
      final batch = faces.sublist(start, end);
      final batchInsert = db.batch();
      for (final face in batch) {
        batchInsert.insert(
          facesTable,
          mapRemoteToFaceDB(face),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batchInsert.commit(noResult: true);
    }
  }

  // Get face_id to embedding map. only select face_id and embedding columns
  Future<Map<String, EVector>> getFaceEmbeddingMap() async {
    _logger.info('reading as float');
    final db = await instance.database;

    // Define the batch size
    const batchSize = 10000;
    int offset = 0;

    final Map<String, EVector> result = {};

    while (true) {
      // Query a batch of rows
      final List<Map<String, dynamic>> maps = await db.query(
        facesTable,
        columns: [faceIDColumn, faceEmbeddingBlob],
        limit: batchSize,
        offset: offset,
      );
      // Break the loop if no more rows
      if (maps.isEmpty) {
        break;
      }
      for (final map in maps) {
        final faceID = map[faceIDColumn] as String;
        final embeddingList =
            EVector.fromBuffer(map[faceEmbeddingBlob] as Uint8List);
        result[faceID] = embeddingList;
      }

      // Increase the offset for the next batch
      offset += batchSize;
    }

    return result;
  }

  // // Get face_id to embedding map. only select face_id and embedding columns
  // Future<Map<String, Detection>> getFaceEmbeddingStrMap() async {
  //   _logger.info('reading as string');
  //   final db = await instance.database;
  //   final List<Map<String, dynamic>> maps = await db.query(
  //     facesTable,
  //     columns: [faceIDColumn, faceDetectionColumn],
  //   );
  //   final Map<String, Detection> result = {};
  //   for (final map in maps) {
  //     final faceID = map[faceIDColumn] as String;
  //     final embedding =
  //         Detection.fromJson(jsonDecode(map[faceDetectionColumn]));
  //     result[faceID] = embedding;
  //   }
  //   return result;
  // }

  /// WARNING: This will delete ALL data in the database! Only use this for debug/testing purposes!
  Future<void> cleanTables() async {
    _logger.fine('`cleanTables()` called');
    final db = await instance.database;
    await db.execute(deleteFacesTable);
    await db.execute(deletePeopleTable);

    await db.execute(createFacesTable);
    await db.execute(createPeopleTable);
  }
}
