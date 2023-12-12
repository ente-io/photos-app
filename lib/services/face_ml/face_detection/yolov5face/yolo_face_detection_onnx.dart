import 'dart:typed_data' show Float32List, Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logging/logging.dart';
import 'package:onnxruntime/onnxruntime.dart';
import "package:photos/services/face_ml/face_detection/detection.dart";
import "package:photos/services/face_ml/face_detection/naive_non_max_suppression.dart";
import "package:photos/services/face_ml/face_detection/yolov5face/yolo_face_detection_exceptions.dart";
import "package:photos/services/face_ml/face_detection/yolov5face/yolo_face_detection_options.dart";
import "package:photos/services/face_ml/face_detection/yolov5face/yolo_filter_extract_detections.dart";
import "package:photos/services/face_ml/face_detection/yolov5face/yolo_model_config.dart";
import "package:photos/utils/image_ml_isolate.dart";

class YoloOnnxFaceDetection {
  final _logger = Logger('YOLOFaceDetectionService');

  OrtSessionOptions? _sessionOptions;
  OrtSession? _session;

  late final FaceDetectionOptionsYOLO _faceOptions;

  bool _isInitialized = false;

  final YOLOModelConfig config;
  // singleton pattern
  YoloOnnxFaceDetection._privateConstructor({required this.config});

  /// Use this instance to access the FaceDetection service. Make sure to call `init()` before using it.
  /// e.g. `await FaceDetection.instance.init();`
  ///
  /// Then you can use `predict()` to get the bounding boxes of the faces, so `FaceDetection.instance.predict(imageData)`
  ///
  /// config options: yoloV5FaceN //
  static final instance = YoloOnnxFaceDetection._privateConstructor(
    config: yoloV5FaceS640x640DynamicBatchonnx,
  );
  factory YoloOnnxFaceDetection() {
    OrtEnv.instance.init();
    return instance;
  }

  /// Check if the interpreter is initialized, if not initialize it with `loadModel()`
  Future<void> init() async {
    if (!_isInitialized) {
      await _loadModel();
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      _sessionOptions?.release();
      _sessionOptions = null;
      _session?.release();
      _session = null;
      OrtEnv.instance.release();

      _isInitialized = false;
    }
  }

  /// Detects faces in the given image data.
  Future<List<FaceDetectionRelative>> predict(Uint8List imageData) async {
    assert(_isInitialized && _session != null && _sessionOptions != null);

    final stopwatch = Stopwatch()..start();

    final stopwatchDecoding = Stopwatch()..start();
    final (inputImageList, originalSize, newSize) =
        await ImageMlIsolate.instance.preprocessImageYoloOnnx(
      imageData,
      normalize: true,
      requiredWidth: _faceOptions.inputWidth,
      requiredHeight: _faceOptions.inputHeight,
      maintainAspectRatio: true,
      quality: FilterQuality.medium,
    );

    // final input = [inputImageList];
    final inputShape = [
      1,
      3,
      _faceOptions.inputHeight,
      _faceOptions.inputWidth,
    ];
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      inputImageList,
      inputShape,
    );
    final inputs = {'input': inputOrt};
    stopwatchDecoding.stop();
    _logger.info(
      'Image decoding and preprocessing is finished, in ${stopwatchDecoding.elapsedMilliseconds}ms',
    );
    _logger.info('original size: $originalSize \n new size: $newSize');

    _logger.info('interpreter.run is called');
    // Run inference
    final stopwatchInterpreter = Stopwatch()..start();
    List<OrtValue?>? outputs;
    try {
      final runOptions = OrtRunOptions();
      outputs = await _session?.runAsync(runOptions, inputs);
      inputOrt.release();
      runOptions.release();
    } catch (e, s) {
      _logger.severe('Error while running inference: $e \n $s');
      throw YOLOInterpreterRunException();
    }
    stopwatchInterpreter.stop();
    _logger.info(
      'interpreter.run is finished, in ${stopwatchInterpreter.elapsedMilliseconds} ms',
    );

    _logger.info('outputs: $outputs');

    // // Get output tensors
    final nestedResults =
        outputs?[0]?.value as List<List<List<double>>>; // [1, 25200, 16]
    final firstResults = nestedResults[0]; // [25200, 16]

    // final rawScores = <double>[];
    // for (final result in firstResults) {
    //   rawScores.add(result[4]);
    // }
    // final rawScoresCopy = List<double>.from(rawScores);
    // rawScoresCopy.sort();
    // _logger.info('rawScores minimum: ${rawScoresCopy.first}');
    // _logger.info('rawScores maximum: ${rawScoresCopy.last}');

    var relativeDetections = yoloOnnxFilterExtractDetections(
      options: _faceOptions,
      results: firstResults,
    );

    // Release outputs
    outputs?.forEach((element) {
      element?.release();
    });

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

    // Non-maximum suppression to remove duplicate detections
    relativeDetections = naiveNonMaxSuppression(
      detections: relativeDetections,
      iouThreshold: _faceOptions.iouThreshold,
    );

    if (relativeDetections.isEmpty) {
      _logger.info('No face detected');
      return <FaceDetectionRelative>[];
    }

    stopwatch.stop();
    _logger.info(
      'predict() face detection executed in ${stopwatch.elapsedMilliseconds}ms',
    );

