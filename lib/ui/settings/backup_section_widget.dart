import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/models/backup_status.dart';
import 'package:photos/models/duplicate_files.dart';
import 'package:photos/services/deduplication_service.dart';
import 'package:photos/services/sync_service.dart';
import 'package:photos/ui/backup_folder_selection_page.dart';
import 'package:photos/ui/deduplicate_page.dart';
import 'package:photos/ui/free_space_page.dart';
import 'package:photos/ui/settings/settings_section_title.dart';
import 'package:photos/ui/settings/settings_text_item.dart';
import 'package:photos/utils/data_util.dart';
import 'package:photos/utils/dialog_util.dart';
import 'package:photos/utils/navigation_util.dart';
import 'package:photos/utils/toast_util.dart';
import 'package:url_launcher/url_launcher.dart';

class BackupSectionWidget extends StatefulWidget {
  BackupSectionWidget({Key? key}) : super(key: key);

  @override
  BackupSectionWidgetState createState() => BackupSectionWidgetState();
}

class BackupSectionWidgetState extends State<BackupSectionWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsSectionTitle("backup"),
        Padding(
          padding: EdgeInsets.all(4),
        ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () async {
            routeToPage(
              context,
              BackupFolderSelectionPage(
                buttonText: "backup",
              ),
            );
          },
          child: SettingsTextItem(
              text: "backed up folders", icon: Icons.navigate_next),
        ),
        Platform.isIOS
            ? Padding(padding: EdgeInsets.all(2))
            : Padding(padding: EdgeInsets.all(0)),
        Divider(height: 4),
        Platform.isIOS
            ? Padding(padding: EdgeInsets.all(2))
            : Padding(padding: EdgeInsets.all(4)),
        SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("backup over mobile data"),
              Switch(
                value: Configuration.instance.shouldBackupOverMobileData()!,
                onChanged: (value) async {
                  Configuration.instance.setBackupOverMobileData(value);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        Platform.isIOS
            ? Padding(padding: EdgeInsets.all(2))
            : Padding(padding: EdgeInsets.all(4)),
        Divider(height: 4),
        Platform.isIOS
            ? Padding(padding: EdgeInsets.all(2))
            : Padding(padding: EdgeInsets.all(4)),
        SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("backup videos"),
              Switch(
                value: Configuration.instance.shouldBackupVideos()!,
                onChanged: (value) async {
                  Configuration.instance.setShouldBackupVideos(value);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        Platform.isIOS
            ? Padding(padding: EdgeInsets.all(4))
            : Padding(padding: EdgeInsets.all(2)),
        Divider(height: 4),
        Platform.isIOS
            ? Padding(padding: EdgeInsets.all(2))
            : Padding(padding: EdgeInsets.all(2)),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () async {
            final dialog = createProgressDialog(context, "calculating...");
            await dialog.show();
            final status = await SyncService.instance.getBackupStatus();
            await dialog.hide();
            if (status.localIDs.isEmpty) {
              showErrorDialog(context, "✨ all clear",
                  "you've no files on this device that can be deleted");
            } else {
              bool? result = await routeToPage(context, FreeSpacePage(status));
              if (result == true) {
                _showSpaceFreedDialog(status);
              }
            }
          },
          child: SettingsTextItem(
            text: "free up space",
            icon: Icons.navigate_next,
          ),
        ),
        Platform.isIOS
            ? Padding(padding: EdgeInsets.all(4))
            : Padding(padding: EdgeInsets.all(2)),
        Divider(height: 4),
        Platform.isIOS
            ? Padding(padding: EdgeInsets.all(2))
            : Padding(padding: EdgeInsets.all(2)),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () async {
            final dialog = createProgressDialog(context, "calculating...");
            await dialog.show();
            List<DuplicateFiles> duplicates;
            try {
              duplicates =
                  await DeduplicationService.instance.getDuplicateFiles();
            } catch (e) {
              await dialog.hide();
              showGenericErrorDialog(context);
              return;
            }

            await dialog.hide();
            if (duplicates.isEmpty) {
              showErrorDialog(context, "✨ no duplicates",
                  "you've no duplicate files that can be cleared");
            } else {
              DeduplicationResult? result =
                  await routeToPage(context, DeduplicatePage(duplicates));
              if (result != null) {
                _showDuplicateFilesDeletedDialog(result);
              }
            }
          },
          child: SettingsTextItem(
            text: "deduplicate files",
            icon: Icons.navigate_next,
          ),
        ),
      ],
    );
  }

  void _showSpaceFreedDialog(BackupStatus status) {
    AlertDialog alert = AlertDialog(
      title: Text("success"),
      content: Text(
          "you have successfully freed up " + formatBytes(status.size) + "!"),
      actions: [
        TextButton(
          child: Text(
            "rate us",
            style: TextStyle(
              color: Theme.of(context).buttonColor,
            ),
          ),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop('dialog');
            // TODO: Replace with https://pub.dev/packages/in_app_review
            if (Platform.isAndroid) {
              launch(
                  "https://play.google.com/store/apps/details?id=io.ente.photos");
            } else {
              launch("https://apps.apple.com/in/app/ente-photos/id1542026904");
            }
          },
        ),
        TextButton(
          child: Text(
            "ok",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          onPressed: () {
            if (Platform.isIOS) {
              showToast(
                  "also empty \"Recently Deleted\" from \"Settings\" -> \"Storage\" to claim the freed space");
            }
            Navigator.of(context, rootNavigator: true).pop('dialog');
          },
        ),
      ],
    );
    showConfettiDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
      barrierColor: Colors.black87,
      confettiAlignment: Alignment.topCenter,
      useRootNavigator: true,
    );
  }

  void _showDuplicateFilesDeletedDialog(DeduplicationResult result) {
    String countText = result.count.toString() +
        " duplicate file" +
        (result.count == 1 ? "" : "s");
    AlertDialog alert = AlertDialog(
      title: Text("✨ success"),
      content: Text("you have cleaned up " +
          countText +
          ", saving " +
          formatBytes(result.size) +
          "!"),
      actions: [
        TextButton(
          child: Text(
            "rate us",
            style: TextStyle(
              color: Theme.of(context).buttonColor,
            ),
          ),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop('dialog');
            // TODO: Replace with https://pub.dev/packages/in_app_review
            if (Platform.isAndroid) {
              launch(
                  "https://play.google.com/store/apps/details?id=io.ente.photos");
            } else {
              launch("https://apps.apple.com/in/app/ente-photos/id1542026904");
            }
          },
        ),
        TextButton(
          child: Text(
            "ok",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          onPressed: () {
            showToast("also empty your \"Trash\" to claim the freed up space");
            Navigator.of(context, rootNavigator: true).pop('dialog');
          },
        ),
      ],
    );
    showConfettiDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
      barrierColor: Colors.black87,
      confettiAlignment: Alignment.topCenter,
      useRootNavigator: true,
    );
  }
}
