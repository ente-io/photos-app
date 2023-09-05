import 'dart:async';

import 'package:logging/logging.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import "package:photos/services/face_ml/face_ml_result.dart";
import 'package:sqflite/sqflite.dart';

/// Stores all data for the ML-related features. The database can be accessed by `MlDataDB.instance.database`.
///
/// This includes:
/// [facesTable] - Stores all the detected faces and its embeddings in the images.
/// [peopleTable] - Stores all the clusters of faces which are considered to be the same person.
class MlDataDB {
  static final Logger _logger = Logger("MlDataDB");

  static const _databaseName = "ente.ml_data.db";
  static const _databaseVersion = 1;

  static const facesTable = 'faces';
  static const fileIDColumn = 'file_id';
  static const faceMlResultColumn = 'face_ml_result';
  static const mlVersionColumn = 'ml_version';

  static const peopleTable = 'people';
  static const personIDColumn = 'person_id';
  static const clusterResultColumn = 'cluster_result';
  static const centroidColumn = 'centroid';

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
  Future<void> cleanTables() async {
    _logger.fine('`cleanTables()` called');

    final db = await instance.database;

    await db.execute(_deleteFacesTable);
    await db.execute(_deletePeopleTable);

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

  /// getAllFileIDs returns a set of all fileIDs from the facesTable, meaning all the fileIDs for which a FaceMlResult exists, optionally filtered by mlVersion.
  Future<Set<int>> getAllFileIDs({int? mlVersion}) async {
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
}
