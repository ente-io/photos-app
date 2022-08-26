import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/collection_updated_event.dart';
import 'package:photos/models/collection_items.dart';
import 'package:photos/services/collections_service.dart';
import 'package:photos/ui/collections/hidden_collections_list_view_widget.dart';
import 'package:photos/ui/common/loading_widget.dart';
import 'package:photos/ui/viewer/gallery/hidden_collections_empty_state.dart';

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
    return Column(
      children: [
        const SizedBox(height: 12),
        hiddenCollectionIds.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(22),
                child: HiddenCollectionsEmptyState(),
              )
            : FutureBuilder(
                future: hiddenCollectionsWithThumbnail,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return HiddenCollectionsListViewWidget(snapshot.data);
                  } else if (snapshot.hasError) {
                    Logger('HiddenCollections').info(snapshot.error);
                    return const HiddenCollectionsEmptyState();
                  } else {
                    return const EnteLoadingWidget();
                  }
                },
              ),
        const Divider(),
      ],
    );
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
