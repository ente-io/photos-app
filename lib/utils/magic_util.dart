import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:photos/core/event_bus.dart';
import "package:photos/events/collection_meta_event.dart";
import 'package:photos/events/force_reload_home_gallery_event.dart';
import "package:photos/generated/l10n.dart";
import 'package:photos/models/collection.dart';
import 'package:photos/models/file.dart';
import "package:photos/models/metadata/common_keys.dart";
import "package:photos/models/metadata/file_magic.dart";
import 'package:photos/services/collections_service.dart';
import 'package:photos/services/file_magic_service.dart';
import 'package:photos/ui/common/progress_dialog.dart';
import 'package:photos/utils/dialog_util.dart';
import 'package:photos/utils/toast_util.dart';

final _logger = Logger('MagicUtil');

Future<void> changeVisibility(
  BuildContext context,
  List<File> files,
  int newVisibility,
) async {
  final dialog = createProgressDialog(
    context,
    newVisibility == archiveVisibility
        ? S.of(context).archiving
        : S.of(context).unarchiving,
  );
  await dialog.show();
  try {
    await FileMagicService.instance.changeVisibility(files, newVisibility);
    showShortToast(
      context,
      newVisibility == archiveVisibility
          ? S.of(context).successfullyArchived
          : S.of(context).successfullyUnarchived,
    );

    await dialog.hide();
  } catch (e, s) {
    _logger.severe("failed to update file visibility", e, s);
    await dialog.hide();
    rethrow;
  }
}

Future<void> changeCollectionVisibility(
  BuildContext context,
  Collection collection,
  int newVisibility,
) async {
  final dialog = createProgressDialog(
    context,
    newVisibility == archiveVisibility
        ? S.of(context).archiving
        : S.of(context).unarchiving,
  );
  await dialog.show();
  try {
    final Map<String, dynamic> update = {magicKeyVisibility: newVisibility};
    await CollectionsService.instance.updateMagicMetadata(collection, update);
    // Force reload home gallery to pull in the now unarchived files
    Bus.instance.fire(ForceReloadHomeGalleryEvent("CollectionArchiveChange"));
    showShortToast(
      context,
      newVisibility == archiveVisibility
          ? S.of(context).successfullyArchived
          : S.of(context).successfullyUnarchived,
    );

    await dialog.hide();
  } catch (e, s) {
    _logger.severe("failed to update collection visibility", e, s);
    await dialog.hide();
    rethrow;
  }
}

Future<void> changeSortOrder(
  BuildContext context,
  Collection collection,
  bool sortedInAscOrder,
) async {
  try {
    final Map<String, dynamic> update = {"asc": sortedInAscOrder};
    await CollectionsService.instance
        .updatePublicMagicMetadata(collection, update);
    Bus.instance.fire(
      CollectionMetaEvent(collection.id, CollectionMetaEventType.sortChanged),
    );
  } catch (e, s) {
    _logger.severe("failed to update collection visibility", e, s);
    showShortToast(context, S.of(context).somethingWentWrong);
    rethrow;
  }
}

Future<bool> editTime(
  BuildContext context,
  List<File> files,
  int editedTime,
) async {
  try {
    await _updatePublicMetadata(
      context,
      files,
      editTimeKey,
      editedTime,
    );
    return true;
  } catch (e) {
    showShortToast(context, S.of(context).somethingWentWrong);
    return false;
  }
}

Future<void> editFilename(
  BuildContext context,
  File file,
) async {
  final fileName = file.displayName;
  final nameWithoutExt = basenameWithoutExtension(fileName);
  final extName = extension(fileName);
  final result = await showTextInputDialog(
    context,
    title: S.of(context).renameFile,
    submitButtonLabel: S.of(context).rename,
    initialValue: nameWithoutExt,
    message: extName.toUpperCase(),
    alignMessage: Alignment.centerRight,
    hintText: S.of(context).enterFileName,
    maxLength: 50,
    alwaysShowSuccessState: true,
    onSubmit: (String text) async {
      if (text.isEmpty || text.trim() == nameWithoutExt.trim()) {
        return;
      }
      final newName = text + extName;
      await _updatePublicMetadata(
        context,
        List.of([file]),
        editNameKey,
        newName,
        showProgressDialogs: false,
        showDoneToast: false,
      );
    },
  );
  if (result is Exception) {
    _logger.severe("Failed to rename file");
    showGenericErrorDialog(context: context);
  }
}

Future<bool> editFileCaption(
  BuildContext? context,
  File file,
  String caption,
) async {
  try {
    await _updatePublicMetadata(
      context,
      [file],
      captionKey,
      caption,
      showDoneToast: false,
    );
    return true;
  } catch (e) {
    if (context != null) {
      showShortToast(context, S.of(context).somethingWentWrong);
    }
    return false;
  }
}

Future<void> _updatePublicMetadata(
  BuildContext? context,
  List<File> files,
  String key,
  dynamic value, {
  bool showDoneToast = true,
  bool showProgressDialogs = true,
}) async {
  if (files.isEmpty) {
    return;
  }
  ProgressDialog? dialog;
  if (context != null && showProgressDialogs) {
    dialog = createProgressDialog(context, S.of(context).pleaseWait);
    await dialog.show();
  }
  try {
    final Map<String, dynamic> update = {key: value};
    await FileMagicService.instance.updatePublicMagicMetadata(files, update);
    if (context != null) {
      if (showDoneToast) {
        showShortToast(context, S.of(context).done);
      }
      await dialog?.hide();
    }

    if (_shouldReloadGallery(key)) {
      Bus.instance.fire(ForceReloadHomeGalleryEvent("FileMetadataChange-$key"));
    }
  } catch (e, s) {
    _logger.severe("failed to update $key = $value", e, s);
    if (context != null) {
      await dialog?.hide();
    }
    rethrow;
  }
}

bool _shouldReloadGallery(String key) {
  return key == editTimeKey;
}
