import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:photos/models/file.dart';
import 'package:photos/services/face_detection_service.dart';
import 'package:photos/ui/common/loading_widget.dart';
import 'package:photos/utils/file_util.dart';

class FacesCarouselWidget extends StatefulWidget {
  final File file;

  const FacesCarouselWidget(this.file, {Key? key}) : super(key: key);

  @override
  State<FacesCarouselWidget> createState() => _FacesCarouselWidgetState();
}

class _FacesCarouselWidgetState extends State<FacesCarouselWidget> {
  bool _hasProcessedFile = false;
  final List<io.File> _faceCrops = [];

  @override
  void initState() {
    super.initState();
    _processFile();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasProcessedFile) {
      return const EnteLoadingWidget();
    } else if (_faceCrops.isEmpty) {
      return const Text("No people in this photo");
    }
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _faceCrops.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ClipOval(
              child: Image.file(_faceCrops[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _processFile() async {
    final file = await getFile(widget.file);
    _faceCrops.addAll(await FaceDetectionService.instance.getFaceCrops(file));
    _hasProcessedFile = true;
    setState(() {});
  }
}
