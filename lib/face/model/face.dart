import "package:photos/face/model/detection.dart";

class Face {
  final int fileID;
  final String id;
  final List<double> embedding;
  final List<(double, double)>? landmarks;
  Detection detection;
  final double score;

  Face(
    this.id,
    this.fileID,
    this.embedding,
    this.score,
    this.detection, {
    this.landmarks,
  });

  factory Face.fromJson(Map<String, dynamic> json) {
    return Face(
      json['id'] as String,
      json['fileID'] as int,
      List<double>.from(json['embedding'] as List),
      json['confidence'] as double,
      Detection.fromJson(json['detection'] as Map<String, dynamic>),
      landmarks: json['landmarks'] as List<(double, double)>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileID': fileID,
        'embedding': embedding,
        'detection': detection.toJson(),
        'score': score,
      };
}
