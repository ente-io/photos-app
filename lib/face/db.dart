import 'dart:async';

import 'package:logging/logging.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:photos/face/db_fields.dart';
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

  /// WARNING: This will delete ALL data in the database! Only use this for debug/testing purposes!
  Future<void> cleanTables({
    bool cleanFaces = false,
    bool cleanPeople = false,
    bool cleanFeedback = false,
  }) async {
    _logger.fine('`cleanTables()` called');
    final db = await instance.database;

    if (cleanFaces) {
      _logger.fine('`cleanTables()`: Cleaning faces table');
      await db.execute(deleteFacesTable);
    }

    if (cleanPeople) {
      _logger.fine('`cleanTables()`: Cleaning people table');
      await db.execute(deletePeopleTable);
    }

    if (!cleanFaces && !cleanPeople && !cleanFeedback) {
      _logger.fine(
        '`cleanTables()`: No tables cleaned, since no table was specified. Please be careful with this function!',
      );
    }

    await db.execute(createFacesTable);
    await db.execute(createPeopleTable);
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

  /// getAllFileIDs returns a set of all fileIDs from the facesTable, meaning all the fileIDs for which a FaceMlResult exists, optionally filtered by mlVersion.
  Future<Set<int>> getAllFaceMlResultFileIDs({int? mlVersion}) async {
    _logger.fine('getAllFaceMlResultFileIDs called');
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
      orderBy: fileIDColumn,
    );

    return results.map((result) => result[fileIDColumn] as int).toSet();
  }
}
