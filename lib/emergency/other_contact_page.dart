import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:logging/logging.dart";
import "package:photos/emergency/emergency_service.dart";
import "package:photos/emergency/model.dart";
import "package:photos/generated/l10n.dart";
import "package:photos/theme/colors.dart";
import "package:photos/theme/ente_theme.dart";
import "package:photos/ui/components/buttons/button_widget.dart";
import "package:photos/ui/components/captioned_text_widget.dart";
import "package:photos/ui/components/menu_item_widget/menu_item_widget.dart";
import "package:photos/ui/components/menu_section_title.dart";
import "package:photos/ui/components/models/button_type.dart";
import "package:photos/ui/components/title_bar_title_widget.dart";
import "package:photos/utils/date_time_util.dart";
import "package:photos/utils/dialog_util.dart";

// OtherContactPage is used to start recovery process for other user's account
// Based on the state of the contact & recovery session, it will show
// different UI
class OtherContactPage extends StatefulWidget {
  final EmergencyContact contact;
  final EmergencyInfo emergencyInfo;

  const OtherContactPage({
    required this.contact,
    required this.emergencyInfo,
    super.key,
  });

  @override
  State<OtherContactPage> createState() => _OtherContactPageState();
}

class _OtherContactPageState extends State<OtherContactPage> {
  late String recoverDelayTime;
  late String accountEmail = widget.contact.user.email;
  RecoverySessions? recoverySession;
  String? waitTill;
  final Logger _logger = Logger("_OtherContactPageState");

  @override
  void initState() {
    super.initState();
    recoverDelayTime = "${(widget.contact.recoveryNoticeInDays ~/ 24)} days";
    recoverySession = widget.emergencyInfo.othersRecoverySession
        .firstWhereOrNull((session) => session.user.email == accountEmail);
  }

  @override
  Widget build(BuildContext context) {
    _logger.info('session ${widget.emergencyInfo}');
    if (recoverySession != null) {
      final dateTime = DateTime.now().add(
        Duration(
          microseconds: recoverySession!.waitTill,
        ),
      );
      waitTill = getFormattedTime(context, dateTime);
    }
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
                    accountEmail,
                    textAlign: TextAlign.left,
                    style:
                        textTheme.small.copyWith(color: colorScheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            recoverySession == null
                ? Text(
                    "You can recover $accountEmail account  $recoverDelayTime"
                    " after starting recovery process.",
                    style: textTheme.body,
                  )
                : Text(
                    "You can recover $accountEmail's"
                    " account after $waitTill  ",
                    style: textTheme.bodyBold,
                  ),
            const SizedBox(height: 12),
            if (recoverySession == null)
              ButtonWidget(
                // icon: Icons.start_outlined,
                buttonType: ButtonType.trailingIconPrimary,
                icon: Icons.start_outlined,
                labelText: "Start recovery",
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
                                  "Please visit page after $recoverDelayTime to"
                                      " recover $accountEmail's account.",
                                );
                                Navigator.of(context).pop(true);
                              }
                            } catch (e) {
                              showGenericErrorDialog(context: context);
                            }
                          }
                        }
                      },
                // isTopBorderRadiusRemoved: true,
              ),
            SizedBox(height: recoverySession == null ? 48 : 24),
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
                final actionResult = await showChoiceActionSheet(
                  context,
                  title: "Remove",
                  firstButtonLabel: S.of(context).yes,
                  body: "Are you sure your want to stop being a trusted "
                      "contact for $accountEmail?",
                  isCritical: true,
                  firstButtonOnTap: () async {
                    try {
                      await EmergencyContactService.instance.updateContact(
                        widget.contact,
                        ContactState.ContactLeft,
                      );
                      Navigator.of(context).pop(true);
                    } catch (e) {
                      showGenericErrorDialog(context: context);
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
