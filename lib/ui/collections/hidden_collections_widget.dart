import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/collection_updated_event.dart';
import 'package:photos/models/collection_items.dart';
import 'package:photos/ui/collections/hidden_collection_item_widget.dart';

class HiddenCollectionsWidget extends StatefulWidget {
  final List<CollectionWithThumbnail> hiddenCollectionsWithThumbnail;
  const HiddenCollectionsWidget(this.hiddenCollectionsWithThumbnail, {Key key})
      : super(key: key);

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
    final isHiddenCollectionsEmpty =
        widget.hiddenCollectionsWithThumbnail.isEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 0),
          child: Column(
            children: [
              isHiddenCollectionsEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: HiddenCollectionsListViewWidget(
                        widget.hiddenCollectionsWithThumbnail,
                      ),
                    ),
            ],
          ),
        )

        // isHiddenCollectionsEmpty ? const SizedBox.shrink() : const Divider(),
      ],
    );
  }

  @override
  void dispose() {
    _collectionUpdatesSubscription.cancel();
    super.dispose();
  }
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
