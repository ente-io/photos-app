
class GeneralFaceMlException implements Exception {
  final String message;

  GeneralFaceMlException(this.message);

  @override
  String toString() => 'GeneralFaceMlException: $message';
}

class CouldNotInitializeFaceDetector implements Exception {}

class CouldNotRunFaceDetector implements Exception {}

class CouldNotEstimateSimilarityTransform implements Exception {}

class CouldNotInitializeFaceEmbeddor implements Exception {}

class CouldNotRunFaceEmbeddor implements Exception {}