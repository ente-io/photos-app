class AlignmentResult {
  final List<List<double>> affineMatrix;

  AlignmentResult({required this.affineMatrix});

  const AlignmentResult.empty()
      : affineMatrix = const <List<double>>[
          [1, 0, 0],
          [0, 1, 0],
          [0, 0, 1]
        ];

  factory AlignmentResult.fromJson(Map<String, dynamic> json) {
    return AlignmentResult(
      affineMatrix: json['affineMatrix'],
    );
  }

  Map<String, dynamic> toJson() => {
        'affineMatrix': affineMatrix,
      };
}
