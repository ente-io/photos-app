import 'package:logging/logging.dart';
import "package:photos/core/configuration.dart";
import 'package:photos/core/network/network.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/models/duplicate_files.dart';
import 'package:photos/models/file/file.dart';
import "package:photos/services/collections_service.dart";
import "package:photos/services/files_service.dart";

class DeduplicationService {
  final _logger = Logger("DeduplicationService");
  final _enteDio = NetworkClient.instance.enteDio;

  DeduplicationService._privateConstructor();

  static final DeduplicationService instance =
      DeduplicationService._privateConstructor();

  Future<List<DuplicateFiles>> getDuplicateFiles() async {
    try {
      final List<DuplicateFiles> result = await _getDuplicateFiles();
      return result;
    } catch (e, s) {
      _logger.severe("failed to get dedupeFile", e, s);
      rethrow;
    }
  }

  // Returns a list of DuplicateFiles, where each DuplicateFiles object contains
  // a list of files that have the same size and hash
  Future<List<DuplicateFiles>> _getDuplicateFiles() async {
    Map<int, int> uploadIDToSize = {};
    final bool hasFileSizes = await FilesService.instance.hasMigratedSizes();
    if (!hasFileSizes) {
      final DuplicateFilesResponse dupes = await _fetchDuplicateFileIDs();
      uploadIDToSize = dupes.toUploadIDToSize();
    }
    final Set<int> allowedCollectionIDs =
        CollectionsService.instance.nonHiddenOwnedCollections();

    final List<EnteFile> allFiles = await FilesDB.instance.getAllFilesFromDB(
      CollectionsService.instance.getHiddenCollectionIds(),
      dedupeByUploadId: false,
    );
    final int ownerID = Configuration.instance.getUserID()!;
    final List<EnteFile> filteredFiles = [];
    for (final file in allFiles) {
      if (!file.isUploaded ||
          (file.hash ?? '').isEmpty ||
          (file.ownerID ?? 0) != ownerID ||
          (!allowedCollectionIDs.contains(file.collectionID!))) {
        continue;
      }
      if ((file.fileSize ?? 0) <= 0) {
        file.fileSize = uploadIDToSize[file.uploadedFileID!] ?? 0;
      }
      if ((file.fileSize ?? 0) <= 0) {
        continue;
      }
      filteredFiles.add(file);
    }

    final Map<String, List<EnteFile>> sizeHashToFilesMap = {};
    final Map<String, Set<int>> sizeHashToCollectionsSet = {};
    final Set<int> processedFileIds = <int>{};
    for (final file in filteredFiles) {
      final key = '${file.fileSize}-${file.hash}';
      if (!sizeHashToFilesMap.containsKey(key)) {
        sizeHashToFilesMap[key] = <EnteFile>[];
        sizeHashToCollectionsSet[key] = <int>{};
      }
      sizeHashToCollectionsSet[key]!.add(file.collectionID!);
      if (!processedFileIds.contains(file.uploadedFileID)) {
        sizeHashToFilesMap[key]!.add(file);
        processedFileIds.add(file.uploadedFileID!);
      }
    }
    final List<DuplicateFiles> dupesBySizeHash = [];
    for (final key in sizeHashToFilesMap.keys) {
      final List<EnteFile> files = sizeHashToFilesMap[key]!;
      final Set<int> collectionIds = sizeHashToCollectionsSet[key]!;
      if (files.length > 1) {
        final size = files[0].fileSize!;
        dupesBySizeHash.add(DuplicateFiles(files, size, collectionIds));
      }
    }
    return dupesBySizeHash;
  }

  Future<DuplicateFilesResponse> _fetchDuplicateFileIDs() async {
    final response = await _enteDio.get("/files/duplicates");
    return DuplicateFilesResponse.fromMap(response.data);
  }
}
