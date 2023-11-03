import "package:flutter/material.dart";
import "package:photos/emergency/emergency_service.dart";
import "package:photos/emergency/model.dart";
import "package:photos/generated/l10n.dart";
import "package:photos/theme/colors.dart";
import "package:photos/theme/ente_theme.dart";
import "package:photos/ui/components/buttons/button_widget.dart";
import "package:photos/ui/components/captioned_text_widget.dart";
import "package:photos/ui/components/menu_item_widget/menu_item_widget.dart";
import 'package:photos/ui/components/menu_section_description_widget.dart';
import "package:photos/ui/components/menu_section_title.dart";
import "package:photos/ui/components/title_bar_title_widget.dart";
import "package:photos/utils/dialog_util.dart";

class OtherContactPage extends StatefulWidget {
  final EmergencyContact contact;

  const OtherContactPage({required this.contact, super.key});

  @override
  _OtherContactPageState createState() => _OtherContactPageState();
}

class _OtherContactPageState extends State<OtherContactPage> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = getEnteColorScheme(context);
    final textTheme = getEnteTextTheme(context);
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 12,
                  ),
                  const TitleBarTitleWidget(
                    title: "Recover account",
                  ),
                  Text(
                    widget.contact.user.email,
                    textAlign: TextAlign.left,
                    style:
                        textTheme.small.copyWith(color: colorScheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            MenuItemWidget(
              captionedTextWidget: const CaptionedTextWidget(
                title: "Start recovery",
              ),
              leadingIcon: Icons.account_circle_outlined,
              leadingIconColor: getEnteColorScheme(context).strokeBase,
              menuItemColor: getEnteColorScheme(context).fillFaint,
              showOnlyLoadingState: true,
              onTap: widget.contact.isPendingInvite()
                  ? null
                  : () async {
                      final actionResult = await showChoiceActionSheet(
                        context,
                        title: "Start recovery",
                        firstButtonLabel: S.of(context).yes,
                        body: "Are you sure you want to initiate recovery?",
                        isCritical: true,
                      );
                      if (actionResult?.action != null) {
                        if (actionResult!.action == ButtonAction.first) {
                          try {
                            await EmergencyContactService.instance
                                .startRecovery(widget.contact);
                            if (mounted) {
                              await showErrorDialog(
                                context,
                                "Done",
                                "You will need for x days before you can finish recovery",
                              );
                              Navigator.of(context).pop(true);
                            }
                          } catch (e) {
                            showGenericErrorDialog(context: context);
                          }
                        }
                      }
                    },
              isTopBorderRadiusRemoved: true,
            ),
            MenuSectionDescriptionWidget(
              content:
                  "You can recover account after ${(widget.contact.recoveryNoticeInDays ~/ 24)} days of initiating "
                  "recovery.",
            ),
            const SizedBox(height: 24),
            MenuSectionTitle(
              title: S.of(context).removeYourselfAsTrustedContact,
            ),
            MenuItemWidget(
              captionedTextWidget: CaptionedTextWidget(
                title: S.of(context).remove,
                textColor: warning500,
                makeTextBold: true,
              ),
              leadingIcon: Icons.not_interested_outlined,
              leadingIconColor: warning500,
              menuItemColor: getEnteColorScheme(context).fillFaint,
              surfaceExecutionStates: false,
              onTap: () async {
                try {
                  await EmergencyContactService.instance
                      .updateContact(widget.contact, ContactState.ContactLeft);
                  Navigator.of(context).pop(true);
                } catch (e) {
                  showGenericErrorDialog(context: context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
