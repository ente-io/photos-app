import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:photos/states/user_details_state.dart';
import 'package:photos/theme/ente_theme.dart';
import 'package:photos/ui/common/loading_widget.dart';

class SettingsTitleBarWidget extends StatelessWidget {
  const SettingsTitleBarWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final logger = Logger((SettingsTitleBarWidget).toString());

    final inheritedUserDetails = InheritedUserDetails.of(context);
    if (inheritedUserDetails == null) {
      logger.severe((InheritedUserDetails).toString() + " is null");
      throw Error();
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity:
                    const VisualDensity(horizontal: -2, vertical: -2),
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.keyboard_double_arrow_left_outlined),
              ),
              inheritedUserDetails.numberOfUploadedFiles is int
                  ? Text(
                      "${NumberFormat().format(inheritedUserDetails.numberOfUploadedFiles)} memories",
                      style: getEnteTextTheme(context).largeBold,
                    )
                  : const EnteLoadingWidget()
            ],
          ),
        ),
      );
    }
  }
}
