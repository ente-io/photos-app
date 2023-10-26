import "dart:async";
import "dart:typed_data" show Uint8List, ByteData;
import "dart:ui";

// import 'package:flutter/material.dart'
//     show
//         ImageProvider,
//         ImageStream,
//         ImageStreamListener,
//         ImageInfo,
//         MemoryImage,
//         ImageConfiguration;
// import 'package:flutter/material.dart' as material show Image;
import 'package:flutter/painting.dart' as paint show decodeImageFromList;
import "package:logging/logging.dart";
import 'package:ml_linalg/linalg.dart';
import 'package:photos/models/ml/ml_typedefs.dart';
import "package:photos/services/face_ml/face_alignment/similarity_transform.dart";
import "package:photos/services/face_ml/face_detection/detection.dart";

/// All of the functions in this file are helper functions for the [ImageMlIsolate] isolate.
/// Don't use them outside of the isolate, unless you are okay with UI jank!!!!

final _logger = Logger('ImageMlUtil');

/// Reads the pixel color at the specified coordinates.
Color readPixelColor(
  Image image,
  ByteData byteData,
  int x,
  int y,
) {
  if (x < 0 || x >= image.width || y < 0 || y >= image.height) {
    throw ArgumentError('Invalid pixel coordinates.');
    // return const Color(0x00000000);
  }
  assert(byteData.lengthInBytes == 4 * image.width * image.height);

  final int byteOffset = 4 * (image.width * y + x);
  return Color(_rgbaToArgb(byteData.getUint32(byteOffset)));
}

int _rgbaToArgb(int rgbaColor) {
  final int a = rgbaColor & 0xFF;
  final int rgb = rgbaColor >> 8;
  return rgb + (a << 24);
}

/// Creates an empty matrix with the specified shape.
///
/// The `shape` argument must be a list of length 2 or 3, where the first
/// element represents the number of rows, the second element represents
/// the number of columns, and the optional third element represents the
/// number of channels. The function returns a matrix filled with zeros.
///
/// Throws an [ArgumentError] if the `shape` argument is invalid.
List createEmptyOutputMatrix(List<int> shape) {
  if (shape.length < 2 || shape.length > 3) {
    throw ArgumentError('Shape must have length 2 or 3');
  }
  if (shape.length == 2) {
    return List.generate(shape[0], (_) => List.filled(shape[1], 0.0));
  } else {
    return List.generate(
      shape[0],
      (_) => List.generate(shape[1], (_) => List.filled(shape[2], 0.0)),
    );
  }
}

/// Creates an input matrix from the specified image, which can be used for inference
///
/// Returns a matrix with the shape [image.height, image.width, 3], where the third dimension represents the RGB channels, as [Num3DInputMatrix].
/// In fact, this is either a [Double3DInputMatrix] or a [Int3DInputMatrix] depending on the `normalize` argument.
/// If `normalize` is true, the pixel values are normalized doubles in range [-1, 1]. Otherwise, they are integers in range [0, 255].
///
/// The `image` argument must be an ui.[Image] object. The function returns a matrix
/// with the shape `[image.height, image.width, 3]`, where the third dimension
/// represents the RGB channels.
///
/// bool `normalize`: Normalize the image to range [-1, 1]
Num3DInputMatrix createInputMatrixFromImage(
  Image image,
  ByteData byteDataRgba, {
  bool normalize = true,
}) {
  return List.generate(
    image.height,
    (y) => List.generate(
      image.width,
      (x) {
        final pixel = readPixelColor(image, byteDataRgba, x, y);
        return [
          normalize ? normalizePixel(pixel.red) : pixel.red,
          normalize ? normalizePixel(pixel.green) : pixel.green,
          normalize ? normalizePixel(pixel.blue) : pixel.blue,
        ];
      },
    ),
  );
}

