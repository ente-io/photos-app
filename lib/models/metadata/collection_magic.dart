import 'dart:convert';

import "package:photos/models/metadata/common_keys.dart";

// Collection SubType Constants
const subTypeDefaultHidden = 1;
const subTypeSharedFilesCollection = 2;

// key for collection subType
const subTypeKey = 'subType';

class CollectionMagicMetadata {
  // 0 -> visible
  // 1 -> archived
  // 2 -> hidden etc?
  int visibility;

  // null/0 value -> no subType
  // 1 -> DEFAULT_HIDDEN COLLECTION for files hidden individually
  // 2 -> Collections created for sharing selected files
  int? subType;

  CollectionMagicMetadata({required this.visibility, this.subType});

  Map<String, dynamic> toJson() {
    final result = {magicKeyVisibility: visibility};
    if (subType != null) {
      result[subTypeKey] = subType!;
    }
    return result;
  }

  factory CollectionMagicMetadata.fromEncodedJson(String encodedJson) =>
      CollectionMagicMetadata.fromJson(jsonDecode(encodedJson));

  factory CollectionMagicMetadata.fromJson(dynamic json) =>
      CollectionMagicMetadata.fromMap(json);

  static fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return CollectionMagicMetadata(
      visibility: map[magicKeyVisibility] ?? visibleVisibility,
      subType: map[subTypeKey],
    );
  }
}

class CollectionPubMagicMetadata {
  // sort order while showing collection
  bool? asc;

  // cover photo id for the collection
  int? coverID;

  CollectionPubMagicMetadata({this.asc, this.coverID});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = {"asc": asc ?? false};
    if (coverID != null) {
      result["coverID"] = coverID!;
    }
    return result;
  }

  factory CollectionPubMagicMetadata.fromEncodedJson(String encodedJson) =>
      CollectionPubMagicMetadata.fromJson(jsonDecode(encodedJson));

  factory CollectionPubMagicMetadata.fromJson(dynamic json) =>
      CollectionPubMagicMetadata.fromMap(json);

  static fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return CollectionPubMagicMetadata(
      asc: map["asc"] as bool?,
      coverID: map["coverID"],
    );
  }
}