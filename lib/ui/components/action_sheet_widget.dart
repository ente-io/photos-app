import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:photos/theme/colors.dart';
import 'package:photos/theme/effects.dart';
import 'package:photos/theme/ente_theme.dart';
import 'package:photos/utils/separators_util.dart';

enum ActionSheetType {
  defaultActionSheet,
  iconOnly,
}

void showActionSheet({
  required BuildContext context,
  required List<Widget> buttons,
  required ActionSheetType actionSheetType,
  bool isCheckIconGreen = false,
  String? title,
  String? body,
}) {
  showMaterialModalBottomSheet(
    backgroundColor: Colors.transparent,
    barrierColor: backdropMutedDark,
    useRootNavigator: true,
    context: context,
    builder: (_) {
      return ActionSheetWidget(
        title: title,
        body: body,
        actionButtons: buttons,
        actionSheetType: actionSheetType,
        isCheckIconGreen: isCheckIconGreen,
      );
    },
  );
}

class ActionSheetWidget extends StatelessWidget {
  final String? title;
  final String? body;
  final List<Widget> actionButtons;
  final ActionSheetType actionSheetType;
  final bool isCheckIconGreen;

  const ActionSheetWidget({
    required this.actionButtons,
    required this.actionSheetType,
    required this.isCheckIconGreen,
    this.title,
    this.body,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isTitleAndBodyNull = title == null && body == null;
    final blur = MediaQuery.of(context).platformBrightness == Brightness.light
        ? blurMuted
        : blurBase;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      child: Container(
        decoration: BoxDecoration(boxShadow: shadowMenuLight),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              color: backdropBaseDark,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  isTitleAndBodyNull ? 24 : 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isTitleAndBodyNull
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 36),
                            child: ContentContainerWidget(
                              title: title,
                              body: body,
                              actionSheetType: actionSheetType,
                              isCheckIconGreen: isCheckIconGreen,
                            ),
                          ),
                    ActionButtons(
                      actionButtons,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ContentContainerWidget extends StatelessWidget {
  final String? title;
  final String? body;
  final ActionSheetType actionSheetType;
  final bool isCheckIconGreen;
  const ContentContainerWidget({
    required this.actionSheetType,
    required this.isCheckIconGreen,
    this.title,
    this.body,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = getEnteTextTheme(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      //todo: set cross axis to center when icon should be shown in place of body
      crossAxisAlignment: actionSheetType == ActionSheetType.defaultActionSheet
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        title == null
            ? const SizedBox.shrink()
            : Text(
                title!,
                style: textTheme.h3Bold
                    .copyWith(color: textBaseDark), //constant color
              ),
        title == null || body == null
            ? const SizedBox.shrink()
            : const SizedBox(height: 19),
        actionSheetType == ActionSheetType.defaultActionSheet
            ? body == null
                ? const SizedBox.shrink()
                : Text(
                    body!,
                    style: textTheme.body
                        .copyWith(color: textMutedDark), //constant color
                  )
            : Icon(Icons.check_outlined,
                size: 48,
                color: isCheckIconGreen
                    ? getEnteColorScheme(context).primary700
                    : strokeBaseDark)
      ],
    );
  }
}

class ActionButtons extends StatelessWidget {
  final List<Widget> actionButtons;
  const ActionButtons(this.actionButtons, {super.key});

  @override
  Widget build(BuildContext context) {
    final actionButtonsWithSeparators = actionButtons;
    return Column(
      children:
          //Separator height is 8pts in figma. -2pts here as the action
          //buttons are 2pts extra in height in code compared to figma because
          //of the border(1pt top + 1pt bottom) of action buttons.
          addSeparators(actionButtonsWithSeparators, const SizedBox(height: 6)),
    );
  }
}