/// Creates an input matrix from the specified image, which can be used for inference
///
/// Returns a matrix with the shape `[3, image.height, image.width]`, where the first dimension represents the RGB channels, as [Num3DInputMatrix].
/// In fact, this is either a [Double3DInputMatrix] or a [Int3DInputMatrix] depending on the `normalize` argument.
/// If `normalize` is true, the pixel values are normalized doubles in range [-1, 1]. Otherwise, they are integers in range [0, 255].
///
/// The `image` argument must be an ui.[Image] object. The function returns a matrix
/// with the shape `[3, image.height, image.width]`, where the first dimension
/// represents the RGB channels.
///
/// bool `normalize`: Normalize the image to range [-1, 1]
Num3DInputMatrix createInputMatrixFromImageChannelsFirst(
  Image image,
  ByteData byteDataRgba, {
  bool normalize = true,
}) {
  // Create an empty 3D list.
  final Num3DInputMatrix imageMatrix = List.generate(
    3,
    (i) => List.generate(
      image.height,
      (j) => List.filled(image.width, 0),
    ),
  );

  // Determine which function to use to get the pixel value.
  final pixelValue = normalize ? normalizePixel : (num value) => value;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      // Get the pixel at (x, y).
      final pixel = readPixelColor(image, byteDataRgba, x, y);

      // Assign the color channels to the respective lists.
      imageMatrix[0][y][x] = pixelValue(pixel.red);
      imageMatrix[1][y][x] = pixelValue(pixel.green);
      imageMatrix[2][y][x] = pixelValue(pixel.blue);
    }
  }
  return imageMatrix;
}

/// Function normalizes the pixel value to be in range [-1, 1].
///
/// It assumes that the pixel value is originally in range [0, 255]
double normalizePixel(num pixelValue) {
  return (pixelValue / 127.5) - 1;
}

/// Decodes [Uint8List] image data to an ui.[Image] object.
Future<Image> decodeImageFromData(Uint8List imageData) async {
  // Decoding using flutter paint. This is the fastest and easiest method.
  final Image image = await paint.decodeImageFromList(imageData);
  return image;

  // // Similar decoding as above, but without using flutter paint. This is not faster than the above.
  // final Codec codec = await instantiateImageCodecFromBuffer(
  //   await ImmutableBuffer.fromUint8List(imageData),
  // );
  // final FrameInfo frameInfo = await codec.getNextFrame();
  // return frameInfo.image;

  // Decoding using the ImageProvider, same as `image_pixels` package. This is not faster than the above.
  // final Completer<Image> completer = Completer<Image>();
  // final ImageProvider provider = MemoryImage(imageData);
  // final ImageStream stream = provider.resolve(const ImageConfiguration());
  // final ImageStreamListener listener =
  //     ImageStreamListener((ImageInfo info, bool _) {
  //   completer.complete(info.image);
  // });
  // stream.addListener(listener);
  // final Image image = await completer.future;
  // stream.removeListener(listener);
  // return image;

  // // Decoding using the ImageProvider from material.Image. This is not faster than the above, and also the code below is not finished!
  // final materialImage = material.Image.memory(imageData);
  // final ImageProvider uiImage = await materialImage.image;
}

/// Decodes [Uint8List] RGBA bytes to an ui.[Image] object.
Future<Image> decodeImageFromRgbaBytes(
  Uint8List rgbaBytes,
  int width,
  int height,
) {
  final Completer<Image> completer = Completer();
  decodeImageFromPixels(
    rgbaBytes,
    width,
    height,
    PixelFormat.rgba8888,
    (Image image) {
      completer.complete(image);
    },
  );
  return completer.future;
}

/// Returns the [ByteData] object of the image, in rawRgba format.
///
/// Throws an exception if the image could not be converted to ByteData.
Future<ByteData> getByteDataFromImage(
  Image image, {
  ImageByteFormat format = ImageByteFormat.rawRgba,
}) async {
  final ByteData? byteDataRgba = await image.toByteData(format: format);
  if (byteDataRgba == null) {
    _logger.severe('Could not convert image to ByteData');
    throw Exception('Could not convert image to ByteData');
  }
  return byteDataRgba;
}

