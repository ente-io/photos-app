import 'package:flutter/material.dart';
import 'package:photos/core/configuration.dart';
import "package:photos/db/ml_data_db.dart";
import "package:photos/services/face_ml/face_feedback.dart/face_feedback_service.dart";
import "package:photos/services/face_ml/face_ml_service.dart";
import "package:photos/services/face_ml/face_search_service.dart";
import 'package:photos/services/ignored_files_service.dart';
import 'package:photos/services/local_sync_service.dart';
import 'package:photos/services/sync_service.dart';
import 'package:photos/services/update_service.dart';
import 'package:photos/theme/ente_theme.dart';
import 'package:photos/ui/components/captioned_text_widget.dart';
import 'package:photos/ui/components/expandable_menu_item_widget.dart';
import 'package:photos/ui/components/menu_item_widget/menu_item_widget.dart';
import 'package:photos/ui/settings/common_settings.dart';
import 'package:photos/utils/crypto_util.dart';
import 'package:photos/utils/toast_util.dart';

class DebugSectionWidget extends StatelessWidget {
  const DebugSectionWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExpandableMenuItemWidget(
      title: "Debug",
      selectionOptionsWidget: _getSectionOptions(context),
      leadingIcon: Icons.bug_report_outlined,
    );
  }

  Widget _getSectionOptions(BuildContext context) {
    return Column(
      children: [
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "Key attributes",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            await UpdateService.instance.resetChangeLog();
            _showKeyAttributesDialog(context);
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "Delete Local Import DB",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            await LocalSyncService.instance.resetLocalSync();
            showShortToast(context, "Done");
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "Allow auto-upload for ignored files",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            await IgnoredFilesService.instance.reset();
            SyncService.instance.sync();
            showShortToast(context, "Done");
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "FaceML: Show cluster count",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            final List<int> peoples =
                await FaceSearchService.instance.getAllPeople();
            // SyncService.instance.sync();
            showShortToast(context, 'people count ${peoples.length}');
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "FaceML: Delete full DB",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            await MlDataDB.instance
                .cleanTables(cleanFaces: true, cleanPeople: true, cleanFeedback: true);
            showShortToast(context, 'Databases cleared');
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "FaceML: Delete face DB",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            await MlDataDB.instance
                .cleanTables(cleanFaces: true);
            showShortToast(context, 'Database cleared');
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "FaceML: Delete clustering DB",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            await MlDataDB.instance
                .cleanTables(cleanPeople: true);
            showShortToast(context, 'Database cleared');
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "FaceML: Delete feedback DB",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            await MlDataDB.instance
                .cleanTables(cleanFeedback: true);
            showShortToast(context, 'Database cleared');
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "FaceML: Start indexing images",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            FaceMlService.instance
                .indexAllImages()
                .onError((error, stackTrace) => debugPrint(error?.toString()));
            showShortToast(context, 'Indexing started');
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "FaceML: Start clustering images",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            showShortToast(context, 'Clustering started');
            await FaceMlService.instance.clusterAllImages();
            showShortToast(context, 'Clustering finished');
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "FeedbackML: remove photo from cluster",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            showShortToast(context, 'Not fully implemented yet');
            // await FaceFeedbackService.instance.removePhotoFromCluster(10, 0);
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "FeedbackML: add photo to cluster",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            showShortToast(context, 'Not fully implemented yet');
            // await FaceFeedbackService.instance.removePhotoFromCluster(10, 0);
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "FeedbackML: Merge two clusters: 0 and 1",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            showShortToast(context, 'Starting merge');
            await FaceFeedbackService.instance.mergeClusters(personIDs: [0, 1]);
            showShortToast(context, 'Finished merge');
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "FeedbackML: delete a cluster: 5",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            showShortToast(context, 'Starting delete');
            await FaceFeedbackService.instance.deleteCluster(personID: 5);
            showShortToast(context, 'Finished delete');
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "FeedbackML: rename a cluster: 6 to 'test'",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            showShortToast(context, 'Starting rename');
            await FaceFeedbackService.instance.renameOrSetThumbnailCluster(
              personID: 6,
              customName: 'test',
            );
            showShortToast(context, 'Finished rename');
          },
        ),
        sectionOptionSpacing,
        MenuItemWidget(
          captionedTextWidget: const CaptionedTextWidget(
            title: "FeedbackML: change thumbnail cluster: 8",
          ),
          pressedColor: getEnteColorScheme(context).fillFaint,
          trailingIcon: Icons.chevron_right_outlined,
          trailingIconIsMuted: true,
          onTap: () async {
            showShortToast(
              context,
              "Can't access thumbnail faceID for testing",
            );
            // await FaceFeedbackService.instance.renameOrSetThumbnailCluster(
            //   personID: 8,
            //   customFaceID: 'test',
            // );
          },
        ),
        sectionOptionSpacing,
      ],
    );
  }

  void _showKeyAttributesDialog(BuildContext context) {
    final keyAttributes = Configuration.instance.getKeyAttributes()!;
    final AlertDialog alert = AlertDialog(
      title: const Text("key attributes"),
      content: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              "Key",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(CryptoUtil.bin2base64(Configuration.instance.getKey()!)),
            const Padding(padding: EdgeInsets.all(12)),
            const Text(
              "Encrypted Key",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(keyAttributes.encryptedKey),
            const Padding(padding: EdgeInsets.all(12)),
            const Text(
              "Key Decryption Nonce",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(keyAttributes.keyDecryptionNonce),
            const Padding(padding: EdgeInsets.all(12)),
            const Text(
              "KEK Salt",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(keyAttributes.kekSalt),
            const Padding(padding: EdgeInsets.all(12)),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text("OK"),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop('dialog');
          },
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}
