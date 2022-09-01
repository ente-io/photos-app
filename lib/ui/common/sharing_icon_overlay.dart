import 'package:flutter/material.dart';

class SharingIconOverlay extends StatelessWidget {
  final EdgeInsetsGeometry iconPadding;
  final List<double> gradientStops;
  const SharingIconOverlay({
    this.iconPadding = const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    this.gradientStops = const [0.587, 0.944],
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            Colors.black.withOpacity(0.06),
            Colors.black.withOpacity(0.5),
          ],
          stops: gradientStops,
        ),
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: iconPadding,
          child: Icon(
            Icons.people_outline_rounded,
            size: 24,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ),
    );
  }
}
