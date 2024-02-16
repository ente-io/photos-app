import "package:flutter/foundation.dart";
import 'package:photos/models/collection/collection.dart';

enum GalleryType {
  homepage,
  archive,
  uncategorized,
  // hidden section shows all the files that are present in the defaultHidden
  // collections.
  hiddenSection,
  hiddenOwnedCollection,
  favorite,
  trash,
  localFolder,
  // indicator for gallery view of collections shared with the user
  sharedCollection,
  ownedCollection,
  searchResults,
  locationTag,
  quickLink,
}

extension GalleyTypeExtension on GalleryType {
  bool showAddToAlbum() {
    switch (this) {
      case GalleryType.homepage:
      case GalleryType.archive:
      case GalleryType.localFolder:
      case GalleryType.ownedCollection:
      case GalleryType.searchResults:
      case GalleryType.favorite:
      case GalleryType.locationTag:
      case GalleryType.quickLink:
      case GalleryType.uncategorized:
        return true;

      case GalleryType.hiddenSection:
      case GalleryType.hiddenOwnedCollection:
      case GalleryType.trash:
      case GalleryType.sharedCollection:
        return false;
    }
  }

  bool showMoveToAlbum() {
    switch (this) {
      case GalleryType.ownedCollection:
      case GalleryType.uncategorized:
      case GalleryType.quickLink:
        return true;

      case GalleryType.hiddenSection:
      case GalleryType.hiddenOwnedCollection:
      case GalleryType.favorite:
      case GalleryType.searchResults:
      case GalleryType.archive:
      case GalleryType.localFolder:
      case GalleryType.homepage:
      case GalleryType.trash:
      case GalleryType.sharedCollection:
      case GalleryType.locationTag:
        return false;
    }
  }

  // showDeleteTopOption indicates whether we should show
  // delete icon as iconButton
  bool showDeleteIconOption() {
    switch (this) {
      case GalleryType.ownedCollection:
      case GalleryType.searchResults:
      case GalleryType.homepage:
      case GalleryType.favorite:
      case GalleryType.localFolder:
      case GalleryType.uncategorized:
      case GalleryType.locationTag:
      case GalleryType.quickLink:
        return true;
      case GalleryType.trash:
      case GalleryType.archive:
      case GalleryType.hiddenSection:
      case GalleryType.hiddenOwnedCollection:
      case GalleryType.sharedCollection:
        return false;
    }
  }

  bool showDeleteOption() {
    switch (this) {
      case GalleryType.ownedCollection:
      case GalleryType.searchResults:
      case GalleryType.homepage:
      case GalleryType.favorite:
      case GalleryType.uncategorized:
      case GalleryType.archive:
      case GalleryType.hiddenSection:
      case GalleryType.hiddenOwnedCollection:
      case GalleryType.localFolder:
      case GalleryType.locationTag:
      case GalleryType.quickLink:
        return true;
      case GalleryType.trash:
      case GalleryType.sharedCollection:
        return false;
    }
  }

  bool showCreateLink() {
    switch (this) {
      case GalleryType.ownedCollection:
      case GalleryType.searchResults:
      case GalleryType.homepage:
      case GalleryType.favorite:
      case GalleryType.archive:
      case GalleryType.uncategorized:
      case GalleryType.locationTag:
        return true;
      case GalleryType.hiddenSection:
      case GalleryType.hiddenOwnedCollection:
      case GalleryType.localFolder:
      case GalleryType.trash:
      case GalleryType.sharedCollection:
      case GalleryType.quickLink:
        return false;
    }
  }

  bool showRemoveFromAlbum() {
    switch (this) {
      case GalleryType.ownedCollection:
      case GalleryType.sharedCollection:
      case GalleryType.quickLink:
        return true;
      case GalleryType.hiddenSection:
      case GalleryType.hiddenOwnedCollection:
      case GalleryType.uncategorized:
      case GalleryType.favorite:
      case GalleryType.searchResults:
      case GalleryType.homepage:
      case GalleryType.archive:
      case GalleryType.localFolder:
      case GalleryType.trash:
      case GalleryType.locationTag:
        return false;
    }
  }

  bool showArchiveOption() {
    switch (this) {
      case GalleryType.ownedCollection:
      case GalleryType.homepage:
      case GalleryType.uncategorized:
      case GalleryType.quickLink:
        return true;

      case GalleryType.hiddenSection:
      case GalleryType.hiddenOwnedCollection:
      case GalleryType.favorite:
      case GalleryType.searchResults:
      case GalleryType.archive:
      case GalleryType.localFolder:
      case GalleryType.trash:
      case GalleryType.sharedCollection:
      case GalleryType.locationTag:
        return false;
    }
  }

  bool showUnArchiveOption() {
    return this == GalleryType.archive;
  }

  bool showHideOption() {
    switch (this) {
      case GalleryType.ownedCollection:
      case GalleryType.homepage:
      case GalleryType.searchResults:
      case GalleryType.archive:
      case GalleryType.uncategorized:
      case GalleryType.locationTag:
      case GalleryType.quickLink:
        return true;

      case GalleryType.hiddenSection:
      case GalleryType.hiddenOwnedCollection:
      case GalleryType.localFolder:
      case GalleryType.trash:
      case GalleryType.favorite:
      case GalleryType.sharedCollection:
        return false;
    }
  }

