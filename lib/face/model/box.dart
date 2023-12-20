class Box {
  final double x;
  final double y;
  final double width;
  final double height;

  Box({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory Box.fromJson(Map<String, dynamic> json) {
    return Box(
      x: json['x'] as double,
      y: json['y'] as double,
      width: json['width'] as double,
      height: json['height'] as double,
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}
