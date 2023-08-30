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

  static const peopleTable = 'people';
  static const personIDColumn = 'person_id';
  static const clusterResultColumn = 'cluster_result';

  static const createFacesTable = '''CREATE TABLE IF NOT EXISTS $facesTable (
  $fileIDColumn	INTEGER NOT NULL UNIQUE,
	$faceMlResultColumn	TEXT NOT NULL,
  PRIMARY KEY($fileIDColumn)
  );
  ''';
  static const createPeopleTable = '''CREATE TABLE IF NOT EXISTS $peopleTable (
  $personIDColumn	INTEGER NOT NULL UNIQUE,
	$clusterResultColumn	TEXT NOT NULL,
	PRIMARY KEY($personIDColumn AUTOINCREMENT)
  );
  ''';

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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> doesFaceMlResultExist(int fileId) async {
    _logger.fine('doesFaceMlResultExist called');
    final db = await instance.database;
    final result = await db.query(
      facesTable,
      where: '$fileIDColumn = ?',
      whereArgs: [fileId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<FaceMlResult?> getFaceMlResult(int fileId) async {
    _logger.fine('getFaceMlResult called');
    final db = await instance.database;
    final result = await db.query(
      facesTable,
      where: '$fileIDColumn = ?',
      whereArgs: [fileId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return FaceMlResult.fromJsonString(
        result.first[faceMlResultColumn] as String,
      );
    }
    _logger.fine('No faceMlResult found for fileID $fileId');
    return null;
  }

  Future<List<FaceMlResult>> getAllFaceMlResults() async {
    _logger.fine('getAllFaceMlResults called');
    final db = await instance.database;
    final results = await db.query(facesTable);
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
      },
      where: '$fileIDColumn = ?',
      whereArgs: [faceMlResult.fileId],
    );
  }

  // getFileIDs return set of fileID from the facesTable
  Future<Set<int>> getFileIDs() async {
    final db = await instance.database;
    final results = await db.query(facesTable);
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
