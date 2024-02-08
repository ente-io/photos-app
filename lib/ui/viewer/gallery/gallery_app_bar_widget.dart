import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import "package:flutter/cupertino.dart";
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/configuration.dart';
import "package:photos/core/constants.dart";
import 'package:photos/core/event_bus.dart';
import "package:photos/core/network/network.dart";
import "package:photos/db/files_db.dart";
import 'package:photos/events/subscription_purchased_event.dart';
import "package:photos/gateways/cast_gw.dart";
import "package:photos/generated/l10n.dart";
import "package:photos/l10n/l10n.dart";
import 'package:photos/models/backup_status.dart';
import 'package:photos/models/collection/collection.dart';
import 'package:photos/models/device_collection.dart';
import 'package:photos/models/gallery_type.dart';
import "package:photos/models/metadata/common_keys.dart";
import 'package:photos/models/selected_files.dart';
import 'package:photos/services/collections_service.dart';
import 'package:photos/services/sync_service.dart';
import 'package:photos/services/update_service.dart';
import 'package:photos/ui/actions/collection/collection_sharing_actions.dart';
import 'package:photos/ui/components/action_sheet_widget.dart';
import 'package:photos/ui/components/buttons/button_widget.dart';
import 'package:photos/ui/components/models/button_type.dart';
import "package:photos/ui/map/enable_map.dart";
import "package:photos/ui/map/map_screen.dart";
import 'package:photos/ui/sharing/album_participants_page.dart';
import "package:photos/ui/sharing/manage_links_widget.dart";
import 'package:photos/ui/sharing/share_collection_page.dart';
import 'package:photos/ui/tools/free_space_page.dart';
import "package:photos/ui/viewer/gallery/hooks/add_photos_sheet.dart";
import 'package:photos/ui/viewer/gallery/hooks/pick_cover_photo.dart';
import 'package:photos/utils/data_util.dart';
import 'package:photos/utils/dialog_util.dart';
import 'package:photos/utils/magic_util.dart';
import 'package:photos/utils/navigation_util.dart';
import 'package:photos/utils/toast_util.dart';
import "package:uuid/uuid.dart";

class GalleryAppBarWidget extends StatefulWidget {
  final GalleryType type;
  final String? title;
  final SelectedFiles selectedFiles;
  final DeviceCollection? deviceCollection;
  final Collection? collection;

  const GalleryAppBarWidget(
    this.type,
    this.title,
    this.selectedFiles, {
    Key? key,
    this.deviceCollection,
    this.collection,
  }) : super(key: key);

  @override
  State<GalleryAppBarWidget> createState() => _GalleryAppBarWidgetState();
}

enum AlbumPopupAction {
  rename,
  delete,
  map,
  ownedArchive,
  sharedArchive,
  ownedHide,
  playOnTv,
  sort,
  leave,
  freeUpSpace,
  setCover,
  addPhotos,
  pinAlbum,
  removeLink,
  cleanUncategorized,
}

class _GalleryAppBarWidgetState extends State<GalleryAppBarWidget> {
  final _logger = Logger("GalleryAppBar");
  late StreamSubscription _userAuthEventSubscription;
  late Function() _selectedFilesListener;
  String? _appBarTitle;
  late CollectionActions collectionActions;
  final GlobalKey shareButtonKey = GlobalKey();
  bool isQuickLink = false;
  late GalleryType galleryType;

  @override
  void initState() {
    super.initState();
    _selectedFilesListener = () {
      setState(() {});
    };
    collectionActions = CollectionActions(CollectionsService.instance);
    widget.selectedFiles.addListener(_selectedFilesListener);
    _userAuthEventSubscription =
        Bus.instance.on<SubscriptionPurchasedEvent>().listen((event) {
      setState(() {});
    });
    _appBarTitle = widget.title;
    galleryType = widget.type;
  }

