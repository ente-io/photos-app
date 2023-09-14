import 'dart:async';

import 'package:logging/logging.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import "package:photos/models/ml_typedefs.dart";
import "package:photos/services/face_ml/face_ml_result.dart";
import 'package:sqflite/sqflite.dart';

/// Stores all data for the ML-related features. The database can be accessed by `MlDataDB.instance.database`.
///
/// This includes:
/// [facesTable] - Stores all the detected faces and its embeddings in the images.
/// [peopleTable] - Stores all the clusters of faces which are considered to be the same person.
class MlDataDB {
  static final Logger _logger = Logger("MlDataDB");

  // TODO: [BOB] put the db in files
  static const _databaseName = "ente.ml_data.db";
  static const _databaseVersion = 1;

  static const facesTable = 'faces';
  static const fileIDColumn = 'file_id';
  static const faceMlResultColumn = 'face_ml_result';
  static const mlVersionColumn = 'ml_version';

  static const peopleTable = 'people';
  static const personIDColumn = 'person_id';
  static const clusterResultColumn = 'cluster_result';
  static const centroidColumn = 'cluster_centroid';
  static const centroidDistanceThresholdColumn = 'centroid_distance_threshold';

  static const createFacesTable = '''CREATE TABLE IF NOT EXISTS $facesTable (
  $fileIDColumn	INTEGER NOT NULL UNIQUE,
	$faceMlResultColumn	TEXT NOT NULL,
  $mlVersionColumn	INTEGER NOT NULL,
  PRIMARY KEY($fileIDColumn)
  );
  ''';
  static const createPeopleTable = '''CREATE TABLE IF NOT EXISTS $peopleTable (
  $personIDColumn	INTEGER NOT NULL UNIQUE,
	$clusterResultColumn	TEXT NOT NULL,
  $centroidColumn	TEXT NOT NULL,
  $centroidDistanceThresholdColumn	REAL NOT NULL,
	PRIMARY KEY($personIDColumn AUTOINCREMENT)
  );
  ''';
  static const _deleteFacesTable = 'DROP TABLE IF EXISTS $facesTable';
  static const _deletePeopleTable = 'DROP TABLE IF EXISTS $peopleTable';

  MlDataDB._privateConstructor();
  static final MlDataDB instance = MlDataDB._privateConstructor();

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

  /// WARNING: This will delete ALL data in the database! Only use this for debug/testing purposes!
  Future<void> cleanTables({
    bool cleanFaces = false,
    bool cleanPeople = false,
  }) async {
    _logger.fine('`cleanTables()` called');
    final db = await instance.database;

    if (cleanFaces) {
      _logger.fine('`cleanTables()`: Cleaning faces table');
      await db.execute(_deleteFacesTable);
    }

    if (cleanPeople) {
      _logger.fine('`cleanTables()`: Cleaning people table');
      await db.execute(_deletePeopleTable);
    }

    if (!cleanFaces && !cleanPeople) {
      _logger.fine(
        '`cleanTables()`: No tables cleaned, since no table was specified. Please be careful with this function!',
      );
    }

    await db.execute(createFacesTable);
    await db.execute(createPeopleTable);
  }

