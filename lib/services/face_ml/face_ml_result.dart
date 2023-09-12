import "dart:convert" show jsonEncode, jsonDecode;

import "package:flutter/material.dart" show Size, immutable;
import "package:ml_linalg/linalg.dart";
import "package:photos/models/file/file.dart";
import "package:photos/models/ml_typedefs.dart";
import "package:photos/services/face_ml/face_alignment/alignment_result.dart";
import "package:photos/services/face_ml/face_detection/detection.dart";
import "package:photos/services/face_ml/face_ml_methods.dart";
import "package:uuid/uuid.dart";

const faceMlVersion = 0;
const clusterMlVersion = 0;

@immutable
class ClusterResult {
  final int personId;
  final String displayFaceId;
  final String displayImageUrl;

  ///
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
    required this.displayFaceId,
    required this.displayImageUrl,
    required List<int> fileIds,
    required List<String> faceIds,
    required this.centroid,
    required this.centroidDistanceThreshold,
  })  : _faceIds = faceIds,
        _fileIds = fileIds;

  Map<String, dynamic> _toJson() => {
        'personId': personId,
        'displayFaceId': displayFaceId,
        'displayImageUrl': displayImageUrl,
        'fileIds': _fileIds,
        'faceIds': _faceIds,
        'centroid': centroid,
        'centroidDistanceThreshold': centroidDistanceThreshold,
      };

  String toJsonString() => jsonEncode(_toJson());

  static ClusterResult _fromJson(Map<String, dynamic> json) {
    return ClusterResult(
      personId: json['personId'] ?? -1,
      displayFaceId: json['displayFaceId'] ?? '',
      displayImageUrl: json['displayImageUrl'] ?? '',
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
  String displayFaceId = '';
  String displayImageUrl = '';

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

  // TODO: add a method to add the display face id and image url. Ask Vishnu or Bob!
  void addDisplayStrings() {}

  ClusterResult build() {
    calculateCentroidAndThreshold();
    addDisplayStrings();
    return ClusterResult(
      personId: personId,
      displayFaceId: displayFaceId,
      displayImageUrl: displayImageUrl,
      fileIds: fileIds,
      faceIds: faceIds,
      centroid: centroid,
      centroidDistanceThreshold: centroidDistanceThreshold,
    );
  }
}

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

  List<Embedding> get allFaceEmbeddings {
    return faces.map((face) => face.embedding).toList();
  }

  List<String> get allFaceIds {
    return faces.map((face) => face.id).toList();
  }

  List<int> get fileIdForEveryFace {
    return List<int>.filled(faces.length, fileId);
  }

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

  Map<String, dynamic> _toJson() => {
        'faceDetectionMethod': faceDetectionMethod.toJson(),
        'faceAlignmentMethod': faceAlignmentMethod.toJson(),
        'faceEmbeddingMethod': faceEmbeddingMethod.toJson(),
        'faces': faces.map((face) => face.toJson()).toList(),
        'fileId': fileId,
        'imageDimensions': {
          'width': imageDimensions.width,
          'height': imageDimensions.height
        },
        'imageSource': imageSource,
        'lastErrorMessage': lastErrorMessage,
        'errorCount': errorCount,
        'mlVersion': mlVersion,
      };

  String toJsonString() => jsonEncode(_toJson());

  static FaceMlResult _fromJson(Map<String, dynamic> json) {
    return FaceMlResult(
      faceDetectionMethod:
          FaceDetectionMethod.fromJson(json['faceDetectionMethod']),
      faceAlignmentMethod:
          FaceAlignmentMethod.fromJson(json['faceAlignmentMethod']),
      faceEmbeddingMethod:
          FaceEmbeddingMethod.fromJson(json['faceEmbeddingMethod']),
      faces: (json['faces'] as List)
          .map((item) => FaceResult.fromJson(item as Map<String, dynamic>))
          .toList(),
      fileId: json['fileId'],
      imageDimensions: Size(
        json['imageDimensions']['width'],
        json['imageDimensions']['height'],
      ),
      imageSource: json['imageSource'],
      lastErrorMessage: json['lastErrorMessage'],
      errorCount: json['errorCount'],
      mlVersion: json['mlVersion'],
    );
  }

  static FaceMlResult fromJsonString(String jsonString) {
    return _fromJson(jsonDecode(jsonString));
  }
}

class FaceMlResultBuilder {
  FaceDetectionMethod faceDetectionMethod = const FaceDetectionMethod.empty();
  FaceAlignmentMethod faceAlignmentMethod = const FaceAlignmentMethod.empty();
  FaceEmbeddingMethod faceEmbeddingMethod = const FaceEmbeddingMethod.empty();

  List<FaceResultBuilder> faces = <FaceResultBuilder>[];

  int fileId;
  Size imageDimensions;
  String imageSource;
  String lastErrorMessage;
  int errorCount = 0;
  int mlVersion;

  FaceMlResultBuilder({
    this.fileId = -1,
    this.imageDimensions = const Size(0, 0),
    this.imageSource = '',
    this.lastErrorMessage = '',
    this.mlVersion = faceMlVersion,
  });

  FaceMlResultBuilder.createWithMlMethods({
    required EnteFile file,
    this.lastErrorMessage = '',
    this.mlVersion = faceMlVersion,
  })  : fileId = file.uploadedFileID ?? -1,
        imageSource = file.displayName, // TODO: Ask Vishnu/Bob whether this is smart to do
        imageDimensions = Size(file.width.toDouble(), file.height.toDouble()),
        faceDetectionMethod = FaceDetectionMethod.blazeFace(),
        faceAlignmentMethod = FaceAlignmentMethod.arcFace(),
        faceEmbeddingMethod = FaceEmbeddingMethod.mobileFaceNet();

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

  // void _noProperFileAcces() {
  //   fileId = -1;
  //   imageDimensions = const Size(0, 0);
  //   imageSource = '';
  //   lastErrorMessage = "No proper file access";
  //   mlVersion = -1;
  // }
}

@immutable
class FaceResult {
  final FaceDetectionRelative detection;
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

  static FaceResult fromJson(Map<String, dynamic> json) {
    return FaceResult(
      detection: FaceDetectionRelative.fromJson(json['detection']),
      alignment: AlignmentResult.fromJson(json['alignment']),
      embedding: Embedding.from(json['embedding']),
      fileId: json['fileId'],
      id: json['id'],
      personId: json['personId'],
    );
  }
}

class FaceResultBuilder {
  FaceDetectionRelative detection =
      FaceDetectionRelative.defaultInitialization();
  AlignmentResult alignment = AlignmentResult.empty();
  Embedding embedding = <double>[];
  int fileId;
  String id;
  int personId;

  FaceResultBuilder({
    this.fileId = -1,
    this.id = '',
    this.personId = -1,
  });

  // TODO: Ask Vishnu or Bob whether my implementation of generating a faceId makes sense! And whether it makes sense to store relative detections in the database, instead of absolute detections what I did before
  FaceResultBuilder.fromFaceDetection(
    FaceDetectionRelative faceDetection, {
    required FaceMlResultBuilder resultBuilder,
    this.personId = -1,
  })  : fileId = resultBuilder.fileId,
        id = resultBuilder.fileId.toString() + '_' + const Uuid().v4(),
        detection = faceDetection;

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
