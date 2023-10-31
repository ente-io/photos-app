import 'package:flutter/material.dart';
import 'package:photos/core/configuration.dart';
import "package:photos/emergency/model.dart";
import "package:photos/generated/l10n.dart";
import "package:photos/models/api/collection/user.dart";
import 'package:photos/theme/ente_theme.dart';
import 'package:photos/ui/components/captioned_text_widget.dart';
import 'package:photos/ui/components/divider_widget.dart';
import 'package:photos/ui/components/menu_item_widget/menu_item_widget.dart';
import 'package:photos/ui/components/menu_section_title.dart';
import "package:photos/ui/components/notification_widget.dart";
import 'package:photos/ui/components/title_bar_title_widget.dart';
import 'package:photos/ui/components/title_bar_widget.dart';
import "package:photos/ui/sharing/user_avator_widget.dart";

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({
    super.key,
  });

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  late int currentUserID;

  @override
  void initState() {
    currentUserID = Configuration.instance.getUserID()!;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    const isOwner = true;
    final colorScheme = getEnteColorScheme(context);
    final currentUserID = Configuration.instance.getUserID()!;
    final User owner = User(
      id: 1,
      email: "",
    );
    if (owner.id == currentUserID && owner.email == "") {
      owner.email = Configuration.instance.getEmail()!;
    }

    final List<EmergencyContact> viewers = emergencyInfo.grantors;
    final List<EmergencyContact> collaborators = emergencyInfo.userContacts;

    return Scaffold(
      body: CustomScrollView(
        primary: false,
        slivers: <Widget>[
          const TitleBarWidget(
            flexibleSpaceTitle: TitleBarTitleWidget(
              title: "Emergency Contacts",
            ),
          ),
          emergencyInfo.userAccountRecoverySessions.isEmpty
              ? SliverPadding(
                  padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return const SizedBox.shrink();
                      },
                      childCount: 1,
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.only(
                    top: 20,
                    left: 16,
                    right: 16,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: NotificationWidget(
                              startIcon: Icons.warning_amber_rounded,
                              text: "Your emergency contact is trying to "
                                  "access your account",
                              actionIcon: null,
                              onTap: () {},
                            ),
                          );
                        }
                        final RecoverySessions recoverSession = emergencyInfo
                            .userAccountRecoverySessions[index - 1];
                        return MenuItemWidget(
                          captionedTextWidget: CaptionedTextWidget(
                            title: recoverSession.emergencyContact.email,
                            makeTextBold: isOwner,
                            textColor: colorScheme.warning500,
                          ),
                          leadingIconWidget: UserAvatarWidget(
                            recoverSession.emergencyContact,
                            currentUserID: currentUserID,
                          ),
                          leadingIconSize: 24,
                          menuItemColor: colorScheme.fillFaint,
                          singleBorderRadius: 8,
                          isGestureDetectorDisabled: true,
                        );
                      },
                      childCount:
                          1 + emergencyInfo.userAccountRecoverySessions.length,
                    ),
                  ),
                ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0 && (isOwner || collaborators.isNotEmpty)) {
                    return const MenuSectionTitle(
                      title: "Your Emergency Contacts",
                      iconData: Icons.emergency_outlined,
                    );
                  } else if (index > 0 && index <= collaborators.length) {
                    final listIndex = index - 1;
                    final currentUser = collaborators[listIndex];
                    final isLastItem =
                        !isOwner && index == collaborators.length;
                    return Column(
                      children: [
                        MenuItemWidget(
                          captionedTextWidget: CaptionedTextWidget(
                            title: currentUser.emergencyContact.email,
                            subTitle: currentUser.isPendingInvite()
                                ? currentUser.state
                                : null,
                            makeTextBold: currentUser.isPendingInvite(),
                          ),
                          leadingIconSize: 24.0,
                          leadingIconWidget: UserAvatarWidget(
                            currentUser.emergencyContact,
                            type: AvatarType.mini,
                            currentUserID: currentUserID,
                          ),
                          menuItemColor: getEnteColorScheme(context).fillFaint,
                          trailingIcon: isOwner ? Icons.chevron_right : null,
                          trailingIconIsMuted: true,
                          onTap: isOwner
                              ? () async {
                                  if (isOwner) {
                                    // _navigateToManageUser(currentUser);
                                  }
                                }
                              : null,
                          isTopBorderRadiusRemoved: listIndex > 0,
                          isBottomBorderRadiusRemoved: !isLastItem,
                          singleBorderRadius: 8,
                        ),
                        isLastItem
                            ? const SizedBox.shrink()
                            : DividerWidget(
                                dividerType: DividerType.menu,
                                bgColor: getEnteColorScheme(context).fillFaint,
                              ),
                      ],
                    );
                  } else if (index == (1 + collaborators.length) && isOwner) {
                    return MenuItemWidget(
                      captionedTextWidget: CaptionedTextWidget(
                        title: collaborators.isNotEmpty
                            ? S.of(context).addMore
                            : "Add Emergency Contact",
                        makeTextBold: true,
                      ),
                      leadingIcon: Icons.add_outlined,
                      menuItemColor: getEnteColorScheme(context).fillFaint,
                      onTap: () async {
                        // _navigateToAddUser(false);
                      },
                      isTopBorderRadiusRemoved: collaborators.isNotEmpty,
                      singleBorderRadius: 8,
                    );
                  }
                  return const SizedBox.shrink();
                },
                childCount: 1 + collaborators.length + 1,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == 0 && (isOwner || viewers.isNotEmpty)) {
                    return const MenuSectionTitle(
                      title: "You're Their Emergency Contact",
                      iconData: Icons.photo_outlined,
                    );
                  } else if (index > 0 && index <= viewers.length) {
                    final listIndex = index - 1;
                    final currentUser = viewers[listIndex];
                    final isLastItem = !isOwner && index == viewers.length;
                    return Column(
                      children: [
                        MenuItemWidget(
                          captionedTextWidget: CaptionedTextWidget(
                            title: currentUser.user.email,
                            makeTextBold: currentUser.isPendingInvite(),
                            subTitle: currentUser.isPendingInvite()
                                ? currentUser.state
                                : null,
                          ),
                          leadingIconSize: 24.0,
                          leadingIconWidget: UserAvatarWidget(
                            currentUser.user,
                            type: AvatarType.mini,
                            currentUserID: currentUserID,
                          ),
                          menuItemColor: getEnteColorScheme(context).fillFaint,
                          trailingIcon: isOwner ? Icons.chevron_right : null,
                          trailingIconIsMuted: true,
                          onTap: isOwner
                              ? () async {
                                  if (isOwner) {
                                    // _navigateToManageUser(currentUser);
                                  }
                                }
                              : null,
                          isTopBorderRadiusRemoved: listIndex > 0,
                          isBottomBorderRadiusRemoved: !isLastItem,
                          singleBorderRadius: 8,
                        ),
                        isLastItem
                            ? const SizedBox.shrink()
                            : DividerWidget(
                                dividerType: DividerType.menu,
                                bgColor: getEnteColorScheme(context).fillFaint,
                              ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
                childCount: 1 + viewers.length + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
