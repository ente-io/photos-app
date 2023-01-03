import 'dart:io';
import 'dart:ui';

import 'package:image/image.dart' as image_lib;
import 'package:photos/services/face_detection/anchors.dart';
import 'package:photos/services/face_detection/generate_anchors.dart';
import 'package:photos/services/face_detection/options.dart';
import 'package:photos/services/face_detection/process.dart';
import 'package:photos/services/face_detection/utils/image_utils.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

// ignore: must_be_immutable
class FaceDetection {
  FaceDetection({this.interpreter}) {
    loadModel();
  }

  final double threshold = 0.7;

  @override
  Interpreter? interpreter;

  @override
  List<Object> get props => [];

  @override
  int get getAddress => interpreter!.address;

  late ImageProcessor _imageProcessor;
  late List<Anchor> _anchors;
  final List<List<int>> _outputShapes = [];
  final List<TfLiteType> _outputTypes = [];

  @override
  Future<void> loadModel() async {
    final anchorOption = AnchorOption(
        inputSizeHeight: 128,
        inputSizeWidth: 128,
        minScale: 0.1484375,
        maxScale: 0.75,
        anchorOffsetX: 0.5,
        anchorOffsetY: 0.5,
        numLayers: 4,
        featureMapHeight: [],
        featureMapWidth: [],
        strides: [8, 16, 16, 16],
        aspectRatios: [1.0],
        reduceBoxesInLowestLayer: false,
        interpolatedScaleAspectRatio: 1.0,
        fixedAnchorSize: true);
    try {
      final interpreterOptions = InterpreterOptions();

      _anchors = generateAnchors(anchorOption);
      interpreter = interpreter ??
          await Interpreter.fromAsset(
            "models/face_detection_back.tflite",
            options: interpreterOptions,
          );

      final outputTensors = interpreter!.getOutputTensors();

      outputTensors.forEach((tensor) {
        _outputShapes.add(tensor.shape);
        _outputTypes.add(tensor.type);
      });
    } catch (e) {
      print('Error while creating interpreter: $e');
    }
  }

  TensorImage getProcessedImage(TensorImage inputImage) {
    final inputShape = interpreter!.getInputTensor(0).shape;
    _imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(inputShape[1], inputShape[2], ResizeMethod.BILINEAR))
        .add(NormalizeOp(127.5, 127.5))
        .build();

    inputImage = _imageProcessor.process(inputImage);
    return inputImage;
  }

  Map<String, dynamic>? predict(image_lib.Image image) {
    if (interpreter == null) {
      print('Interpreter not initialized');
      return null;
    }

    final options = OptionsFace(
        numClasses: 1,
        numBoxes: 896,
        numCoords: 16,
        keypointCoordOffset: 4,
        ignoreClasses: [],
        scoreClippingThresh: 100.0,
        minScoreThresh: 0.75,
        numKeypoints: 6,
        numValuesPerKeypoint: 2,
        reverseOutputOrder: true,
        boxCoordOffset: 0,
        xScale: 128,
        yScale: 128,
        hScale: 128,
        wScale: 128);

    if (Platform.isAndroid) {
      image = image_lib.copyRotate(image, -90);
      image = image_lib.flipHorizontal(image);
    }
    final tensorImage = TensorImage(TfLiteType.float32);
    tensorImage.loadImage(image);
    final inputImage = getProcessedImage(tensorImage);

    TensorBuffer outputFaces = TensorBuffer.createFixedSize(
      interpreter!.getOutputTensor(0).shape,
      interpreter!.getOutputTensor(0).type,
    );
    TensorBuffer outputScores = TensorBuffer.createFixedSize(
      interpreter!.getOutputTensor(1).shape,
      interpreter!.getOutputTensor(1).type,
    );
    TensorBuffer numLocations = TensorBufferFloat(_outputShapes[2]);

    final inputs = <Object>[inputImage.buffer];

    final outputs = <int, Object>{
      0: outputFaces.buffer,
      1: outputScores.buffer,
      3: numLocations.buffer,
    };

    interpreter!.runForMultipleInputs(inputs, outputs);

    final rawBoxes = outputFaces.getDoubleList();
    final rawScores = outputScores.getDoubleList();
    var detections = process(
      options: options,
      rawScores: rawScores,
      rawBoxes: rawBoxes,
      anchors: _anchors,
    );

    // detections = nonMaximumSuppression(detections, threshold);
    // if (detections.isEmpty) {
    //   return null;
    // }

    final rectFaces = <Map<String, dynamic>>[];

    // List<Rect> locations = BoundingBoxUtils.convert(
    //   tensor: outputFaces,
    //   valueIndex: [1, 0, 3, 2],
    //   boundingBoxAxis: 2,
    //   boundingBoxType: BoundingBoxType.CENTER,
    //   coordinateType: CoordinateType.PIXEL,
    //   height: 128,
    //   width: 128,
    // );

    for (var detection in detections) {
      Rect? bbox;
      final score = detection.score;
      if (score > threshold) {
        bbox = Rect.fromLTRB(
          inputImage.width * detection.xMin,
          inputImage.height * detection.yMin,
          inputImage.width * detection.width,
          inputImage.height * detection.height,
        );

        bbox = _imageProcessor.inverseTransformRect(
            bbox, image.height, image.width);
      }
      rectFaces.add({'bbox': bbox, 'score': score});
    }
    rectFaces.sort((a, b) => b['score'].compareTo(a['score']));

    return rectFaces[0];
  }
}

Map<String, dynamic>? runFaceDetector(Map<String, dynamic> params) {
  final faceDetection = FaceDetection(
      interpreter: Interpreter.fromAddress(params['detectorAddress']));
  final image = ImageUtils.convertCameraImage(params['cameraImage'])!;
  final result = faceDetection.predict(image);

  return result;
}