  Future<void> createFaceMlResult(FaceMlResult faceMlResult) async {
    _logger.fine('createFaceMlResult called');

    final existingResult = await getFaceMlResult(faceMlResult.fileId);
    if (existingResult != null) {
      if (faceMlResult.mlVersion <= existingResult.mlVersion) {
        _logger.fine(
          'FaceMlResult with file ID ${faceMlResult.fileId} already exists with equal or higher version. Skipping insert.',
        );
        return;
      }
    }

    final db = await instance.database;
    await db.insert(
      facesTable,
      {
        fileIDColumn: faceMlResult.fileId,
        faceMlResultColumn: faceMlResult.toJsonString(),
        mlVersionColumn: faceMlResult.mlVersion,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> doesFaceMlResultExist(int fileId, {int? mlVersion}) async {
    _logger.fine('doesFaceMlResultExist called');
    final db = await instance.database;

    String whereString = '$fileIDColumn = ?';
    final List<dynamic> whereArgs = [fileId];

    if (mlVersion != null) {
      whereString += ' AND $mlVersionColumn = ?';
      whereArgs.add(mlVersion);
    }

    final result = await db.query(
      facesTable,
      where: whereString,
      whereArgs: whereArgs,
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<FaceMlResult?> getFaceMlResult(int fileId, {int? mlVersion}) async {
    _logger.fine('getFaceMlResult called');
    final db = await instance.database;

    String whereString = '$fileIDColumn = ?';
    final List<dynamic> whereArgs = [fileId];

    if (mlVersion != null) {
      whereString += ' AND $mlVersionColumn = ?';
      whereArgs.add(mlVersion);
    }

    final result = await db.query(
      facesTable,
      where: whereString,
      whereArgs: whereArgs,
      limit: 1,
    );
    if (result.isNotEmpty) {
      return FaceMlResult.fromJsonString(
        result.first[faceMlResultColumn] as String,
      );
    }
    _logger.fine(
      'No faceMlResult found for fileID $fileId and mlVersion $mlVersion (null if not specified)',
    );
    return null;
  }

  Future<List<FaceMlResult>?> getSelectedFaceMlResults(
    List<int> fileIds,
  ) async {
    _logger.fine('getSelectedFaceMlResults called');
    final db = await instance.database;

    final List<Map<String, Object?>> results = await db.query(
      facesTable,
      columns: [faceMlResultColumn],
      where: '$fileIDColumn IN (${fileIds.join(',')})',
    );

    return results
        .map(
          (result) =>
              FaceMlResult.fromJsonString(result[faceMlResultColumn] as String),
        )
        .toList();
  }

  Future<List<FaceMlResult>> getAllFaceMlResults({int? mlVersion}) async {
    _logger.fine('getAllFaceMlResults called');
    final db = await instance.database;

    String? whereString;
    List<dynamic>? whereArgs;

    if (mlVersion != null) {
      whereString = '$mlVersionColumn = ?';
      whereArgs = [mlVersion];
    }

    final results = await db.query(
      facesTable,
      where: whereString,
      whereArgs: whereArgs,
    );

    return results
        .map(
          (result) =>
              FaceMlResult.fromJsonString(result[faceMlResultColumn] as String),
        )
        .toList();
  }

  /// getAllFileIDs returns a set of all fileIDs from the facesTable, meaning all the fileIDs for which a FaceMlResult exists, optionally filtered by mlVersion.
  Future<Set<int>> getAllFaceMlResultFileIDs({int? mlVersion}) async {
    _logger.fine('getAllFileIDs called');
    final db = await instance.database;

    String? whereString;
    List<dynamic>? whereArgs;

    if (mlVersion != null) {
      whereString = '$mlVersionColumn = ?';
      whereArgs = [mlVersion];
    }

    final List<Map<String, Object?>> results = await db.query(
      facesTable,
      where: whereString,
      whereArgs: whereArgs,
    );

    return results.map((result) => result[fileIDColumn] as int).toSet();
  }

  Future<void> updateFaceMlResult(FaceMlResult faceMlResult) async {
    _logger.fine('updateFaceMlResult called');
    final db = await instance.database;
    await db.update(
      facesTable,
      {
        fileIDColumn: faceMlResult.fileId,
        faceMlResultColumn: faceMlResult.toJsonString(),
        mlVersionColumn: faceMlResult.mlVersion,
      },
      where: '$fileIDColumn = ?',
      whereArgs: [faceMlResult.fileId],
    );
  }

  Future<int> deleteFaceMlResult(int fileId) async {
    _logger.fine('deleteFaceMlResult called');
    final db = await instance.database;
    final deleteCount = await db.delete(
      facesTable,
      where: '$fileIDColumn = ?',
      whereArgs: [fileId],
    );
    _logger.fine('Deleted $deleteCount faceMlResults');
    return deleteCount;
  }

  Future<void> createAllClusterResults(
    List<ClusterResult> clusterResults, {
    bool cleanExistingClusters = true,
  }) async {
    _logger.fine('createClusterResults called');
    final db = await instance.database;

    // Completely clean the table and start fresh
    if (cleanExistingClusters) {
      await deleteAllClusterResults();
    }

    // Insert all the cluster results
    for (final clusterResult in clusterResults) {
      await db.insert(
        peopleTable,
        {
          personIDColumn: clusterResult.personId,
          clusterResultColumn: clusterResult.toJsonString(),
          centroidColumn: clusterResult.centroid.toString(),
          centroidDistanceThresholdColumn:
              clusterResult.centroidDistanceThreshold,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<ClusterResult?> getClusterResult(int personId) async {
    _logger.fine('getClusterResult called');
    final db = await instance.database;

    final result = await db.query(
      peopleTable,
      where: '$personIDColumn = ?',
      whereArgs: [personId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return ClusterResult.fromJsonString(
        result.first[clusterResultColumn] as String,
      );
    }
    _logger.fine('No clusterResult found for personID $personId');
    return null;
  }

  Future<List<ClusterResult>> getAllClusterResults() async {
    _logger.fine('getAllClusterResults called');
    final db = await instance.database;

    final results = await db.query(
      peopleTable,
    );

    return results
        .map(
          (result) => ClusterResult.fromJsonString(
            result[clusterResultColumn] as String,
          ),
        )
        .toList();
  }

  Future<List<int>?> getClusterFileIds(int personId) async {
    _logger.fine('getClusterFileIds called');

    final ClusterResult? clusterResult = await getClusterResult(personId);
    if (clusterResult == null) {
      return null;
    }
    return clusterResult.uniqueFileIds;
  }

  Future<List<String>?> getClusterFaceIds(int personId) async {
    _logger.fine('getClusterFaceIds called');

    final ClusterResult? clusterResult = await getClusterResult(personId);
    if (clusterResult == null) {
      return null;
    }
    return clusterResult.uniqueFaceIds;
  }

  Future<List<Embedding>?> getClusterEmbeddings(
    int personId,
  ) async {
    _logger.fine('getClusterEmbeddings called');

    final ClusterResult? clusterResult = await getClusterResult(personId);
    if (clusterResult == null) return null;

    final fileIds = clusterResult.uniqueFileIds;
    final faceIds = clusterResult.uniqueFaceIds;
    if (fileIds.length != faceIds.length) {
      _logger.severe(
        'fileIds and faceIds have different lengths: ${fileIds.length} vs ${faceIds.length}. This should not happen!',
      );
      return null;
    }

    final faceMlResults = await getSelectedFaceMlResults(fileIds);
    if (faceMlResults == null) return null;

    final embeddings = <Embedding>[];
    for (var i = 0; i < faceMlResults.length; i++) {
      final faceMlResult = faceMlResults[i];
      final int faceIndex = faceMlResult.allFaceIds.indexOf(faceIds[i]);
      if (faceIndex == -1) {
        _logger.severe(
          'Could not find faceIndex for faceId ${faceIds[i]} in faceMlResult ${faceMlResult.fileId}',
        );
        return null;
      }
      embeddings.add(faceMlResult.faces[faceIndex].embedding);
    }

    return embeddings;
  }

  Future<void> updateClusterResult(ClusterResult clusterResult) async {
    _logger.fine('updateClusterResult called');
    final db = await instance.database;
    await db.update(
      peopleTable,
      {
        personIDColumn: clusterResult.personId,
        clusterResultColumn: clusterResult.toJsonString(),
        centroidColumn: clusterResult.centroid.toString(),
        centroidDistanceThresholdColumn:
            clusterResult.centroidDistanceThreshold,
      },
      where: '$personIDColumn = ?',
      whereArgs: [clusterResult.personId],
    );
  }

  Future<int> deleteClusterResult(int personId) async {
    _logger.fine('deleteClusterResult called');
    final db = await instance.database;
    final deleteCount = await db.delete(
      peopleTable,
      where: '$personIDColumn = ?',
      whereArgs: [personId],
    );
    _logger.fine('Deleted $deleteCount clusterResults');
    return deleteCount;
  }

  Future<void> deleteAllClusterResults() async {
    _logger.fine('deleteAllClusterResults called');
    final db = await instance.database;
    await db.execute(_deletePeopleTable);
    await db.execute(createPeopleTable);
  }
}
