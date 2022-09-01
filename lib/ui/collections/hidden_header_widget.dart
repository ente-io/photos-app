import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/events/collection_updated_event.dart';
import 'package:photos/models/collection_items.dart';
import 'package:photos/services/collections_service.dart';
import 'package:photos/ui/collections/hidden_collections_list_view_widget.dart';
import 'package:photos/ui/common/loading_widget.dart';
import 'package:photos/ui/viewer/gallery/sharing_hidden_album_warning_widget.dart';

class HiddenHeaderWidget extends StatefulWidget {
  const HiddenHeaderWidget({Key key}) : super(key: key);

  @override
  State<HiddenHeaderWidget> createState() => _HiddenHeaderWidgetState();
}

class _HiddenHeaderWidgetState extends State<HiddenHeaderWidget> {
  StreamSubscription<CollectionUpdatedEvent> _collectionUpdatesSubscription;

  @override
  void initState() {
    _collectionUpdatesSubscription =
        Bus.instance.on<CollectionUpdatedEvent>().listen(
      (event) {
        setState(() {});
      },
    );
    super.initState();
  }

  @override
  void dispose() {
    _collectionUpdatesSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder(
          future: _showBanner(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              if (snapshot.data) {
                return const SharingHiddenItemsBanner();
              }
              return const SizedBox.shrink();
            } else if (snapshot.hasError) {
              Logger('HiddenPage').info(snapshot.error);
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
              return HiddenCollectionsListViewWidget(snapshot.data);
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
    );
  }

  Future<bool> _showBanner() async {
    final hiddenCollections =
        CollectionsService.instance.getHiddenCollections();
    bool hasHiddenFilesInSharedCollection = false;
    bool hasSharedHiddenCollection = false;
    for (var hiddenCollection in hiddenCollections) {
      if (hiddenCollection.isShared()) {
        hasSharedHiddenCollection = true;
        break;
      }
    }

    final sharedCollectionIDs =
        CollectionsService.instance.getSharedCollectionIDs();
    final collectionIDsOfHiddenFiles = await FilesDB.instance
        .getCollectionIDsOfHiddenFiles(Configuration.instance.getUserID());
    collectionIDsOfHiddenFiles.intersection(sharedCollectionIDs).isNotEmpty
        ? hasHiddenFilesInSharedCollection = true
        : {};
    return hasSharedHiddenCollection || hasHiddenFilesInSharedCollection;
  }

  Future<List<CollectionWithThumbnail>>
      _getHiddenCollectionsWithThumbnail() async {
    final hiddenCollectionIDs =
        CollectionsService.instance.getHiddenCollectionIDs();
    final collectionService = CollectionsService.instance;
    final List<CollectionWithThumbnail> hiddenCollectionsWithThumbnail = [];
    final latestCollectionFiles =
        await collectionService.getLatestCollectionFiles();

    for (final file in latestCollectionFiles) {
      if (hiddenCollectionIDs.contains(file.collectionID)) {
        final c = collectionService.getCollectionByID(file.collectionID);
        hiddenCollectionsWithThumbnail.add(CollectionWithThumbnail(c, file));
      }
    }
    return hiddenCollectionsWithThumbnail;
  }
}
