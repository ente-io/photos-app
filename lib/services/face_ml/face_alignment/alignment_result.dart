class AlignmentResult {
  final List<List<double>> affineMatrix;

  AlignmentResult({required this.affineMatrix});

  AlignmentResult.empty()
      : affineMatrix = <List<double>>[
          [1, 0, 0],
          [0, 1, 0],
          [0, 0, 1]
        ];

  factory AlignmentResult.fromJson(Map<String, dynamic> json) {
    return AlignmentResult(
      affineMatrix: (json['affineMatrix'] as List)
          .map((item) => List<double>.from(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'affineMatrix': affineMatrix,
      };
}
