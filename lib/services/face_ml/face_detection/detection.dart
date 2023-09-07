abstract class Detection {
  final double score;

  Detection({required this.score});

  const Detection.empty() : score = 0;

  get width;
  get height;

  @override
  String toString();
}

class FaceDetectionRelative extends Detection {
  final List<double> box;
  final List<List<double>> allKeypoints;
  final double xMinBox;
  final double yMinBox;
  final double xMaxBox;
  final double yMaxBox;
  final List<double> leftEye;
  final List<double> rightEye;
  final List<double> nose;
  final List<double> mouth;
  final List<double> leftEar;
  final List<double> rightEar;

  FaceDetectionRelative({
    required double score,
    required this.box,
    required this.allKeypoints,
  })  : xMinBox = box[0],
        yMinBox = box[1],
        xMaxBox = box[2],
        yMaxBox = box[3],
        leftEye = allKeypoints[0],
        rightEye = allKeypoints[1],
        nose = allKeypoints[2],
        mouth = allKeypoints[3],
        leftEar = allKeypoints[4],
        rightEar = allKeypoints[5],
        super(score: score);

  factory FaceDetectionRelative.zero() {
    return FaceDetectionRelative(
      score: 0,
      box: <double>[0, 0, 0, 0],
      allKeypoints: <List<double>>[
        [0, 0],
        [0, 0],
        [0, 0],
        [0, 0],
        [0, 0],
        [0, 0]
      ],
    );
  }

  /// This is used to initialize the FaceDetectionRelative object with default values.
  /// This constructor is useful because it can be used to initialize a FaceDetectionRelative object as a constant.
  /// Contrary to the `FaceDetectionRelative.zero()` constructor, this one gives immutable attributes [box] and [allKeypoints].
  FaceDetectionRelative.defaultInitialization()
      : box = const <double>[0, 0, 0, 0],
        allKeypoints = const <List<double>>[
          [0, 0],
          [0, 0],
          [0, 0],
          [0, 0],
          [0, 0],
          [0, 0]
        ],
        xMinBox = 0,
        yMinBox = 0,
        xMaxBox = 0,
        yMaxBox = 0,
        leftEye = <double>[0, 0],
        rightEye = <double>[0, 0],
        nose = <double>[0, 0],
        mouth = <double>[0, 0],
        leftEar = <double>[0, 0],
        rightEar = <double>[0, 0],
        super.empty();

  FaceDetectionAbsolute toAbsolute({
    required int imageWidth,
    required int imageHeight,
  }) {
    final score = this.score;
    final box = this.box;
    final allKeypoints = this.allKeypoints;

    box[0] *= imageWidth;
    box[1] *= imageHeight;
    box[2] *= imageWidth;
    box[3] *= imageHeight;
    final intbox = box.map((e) => e.toInt()).toList();

    for (List<double> keypoint in allKeypoints) {
      keypoint[0] *= imageWidth;
      keypoint[1] *= imageHeight;
    }
    final intKeypoints =
        allKeypoints.map((e) => e.map((e) => e.toInt()).toList()).toList();
    return FaceDetectionAbsolute(
      score: score,
      box: intbox,
      allKeypoints: intKeypoints,
    );
  }

  @override
  String toString() {
    return 'FaceDetectionRelative( with relative coordinates: \n score: $score \n Box: xMinBox: $xMinBox, yMinBox: $yMinBox, xMaxBox: $xMaxBox, yMaxBox: $yMaxBox, \n Keypoints: leftEye: $leftEye, rightEye: $rightEye, nose: $nose, mouth: $mouth, leftEar: $leftEar, rightEar: $rightEar \n )';
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'box': box,
      'allKeypoints': allKeypoints,
      'xMinBox': xMinBox,
      'yMinBox': yMinBox,
      'xMaxBox': xMaxBox,
      'yMaxBox': yMaxBox,
      'leftEye': leftEye,
      'rightEye': rightEye,
      'nose': nose,
      'mouth': mouth,
      'leftEar': leftEar,
      'rightEar': rightEar,
      'width': width,
      'height': height,
    };
  }

  factory FaceDetectionRelative.fromJson(Map<String, dynamic> json) {
    return FaceDetectionRelative(
      score: (json['score'] as num).toDouble(),
      box: List<double>.from(json['box']),
      allKeypoints: (json['allKeypoints'] as List)
          .map((item) => List<double>.from(item))
          .toList(),
    );
  }

  @override
  double get width => xMaxBox - xMinBox;
  @override
  double get height => yMaxBox - yMinBox;
}

