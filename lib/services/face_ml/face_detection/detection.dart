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

  @override
  String toString() {
    return 'FaceDetectionRelative( with relative coordinates: \n score: $score \n Box: xMinBox: $xMinBox, yMinBox: $yMinBox, xMaxBox: $xMaxBox, yMaxBox: $yMaxBox, \n Keypoints: leftEye: $leftEye, rightEye: $rightEye, nose: $nose, mouth: $mouth, leftEar: $leftEar, rightEar: $rightEar \n )';
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
      score: json['score'],
      box: json['box'],
      allKeypoints: json['allKeypoints'],
    );
  }

  static FaceDetectionAbsolute empty = FaceDetectionAbsolute._zero();

  @override
  int get width => xMaxBox - xMinBox;
  @override
  int get height => yMaxBox - yMinBox;
}

List<FaceDetectionAbsolute> relativeToAbsoluteDetections({
  required List<FaceDetectionRelative> detections,
  required int originalWidth,
  required int originalHeight,
}) {
  final numberOfDetections = detections.length;
  final intDetections = List<FaceDetectionAbsolute>.filled(
    numberOfDetections,
    FaceDetectionAbsolute._zero(),
  );
  for (var i = 0; i < detections.length; i++) {
    final detection = detections[i];
    final score = detection.score;
    final box = detection.box;
    final allKeypoints = detection.allKeypoints;

    box[0] *= originalWidth;
    box[1] *= originalHeight;
    box[2] *= originalWidth;
    box[3] *= originalHeight;
    final intbox = box.map((e) => e.toInt()).toList();

    for (var keypoint in allKeypoints) {
      keypoint[0] *= originalWidth;
      keypoint[1] *= originalHeight;
    }
    final intKeypoints =
        allKeypoints.map((e) => e.map((e) => e.toInt()).toList()).toList();

    intDetections[i] = FaceDetectionAbsolute(
      score: score,
      box: intbox,
      allKeypoints: intKeypoints,
    );
  }

  return intDetections;
}
