import "package:photos/services/face_ml/face_ml_version.dart";

/// Represents a face detection method with a specific version.
class FaceDetectionMethod extends VersionedMethod {
  /// Creates a [FaceDetectionMethod] instance with a specific `method` and `version` (default `0`)
  FaceDetectionMethod(String method, {int version = 0})
      : super(method, version);

  /// Creates a [FaceDetectionMethod] instance with 'Empty method' as the method, and a specific `version` (default `0`)
  const FaceDetectionMethod.empty()
      : super.empty();

  /// Creates a [FaceDetectionMethod] instance with 'BlazeFace' as the method, and a specific `version` (default `0`)
  FaceDetectionMethod.blazeFace({int version = 0})
      : super('BlazeFace', version);
}

/// Represents a face alignment method with a specific version.
class FaceAlignmentMethod extends VersionedMethod {
  /// Creates a [FaceAlignmentMethod] instance with a specific `method` and `version` (default `0`)
  FaceAlignmentMethod(String method, {int version = 0})
      : super(method, version);

  /// Creates a [FaceAlignmentMethod] instance with 'Empty method' as the method, and a specific `version` (default `0`)
  const FaceAlignmentMethod.empty()
      : super.empty();

  /// Creates a [FaceAlignmentMethod] instance with 'ArcFace' as the method, and a specific `version` (default `0`)
  FaceAlignmentMethod.arcFace({int version = 0}) : super('ArcFace', version);
}

/// Represents a face embedding method with a specific version.
class FaceEmbeddingMethod extends VersionedMethod {
  /// Creates a [FaceEmbeddingMethod] instance with a specific `method` and `version` (default `0`)
  FaceEmbeddingMethod(String method, {int version = 0})
      : super(method, version);

  /// Creates a [FaceEmbeddingMethod] instance with 'Empty method' as the method, and a specific `version` (default `0`)
  const FaceEmbeddingMethod.empty()
      : super.empty();

  /// Creates a [FaceEmbeddingMethod] instance with 'MobileFaceNet' as the method, and a specific `version` (default `0`)
  FaceEmbeddingMethod.mobileFaceNet({int version = 0})
      : super('MobileFaceNet', version);
}
