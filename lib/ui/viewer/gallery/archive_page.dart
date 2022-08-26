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
import 'package:photos/ui/collections/hidden_collections_list_view_widget.dart';
import 'package:photos/ui/common/loading_widget.dart';
import 'package:photos/ui/viewer/gallery/empte_state.dart';
import 'package:photos/ui/viewer/gallery/gallery.dart';
import 'package:photos/ui/viewer/gallery/gallery_app_bar_widget.dart';
import 'package:photos/ui/viewer/gallery/gallery_overlay_widget.dart';

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
      header: const HiddenCollections(),
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
}

class HiddenCollections extends StatelessWidget {
  const HiddenCollections({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hiddenCollectionIds =
        CollectionsService.instance.getArchivedCollections();

    final hiddenCollectionsWithThumbnail =
        getCollectionsWithThumbnail(hiddenCollectionIds);
    return Column(
      children: [
        const SizedBox(height: 12),
        hiddenCollectionIds.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(22),
                child: EmptyState(),
              )
            : FutureBuilder(
                future: hiddenCollectionsWithThumbnail,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return HiddenCollectionsListViewWidget(snapshot.data);
                  } else if (snapshot.hasError) {
                    Logger('HiddenCollections').info(snapshot.error);
                    return const EmptyState();
                  } else {
                    return const EnteLoadingWidget();
                  }
                },
              ),
        const Divider(),
      ],
    );
  }
}

Future<List<CollectionWithThumbnail>> getCollectionsWithThumbnail(
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
