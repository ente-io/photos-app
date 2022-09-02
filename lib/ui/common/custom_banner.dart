import 'package:flutter/material.dart';
import 'package:photos/ente_theme_data.dart';

class CustomBanner extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final int contentMaxLines;
  const CustomBanner({
    Key key,
    this.title = "Note",
    this.content,
    this.icon = Icons.info,
    this.contentMaxLines = 2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.stroke2),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 36,
                color: Theme.of(context).colorScheme.stroke2,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.text3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    content == null
                        ? const SizedBox.shrink()
                        : Text(
                            content,
                            overflow: TextOverflow.ellipsis,
                            maxLines: contentMaxLines,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.text2,
                            ),
                          ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
