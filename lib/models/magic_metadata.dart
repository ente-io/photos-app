import 'dart:convert';

const kVisibilityVisible = 0;
const kVisibilityArchive = 1;

const kMagicKeyVisibility = 'visibility';
const kMagicKeyMLKitV1Faces = 'mlkit-v1-faces';

class FaceBoundingBox {
  double left;
  double top;
  double right;
  double bottom;

  FaceBoundingBox({this.left, this.top, this.right, this.bottom});

  FaceBoundingBox.fromJson(Map<String, dynamic> json)
      : left = json['left'],
        top = json['top'],
        right = json['right'],
        bottom = json['bottom'];

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
      };
}

class MagicMetadata {
  // 0 -> visible
  // 1 -> archived
  // 2 -> hidden etc?
  int visibility;
  List<FaceBoundingBox> mlKitV1Faces;

  MagicMetadata({this.visibility, this.mlKitV1Faces});

  factory MagicMetadata.fromEncodedJson(String encodedJson) =>
      MagicMetadata.fromJson(jsonDecode(encodedJson));

  factory MagicMetadata.fromJson(dynamic json) => MagicMetadata.fromMap(json);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map[kMagicKeyVisibility] = visibility;
    List<Map<String, dynamic>> faces = <Map<String, dynamic>>[];
    for (final face in mlKitV1Faces) {
      faces.add(face.toJson());
    }
    map[kMagicKeyMLKitV1Faces] = faces;
    return map;
  }

  factory MagicMetadata.fromMap(Map<String, dynamic> map) {
    if (map == null) return null;
    List<FaceBoundingBox> faces = <FaceBoundingBox>[];
    for (final faceJson in map[kMagicKeyMLKitV1Faces] ?? []) {
      faces.add(FaceBoundingBox.fromJson(faceJson));
    }
    return MagicMetadata(
      visibility: map[kMagicKeyVisibility] ?? kVisibilityVisible,
      mlKitV1Faces: faces,
    );
  }
}
