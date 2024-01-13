import "dart:developer";
import "dart:typed_data";

import 'package:flutter/widgets.dart';
import "package:photos/face/model/face.dart";
import 'package:photos/models/file/file.dart';
import "package:photos/ui/viewer/file/no_thumbnail_widget.dart";
import "package:photos/utils/face/face_box_crop.dart";
import "package:photos/utils/thumbnail_util.dart";

class FaceWidget extends StatelessWidget {
  final EnteFile file;
  final Face face;
  final String? personId;
  final int? clusterID;

  const FaceWidget(
    this.file,
    this.face, {
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
          return ClipOval(
            child: SizedBox(
              width: 60,
              height: 60,
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ),
          );
        } else {
          if (snapshot.hasError) {
            log('Error getting face: ${snapshot.error}');
          }
          return const SizedBox(
            width: 60, // Ensure consistent sizing
            height: 60,
            child: NoThumbnailWidget(),
          );
        }
      },
    );
  }

  Future<Uint8List?> getFaceCrop() async {
    try {
      final Uint8List? cachedFace = faceCropCache.get(face.faceID);
      if (cachedFace != null) {
        return cachedFace;
      }
      final faceCropCacheFile = cachedFaceCropPath(face.faceID);
      if ((await faceCropCacheFile.exists())) {
        final data = await faceCropCacheFile.readAsBytes();
        faceCropCache.put(face.faceID, data);
        return data;
      }

      final result = await pool.withResource(
        () async => await getFaceCrops(
          file,
          {
            face.faceID: face.detection.box,
          },
        ),
      );
      final Uint8List? computedCrop = result?[face.faceID];
      if (computedCrop != null) {
        faceCropCache.put(face.faceID, computedCrop);
        faceCropCacheFile.writeAsBytes(computedCrop).ignore();
      }
      return computedCrop;
    } catch (e, s) {
      log(
        "Error getting face for faceID: ${face.faceID}",
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }
}
