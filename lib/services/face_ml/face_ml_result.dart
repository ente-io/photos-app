import "dart:convert" show jsonEncode, jsonDecode;

import "package:flutter/material.dart" show immutable;
import "package:ml_linalg/linalg.dart";
import "package:photos/models/file/file.dart";
import "package:photos/models/ml_typedefs.dart";
import "package:photos/services/face_ml/face_alignment/alignment_result.dart";
import "package:photos/services/face_ml/face_detection/detection.dart";
import "package:photos/services/face_ml/face_ml_methods.dart";
import "package:uuid/uuid.dart";

const faceMlVersion = 1;
const clusterMlVersion = 1;

@immutable
class ClusterResult {
  final int personId;

  final String thumbnailFaceId;

  final List<int> _fileIds;
  final List<String> _faceIds;

  final Embedding centroid;
  final double centroidDistanceThreshold;

  List<int> get uniqueFileIds {
    return _fileIds.toSet().toList();
  }

  List<String> get uniqueFaceIds {
    return _faceIds.toSet().toList();
  }

  const ClusterResult({
    required this.personId,
    required this.thumbnailFaceId,
    required List<int> fileIds,
    required List<String> faceIds,
    required this.centroid,
    required this.centroidDistanceThreshold,
  })  : _faceIds = faceIds,
        _fileIds = fileIds;

  Map<String, dynamic> _toJson() => {
        'personId': personId,
        'displayFaceId': thumbnailFaceId,
        'fileIds': _fileIds,
        'faceIds': _faceIds,
        'centroid': centroid,
        'centroidDistanceThreshold': centroidDistanceThreshold,
      };

  String toJsonString() => jsonEncode(_toJson());

  static ClusterResult _fromJson(Map<String, dynamic> json) {
    return ClusterResult(
      personId: json['personId'] ?? -1,
      thumbnailFaceId: json['displayFaceId'] ?? '',
      fileIds:
          (json['fileIds'] as List?)?.map((item) => item as int).toList() ?? [],
      faceIds:
          (json['faceIds'] as List?)?.map((item) => item as String).toList() ??
              [],
      centroid:
          (json['centroid'] as List?)?.map((item) => item as double).toList() ??
              [],
      centroidDistanceThreshold: json['centroidDistanceThreshold'] ?? 0,
    );
  }

  static ClusterResult fromJsonString(String jsonString) {
    return _fromJson(jsonDecode(jsonString));
  }
}

class ClusterResultBuilder {
  int personId = -1;
  String thumbnailFaceId = '';

  List<int> fileIds = <int>[];
  List<String> faceIds = <String>[];

  List<Embedding> embeddings = <Embedding>[];
  Embedding centroid = <double>[];
  double centroidDistanceThreshold = 0;

  ClusterResultBuilder.createFromIndices({
    required List<int> clusterIndices,
    required List<int> labels,
    required List<Embedding> allEmbeddings,
    required List<int> allFileIds,
    required List<String> allFaceIds,
  }) {
    final clusteredFileIds =
        clusterIndices.map((fileIndex) => allFileIds[fileIndex]).toList();
    final clusteredFaceIds =
        clusterIndices.map((fileIndex) => allFaceIds[fileIndex]).toList();
    final clusteredEmbeddings =
        clusterIndices.map((fileIndex) => allEmbeddings[fileIndex]).toList();
    personId = labels[clusterIndices[0]];
    fileIds = clusteredFileIds;
    faceIds = clusteredFaceIds;
    thumbnailFaceId = faceIds[0];
    embeddings = clusteredEmbeddings;
  }

  void calculateCentroidAndThreshold() {
    if (embeddings.isEmpty) {
      throw Exception("Cannot calculate centroid and threshold for empty list");
    }

    final Matrix embeddingsMatrix = Matrix.fromList(embeddings);

    // Calculate and update the centroid
    final tempCentroid = embeddingsMatrix.mean();
    centroid = tempCentroid.toList();

    // Calculate and update the centroidDistanceThreshold as the maximum distance from the centroid and any of the embeddings
    double maximumDistance = 0;
    for (final embedding in embeddings) {
      final distance = tempCentroid.distanceTo(
        Vector.fromList(embedding),
        distance: Distance.cosine,
      );
      if (distance > maximumDistance) {
        maximumDistance = distance;
      }
    }
    centroidDistanceThreshold = maximumDistance;
  }

  void changeThumbnailFaceId(String faceId) {
    if (!faceIds.contains(faceId)) {
      throw Exception(
        "The faceId $faceId is not in the list of faceIds: $faceIds",
      );
    }
    thumbnailFaceId = faceId;
  }

  ClusterResult build() {
    calculateCentroidAndThreshold();
    return ClusterResult(
      personId: personId,
      thumbnailFaceId: thumbnailFaceId,
      fileIds: fileIds,
      faceIds: faceIds,
      centroid: centroid,
      centroidDistanceThreshold: centroidDistanceThreshold,
    );
  }
}

@immutable
class FaceMlResult {
  final int fileId;

  final List<FaceResult> faces;

  final int mlVersion;
  final bool errorOccured;
  final bool onlyThumbnailUsed;

  bool get hasFaces => faces.isNotEmpty;

  List<Embedding> get allFaceEmbeddings {
    return faces.map((face) => face.embedding).toList();
  }

