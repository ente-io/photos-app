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
const idColumn = 'id';
const nameColumn = 'name';
const personHiddenColumn = 'hidden';
const clusterToFaceIdJson = 'clusterToFaceIds';
const coverFaceIDColumn = 'cover_face_id';

const createPeopleTable = '''CREATE TABLE IF NOT EXISTS $peopleTable (
  $idColumn	TEXT NOT NULL UNIQUE,
	$nameColumn	TEXT NOT NULL DEFAULT '',
  $personHiddenColumn	INTEGER NOT NULL DEFAULT 0,
  $clusterToFaceIdJson	TEXT NOT NULL DEFAULT '{}',
  $coverFaceIDColumn	TEXT,
	PRIMARY KEY($idColumn)
  );
  ''';

const deletePeopleTable = 'DROP TABLE IF EXISTS $peopleTable';
//End People Table Fields & Schema Queries

// PersonToClusterID Table Fields & Schema Queries
const personToClusterIDTable = 'person_to_cluster_id';
const personToClusterIDPersonIDColumn = 'person_id';
const cluserIDColumn = 'cluster_id';

const createPersonClusterTable = '''
CREATE TABLE IF NOT EXISTS $personToClusterIDTable (
  $personToClusterIDPersonIDColumn	TEXT NOT NULL,
  $cluserIDColumn	INTEGER  NOT NULL,
  PRIMARY KEY($personToClusterIDPersonIDColumn, $cluserIDColumn)
);
''';
const dropPersonClusterTable = 'DROP TABLE IF EXISTS $personToClusterIDTable';
// End PersonToClusterID Table Fields & Schema Queries 
