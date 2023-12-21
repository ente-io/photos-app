// Class for the 'landmark' sub-object
class Landmark {
  double x;
  double y;

  Landmark({
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
      };

  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      x: json['x'] as double,
      y: json['y'] as double,
    );
  }
}
