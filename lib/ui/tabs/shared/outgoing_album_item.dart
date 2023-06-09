import "package:flutter/material.dart";
import "package:photos/generated/l10n.dart";
import "package:photos/models/collection_items.dart";
import "package:photos/models/gallery_type.dart";
import 'package:photos/theme/colors.dart';
import "package:photos/ui/viewer/file/thumbnail_widget.dart";
import "package:photos/ui/viewer/gallery/collection_page.dart";
import "package:photos/utils/navigation_util.dart";

class OutgoingAlbumItem extends StatelessWidget {
  final CollectionWithThumbnail c;

  const OutgoingAlbumItem({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final shareesName = <String>[];
    if (c.collection.hasSharees) {
      for (int index = 0; index < c.collection.sharees!.length; index++) {
        final sharee = c.collection.sharees![index]!;
        final String name =
            (sharee.name?.isNotEmpty ?? false) ? sharee.name! : sharee.email;
        if (index < 2) {
          shareesName.add(name);
        } else {
          final remaining = c.collection.sharees!.length - index;
          if (remaining == 1) {
            // If it's the last sharee
            shareesName.add(name);
          } else {
            shareesName.add(
              "and " +
                  remaining.toString() +
                  " other" +
                  (remaining > 1 ? "s" : ""),
            );
          }
          break;
        }
      }
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: SizedBox(
                height: 60,
                width: 60,
                child: Hero(
                  tag: "outgoing_collection" + c.thumbnail!.tag,
                  child: ThumbnailWidget(
                    c.thumbnail,
                    key: ValueKey("outgoing_collection" + c.thumbnail!.tag),
                  ),
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.all(8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        c.collection.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const Padding(padding: EdgeInsets.all(2)),
                      c.collection.hasLink
                          ? (c.collection.publicURLs!.first!.isExpired
                              ? const Icon(
                                  Icons.link,
                                  color: warning500,
                                )
                              : const Icon(Icons.link))
                          : const SizedBox.shrink(),
                    ],
                  ),
                  shareesName.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                          child: Text(
                            S.of(context).sharedWith(shareesName.join(", ")),
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).primaryColorLight,
                            ),
                            textAlign: TextAlign.left,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
      onTap: () {
        final page = CollectionPage(
          c,
          appBarType: GalleryType.ownedCollection,
          tagPrefix: "outgoing_collection",
        );
        routeToPage(context, page);
      },
    );
  }
}