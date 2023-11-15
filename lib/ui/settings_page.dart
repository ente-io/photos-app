import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import "package:flutter_animate/flutter_animate.dart";
import 'package:photos/core/configuration.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/opened_settings_event.dart';
import "package:photos/generated/l10n.dart";
import 'package:photos/services/feature_flag_service.dart';
import "package:photos/services/storage_bonus_service.dart";
import "package:photos/services/user_service.dart";
import 'package:photos/theme/colors.dart';
import 'package:photos/theme/ente_theme.dart';
import "package:photos/ui/components/notification_widget.dart";
import "package:photos/ui/growth/referral_screen.dart";
import 'package:photos/ui/settings/about_section_widget.dart';
import 'package:photos/ui/settings/account_section_widget.dart';
import 'package:photos/ui/settings/app_version_widget.dart';
import 'package:photos/ui/settings/backup/backup_section_widget.dart';
import 'package:photos/ui/settings/debug_section_widget.dart';
import 'package:photos/ui/settings/general_section_widget.dart';
import 'package:photos/ui/settings/inherited_settings_state.dart';
import 'package:photos/ui/settings/security_section_widget.dart';
import 'package:photos/ui/settings/settings_title_bar_widget.dart';
import 'package:photos/ui/settings/social_section_widget.dart';
import 'package:photos/ui/settings/storage_card_widget.dart';
import 'package:photos/ui/settings/support_section_widget.dart';
import 'package:photos/ui/settings/theme_switch_widget.dart';
import "package:photos/ui/sharing/verify_identity_dialog.dart";
import "package:photos/utils/navigation_util.dart";
import "package:url_launcher/url_launcher_string.dart";

class SettingsPage extends StatelessWidget {
  final ValueNotifier<String?> emailNotifier;

  const SettingsPage({Key? key, required this.emailNotifier}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Bus.instance.fire(OpenedSettingsEvent());
    final enteColorScheme = getEnteColorScheme(context);
    return Scaffold(
      body: Container(
        color: enteColorScheme.backdropMuted,
        child: SettingsStateContainer(
          child: _getBody(context, enteColorScheme),
        ),
      ),
    );
  }

  Widget _getBody(BuildContext context, EnteColorScheme colorScheme) {
    final hasLoggedIn = Configuration.instance.isLoggedIn();
    final enteTextTheme = getEnteTextTheme(context);
    final List<Widget> contents = [];
    contents.add(
      GestureDetector(
        onDoubleTap: () {
          _showVerifyIdentityDialog(context);
        },
        onLongPress: () {
          _showVerifyIdentityDialog(context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedBuilder(
              // [AnimatedBuilder] accepts any [Listenable] subtype.
              animation: emailNotifier,
              builder: (BuildContext context, Widget? child) {
                return Text(
                  emailNotifier.value!,
                  style: enteTextTheme.body.copyWith(
                    color: colorScheme.textMuted,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    const sectionSpacing = SizedBox(height: 8);
    contents.add(const SizedBox(height: 8));
    if (hasLoggedIn) {
      final shouldShowBFBanner = shouldShowBfBanner();
      final showStorageBonusBanner =
          StorageBonusService.instance.shouldShowStorageBonus();
      contents.addAll([
        const StorageCardWidget(),
        (shouldShowBFBanner || showStorageBonusBanner)
            ? RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: shouldShowBFBanner
                      ? NotificationWidget(
                          isBlackFriday: true,
                          startIcon: Icons.celebration,
                          actionIcon: Icons.arrow_forward_outlined,
                          text: S.of(context).blackFridaySale,
                          subText: S.of(context).upto50OffUntil4thDec,
                          type: NotificationType.goldenBanner,
                          onTap: () async {
                            launchUrlString(
                              "https://ente.io/blackfriday",
                              mode: LaunchMode.platformDefault,
                            );
                          },
                        )
                      : NotificationWidget(
                          startIcon: Icons.auto_awesome,
                          actionIcon: Icons.arrow_forward_outlined,
                          text: S.of(context).doubleYourStorage,
                          subText: S.of(context).referFriendsAnd2xYourPlan,
                          type: NotificationType.goldenBanner,
                          onTap: () async {
                            StorageBonusService.instance
                                .markStorageBonusAsDone();
                            routeToPage(context, const ReferralScreen());
                          },
                        ),
                ).animate(onPlay: (controller) => controller.repeat()).shimmer(
                      duration: 1000.ms,
                      delay: 3200.ms,
                      size: 0.6,
                    ),
              )
            : const SizedBox(height: 12),
        const BackupSectionWidget(),
        sectionSpacing,
        const AccountSectionWidget(),
        sectionSpacing,
      ]);
    }
    contents.addAll([
      const SecuritySectionWidget(),
      sectionSpacing,
      const GeneralSectionWidget(),
      sectionSpacing,
    ]);

    if (Platform.isAndroid || kDebugMode) {
      contents.addAll([
        const ThemeSwitchWidget(),
        sectionSpacing,
      ]);
    }

    contents.addAll([
      const SupportSectionWidget(),
      sectionSpacing,
      const SocialSectionWidget(),
      sectionSpacing,
      const AboutSectionWidget(),
    ]);

    if (hasLoggedIn &&
        FeatureFlagService.instance.isInternalUserOrDebugBuild()) {
      contents.addAll([sectionSpacing, const DebugSectionWidget()]);
    }
    contents.add(const AppVersionWidget());
    contents.add(
      const Padding(
        padding: EdgeInsets.only(bottom: 60),
      ),
    );

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SettingsTitleBarWidget(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: contents,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool shouldShowBfBanner() {
    if (!Platform.isAndroid && !kDebugMode) {
      return false;
    }
    // if date is after 5th of December 2023, 00:00:00, hide banner
    if (DateTime.now().isAfter(DateTime(2023, 12, 5))) {
      return false;
    }
    // if coupon is already applied, can hide the banner
    return (UserService.instance
            .getCachedUserDetails()
            ?.bonusData
            ?.getAddOnBonuses()
            .isEmpty ??
        true);
  }

  Future<void> _showVerifyIdentityDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return VerifyIdentifyDialog(self: true);
      },
    );
  }
}
