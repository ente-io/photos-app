import 'dart:io';
// import 'dart:math' as math show min, max;
import 'dart:typed_data' show Uint8List;

import 'package:image/image.dart' as image_lib;
import "package:logging/logging.dart";
import "package:photos/services/face_ml/face_embedding/face_embedding_exceptions.dart";
import "package:photos/services/face_ml/face_embedding/mobilefacenet_model_config.dart";
import "package:photos/utils/image.dart";
import "package:photos/utils/ml_input_output.dart";
import 'package:tflite_flutter/tflite_flutter.dart';

/// This class is responsible for running the MobileFaceNet model, and can be accessed through the singleton `FaceEmbedding.instance`.
class FaceEmbedding {
  Interpreter? _interpreter;
  int get getAddress => _interpreter!.address;

  final outputShapes = <List<int>>[];
  final outputTypes = <TfLiteType>[];

  final _logger = Logger("FaceEmbeddingService");

  final MobileFaceNetModelConfig config;
  // singleton pattern
  FaceEmbedding._privateConstructor({required this.config});

  /// Use this instance to access the FaceEmbedding service. Make sure to call `init()` before using it.
  /// e.g. `await FaceEmbedding.instance.init();`
  ///
  /// Then you can use `predict()` to get the embedding of a face, so `FaceEmbedding.instance.predict(imageData)`
  ///
  /// config options: faceEmbeddingEnte
  static final instance =
      FaceEmbedding._privateConstructor(config: faceEmbeddingEnte);

  /// Check if the interpreter is initialized, if not initialize it with `loadModel()`
  Future<void> init() async {
    if (_interpreter == null) {
      await loadModel();
    }
  }

  Future<void> loadModel() async {
    _logger.info('loadModel is called');

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

      // Load model from assets
      _interpreter = _interpreter ??
          await Interpreter.fromAsset(
            config.modelPath,
            options: interpreterOptions,
          );

      // Get tensor input shape [1, 112, 112, 3]
      final inputTensors = _interpreter!.getInputTensors().first;
      _logger.info('Input Tensors: $inputTensors');
      // Get tensour output shape [1, 192]
      final outputTensors = _interpreter!.getOutputTensors();
      final outputTensor = outputTensors.first;
      _logger.info('Output Tensors: $outputTensor');

      for (var tensor in outputTensors) {
        outputShapes.add(tensor.shape);
        outputTypes.add(tensor.type);
      }
      _logger.info('loadModel is finished');
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      _logger.severe('Error while creating interpreter: $e');
      throw MobileFaceNetInterpreterInitializationException();
    }
  }

  List<List<List<num>>> getPreprocessedImage(
    image_lib.Image image,
  ) {
    final embeddingOptions = config.faceEmbeddingOptions;

    // Resize image for model input (112, 112) (thought most likely it is already resized, so we check first)
    if (image.width != embeddingOptions.inputWidth ||
        image.height != embeddingOptions.inputHeight) {
      image = image_lib.copyResize(
        image,
        width: embeddingOptions.inputWidth,
        height: embeddingOptions.inputHeight,
        interpolation: image_lib.Interpolation
            .linear, // can choose `bicubic` if more accuracy is needed. But this is slow, and adds little if bilinear is already used earlier (which is the case)
      );
    }

    // Get image matrix representation [inputWidt, inputHeight, 3]
    final imageMatrix = createInputMatrixFromImage(image, normalize: true);

    return imageMatrix;
  }

  // TODO: Make the predict function asynchronous with use of isolate-interpreter: https://github.com/tensorflow/flutter-tflite/issues/52
  List<double> predict(Uint8List imageData) {
    assert(_interpreter != null);

    final dataConversionStopwatch = Stopwatch()..start();
    final image = convertUint8ListToImagePackageImage(imageData);
    dataConversionStopwatch.stop();
    _logger.info(
      'image data conversion is finished, in ${dataConversionStopwatch.elapsedMilliseconds}ms',
    );

    _logger.info('outputShapes: $outputShapes');

    final stopwatch = Stopwatch()..start();

    final inputImageMatrix =
        getPreprocessedImage(image); // [inputWidt, inputHeight, 3]
    final input = [inputImageMatrix];

    final output = createEmptyOutputMatrix(outputShapes[0]);

    _logger.info('interpreter.run is called');
    // Run inference
    try {
      _interpreter!.run(input, output);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      _logger.severe('Error while running inference: $e');
      throw MobileFaceNetInterpreterRunException();
    }
    _logger.info('interpreter.run is finished');

    // Get output tensors
    final embedding = output[0] as List<double>;

    stopwatch.stop();
    _logger.info(
      'predict() executed in ${stopwatch.elapsedMilliseconds}ms',
    );

    // _logger.info(
    //   'results (only first few numbers): embedding ${embedding.sublist(0, 5)}',
    // );
    // _logger.info(
    //   'Mean of embedding: ${embedding.reduce((a, b) => a + b) / embedding.length}',
    // );
    // _logger.info(
    //   'Max of embedding: ${embedding.reduce(math.max)}',
    // );
    // _logger.info(
    //   'Min of embedding: ${embedding.reduce(math.min)}',
    // );

    return embedding;
  }
}