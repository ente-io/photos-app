import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/ui/settings/account_section_widget.dart';
import 'package:photos/ui/settings/app_version_widget.dart';
import 'package:photos/ui/settings/backup_section_widget.dart';
import 'package:photos/ui/settings/danger_section_widget.dart';
import 'package:photos/ui/settings/debug_section_widget.dart';
import 'package:photos/ui/settings/details_section_widget.dart';
import 'package:photos/ui/settings/info_section_widget.dart';
import 'package:photos/ui/settings/security_section_widget.dart';
import 'package:photos/ui/settings/support_section_widget.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("settings"),
      ),
      body: _getBody(),
    );
  }

  Widget _getBody() {
    final hasLoggedIn = Configuration.instance.getToken() != null;
    final List<Widget> contents = [];
    if (hasLoggedIn) {
      contents.addAll([
        DetailsSectionWidget(),
        Padding(padding: EdgeInsets.all(12)),
        BackupSectionWidget(),
        Padding(padding: EdgeInsets.all(12)),
        AccountSectionWidget(),
        Padding(padding: EdgeInsets.all(12)),
      ]);
    }
    contents.addAll([
      SecuritySectionWidget(),
      Padding(padding: EdgeInsets.all(12)),
      SupportSectionWidget(),
      Padding(padding: EdgeInsets.all(12)),
      InfoSectionWidget(),
    ]);
    if (hasLoggedIn) {
      contents.addAll([
        Padding(padding: EdgeInsets.all(12)),
        DangerSectionWidget(),
      ]);
    }
    contents.add(AppVersionWidget());
    if (kDebugMode && hasLoggedIn) {
      contents.add(DebugSectionWidget());
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: contents,
        ),
      ),
    );
  }
}
