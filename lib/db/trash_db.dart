import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photos/models/file_load_result.dart';
import 'package:photos/models/file_type.dart';
import 'package:photos/models/location.dart';
import 'package:photos/models/magic_metadata.dart';
import 'package:photos/models/trash_file.dart';
import 'package:sqflite/sqflite.dart';

class TrashDB {
  static final _databaseName = "ente.trash.db";
  static final _databaseVersion = 1;
  static final Logger _logger = Logger("TrashDB");
  static final tableName = 'trash';

  static final columnUploadedFileID = 'uploaded_file_id';
  static final columnCollectionID = 'collection_id';
  static final columnOwnerID = 'owner_id';
  static final columnTrashUpdatedAt = 't_updated_at';
  static final columnTrashDeleteBy = 't_delete_by';
  static final columnEncryptedKey = 'encrypted_key';
  static final columnKeyDecryptionNonce = 'key_decryption_nonce';
  static final columnFileDecryptionHeader = 'file_decryption_header';
  static final columnThumbnailDecryptionHeader = 'thumbnail_decryption_header';

  static final columnLocalID = 'local_id';
  static final columnTitle = 'title';
  static final columnDeviceFolder = 'device_folder';
  static final columnLatitude = 'latitude';
  static final columnLongitude = 'longitude';
  static final columnFileType = 'file_type';
  static final columnFileSubType = 'file_sub_type';
  static final columnDuration = 'duration';
  static final columnHash = 'hash';
  static final columnMetadataVersion = 'metadata_version';
  static final columnModificationTime = 'modification_time';
  static final columnCreationTime = 'creation_time';
  static final columnMMdEncodedJson = 'mmd_encoded_json';
  static final columnMMdVersion = 'mmd_ver';
  static final columnMMdVisibility = 'mmd_visibility';

  Future _onCreate(Database db, int version) async {
    await db.execute('''
        CREATE TABLE $tableName (
          $columnUploadedFileID INTEGER PRIMARY KEY NOT NULL,
          $columnCollectionID INTEGER NOT NULL,
          $columnOwnerID INTEGER,
          $columnTrashUpdatedAt INTEGER NOT NULL,
          $columnTrashDeleteBy INTEGER NOT NULL,
          $columnEncryptedKey TEXT,
          $columnKeyDecryptionNonce TEXT,
          $columnFileDecryptionHeader TEXT,
          $columnThumbnailDecryptionHeader TEXT,
          $columnLocalID TEXT,
          $columnTitle TEXT NOT NULL,
          $columnDeviceFolder TEXT,
          $columnLatitude REAL,
          $columnLongitude REAL,
          $columnFileType INTEGER,
          $columnCreationTime INTEGER NOT NULL,
          $columnModificationTime INTEGER NOT NULL,
          $columnFileSubType INTEGER,
          $columnDuration INTEGER,
          $columnHash TEXT,
          $columnMetadataVersion INTEGER,
          $columnMMdEncodedJson TEXT DEFAULT '{}',
          $columnMMdVersion INTEGER DEFAULT 0,
          $columnMMdVisibility INTEGER DEFAULT $kVisibilityVisible
        );
      CREATE INDEX IF NOT EXISTS creation_time_index ON $tableName($columnCreationTime); 
      CREATE INDEX IF NOT EXISTS creation_time_index ON $tableName($columnTrashDeleteBy);
      CREATE INDEX IF NOT EXISTS creation_time_index ON $tableName($columnTrashUpdatedAt);
      ''');
  }

  TrashDB._privateConstructor();

  static final TrashDB instance = TrashDB._privateConstructor();

  // only have a single app-wide reference to the database
  static Future<Database> _dbFuture;

  Future<Database> get database async {
    // lazily instantiate the db the first time it is accessed
    _dbFuture ??= _initDatabase();
    return _dbFuture;
  }

  // this opens the database (and creates it if it doesn't exist)
  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    _logger.info("DB path " + path);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> clearTable() async {
    final db = await instance.database;
    await db.delete(tableName);
  }

