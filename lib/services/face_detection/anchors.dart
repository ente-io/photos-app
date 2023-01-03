class AnchorOption {
  int inputSizeWidth;
  int inputSizeHeight;
  final double minScale;
  final double maxScale;
  final double anchorOffsetX;
  final double anchorOffsetY;
  final int numLayers;
  final List<int> featureMapWidth;
  final List<int> featureMapHeight;
  final List<int> strides;
  final List<double> aspectRatios;
  final bool reduceBoxesInLowestLayer;
  final double interpolatedScaleAspectRatio;
  final bool fixedAnchorSize;

  AnchorOption({
    required this.inputSizeWidth,
    required this.inputSizeHeight,
    required this.minScale,
    required this.maxScale,
    required this.anchorOffsetX,
    required this.anchorOffsetY,
    required this.numLayers,
    required this.featureMapWidth,
    required this.featureMapHeight,
    required this.strides,
    required this.aspectRatios,
    required this.reduceBoxesInLowestLayer,
    required this.interpolatedScaleAspectRatio,
    required this.fixedAnchorSize,
  });

  int get stridesSize {
    return strides.length;
  }

  int get aspectRatiosSize {
    return aspectRatios.length;
  }

  int get featureMapHeightSize {
    return featureMapHeight.length;
  }

  int get featureMapWidthSize {
    return featureMapWidth.length;
  }
}

class Anchor {
  final double xCenter;
  final double yCenter;
  final double h;
  final double w;
  Anchor(this.xCenter, this.yCenter, this.h, this.w);
}
