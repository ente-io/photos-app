import 'package:flutter/material.dart';
import "package:logging/logging.dart";
import "package:photos/extensions/stop_watch.dart";
import "package:photos/face/db.dart";
import "package:photos/face/utils/import_from_zip.dart";
import "package:photos/services/face_ml/face_clusterting_linear/linear_clustering.dart";
import 'package:photos/theme/ente_theme.dart';
import 'package:photos/ui/components/captioned_text_widget.dart';
import 'package:photos/ui/components/expandable_menu_item_widget.dart';
import 'package:photos/ui/components/menu_item_widget/menu_item_widget.dart';
import 'package:photos/ui/settings/common_settings.dart';
import "package:photos/utils/dialog_util.dart";
import 'package:photos/utils/toast_util.dart';

class FaceDebugSectionWidget extends StatelessWidget {
  const FaceDebugSectionWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExpandableMenuItemWidget(
      title: "FaceDebug",
      selectionOptionsWidget: _getSectionOptions(context),
      leadingIcon: Icons.bug_report_outlined,
    );
  }

  Widget _getSectionOptions(BuildContext context) {
    final Logger _logger = Logger("FaceDebugSectionWidget");
    return Column(
      children: [
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "Pull Embeddings From Local",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            try {
              await FaceMLDataDB.instance.bulkInsertFaces([]);
              final EnteWatch watch = EnteWatch("face_time")..start();

              final results = await downloadZip();
              watch.logAndReset('downloaded and de-serialized');
              await FaceMLDataDB.instance.bulkInsertFaces(results);
              watch.logAndReset('inserted in to db');
              showShortToast(context, "Got ${results.length} results");
            } catch (e, s) {
              _logger.warning('download failed ', e, s);
              await showGenericErrorDialog(context: context, error: e);
            }
            // _showKeyAttributesDialog(context);
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "Read embeddings from DB",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            final EnteWatch watch = EnteWatch("read_embeddings")..start();
            final result = await FaceMLDataDB.instance.getFaceEmbeddingMap();
            watch.logAndReset('read embeddings ${result.length} ');
            showShortToast(context, "Done");
          },
        ),
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "Full clustering (min:0.75)",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            final EnteWatch watch = EnteWatch("cluster")..start();
            final result = await FaceMLDataDB.instance.getFaceEmbeddingMap(
              minScore: 0.75,
            );
            watch.logAndReset('read embeddings ${result.length} ');
            final faceIdToCluster =
                await FaceLinearClustering.instance.predict(result);
            watch.logAndReset('done with clustering ${result.length} ');
            await FaceMLDataDB.instance
                .updatePersonIDForFaceIDIFNotSet(faceIdToCluster!);
            showShortToast(context, "Done");
          },
        ),
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "< 2 faces clustering",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            final fileToFaceCount =
                await FaceMLDataDB.instance.getFileIdToCount();
            // print number of files with faces count
            final Map<int, int> faceCountToFilesCount = {};
            final Map<int, List<int>> faceCountToFiles = {};
            for (final fileID in fileToFaceCount.keys) {
              final faceCount = fileToFaceCount[fileID]!;
              faceCountToFilesCount[faceCount] =
                  (faceCountToFilesCount[faceCount] ?? 0) + 1;
              faceCountToFiles[faceCount] = (faceCountToFiles[faceCount] ?? [])
                ..add(fileID);
            }
            final List<int> singleFaceFiles = faceCountToFiles[1] ?? [];
            final List<int> twoFaceFiles = faceCountToFiles[2] ?? [];

            final EnteWatch watch = EnteWatch("cluster")..start();
            final result =
                await FaceMLDataDB.instance.getFaceEmbeddingMapForFile(
              singleFaceFiles..addAll(twoFaceFiles),
            );
            // final result = await FaceMLDataDB.instance.getFaceEmbeddingMap();
            watch.logAndReset('read embeddings ${result.length} ');
            final faceIdToCluster =
                await FaceLinearClustering.instance.predict(result);
            await FaceMLDataDB.instance
                .updatePersonIDForFaceIDIFNotSet(faceIdToCluster!);
            watch.logAndReset('done with clustering ${result.length} ');

            showShortToast(context, "done");
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "Drop clusters",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            await FaceMLDataDB.instance.resetClusterIDs();
            showShortToast(context, "Done");
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "Drop and recreate DB",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            await FaceMLDataDB.instance.resetClusterIDs();
            await FaceMLDataDB.instance.dropClustersAndPeople();
            showShortToast(context, "Done");
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "Drop everything",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            await FaceMLDataDB.instance.dropClustersAndPeople(faces: true);
            showShortToast(context, "Done");
          },
        ),
      ],
    );
  }
}
