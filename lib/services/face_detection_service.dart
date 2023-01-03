import 'dart:io';
import 'dart:math';

import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:ml_linalg/vector.dart';
import 'package:photos/models/ml/faces/anchor_options.dart';
import 'package:photos/models/ml/faces/face_detection.dart';
import 'package:photos/models/ml/faces/face_options.dart';
import 'package:photos/services/face_detection/face_detection_service.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

class FaceDetectionService {
  final _logger = Logger("FaceDetectionService");

  FaceDetectionService._privateConstructor();

  static FaceDetectionService instance =
      FaceDetectionService._privateConstructor();

  Future<List<File>> getFaceCrops(File file) async {
    try {
      return await getFaceCropsNewV2(file);
    } catch (e, s) {
      _logger.severe(e, s);
    }
    final options = FaceDetectorOptions();
    final faceDetector = FaceDetector(options: options);
    final faces = await faceDetector.processImage(InputImage.fromFile(file));
    final List<File> faceCrops = [];
    for (final face in faces) {
      try {
        final croppedFace = await FlutterNativeImage.cropImage(
          file.path,
          face.boundingBox.left.toInt(),
          face.boundingBox.top.toInt(),
          face.boundingBox.width.toInt(),
          face.boundingBox.height.toInt(),
        );
        faceCrops.add(croppedFace);
      } catch (e) {
        _logger.severe(e);
      }
    }
    return faceCrops;
  }

  bool isRunning = false;

  Future<List<File>> getFaceCropsNewV2(File file) async {
    // if (isRunning) {
    //   return [];
    // }

    isRunning = true;
    final image = img.decodeImage(file.readAsBytesSync())!;
    final faceDetection = FaceDetection();
    _logger.info("loading model");
    await faceDetection.loadModel();
    _logger.info("model loaded");
    try {
      final faces = faceDetection.predict(image);
      if (faces != null) {
        _logger.info(faces.length.toString() + " faces detected");

        final List<File> faceCrops = [];

        // for (final face in faces.values) {
        final face = faces["bbox"];
        try {
          final croppedFace = await FlutterNativeImage.cropImage(
            file.path,
            face.left.toInt(),
            face.top.toInt(),
            face.width.toInt(),
            face.height.toInt(),
          );
          faceCrops.add(croppedFace);
        } catch (e, s) {
          _logger.severe(e, s);
        }
        // }
        return faceCrops;
      }
    } catch (e, s) {
      _logger.severe(e, s);
    }
    isRunning = false;
    return [];
  }

  Future<List<File>> getFaceCropsBF(File file) async {
    final faceOptions = FaceOptions(
      numClasses: 1,
      numBoxes: 896,
      numCoords: 16,
      keypointCoordOffset: 4,
      ignoreClasses: [],
      scoreClippingThresh: 100.0,
      minScoreThresh: 0.75,
      numKeypoints: 6,
      numValuesPerKeypoint: 2,
      reverseOutputOrder: false,
      boxCoordOffset: 0,
      xScale: 128,
      yScale: 128,
      hScale: 128,
      wScale: 128,
    );

    final anchorOptions = AnchorOptions(
      inputSizeHeight: 128,
      inputSizeWidth: 128,
      minScale: 0.1484375,
      maxScale: 0.75,
      anchorOffsetX: 0.5,
      anchorOffsetY: 0.5,
      numLayers: 4,
      featureMapHeight: [],
      featureMapWidth: [],
      strides: [8, 16, 16, 16],
      aspectRatios: [1.0],
      reduceBoxesInLowestLayer: false,
      interpolatedScaleAspectRatio: 1.0,
      fixedAnchorSize: true,
    );

    final interpreter = await Interpreter.fromAsset(
      "models/face_detection_back.tflite",
    );
    final inputShape = interpreter.getInputTensor(0).shape;
    final normalizeInput = NormalizeOp(127.5, 127.5);

    final imageProcessor = ImageProcessorBuilder()
        .add(
          ResizeOp(
            inputShape[1],
            inputShape[2],
            ResizeMethod.NEAREST_NEIGHBOUR,
          ),
        )
        .add(normalizeInput)
        .build();

    final image = img.decodeImage(file.readAsBytesSync())!;
    final tfImage = TensorImage(TfLiteType.float32);
    tfImage.loadImage(image);
    final inputImage = imageProcessor.process(tfImage);

    final output0 = TensorBuffer.createFixedSize(
      interpreter.getOutputTensor(0).shape,
      interpreter.getOutputTensor(0).type,
    );
    final output1 = TensorBuffer.createFixedSize(
      interpreter.getOutputTensor(1).shape,
      interpreter.getOutputTensor(1).type,
    );
    final outputs = {0: output0.buffer, 1: output1.buffer};

    interpreter.runForMultipleInputs([inputImage.buffer], outputs);

    final detections = _process(
      options: faceOptions,
      rawScores: output1.getDoubleList(),
      rawBoxes: output0.getDoubleList(),
      anchors: _getAnchors(anchorOptions),
    );
    final newDetections = origNms(detections, 0.75);
    _logger.info(newDetections.length.toString() + " faces detected");
    return [];
  }