/// Encodes an [Image] object to a [Uint8List], by default in the png format.
///
/// Note that the result can be used with `Image.memory()` only if the [format] is png.
Future<Uint8List> encodeImageToUint8List(
  Image image, {
  ImageByteFormat format = ImageByteFormat.png,
}) async {
  final ByteData byteDataPng =
      await getByteDataFromImage(image, format: format);
  final encodedImage = byteDataPng.buffer.asUint8List();

  return encodedImage;
}

/// Resizes an [Image] object to the specified [width] and [height].
Future<Image> resizeImage(
  Image image,
  int width,
  int height, {
  FilterQuality quality = FilterQuality.medium,
}) async {
  if (image.width == width && image.height == height) {
    return image;
  }
  final recorder = PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromPoints(
      const Offset(0, 0),
      Offset(width.toDouble(), height.toDouble()),
    ),
  );

  canvas.drawImageRect(
    image,
    Rect.fromPoints(
      const Offset(0, 0),
      Offset(image.width.toDouble(), image.height.toDouble()),
    ),
    Rect.fromPoints(
      const Offset(0, 0),
      Offset(width.toDouble(), height.toDouble()),
    ),
    Paint()..filterQuality = quality,
  );

  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

/// Crops an [Image] object to the specified [width] and [height], starting at the specified [x] and [y] coordinates.
Future<Image> cropImage(
  Image image, {
  required int x,
  required int y,
  required int width,
  required int height,
  FilterQuality quality = FilterQuality.medium,
}) async {
  if (x < 0 ||
      y < 0 ||
      (x + width) > image.width ||
      (y + height) > image.height) {
    _logger.severe('Invalid crop dimensions or coordinates.');
    throw ArgumentError('Invalid crop dimensions or coordinates.');
  }

  final recorder = PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromPoints(
      const Offset(0, 0),
      Offset(width.toDouble(), height.toDouble()),
    ),
  );

  canvas.drawImageRect(
    image,
    Rect.fromPoints(
      Offset(x.toDouble(), y.toDouble()),
      Offset((x + width).toDouble(), (y + height).toDouble()),
    ),
    Rect.fromPoints(
      const Offset(0, 0),
      Offset(width.toDouble(), height.toDouble()),
    ),
    Paint()..filterQuality = quality,
  );

  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

/// Preprocesses [imageData] for standard ML models
Future<Num3DInputMatrix> preprocessImageToMatrix(
  Uint8List imageData, {
  required bool normalize,
  required int requiredWidth,
  required int requiredHeight,
  FilterQuality quality = FilterQuality.medium,
}) async {
  final Image image = await decodeImageFromData(imageData);

  _logger.info(
    'Face detection preprocessing: image has dimensions ${image.width}x${image.height}',
  );

  if (image.width == requiredWidth && image.height == requiredHeight) {
    final ByteData imgByteData = await getByteDataFromImage(image);
    return createInputMatrixFromImage(
      image,
      imgByteData,
      normalize: normalize,
    );
  }

  final Image resizedImage = await resizeImage(
    image,
    requiredWidth,
    requiredHeight,
    quality: quality,
  );

  final ByteData imgByteData = await getByteDataFromImage(resizedImage);
  final Num3DInputMatrix imageMatrix = createInputMatrixFromImage(
    resizedImage,
    imgByteData,
    normalize: normalize,
  );

  return imageMatrix;
}

