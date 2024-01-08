import "dart:developer";

import 'package:flutter/widgets.dart';
import "package:logging/logging.dart";
import "package:photos/face/db.dart";
import "package:photos/face/model/face.dart";
import 'package:photos/models/file/file.dart';
import 'package:photos/ui/viewer/file/thumbnail_widget.dart';

class ClusterOrPersonWidget extends StatelessWidget {
  final EnteFile file;
  final String tagPrefix;
  final String? personId;
  final int? clusterID;

  const ClusterOrPersonWidget(
    this.file,
    this.tagPrefix, {
    this.personId,
    this.clusterID,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Face?>(
      future: FaceMLDataDB.instance.getCoverFaceForPerson(
        recentFileID: file.uploadedFileID!,
        personID: personId,
        clusterID: clusterID,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          Logger("ClusterOrPersonWidget")
              .info("build with face ${snapshot.data!.faceID}");
          return Text(
            snapshot.data!.fileID.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
            ),
          );
        } else if (snapshot.hasError) {
          log('Error getting cover face for person: ${snapshot.error}');
          return Text(snapshot.error.toString());
        } else {
          return ThumbnailWidget(
            file,
          );
        }
      },
    );
  }
}