  List<Anchor> _getAnchors(AnchorOptions options) {
    final anchors = <Anchor>[];
    if (options.stridesSize != options.numLayers) {
      print('strides_size and num_layers must be equal.');
      return [];
    }
    int layerID = 0;
    while (layerID < options.stridesSize) {
      final anchorHeight = <double>[];
      final anchorWidth = <double>[];
      final aspectRatios = <double>[];
      final scales = <double>[];

      int lastSameStrideLayer = layerID;
      while (lastSameStrideLayer < options.stridesSize &&
          options.strides[lastSameStrideLayer] == options.strides[layerID]) {
        final scale = options.minScale +
            (options.maxScale - options.minScale) *
                1.0 *
                lastSameStrideLayer /
                (options.stridesSize - 1.0);
        if (lastSameStrideLayer == 0 && options.reduceBoxesInLowestLayer) {
          aspectRatios.add(1.0);
          aspectRatios.add(2.0);
          aspectRatios.add(0.5);
          scales.add(0.1);
          scales.add(scale);
          scales.add(scale);
        } else {
          for (int i = 0; i < options.aspectRatios.length; i++) {
            aspectRatios.add(options.aspectRatios[i]);
            scales.add(scale);
          }

          if (options.interpolatedScaleAspectRatio > 0.0) {
            double scaleNext = 0.0;
            if (lastSameStrideLayer == options.stridesSize - 1) {
              scaleNext = 1.0;
            } else {
              scaleNext = options.minScale +
                  (options.maxScale - options.minScale) *
                      1.0 *
                      (lastSameStrideLayer + 1) /
                      (options.stridesSize - 1.0);
            }
            scales.add(sqrt(scale * scaleNext));
            aspectRatios.add(options.interpolatedScaleAspectRatio);
          }
        }
        lastSameStrideLayer++;
      }
      for (int i = 0; i < aspectRatios.length; i++) {
        final ratioSQRT = sqrt(aspectRatios[i]);
        anchorHeight.add(scales[i] / ratioSQRT);
        anchorWidth.add(scales[i] * ratioSQRT);
      }
      int featureMapHeight = 0;
      int featureMapWidth = 0;
      if (options.featureMapHeightSize > 0) {
        featureMapHeight = options.featureMapHeight[layerID];
        featureMapWidth = options.featureMapWidth[layerID];
      } else {
        final stride = options.strides[layerID];
        featureMapHeight = (1.0 * options.inputSizeHeight / stride).ceil();
        featureMapWidth = (1.0 * options.inputSizeWidth / stride).ceil();
      }

      for (int y = 0; y < featureMapHeight; y++) {
        for (int x = 0; x < featureMapWidth; x++) {
          for (int anchorID = 0; anchorID < anchorHeight.length; anchorID++) {
            final xCenter = (x + options.anchorOffsetX) * 1.0 / featureMapWidth;
            final yCenter =
                (y + options.anchorOffsetY) * 1.0 / featureMapHeight;
            double w = 0;
            double h = 0;
            if (options.fixedAnchorSize) {
              w = 1.0;
              h = 1.0;
            } else {
              w = anchorWidth[anchorID];
              h = anchorHeight[anchorID];
            }
            anchors.add(Anchor(xCenter, yCenter, h, w));
          }
        }
      }
      layerID = lastSameStrideLayer;
    }
    return anchors;
  }

