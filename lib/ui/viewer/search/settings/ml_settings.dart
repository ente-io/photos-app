import 'dart:io';

import 'package:flutter/material.dart';
import "package:photos/generated/l10n.dart";
import 'package:photos/services/feature_flag_service.dart';
import 'package:photos/theme/ente_theme.dart';
import 'package:photos/ui/components/buttons/icon_button_widget.dart';
import 'package:photos/ui/components/captioned_text_widget.dart';
import 'package:photos/ui/components/menu_item_widget/menu_item_widget.dart';
import "package:photos/ui/components/menu_section_description_widget.dart";
import 'package:photos/ui/components/menu_section_title.dart';
import 'package:photos/ui/components/title_bar_title_widget.dart';
import 'package:photos/ui/components/title_bar_widget.dart';
import 'package:photos/ui/tools/debug/path_storage_viewer.dart';
import 'package:photos/utils/directory_content.dart';
import "package:shared_preferences/shared_preferences.dart";

class MLSettings extends StatefulWidget {
  final SharedPreferences pref;

  const MLSettings({Key? key, required this.pref}) : super(key: key);

  @override
  State<MLSettings> createState() => _MLSettingsState();
}

class _MLSettingsState extends State<MLSettings> {
  final List<PathStorageItem> paths = [];
  late String iosTempDirectoryPath;
  late bool internalUser;
  late bool _isMLEnabled;

  @override
  void initState() {
    internalUser = FeatureFlagService.instance.isInternalUserOrDebugBuild();
    _isMLEnabled = widget.pref.getBool("ml_enabled") ?? false;

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("$runtimeType building");

    return Scaffold(
      body: CustomScrollView(
        primary: false,
        slivers: <Widget>[
          TitleBarWidget(
            flexibleSpaceTitle: TitleBarTitleWidget(
              title: S.of(context).machineLearning,
            ),
            actionIcons: [
              IconButtonWidget(
                icon: Icons.close_outlined,
                iconButtonType: IconButtonType.secondary,
                onTap: () {
                  Navigator.pop(context);
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        children: [
                          MenuItemWidget(
                            key: ValueKey("enabled $_isMLEnabled"),
                            captionedTextWidget: CaptionedTextWidget(
                              title: S.of(context).enableMachineLearning,
                            ),
                            alignCaptionedTextToLeft: true,
                            menuItemColor:
                                getEnteColorScheme(context).fillFaint,
                            trailingWidget: Switch.adaptive(
                              value: _isMLEnabled,
                              onChanged: (value) async {
                                await widget.pref.setBool("ml_enabled", value);
                                setState(() {
                                  _isMLEnabled = value;
                                });
                              },
                            ),
                          ),
                          MenuSectionDescriptionWidget(
                            content: S.of(context).enableMLWarning,
                          ),
                          const SizedBox(height: 24),
                          MenuSectionTitle(
                            title: S.of(context).status,
                          ),
                          MenuItemWidget(
                            alignCaptionedTextToLeft: true,
                            captionedTextWidget: CaptionedTextWidget(
                              title: S.of(context).indexedItems,
                            ),
                            trailingWidget: Text(
                              "13",
                              style: getEnteTextTheme(context).small.copyWith(
                                    color:
                                        getEnteColorScheme(context).textFaint,
                                  ),
                            ),
                            singleBorderRadius: 8,
                            menuItemColor:
                                getEnteColorScheme(context).fillFaint,
                            isBottomBorderRadiusRemoved: true,
                            isTopBorderRadiusRemoved: false,
                          ),
                          MenuItemWidget(
                            alignCaptionedTextToLeft: true,
                            captionedTextWidget: CaptionedTextWidget(
                              title: S.of(context).unindexedItems,
                            ),
                            trailingWidget: Text(
                              "4,405",
                              style: getEnteTextTheme(context).small.copyWith(
                                    color:
                                        getEnteColorScheme(context).textFaint,
                                  ),
                            ),
                            singleBorderRadius: 8,
                            menuItemColor:
                                getEnteColorScheme(context).fillFaint,
                            isBottomBorderRadiusRemoved: false,
                            isTopBorderRadiusRemoved: true,
                          ),
                          const SizedBox(
                            height: 24,
                          ),
                          MenuItemWidget(
                            leadingIcon: Icons.delete_sweep_outlined,
                            captionedTextWidget: CaptionedTextWidget(
                              title: S.of(context).clearIndexes,
                            ),
                            menuItemColor:
                                getEnteColorScheme(context).fillFaint,
                            singleBorderRadius: 8,
                            alwaysShowSuccessState: true,
                            onTap: () async {
                              for (var pathItem in paths) {
                                if (pathItem.allowCacheClear) {
                                  await deleteDirectoryContents(
                                    pathItem.path,
                                  );
                                }
                              }
                              if (!Platform.isAndroid) {
                                await deleteDirectoryContents(
                                  iosTempDirectoryPath,
                                );
                              }
                              if (mounted) {
                                setState(() => {});
                              }
                            },
                          ),
                          const SizedBox(
                            height: 24,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              childCount: 1,
            ),
          ),
        ],
      ),
    );
  }
}
