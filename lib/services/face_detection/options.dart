class OptionsFace {
  final int numClasses;
  final int numBoxes;
  final int numCoords;
  final int keypointCoordOffset;
  final List<int> ignoreClasses;
  final double scoreClippingThresh;
  final double minScoreThresh;
  final int numKeypoints;
  final int numValuesPerKeypoint;
  final int boxCoordOffset;
  final double xScale;
  final double yScale;
  final double wScale;
  final double hScale;
  final bool applyExponentialOnBoxSize;
  final bool reverseOutputOrder;
  final bool sigmoidScore;
  final bool flipVertically;

  OptionsFace({
    required this.numClasses,
    required this.numBoxes,
    required this.numCoords,
    required this.keypointCoordOffset,
    required this.ignoreClasses,
    required this.scoreClippingThresh,
    required this.minScoreThresh,
    this.numKeypoints = 0,
    this.numValuesPerKeypoint = 2,
    this.boxCoordOffset = 0,
    this.xScale = 0.0,
    this.yScale = 0.0,
    this.wScale = 0.0,
    this.hScale = 0.0,
    this.applyExponentialOnBoxSize = false,
    this.reverseOutputOrder = true,
    this.sigmoidScore = true,
    this.flipVertically = false,
  });
}
