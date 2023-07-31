import 'dart:typed_data' show Uint8List;

import 'package:image/image.dart' as image_lib;
import 'package:ml_linalg/linalg.dart';
import 'package:photos/extensions/ml_linalg_extensions.dart';
import "package:photos/models/ml_typedefs.dart";
import "package:photos/utils/image.dart";
import "package:photos/utils/ml_input_output.dart";

/// Class to compute the similarity transform between two sets of points.
///
/// The class estimates the parameters of the similarity transformation via the `estimate` function.
/// After estimation, the transformation can be applied to an image using the `warpAffine` function.
class SimilarityTransform {
  var params = Matrix.fromList([
    [1.0, 0.0, 0.0],
    [0.0, 1.0, 0.0],
    [0, 0, 1]
  ]);
  final arcface = [
    <double>[38.2946, 51.6963],
    <double>[73.5318, 51.5014],
    <double>[56.0252, 71.7366],
    <double>[56.1396, 92.2848],
  ];

  List<List<double>> get paramsList => params.to2DList();

  SimilarityTransform();

  void cleanParams() {
    params = Matrix.fromList([
      [1.0, 0.0, 0.0],
      [0.0, 1.0, 0.0],
      [0, 0, 1]
    ]);
  }

  /// Function to estimate the parameters of the affine transformation. These parameters are stored in the class variable params.
  ///
  /// Runs efficiently in about 1-3 ms after initial warm-up.
  ///
  /// It takes the source and destination points as input and returns the
  /// parameters of the affine transformation as output. The function
  /// returns false if the parameters cannot be estimated. The function
  /// estimates the parameters by solving a least-squares problem using
  /// the Umeyama algorithm.
  bool estimate(List<List<int>> src) {
    params = _umeyama(src, arcface, true);
    // We check for NaN in the transformation matrix params.
    final isNoNanInParam =
        !params.asFlattenedList.any((element) => element.isNaN);
    return isNoNanInParam;
  }

  static Matrix _umeyama(
    List<List<int>> src,
    List<List<double>> dst,
    bool estimateScale,
  ) {
    final srcMat = Matrix.fromList(
      src
          .map((list) => list.map((value) => value.toDouble()).toList())
          .toList(),
    );
    final dstMat = Matrix.fromList(dst);
    final num = srcMat.rowCount;
    final dim = srcMat.columnCount;

    // Compute mean of src and dst.
    final srcMean = srcMat.mean(Axis.columns);
    final dstMean = dstMat.mean(Axis.columns);

    // Subtract mean from src and dst.
    final srcDemean = srcMat.mapRows((vector) => vector - srcMean);
    final dstDemean = dstMat.mapRows((vector) => vector - dstMean);

    // Eq. (38).
    final A = (dstDemean.transpose() * srcDemean) / num;

    // Eq. (39).
    var d = Vector.filled(dim, 1.0);
    if (A.determinant() < 0) {
      d = d.set(dim - 1, -1);
    }

    var T = Matrix.identity(dim + 1);

    final svdResult = A.svd();
    final Matrix U = svdResult['U']!;
    final Vector S = svdResult['S']!;
    final Matrix V = svdResult['V']!;

    // Eq. (40) and (43).
    final rank = A.matrixRank();
    if (rank == 0) {
      return T * double.nan;
    } else if (rank == dim - 1) {
      if (U.determinant() * V.determinant() > 0) {
        T = T.setSubMatrix(0, dim, 0, dim, U * V);
      } else {
        final s = d[dim - 1];
        d = d.set(dim - 1, -1);
        final replacement = U * Matrix.diagonal(d.toList()) * V;
        T = T.setSubMatrix(0, dim, 0, dim, replacement);
        d = d.set(dim - 1, s);
      }
    } else {
      final replacement = U * Matrix.diagonal(d.toList()) * V;
      T = T.setSubMatrix(0, dim, 0, dim, replacement);
    }

    var scale = 1.0;
    if (estimateScale) {
      // Eq. (41) and (42).
      scale = 1.0 / srcDemean.variance(Axis.columns).sum() * (S * d).sum();
    }

    final subTIndices = Iterable<int>.generate(dim, (index) => index);
    final subT = T.sample(rowIndices: subTIndices, columnIndices: subTIndices);
    final newSubT = dstMean - (subT * srcMean) * scale;
    T = T.setValues(0, dim, dim, dim + 1, newSubT);
    final newNewSubT =
        T.sample(rowIndices: subTIndices, columnIndices: subTIndices) * scale;
    T = T.setSubMatrix(0, dim, 0, dim, newNewSubT);

    return T;
  }

