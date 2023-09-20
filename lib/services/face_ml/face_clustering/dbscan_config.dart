import "package:photos/services/face_ml/face_clustering/cosine_distance.dart";

class DBSCANConfig {
  final double epsilon;
  final int minPoints;
  final double Function(List<double>, List<double>) distanceMeasure;
  final double minClusterSize;

  DBSCANConfig({
    required this.epsilon,
    required this.minPoints,
    this.distanceMeasure = cosineDistance,
    this.minClusterSize = 5,
  });
}

final DBSCANConfig faceClusteringDBSCANConfig = DBSCANConfig(
  // TODO: Find the best epsilon and minPoints for clustering faces
  epsilon: 0.3,
  minPoints: 5,
  distanceMeasure: cosineDistance,
  minClusterSize: 5,
);
