import 'package:flutter/cupertino.dart';
import 'package:photos/models/collection.dart';
import 'package:photos/models/file.dart';
import 'package:photos/models/selected_files.dart';
import 'package:photos/services/favorites_service.dart';
import 'package:photos/ui/actions/collection/collection_sharing_actions.dart';
import 'package:photos/ui/common/progress_dialog.dart';
import 'package:photos/ui/components/action_sheet_widget.dart';
import 'package:photos/ui/components/buttons/button_widget.dart';
import 'package:photos/ui/components/models/button_type.dart';
import 'package:photos/utils/dialog_util.dart';
import 'package:photos/utils/toast_util.dart';

extension CollectionFileActions on CollectionActions {
  Future<void> showRemoveFromCollectionSheetV2(
    BuildContext bContext,
    Collection collection,
    SelectedFiles selectedFiles,
    bool removingOthersFile,
  ) async {
    final actionResult = await showActionSheet(
      context: bContext,
      buttons: [
        ButtonWidget(
          labelText: "Remove",
          buttonType:
              removingOthersFile ? ButtonType.critical : ButtonType.neutral,
          buttonSize: ButtonSize.large,
          shouldStickToDarkTheme: true,
          isInAlert: true,
          onTap: () async {
            try {
              await moveFilesFromCurrentCollection(
                bContext,
                collection,
                selectedFiles.files,
              );
            } catch (e) {
              logger.severe("Failed to move files", e);
              rethrow;
            }
          },
        ),
        const ButtonWidget(
          labelText: "Cancel",
          buttonType: ButtonType.secondary,
          buttonSize: ButtonSize.large,
          buttonAction: ButtonAction.second,
          shouldStickToDarkTheme: true,
          isInAlert: true,
        ),
      ],
      title: removingOthersFile ? "Remove from album?" : null,
      body: removingOthersFile
          ? "Some of the items you are removing were "
              "added by other people, and you will lose access to them"
          : "Selected items will be removed from this album",
      actionSheetType: ActionSheetType.defaultActionSheet,
    );
    if (actionResult?.action != null &&
        actionResult!.action == ButtonAction.error) {
      showGenericErrorDialog(context: bContext);
    } else {
      selectedFiles.clearAll();
    }
  }

  Future<bool> updateFavorites(
    BuildContext context,
    List<File> files,
    bool markAsFavorite,
  ) async {
    final ProgressDialog dialog = createProgressDialog(
      context,
      markAsFavorite ? "Adding to favorites..." : "Removing from favorites...",
    );
    await dialog.show();

    try {
      await FavoritesService.instance
          .updateFavorites(context, files, markAsFavorite);
      return true;
    } catch (e, s) {
      logger.severe(e, s);
      showShortToast(
        context,
        "Sorry, could not" +
            (markAsFavorite ? "add  to favorites!" : "remove from favorites!"),
      );
    } finally {
      await dialog.hide();
    }
    return false;
  }
}
