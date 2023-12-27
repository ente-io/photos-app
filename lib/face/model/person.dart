class Person {
  final String remoteID;
  final PersonAttr attr;
  int? id;
  Person({
    required this.remoteID,
    required this.attr,
    this.id,
  });
}

class PersonAttr {
  final String name;
  final bool isHidden;
  final String? avatarFaceId;
  final Set<String> faces;
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
      faces: (json['faces'] as List).map((e) => e as String).toSet(),
      avatarFaceId: json['avatarFaceId'] as String?,
      isHidden: json['isHidden'] as bool? ?? false,
      birthDatae: json['birthDatae'] as String?,
    );
  }
}
