import "package:photos/services/face_ml/face_clustering/cosine_distance.dart";

class DBSCANConfig {
  final double epsilon;
  final int minPoints;
  final double Function(List<double>, List<double>) distanceMeasure;

  DBSCANConfig({
    required this.epsilon,
    required this.minPoints,
    this.distanceMeasure = cosineDistance,
  });
}

final DBSCANConfig faceClusteringDBSCANConfig = DBSCANConfig(
  // TODO: Find the best epsilon and minPoints for clustering faces
  epsilon: 0.5,
  minPoints: 4,
  distanceMeasure: cosineDistance,
);
