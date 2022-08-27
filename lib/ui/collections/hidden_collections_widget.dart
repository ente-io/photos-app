import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/collection_updated_event.dart';
import 'package:photos/models/collection_items.dart';
import 'package:photos/services/collections_service.dart';
import 'package:photos/ui/collections/hidden_collection_item_widget.dart';
import 'package:photos/ui/common/loading_widget.dart';
import 'package:photos/ui/viewer/gallery/sharing_hidden_album_warning_widget.dart';

class HiddenCollectionsWidget extends StatefulWidget {
  const HiddenCollectionsWidget({Key key}) : super(key: key);

  @override
  State<HiddenCollectionsWidget> createState() =>
      _HiddenCollectionsWidgetState();
}

class _HiddenCollectionsWidgetState extends State<HiddenCollectionsWidget> {
  StreamSubscription<CollectionUpdatedEvent> _collectionUpdatesSubscription;

  @override
  void initState() {
    _collectionUpdatesSubscription =
        Bus.instance.on<CollectionUpdatedEvent>().listen((event) {
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final hiddenCollectionIds =
        CollectionsService.instance.getArchivedCollections();

    final hiddenCollectionsWithThumbnail =
        getCollectionsWithThumbnail(hiddenCollectionIds);
    final isHiddenCollectionsEmpty = hiddenCollectionIds.isEmpty;
    return Column(
      children: [
        isHiddenCollectionsEmpty
            ? const SizedBox.shrink()
            : FutureBuilder(
                future: hiddenCollectionsWithThumbnail,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final List<CollectionWithThumbnail> hiddenCollections =
                        snapshot.data;

                    return Padding(
                      padding: const EdgeInsets.only(top: 0),
                      child: Column(
                        children: [
                          _hasSharedCollection(hiddenCollections)
                              ? const SharingHiddenAlbumWarning()
                              : const SizedBox.shrink(),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child:
                                HiddenCollectionsListViewWidget(snapshot.data),
                          ),
                        ],
                      ),
                    );
                  } else if (snapshot.hasError) {
                    Logger('HiddenCollections').info(snapshot.error);
                    return const SizedBox.shrink();
                  } else {
                    return const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: EnteLoadingWidget(),
                    );
                  }
                },
              ),
        isHiddenCollectionsEmpty ? const SizedBox.shrink() : const Divider(),
      ],
    );
  }

  bool _hasSharedCollection(
    List<CollectionWithThumbnail> hiddenCollecitons,
  ) {
    bool hasSharedCollection = false;
    for (var collection in hiddenCollecitons) {
      if (collection.collection.isShared()) {
        hasSharedCollection = true;
        break;
      }
    }
    return hasSharedCollection;
  }

  @override
  void dispose() {
    _collectionUpdatesSubscription.cancel();
    super.dispose();
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

class HiddenCollectionsListViewWidget extends StatelessWidget {
  final List<CollectionWithThumbnail> hiddenCollections;

  const HiddenCollectionsListViewWidget(
    this.hiddenCollections, {
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 155,
        child: Align(
          alignment: Alignment.centerLeft,
          child: ListView.builder(
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
            physics: const ScrollPhysics(),
            // to disable GridView's scrolling
            itemBuilder: (context, index) {
              return HiddenCollectionItem(hiddenCollections[index]);
            },
            itemCount: hiddenCollections.length,
          ),
        ),
      ),
    );
  }
}