/// Preprocesses [imageData] based on [faceLandmarks] to align the faces in the images.
///
/// Returns a list of [Uint8List] images, one for each face, in png format.
Future<List<Uint8List>> preprocessFaceAlignToUint8List(
  Uint8List imageData,
  List<List<List<int>>> faceLandmarks, {
  int width = 112,
  int height = 112,
}) async {
  final alignedImages = <Uint8List>[];
  final Image image = await decodeImageFromData(imageData);
  final ByteData imgByteData =
      await getByteDataFromImage(image, format: ImageByteFormat.rawRgba);

  for (final faceLandmark in faceLandmarks) {
    final (transformationMatrix, correctlyEstimated) =
        SimilarityTransform.instance.estimate(faceLandmark);
    if (!correctlyEstimated) {
      alignedImages.add(Uint8List(0));
      continue;
    }
    final Uint8List alignedImageRGBA = await warpAffineToUint8List(
      image,
      imgByteData,
      transformationMatrix,
      width: width,
      height: height,
    );
    final Image alignedImage =
        await decodeImageFromRgbaBytes(alignedImageRGBA, width, height);
    final Uint8List alignedImagePng =
        await encodeImageToUint8List(alignedImage);

    alignedImages.add(alignedImagePng);
  }
  return alignedImages;
}

/// Preprocesses [imageData] based on [faceLandmarks] to align the faces in the images
///
/// Returns a list of [Num3DInputMatrix] images, one for each face, ready for MobileFaceNet inference
Future<(List<Double3DInputMatrix>, List<List<List<double>>>)>
    preprocessToMobileFaceNetInput(
  Uint8List imageData,
  List<Map<String, dynamic>> facesJson, {
  int width = 112,
  int height = 112,
}) async {
  final Image image = await decodeImageFromData(imageData);
  final ByteData imgByteData = await getByteDataFromImage(image);

  final List<FaceDetectionRelative> relativeFaces =
      facesJson.map((face) => FaceDetectionRelative.fromJson(face)).toList();

  final List<FaceDetectionAbsolute> absoluteFaces =
      relativeToAbsoluteDetections(
    relativeDetections: relativeFaces,
    imageWidth: image.width,
    imageHeight: image.height,
  );

  final List<List<List<int>>> faceLandmarks =
      absoluteFaces.map((face) => face.allKeypoints.sublist(0, 4)).toList();

  final alignedImages = <Double3DInputMatrix>[];
  final transformationMatrices = <List<List<double>>>[];

  for (final faceLandmark in faceLandmarks) {
    final (transformationMatrix, correctlyEstimated) =
        SimilarityTransform.instance.estimate(faceLandmark);
    if (!correctlyEstimated) {
      alignedImages.add([]);
      transformationMatrices.add([]);
      continue;
    }
    final Double3DInputMatrix alignedImage = await warpAffineToMatrix(
      image,
      imgByteData,
      transformationMatrix,
      width: width,
      height: height,
      normalize: true,
    );
    alignedImages.add(alignedImage);
    transformationMatrices.add(transformationMatrix);
  }
  return (alignedImages, transformationMatrices);
}

