import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/events/files_updated_event.dart';
import 'package:photos/models/collection_items.dart';
import 'package:photos/models/gallery_type.dart';
import 'package:photos/models/magic_metadata.dart';
import 'package:photos/models/selected_files.dart';
import 'package:photos/services/collections_service.dart';
import 'package:photos/ui/collections/hidden_collections_widget.dart';
import 'package:photos/ui/common/loading_widget.dart';
import 'package:photos/ui/viewer/gallery/gallery.dart';
import 'package:photos/ui/viewer/gallery/gallery_app_bar_widget.dart';
import 'package:photos/ui/viewer/gallery/gallery_overlay_widget.dart';
import 'package:photos/ui/viewer/gallery/sharing_hidden_album_warning_widget.dart';

class ArchivePage extends StatelessWidget {
  final String tagPrefix;
  final GalleryType appBarType;
  final GalleryType overlayType;
  final _selectedFiles = SelectedFiles();

  ArchivePage({
    this.tagPrefix = "archived_page",
    this.appBarType = GalleryType.archive,
    this.overlayType = GalleryType.archive,
    Key key,
  }) : super(key: key);

  @override
  Widget build(Object context) {
    final gallery = Gallery(
      asyncLoader: (creationStartTime, creationEndTime, {limit, asc}) {
        return FilesDB.instance.getAllUploadedFiles(
          creationStartTime,
          creationEndTime,
          Configuration.instance.getUserID(),
          visibility: kVisibilityArchive,
          limit: limit,
          asc: asc,
        );
      },
      reloadEvent: Bus.instance.on<FilesUpdatedEvent>().where(
            (event) =>
                event.updatedFiles.firstWhere(
                  (element) => element.uploadedFileID != null,
                  orElse: () => null,
                ) !=
                null,
          ),
      removalEventTypes: const {EventType.unarchived},
      forceReloadEvents: [
        Bus.instance.on<FilesUpdatedEvent>().where(
              (event) =>
                  event.updatedFiles.firstWhere(
                    (element) => element.uploadedFileID != null,
                    orElse: () => null,
                  ) !=
                  null,
            ),
      ],
      tagPrefix: tagPrefix,
      selectedFiles: _selectedFiles,
      initialFiles: null,
      header: Column(
        children: [
          FutureBuilder(
            future: _showBanner(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                if (snapshot.data) {
                  return const SharingHiddenAlbumWarning();
                }
                return const SizedBox.shrink();
              } else if (snapshot.hasError) {
                Logger('ArchivePage').info(snapshot.error);
                return const SizedBox.shrink();
              } else {
                return const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: EnteLoadingWidget(),
                );
              }
            },
          ),
          FutureBuilder(
            future: _getHiddenCollectionsWithThumbnail(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return HiddenCollectionsWidget(snapshot.data);
              } else if (snapshot.hasError) {
                Logger('ArchivePage').info(snapshot.error);
                return const SizedBox.shrink();
              } else {
                return const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: EnteLoadingWidget(),
                );
              }
            },
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: GalleryAppBarWidget(
          appBarType,
          "Hidden",
          _selectedFiles,
        ),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          gallery,
          GalleryOverlayWidget(
            overlayType,
            _selectedFiles,
          )
        ],
      ),
    );
  }

  Future<bool> _showBanner() async {
    final hiddenCollectionsWithThumbnail =
        await _getHiddenCollectionsWithThumbnail();

    bool hasSharedCollection = false;
    for (var collectionWithThumbnail in hiddenCollectionsWithThumbnail) {
      if (collectionWithThumbnail.collection.isShared()) {
        hasSharedCollection = true;
        break;
      }
    }
    return hasSharedCollection;
  }

  Future<List<CollectionWithThumbnail>>
      _getHiddenCollectionsWithThumbnail() async {
    final hiddenCollectionIds =
        CollectionsService.instance.getArchivedCollections();

    final hiddenCollectionsWithThumbnail =
        await _getCollectionsWithThumbnail(hiddenCollectionIds);

    return hiddenCollectionsWithThumbnail;
  }

  Future<List<CollectionWithThumbnail>> _getCollectionsWithThumbnail(
    Set<int> hiddenCollectionIDs,
  ) async {
    final collectionService = CollectionsService.instance;
    final List<CollectionWithThumbnail> collectionsWithThumbnail = [];
    final latestCollectionFiles =
        await collectionService.getLatestCollectionFiles();
    for (final file in latestCollectionFiles) {
      if (hiddenCollectionIDs.contains(file.collectionID)) {
        final c = collectionService.getCollectionByID(file.collectionID);
        collectionsWithThumbnail.add(CollectionWithThumbnail(c, file));
      }
    }
    return collectionsWithThumbnail;
  }
}
