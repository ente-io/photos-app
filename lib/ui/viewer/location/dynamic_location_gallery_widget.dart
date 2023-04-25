import "dart:developer" as dev;
import "dart:math";

import "package:flutter/material.dart";
import "package:photos/core/constants.dart";
import "package:photos/db/files_db.dart";
import "package:photos/models/file.dart";
import "package:photos/models/file_load_result.dart";
import "package:photos/services/collections_service.dart";
import "package:photos/services/files_service.dart";
import "package:photos/services/location_service.dart";
import 'package:photos/states/location_state.dart';
import "package:photos/ui/viewer/gallery/gallery.dart";
import "package:photos/utils/local_settings.dart";

///This gallery will get rebuilt with the updated radius when
///InheritedLocationTagData notifies a change in radius.
class DynamicLocationGalleryWidget extends StatefulWidget {
  final ValueNotifier<int?> memoriesCountNotifier;
  final String tagPrefix;
  const DynamicLocationGalleryWidget(
    this.memoriesCountNotifier,
    this.tagPrefix, {
    super.key,
  });

  @override
  State<DynamicLocationGalleryWidget> createState() =>
      _DynamicLocationGalleryWidgetState();
}

class _DynamicLocationGalleryWidgetState
    extends State<DynamicLocationGalleryWidget> {
  late final Future<FileLoadResult> fileLoadResult;
  late Future<void> removeIgnoredFiles;
  double heightOfGallery = 0;

  @override
  void initState() {
    final collectionsToHide =
        CollectionsService.instance.collectionsHiddenFromTimeline();
    fileLoadResult =
        FilesDB.instance.fetchAllUploadedAndSharedFilesWithLocation(
      galleryLoadStartTime,
      galleryLoadEndTime,
      limit: null,
      asc: false,
      ignoredCollectionIDs: collectionsToHide,
    );
    removeIgnoredFiles =
        FilesService.instance.removeIgnoredFiles(fileLoadResult);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    const galleryFilesLimit = 1000;
    final selectedRadius = _selectedRadius();
    Future<FileLoadResult> filterFiles() async {
      final FileLoadResult result = await fileLoadResult;
      //wait for ignored files to be removed after init
      await removeIgnoredFiles;
      final stopWatch = Stopwatch()..start();
      final copyOfFiles = List<File>.from(result.files);
      copyOfFiles.removeWhere((f) {
        return !LocationService.instance.isFileInsideLocationTag(
          InheritedLocationTagData.of(context).centerPoint,
          f.location!,
          selectedRadius,
        );
      });
      dev.log(
        "Time taken to get all files in a location tag: ${stopWatch.elapsedMilliseconds} ms",
      );
      stopWatch.stop();
      widget.memoriesCountNotifier.value = copyOfFiles.length;
      final limitedResults = copyOfFiles.take(galleryFilesLimit).toList();

      return Future.value(
        FileLoadResult(
          limitedResults,
          result.hasMore,
        ),
      );
    }

    return FutureBuilder(
      //Only rebuild Gallery if the center point or radius changes
      key: ValueKey(
        "${InheritedLocationTagData.of(context).centerPoint}$selectedRadius",
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return SizedBox(
            height: _galleryHeight(
              min(
                (widget.memoriesCountNotifier.value ?? 0),
                galleryFilesLimit,
              ),
            ),
            child: Gallery(
              loadingWidget: const SizedBox.shrink(),
              disableScroll: true,
              asyncLoader: (
                creationStartTime,
                creationEndTime, {
                limit,
                asc,
              }) async {
                return snapshot.data as FileLoadResult;
              },
              tagPrefix: widget.tagPrefix,
              shouldCollateFilesByDay: false,
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
      future: filterFiles(),
    );
  }

  double _selectedRadius() {
    return radiusValues[
        InheritedLocationTagData.of(context).selectedRadiusIndex];
  }

  double _galleryHeight(int fileCount) {
    final photoGridSize = LocalSettings.instance.getPhotoGridSize();
    final totalWhiteSpaceBetweenPhotos =
        galleryGridSpacing * (photoGridSize - 1);

    final thumbnailHeight =
        ((MediaQuery.of(context).size.width - totalWhiteSpaceBetweenPhotos) /
            photoGridSize);

    final numberOfRows = (fileCount / photoGridSize).ceil();

    final galleryHeight = (thumbnailHeight * numberOfRows) +
        (galleryGridSpacing * (numberOfRows - 1));
    return galleryHeight + 120;
  }
}
