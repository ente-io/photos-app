import 'package:flutter/material.dart';
import 'package:photos/models/collection_items.dart';
import 'package:photos/ui/collections/hidden_collection_item_widget.dart';
import 'package:photos/ui/viewer/gallery/empte_state.dart';

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
          child: hiddenCollections.isEmpty
              ? const EmptyState()
              : ListView.builder(
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
