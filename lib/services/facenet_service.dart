import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:logging/logging.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:image/image.dart' as imglib;

class FaceNetService {
  final _logger = Logger("MobileFaceNetService");
  Interpreter _interpreter;

  FaceNetService._privateConstructor();

  static final FaceNetService instance = FaceNetService._privateConstructor();

  Future<void> init() async {
    if (_interpreter == null) {
      await loadModel();
    }
  }

  Future<void> loadModel() async {
    Delegate delegate;
    var interpreterOptions = InterpreterOptions();
    try {
      if (Platform.isAndroid) {
        delegate = GpuDelegateV2(
            options: GpuDelegateOptionsV2(
                inferencePreference: TfLiteGpuInferenceUsage.fastSingleAnswer,
                inferencePriority1: TfLiteGpuInferencePriority.minLatency,
                inferencePriority2: TfLiteGpuInferencePriority.auto,
                inferencePriority3: TfLiteGpuInferencePriority.auto,
                isPrecisionLossAllowed: false));
        interpreterOptions.addDelegate(delegate);
      }
      // else if (Platform.isIOS) {
      //   delegate = GpuDelegate(
      //     options: GpuDelegateOptions(
      //         allowPrecisionLoss: true,
      //         waitType: TFLGpuDelegateWaitType.active),
      //   );
      // }
      _interpreter = await Interpreter.fromAsset('mobilefacenet.tflite',
          options: interpreterOptions);
      _logger.fine('mobilefacenet.tflite loaded successfully');
    } catch (e) {
      _logger.severe('Failed to load mobilefacenet.tflite model', e);
    }
  }

  List<double> getFeatures(imglib.Image faceImage) {
    List input = _preProcess(faceImage);
    input = input.reshape([1, 112, 112, 3]);

    List output = List.generate(1, (index) => List.filled(192, 0));

    _interpreter.run(input, output);
    output = output.reshape([192]);

    return List<double>.from(output);
  }

  double euclideanDistance(List<double> e1, List<double> e2) {
    if (e1 == null || e2 == null) throw Exception("Null argument");

    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum += pow((e1[i] - e2[i]), 2);
    }
    return sqrt(sum);
  }

  List _preProcess(imglib.Image faceImage) {
    imglib.Image img = imglib.copyResizeCropSquare(faceImage, 112);

    Float32List imageAsList = _imageToByteListFloat32(img);
    return imageAsList;
  }

  Float32List _imageToByteListFloat32(imglib.Image image) {
    /// input size = 112
    var convertedBytes = Float32List(1 * 112 * 112 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < 112; i++) {
      for (var j = 0; j < 112; j++) {
        var pixel = image.getPixel(j, i);

        /// mean: 128
        /// std: 128
        buffer[pixelIndex++] = (imglib.getRed(pixel) - 127.5) / 128;
        buffer[pixelIndex++] = (imglib.getGreen(pixel) - 127.5) / 128;
        buffer[pixelIndex++] = (imglib.getBlue(pixel) - 127.5) / 128;
      }
    }
    return convertedBytes.buffer.asFloat32List();
  }
}
