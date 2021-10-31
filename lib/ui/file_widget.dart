import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:photos/models/file.dart';
import 'package:photos/models/file_type.dart';
import 'package:photos/ui/video_widget.dart';
import 'package:photos/ui/zoomable_image.dart';
import 'package:photos/ui/zoomable_live_image.dart';

class FileWidget extends StatelessWidget {
  final File file;
  final String? tagPrefix;
  final Function(bool)? shouldDisableScroll;
  final Function(bool)? playbackCallback;
  final BoxDecoration? backgroundDecoration;
  final bool? autoPlay;

  const FileWidget(
    @required this.file, {
    this.autoPlay,
    this.shouldDisableScroll,
    this.playbackCallback,
    this.tagPrefix,
    this.backgroundDecoration,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (file.fileType == FileType.image) {
      return ZoomableImage(
        file,
        shouldDisableScroll: shouldDisableScroll,
        tagPrefix: tagPrefix,
        backgroundDecoration: backgroundDecoration,
      );
    } else if (file.fileType == FileType.livePhoto) {
      return ZoomableLiveImage(
        file,
        shouldDisableScroll: shouldDisableScroll,
        tagPrefix: tagPrefix,
        backgroundDecoration: backgroundDecoration,
      );
    } else if (file.fileType == FileType.video) {
      return VideoWidget(
        file,
        autoPlay: autoPlay, // Autoplay if it was opened directly
        tagPrefix: tagPrefix,
        playbackCallback: playbackCallback,
      );
    } else {
      Logger('FileWidget').severe('unsupported file type ${file.fileType}');
      return Icon(Icons.error);
    }
  }
}
