import "dart:developer";
import "dart:typed_data";

import 'package:flutter/widgets.dart';
import "package:logging/logging.dart";
import "package:photos/face/db.dart";
import "package:photos/face/model/face.dart";
import 'package:photos/models/file/file.dart';
import 'package:photos/ui/viewer/file/thumbnail_widget.dart';
import "package:photos/utils/face/face_box_crop.dart";

class PersonFaceWidget extends StatelessWidget {
  final EnteFile file;
  final String? personId;
  final int? clusterID;

  const PersonFaceWidget(
    this.file, {
    this.personId,
    this.clusterID,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: getFaceCrop(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final ImageProvider imageProvider = MemoryImage(snapshot.data!);
          return Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ],
          );
        } else {
          if (snapshot.hasError) {
            log('Error getting cover face for person: ${snapshot.error}');
          }
          return ThumbnailWidget(
            file,
          );
        }
      },
    );
  }

  Future<Uint8List?> getFaceCrop() async {
    final Face? face = await FaceMLDataDB.instance.getCoverFaceForPerson(
      recentFileID: file.uploadedFileID!,
      personID: personId,
      clusterID: clusterID,
    );
    if (face == null) {
      debugPrint("No cover face for person: $personId and cluster $clusterID");
      return null;
    }
    final result = await getFaceCrops(
      file,
      {
        face.faceID: face.detection.box,
      },
    );
    return result?[face.faceID];
  }
}
