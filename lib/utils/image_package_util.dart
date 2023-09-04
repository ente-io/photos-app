import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data' show Uint8List;
import 'package:image/image.dart' as image_lib;
import "package:logging/logging.dart";

class CouldNotConvertToImageImage implements Exception {}

// TODO: the image conversion below is what makes the whole pipeline slow, so come up with different solution

/// Converts a [Uint8List] to an [image_lib.Image] object.
image_lib.Image? _convertUint8ListToImagePackageImage(Uint8List imageData) {
  return image_lib.decodeImage(imageData);
}

Uint8List _convertImagePackageImageToUint8List(image_lib.Image image) {
  return image_lib.encodeJpg(image);
}

// extension ColorExtension on int {
//   int get r => (this >> 0) & 0xFF;
//   int get g => (this >> 8) & 0xFF;
//   int get b => (this >> 16) & 0xFF;
//   int get alpha => (this >> 24) & 0xFF;
// }

/// This class is responsible for converting [Uint8List] to [image_lib.Image].
/// 
/// Used primarily for ML applications.
class ImageConversionIsolate {
  static const String debugName = "ImageConversionIsolate";

  final _logger = Logger("ImageConversionIsolate");

  late Isolate _isolate;
  late ReceivePort _receivePort = ReceivePort();
  late SendPort _mainSendPort;

  bool isSpawned = false;

  // singleton pattern
  ImageConversionIsolate._privateConstructor();

  /// Use this instance to access the ImageConversionIsolate service. Make sure to call `init()` before using it.
  /// e.g. `await ImageConversionIsolate.instance.init();`
  /// And kill the isolate when you're done with it with `dispose()`, e.g. `ImageConversionIsolate.instance.dispose();`
  ///
  /// Then you can use `convert()` to get the image, so `ImageConversionIsolate.instance.convert(imageData)`
  static final ImageConversionIsolate instance =
      ImageConversionIsolate._privateConstructor();

  Future<void> init() async {
    if (isSpawned) return;

    _receivePort = ReceivePort();

    try {
      _isolate = await Isolate.spawn(
        isolateMain,
        _receivePort.sendPort,
        debugName: debugName,
      );
      _mainSendPort = await _receivePort.first as SendPort;
      isSpawned = true;
    } catch (e) {
      _logger.severe("Could not spawn isolate", e);
      isSpawned = false;
    }
  }

  Future<void> ensureSpawned() async {
    if (!isSpawned) {
      await init();
    }
  }

  static void isolateMain(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      final data = message[0] as Uint8List;
      final sendPort = message[1] as SendPort;

      final result = _convertUint8ListToImagePackageImage(data);
      // if (result != null) {
      sendPort.send(result);
      // } else {
      //   sendPort.send(CouldNotConvertToImageImage());
      // }
    });
  }

  Future<image_lib.Image?> convert(Uint8List data) async {
    await ensureSpawned();
    final completer = Completer<image_lib.Image?>();
    final answerPort = ReceivePort();

    _mainSendPort.send([data, answerPort.sendPort]);

    answerPort.listen((message) {
      // if (message is image_lib.Image?) {
      completer.complete(message);
      // } else if (message is CouldNotConvertToImageImage) {
      //   completer.completeError(message);
      // }
    });

    return completer.future;
  }

  void dispose() {
    if (!isSpawned) return;

    _isolate.kill();
    _receivePort.close();
    isSpawned = false;
  }
}