  List<Detection> _process({
    required FaceOptions options,
    required List<double> rawScores,
    required List<double> rawBoxes,
    required List<Anchor> anchors,
  }) {
    final detectionScores = <double>[];
    final detectionClasses = <int>[];
    for (int i = 0; i < options.numBoxes; i++) {
      int classId = -1;
      double maxScore = double.minPositive;
      for (int scoreIdx = 0; scoreIdx < options.numClasses; scoreIdx++) {
        double score = rawScores[i * options.numClasses + scoreIdx];
        if (options.sigmoidScore) {
          if (options.scoreClippingThresh > 0) {
            if (score < -options.scoreClippingThresh) {
              score = -options.scoreClippingThresh;
            }
            if (score > options.scoreClippingThresh) {
              score = options.scoreClippingThresh;
            }
            score = 1.0 / (1.0 + exp(-score));
            if (maxScore < score) {
              maxScore = score;
              classId = scoreIdx;
            }
          }
        }
      }
      detectionClasses.add(classId);
      detectionScores.add(maxScore);
    }
    return convertToDetections(
      rawBoxes,
      anchors,
      detectionScores,
      detectionClasses,
      options,
    );
  }

  List<Detection> convertToDetections(
    List<double> rawBoxes,
    List<Anchor> anchors,
    List<double> detectionScores,
    List<int> detectionClasses,
    FaceOptions options,
  ) {
    final outputDetections = <Detection>[];
    for (int i = 0; i < options.numBoxes; i++) {
      if (detectionScores[i] < options.minScoreThresh) {
        continue;
      }
      const boxOffset = 0;
      final boxData = decodeBox(rawBoxes, i, anchors, options);
      final detection = convertToDetection(
        boxData[boxOffset + 0],
        boxData[boxOffset + 1],
        boxData[boxOffset + 2],
        boxData[boxOffset + 3],
        detectionScores[i],
        detectionClasses[i],
        options.flipVertically,
      );
      outputDetections.add(detection);
    }
    return outputDetections;
  }

  List<double> decodeBox(
    List<double> rawBoxes,
    int i,
    List<Anchor> anchors,
    FaceOptions options,
  ) {
    final boxData = List.filled(options.numCoords, 0.0);
    final boxOffset = i * options.numCoords + options.boxCoordOffset;
    double yCenter = rawBoxes[boxOffset];
    double xCenter = rawBoxes[boxOffset + 1];
    double h = rawBoxes[boxOffset + 2];
    double w = rawBoxes[boxOffset + 3];
    if (options.reverseOutputOrder) {
      xCenter = rawBoxes[boxOffset];
      yCenter = rawBoxes[boxOffset + 1];
      w = rawBoxes[boxOffset + 2];
      h = rawBoxes[boxOffset + 3];
    }

    xCenter = xCenter / options.xScale * anchors[i].w + anchors[i].xCenter;
    yCenter = yCenter / options.yScale * anchors[i].h + anchors[i].yCenter;

    if (options.applyExponentialOnBoxSize) {
      h = exp(h / options.hScale) * anchors[i].h;
      w = exp(w / options.wScale) * anchors[i].w;
    } else {
      h = h / options.hScale * anchors[i].h;
      w = w / options.wScale * anchors[i].w;
    }

    final yMin = yCenter - h / 2.0;
    final xMin = xCenter - w / 2.0;
    final yMax = yCenter + h / 2.0;
    final xMax = xCenter + w / 2.0;

    boxData[0] = yMin;
    boxData[1] = xMin;
    boxData[2] = yMax;
    boxData[3] = xMax;

    if (options.numKeypoints > 0) {
      for (int k = 0; k < options.numKeypoints; k++) {
        final offset = i * options.numCoords +
            options.keypointCoordOffset +
            k * options.numValuesPerKeypoint;
        double keyPointY = rawBoxes[offset];
        double keyPointX = rawBoxes[offset + 1];

        if (options.reverseOutputOrder) {
          keyPointX = rawBoxes[offset];
          keyPointY = rawBoxes[offset + 1];
        }
        boxData[4 + k * options.numValuesPerKeypoint] =
            keyPointX / options.xScale * anchors[i].w + anchors[i].xCenter;

        boxData[4 + k * options.numValuesPerKeypoint + 1] =
            keyPointY / options.yScale * anchors[i].h + anchors[i].yCenter;
      }
    }
    return boxData;
  }

