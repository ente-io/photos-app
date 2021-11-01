import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:photos/core/network.dart';
import 'package:photos/utils/dialog_util.dart';

class AppVersionWidget extends StatefulWidget {
  const AppVersionWidget({
    Key? key,
  }) : super(key: key);

  @override
  State<AppVersionWidget> createState() => _AppVersionWidgetState();
}

class _AppVersionWidgetState extends State<AppVersionWidget> {
  static const kTapThresholdForInspector = 5;
  static const kConsecutiveTapTimeWindowInMilliseconds = 2000;
  static const kDummyDelayDurationInMilliseconds = 1500;

  int? _lastTap;
  int _consecutiveTaps = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () async {
        int now = DateTime.now().millisecondsSinceEpoch;
        if (now - (_lastTap ?? now) < kConsecutiveTapTimeWindowInMilliseconds) {
          _consecutiveTaps++;
          if (_consecutiveTaps == kTapThresholdForInspector) {
            final dialog =
                createProgressDialog(context, "starting network inspector...");
            await dialog.show();
            await Future.delayed(
                Duration(milliseconds: kDummyDelayDurationInMilliseconds));
            await dialog.hide();
            Network.instance.getAlice().showInspector();
          }
        } else {
          _consecutiveTaps = 1;
        }
        _lastTap = now;
      },
      child: FutureBuilder<String>(
        future: _getAppVersion(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "app version: " + snapshot.data!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            );
          }
          return Container();
        },
      ),
    );
  }

  Future<String> _getAppVersion() async {
    final pkgInfo = await PackageInfo.fromPlatform();
    return pkgInfo.version;
  }
}
