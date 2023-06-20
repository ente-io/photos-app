import "package:photos/models/file.dart";
import "package:photos/services/filter/collection_ignore.dart";
import "package:photos/services/filter/dedupe_by_upload_id.dart";
import "package:photos/services/filter/filter.dart";
import "package:photos/services/filter/upload_ignore.dart";
import "package:photos/services/ignored_files_service.dart";

class CommonDBFilterOptions {
  // typically used for filtering out all files which are present in hidden
  // (searchable files result) or archived collections or both (ex: home
  // timeline)
  Set<int>? ignoredCollectionIDs;
  bool dedupeUploadID;
  bool hideIgnoredForUpload;

  CommonDBFilterOptions({
    this.ignoredCollectionIDs,
    this.hideIgnoredForUpload = false,
    this.dedupeUploadID = true,
  });
}

Future<List<File>> applyCommonFilter(
  List<File> files,
  CommonDBFilterOptions? options,
) async {
  if (options == null) {
    return files;
  }
  final List<Filter> filters = [];
  if (options.hideIgnoredForUpload) {
    final Set<String> ignoredIDs =
        await IgnoredFilesService.instance.ignoredIDs;
    if (ignoredIDs.isNotEmpty) {
      filters.add(UploadIgnoreFilter(ignoredIDs));
    }
  }
  if (options.dedupeUploadID) {
    filters.add(DedupeUploadIDFilter());
  }
  if (options.ignoredCollectionIDs != null &&
      options.ignoredCollectionIDs!.isNotEmpty) {
    final collectionIgnoreFilter =
        CollectionsIgnoreFilter(options.ignoredCollectionIDs!, files);
    filters.add(collectionIgnoreFilter);
  }
  final List<File> filterFiles = [];
  for (final file in files) {
    if (filters.every((f) => f.filter(file))) {
      filterFiles.add(file);
    }
  }
  return filterFiles;
}
