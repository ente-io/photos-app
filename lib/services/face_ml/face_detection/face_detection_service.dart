import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:image/image.dart' as image_lib;
import "package:logging/logging.dart";
import "package:photos/services/face_ml/face_detection/anchors.dart";
import "package:photos/services/face_ml/face_detection/blazeface_model_config.dart";
import "package:photos/services/face_ml/face_detection/detection.dart";
import "package:photos/services/face_ml/face_detection/face_detection_exceptions.dart";
import "package:photos/services/face_ml/face_detection/filter_extract_detections.dart";
import "package:photos/services/face_ml/face_detection/generate_anchors.dart";
import "package:photos/services/face_ml/face_detection/naive_non_max_suppression.dart";
import "package:photos/utils/image.dart";
import "package:photos/utils/ml_input_output.dart";
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceDetection {
  Interpreter? _interpreter;
  int get getAddress => _interpreter!.address;

  final outputShapes = <List<int>>[];
  final outputTypes = <TensorType>[];

  final _logger = Logger("FaceDetectionService");

  late List<Anchor> _anchors;
  late int originalImageWidth;
  late int originalImageHeight;

  final BlazeFaceModelConfig config;
  // singleton pattern
  FaceDetection._privateConstructor({required this.config});

  /// Use this instance to access the FaceDetection service. Make sure to call `init()` before using it.
  /// e.g. `await FaceDetection.instance.init();`
  ///
  /// Then you can use `predict()` to get the bounding boxes of the faces, so `FaceDetection.instance.predict(imageData)`
  ///
  /// config options: faceDetectionFront // faceDetectionBackWeb // faceDetectionShortRange //faceDetectionFullRangeSparse; // faceDetectionFullRangeDense (faster than web while still accurate)
  static final instance =
      FaceDetection._privateConstructor(config: faceDetectionBackWeb);

  /// Check if the interpreter is initialized, if not initialize it with `loadModel()`
  Future<void> init() async {
    if (_interpreter == null) {
      await _loadModel();
    }
  }

  // TODO: Make the predict function asynchronous with use of isolate-interpreter: https://github.com/tensorflow/flutter-tflite/issues/52
  List<FaceDetectionAbsolute> predict(Uint8List imageData) {
    assert(_interpreter != null);

    final image = convertUint8ListToImagePackageImage(imageData);

    final faceOptions = config.faceOptions;

    final stopwatch = Stopwatch()..start();

    final inputImageMatrix =
        _getPreprocessedImage(image); // [inputWidt, inputHeight, 3]
    final input = [inputImageMatrix];

    final outputFaces = createEmptyOutputMatrix(outputShapes[0]);
    final outputScores = createEmptyOutputMatrix(outputShapes[1]);
    final outputs = <int, List>{
      0: outputFaces,
      1: outputScores,
    };

    _logger.info('interpreter.run is called');
    // Run inference
    final stopwatchInterpreter = Stopwatch()..start();
    try {
      _interpreter!.runForMultipleInputs([input], outputs);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      _logger.severe('Error while running inference: $e');
      throw BlazeFaceInterpreterRunException();
    }
    stopwatchInterpreter.stop();
    _logger.info(
      'interpreter.run is finished, in ${stopwatchInterpreter.elapsedMilliseconds} ms',
    );

    // Get output tensors
    final rawBoxes = outputs[0]![0]; // Nested List of shape [896, 16]
    final rawScores = outputs[1]![0]; // Nested List of shape [896, 1]

    // // Visually inspecting the raw scores
    // final List<dynamic> flatScores = List.filled(896, 0);
    // for (var i = 0; i < rawScores.length; i++) {
    //   flatScores[i] = rawScores[i][0];
    // }
    // final flatScoresSorted = flatScores;
    // flatScoresSorted.sort();
    // devtools.log('Ten highest (raw) scores: ${flatScoresSorted.sublist(886)}');

    // // Visually inspecting the raw boxes
    // final List<dynamic> flatBoxesFirstCoordinates = List.filled(896, 0);
    // final List<dynamic> flatBoxesSecondCoordinates = List.filled(896, 0);
    // final List<dynamic> flatBoxesThirdCoordinates = List.filled(896, 0);
    // final List<dynamic> flatBoxesFourthCoordinates = List.filled(896, 0);
    // for (var i = 0; i < rawBoxes[0].length; i++) {
    //   flatBoxesFirstCoordinates[i] = rawBoxes[i][0];
    //   flatBoxesSecondCoordinates[i] = rawBoxes[i][1];
    //   flatBoxesThirdCoordinates[i] = rawBoxes[i][2];
    //   flatBoxesFourthCoordinates[i] = rawBoxes[i][3];
    // }
    // devtools.log('rawBoxesFirstCoordinates: $flatBoxesFirstCoordinates');

    var relativeDetections = filterExtractDetections(
      options: faceOptions,
      rawScores: rawScores,
      rawBoxes: rawBoxes,
      anchors: _anchors,
    );

    relativeDetections = naiveNonMaxSuppression(
      detections: relativeDetections,
      iouThreshold: faceOptions.iouThreshold,
    );

    if (relativeDetections.isEmpty) {
      _logger.info('No face detected');
      return <FaceDetectionAbsolute>[];
    }

    final absoluteDetections = relativeToAbsoluteDetections(
      detections: relativeDetections,
      originalWidth: originalImageWidth,
      originalHeight: originalImageHeight,
    );

    stopwatch.stop();
    _logger.info(
      'predict() face detection executed in ${stopwatch.elapsedMilliseconds}ms',
    );

    return absoluteDetections;
  }

  List<List<List<num>>> _getPreprocessedImage(
    image_lib.Image image,
  ) {
    _logger.info('preprocessing is called');
    final faceOptions = config.faceOptions;

    originalImageWidth = image.width;
    originalImageHeight = image.height;
    _logger.info(
      'originalImageWidth: $originalImageWidth, originalImageHeight: $originalImageHeight',
    );

    // Resize image for model input
    final image_lib.Image imageInput = image_lib.copyResize(
      image,
      width: faceOptions.inputWidth,
      height: faceOptions.inputHeight,
      interpolation: image_lib.Interpolation
          .linear, // linear interpolation is less accurate than cubic, but faster!
    );

    // Get image matrix representation [inputWidt, inputHeight, 3]
    final imageMatrix = createInputMatrixFromImage(imageInput, normalize: true);

    _logger.info('preprocessing is finished');

    return imageMatrix;
  }

  /// Initialize the interpreter by loading the model file.
  Future<void> _loadModel() async {
    _logger.info('loadModel is called');

    final anchorOption = config.anchorOptions;

    try {
      final interpreterOptions = InterpreterOptions();

      // Android Delegates
      // TODO: Re-enable delegates on new version of tflite_flutter
      if (Platform.isAndroid) {
        // Use XNNPACK Delegate (CPU)
        // interpreterOptions.addDelegate(XNNPackDelegate());
        // Use GPU Delegate (GPU). WARNING: It doesn't work on emulator
        // interpreterOptions.addDelegate(GpuDelegateV2());
      }

      // iOS Delegates
      if (Platform.isIOS) {
        // Use Metal Delegate (GPU)
        interpreterOptions.addDelegate(GpuDelegate());
      }

      // Create anchor boxes for BlazeFace
      _anchors = generateAnchors(anchorOption);

      // Load model from assets
      _interpreter = _interpreter ??
          await Interpreter.fromAsset(
            config.modelPath,
            options: interpreterOptions,
          );

      _logger.info('Interpreter created from asset: ${config.modelPath}');

      // Get tensor input shape [1, 128, 128, 3]
      final inputTensors = _interpreter!.getInputTensors().first;
      _logger.info('Input Tensors: $inputTensors');
      // Get tensour output shape [1, 896, 16]
      final outputTensors = _interpreter!.getOutputTensors();
      final outputTensor = outputTensors.first;
      _logger.info('Output Tensors: $outputTensor');

      for (var tensor in outputTensors) {
        outputShapes.add(tensor.shape);
        outputTypes.add(tensor.type);
      }
      _logger.info('outputShapes: $outputShapes');
      _logger.info('loadModel is finished');
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      _logger.severe('Error while creating interpreter: $e');
      throw BlazeFaceInterpreterInitializationException();
    }
  }
}
