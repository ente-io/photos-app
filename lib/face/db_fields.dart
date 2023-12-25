// Faces Table Fields & Schema Queries
const facesTable = 'faces';
const fileIDColumn = 'file_id';
const faceIDColumn = 'face_id';
const faceDetectionColumn = 'detection';
const faceEmbeddingBlob = 'eBlob';
const faceScore = 'score';
const facePersonIDColumn = 'person_id';
const faceConfirmedColumn = 'confirmed';
const faceClosestDistColumn = 'close_dist';
const faceClosestFaceID = 'close_face_id';
const mlVersionColumn = 'ml_version';

const createFacesTable = '''CREATE TABLE IF NOT EXISTS $facesTable (
  $fileIDColumn	INTEGER NOT NULL,
  $faceIDColumn  TEXT NOT NULL,
	$faceDetectionColumn	TEXT NOT NULL,
  $faceEmbeddingBlob BLOB NOT NULL,
  $faceScore  REAL NOT NULL,
	$facePersonIDColumn	INTEGER,
	$faceClosestDistColumn	REAL,
  $faceClosestFaceID  TEXT,
	$faceConfirmedColumn  INTEGER NOT NULL DEFAULT 0,
  $mlVersionColumn	INTEGER NOT NULL DEFAULT -1,
  PRIMARY KEY($fileIDColumn, $faceIDColumn)
  );
  ''';

const deleteFacesTable = 'DROP TABLE IF EXISTS $facesTable';
// End of Faces Table Fields & Schema Queries

// People Table Fields & Schema Queries
const peopleTable = 'people';
const personIDColumn = 'id';
const personNameColumn = 'name';
const personHiddenColumn = 'hidden';
const personFaceIDsColumn = 'face_ids';

const createPeopleTable = '''CREATE TABLE IF NOT EXISTS $peopleTable (
  $personIDColumn	INTEGER NOT NULL UNIQUE,
	$personNameColumn	TEXT NOT NULL DEFAULT '',
  $personHiddenColumn	INTEGER NOT NULL DEFAULT 0,
  $personFaceIDsColumn	TEXT NOT NULL,
	PRIMARY KEY($personIDColumn)
  );
  ''';

const deletePeopleTable = 'DROP TABLE IF EXISTS $peopleTable';
//End People Table Fields & Schema Queries