  Future<void> insertMultiple(List<TrashFile> trashFiles) async {
    final startTime = DateTime.now();
    final db = await instance.database;
    var batch = db.batch();
    int batchCounter = 0;
    for (TrashFile trash in trashFiles) {
      if (batchCounter == 400) {
        await batch.commit(noResult: true);
        batch = db.batch();
        batchCounter = 0;
      }
      batch.insert(
        tableName,
        _getRowForTrash(trash),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batchCounter++;
    }
    await batch.commit(noResult: true);
    final endTime = DateTime.now();
    final duration = Duration(
        microseconds:
            endTime.microsecondsSinceEpoch - startTime.microsecondsSinceEpoch);
    _logger.info("Batch insert of " +
        trashFiles.length.toString() +
        " took " +
        duration.inMilliseconds.toString() +
        "ms.");
  }

  Future<int> insert(TrashFile trash) async {
    final db = await instance.database;
    return db.insert(
      tableName,
      _getRowForTrash(trash),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> delete(List<int> uploadedFileIDs) async {
    final db = await instance.database;
    return db.delete(
      tableName,
      where: '$columnUploadedFileID IN (${uploadedFileIDs.join(', ')})',
    );
  }

  Future<FileLoadResult> getTrashedFiles(int startTime, int endTime,
      {int limit, bool asc}) async {
    final db = await instance.database;
    final order = (asc ?? false ? 'ASC' : 'DESC');
    final results = await db.query(
      tableName,
      where: '$columnCreationTime >= ? AND $columnCreationTime <= ?',
      whereArgs: [startTime, endTime],
      orderBy:
          '$columnCreationTime ' + order + ', $columnModificationTime ' + order,
      limit: limit,
    );
    final files = _convertToFiles(results);
    return FileLoadResult(files, files.length == limit);
  }

  List<TrashFile> _convertToFiles(List<Map<String, dynamic>> results) {
    final List<TrashFile> trashedFiles = [];
    for (final result in results) {
      trashedFiles.add(_getTrashFromRow(result));
    }
    return trashedFiles;
  }

  TrashFile _getTrashFromRow(Map<String, dynamic> row) {
    final trashFile = TrashFile();
    trashFile.updateAt = row[columnTrashUpdatedAt];
    trashFile.deleteBy = row[columnTrashDeleteBy];
    trashFile.uploadedFileID =
        row[columnUploadedFileID] == -1 ? null : row[columnUploadedFileID];
    trashFile.generatedID = -1 * trashFile.uploadedFileID;
    trashFile.localID = row[columnLocalID];
    trashFile.ownerID = row[columnOwnerID];
    trashFile.collectionID =
        row[columnCollectionID] == -1 ? null : row[columnCollectionID];
    trashFile.title = row[columnTitle];
    trashFile.deviceFolder = row[columnDeviceFolder];
    if (row[columnLatitude] != null && row[columnLongitude] != null) {
      trashFile.location = Location(row[columnLatitude], row[columnLongitude]);
    }
    trashFile.fileType = getFileType(row[columnFileType]);
    trashFile.creationTime = row[columnCreationTime];
    trashFile.modificationTime = row[columnModificationTime];
    trashFile.encryptedKey = row[columnEncryptedKey];
    trashFile.keyDecryptionNonce = row[columnKeyDecryptionNonce];
    trashFile.fileDecryptionHeader = row[columnFileDecryptionHeader];
    trashFile.thumbnailDecryptionHeader = row[columnThumbnailDecryptionHeader];
    trashFile.fileSubType = row[columnFileSubType] ?? -1;
    trashFile.duration = row[columnDuration] ?? 0;
    trashFile.hash = row[columnHash];
    trashFile.metadataVersion = row[columnMetadataVersion] ?? 0;
    trashFile.mMdVersion = row[columnMMdVersion] ?? 0;
    trashFile.mMdEncodedJson = row[columnMMdEncodedJson] ?? '{}';

    return trashFile;
  }

  Map<String, dynamic> _getRowForTrash(TrashFile trash) {
    final row = <String, dynamic>{};
    row[columnTrashUpdatedAt] = trash.updateAt;
    row[columnTrashDeleteBy] = trash.deleteBy;
    row[columnUploadedFileID] = trash.uploadedFileID;
    row[columnCollectionID] = trash.collectionID;
    row[columnOwnerID] = trash.ownerID;
    row[columnLocalID] = trash.localID;
    row[columnTitle] = trash.title;
    row[columnDeviceFolder] = trash.deviceFolder;
    if (trash.location != null) {
      row[columnLatitude] = trash.location.latitude;
      row[columnLongitude] = trash.location.longitude;
    }
    row[columnFileType] = getInt(trash.fileType);
    row[columnCreationTime] = trash.creationTime;
    row[columnModificationTime] = trash.modificationTime;
    row[columnEncryptedKey] = trash.encryptedKey;
    row[columnKeyDecryptionNonce] = trash.keyDecryptionNonce;
    row[columnFileDecryptionHeader] = trash.fileDecryptionHeader;
    row[columnThumbnailDecryptionHeader] = trash.thumbnailDecryptionHeader;
    row[columnFileSubType] = trash.fileSubType ?? -1;
    row[columnDuration] = trash.duration ?? 0;
    row[columnHash] = trash.hash;
    row[columnMetadataVersion] = trash.metadataVersion;
    row[columnMMdVersion] = trash.mMdVersion ?? 0;
    row[columnMMdEncodedJson] = trash.mMdEncodedJson ?? '{}';
    row[columnMMdVisibility] =
        trash.magicMetadata?.visibility ?? kVisibilityVisible;
    return row;
  }
}
