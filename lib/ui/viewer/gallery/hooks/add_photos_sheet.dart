import "dart:math";

import "package:flutter/material.dart";
import "package:modal_bottom_sheet/modal_bottom_sheet.dart";
import "package:photos/core/configuration.dart";
import "package:photos/db/files_db.dart";
import "package:photos/generated/l10n.dart";
import "package:photos/models/collection.dart";
import "package:photos/models/file.dart";
import "package:photos/models/selected_files.dart";
import "package:photos/services/collections_service.dart";
import "package:photos/services/filter/db_filters.dart";
import "package:photos/theme/colors.dart";
import "package:photos/theme/ente_theme.dart";
import "package:photos/ui/components/bottom_of_title_bar_widget.dart";
import "package:photos/ui/components/buttons/button_widget.dart";
import "package:photos/ui/components/models/button_type.dart";
import "package:photos/ui/components/title_bar_title_widget.dart";
import "package:photos/ui/viewer/gallery/gallery.dart";

Future<List<File>?> showAddPhotosSheet(
  BuildContext context,
  Collection collection,
) async {
  return await showBarModalBottomSheet(
    context: context,
    builder: (context) {
      return AddPhotosPhotoWidget(collection);
    },
    shape: const RoundedRectangleBorder(
      side: BorderSide(width: 0),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(5),
      ),
    ),
    topControl: const SizedBox.shrink(),
    backgroundColor: getEnteColorScheme(context).backgroundElevated,
    barrierColor: backdropFaintDark,
    enableDrag: false,
  );
}

class AddPhotosPhotoWidget extends StatelessWidget {
  final Collection collection;

  const AddPhotosPhotoWidget(
    this.collection, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<bool> isFileSelected = ValueNotifier(false);
    final selectedFiles = SelectedFiles();
    selectedFiles.addListener(() {
      isFileSelected.value = selectedFiles.files.isNotEmpty;
    });
    final Set<int> hiddenCollectionIDs =
        CollectionsService.instance.getHiddenCollections();

    return Padding(
      padding: const EdgeInsets.all(0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: min(428, MediaQuery.of(context).size.width),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 32, 0, 8),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        BottomOfTitleBarWidget(
                          title: TitleBarTitleWidget(
                            title: S.of(context).addMore,
                          ),
                          caption: S.of(context).selectItemsToAdd,
                        ),
                        Expanded(
                          child: Gallery(
                            inSelectionMode: true,
                            asyncLoader: (
                              creationStartTime,
                              creationEndTime, {
                              limit,
                              asc,
                            }) {
                              return FilesDB.instance
                                  .getAllPendingOrUploadedFiles(
                                creationStartTime,
                                creationEndTime,
                                Configuration.instance.getUserID()!,
                                limit: limit,
                                asc: asc,
                                filterOptions: DBFilterOptions(
                                  hideIgnoredForUpload: true,
                                  dedupeUploadID: true,
                                  ignoredCollectionIDs: hiddenCollectionIDs,
                                ),
                                applyOwnerCheck: true,
                              );
                            },
                            tagPrefix: "pick_add_photos_gallery",
                            selectedFiles: selectedFiles,
                            showSelectAllByDefault: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    child: Container(
                      //inner stroke of 1pt + 15 pts of top padding = 16 pts
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: getEnteColorScheme(context).strokeFaint,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          ValueListenableBuilder(
                            valueListenable: isFileSelected,
                            builder: (context, bool value, _) {
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeInOutExpo,
                                switchOutCurve: Curves.easeInOutExpo,
                                child: ButtonWidget(
                                  key: ValueKey(value),
                                  isDisabled: !value,
                                  buttonType: ButtonType.neutral,
                                  labelText: S.of(context).addSelected,
                                  onTap: () async {
                                    final selectedFile = selectedFiles.files;
                                    Navigator.pop(context, selectedFile);
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          ButtonWidget(
                            buttonType: ButtonType.secondary,
                            buttonAction: ButtonAction.cancel,
                            labelText: S.of(context).cancel,
                            onTap: () async {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
