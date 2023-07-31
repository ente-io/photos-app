import "package:flutter/material.dart" show Size, immutable;
import "package:photos/models/ml_typedefs.dart";
import "package:photos/services/face_ml/face_alignment/alignment_result.dart";
import "package:photos/services/face_ml/face_detection/detection.dart";
import "package:photos/services/face_ml/face_ml_methods.dart";

@immutable
class FaceMlResult {
  final FaceDetectionMethod faceDetectionMethod;
  final FaceAlignmentMethod faceAlignmentMethod;
  final FaceEmbeddingMethod faceEmbeddingMethod;

  final List<FaceResult> faces;

  final int fileId;
  final Size imageDimensions;
  final String? imageSource;
  final String? lastErrorMessage;
  final int errorCount;
  final int mlVersion;

  const FaceMlResult({
    required this.faceDetectionMethod,
    required this.faceAlignmentMethod,
    required this.faceEmbeddingMethod,
    required this.faces,
    required this.fileId,
    required this.imageDimensions,
    required this.imageSource,
    required this.lastErrorMessage,
    required this.errorCount,
    required this.mlVersion,
  });

  Map<String, dynamic> toJson() => {
        'faceDetectionMethod': faceDetectionMethod.toJson(),
        'faceAlignmentMethod': faceAlignmentMethod.toJson(),
        'faceEmbeddingMethod': faceEmbeddingMethod.toJson(),
        'faces': faces,
        'fileId': fileId,
        'imageDimensions': imageDimensions,
        'imageSource': imageSource,
        'lastErrorMessage': lastErrorMessage,
        'errorCount': errorCount,
        'mlVersion': mlVersion,
      };

  FaceMlResult fromJson(Map<String, dynamic> json) {
    return FaceMlResult(
      faceDetectionMethod: json['faceDetectionMethod'],
      faceAlignmentMethod: json['faceAlignmentMethod'],
      faceEmbeddingMethod: json['faceEmbeddingMethod'],
      faces: json['faces'],
      fileId: json['fileId'],
      imageDimensions: json['imageDimensions'],
      imageSource: json['imageSource'],
      lastErrorMessage: json['lastErrorMessage'],
      errorCount: json['errorCount'],
      mlVersion: json['mlVersion'],
    );
  }
}

class FaceMlResultBuilder {
  FaceDetectionMethod faceDetectionMethod;
  FaceAlignmentMethod faceAlignmentMethod;
  FaceEmbeddingMethod faceEmbeddingMethod;

  List<FaceResultBuilder> faces;

  int fileId;
  Size imageDimensions;
  String imageSource;
  String lastErrorMessage;
  int errorCount;
  int mlVersion;

  FaceMlResultBuilder({
    this.faceDetectionMethod = const FaceDetectionMethod.empty(),
    this.faceAlignmentMethod = const FaceAlignmentMethod.empty(),
    this.faceEmbeddingMethod = const FaceEmbeddingMethod.empty(),
    this.faces = const <FaceResultBuilder>[],
    this.fileId = -1,
    this.imageDimensions = const Size(0, 0),
    this.imageSource = '',
    this.lastErrorMessage = '',
    this.errorCount = 0,
    this.mlVersion = -1,
  });

  FaceMlResultBuilder.createWithMlMethods()
      : faceDetectionMethod = FaceDetectionMethod.blazeFace(),
        faceAlignmentMethod = FaceAlignmentMethod.arcFace(),
        faceEmbeddingMethod = FaceEmbeddingMethod.mobileFaceNet(),
        faces = const <FaceResultBuilder>[],
        fileId = -1,
        imageDimensions = const Size(0, 0),
        imageSource = '',
        lastErrorMessage = '',
        errorCount = 0,
        mlVersion = -1;

  /// Adds the ML methods to the FaceMlResultBuilder
  ///
  /// WARNING: This overrides all methods, even if you only give the argument for one specific method
  void addMlMethods({
    FaceDetectionMethod? faceDetectionMethod,
    FaceAlignmentMethod? faceAlignmentMethod,
    FaceEmbeddingMethod? faceEmbeddingMethod,
  }) {
    faceDetectionMethod ??= FaceDetectionMethod.blazeFace();
    faceAlignmentMethod ??= FaceAlignmentMethod.arcFace();
    faceEmbeddingMethod ??= FaceEmbeddingMethod.mobileFaceNet();

    this.faceDetectionMethod = faceDetectionMethod;
    this.faceAlignmentMethod = faceAlignmentMethod;
    this.faceEmbeddingMethod = faceEmbeddingMethod;
  }

