import 'dart:math' as math show sqrt;

import "package:logging/logging.dart";
import 'package:photos/services/face_ml/face_detection/blazeface/blazeface_anchors.dart';

List<Anchor> blazefaceGenerateAnchors(AnchorOptions options) {
  final logger = Logger("GenerateAnchors");
  final anchors = <Anchor>[];
  if (options.stridesSize != options.numLayers) {
    logger.warning('strides_size and num_layers must be equal.');
    return [];
  }
  var layerID = 0;
  while (layerID < options.numLayers) {
    final anchorHeight = <double>[];
    final anchorWidth = <double>[];
    final aspectRatios = <double>[];
    final scales = <double>[];

    var lastSameStrideLayer = layerID;
    while (lastSameStrideLayer < options.stridesSize &&
        options.strides[lastSameStrideLayer] == options.strides[layerID]) {
      final scale = _calculateScale(
        options.minScale,
        options.maxScale,
        lastSameStrideLayer,
        options.stridesSize,
      );

      if (lastSameStrideLayer == 0 && options.reduceBoxesInLowestLayer) {
        aspectRatios.add(1.0);
        aspectRatios.add(2.0);
        aspectRatios.add(0.5);
        scales.add(0.1);
        scales.add(scale);
        scales.add(scale);
      } else {
        for (var aspectRatioId = 0;
            aspectRatioId < options.aspectRatiosSize;
            aspectRatioId++) {
          aspectRatios.add(options.aspectRatios[aspectRatioId]);
          scales.add(scale);
        }

        if (options.interpolatedScaleAspectRatio > 0.0) {
          final scaleNext = (lastSameStrideLayer == options.stridesSize - 1)
              ? 1.0
              : _calculateScale(
                  options.minScale,
                  options.maxScale,
                  lastSameStrideLayer + 1,
                  options.stridesSize,
                );
          scales.add(math.sqrt(scale * scaleNext));
          aspectRatios.add(options.interpolatedScaleAspectRatio);
        }
      }
      lastSameStrideLayer++;
    }

    for (var i = 0; i < aspectRatios.length; i++) {
      final ratioSQRT = math.sqrt(aspectRatios[i]);
      anchorHeight.add(scales[i] / ratioSQRT);
      anchorWidth.add(scales[i] * ratioSQRT);
    }
    var featureMapHeight = 0;
    var featureMapWidth = 0;
    if (options.featureMapHeightSize > 0) {
      featureMapHeight = options.featureMapHeight[layerID];
      featureMapWidth = options.featureMapWidth[layerID];
    } else {
      final stride = options.strides[layerID];
      featureMapHeight = (1.0 * options.inputSizeHeight / stride).ceil();
      featureMapWidth = (1.0 * options.inputSizeWidth / stride).ceil();
    }

    for (var y = 0; y < featureMapHeight; y++) {
      for (var x = 0; x < featureMapWidth; x++) {
        for (var anchorID = 0; anchorID < anchorHeight.length; anchorID++) {
          final xCenter = (x + options.anchorOffsetX) * 1.0 / featureMapWidth;
          final yCenter = (y + options.anchorOffsetY) * 1.0 / featureMapHeight;

          var w = 0.0;
          var h = 0.0;
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

double _calculateScale(
  double minScale,
  double maxScale,
  int strideIndex,
  int numStrides,
) {
  if (numStrides == 1) {
    return (minScale + maxScale) * 0.5;
  } else {
    return minScale +
        (maxScale - minScale) * 1.0 * strideIndex / (numStrides - 1.0);
  }
}
