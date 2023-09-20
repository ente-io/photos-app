import "dart:typed_data";

import 'package:flutter/widgets.dart';
import 'package:photos/models/file/file.dart';
import "package:photos/services/face_ml/face_search_service.dart";
import 'package:photos/ui/viewer/file/no_thumbnail_widget.dart';
import "package:photos/utils/toast_util.dart";

class PersonThumbnailWidget extends StatelessWidget {
  final EnteFile? file;
  final String tagPrefix;
  final int personID;

  const PersonThumbnailWidget(
    this.file,
    this.personID,
    this.tagPrefix, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tagPrefix + (file?.tag ?? ""),
      child: SizedBox(
        height: 58,
        width: 58,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: FutureBuilder<Uint8List?>(
            future: FaceSearchService.instance.getPersonThumbnail(personID),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                showToast(
                    context,
                    "Got thumbnail for person $personID "
                    "${snapshot.data!.length} bytes");
                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                );
              } else {
                showToast(context, "No thumbnail");
              }
              return const NoThumbnailWidget();
            },
          ),
        ),
      ),
    );
  }
}