    return relativeDetections;
  }

  /// Detects faces in the given image data.
  /// This method is optimized for batch processing.
  /// 
  /// `imageDataList`: The image data to analyze.
  /// 
  /// WARNING: Currently this method only returns the detections for the first image in the batch.
  /// Change the function to output all detection before actually using it in production.
  Future<List<FaceDetectionRelative>> predictBatch(
    List<Uint8List> imageDataList,
  ) async {
    assert(_isInitialized && _session != null && _sessionOptions != null);

    final stopwatch = Stopwatch()..start();

    final stopwatchDecoding = Stopwatch()..start();
    final List<Float32List> inputImageDataLists = [];
    final List<(Size, Size)> originalAndNewSizeList = [];
    int concatenatedImageInputsLength = 0;
    for (final imageData in imageDataList) {
      final (inputImageList, originalSize, newSize) =
          await ImageMlIsolate.instance.preprocessImageYoloOnnx(
        imageData,
        normalize: true,
        requiredWidth: _faceOptions.inputWidth,
        requiredHeight: _faceOptions.inputHeight,
        maintainAspectRatio: true,
        quality: FilterQuality.medium,
      );
      inputImageDataLists.add(inputImageList);
      originalAndNewSizeList.add((originalSize, newSize));
      concatenatedImageInputsLength += inputImageList.length;
    }

    final inputImageList = Float32List(concatenatedImageInputsLength);

    int offset = 0;
    for (int i = 0; i < inputImageDataLists.length; i++) {
      final inputImageData = inputImageDataLists[i];
      inputImageList.setRange(
        offset,
        offset + inputImageData.length,
        inputImageData,
      );
      offset += inputImageData.length;
    }

    // final input = [inputImageList];
    final inputShape = [
      inputImageDataLists.length,
      3,
      _faceOptions.inputHeight,
      _faceOptions.inputWidth,
    ];
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      inputImageList,
      inputShape,
    );
    final inputs = {'input': inputOrt};
    stopwatchDecoding.stop();
    _logger.info(
      'Image decoding and preprocessing is finished, in ${stopwatchDecoding.elapsedMilliseconds}ms',
    );
    // _logger.info('original size: $originalSize \n new size: $newSize');

    _logger.info('interpreter.run is called');
    // Run inference
    final stopwatchInterpreter = Stopwatch()..start();
    List<OrtValue?>? outputs;
    try {
      final runOptions = OrtRunOptions();
      outputs = await _session?.runAsync(runOptions, inputs);
      inputOrt.release();
      runOptions.release();
    } catch (e, s) {
      _logger.severe('Error while running inference: $e \n $s');
      throw YOLOInterpreterRunException();
    }
    stopwatchInterpreter.stop();
    _logger.info(
      'interpreter.run is finished, in ${stopwatchInterpreter.elapsedMilliseconds} ms, or ${stopwatchInterpreter.elapsedMilliseconds / inputImageDataLists.length} ms per image',
    );

    _logger.info('outputs: $outputs');

    const int imageOutputToUse = 0;

    // // Get output tensors
    final nestedResults =
        outputs?[0]?.value as List<List<List<double>>>; // [b, 25200, 16]
    final selectedResults = nestedResults[imageOutputToUse]; // [25200, 16]

    // final rawScores = <double>[];
    // for (final result in firstResults) {
    //   rawScores.add(result[4]);
    // }
    // final rawScoresCopy = List<double>.from(rawScores);
    // rawScoresCopy.sort();
    // _logger.info('rawScores minimum: ${rawScoresCopy.first}');
    // _logger.info('rawScores maximum: ${rawScoresCopy.last}');

    var relativeDetections = yoloOnnxFilterExtractDetections(
      options: _faceOptions,
      results: selectedResults,
    );

    // Release outputs
    outputs?.forEach((element) {
      element?.release();
    });

    // Account for the fact that the aspect ratio was maintained
    for (final faceDetection in relativeDetections) {
      faceDetection.correctForMaintainedAspectRatio(
        Size(
          _faceOptions.inputWidth.toDouble(),
          _faceOptions.inputHeight.toDouble(),
        ),
        originalAndNewSizeList[imageOutputToUse].$2,
      );
    }

    // Non-maximum suppression to remove duplicate detections
    relativeDetections = naiveNonMaxSuppression(
      detections: relativeDetections,
      iouThreshold: _faceOptions.iouThreshold,
    );

    if (relativeDetections.isEmpty) {
      _logger.info('No face detected');
      return <FaceDetectionRelative>[];
    }

    stopwatch.stop();
    _logger.info(
      'predict() face detection executed in ${stopwatch.elapsedMilliseconds}ms',
    );

    return relativeDetections;
  }

  /// Initialize the interpreter by loading the model file.
  Future<void> _loadModel() async {
    _logger.info('loadModel is called');

    _faceOptions = config.faceOptions;

    try {
      OrtEnv.instance.init();
      OrtEnv.instance.availableProviders().forEach((element) {
        _logger.info('onnx provider= $element');
      });

      _sessionOptions = OrtSessionOptions();
      // ..setInterOpNumThreads(1)
      // ..setIntraOpNumThreads(1)
      // ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
      final rawAssetFile = await rootBundle.load(config.modelPath);
      final bytes = rawAssetFile.buffer.asUint8List();
      _session = OrtSession.fromBuffer(bytes, _sessionOptions!);

      _isInitialized = true;
    } catch (e, s) {
      _logger.severe('Error while initializing YOLO onnx: $e \n $s');
      throw YOLOInterpreterInitializationException();
    }
  }
}
