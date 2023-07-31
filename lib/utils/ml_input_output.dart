import 'package:image/image.dart';
import "package:photos/models/ml_typedefs.dart";
import "package:photos/utils/image.dart";

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
/// Returns a matrix with the shape `[image.height, image.width, 3]`, where the third dimension represents the RGB channels, as [Num3DInputMatrix].
/// In fact, this is either a [Double3DInputMatrix] or a [Int3DInputMatrix] depending on the `normalize` argument.
/// If `normalize` is true, the pixel values are normalized doubles in range [-1, 1]. Otherwise, they are integers in range [0, 255].
///
/// The `image` argument must be an [Image] object. The function returns a matrix
/// with the shape `[image.height, image.width, 3]`, where the third dimension
/// represents the RGB channels.
///
/// bool `normalize`: Normalize the image to range [-1, 1]
Num3DInputMatrix createInputMatrixFromImage(
  Image image, {
  bool normalize = true,
}) {
  return List.generate(
    image.height,
    (y) => List.generate(
      image.width,
      (x) {
        final pixel = image.getPixel(x, y);
        return [
          normalize ? normalizePixel(pixel.r) : pixel.r,
          normalize ? normalizePixel(pixel.g) : pixel.g,
          normalize ? normalizePixel(pixel.b) : pixel.b,
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
/// The `image` argument must be an [Image] object. The function returns a matrix
/// with the shape `[3, image.height, image.width]`, where the first dimension
/// represents the RGB channels.
///
/// bool `normalize`: Normalize the image to range [-1, 1]
Num3DInputMatrix createInputMatrixFromImageChannelsFirst(
  Image image, {
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
  final pixelValue = normalize ? normalizePixel : (int value) => value;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      // Get the pixel at (x, y).
      final pixel = image.getPixel(x, y);

      // Assign the color channels to the respective lists.
      imageMatrix[0][y][x] = pixelValue(pixel.r);
      imageMatrix[1][y][x] = pixelValue(pixel.g);
      imageMatrix[2][y][x] = pixelValue(pixel.b);
    }
  }
  return imageMatrix;
}

/// Function normalizes the pixel value to be in range [-1, 1].
///
/// It assumes that the pixel value is originally in range [0, 255]
double normalizePixel(int pixelValue) {
  return (pixelValue / 127.5) - 1;
}
