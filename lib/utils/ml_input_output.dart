import 'package:image/image.dart';
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
/// The `image` argument must be an [Image] object. The function returns a matrix
/// with the shape `[image.height, image.width, 3]`, where the third dimension
/// represents the RGB channels.
/// 
/// bool `normalize`: Normalize the image to range [-1, 1]
List<List<List<num>>> createInputMatrixFromImage(
  Image image, {
  bool normalize = true,
}) {
  List<List<List<num>>> imageMatrix;
  if (normalize) {
    imageMatrix = List.generate(
      image.height,
      (y) => List.generate(
        image.width,
        (x) {
          final pixel = image.getPixel(x, y);
          return [
            normalizePixel(pixel.r), // Normalize the image to range [-1, 1]
            normalizePixel(pixel.g), // Normalize the image to range [-1, 1]
            normalizePixel(pixel.b), // Normalize the image to range [-1, 1]
          ];
        },
      ),
    );
  } else {
    imageMatrix = List.generate(
      image.height,
      (y) => List.generate(
        image.width,
        (x) {
          final pixel = image.getPixel(x, y);
          return [
            pixel.r, // Normalize the image to range [-1, 1]
            pixel.g, // Normalize the image to range [-1, 1]
            pixel.b, // Normalize the image to range [-1, 1]
          ];
        },
      ),
    );
  }
  return imageMatrix;
}

/// Creates an input matrix from the specified image, which can be used for inference
///
/// The `image` argument must be an [Image] object. The function returns a matrix
/// with the shape `[3, image.height, image.width]`, where the first dimension
/// represents the RGB channels.
///
/// bool `normalize`: Normalize the image to range [-1, 1]
List<List<List<num>>> createInputMatrixFromImageChannelsFirst(
  Image image, {
  bool normalize = true,
}) {
  // Create an empty 3D list.
  final List<List<List<num>>> imageMatrix = List.generate(
    3,
    (i) => List.generate(
      image.height,
      (j) => List.filled(image.width, 0.0),
    ),
  );

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      // Get the pixel at (x, y).
      final pixel = image.getPixel(x, y);

      // Assign the color channels to the respective lists.
      if (normalize) {
        imageMatrix[0][y][x] = normalizePixel(pixel.r);
        imageMatrix[1][y][x] = normalizePixel(pixel.g);
        imageMatrix[2][y][x] = normalizePixel(pixel.b);
      } else {
        imageMatrix[0][y][x] = pixel.r;
        imageMatrix[1][y][x] = pixel.g;
        imageMatrix[2][y][x] = pixel.b;
      }
    }
  }
  return imageMatrix;
}

/// Function normalizes the pixel value to be in range [-1, 1].
///
/// It assumes that the pixel value is originally in range [0, 255]
num normalizePixel(num pixelValue) {
  return (pixelValue / 127.5) - 1;
}
