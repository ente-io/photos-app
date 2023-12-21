import "package:photos/face/model/detection.dart";

class Face {
  final int fileID;
  final String faceID;
  final List<double> embedding;
  Detection detection;
  final double score;

  Face(
    this.faceID,
    this.fileID,
    this.embedding,
    this.score,
    this.detection,
  );

  factory Face.fromJson(Map<String, dynamic> json) {
    return Face(
      json['faceID'] as String,
      json['fileID'] as int,
      List<double>.from(json['embeddings'] as List),
      json['score'] as double,
      Detection.fromJson(json['detection'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'faceID': faceID,
        'fileID': fileID,
        'embeddings': embedding,
        'detection': detection.toJson(),
        'score': score,
      };
}
