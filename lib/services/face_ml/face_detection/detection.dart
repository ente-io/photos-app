abstract class Detection {
  final double score;

  Detection({required this.score});

  const Detection.empty() : score = 0;

  get width;
  get height;

  @override
  String toString();
}

/// This class represents a face detection with relative coordinates in the range [0, 1].
/// The coordinates are relative to the image size. The pattern for the coordinates is always [x, y], where x is the horizontal coordinate and y is the vertical coordinate.
///
/// The [score] attribute is a double representing the confidence of the face detection.
///
/// The [box] attribute is a list of 4 doubles, representing the coordinates of the bounding box of the face detection.
/// The four values of the box in order are: [xMinBox, yMinBox, xMaxBox, yMaxBox].
///
/// The [allKeypoints] attribute is a list of 6 lists of 2 doubles, representing the coordinates of the keypoints of the face detection.
/// The six lists of two values in order are: [leftEye, rightEye, nose, mouth, leftEar, rightEar]. Again, all in [x, y] order.
class FaceDetectionRelative extends Detection {
  final List<double> box;
  final List<List<double>> allKeypoints;

  double get xMinBox => box[0];
  double get yMinBox => box[1];
  double get xMaxBox => box[2];
  double get yMaxBox => box[3];

  List<double> get leftEye => allKeypoints[0];
  List<double> get rightEye => allKeypoints[1];
  List<double> get nose => allKeypoints[2];
  List<double> get mouth => allKeypoints[3];
  List<double> get leftEar => allKeypoints[4];
  List<double> get rightEar => allKeypoints[5];

  FaceDetectionRelative({
    required double score,
    required this.box,
    required this.allKeypoints,
  }) : super(score: score);

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
        [0, 0],
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
          [0, 0],
        ],
        super.empty();

  FaceDetectionAbsolute toAbsolute({
    required int imageWidth,
    required int imageHeight,
  }) {
    final scoreCopy = score;
    final boxCopy = List<double>.from(box, growable: false);
    final allKeypointsCopy = allKeypoints
        .map((sublist) => List<double>.from(sublist, growable: false))
        .toList();

    boxCopy[0] *= imageWidth;
    boxCopy[1] *= imageHeight;
    boxCopy[2] *= imageWidth;
    boxCopy[3] *= imageHeight;
    final intbox = boxCopy.map((e) => e.toInt()).toList();

    for (List<double> keypoint in allKeypointsCopy) {
      keypoint[0] *= imageWidth;
      keypoint[1] *= imageHeight;
    }
    final intKeypoints =
        allKeypointsCopy.map((e) => e.map((e) => e.toInt()).toList()).toList();
    return FaceDetectionAbsolute(
      score: scoreCopy,
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

  /// The width of the bounding box of the face detection, in relative range [0, 1].
  double get width => xMaxBox - xMinBox;
  @override

  /// The height of the bounding box of the face detection, in relative range [0, 1].
  double get height => yMaxBox - yMinBox;
}

/// This class represents a face detection with absolute coordinates in pixels, in the range [0, imageWidth] for the horizontal coordinates and [0, imageHeight] for the vertical coordinates.
/// The pattern for the coordinates is always [x, y], where x is the horizontal coordinate and y is the vertical coordinate.
///
/// The [score] attribute is a double representing the confidence of the face detection.
///
/// The [box] attribute is a list of 4 integers, representing the coordinates of the bounding box of the face detection.
/// The four values of the box in order are: [xMinBox, yMinBox, xMaxBox, yMaxBox].
///
/// The [allKeypoints] attribute is a list of 6 lists of 2 integers, representing the coordinates of the keypoints of the face detection.
/// The six lists of two values in order are: [leftEye, rightEye, nose, mouth, leftEar, rightEar]. Again, all in [x, y] order.
class FaceDetectionAbsolute extends Detection {
  final List<int> box;
  final List<List<int>> allKeypoints;

  int get xMinBox => box[0];
  int get yMinBox => box[1];
  int get xMaxBox => box[2];
  int get yMaxBox => box[3];

  List<int> get leftEye => allKeypoints[0];
  List<int> get rightEye => allKeypoints[1];
  List<int> get nose => allKeypoints[2];
  List<int> get mouth => allKeypoints[3];
  List<int> get leftEar => allKeypoints[4];
  List<int> get rightEar => allKeypoints[5];

  FaceDetectionAbsolute({
    required double score,
    required this.box,
    required this.allKeypoints,
  }) : super(score: score);

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
        [0, 0],
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
          [0, 0],
        ],
        super.empty();

  @override
  String toString() {
    return 'FaceDetectionAbsolute( with absolute coordinates: \n score: $score \n Box: xMinBox: $xMinBox, yMinBox: $yMinBox, xMaxBox: $xMaxBox, yMaxBox: $yMaxBox, \n Keypoints: leftEye: $leftEye, rightEye: $rightEye, nose: $nose, mouth: $mouth, leftEar: $leftEar, rightEar: $rightEar \n )';
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'box': box,
      'allKeypoints': allKeypoints,
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

  /// The width of the bounding box of the face detection, in number of pixels, range [0, imageWidth].
  int get width => xMaxBox - xMinBox;
  @override

  /// The height of the bounding box of the face detection, in number of pixels, range [0, imageHeight].
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
