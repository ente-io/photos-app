import "package:flutter/material.dart";
// import "package:flutter/widgets.dart";
import "package:logging/logging.dart";
import "package:photos/face/db.dart";
import "package:photos/face/model/face.dart";
import "package:photos/models/file/file.dart";
import "package:photos/ui/components/buttons/chip_button_widget.dart";
import "package:photos/ui/components/info_item_widget.dart";
import "package:photos/ui/viewer/file_details/face_widget.dart";

class FacesItemWidget extends StatelessWidget {
  final EnteFile file;
  const FacesItemWidget(this.file, {super.key});

  @override
  Widget build(BuildContext context) {
    return InfoItemWidget(
      key: const ValueKey("Faces"),
      leadingIcon: Icons.face_retouching_natural_outlined,
      subtitleSection: _faceWidgets(context, file),
      hasChipButtons: true,
    );
  }

  Future<List<Widget>> _faceWidgets(
    BuildContext context,
    EnteFile file,
  ) async {
    try {
      if (file.uploadedFileID == null) {
        return [
          const ChipButtonWidget(
            "File not uploaded yet",
            noChips: true,
          ),
        ];
      }

      final List<Face> faces = await FaceMLDataDB.instance
          .getFacesForGivenFileID(file.uploadedFileID!);
      if (faces.isEmpty) {
        return [
          const ChipButtonWidget(
            "No faces found",
            noChips: true,
          ),
        ];
      }

      // Sort the faces by score in descending order, so that the highest scoring face is first.
      faces.sort((Face a, Face b) => b.score.compareTo(a.score));

      final faceWidgets = <FaceWidget>[];
      for (final Face face in faces) {
        faceWidgets.add(
          FaceWidget(
            file,
            face,
          ),
        );
      }

      return faceWidgets;
    } catch (e, s) {
      Logger("FacesItemWidget").info(e, s);
      return <FaceWidget>[];
    }
  }

}