  /// Function to warp an image with an affine transformation using the estimated parameters.
  /// Returns the warped image in the specified width and height, in Uint8List format.
  ///
  /// WARNING: This function is not efficient due to encoding with the image package. Use the [warpAffineToMatrix] function instead.
  Uint8List warpAffine({
    required Uint8List imageData,
    required Matrix transformationMatrix,
    int width = 112,
    int height = 112,
  }) {
    final image_lib.Image outputImage = image_lib.Image(width, height);
    final image_lib.Image inputImage = image_lib.decodeImage(imageData)!;

    if (width != 112 || height != 112) {
      throw Exception(
        'Width and height must be 112, other transformations are not supported yet.',
      );
    }

    final A = Matrix.fromList([
      [transformationMatrix[0][0], transformationMatrix[0][1]],
      [transformationMatrix[1][0], transformationMatrix[1][1]]
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

        // Get the original pixels, either in image_lib.Pixel or in Uint32
        final pixel1 = inputImage.getPixelSafe(x0, y0);
        final pixel2 = inputImage.getPixelSafe(x1, y0);
        final pixel3 = inputImage.getPixelSafe(x0, y1);
        final pixel4 = inputImage.getPixelSafe(x1, y1);

        // Calculate the weights for each pixel
        final fx = xOrigin - x0;
        final fy = yOrigin - y0;
        final fx1 = 1.0 - fx;
        final fy1 = 1.0 - fy;

        // Calculate the weighted sum of pixels
        final int r = _bilinearInterpolation(
          pixel1.r,
          pixel2.r,
          pixel3.r,
          pixel4.r,
          fx,
          fy,
          fx1,
          fy1,
        );
        final int g = _bilinearInterpolation(
          pixel1.g,
          pixel2.g,
          pixel3.g,
          pixel4.g,
          fx,
          fy,
          fx1,
          fy1,
        );
        final int b = _bilinearInterpolation(
          pixel1.b,
          pixel2.b,
          pixel3.b,
          pixel4.b,
          fx,
          fy,
          fx1,
          fy1,
        );

        // Set the new pixel
        outputImage.setPixel(
          xTrans,
          yTrans,
          _encodeColor(r, g, b),
        );
      }
    }

    final Uint8List outputData = image_lib.encodeJpg(outputImage) as Uint8List;

    return outputData;
  }

  /// Function to warp an image with an affine transformation using the estimated parameters.
  ///
  /// 'inputImage': The image to warp, in the image package format [image_lib.Image].
  /// 'transformationMatrix': The transformation matrix, in the format of a 3x3 matrix.
  ///
  /// Returns the warped face in the specified width and height, in [Num3DInputMatrix].
  /// In fact, this is either a [Double3DInputMatrix] or a [Int3DInputMatrix] depending on the `normalize` argument.
  /// If `normalize` is true, the pixel values are normalized doubles in range [-1, 1]. Otherwise, they are integers in range [0, 255].
  ///
  /// Runs efficiently in about 3-9 ms after initial warm-up.
  Num3DInputMatrix warpAffineToMatrix({
    required image_lib.Image inputImage,
    required Matrix transformationMatrix,
    bool normalize = true,
    int width = 112,
    int height = 112,
  }) {
    final Num3DInputMatrix outputMatrix = List.generate(
      height,
      (y) => List.generate(
        width,
        (_) => List.filled(3, 0),
      ),
    );

    if (width != 112 || height != 112) {
      throw Exception(
        'Width and height must be 112, other transformations are not supported yet.',
      );
    }

    final A = Matrix.fromList([
      [transformationMatrix[0][0], transformationMatrix[0][1]],
      [transformationMatrix[1][0], transformationMatrix[1][1]]
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
        final pixel1 = inputImage.getPixelSafe(x0, y0);
        final pixel2 = inputImage.getPixelSafe(x1, y0);
        final pixel3 = inputImage.getPixelSafe(x0, y1);
        final pixel4 = inputImage.getPixelSafe(x1, y1);

        // Calculate the weights for each pixel
        final fx = xOrigin - x0;
        final fy = yOrigin - y0;
        final fx1 = 1.0 - fx;
        final fy1 = 1.0 - fy;

        // Calculate the weighted sum of pixels
        final int r = SimilarityTransform._bilinearInterpolation(
          pixel1.r,
          pixel2.r,
          pixel3.r,
          pixel4.r,
          fx,
          fy,
          fx1,
          fy1,
        );
        final int g = SimilarityTransform._bilinearInterpolation(
          pixel1.g,
          pixel2.g,
          pixel3.g,
          pixel4.g,
          fx,
          fy,
          fx1,
          fy1,
        );
        final int b = SimilarityTransform._bilinearInterpolation(
          pixel1.b,
          pixel2.b,
          pixel3.b,
          pixel4.b,
          fx,
          fy,
          fx1,
          fy1,
        );

        // Determine which function to use to get the pixel value.
        final pixelValue = normalize ? normalizePixel : (int value) => value;

        // Set the new pixel
        outputMatrix[xTrans]
            [yTrans] = [pixelValue(r), pixelValue(g), pixelValue(b)];
      }
    }

    return outputMatrix;
  }

  static int _bilinearInterpolation(
    num val1,
    num val2,
    num val3,
    num val4,
    num fx,
    num fy,
    num fx1,
    num fy1,
  ) {
    return (val1 * fx1 * fy1 +
            val2 * fx * fy1 +
            val3 * fx1 * fy +
            val4 * fx * fy)
        .round();
  }

  static int _encodeColor(int red, int green, int blue, {int alpha = 0xFF}) {
    return (alpha << 24) | (blue << 16) | (green << 8) | red;
  }
}
