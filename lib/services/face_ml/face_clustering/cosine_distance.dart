import 'dart:math' show sqrt;

/// Simple cosine distance measurement function.
double cosineDistance(List<double> vector1, List<double> vector2) {
  assert(vector1.length == vector2.length, 'Vectors must be the same length');

  double dotProduct = 0.0;
  double magnitude1 = 0.0;
  double magnitude2 = 0.0;

  for (int i = 0; i < vector1.length; i++) {
    dotProduct += vector1[i] * vector2[i];
    magnitude1 += vector1[i] * vector1[i];
    magnitude2 += vector2[i] * vector2[i];
  }

  magnitude1 = sqrt(magnitude1);
  magnitude2 = sqrt(magnitude2);

  // Avoid division by zero
  if (magnitude1 == 0 || magnitude2 == 0) {
    return 0.0;
  }

  final double similarity = dotProduct / (magnitude1 * magnitude2);

  // Cosine distance is the complement of cosine similarity
  return 1.0 - similarity;
}