  void addNewlyDetectedFaces(List<FaceDetectionAbsolute> faceDetections) {
    for (var i = 0; i < faceDetections.length; i++) {
      faces.add(FaceResultBuilder.fromFaceDetection(faceDetections[i]));
    }
  }

  void addAlignmentToExistingFace(
    List<List<double>> transformationMatrix,
    int faceIndex,
  ) {
    if (faceIndex >= faces.length) {
      throw Exception(
        "Face index $faceIndex is out of bounds. There are only ${faces.length} faces",
      );
    }
    faces[faceIndex].alignment =
        AlignmentResult(affineMatrix: transformationMatrix);
  }

  void addEmbeddingsToExistingFaces(
    List<Embedding> embeddings,
  ) {
    if (embeddings.length != faces.length) {
      throw Exception(
        "The amount of embeddings (${embeddings.length}) does not match the number of faces (${faces.length})",
      );
    }
    for (var faceIndex = 0; faceIndex < faces.length; faceIndex++) {
      faces[faceIndex].embedding = embeddings[faceIndex];
    }
  }

  FaceMlResult build() {
    _noProperFileAcces();
    final faceResults = <FaceResult>[];
    for (var i = 0; i < faces.length; i++) {
      faceResults.add(faces[i].build());
    }

    return FaceMlResult(
      faceAlignmentMethod: faceAlignmentMethod,
      faceDetectionMethod: faceDetectionMethod,
      faceEmbeddingMethod: faceEmbeddingMethod,
      faces: faceResults,
      fileId: fileId,
      imageDimensions: imageDimensions,
      imageSource: imageSource,
      lastErrorMessage: lastErrorMessage,
      errorCount: errorCount,
      mlVersion: mlVersion,
    );
  }

  FaceMlResult buildNoFaceDetected() {
    faces = <FaceResultBuilder>[];
    return build();
  }

  void _noProperFileAcces() {
    fileId = -1;
    imageDimensions = const Size(0, 0);
    imageSource = '';
    lastErrorMessage = "No proper file access";
    mlVersion = -1;
  }
}

@immutable
class FaceResult {
  final FaceDetectionAbsolute detection;
  final AlignmentResult alignment;
  final Embedding embedding;
  final int fileId;
  final String id;
  final int personId;

  const FaceResult({
    required this.detection,
    required this.alignment,
    required this.embedding,
    required this.fileId,
    required this.id,
    required this.personId,
  });

  Map<String, dynamic> toJson() => {
        'detection': detection.toJson(),
        'alignment': alignment.toJson(),
        'embedding': embedding,
        'fileId': fileId,
        'id': id,
        'personId': personId,
      };

  FaceResult fromJson(Map<String, dynamic> json) {
    return FaceResult(
      detection: json['detection'],
      alignment: json['alignment'],
      embedding: json['embedding'],
      fileId: json['fileId'],
      id: json['id'],
      personId: json['personId'],
    );
  }
}

class FaceResultBuilder {
  FaceDetectionAbsolute detection;
  AlignmentResult alignment;
  Embedding embedding;
  int fileId;
  String id;
  int personId;

  FaceResultBuilder({
    this.detection = const FaceDetectionAbsolute.defaultInitialization(),
    this.alignment = const AlignmentResult.empty(),
    this.embedding = const <double>[],
    this.fileId = -1,
    this.id = '',
    this.personId = -1,
  });

  FaceResultBuilder.fromFaceDetection(FaceDetectionAbsolute faceDetection)
      : detection = faceDetection,
        alignment = const AlignmentResult.empty(),
        embedding = const <double>[],
        fileId = -1,
        id = '',
        personId = -1;

  FaceResult build() {
    return FaceResult(
      detection: detection,
      alignment: alignment,
      embedding: embedding,
      fileId: fileId,
      id: id,
      personId: personId,
    );
  }
}
