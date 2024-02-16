import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/collection_updated_event.dart';
import 'package:photos/events/local_photos_updated_event.dart';
import 'package:photos/events/user_logged_out_event.dart';
import "package:photos/generated/l10n.dart";
import 'package:photos/models/collection/collection_items.dart';
import 'package:photos/services/collections_service.dart';
import "package:photos/ui/collections/album/row_item.dart";
import "package:photos/ui/collections/collection_list_page.dart";
import 'package:photos/ui/common/loading_widget.dart';
import "package:photos/ui/components/buttons/button_widget.dart";
import "package:photos/ui/components/buttons/icon_button_widget.dart";
import "package:photos/ui/components/divider_widget.dart";
import "package:photos/ui/components/models/button_type.dart";
import 'package:photos/ui/tabs/section_title.dart';
import "package:photos/ui/tabs/shared/empty_state.dart";
import "package:photos/ui/tabs/shared/quick_link_album_item.dart";
import "package:photos/utils/debouncer.dart";
import "package:photos/utils/navigation_util.dart";
import "package:photos/utils/share_util.dart";

class SharedCollectionsTab extends StatefulWidget {
  const SharedCollectionsTab({Key? key}) : super(key: key);

  @override
  State<SharedCollectionsTab> createState() => _SharedCollectionsTabState();
}

class _SharedCollectionsTabState extends State<SharedCollectionsTab>
    with AutomaticKeepAliveClientMixin {
  final Logger _logger = Logger("SharedCollectionGallery");
  late StreamSubscription<LocalPhotosUpdatedEvent> _localFilesSubscription;
  late StreamSubscription<CollectionUpdatedEvent>
      _collectionUpdatesSubscription;
  late StreamSubscription<UserLoggedOutEvent> _loggedOutEvent;
  final _debouncer = Debouncer(
    const Duration(seconds: 2),
    executionInterval: const Duration(seconds: 5),
  );

  @override
  void initState() {
    super.initState();
    _localFilesSubscription =
        Bus.instance.on<LocalPhotosUpdatedEvent>().listen((event) {
      _debouncer.run(() async {
        if (mounted) {
          debugPrint("SetState Shared Collections on ${event.reason}");
          setState(() {});
        }
      });
    });
    _collectionUpdatesSubscription =
        Bus.instance.on<CollectionUpdatedEvent>().listen((event) {
      _debouncer.run(() async {
        if (mounted) {
          debugPrint("SetState Shared Collections on ${event.reason}");
          setState(() {});
        }
      });
    });
    _loggedOutEvent = Bus.instance.on<UserLoggedOutEvent>().listen((event) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<SharedCollections>(
      future: Future.value(CollectionsService.instance.getSharedCollections()),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          if ((snapshot.data?.incoming.length ?? 0) == 0 &&
              (snapshot.data?.quickLinks.length ?? 0) == 0 &&
              (snapshot.data?.outgoing.length ?? 0) == 0) {
            return const Center(child: SharedEmptyStateWidget());
          }
          return _getSharedCollectionsGallery(snapshot.data!);
        } else if (snapshot.hasError) {
          _logger.severe(
            "critical: failed to load share gallery",
            snapshot.error,
            snapshot.stackTrace,
          );
          return Center(child: Text(S.of(context).somethingWentWrong));
        } else {
          return const EnteLoadingWidget();
        }
      },
    );
  }

  Widget _getSharedCollectionsGallery(SharedCollections collections) {
    const maxThumbnailWidth = 160.0;
    final bool hasQuickLinks = collections.quickLinks.isNotEmpty;
    final SectionTitle sharedWithYou =
        SectionTitle(title: S.of(context).sharedWithYou);
    final SectionTitle sharedByYou =
        SectionTitle(title: S.of(context).sharedByYou);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 50),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SectionOptions(
                    Hero(tag: "incoming", child: sharedWithYou),
                    trailingWidget: collections.incoming.isNotEmpty
                        ? IconButtonWidget(
                            icon: Icons.chevron_right,
                            iconButtonType: IconButtonType.secondary,
                            onTap: () {
                              unawaited(
                                routeToPage(
                                  context,
                                  CollectionListPage(
                                    collections.incoming,
                                    sectionType:
                                        UISectionType.incomingCollections,
                                    tag: "incoming",
                                    appTitle: sharedWithYou,
                                  ),
                                ),
                              );
                            },
                          )
                        : null,
                  ),
                  const SizedBox(height: 2),
                  collections.incoming.isNotEmpty
                      ? SizedBox(
                          height: maxThumbnailWidth + 24,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: AlbumRowItemWidget(
                                  collections.incoming[index],
                                  maxThumbnailWidth,
                                  tag: "incoming",
                                ),
                              );
                            },
                            itemCount: collections.incoming.length,
                          ),
                        )
                      : const IncomingAlbumEmptyState(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SectionOptions(
                    Hero(tag: "outgoing", child: sharedByYou),
                    trailingWidget: collections.outgoing.isNotEmpty
                        ? IconButtonWidget(
                            icon: Icons.chevron_right,
                            iconButtonType: IconButtonType.secondary,
                            onTap: () {
                              unawaited(
                                routeToPage(
                                  context,
                                  CollectionListPage(
                                    collections.outgoing,
                                    sectionType:
                                        UISectionType.outgoingCollections,
                                    tag: "outgoing",
                                    appTitle: sharedByYou,
                                  ),
                                ),
                              );
                            },
                          )
                        : null,
                  ),
                  const SizedBox(height: 2),
                  collections.outgoing.isNotEmpty
                      ? SizedBox(
                          height: maxThumbnailWidth + 24,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: AlbumRowItemWidget(
                                  collections.outgoing[index],
                                  maxThumbnailWidth,
                                  tag: "outgoing",
                                ),
                              );
                            },
                            itemCount: collections.outgoing.length,
                          ),
                        )
                      : const OutgoingAlbumEmptyState(),
                ],
              ),
            ),
            hasQuickLinks
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        SectionOptions(
                          SectionTitle(title: S.of(context).quickLinks),
                        ),
                        const SizedBox(height: 2),
                        ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 12),
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            return QuickLinkAlbumItem(
                              c: collections.quickLinks[index],
                            );
                          },
                          itemCount: collections.quickLinks.length,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            collections.incoming.isNotEmpty
                ? Column(
                    children: [
                      const DividerWidget(dividerType: DividerType.bottomBar),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: ButtonWidget(
                          buttonType:
                              !hasQuickLinks && collections.outgoing.isEmpty
                                  ? ButtonType.trailingIconSecondary
                                  : ButtonType.trailingIconPrimary,
                          labelText: S.of(context).inviteYourFriendsToEnte,
                          icon: Icons.ios_share_outlined,
                          onTap: () async {
                            // ignore: unawaited_futures
                            shareText(
                              S.of(context).shareTextRecommendUsingEnte,
                            );
                          },
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _localFilesSubscription.cancel();
    _collectionUpdatesSubscription.cancel();
    _loggedOutEvent.cancel();
    _debouncer.cancelDebounce();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}