/// Function to warp an image [imageData] with an affine transformation using the estimated [transformationMatrix].
///
/// Returns the warped image in the specified width and height, in [Uint8List] RGBA format.
Future<Uint8List> warpAffineToUint8List(
  Image inputImage,
  ByteData imgByteDataRgba,
  List<List<double>> transformationMatrix, {
  required int width,
  required int height,
}) async {
  final Uint8List outputList = Uint8List(4 * width * height);

  if (width != 112 || height != 112) {
    throw Exception(
      'Width and height must be 112, other transformations are not supported yet.',
    );
  }

  final A = Matrix.fromList([
    [transformationMatrix[0][0], transformationMatrix[0][1]],
    [transformationMatrix[1][0], transformationMatrix[1][1]],
  ]);
  final aInverse = A.inverse();
  // final aInverseMinus = aInverse * -1;
  final B = Vector.fromList(
    [transformationMatrix[0][2], transformationMatrix[1][2]],
  );
  final b00 = B[0];
  final b10 = B[1];
  final a00Prime = aInverse[0][0];
  final a01Prime = aInverse[0][1];
  final a10Prime = aInverse[1][0];
  final a11Prime = aInverse[1][1];

  for (int yTrans = 0; yTrans < height; ++yTrans) {
    for (int xTrans = 0; xTrans < width; ++xTrans) {
      // Perform inverse affine transformation (original implementation, intuitive but slow)
      // final X = aInverse * (Vector.fromList([xTrans, yTrans]) - B);
      // final X = aInverseMinus * (B - [xTrans, yTrans]);
      // final xList = X.asFlattenedList;
      // num xOrigin = xList[0];
      // num yOrigin = xList[1];

      // Perform inverse affine transformation (fast implementation, less intuitive)
      num xOrigin = (xTrans - b00) * a00Prime + (yTrans - b10) * a01Prime;
      num yOrigin = (xTrans - b00) * a10Prime + (yTrans - b10) * a11Prime;

      // Clamp to image boundaries
      xOrigin = xOrigin.clamp(0, inputImage.width - 1);
      yOrigin = yOrigin.clamp(0, inputImage.height - 1);

      // Bilinear interpolation
      final int x0 = xOrigin.floor();
      final int x1 = xOrigin.ceil();
      final int y0 = yOrigin.floor();
      final int y1 = yOrigin.ceil();

      // Get the original pixels
      final Color pixel1 = readPixelColor(inputImage, imgByteDataRgba, x0, y0);
      final Color pixel2 = readPixelColor(inputImage, imgByteDataRgba, x1, y0);
      final Color pixel3 = readPixelColor(inputImage, imgByteDataRgba, x0, y1);
      final Color pixel4 = readPixelColor(inputImage, imgByteDataRgba, x1, y1);

      // Calculate the weights for each pixel
      final fx = xOrigin - x0;
      final fy = yOrigin - y0;
      final fx1 = 1.0 - fx;
      final fy1 = 1.0 - fy;

      // Calculate the weighted sum of pixels
      final int r = bilinearInterpolation(
        pixel1.red,
        pixel2.red,
        pixel3.red,
        pixel4.red,
        fx,
        fy,
        fx1,
        fy1,
      );
      final int g = bilinearInterpolation(
        pixel1.green,
        pixel2.green,
        pixel3.green,
        pixel4.green,
        fx,
        fy,
        fx1,
        fy1,
      );
      final int b = bilinearInterpolation(
        pixel1.blue,
        pixel2.blue,
        pixel3.blue,
        pixel4.blue,
        fx,
        fy,
        fx1,
        fy1,
      );

      // Set the new pixel
      outputList[4 * (yTrans * width + xTrans)] = r;
      outputList[4 * (yTrans * width + xTrans) + 1] = g;
      outputList[4 * (yTrans * width + xTrans) + 2] = b;
      outputList[4 * (yTrans * width + xTrans) + 3] = 255;
    }
  }

  return outputList;
}