  Detection convertToDetection(
    double boxYMin,
    double boxXMin,
    double boxYMax,
    double boxXMax,
    double score,
    int classID,
    bool flipVertically,
  ) {
    double yMin;
    if (flipVertically) {
      yMin = 1.0 - boxYMax;
    } else {
      yMin = boxYMin;
    }
    return Detection(
      score,
      classID,
      boxXMin,
      yMin,
      (boxXMax - boxXMin),
      (boxXMax - boxYMin),
    );
  }

  List<Detection> origNms(List<Detection> detections, double threshold) {
    if (detections.isEmpty) {
      return [];
    }
    final x1 = <double>[];
    final x2 = <double>[];
    final y1 = <double>[];
    final y2 = <double>[];
    final s = <double>[];

    detections.forEach((detection) {
      x1.add(detection.xMin);
      x2.add(detection.xMin + detection.width);
      y1.add(detection.yMin);
      y2.add(detection.yMin + detection.height);
      s.add(detection.score);
    });

    final x1Copy = Vector.fromList(x1);
    final x2Copy = Vector.fromList(x2);
    final y1Copy = Vector.fromList(y1);
    final y2Copy = Vector.fromList(y2);

    final area = (x2Copy - x1Copy) * (y2Copy - y1Copy);
    final areaList = area.toList();

    List<double> I = _quickSort(s);
    final positions = <int>[];
    I.forEach((element) {
      positions.add(s.indexOf(element));
    });

    final ind0 = positions.sublist(positions.length - 1, positions.length);
    final ind1 = positions.sublist(0, positions.length - 1);

    final pick = <int>[];
    while (I.isNotEmpty) {
      final xx1 = _maximum(_itemIndex(x1, ind0)[0], _itemIndex(x1, ind1));
      final yy1 = _maximum(_itemIndex(y1, ind0)[0], _itemIndex(y1, ind1));
      final xx2 = _maximum(_itemIndex(x2, ind0)[0], _itemIndex(x2, ind1));
      final yy2 = _maximum(_itemIndex(y2, ind0)[0], _itemIndex(y2, ind1));
      final List<double> xDiff = List<double>.from(xx2 - xx1);
      final List<double> yDiff = List<double>.from(yy2 - yy1);
      final w = _maximum(0.0, xDiff);
      final h = _maximum(0.0, yDiff);
      final inter = w * h;
      final o = List<double>.from(
        inter /
            (_sum(_itemIndex(areaList, ind0)[0], _itemIndex(areaList, ind1)) -
                inter),
      );
      pick.add(ind0[0]);
      I = o.where((element) => element <= threshold).toList();
    }
    return [detections[pick[0]]];
  }

  Vector _sum(double a, List<double> b) {
    final temp = <double>[];
    b.forEach((element) {
      temp.add(a + element);
    });
    return Vector.fromList(temp);
  }

  Vector _maximum(double value, List<double> itemIndex) {
    final temp = <double>[];
    itemIndex.forEach((element) {
      if (value > element) {
        temp.add(value);
      } else {
        temp.add(element);
      }
    });
    return Vector.fromList(temp);
  }

  List<double> _itemIndex(List<double> item, List<int> positions) {
    final temp = <double>[];
    positions.forEach((element) => temp.add(item[element]));
    return List.from(temp);
  }

  List<double> _quickSort(List<double> a) {
    if (a.length <= 1) return a;

    final pivot = a[0];
    var less = <double>[];
    var more = <double>[];
    final pivotList = <double>[];

    a.forEach((var i) {
      if (i.compareTo(pivot) < 0) {
        less.add(i);
      } else if (i.compareTo(pivot) > 0) {
        more.add(i);
      } else {
        pivotList.add(i);
      }
    });

    less = _quickSort(less);
    more = _quickSort(more);

    less.addAll(pivotList);
    less.addAll(more);
    return less;
  }
}
