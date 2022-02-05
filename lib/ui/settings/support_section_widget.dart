import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/ui/settings/settings_section_title.dart';
import 'package:photos/ui/settings/settings_text_item.dart';
import 'package:photos/ui/web_page.dart';
import 'package:photos/utils/email_util.dart';
import 'package:photos/utils/toast_util.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportSectionWidget extends StatelessWidget {
  const SupportSectionWidget({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsSectionTitle("support"),
        Padding(padding: EdgeInsets.all(4)),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () async {
            try {
              final Email email = Email(
                recipients: ['hey@ente.io'],
                isHTML: false,
              );
              await FlutterEmailSender.send(email);
            } catch (e) {
              Logger("SupportSection").severe(e);
              launch("mailto:hey@ente.io");
            }
          },
          child: SettingsTextItem(text: "email", icon: Icons.navigate_next),
        ),
        Divider(height: 4),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) {
                  final endpoint = Configuration.instance.getHttpEndpoint() +
                      "/users/roadmap";
                  final isLoggedIn = Configuration.instance.getToken() != null;
                  final url = isLoggedIn
                      ? endpoint + "?token=" + Configuration.instance.getToken()
                      : kFeatureRequestURL;
                  return WebPage("feature request", url);
                },
              ),
            );
          },
          child: SettingsTextItem(text: "roadmap", icon: Icons.navigate_next),
        ),
        Divider(height: 4),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) {
                  final endpoint = Configuration.instance.getHttpEndpoint() +
                      "/users/roadmap";
                  final isLoggedIn = Configuration.instance.getToken() != null;
                  final url = isLoggedIn
                      ? endpoint + "?token=" + Configuration.instance.getToken()
                      : kRoadmapURL;
                  return WebPage("roadmap", url);
                },
              ),
            );
          },
          child: SettingsTextItem(text: "roadmap", icon: Icons.navigate_next),
        ),
        Divider(height: 4),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            launch("https://reddit.com/r/enteio");
          },
          child: SettingsTextItem(text: "community", icon: Icons.navigate_next),
        ),
        Divider(height: 4),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () async {
            await sendLogs(context, "report bug", "bug@ente.io", postShare: () {
              showToast("thanks for reporting a bug!");
            });
          },
          child: SettingsTextItem(
              text: "report bug 🐞", icon: Icons.navigate_next),
        ),
      ],
    );
  }
}
