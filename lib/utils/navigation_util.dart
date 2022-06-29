import 'dart:io';

import 'package:flutter/material.dart';

Future<T> routeToPage<T extends Object>(
  BuildContext context,
  Widget page, {
  bool forceCustomPageRoute = false,
}) {
  if (Platform.isAndroid || forceCustomPageRoute) {
    return Navigator.of(context).push(
      _buildPageRoute(page),
    );
  } else {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return page;
        },
      ),
    );
  }
}

void replacePage(BuildContext context, Widget page) {
  Navigator.of(context).pushReplacement(
    _buildPageRoute(page),
  );
}

PageRouteBuilder<T> _buildPageRoute<T extends Object>(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return page;
    },
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      return Align(
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
    transitionDuration: Duration(milliseconds: 200),
    opaque: false,
  );
}
