import 'package:flutter/material.dart';
import 'package:photos/models/collection_items.dart';
import 'package:photos/ui/collections/hidden_collection_item_widget.dart';

class HiddenCollectionsListViewWidget extends StatelessWidget {
  final List<CollectionWithThumbnail> hiddenCollectionsWithThumbnail;
  const HiddenCollectionsListViewWidget(
    this.hiddenCollectionsWithThumbnail, {
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isHiddenCollectionsEmpty = hiddenCollectionsWithThumbnail.isEmpty;

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
                      child: Padding(
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
                                return HiddenCollectionItem(
                                  hiddenCollectionsWithThumbnail[index],
                                );
                              },
                              itemCount: hiddenCollectionsWithThumbnail.length,
                            ),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        )
      ],
    );
  }
}
