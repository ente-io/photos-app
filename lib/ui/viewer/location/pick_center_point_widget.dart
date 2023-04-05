import "dart:math";

import "package:flutter/material.dart";
import "package:modal_bottom_sheet/modal_bottom_sheet.dart";
import "package:photos/core/configuration.dart";
import "package:photos/db/files_db.dart";
import "package:photos/models/file_load_result.dart";
import "package:photos/models/local_entity_data.dart";
import "package:photos/models/location_tag/location_tag.dart";
import "package:photos/models/selected_files.dart";
import "package:photos/services/collections_service.dart";
import "package:photos/services/ignored_files_service.dart";
import "package:photos/services/location_service.dart";
import "package:photos/theme/colors.dart";
import "package:photos/theme/ente_theme.dart";
import "package:photos/ui/components/bottom_of_title_bar_widget.dart";
import "package:photos/ui/components/buttons/button_widget.dart";
import "package:photos/ui/components/models/button_type.dart";
import "package:photos/ui/components/title_bar_title_widget.dart";
import "package:photos/ui/viewer/gallery/gallery.dart";
import "package:photos/utils/dialog_util.dart";

showPickCenterPointSheet(
  BuildContext context,
  LocalEntity<LocationTag> locationTagEntity,
  VoidCallback onLocationEdited,
) {
  showBarModalBottomSheet(
    context: context,
    builder: (context) {
      return PickCenterPointWidget(locationTagEntity, onLocationEdited);
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

class PickCenterPointWidget extends StatelessWidget {
  final LocalEntity<LocationTag> locationTagEntity;
  final VoidCallback onLocationEdited;

  const PickCenterPointWidget(
    this.locationTagEntity,
    this.onLocationEdited, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<bool> isFileSelected = ValueNotifier(false);
    final selectedFiles = SelectedFiles();
    selectedFiles.addListener(() {
      isFileSelected.value = selectedFiles.files.isNotEmpty;
    });

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
                          title: const TitleBarTitleWidget(
                            title: "Pick center point",
                          ),
                          caption: locationTagEntity.item.name,
                        ),
                        Expanded(
                          child: Gallery(
                            asyncLoader: (
                              creationStartTime,
                              creationEndTime, {
                              limit,
                              asc,
                            }) async {
                              final ownerID =
                                  Configuration.instance.getUserID();
                              final hasSelectedAllForBackup = Configuration
                                  .instance
                                  .hasSelectedAllFoldersForBackup();
                              final collectionsToHide = CollectionsService
                                  .instance
                                  .collectionsHiddenFromTimeline();
                              FileLoadResult result;
                              if (hasSelectedAllForBackup) {
                                result = await FilesDB.instance
                                    .getAllLocalAndUploadedFiles(
                                  creationStartTime,
                                  creationEndTime,
                                  ownerID!,
                                  limit: limit,
                                  asc: asc,
                                  ignoredCollectionIDs: collectionsToHide,
                                );
                              } else {
                                result = await FilesDB.instance
                                    .getAllPendingOrUploadedFiles(
                                  creationStartTime,
                                  creationEndTime,
                                  ownerID!,
                                  limit: limit,
                                  asc: asc,
                                  ignoredCollectionIDs: collectionsToHide,
                                );
                              }

                              // hide ignored files from home page UI
                              final ignoredIDs =
                                  await IgnoredFilesService.instance.ignoredIDs;
                              result.files.removeWhere(
                                (f) =>
                                    f.uploadedFileID == null &&
                                    IgnoredFilesService.instance
                                        .shouldSkipUpload(ignoredIDs, f),
                              );
                              return result;
                            },
                            tagPrefix: "pick_center_point_gallery",
                            selectedFiles: selectedFiles,
                            limitSelectionToOne: true,
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
                                  isInAlert: true,
                                  labelText: "Use selected photo",
                                  onTap: () async {
                                    final selectedFile =
                                        selectedFiles.files.first;
                                    await LocationService.instance
                                        .updateCenterPoint(
                                      locationTagEntity,
                                      selectedFile.location!,
                                    )
                                        .onError((e, s) {
                                      showGenericErrorDialog(context: context);
                                    });
                                    onLocationEdited();
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          const ButtonWidget(
                            buttonType: ButtonType.secondary,
                            buttonAction: ButtonAction.cancel,
                            isInAlert: true,
                            labelText: "Cancel",
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