  bool showUnHideOption() {
    return this == GalleryType.hiddenSection ||
        this == GalleryType.hiddenOwnedCollection;
  }

  bool showFavoriteOption() {
    switch (this) {
      case GalleryType.ownedCollection:
      case GalleryType.homepage:
      case GalleryType.searchResults:
      case GalleryType.uncategorized:
      case GalleryType.locationTag:
        return true;

      case GalleryType.hiddenSection:
      case GalleryType.hiddenOwnedCollection:
      case GalleryType.quickLink:
      case GalleryType.favorite:
      case GalleryType.archive:
      case GalleryType.localFolder:
      case GalleryType.trash:
      case GalleryType.sharedCollection:
        return false;
    }
  }

  bool showUnFavoriteOption() {
    return this == GalleryType.favorite;
  }

  bool showRestoreOption() {
    return this == GalleryType.trash;
  }

  bool showPermanentlyDeleteOption() {
    return this == GalleryType.trash;
  }

  bool showMovetoHiddenAlbum() {
    return this == GalleryType.hiddenSection ||
        this == GalleryType.hiddenOwnedCollection;
  }

  bool showAddtoHiddenAlbum() {
    return this == GalleryType.hiddenSection ||
        this == GalleryType.hiddenOwnedCollection;
  }

  bool showRemoveFromHiddenAlbum() {
    return this == GalleryType.hiddenOwnedCollection;
  }

  bool showEditLocation() {
    return this != GalleryType.sharedCollection;
  }
}

extension GalleryAppBarExtn on GalleryType {
  bool canAddFiles(Collection? c, int userID) {
    if (this == GalleryType.ownedCollection ||
        this == GalleryType.quickLink ||
        this == GalleryType.hiddenOwnedCollection) {
      return true;
    }
    if (this == GalleryType.sharedCollection) {
      return c?.getRole(userID) == CollectionParticipantRole.collaborator;
    }
    return false;
  }

  bool isSharable() {
    if (this == GalleryType.ownedCollection ||
        this == GalleryType.quickLink ||
        this == GalleryType.hiddenOwnedCollection ||
        this == GalleryType.sharedCollection) {
      return true;
    }
    return false;
  }

  bool isOwnedCollectionGallery() {
    if (this == GalleryType.ownedCollection ||
        this == GalleryType.quickLink ||
        this == GalleryType.hiddenOwnedCollection ||
        this == GalleryType.favorite) {
      return true;
    }
    return false;
  }

  bool canRename() {
    if (this == GalleryType.ownedCollection ||
        this == GalleryType.quickLink ||
        this == GalleryType.hiddenOwnedCollection) {
      return true;
    }
    return false;
  }

  bool canSetCover() {
    if (this == GalleryType.ownedCollection ||
        this == GalleryType.hiddenOwnedCollection) {
      return true;
    }
    return false;
  }

  bool canArchive() {
    return this == GalleryType.ownedCollection;
  }

  bool canPin() {
    return this == GalleryType.ownedCollection;
  }

  bool canHide() {
    return this == GalleryType.ownedCollection ||
        this == GalleryType.hiddenOwnedCollection;
  }

  bool canDelete() {
    return this == GalleryType.ownedCollection ||
        this == GalleryType.hiddenOwnedCollection ||
        this == GalleryType.quickLink;
  }

  bool canSort() {
    return this == GalleryType.ownedCollection ||
        this == GalleryType.hiddenOwnedCollection ||
        this == GalleryType.uncategorized ||
        this == GalleryType.quickLink;
  }

  bool showMap() {
    switch (this) {
      case GalleryType.homepage:
      case GalleryType.archive:
      case GalleryType.hiddenSection:
      case GalleryType.trash:
      case GalleryType.localFolder:
      case GalleryType.locationTag:
      case GalleryType.searchResults:
        return false;
      case GalleryType.uncategorized:
      case GalleryType.ownedCollection:
      case GalleryType.sharedCollection:
      case GalleryType.quickLink:
      case GalleryType.favorite:
      case GalleryType.hiddenOwnedCollection:
        return true;
    }
  }
}

GalleryType getGalleryType(Collection c, int userID) {
  if (!c.isOwner(userID)) {
    return GalleryType.sharedCollection;
  }
  if (c.isDefaultHidden()) {
    return GalleryType.hiddenSection;
  } else if (c.type == CollectionType.uncategorized) {
    return GalleryType.uncategorized;
  } else if (c.type == CollectionType.favorites) {
    return GalleryType.favorite;
  } else if (c.isQuickLinkCollection()) {
    return GalleryType.quickLink;
  } else if (c.isHidden()) {
    return GalleryType.hiddenOwnedCollection;
  }
  debugPrint("Unknown gallery type for collection ${c.id}, falling back to "
      "default");
  return GalleryType.ownedCollection;
}