/// Function to warp an image [imageData] with an affine transformation using the estimated [transformationMatrix].
///
/// Returns a [Num3DInputMatrix], potentially normalized (RGB) and ready to be used as input for a ML model.
Future<Double3DInputMatrix> warpAffineToMatrix(
  Image inputImage,
  ByteData imgByteDataRgba,
  List<List<double>> transformationMatrix, {
  required int width,
  required int height,
  bool normalize = true,
}) async {
  final List<List<List<double>>> outputMatrix = List.generate(
    height,
    (y) => List.generate(
      width,
      (_) => List.filled(3, 0.0),
    ),
  );
  final double Function(num) pixelValue =
      normalize ? normalizePixel : (num value) => value.toDouble();

  if (width != 112 || height != 112) {
    throw Exception(
      'Width and height must be 112, other transformations are not supported yet.',
    );
  }

  final A = Matrix.fromList([
    [transformationMatrix[0][0], transformationMatrix[0][1]],
    [transformationMatrix[1][0], transformationMatrix[1][1]],
  ]);
  final aInverse = A.inverse();
  // final aInverseMinus = aInverse * -1;
  final B = Vector.fromList(
    [transformationMatrix[0][2], transformationMatrix[1][2]],
  );
  final b00 = B[0];
  final b10 = B[1];
  final a00Prime = aInverse[0][0];
  final a01Prime = aInverse[0][1];
  final a10Prime = aInverse[1][0];
  final a11Prime = aInverse[1][1];

  for (int yTrans = 0; yTrans < height; ++yTrans) {
    for (int xTrans = 0; xTrans < width; ++xTrans) {
      // Perform inverse affine transformation (original implementation, intuitive but slow)
      // final X = aInverse * (Vector.fromList([xTrans, yTrans]) - B);
      // final X = aInverseMinus * (B - [xTrans, yTrans]);
      // final xList = X.asFlattenedList;
      // num xOrigin = xList[0];
      // num yOrigin = xList[1];

      // Perform inverse affine transformation (fast implementation, less intuitive)
      num xOrigin = (xTrans - b00) * a00Prime + (yTrans - b10) * a01Prime;
      num yOrigin = (xTrans - b00) * a10Prime + (yTrans - b10) * a11Prime;

      // Clamp to image boundaries
      xOrigin = xOrigin.clamp(0, inputImage.width - 1);
      yOrigin = yOrigin.clamp(0, inputImage.height - 1);

      // Bilinear interpolation
      final int x0 = xOrigin.floor();
      final int x1 = xOrigin.ceil();
      final int y0 = yOrigin.floor();
      final int y1 = yOrigin.ceil();

      // Get the original pixels
      final Color pixel1 = readPixelColor(inputImage, imgByteDataRgba, x0, y0);
      final Color pixel2 = readPixelColor(inputImage, imgByteDataRgba, x1, y0);
      final Color pixel3 = readPixelColor(inputImage, imgByteDataRgba, x0, y1);
      final Color pixel4 = readPixelColor(inputImage, imgByteDataRgba, x1, y1);

      // Calculate the weights for each pixel
      final fx = xOrigin - x0;
      final fy = yOrigin - y0;
      final fx1 = 1.0 - fx;
      final fy1 = 1.0 - fy;

      // Calculate the weighted sum of pixels
      final int r = bilinearInterpolation(
        pixel1.red,
        pixel2.red,
        pixel3.red,
        pixel4.red,
        fx,
        fy,
        fx1,
        fy1,
      );
      final int g = bilinearInterpolation(
        pixel1.green,
        pixel2.green,
        pixel3.green,
        pixel4.green,
        fx,
        fy,
        fx1,
        fy1,
      );
      final int b = bilinearInterpolation(
        pixel1.blue,
        pixel2.blue,
        pixel3.blue,
        pixel4.blue,
        fx,
        fy,
        fx1,
        fy1,
      );

      // Set the new pixel
      outputMatrix[yTrans][xTrans] = [
        pixelValue(r),
        pixelValue(g),
        pixelValue(b),
      ];
    }
  }

  return outputMatrix;
}

/// Generates a face thumbnail from [imageData] and a [faceDetection].
///
/// Returns a [Uint8List] image, in png format.
Future<Uint8List> generateFaceThumbnailFromData(
  Uint8List imageData,
  FaceDetectionRelative faceDetection,
) async {
  final Image image = await decodeImageFromData(imageData);

  final Image faceThumbnail = await cropImage(
    image,
    x: (faceDetection.xMinBox * image.width).round() - 20,
    y: (faceDetection.yMinBox * image.height).round() - 30,
    width: (faceDetection.width * image.width).round() + 40,
    height: (faceDetection.height * image.height).round() + 60,
  );

  return await encodeImageToUint8List(
    faceThumbnail,
    format: ImageByteFormat.png,
  );
}

int bilinearInterpolation(
  num val1,
  num val2,
  num val3,
  num val4,
  num fx,
  num fy,
  num fx1,
  num fy1,
) {
  return (val1 * fx1 * fy1 + val2 * fx * fy1 + val3 * fx1 * fy + val4 * fx * fy)
      .round();
}
