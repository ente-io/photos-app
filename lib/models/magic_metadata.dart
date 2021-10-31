import 'dart:convert';

const kVisibilityVisible = 0;
const kVisibilityArchive = 1;

const kMagicKeyVisibility = 'visibility';

const kPubMagicKeyEditedTime = 'editedTime';

class MagicMetadata {
  // 0 -> visible
  // 1 -> archived
  // 2 -> hidden etc?
  int? visibility;

  MagicMetadata({this.visibility});

  factory MagicMetadata.fromEncodedJson(String encodedJson) =>
      MagicMetadata.fromJson(jsonDecode(encodedJson));

  factory MagicMetadata.fromJson(dynamic json) => MagicMetadata.fromMap(json);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map[kMagicKeyVisibility] = visibility;
    return map;
  }

  static fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return MagicMetadata(
      visibility: map[kMagicKeyVisibility] ?? kVisibilityVisible,
    );
  }
}

class PubMagicMetadata {
  int? editedTime;

  PubMagicMetadata({this.editedTime});

  factory PubMagicMetadata.fromEncodedJson(String encodedJson) =>
      PubMagicMetadata.fromJson(jsonDecode(encodedJson));

  factory PubMagicMetadata.fromJson(dynamic json) =>
      PubMagicMetadata.fromMap(json);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map[kPubMagicKeyEditedTime] = editedTime;
    return map;
  }

  static fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return PubMagicMetadata(
      editedTime: map[kPubMagicKeyEditedTime],
    );
  }
}
