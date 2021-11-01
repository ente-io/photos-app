import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photos/models/file_load_result.dart';
import 'package:photos/models/trash_file.dart';
import 'package:sqflite/sqflite.dart';

// The TrashDB doesn't need to flatten and store all attributes of a file.
// Before adding any other column, we should evaluate if we need to query on that
// column or not while showing trashed items. Even if we miss storing any new attributes,
// during restore, all file attributes will be fetched & stored as required.
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
  static final columnUpdationTime = 'updation_time';

  static final columnCreationTime = 'creation_time';
  static final columnLocalID = 'local_id';

  // standard file metadata, which isn't editable
  static final columnFileMetadata = 'file_metadata';

  static final columnMMdEncodedJson = 'mmd_encoded_json';
  static final columnMMdVersion = 'mmd_ver';

  static final columnPubMMdEncodedJson = 'pub_mmd_encoded_json';
  static final columnPubMMdVersion = 'pub_mmd_ver';

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
          $columnUpdationTime INTEGER,
          $columnLocalID TEXT,
          $columnCreationTime INTEGER NOT NULL,
          $columnFileMetadata TEXT DEFAULT '{}',
          $columnMMdEncodedJson TEXT DEFAULT '{}',
          $columnMMdVersion INTEGER DEFAULT 0,
          $columnPubMMdEncodedJson TEXT DEFAULT '{}',
          $columnPubMMdVersion INTEGER DEFAULT 0
        );
      CREATE INDEX IF NOT EXISTS creation_time_index ON $tableName($columnCreationTime); 
      CREATE INDEX IF NOT EXISTS delete_by_time_index ON $tableName($columnTrashDeleteBy);
      CREATE INDEX IF NOT EXISTS updated_at_time_index ON $tableName($columnTrashUpdatedAt);
      ''');
  }

  TrashDB._privateConstructor();

  static final TrashDB instance = TrashDB._privateConstructor();

  // only have a single app-wide reference to the database
  // lazily instantiate the db the first time it is accessed
  late final Future<Database> _dbFuture = _initDatabase();
  Future<Database> get database async {
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

  // getRecentlyTrashedFile returns the file which was trashed recently
  Future<TrashFile?> getRecentlyTrashedFile() async {
    final db = await instance.database;
    var rows = await db.query(tableName,
        orderBy: '$columnTrashDeleteBy DESC', limit: 1);
    if (rows == null || rows.isEmpty) {
      return null;
    }
    return _getTrashFromRow(rows[0]);
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

  Future<int> delete(List<int?> uploadedFileIDs) async {
    final db = await instance.database;
    return db.delete(
      tableName,
      where: '$columnUploadedFileID IN (${uploadedFileIDs.join(', ')})',
    );
  }

  Future<int> update(TrashFile file) async {
    final db = await instance.database;
    return await db.update(
      tableName,
      _getRowForTrash(file),
      where: '$columnUploadedFileID = ?',
      whereArgs: [file.uploadedFileID],
    );
  }

  Future<FileLoadResult> getTrashedFiles(int startTime, int endTime,
      {int? limit, bool? asc}) async {
    final db = await instance.database;
    final order = (asc ?? false ? 'ASC' : 'DESC');
    final results = await db.query(
      tableName,
      where: '$columnCreationTime >= ? AND $columnCreationTime <= ?',
      whereArgs: [startTime, endTime],
      orderBy: '$columnCreationTime ' + order,
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
    trashFile.uploadedFileID = row[columnUploadedFileID];
    // dirty hack to ensure that the file_downloads & cache mechanism works
    trashFile.generatedID = -1 * trashFile.uploadedFileID!;
    trashFile.ownerID = row[columnOwnerID];
    trashFile.collectionID =
        row[columnCollectionID] == -1 ? null : row[columnCollectionID];
    trashFile.encryptedKey = row[columnEncryptedKey];
    trashFile.keyDecryptionNonce = row[columnKeyDecryptionNonce];
    trashFile.fileDecryptionHeader = row[columnFileDecryptionHeader];
    trashFile.thumbnailDecryptionHeader = row[columnThumbnailDecryptionHeader];
    trashFile.updationTime = row[columnUpdationTime] ?? 0;

    trashFile.localID = row[columnLocalID];
    trashFile.creationTime = row[columnCreationTime];
    final fileMetadata = row[columnFileMetadata] ?? '{}';
    trashFile.applyMetadata(jsonDecode(fileMetadata));

    trashFile.mMdVersion = row[columnMMdVersion] ?? 0;
    trashFile.mMdEncodedJson = row[columnMMdEncodedJson] ?? '{}';

    trashFile.pubMmdVersion = row[columnPubMMdVersion] ?? 0;
    trashFile.pubMmdEncodedJson = row[columnPubMMdEncodedJson] ?? '{}';

    if (trashFile.pubMagicMetadata != null &&
        trashFile.pubMagicMetadata.editedTime != null) {
      // override existing creationTime to avoid re-writing all queries related
      // to loading the gallery
      row[columnCreationTime] = trashFile.pubMagicMetadata.editedTime;
    }

    return trashFile;
  }

  Map<String, dynamic> _getRowForTrash(TrashFile trash) {
    final row = <String, dynamic>{};
    row[columnTrashUpdatedAt] = trash.updateAt;
    row[columnTrashDeleteBy] = trash.deleteBy;
    row[columnUploadedFileID] = trash.uploadedFileID;
    row[columnCollectionID] = trash.collectionID;
    row[columnOwnerID] = trash.ownerID;
    row[columnEncryptedKey] = trash.encryptedKey;
    row[columnKeyDecryptionNonce] = trash.keyDecryptionNonce;
    row[columnFileDecryptionHeader] = trash.fileDecryptionHeader;
    row[columnThumbnailDecryptionHeader] = trash.thumbnailDecryptionHeader;
    row[columnUpdationTime] = trash.updationTime;

    row[columnLocalID] = trash.localID;
    row[columnCreationTime] = trash.creationTime;
    row[columnFileMetadata] = jsonEncode(trash.getMetadata());

    row[columnMMdVersion] = trash.mMdVersion ?? 0;
    row[columnMMdEncodedJson] = trash.mMdEncodedJson ?? '{}';

    row[columnPubMMdVersion] = trash.pubMmdVersion ?? 0;
    row[columnPubMMdEncodedJson] = trash.pubMmdEncodedJson ?? '{}';
    return row;
  }
}