class FaceDetectionAbsolute extends Detection {
  final List<int> box;
  final List<List<int>> allKeypoints;
  final int xMinBox;
  final int yMinBox;
  final int xMaxBox;
  final int yMaxBox;
  final List<int> leftEye;
  final List<int> rightEye;
  final List<int> nose;
  final List<int> mouth;
  final List<int> leftEar;
  final List<int> rightEar;

  FaceDetectionAbsolute({
    required double score,
    required this.box,
    required this.allKeypoints,
  })  : xMinBox = box[0],
        yMinBox = box[1],
        xMaxBox = box[2],
        yMaxBox = box[3],
        leftEye = allKeypoints[0],
        rightEye = allKeypoints[1],
        nose = allKeypoints[2],
        mouth = allKeypoints[3],
        leftEar = allKeypoints[4],
        rightEar = allKeypoints[5],
        super(score: score);

  factory FaceDetectionAbsolute._zero() {
    return FaceDetectionAbsolute(
      score: 0,
      box: <int>[0, 0, 0, 0],
      allKeypoints: <List<int>>[
        [0, 0],
        [0, 0],
        [0, 0],
        [0, 0],
        [0, 0],
        [0, 0]
      ],
    );
  }

  FaceDetectionAbsolute.defaultInitialization()
      : box = const <int>[0, 0, 0, 0],
        allKeypoints = const <List<int>>[
          [0, 0],
          [0, 0],
          [0, 0],
          [0, 0],
          [0, 0],
          [0, 0]
        ],
        xMinBox = 0,
        yMinBox = 0,
        xMaxBox = 0,
        yMaxBox = 0,
        leftEye = <int>[0, 0],
        rightEye = <int>[0, 0],
        nose = <int>[0, 0],
        mouth = <int>[0, 0],
        leftEar = <int>[0, 0],
        rightEar = <int>[0, 0],
        super.empty();

  @override
  String toString() {
    return 'FaceDetectionRelative( with relative coordinates: \n score: $score \n Box: xMinBox: $xMinBox, yMinBox: $yMinBox, xMaxBox: $xMaxBox, yMaxBox: $yMaxBox, \n Keypoints: leftEye: $leftEye, rightEye: $rightEye, nose: $nose, mouth: $mouth, leftEar: $leftEar, rightEar: $rightEar \n )';
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'box': box,
      'allKeypoints': allKeypoints,
      'xMinBox': xMinBox,
      'yMinBox': yMinBox,
      'xMaxBox': xMaxBox,
      'yMaxBox': yMaxBox,
      'leftEye': leftEye,
      'rightEye': rightEye,
      'nose': nose,
      'mouth': mouth,
      'leftEar': leftEar,
      'rightEar': rightEar,
      'width': width,
      'height': height,
    };
  }

  factory FaceDetectionAbsolute.fromJson(Map<String, dynamic> json) {
    return FaceDetectionAbsolute(
      score: (json['score'] as num).toDouble(),
      box: List<int>.from(json['box']),
      allKeypoints: (json['allKeypoints'] as List)
          .map((item) => List<int>.from(item))
          .toList(),
    );
  }

  static FaceDetectionAbsolute empty = FaceDetectionAbsolute._zero();

  @override
  int get width => xMaxBox - xMinBox;
  @override
  int get height => yMaxBox - yMinBox;
}

List<FaceDetectionAbsolute> relativeToAbsoluteDetections({
  required List<FaceDetectionRelative> relativeDetections,
  required int imageWidth,
  required int imageHeight,
}) {
  final numberOfDetections = relativeDetections.length;
  final absoluteDetections = List<FaceDetectionAbsolute>.filled(
    numberOfDetections,
    FaceDetectionAbsolute._zero(),
  );
  for (var i = 0; i < relativeDetections.length; i++) {
    final relativeDetection = relativeDetections[i];
    final absoluteDetection = relativeDetection.toAbsolute(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );

    absoluteDetections[i] = absoluteDetection;
  }

  return absoluteDetections;
}
