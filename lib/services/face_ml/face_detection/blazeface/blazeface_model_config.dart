import 'package:photos/services/face_ml/face_detection/blazeface/blazeface_anchors.dart';
import 'package:photos/services/face_ml/face_detection/blazeface/blazeface_face_detection_options.dart';
import "package:photos/services/face_ml/model_file.dart";

class BlazeFaceModelConfig {
  final String modelPath;
  final FaceDetectionOptionsBlazeFace faceOptions;
  final AnchorOptions anchorOptions;

  BlazeFaceModelConfig({
    required this.modelPath,
    required this.faceOptions,
    required this.anchorOptions,
  });
}

final BlazeFaceModelConfig faceDetectionBackWeb = BlazeFaceModelConfig(
  modelPath: ModelFile.faceDetectionBackWeb,
  faceOptions: FaceDetectionOptionsBlazeFace(
    numBoxes: 896,
    minScoreSigmoidThreshold:
        0.4, // TODO: double check this. first pass should be 0.4, second pass should be 0.75
    minScoreSigmoidThresholdSecondPass: 0.75,
    iouThreshold: 0.3,
    inputWidth: 256,
    inputHeight: 256,
  ),
  anchorOptions: AnchorOptions(
    inputSizeHeight: 256,
    inputSizeWidth: 256,
    minScale: 0.15625,
    maxScale: 0.75,
    anchorOffsetX: 0.5,
    anchorOffsetY: 0.5,
    numLayers: 4,
    featureMapHeight: [],
    featureMapWidth: [],
    strides: [16, 32, 32, 32],
    aspectRatios: [1.0],
    reduceBoxesInLowestLayer: false,
    interpolatedScaleAspectRatio: 1.0,
    fixedAnchorSize: true,
  ),
);

// final BlazeFaceModelConfig faceDetectionShortRange = BlazeFaceModelConfig(
//   modelPath: ModelFile.faceDetectionShortRange,
//   faceOptions: FaceDetectionOptions(
//     numBoxes: 896,
//     minScoreSigmoidThreshold: 0.60,
//     iouThreshold: 0.3,
//     inputWidth: 128,
//     inputHeight: 128,
//   ),
//   anchorOptions: AnchorOptions(
//     inputSizeHeight: 128,
//     inputSizeWidth: 128,
//     minScale: 0.1484375,
//     maxScale: 0.75,
//     anchorOffsetX: 0.5,
//     anchorOffsetY: 0.5,
//     numLayers: 4,
//     featureMapHeight: [],
//     featureMapWidth: [],
//     strides: [8, 16, 16, 16],
//     aspectRatios: [1.0],
//     reduceBoxesInLowestLayer: false,
//     interpolatedScaleAspectRatio: 1.0,
//     fixedAnchorSize: true,
//   ),
// );

// final BlazeFaceModelConfig faceDetectionFullRangeSparse = BlazeFaceModelConfig(
//   modelPath: ModelFile.faceDetectionFullRangeSparse,
//   faceOptions: FaceDetectionOptions(
//     numBoxes: 2304,
//     minScoreSigmoidThreshold: 0.60,
//     iouThreshold: 0.3,
//     inputWidth: 192,
//     inputHeight: 192,
//   ),
//   anchorOptions: AnchorOptions(
//     inputSizeHeight: 192,
//     inputSizeWidth: 192,
//     minScale: 0.1484375,
//     maxScale: 0.75,
//     anchorOffsetX: 0.5,
//     anchorOffsetY: 0.5,
//     numLayers: 1,
//     featureMapHeight: [],
//     featureMapWidth: [],
//     strides: [4],
//     aspectRatios: [1.0],
//     reduceBoxesInLowestLayer: false,
//     interpolatedScaleAspectRatio: 0.0,
//     fixedAnchorSize: true,
//   ),
// );

// final BlazeFaceModelConfig faceDetectionFullRangeDense = BlazeFaceModelConfig(
//   modelPath: ModelFile.faceDetectionFullRangeDense,
//   faceOptions: FaceDetectionOptions(
//     numBoxes: 2304,
//     minScoreSigmoidThreshold: 0.60,
//     iouThreshold: 0.3,
//     inputWidth: 192,
//     inputHeight: 192,
//   ),
//   anchorOptions: AnchorOptions(
//     inputSizeHeight: 192,
//     inputSizeWidth: 192,
//     minScale: 0.1484375,
//     maxScale: 0.75,
//     anchorOffsetX: 0.5,
//     anchorOffsetY: 0.5,
//     numLayers: 1,
//     featureMapHeight: [],
//     featureMapWidth: [],
//     strides: [4],
//     aspectRatios: [1.0],
//     reduceBoxesInLowestLayer: false,
//     interpolatedScaleAspectRatio: 0.0,
//     fixedAnchorSize: true,
//   ),
// );

// final BlazeFaceModelConfig faceDetectionFront = BlazeFaceModelConfig(
//   modelPath: ModelFile.faceDetectionFront,
//   faceOptions: FaceDetectionOptions(
//     numBoxes: 896,
//     minScoreSigmoidThreshold: 0.60,
//     iouThreshold: 0.3,
//     inputWidth: 128,
//     inputHeight: 128,
//   ),
//   anchorOptions: AnchorOptions(
//     inputSizeHeight: 128,
//     inputSizeWidth: 128,
//     minScale: 0.1484375,
//     maxScale: 0.75,
//     anchorOffsetX: 0.5,
//     anchorOffsetY: 0.5,
//     numLayers: 4,
//     featureMapHeight: [],
//     featureMapWidth: [],
//     strides: [8, 16, 16, 16],
//     aspectRatios: [1.0],
//     reduceBoxesInLowestLayer: false,
//     interpolatedScaleAspectRatio: 1.0,
//     fixedAnchorSize: true,
//   ),
// );