  List<String> get allFaceIds {
    return faces.map((face) => face.faceId).toList();
  }

  List<int> get fileIdForEveryFace {
    return List<int>.filled(faces.length, fileId);
  }

  FaceDetectionMethod get faceDetectionMethod =>
      FaceDetectionMethod.fromMlVersion(mlVersion);
  FaceAlignmentMethod get faceAlignmentMethod =>
      FaceAlignmentMethod.fromMlVersion(mlVersion);
  FaceEmbeddingMethod get faceEmbeddingMethod =>
      FaceEmbeddingMethod.fromMlVersion(mlVersion);

  const FaceMlResult({
    required this.fileId,
    required this.faces,
    required this.mlVersion,
    required this.errorOccured,
    required this.onlyThumbnailUsed,
  });

  Map<String, dynamic> _toJson() => {
        'fileId': fileId,
        'faces': faces.map((face) => face.toJson()).toList(),
        'mlVersion': mlVersion,
        'errorOccured': errorOccured,
        'onlyThumbnailUsed': onlyThumbnailUsed,
      };

  String toJsonString() => jsonEncode(_toJson());

  static FaceMlResult _fromJson(Map<String, dynamic> json) {
    return FaceMlResult(
      fileId: json['fileId'],
      faces: (json['faces'] as List)
          .map((item) => FaceResult.fromJson(item as Map<String, dynamic>))
          .toList(),
      mlVersion: json['mlVersion'],
      errorOccured: json['errorOccured'] ?? false,
      onlyThumbnailUsed: json['onlyThumbnailUsed'] ?? false,
    );
  }

  static FaceMlResult fromJsonString(String jsonString) {
    return _fromJson(jsonDecode(jsonString));
  }

  FaceDetectionRelative getDetectionForFaceId(String faceId) {
    final faceIndex = faces.indexWhere((face) => face.faceId == faceId);
    if (faceIndex == -1) {
      throw Exception("No face found with faceId $faceId");
    }
    return faces[faceIndex].detection;
  }
}

class FaceMlResultBuilder {
  int fileId;

  List<FaceResultBuilder> faces = <FaceResultBuilder>[];

  int mlVersion;
  bool errorOccured;
  bool onlyThumbnailUsed;

  FaceMlResultBuilder({
    this.fileId = -1,
    this.mlVersion = faceMlVersion,
    this.errorOccured = false,
    this.onlyThumbnailUsed = false,
  });

  FaceMlResultBuilder.fromEnteFile(
    EnteFile file, {
    this.mlVersion = faceMlVersion,
    this.errorOccured = false,
    this.onlyThumbnailUsed = false,
  }) : fileId = file.uploadedFileID ?? -1;

  void addNewlyDetectedFaces(List<FaceDetectionRelative> faceDetections) {
    for (var i = 0; i < faceDetections.length; i++) {
      faces.add(
        FaceResultBuilder.fromFaceDetection(
          faceDetections[i],
          resultBuilder: this,
        ),
      );
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
    final faceResults = <FaceResult>[];
    for (var i = 0; i < faces.length; i++) {
      faceResults.add(faces[i].build());
    }
    return FaceMlResult(
      fileId: fileId,
      faces: faceResults,
      mlVersion: mlVersion,
      errorOccured: errorOccured,
      onlyThumbnailUsed: onlyThumbnailUsed,
    );
  }

  FaceMlResult buildNoFaceDetected() {
    faces = <FaceResultBuilder>[];
    return build();
  }
}

@immutable
class FaceResult {
  final FaceDetectionRelative detection;
  final AlignmentResult alignment;
  final Embedding embedding;
  final int fileId;
  final String faceId;

  const FaceResult({
    required this.detection,
    required this.alignment,
    required this.embedding,
    required this.fileId,
    required this.faceId,
  });

  Map<String, dynamic> toJson() => {
        'detection': detection.toJson(),
        'alignment': alignment.toJson(),
        'embedding': embedding,
        'fileId': fileId,
        'faceId': faceId,
      };

  static FaceResult fromJson(Map<String, dynamic> json) {
    return FaceResult(
      detection: FaceDetectionRelative.fromJson(json['detection']),
      alignment: AlignmentResult.fromJson(json['alignment']),
      embedding: Embedding.from(json['embedding']),
      fileId: json['fileId'],
      faceId: json['faceId'],
    );
  }
}

class FaceResultBuilder {
  FaceDetectionRelative detection =
      FaceDetectionRelative.defaultInitialization();
  AlignmentResult alignment = AlignmentResult.empty();
  Embedding embedding = <double>[];
  int fileId = -1;
  String faceId = '';

  FaceResultBuilder({
    required this.fileId,
    required this.faceId,
  });

  // TODO: [BOB] change id to depend on the detection box, being deterministic, still prepended with fileId. Use md5 hash instead of uuid?
  FaceResultBuilder.fromFaceDetection(
    FaceDetectionRelative faceDetection, {
    required FaceMlResultBuilder resultBuilder,
  }) {
    fileId = resultBuilder.fileId;
    faceId = resultBuilder.fileId.toString() + '_' + const Uuid().v4();
    detection = faceDetection;
  }

  FaceResult build() {
    return FaceResult(
      detection: detection,
      alignment: alignment,
      embedding: embedding,
      fileId: fileId,
      faceId: faceId,
    );
  }
}
