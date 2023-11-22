import "dart:convert";
import 'dart:io';
import 'dart:typed_data' show Uint8List;

import "package:flutter/cupertino.dart";
import "package:logging/logging.dart";
import "package:path_provider/path_provider.dart";
import "package:photos/services/face_ml/face_detection/anchors.dart";
import "package:photos/services/face_ml/face_detection/blazeface_model_config.dart";
import "package:photos/services/face_ml/face_detection/detection.dart";
import "package:photos/services/face_ml/face_detection/face_detection_exceptions.dart";
import "package:photos/services/face_ml/face_detection/face_detection_options.dart";
import "package:photos/services/face_ml/face_detection/generate_anchors.dart";
import "package:photos/services/face_ml/face_detection/naive_non_max_suppression.dart";
import 'package:photos/utils/image_ml_isolate.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceDetection {
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  int get getAddress => _interpreter!.address;

  final outputShapes = <List<int>>[];
  final outputTypes = <TensorType>[];

  final _logger = Logger("FaceDetectionService");

  late List<Anchor> _anchors;
  late int originalImageWidth;
  late int originalImageHeight;
  late final FaceDetectionOptions _faceOptions;

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
  factory FaceDetection() => instance;

  /// Check if the interpreter is initialized, if not initialize it with `loadModel()`
  Future<void> init() async {
    if (_interpreter == null || _isolateInterpreter == null) {
      await _loadModel();
    }
  }

  Future<void> _encodeAndSaveData(dynamic nestedData, String identifier) async {
    // Convert map keys to strings if nestedData is a map
    final dataToEncode = nestedData is Map
        ? nestedData.map((key, value) => MapEntry(key.toString(), value))
        : nestedData;
    // Step 1: Serialize Your Data
    final String jsonData = jsonEncode(dataToEncode);

    // Step 2: Encode the JSON String to Base64
    // final String base64String = base64Encode(utf8.encode(jsonData));

    // Step 3 & 4: Write the Base64 String to a File and Execute the Function
    try {
      final File file = await _writeBase64StringToFile(jsonData, identifier);
      // Success, handle the file, e.g., print the file path
      debugPrint('[FaceDetectionService]: File saved at ${file.path}');
    } catch (e) {
      // If an error occurs, handle it.
      debugPrint('[FaceDetectionService]: Error saving file: $e');
    }
  }

  Future<File> _writeBase64StringToFile(
    String base64String,
    String identifier,
  ) async {
    final directory = Platform.isAndroid
        ? (await getExternalStorageDirectory())
        : (await getApplicationSupportDirectory());
    final file = File('${directory!.path}/$identifier.json');
    return file.writeAsString(base64String);
  }

  /// Detects faces in the given image data.
  Future<List<FaceDetectionRelative>> predict(Uint8List imageData) async {
    assert(_interpreter != null && _isolateInterpreter != null);
    final stopwatch = Stopwatch()..start();
    final stopwatchDecoding = Stopwatch()..start();
    final List<FilterQuality> qualities = [
      FilterQuality.low,
      FilterQuality.medium,
      FilterQuality.high,
    ];
    final List<bool> aspectFollow = [false, true];
    for (final filter in qualities) {
      for (bool aspect in aspectFollow) {
        final List<List<List<num>>> matrix =
            await ImageMlIsolate.instance.preprocessImage(
          imageData,
          normalize: false,
          requiredWidth: _faceOptions.inputWidth,
          requiredHeight: _faceOptions.inputHeight,
          quality: filter,
          resizeWithAspectRatio: aspect,
        );
        await _encodeAndSaveData(
          matrix,
          "input_${filter.name}_aspect_$aspect",
        );
      }
    }

    throw Exception("done");
    // stopwatchDecoding.stop();
    // _logger.info(
    //   'Image decoding and preprocessing is finished, in ${stopwatchDecoding.elapsedMilliseconds}ms',
    // );
    //
    // final outputFaces = createEmptyOutputMatrix(outputShapes[0]);
    // final outputScores = createEmptyOutputMatrix(outputShapes[1]);
    // final outputs = <int, List>{
    //   0: outputFaces,
    //   1: outputScores,
    // };
    //
    // _logger.info('interpreter.run is called');
    // // Run inference
    // final stopwatchInterpreter = Stopwatch()..start();
    // try {
    //   await _isolateInterpreter!.runForMultipleInputs([input], outputs);
    // } catch (e, s) {
    //   _logger.severe('Error while running inference: $e \n $s');
    //   throw BlazeFaceInterpreterRunException();
    // }
    // stopwatchInterpreter.stop();
    // _logger.info(
    //   'interpreter.run is finished, in ${stopwatchInterpreter.elapsedMilliseconds} ms',
    // );
    //
    // // Get output tensors
    // final rawBoxes = outputs[0]![0]; // Nested List of shape [896, 16]
    // final rawScores = outputs[1]![0]; // Nested List of shape [896, 1]
    //
    // // // Visually inspecting the raw scores
    // // final List<dynamic> flatScores = List.filled(896, 0);
    // // for (var i = 0; i < rawScores.length; i++) {
    // //   flatScores[i] = rawScores[i][0];
    // // }
    // // final flatScoresSorted = flatScores;
    // // flatScoresSorted.sort();
    // // devtools.log('Ten highest (raw) scores: ${flatScoresSorted.sublist(886)}');
    //
    // // // Visually inspecting the raw boxes
    // // final List<dynamic> flatBoxesFirstCoordinates = List.filled(896, 0);
    // // final List<dynamic> flatBoxesSecondCoordinates = List.filled(896, 0);
    // // final List<dynamic> flatBoxesThirdCoordinates = List.filled(896, 0);
    // // final List<dynamic> flatBoxesFourthCoordinates = List.filled(896, 0);
    // // for (var i = 0; i < rawBoxes[0].length; i++) {
    // //   flatBoxesFirstCoordinates[i] = rawBoxes[i][0];
    // //   flatBoxesSecondCoordinates[i] = rawBoxes[i][1];
    // //   flatBoxesThirdCoordinates[i] = rawBoxes[i][2];
    // //   flatBoxesFourthCoordinates[i] = rawBoxes[i][3];
    // // }
    // // devtools.log('rawBoxesFirstCoordinates: $flatBoxesFirstCoordinates');
    //
    // var relativeDetections = filterExtractDetections(
    //   options: _faceOptions,
    //   rawScores: rawScores,
    //   rawBoxes: rawBoxes,
    //   anchors: _anchors,
    // );
    //
    // relativeDetections = naiveNonMaxSuppression(
    //   detections: relativeDetections,
    //   iouThreshold: _faceOptions.iouThreshold,
    // );
    //
    // if (relativeDetections.isEmpty) {
    //   _logger.info('No face detected');
    //   return <FaceDetectionRelative>[];
    // }
    //
    // stopwatch.stop();
    // _logger.info(
    //   'predict() face detection executed in ${stopwatch.elapsedMilliseconds}ms',
    // );
    //
    // return relativeDetections;
  }

  Future<List<FaceDetectionRelative>> predictInTwoPhases(
    Uint8List thumbnailDataxx,
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
          await FaceDetection.instance.predict(paddedImage);
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
      _anchors = generateAnchors(anchorOption);

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
