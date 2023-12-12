import "dart:io";
import 'dart:typed_data' show Uint8List;
import "dart:ui" show FilterQuality, Size;

import "package:logging/logging.dart";
import 'package:photos/services/face_ml/face_detection/blazeface/blazeface_anchors.dart';
import 'package:photos/services/face_ml/face_detection/blazeface/blazeface_face_detection_exceptions.dart';
import 'package:photos/services/face_ml/face_detection/blazeface/blazeface_face_detection_options.dart';
import 'package:photos/services/face_ml/face_detection/blazeface/blazeface_filter_extract_detections.dart';
import 'package:photos/services/face_ml/face_detection/blazeface/blazeface_generate_anchors.dart';
import 'package:photos/services/face_ml/face_detection/blazeface/blazeface_model_config.dart';
import "package:photos/services/face_ml/face_detection/detection.dart";
import "package:photos/services/face_ml/face_detection/naive_non_max_suppression.dart";
import 'package:photos/utils/image_ml_isolate.dart';
import 'package:photos/utils/image_ml_util.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class BlazeFaceFaceDetection {
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  int get getAddress => _interpreter!.address;

  final outputShapes = <List<int>>[];
  final outputTypes = <TensorType>[];

  final _logger = Logger("FaceDetectionService");

  late List<Anchor> _anchors;
  late int originalImageWidth;
  late int originalImageHeight;
  late final FaceDetectionOptionsBlazeFace _faceOptions;

  final BlazeFaceModelConfig config;
  // singleton pattern
  BlazeFaceFaceDetection._privateConstructor({required this.config});

  /// Use this instance to access the FaceDetection service. Make sure to call `init()` before using it.
  /// e.g. `await FaceDetection.instance.init();`
  ///
  /// Then you can use `predict()` to get the bounding boxes of the faces, so `FaceDetection.instance.predict(imageData)`
  ///
  /// config options: faceDetectionFront // faceDetectionBackWeb // faceDetectionShortRange //faceDetectionFullRangeSparse; // faceDetectionFullRangeDense (faster than web while still accurate)
  static final instance =
      BlazeFaceFaceDetection._privateConstructor(config: faceDetectionBackWeb);
  factory BlazeFaceFaceDetection() => instance;

  /// Check if the interpreter is initialized, if not initialize it with `loadModel()`
  Future<void> init() async {
    if (_interpreter == null || _isolateInterpreter == null) {
      await _loadModel();
    }
  }

  /// Detects faces in the given image data.
  Future<List<FaceDetectionRelative>> predict(Uint8List imageData) async {
    assert(_interpreter != null && _isolateInterpreter != null);

    final stopwatch = Stopwatch()..start();

    final stopwatchDecoding = Stopwatch()..start();
    final (inputImageMatrix, originalSize, newSize) =
        await ImageMlIsolate.instance.preprocessImageBlazeFace(
      imageData,
      normalize: true,
      requiredWidth: _faceOptions.inputWidth,
      requiredHeight: _faceOptions.inputHeight,
      maintainAspectRatio: true,
      quality: FilterQuality.medium,
    );
    final input = [inputImageMatrix];
    stopwatchDecoding.stop();
    _logger.info(
      'Image decoding and preprocessing (size W*H: ${originalSize.width}x${originalSize.height} ) is finished, in ${stopwatchDecoding.elapsedMilliseconds}ms',
    );
    // await encodeAndSaveData(inputImageMatrix, 'input_resized_float.json');

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
      await _isolateInterpreter!.runForMultipleInputs([input], outputs);
    } catch (e, s) {
      _logger.severe('Error while running inference: $e \n $s');
      throw BlazeFaceInterpreterRunException();
    }
    stopwatchInterpreter.stop();
    _logger.info(
      'interpreter.run is finished, in ${stopwatchInterpreter.elapsedMilliseconds} ms',
    );
    // await encodeAndSaveData(outputs, 'image_resized_raw_outputs');

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

    var relativeDetections = filterExtractDetectionsBlazeFace(
      options: _faceOptions,
      rawScores: rawScores,
      rawBoxes: rawBoxes,
      anchors: _anchors,
    );

    // Account for the fact that the aspect ratio was maintained
    for (final faceDetection in relativeDetections) {
      faceDetection.correctForMaintainedAspectRatio(
        Size(
          _faceOptions.inputWidth.toDouble(),
          _faceOptions.inputHeight.toDouble(),
        ),
        newSize,
      );
    }

    relativeDetections = naiveNonMaxSuppression(
      detections: relativeDetections,
      iouThreshold: _faceOptions.iouThreshold,
    );

    if (relativeDetections.isEmpty) {
      _logger.info('No face detected');
      return <FaceDetectionRelative>[];
    }

    // await encodeAndSaveData(
    //   relativeDetections,
    //   'image_resized_final_detections_pass1',
    // );

    stopwatch.stop();
    _logger.info(
      'predict() face detection executed in ${stopwatch.elapsedMilliseconds}ms',
    );

    return relativeDetections;
  }

  Future<List<FaceDetectionRelative>> predictInTwoPhases(
    Uint8List thumbnailData,
    Uint8List fileData,
  ) async {
    // Get the bounding boxes of the faces
    final List<FaceDetectionRelative> phase1Faces = await predict(fileData);

    final finalDetections = <FaceDetectionRelative>[];
    for (final FaceDetectionRelative phase1Face in phase1Faces) {
      // Enlarge the bounding box by factor 2
      final List<double> imageBox = getEnlargedRelativeBox(phase1Face.box, 2.0);
      // Crop and pad the image
      final paddedImage =
          await ImageMlIsolate.instance.cropAndPadFace(fileData, imageBox);
      // Enlarge the imageBox, to help with transformation to original image
      final List<double> paddedBox = getEnlargedRelativeBox(imageBox, 2.0);

      // Get the bounding boxes of the faces
      final List<FaceDetectionRelative> phase2Faces =
          await BlazeFaceFaceDetection.instance.predict(paddedImage);
      // Transform the bounding boxes to original image
      for (final phase2Detection in phase2Faces) {
        phase2Detection.transformRelativeToOriginalImage(
          imageBox,
          paddedBox,
        );
      }

      FaceDetectionRelative? selected;
      if (phase2Faces.length == 1) {
        selected = phase2Faces[0];
      } else if (phase2Faces.length > 1) {
        selected = phase1Face.getNearestDetection(phase2Faces);
      }

      if (selected != null &&
          selected.score > _faceOptions.minScoreSigmoidThresholdSecondPass) {
        finalDetections.add(selected);
      } else if (phase1Face.score >
          _faceOptions.minScoreSigmoidThresholdSecondPass) {
        finalDetections.add(phase1Face);
        _logger.info(
          'No high confidence face detected in second phase, using first phase detection',
        );
      }
    }

    final finalFilteredDetections = naiveNonMaxSuppression(
      detections: finalDetections,
      iouThreshold: config.faceOptions.iouThreshold,
    );

    if (finalFilteredDetections.isEmpty) {
      _logger.info('No face detected');
      return <FaceDetectionRelative>[];
    }

    return finalFilteredDetections;
  }

  /// Initialize the interpreter by loading the model file.
  Future<void> _loadModel() async {
    _logger.info('loadModel is called');

    final anchorOption = config.anchorOptions;
    _faceOptions = config.faceOptions;

    try {
      final interpreterOptions = InterpreterOptions();

      // Android Delegates
      // TODO: Make sure this works on both platforms: Android and iOS
      if (Platform.isAndroid) {
        // Use GPU Delegate (GPU). WARNING: It doesn't work on emulator. And doesn't speed up current version of BlazeFace used.
        interpreterOptions.addDelegate(GpuDelegateV2());
        // Use XNNPACK Delegate (CPU)
        interpreterOptions.addDelegate(XNNPackDelegate());
      }

      // iOS Delegates
      if (Platform.isIOS) {
        // Use Metal Delegate (GPU)
        interpreterOptions.addDelegate(GpuDelegate());
      }

      // Create anchor boxes for BlazeFace
      _anchors = blazefaceGenerateAnchors(anchorOption);

      // Load model from assets
      _interpreter ??= await Interpreter.fromAsset(
        config.modelPath,
        options: interpreterOptions,
      );
      _isolateInterpreter ??=
          IsolateInterpreter(address: _interpreter!.address);

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
