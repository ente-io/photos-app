class Person {
  final String remoteID;
  final PersonAttr attr;
  Person(
    this.remoteID,
    this.attr,
  );
}

class PersonAttr {
  final String name;
  final bool isHidden;
  final String? avatarFaceId;
  final List<String> faces;
  final String? birthDatae;
  PersonAttr({
    required this.name,
    required this.faces,
    this.avatarFaceId,
    this.isHidden = false,
    this.birthDatae,
  });

  // toJson
  Map<String, dynamic> toJson() => {
        'name': name,
        'faces': faces.toList(),
        'avatarFaceId': avatarFaceId,
        'isHidden': isHidden,
        'birthDatae': birthDatae,
      };

  // fromJson
  factory PersonAttr.fromJson(Map<String, dynamic> json) {
    return PersonAttr(
      name: json['name'] as String,
      faces: List<String>.from(json['faces'] as List<dynamic>),
      avatarFaceId: json['avatarFaceId'] as String?,
      isHidden: json['isHidden'] as bool? ?? false,
      birthDatae: json['birthDatae'] as String?,
    );
  }
}
