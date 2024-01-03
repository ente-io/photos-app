import 'dart:async';
import "dart:math";
import "dart:typed_data";

import "package:flutter/foundation.dart";
import 'package:logging/logging.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:photos/face/db_fields.dart';
import "package:photos/face/db_model_mappers.dart";
import "package:photos/face/model/face.dart";
import "package:photos/face/model/person.dart";
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
    await db.execute(createPersonClusterTable);
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

  Future<Set<int>> getIndexedFileIds() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT $fileIDColumn FROM $facesTable',
    );
    return maps.map((e) => e[fileIDColumn] as int).toSet();
  }

  Future<Map<int, int>> getFileIdToCount() async {
    final Map<int, int> result = {};
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT $fileIDColumn, COUNT(*) as count FROM $facesTable where $faceScore > 0.8 GROUP BY $fileIDColumn',
    );

    for (final map in maps) {
      result[map[fileIDColumn] as int] = map['count'] as int;
    }
    return result;
  }

  Future<Map<int, Set<int>>> getFileIdToPersonIDs() async {
    final Map<int, Set<int>> result = {};
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT $faceClusterId, $fileIDColumn FROM $facesTable where $faceClusterId IS NOT NULL',
    );

    for (final map in maps) {
      final personID = map[faceClusterId] as int;
      final fileID = map[fileIDColumn] as int;
      result[fileID] = (result[fileID] ?? {})..add(personID);
    }
    return result;
  }

  Future<void> updatePersonIDForFaceIDIFNotSet(
    Map<String, int> faceIDToPersonID,
  ) async {
    final db = await instance.database;

    // Start a batch
    final batch = db.batch();

    for (final map in faceIDToPersonID.entries) {
      final faceID = map.key;
      final personID = map.value;
      batch.update(
        facesTable,
        {faceClusterId: personID},
        where: '$faceIDColumn = ? AND $faceClusterId IS NULL',
        whereArgs: [faceID],
      );
    }
    // Commit the batch
    await batch.commit(noResult: true);
  }

  // Get face_id to embedding map. only select face_id and embedding columns
  // where score is greater than 0.
  Future<Map<String, Uint8List>> getFaceEmbeddingMap({
    double minScore = 0.8,
    int maxRows = 20000,
  }) async {
    _logger.info('reading as float');
    final db = await instance.database;

    // Define the batch size
    const batchSize = 10000;
    int offset = 0;

    final Map<String, Uint8List> result = {};
    while (true) {
      // Query a batch of rows
      final List<Map<String, dynamic>> maps = await db.query(
        facesTable,
        columns: [faceIDColumn, faceEmbeddingBlob],
        where: '$faceScore > $minScore',
        limit: batchSize,
        offset: offset,
        orderBy: '$faceIDColumn DESC',
      );
      // Break the loop if no more rows
      if (maps.isEmpty) {
        break;
      }
      for (final map in maps) {
        final faceID = map[faceIDColumn] as String;
        result[faceID] = map[faceEmbeddingBlob] as Uint8List;
      }
      if (result.length >= 20000) {
        break;
      }
      offset += batchSize;
    }
    return result;
  }

  Future<Map<String, Uint8List>> getFaceEmbeddingMapForFile(
    List<int> fileIDs,
  ) async {
    _logger.info('reading as float');
    final db = await instance.database;

    // Define the batch size
    const batchSize = 10000;
    int offset = 0;

    final Map<String, Uint8List> result = {};
    while (true) {
      // Query a batch of rows
      final List<Map<String, dynamic>> maps = await db.query(
        facesTable,
        columns: [faceIDColumn, faceEmbeddingBlob],
        where: '$faceScore > 0.8 AND $fileIDColumn IN (${fileIDs.join(",")})',
        limit: batchSize,
        offset: offset,
        orderBy: '$faceIDColumn DESC',
      );
      // Break the loop if no more rows
      if (maps.isEmpty) {
        break;
      }
      for (final map in maps) {
        final faceID = map[faceIDColumn] as String;
        result[faceID] = map[faceEmbeddingBlob] as Uint8List;
      }
      if (result.length > 10000) {
        break;
      }
      offset += batchSize;
    }
    return result;
  }

  Future<void> resetClusterIDs() async {
    final db = await instance.database;
    await db.update(
      facesTable,
      {faceClusterId: null},
    );
  }

  Future<void> insert(Person p, int cluserID) async {
    debugPrint("inserting person");
    final db = await instance.database;
    await db.insert(
      peopleTable,
      mapPersonToRow(p),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      personToClusterIDTable,
      {
        personToClusterIDPersonIDColumn: p.remoteID,
        cluserIDColumn: cluserID,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint("person inserted");
  }

  Future<void> assignClusterToPerson({
    required String personID,
    required int clusterID,
  }) async {
    final db = await instance.database;
    await db.insert(
      personToClusterIDTable,
      {
        personToClusterIDPersonIDColumn: personID,
        cluserIDColumn: clusterID,
      },
    );
  }

  // for a given personID, return a map of clusterID to fileIDs using join query
  Future<Map<int, Set<int>>> getFileIdToClusterIDSet(String personID) {
    final db = instance.database;
    return db.then((db) async {
      final List<Map<String, dynamic>> maps = await db.rawQuery(
        'SELECT $cluserIDColumn, $fileIDColumn FROM $facesTable '
        'INNER JOIN $personToClusterIDTable '
        'ON $facesTable.$faceClusterId = $personToClusterIDTable.$cluserIDColumn '
        'WHERE $personToClusterIDTable.$personToClusterIDPersonIDColumn = ?',
        [personID],
      );
      final Map<int, Set<int>> result = {};
      for (final map in maps) {
        final clusterID = map[cluserIDColumn] as int;
        final fileID = map[fileIDColumn] as int;
        result[fileID] = (result[fileID] ?? {})..add(clusterID);
      }
      return result;
    });
  }

  Future<Map<int, String>> getCluserIDToPersonMap() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT $personToClusterIDPersonIDColumn, $cluserIDColumn FROM $personToClusterIDTable',
    );
    final Map<int, String> result = {};
    for (final map in maps) {
      result[map[cluserIDColumn] as int] =
          map[personToClusterIDPersonIDColumn] as String;
    }
    return result;
  }

  Future<(Map<int, Person>, Map<String, Person>)> getClusterIdToPerson() async {
    final db = await instance.database;
    final Map<String, Person> peopleMap = await getPeopleMap();
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT $personToClusterIDPersonIDColumn, $cluserIDColumn FROM $personToClusterIDTable',
    );

    final Map<int, Person> result = {};
    for (final map in maps) {
      final Person? p =
          peopleMap[map[personToClusterIDPersonIDColumn] as String];
      if (p != null) {
        result[map[cluserIDColumn] as int] = p!;
      } else {
        _logger.warning(
          'Person with id ${map[personToClusterIDPersonIDColumn]} not found',
        );
      }
    }
    return (result, peopleMap);
  }

  Future<Map<String, Person>> getPeopleMap() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      peopleTable,
      columns: [
        idColumn,
        nameColumn,
        personHiddenColumn,
        clusterToFaceIdJson,
        coverFaceIDColumn,
      ],
    );
    final Map<String, Person> result = {};
    for (final map in maps) {
      result[map[idColumn] as String] = mapRowToPerson(map);
    }
    return result;
  }

  Future<List<Person>> getPeople() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      peopleTable,
      columns: [
        idColumn,
        nameColumn,
        personHiddenColumn,
        clusterToFaceIdJson,
        coverFaceIDColumn,
      ],
    );
    return maps.map((map) => mapRowToPerson(map)).toList();
  }

  /// WARNING: This will delete ALL data in the database! Only use this for debug/testing purposes!
  Future<void> dropClustersAndPeople({bool faces = false}) async {
    final db = await instance.database;
    if (faces) {
      await db.execute(deleteFacesTable);
      await db.execute(createFacesTable);
    }
    await db.execute(deletePeopleTable);
    await db.execute(dropPersonClusterTable);

    // await db.execute(createFacesTable);
    await db.execute(createPeopleTable);
    await db.execute(createPersonClusterTable);
  }
}
