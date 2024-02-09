import "dart:async";
import "dart:developer" as dev show log;
import "dart:isolate";
import 'dart:typed_data' show Float32List, Uint8List;

import "package:computer/computer.dart";
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
import "package:synchronized/synchronized.dart";

enum FaceDetectionOperation { yoloInferenceAndPostProcessing }

class YoloOnnxFaceDetection {
  final _logger = Logger('YOLOFaceDetectionService');

  final _computer = Computer.shared();

  OrtSessionOptions? _sessionOptions;
  int _sessionAddress = 0;

  final FaceDetectionOptionsYOLO _faceOptions;

  bool _isInitialized = false;

  // Isolate things
  Timer? _inactivityTimer;
  final Duration _inactivityDuration = const Duration(seconds: 30);

  final _initLock = Lock();

  late Isolate _isolate;
  late ReceivePort _receivePort = ReceivePort();
  late SendPort _mainSendPort;

  bool isSpawned = false;
  bool isRunning = false;

  final YOLOModelConfig config;
  // singleton pattern
  YoloOnnxFaceDetection._privateConstructor({required this.config})
      : _faceOptions = config.faceOptions;

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
      _logger.info('init is called');
      await _loadModel();
    }
  }

  Future<void> dispose() async {
    _logger.info('dispose is called');
    if (_isInitialized) {
      try {
        _sessionOptions?.release();
        _sessionOptions = null;
        // _session?.release();
        // _session = null;
        OrtEnv.instance.release();

        _isInitialized = false;
      } catch (e, s) {
        _logger.severe('Error while disposing YOLO onnx: $e \n $s');
        rethrow;
      }
    }
  }

  Future<void> initIsolate() async {
    return _initLock.synchronized(() async {
      if (isSpawned) return;

      _receivePort = ReceivePort();

      try {
        _isolate = await Isolate.spawn(
          _isolateMain,
          _receivePort.sendPort,
        );
        _mainSendPort = await _receivePort.first as SendPort;
        isSpawned = true;

        _resetInactivityTimer();
      } catch (e) {
        _logger.severe('Could not spawn isolate', e);
        isSpawned = false;
      }
    });
  }

  Future<void> ensureSpawnedIsolate() async {
    if (!isSpawned) {
      await initIsolate();
    }
  }

  /// The main execution function of the isolate.
  static void _isolateMain(SendPort mainSendPort) async {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      final functionIndex = message[0] as int;
      final function = FaceDetectionOperation.values[functionIndex];
      final args = message[1] as Map<String, dynamic>;
      final sendPort = message[2] as SendPort;

      try {
        switch (function) {
          case FaceDetectionOperation.yoloInferenceAndPostProcessing:
            final inputImageList = args['inputImageList'] as Float32List;
            final inputShape = args['inputShape'] as List<int>;
            final faceOptions = args['faceOptions'] as FaceDetectionOptionsYOLO;
            final newSize = args['newSize'] as Size;
            final sessionAddress = args['sessionAddress'] as int;
            final timeSentToIsolate = args['timeNow'] as DateTime;
            final delaySentToIsolate =
                DateTime.now().difference(timeSentToIsolate).inMilliseconds;

            final Stopwatch stopwatchPrepare = Stopwatch()..start();
            final inputOrt = OrtValueTensor.createTensorWithDataList(
              inputImageList,
              inputShape,
            );
            final inputs = {'input': inputOrt};
            stopwatchPrepare.stop();
            dev.log(
              '[YOLOFaceDetectionService] data preparation is finished, in ${stopwatchPrepare.elapsedMilliseconds}ms',
            );

            stopwatchPrepare.reset();
            stopwatchPrepare.start();
            final runOptions = OrtRunOptions();
            final session = OrtSession.fromAddress(sessionAddress);
            stopwatchPrepare.stop();
            dev.log(
              '[YOLOFaceDetectionService] session preparation is finished, in ${stopwatchPrepare.elapsedMilliseconds}ms',
            );

            final stopwatchInterpreter = Stopwatch()..start();
            late final List<OrtValue?> outputs;
            try {
              outputs = session.run(runOptions, inputs);
            } catch (e, s) {
              dev.log(
                '[YOLOFaceDetectionService] Error while running inference: $e \n $s',
              );
              throw YOLOInterpreterRunException();
            }
            stopwatchInterpreter.stop();
            dev.log(
              '[YOLOFaceDetectionService] interpreter.run is finished, in ${stopwatchInterpreter.elapsedMilliseconds} ms',
            );

            final relativeDetections =
                _yoloPostProcessOutputs(outputs, faceOptions, newSize);

            sendPort
                .send((relativeDetections, delaySentToIsolate, DateTime.now()));
            break;
        }
      } catch (e, stackTrace) {
        sendPort
            .send({'error': e.toString(), 'stackTrace': stackTrace.toString()});
      }
    });
  }

  /// The common method to run any operation in the isolate. It sends the [message] to [_isolateMain] and waits for the result.
  Future<dynamic> _runInIsolate(
    (FaceDetectionOperation, Map<String, dynamic>) message,
  ) async {
    await ensureSpawnedIsolate();
    _resetInactivityTimer();
    final completer = Completer<dynamic>();
    final answerPort = ReceivePort();

    _mainSendPort.send([message.$1.index, message.$2, answerPort.sendPort]);

    answerPort.listen((receivedMessage) {
      if (receivedMessage is Map && receivedMessage.containsKey('error')) {
        // Handle the error
        final errorMessage = receivedMessage['error'];
        final errorStackTrace = receivedMessage['stackTrace'];
        final exception = Exception(errorMessage);
        final stackTrace = StackTrace.fromString(errorStackTrace);
        completer.completeError(exception, stackTrace);
      } else {
        completer.complete(receivedMessage);
      }
    });

    return completer.future;
  }

  /// Resets a timer that kills the isolate after a certain amount of inactivity.
  ///
  /// Should be called after initialization (e.g. inside `init()`) and after every call to isolate (e.g. inside `_runInIsolate()`)
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDuration, () {
      _logger.info(
        'Face detection (YOLO ONNX) Isolate has been inactive for ${_inactivityDuration.inSeconds} seconds. Killing isolate.',
      );
      disposeIsolate();
    });
  }

  /// Disposes the isolate worker.
  void disposeIsolate() {
    if (!isSpawned) return;

    isSpawned = false;
    _isolate.kill();
    _receivePort.close();
    _inactivityTimer?.cancel();
  }

  /// Detects faces in the given image data.
  Future<(List<FaceDetectionRelative>, Size)> predict(
    Uint8List imageData,
  ) async {
    assert(_isInitialized && _sessionOptions != null);

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

    // Run inference
    final stopwatchInterpreter = Stopwatch()..start();
    List<OrtValue?>? outputs;
    try {
      final runOptions = OrtRunOptions();
      final session = OrtSession.fromAddress(_sessionAddress);
      outputs = session.run(runOptions, inputs);
      // inputOrt.release();
      // runOptions.release();
    } catch (e, s) {
      _logger.severe('Error while running inference: $e \n $s');
      throw YOLOInterpreterRunException();
    }
    stopwatchInterpreter.stop();
    _logger.info(
      'interpreter.run is finished, in ${stopwatchInterpreter.elapsedMilliseconds} ms',
    );

    final relativeDetections =
        _yoloPostProcessOutputs(outputs, _faceOptions, newSize);

    stopwatch.stop();
    _logger.info(
      'predict() face detection executed in ${stopwatch.elapsedMilliseconds}ms',
    );

    return (relativeDetections, originalSize);
  }

  /// Detects faces in the given image data.
  Future<(List<FaceDetectionRelative>, Size)> predictInIsolate(
    Uint8List imageData,
  ) async {
    await ensureSpawnedIsolate();
    assert(_isInitialized && _sessionOptions != null);

    _logger.info('predictInIsolate() is called');

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

    stopwatchDecoding.stop();
    _logger.info(
      'Image decoding and preprocessing is finished, in ${stopwatchDecoding.elapsedMilliseconds}ms',
    );
    _logger.info('original size: $originalSize \n new size: $newSize');

    final (
      List<FaceDetectionRelative> relativeDetections,
      delaySentToIsolate,
      timeSentToMain
    ) = await _runInIsolate(
      (
        FaceDetectionOperation.yoloInferenceAndPostProcessing,
        {
          'inputImageList': inputImageList,
          'inputShape': inputShape,
          'faceOptions': _faceOptions,
          'newSize': newSize,
          'sessionAddress': _sessionAddress,
          'timeNow': DateTime.now(),
        }
      ),
    ) as (List<FaceDetectionRelative>, int, DateTime);

    final delaySentToMain =
        DateTime.now().difference(timeSentToMain).inMilliseconds;

    stopwatch.stop();
    _logger.info(
      'predictInIsolate() face detection executed in ${stopwatch.elapsedMilliseconds}ms, with ${delaySentToIsolate}ms delay sent to isolate, and ${delaySentToMain}ms delay sent to main, for a total of ${delaySentToIsolate + delaySentToMain}ms delay due to isolate',
    );

    return (relativeDetections, originalSize);
  }

  Future<(List<FaceDetectionRelative>, Size)> predictInComputer(
    Uint8List imageData,
  ) async {
    assert(_isInitialized && _sessionOptions != null);

    _logger.info('predictInComputer() is called');

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

    stopwatchDecoding.stop();
    _logger.info(
      'Image decoding and preprocessing is finished, in ${stopwatchDecoding.elapsedMilliseconds}ms',
    );
    _logger.info('original size: $originalSize \n new size: $newSize');

    final (
      List<FaceDetectionRelative> relativeDetections,
      delaySentToIsolate,
      timeSentToMain
    ) = await _computer.compute(
      inferenceAndPostProcess,
      param: {
        'inputImageList': inputImageList,
        'inputShape': inputShape,
        'faceOptions': _faceOptions,
        'newSize': newSize,
        'sessionAddress': _sessionAddress,
        'timeNow': DateTime.now(),
      },
    ) as (List<FaceDetectionRelative>, int, DateTime);

    final delaySentToMain =
        DateTime.now().difference(timeSentToMain).inMilliseconds;

    stopwatch.stop();
    _logger.info(
      'predictInIsolate() face detection executed in ${stopwatch.elapsedMilliseconds}ms, with ${delaySentToIsolate}ms delay sent to isolate, and ${delaySentToMain}ms delay sent to main, for a total of ${delaySentToIsolate + delaySentToMain}ms delay due to isolate',
    );

    return (relativeDetections, originalSize);
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
    assert(_isInitialized && _sessionOptions != null);

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
      final session = OrtSession.fromAddress(_sessionAddress);
      outputs = session.run(runOptions, inputs);
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

  static List<FaceDetectionRelative> _yoloPostProcessOutputs(
    List<OrtValue?>? outputs,
    FaceDetectionOptionsYOLO faceOptions,
    Size newSize,
  ) {
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
      options: faceOptions,
      results: firstResults,
    );

    // Release outputs
    // outputs?.forEach((element) {
    //   element?.release();
    // });

    // Account for the fact that the aspect ratio was maintained
    for (final faceDetection in relativeDetections) {
      faceDetection.correctForMaintainedAspectRatio(
        Size(
          faceOptions.inputWidth.toDouble(),
          faceOptions.inputHeight.toDouble(),
        ),
        newSize,
      );
    }

    // Non-maximum suppression to remove duplicate detections
    relativeDetections = naiveNonMaxSuppression(
      detections: relativeDetections,
      iouThreshold: faceOptions.iouThreshold,
    );

    dev.log(
      '[YOLOFaceDetectionService] ${relativeDetections.length} faces detected',
    );

    return relativeDetections;
  }

  /// Initialize the interpreter by loading the model file.
  Future<void> _loadModel() async {
    _logger.info('loadModel is called');

    try {
      // final threadOptions = OrtThreadingOptions().;
      OrtEnv.instance.init();
      OrtEnv.instance.availableProviders().forEach((element) {
        _logger.info('onnx provider= $element');
      });

      _sessionOptions = OrtSessionOptions()
        ..setInterOpNumThreads(1)
        ..setIntraOpNumThreads(1)
        ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
      final rawAssetFile = await rootBundle.load(config.modelPath);
      final bytes = rawAssetFile.buffer.asUint8List();
      final session = OrtSession.fromBuffer(bytes, _sessionOptions!);
      _sessionAddress = session.address;

      _isInitialized = true;
    } catch (e, s) {
      _logger.severe('Error while initializing YOLO onnx: $e \n $s');
      throw YOLOInterpreterInitializationException();
    }
  }

  static Future<(List<FaceDetectionRelative>, int, DateTime)>
      inferenceAndPostProcess(
    Map args,
  ) async {
    final inputImageList = args['inputImageList'] as Float32List;
    final inputShape = args['inputShape'] as List<int>;
    final faceOptions = args['faceOptions'] as FaceDetectionOptionsYOLO;
    final newSize = args['newSize'] as Size;
    final sessionAddress = args['sessionAddress'] as int;
    final timeSentToIsolate = args['timeNow'] as DateTime;
    final delaySentToIsolate =
        DateTime.now().difference(timeSentToIsolate).inMilliseconds;

    final Stopwatch stopwatchPrepare = Stopwatch()..start();
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      inputImageList,
      inputShape,
    );
    final inputs = {'input': inputOrt};
    stopwatchPrepare.stop();
    dev.log(
      '[YOLOFaceDetectionService] data preparation is finished, in ${stopwatchPrepare.elapsedMilliseconds}ms',
    );

    stopwatchPrepare.reset();
    stopwatchPrepare.start();
    final runOptions = OrtRunOptions();
    final session = OrtSession.fromAddress(sessionAddress);
    stopwatchPrepare.stop();
    dev.log(
      '[YOLOFaceDetectionService] session preparation is finished, in ${stopwatchPrepare.elapsedMilliseconds}ms',
    );

    final stopwatchInterpreter = Stopwatch()..start();
    late final List<OrtValue?> outputs;
    try {
      outputs = session.run(runOptions, inputs);
    } catch (e, s) {
      dev.log(
        '[YOLOFaceDetectionService] Error while running inference: $e \n $s',
      );
      throw YOLOInterpreterRunException();
    }
    stopwatchInterpreter.stop();
    dev.log(
      '[YOLOFaceDetectionService] interpreter.run is finished, in ${stopwatchInterpreter.elapsedMilliseconds} ms',
    );

    final relativeDetections =
        _yoloPostProcessOutputs(outputs, faceOptions, newSize);

    return (relativeDetections, delaySentToIsolate, DateTime.now());
  }
}
