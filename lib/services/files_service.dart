import 'package:photos/core/configuration.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/models/magic_metadata.dart';
import 'package:photos/services/collections_service.dart';

class FilesService {
  FilesDB _db;
  Configuration _config;
  FilesService._privateConstructor() {
    _db = FilesDB.instance;
    _config = Configuration.instance;
  }
  static final FilesService instance = FilesService._privateConstructor();

  Future<bool> doesFileBelongToSharedCollection(int uploadedFileID) async {
    final collectionIDsOfFile = await _db.getAllCollectionIDsOfFile(
      uploadedFileID,
      _config.getUserID(),
      visibility: visibilityHidden,
    );
    final sharedCollectionIDs =
        CollectionsService.instance.getSharedCollectionIDs();
    return sharedCollectionIDs.intersection(collectionIDsOfFile).isNotEmpty;
  }
}
