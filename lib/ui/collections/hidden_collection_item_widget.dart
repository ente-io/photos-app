import 'package:flutter/material.dart';
import 'package:photos/models/collection_items.dart';
import 'package:photos/ui/viewer/file/thumbnail_widget.dart';
import 'package:photos/ui/viewer/gallery/collection_page.dart';
import 'package:photos/utils/navigation_util.dart';

class HiddenCollectionItem extends StatelessWidget {
  HiddenCollectionItem(
    this.c, {
    Key key,
  }) : super(key: Key(c.collection.id.toString()));

  final CollectionWithThumbnail c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: SizedBox(
          height: 140,
          width: 120,
          child: Column(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 120,
                  width: 120,
                  child: Hero(
                    tag: "collection" + c.thumbnail.tag(),
                    child: Stack(
                      children: [
                        ThumbnailWidget(
                          c.thumbnail,
                          key: Key(
                            "collection" + c.thumbnail.tag(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  c.collection.name,
                  style: Theme.of(context)
                      .textTheme
                      .subtitle1
                      .copyWith(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      onTap: () {
        routeToPage(context, CollectionPage(c));
      },
    );
  }
}
