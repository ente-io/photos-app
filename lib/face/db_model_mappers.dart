import "dart:convert";

import 'package:photos/face/db_fields.dart';
import 'package:photos/face/model/person_face.dart';

int boolToSQLInt(bool? value, {bool defaultValue = false}) {
  final bool v = value ?? defaultValue;
  if (v == false) {
    return 0;
  } else {
    return 1;
  }
}

bool sqlIntToBool(int? value, {bool defaultValue = false}) {
  final int v = value ?? (defaultValue ? 1 : 0);
  if (v == 0) {
    return false;
  } else {
    return true;
  }
}

Map<String, dynamic> mapToFaceDB(PersonFace personFace) {
  return {
    faceIDColumn: personFace.face.id,
    faceMlResultColumn: json.encode(personFace.face.toJson()),
    faceConfirmedColumn: boolToSQLInt(personFace.confirmed),
    facePersonIDColumn: personFace.personID,
    faceClosestDistColumn: personFace.closeDist,
    faceClosestFaceID: personFace.closeFaceID,
  };
}