  @override
  void dispose() {
    _userAuthEventSubscription.cancel();
    widget.selectedFiles.removeListener(_selectedFilesListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return galleryType == GalleryType.homepage
        ? const SizedBox.shrink()
        : AppBar(
            elevation: 0,
            centerTitle: false,
            title: Text(
              _appBarTitle!,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall!
                  .copyWith(fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            actions: _getDefaultActions(context),
          );
  }

  Future<dynamic> _renameAlbum(BuildContext context) async {
    if (galleryType != GalleryType.ownedCollection &&
        galleryType != GalleryType.hiddenOwnedCollection &&
        galleryType != GalleryType.quickLink) {
      showToast(
        context,
        'Type of galler $galleryType is not supported for '
        'rename',
      );

      return;
    }
    final result = await showTextInputDialog(
      context,
      title: isQuickLink
          ? S.of(context).enterAlbumName
          : S.of(context).renameAlbum,
      submitButtonLabel:
          isQuickLink ? S.of(context).done : S.of(context).rename,
      hintText: S.of(context).enterAlbumName,
      alwaysShowSuccessState: true,
      initialValue: widget.collection?.displayName ?? "",
      textCapitalization: TextCapitalization.words,
      onSubmit: (String text) async {
        // indicates user cancelled the rename request
        if (text == "" || text.trim() == _appBarTitle!.trim()) {
          return;
        }

        try {
          await CollectionsService.instance.rename(widget.collection!, text);
          if (mounted) {
            _appBarTitle = text;
            if (isQuickLink) {
              // update the gallery type to owned collection so that correct
              // actions are shown
              galleryType = GalleryType.ownedCollection;
            }
            setState(() {});
          }
        } catch (e, s) {
          _logger.severe("Failed to rename album", e, s);
          rethrow;
        }
      },
    );
    if (result is Exception) {
      await showGenericErrorDialog(context: context, error: result);
    }
  }

  Future<dynamic> _leaveAlbum(BuildContext context) async {
    final actionResult = await showActionSheet(
      context: context,
      buttons: [
        ButtonWidget(
          buttonType: ButtonType.critical,
          isInAlert: true,
          shouldStickToDarkTheme: true,
          buttonAction: ButtonAction.first,
          shouldSurfaceExecutionStates: true,
          labelText: S.of(context).leaveAlbum,
          onTap: () async {
            await CollectionsService.instance.leaveAlbum(widget.collection!);
          },
        ),
        ButtonWidget(
          buttonType: ButtonType.secondary,
          buttonAction: ButtonAction.cancel,
          isInAlert: true,
          shouldStickToDarkTheme: true,
          labelText: S.of(context).cancel,
        ),
      ],
      title: S.of(context).leaveSharedAlbum,
      body: S.of(context).photosAddedByYouWillBeRemovedFromTheAlbum,
    );
    if (actionResult?.action != null && mounted) {
      if (actionResult!.action == ButtonAction.error) {
        await showGenericErrorDialog(
          context: context,
          error: actionResult.exception,
        );
      } else if (actionResult.action == ButtonAction.first) {
        Navigator.of(context).pop();
      }
    }
  }

  // todo: In the new design, clicking on free up space will directly open
  // the free up space page and show loading indicator while calculating
  // the space which can be claimed up. This code duplication should be removed
  // whenever we move to the new design for free up space.
  Future<dynamic> _deleteBackedUpFiles(BuildContext context) async {
    final dialog = createProgressDialog(context, S.of(context).calculating);
    await dialog.show();
    BackupStatus status;
    try {
      status = await SyncService.instance
          .getBackupStatus(pathID: widget.deviceCollection!.id);
    } catch (e) {
      await dialog.hide();
      unawaited(showGenericErrorDialog(context: context, error: e));
      return;
    }

    await dialog.hide();
    if (status.localIDs.isEmpty) {
      await showErrorDialog(
        context,
        S.of(context).allClear,
        S.of(context).youveNoFilesInThisAlbumThatCanBeDeleted,
      );
    } else {
      final bool? result = await routeToPage(
        context,
        FreeSpacePage(status, clearSpaceForFolder: true),
      );
      if (result == true) {
        _showSpaceFreedDialog(status);
      }
    }
  }

  void _showSpaceFreedDialog(BackupStatus status) {
    showChoiceDialog(
      context,
      title: S.of(context).success,
      body: S.of(context).youHaveSuccessfullyFreedUp(formatBytes(status.size)),
      firstButtonLabel: S.of(context).rateUs,
      firstButtonOnTap: () async {
        await UpdateService.instance.launchReviewUrl();
      },
      firstButtonType: ButtonType.primary,
      secondButtonLabel: S.of(context).ok,
      secondButtonOnTap: () async {
        if (Platform.isIOS) {
          showToast(
            context,
            S.of(context).remindToEmptyDeviceTrash,
          );
        }
      },
    );
  }

  List<Widget> _getDefaultActions(BuildContext context) {
    final List<Widget> actions = <Widget>[];
    // If the user has selected files, don't show any actions
    if (widget.selectedFiles.files.isNotEmpty ||
        !Configuration.instance.hasConfiguredAccount()) {
      return actions;
    }
    final int userID = Configuration.instance.getUserID()!;
    isQuickLink = widget.collection?.isQuickLinkCollection() ?? false;
    if (galleryType.canAddFiles(widget.collection, userID)) {
      actions.add(
        Tooltip(
          message: "Add Files",
          child: IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: () async {
              await _showAddPhotoDialog(context);
            },
          ),
        ),
      );
    }
    if (galleryType.isSharable()) {
      actions.add(
        Tooltip(
          message: "Share",
          child: IconButton(
            icon: Icon(
              isQuickLink && (widget.collection!.hasLink)
                  ? Icons.link_outlined
                  : Icons.people_outlined,
            ),
            onPressed: () async {
              await _showShareCollectionDialog();
            },
          ),
        ),
      );
    }
    final List<PopupMenuItem<AlbumPopupAction>> items = [];
    if (galleryType.canRename()) {
      items.add(
        PopupMenuItem(
          value: AlbumPopupAction.rename,
          child: Row(
            children: [
              Icon(isQuickLink ? Icons.photo_album_outlined : Icons.edit),
              const Padding(
                padding: EdgeInsets.all(8),
              ),
              Text(
                isQuickLink
                    ? S.of(context).convertToAlbum
                    : S.of(context).renameAlbum,
              ),
            ],
          ),
        ),
      );
    }
    if (galleryType.canSetCover()) {
      items.add(
        PopupMenuItem(
          value: AlbumPopupAction.setCover,
          child: Row(
            children: [
              const Icon(Icons.image_outlined),
              const Padding(
                padding: EdgeInsets.all(8),
              ),
              Text(S.of(context).setCover),
            ],
          ),
        ),
      );
    }
    if (galleryType.showMap()) {
      items.add(
        PopupMenuItem(
          value: AlbumPopupAction.map,
          child: Row(
            children: [
              const Icon(Icons.map_outlined),
              const Padding(
                padding: EdgeInsets.all(8),
              ),
              Text(S.of(context).map),
            ],
          ),
        ),
      );
    }

    if (galleryType.canSort()) {
      items.add(
        PopupMenuItem(
          value: AlbumPopupAction.sort,
          child: Row(
            children: [
              const Icon(Icons.sort_outlined),
              const Padding(
                padding: EdgeInsets.all(8),
              ),
              Text(
                S.of(context).sortAlbumsBy,
              ),
            ],
          ),
        ),
      );
    }

    if (galleryType == GalleryType.uncategorized) {
      items.add(
        PopupMenuItem(
          value: AlbumPopupAction.cleanUncategorized,
          child: Row(
            children: [
              const Icon(Icons.crop_original_outlined),
              const Padding(
                padding: EdgeInsets.all(8),
              ),
              Text(S.of(context).cleanUncategorized),
            ],
          ),
        ),
      );
    }
    if (galleryType.canPin()) {
      items.add(
        PopupMenuItem(
          value: AlbumPopupAction.pinAlbum,
          child: Row(
            children: [
              widget.collection!.isPinned
                  ? const Icon(CupertinoIcons.pin_slash)
                  : Transform.rotate(
                      angle: 45 * math.pi / 180, // rotate by 45 degrees
                      child: const Icon(CupertinoIcons.pin),
                    ),
              const Padding(
                padding: EdgeInsets.all(8),
              ),
              Text(
                widget.collection!.isPinned
                    ? S.of(context).unpinAlbum
                    : S.of(context).pinAlbum,
              ),
            ],
          ),
        ),
      );
    }
    final bool isArchived = widget.collection?.isArchived() ?? false;
    final bool isHidden = widget.collection?.isHidden() ?? false;
    // Do not show archive option for favorite collection. If collection is
    // already archived, allow user to unarchive that collection.
    if (isArchived || (galleryType.canArchive() && !isHidden)) {
      items.add(
        PopupMenuItem(
          value: AlbumPopupAction.ownedArchive,
          child: Row(
            children: [
              Icon(isArchived ? Icons.unarchive : Icons.archive_outlined),
              const Padding(
                padding: EdgeInsets.all(8),
              ),
              Text(
                isArchived
                    ? S.of(context).unarchiveAlbum
                    : S.of(context).archiveAlbum,
              ),
            ],
          ),
        ),
      );
    }
    if (!isArchived && galleryType.canHide()) {
      items.add(
        PopupMenuItem(
          value: AlbumPopupAction.ownedHide,
          child: Row(
            children: [
              Icon(
                isHidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              const Padding(
                padding: EdgeInsets.all(8),
              ),
              Text(
                isHidden ? S.of(context).unhide : S.of(context).hide,
              ),
            ],
          ),
        ),
      );
    }
    if (widget.collection != null && isInternalUser) {
      items.add(
        PopupMenuItem(
          value: AlbumPopupAction.playOnTv,
          child: Row(
            children: [
              const Icon(Icons.tv_outlined),
              const Padding(
                padding: EdgeInsets.all(8),
              ),
              Text(context.l10n.playOnTv),
            ],
          ),
        ),
      );
    }

    if (galleryType.canDelete()) {
      items.add(
        PopupMenuItem(
          value: isQuickLink
              ? AlbumPopupAction.removeLink
              : AlbumPopupAction.delete,
          child: Row(
            children: [
              Icon(
                isQuickLink
                    ? Icons.remove_circle_outline
                    : Icons.delete_outline,
              ),
              const Padding(
                padding: EdgeInsets.all(8),
              ),
              Text(
                isQuickLink
                    ? S.of(context).removeLink
                    : S.of(context).deleteAlbum,
              ),
            ],
          ),
        ),
      );
    }

    if (galleryType == GalleryType.sharedCollection) {
      final bool hasShareeArchived = widget.collection!.hasShareeArchived();
      items.add(
        PopupMenuItem(
          value: AlbumPopupAction.sharedArchive,
          child: Row(
            children: [
              Icon(
                hasShareeArchived ? Icons.unarchive : Icons.archive_outlined,
              ),
              const Padding(
                padding: EdgeInsets.all(8),
              ),
              Text(
                hasShareeArchived
                    ? S.of(context).unarchiveAlbum
                    : S.of(context).archiveAlbum,
              ),
            ],
          ),
        ),
      );
      items.add(
        PopupMenuItem(
          value: AlbumPopupAction.leave,
          child: Row(
            children: [
              const Icon(Icons.logout),
              const Padding(
                padding: EdgeInsets.all(8),
              ),
              Text(S.of(context).leaveAlbum),
            ],
          ),
        ),
      );
    }
    if (galleryType == GalleryType.localFolder) {
      items.add(
        PopupMenuItem(
          value: AlbumPopupAction.freeUpSpace,
          child: Row(
            children: [
              const Icon(Icons.delete_sweep_outlined),
              const Padding(
                padding: EdgeInsets.all(8),
              ),
              Text(S.of(context).freeUpDeviceSpace),
            ],
          ),
        ),
      );
    }
    if (items.isNotEmpty) {
      actions.add(
        PopupMenuButton(
          itemBuilder: (context) {
            return items;
          },
          onSelected: (AlbumPopupAction value) async {
            if (value == AlbumPopupAction.rename) {
              await _renameAlbum(context);
            } else if (value == AlbumPopupAction.pinAlbum) {
              await updateOrder(
                context,
                widget.collection!,
                widget.collection!.isPinned ? 0 : 1,
              );
              if (mounted) setState(() {});
            } else if (value == AlbumPopupAction.ownedArchive) {
              await archiveOrUnarchive();
            } else if (value == AlbumPopupAction.ownedHide) {
              await hideOrUnhide();
            } else if (value == AlbumPopupAction.delete) {
              await _trashCollection();
            } else if (value == AlbumPopupAction.removeLink) {
              await _removeQuickLink();
            } else if (value == AlbumPopupAction.leave) {
              await _leaveAlbum(context);
            } else if (value == AlbumPopupAction.playOnTv) {
              await castAlbum();
            } else if (value == AlbumPopupAction.freeUpSpace) {
              await _deleteBackedUpFiles(context);
            } else if (value == AlbumPopupAction.setCover) {
              await setCoverPhoto(context);
            } else if (value == AlbumPopupAction.sort) {
              await _showSortOption(context);
            } else if (value == AlbumPopupAction.sharedArchive) {
              final hasShareeArchived = widget.collection!.hasShareeArchived();
              final int prevVisiblity =
                  hasShareeArchived ? archiveVisibility : visibleVisibility;
              final int newVisiblity =
                  hasShareeArchived ? visibleVisibility : archiveVisibility;

              await changeCollectionVisibility(
                context,
                collection: widget.collection!,
                newVisibility: newVisiblity,
                prevVisibility: prevVisiblity,
                isOwner: false,
              );
              if (mounted) {
                setState(() {});
              }
            } else if (value == AlbumPopupAction.map) {
              await showOnMap();
            } else if (value == AlbumPopupAction.cleanUncategorized) {
              await collectionActions.removeFromUncatIfPresentInOtherAlbum(
                widget.collection!,
                context,
              );
            } else {
              showToast(context, S.of(context).somethingWentWrong);
            }
          },
        ),
      );
    }

    return actions;
  }

  Future<void> setCoverPhoto(BuildContext context) async {
    final int? coverPhotoID = await showPickCoverPhotoSheet(
      context,
      widget.collection!,
    );
    if (coverPhotoID != null) {
      unawaited(changeCoverPhoto(context, widget.collection!, coverPhotoID));
    }
  }

  Future<void> showOnMap() async {
    final bool result = await requestForMapEnable(context);
    if (result) {
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MapScreen(
              filesFutureFn: () async {
                return FilesDB.instance.getAllFilesCollection(
                  widget.collection!.id,
                );
              },
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showSortOption(BuildContext bContext) async {
    final bool? sortByAsc = await showMenu<bool>(
      context: bContext,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width,
        kToolbarHeight + 12,
        12,
        0,
      ),
      items: [
        PopupMenuItem(
          value: false,
          child: Text(S.of(context).sortNewestFirst),
        ),
        PopupMenuItem(
          value: true,
          child: Text(S.of(context).sortOldestFirst),
        ),
      ],
    );
    if (sortByAsc != null) {
      unawaited(changeSortOrder(bContext, widget.collection!, sortByAsc));
    }
  }

  Future<void> _trashCollection() async {
    // Fetch the count by-passing the cache to avoid any stale data
    final int count =
        await FilesDB.instance.collectionFileCount(widget.collection!.id);
    final bool isEmptyCollection = count == 0;
    if (isEmptyCollection) {
      final dialog = createProgressDialog(
        context,
        S.of(context).pleaseWaitDeletingAlbum,
      );
      await dialog.show();
      try {
        await CollectionsService.instance
            .trashEmptyCollection(widget.collection!);
        await dialog.hide();
        Navigator.of(context).pop();
      } catch (e, s) {
        _logger.severe("failed to trash collection", e, s);
        await dialog.hide();
        await showGenericErrorDialog(context: context, error: e);
      }
    } else {
      final bool result = await collectionActions.deleteCollectionSheet(
        context,
        widget.collection!,
      );
      if (result == true) {
        Navigator.of(context).pop();
      } else {
        debugPrint("No pop");
      }
    }
  }

  Future<void> _removeQuickLink() async {
    try {
      final bool result =
          await CollectionActions(CollectionsService.instance).disableUrl(
        context,
        widget.collection!,
      );
      if (result && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, s) {
      _logger.severe("failed to trash collection", e, s);
      await showGenericErrorDialog(context: context, error: e);
    }
  }

  Future<void> _showShareCollectionDialog() async {
    final collection = widget.collection;
    try {
      if (collection == null ||
          (galleryType != GalleryType.ownedCollection &&
              galleryType != GalleryType.sharedCollection &&
              galleryType != GalleryType.hiddenOwnedCollection &&
              !isQuickLink)) {
        throw Exception(
          "Cannot share empty collection of type $galleryType",
        );
      }
      if (Configuration.instance.getUserID() == widget.collection!.owner!.id) {
        unawaited(
          routeToPage(
            context,
            (isQuickLink && (collection.hasLink))
                ? ManageSharedLinkWidget(collection: collection)
                : ShareCollectionPage(collection),
          ),
        );
      } else {
        unawaited(
          routeToPage(
            context,
            AlbumParticipantsPage(collection),
          ),
        );
      }
    } catch (e, s) {
      _logger.severe(e, s);
      await showGenericErrorDialog(context: context, error: e);
    }
  }

  Future<void> _showAddPhotoDialog(BuildContext bContext) async {
    final collection = widget.collection;
    try {
      await showAddPhotosSheet(bContext, collection!);
    } catch (e, s) {
      _logger.severe(e, s);
      await showGenericErrorDialog(context: bContext, error: e);
    }
  }

  Future<void> hideOrUnhide() async {
    final isHidden = widget.collection!.isHidden();
    final int prevVisiblity = isHidden ? hiddenVisibility : visibleVisibility;
    final int newVisiblity = isHidden ? visibleVisibility : hiddenVisibility;

    await changeCollectionVisibility(
      context,
      collection: widget.collection!,
      newVisibility: newVisiblity,
      prevVisibility: prevVisiblity,
    );
    setState(() {});
  }

  Future<void> archiveOrUnarchive() async {
    final isArchived = widget.collection!.isArchived();
    final int prevVisiblity =
        isArchived ? archiveVisibility : visibleVisibility;
    final int newVisiblity = isArchived ? visibleVisibility : archiveVisibility;

    await changeCollectionVisibility(
      context,
      collection: widget.collection!,
      newVisibility: newVisiblity,
      prevVisibility: prevVisiblity,
    );
    setState(() {});
  }

  Future<void> castAlbum() async {
    final gw = CastGateway(NetworkClient.instance.enteDio);
    // stop any existing cast session
    gw.revokeAllTokens().ignore();
    await showTextInputDialog(
      context,
      title: context.l10n.playOnTv,
      body: S.of(context).castInstruction,
      submitButtonLabel: S.of(context).pair,
      textInputType: TextInputType.streetAddress,
      hintText: context.l10n.deviceCodeHint,
      onSubmit: (String text) async {
        try {
          String code = text.trim();
          final String? publicKey = await gw.getPublicKey(code);
          if (publicKey == null) {
            showToast(context, S.of(context).deviceNotFound);
            return;
          }
          final String castToken = Uuid().v4().toString();
          final castPayload = CollectionsService.instance
              .getCastData(castToken, widget.collection!, publicKey);
          await gw.publishCastPayload(
            code,
            castPayload,
            widget.collection!.id,
            castToken,
          );
        } catch (e, s) {
          _logger.severe("Failed to cast album", e, s);
          await showGenericErrorDialog(context: context, error: e);
        }
      },
    );
  }
}
