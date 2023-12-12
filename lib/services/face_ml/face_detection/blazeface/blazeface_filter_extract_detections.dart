import 'dart:math' as math show exp;

import 'package:photos/services/face_ml/face_detection/blazeface/blazeface_anchors.dart';
import 'package:photos/services/face_ml/face_detection/blazeface/blazeface_face_detection_options.dart';
import "package:photos/services/face_ml/face_detection/detection.dart";

/// Filters the raw scores and boxes based on the score threshold and then returns the bounding boxes and keypoints.
List<FaceDetectionRelative> filterExtractDetectionsBlazeFace({
  required FaceDetectionOptionsBlazeFace options,
  required List<dynamic> rawScores,
  required List<dynamic> rawBoxes,
  required List<Anchor> anchors,
}) {
  final outputDetections = <FaceDetectionRelative>[];
  for (var i = 0; i < options.numBoxes; i++) {
    // Filter out low scores
    if (rawScores[i][0] < options.inverseSigmoidMinScoreThreshold) continue;

    // Extract sigmoid score and get anchor
    final score = 1.0 / (1.0 + math.exp(-rawScores[i][0]));
    final anchor = anchors[i];

    // Extract the bounding box data
    final sx = rawBoxes[i][options.boxCoordOffset];
    final sy = rawBoxes[i][options.boxCoordOffset + 1];
    var w = rawBoxes[i][options.boxCoordOffset + 2];
    var h = rawBoxes[i][options.boxCoordOffset + 3];

    var cx = sx + anchor.xCenter * options.inputWidth;
    var cy = sy + anchor.yCenter * options.inputHeight;

    cx /= options.inputWidth;
    cy /= options.inputHeight;
    w /= options.inputWidth;
    h /= options.inputHeight;

    final box = [
      cx - w * 0.5 as double,
      cy - h * 0.5 as double,
      cx + w * 0.5 as double,
      cy + h * 0.5 as double,
    ]; // box gives the bounding box coordinates: [xMin, yMin, xMax, yMax]

    // Extract the keypoints data
    final completeKeyPoints = <List<double>>[];
    for (var k = 0; k < options.numKeypoints; k++) {
      final offset =
          options.keypointCoordOffset + k * options.numValuesPerKeypoint;
      var lx = rawBoxes[i][offset] + anchor.xCenter * options.inputWidth;
      var ly = rawBoxes[i][offset + 1] + anchor.yCenter * options.inputHeight;
      lx /= options.inputWidth;
      ly /= options.inputHeight;
      completeKeyPoints.add([
        lx as double,
        ly as double,
      ]);
    }

    final detection = FaceDetectionRelative(
      score: score,
      box: box,
      allKeypoints: completeKeyPoints,
    );

    outputDetections.add(detection);
  }

  return outputDetections;
}
