import 'box.dart';

class Face {
  final int fileID;
  final String id;
  final List<double> embedding;
  final List<(double, double)>? landmarks;
  final Box box;
  final double confidence;

  Face(
    this.id,
    this.fileID,
    this.embedding,
    this.confidence,
    this.box, {
    this.landmarks,
  });

  factory Face.fromJson(Map<String, dynamic> json) {
    return Face(
      json['id'] as String,
      json['fileID'] as int,
      List<double>.from(json['embedding'] as List),
      json['confidence'] as double,
      Box.fromJson(json['box'] as Map<String, dynamic>),
      landmarks: json['landmarks'] as List<(double, double)>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileID': fileID,
        'embedding': embedding,
        'box': box.toJson(),
        'confidence': confidence,
        'landmarks': landmarks,
      };
}
