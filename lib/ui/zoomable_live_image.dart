import 'dart:io' as io;

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/models/file.dart';
import 'package:photos/ui/zoomable_image.dart';
import 'package:photos/utils/file_util.dart';
import 'package:photos/utils/toast_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class ZoomableLiveImage extends StatefulWidget {
  final File file;
  final Function(bool)? shouldDisableScroll;
  final String? tagPrefix;
  final Decoration? backgroundDecoration;

  ZoomableLiveImage(
    this.file, {
    Key? key,
    this.shouldDisableScroll,
    required this.tagPrefix,
    this.backgroundDecoration,
  }) : super(key: key);

  @override
  _ZoomableLiveImageState createState() => _ZoomableLiveImageState();
}

class _ZoomableLiveImageState extends State<ZoomableLiveImage>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger("ZoomableLiveImage");
  File? _file;
  bool _showVideo = false;
  bool _isLoadingVideoPlayer = false;

  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    _file = widget.file;
    _showLivePhotoToast();
    super.initState();
  }

  void _onLongPressEvent(bool isPressed) {
    if (_videoPlayerController != null && isPressed == false) {
      // stop playing video
      _videoPlayerController!.pause();
    }
    if (mounted) {
      setState(() {
        _showVideo = isPressed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    // check is long press is selected but videoPlayer is not configured yet
    if (_showVideo && _videoPlayerController == null) {
      _loadLiveVideo();
    }

    if (_showVideo && _videoPlayerController != null) {
      content = _getVideoPlayer();
    } else {
      content = ZoomableImage(_file,
          tagPrefix: widget.tagPrefix,
          shouldDisableScroll: widget.shouldDisableScroll,
          backgroundDecoration: widget.backgroundDecoration);
    }
    return GestureDetector(
        onLongPressStart: (_) => {_onLongPressEvent(true)},
        onLongPressEnd: (_) => {_onLongPressEvent(false)},
        child: content);
  }

  @override
  void dispose() {
    if (_videoPlayerController != null) {
      _videoPlayerController!.pause();
      _videoPlayerController!.dispose();
    }
    if (_chewieController != null) {
      _chewieController!.dispose();
    }
    super.dispose();
  }

  Widget _getVideoPlayer() {
    _videoPlayerController!.seekTo(Duration.zero);
    _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        autoPlay: true,
        autoInitialize: true,
        looping: true,
        allowFullScreen: false,
        showControls: false);
    return Chewie(controller: _chewieController!);
  }

  Future<void> _loadLiveVideo() async {
    // do nothing is already loading or loaded
    if (_isLoadingVideoPlayer || _videoPlayerController != null) {
      return;
    }
    _isLoadingVideoPlayer = true;
    if (_file!.isRemoteFile() && !(await isFileCached(_file!, liveVideo: true))) {
      showToast("downloading...", toastLength: Toast.LENGTH_LONG);
    }

    var videoFile = await getFile(widget.file, liveVideo: true)!
        .timeout(Duration(seconds: 15))
        .onError((dynamic e, s) {
      _logger.info("getFile failed ${_file!.tag()}", e);
      return null;
    });

    if ((videoFile == null || !videoFile.existsSync()) &&
        _file!.isRemoteFile()) {
      videoFile = await getFileFromServer(widget.file, liveVideo: true)!
          .timeout(Duration(seconds: 15))
          .onError((dynamic e, s) {
        _logger.info("getRemoteFile failed ${_file!.tag()}", e);
        return null;
      });
    }

    if (videoFile != null && videoFile.existsSync()) {
      _setVideoPlayerController(file: videoFile);
    } else {
      showShortToast("download failed");
    }
    _isLoadingVideoPlayer = false;
  }

  VideoPlayerController _setVideoPlayerController({required io.File file}) {
    var videoPlayerController = VideoPlayerController.file(file);
    return _videoPlayerController = videoPlayerController
      ..initialize().whenComplete(() {
        if (mounted) {
          setState(() {
            _showVideo = true;
          });
        }
      });
  }

  void _showLivePhotoToast() async {
    var _preferences = await SharedPreferences.getInstance();
    int promptTillNow = _preferences.getInt(kLivePhotoToastCounterKey) ?? 0;
    if (promptTillNow < kMaxLivePhotoToastCount) {
      showToast("press and hold to play video");
      _preferences.setInt(kLivePhotoToastCounterKey, promptTillNow + 1);
    }
  }
}
