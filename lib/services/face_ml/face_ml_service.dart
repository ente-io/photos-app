import "dart:io" as io;
import "dart:typed_data" show Uint8List;

import "package:flutter/foundation.dart";
import "package:flutter_image_compress/flutter_image_compress.dart";
import "package:image/image.dart" as image_lib;
import "package:logging/logging.dart";
import "package:photos/core/configuration.dart";
import "package:photos/db/ml_data_db.dart";
import "package:photos/models/file.dart";
import "package:photos/models/file_type.dart";
import "package:photos/models/ml_typedefs.dart";
import "package:photos/services/face_ml/face_alignment/similarity_transform.dart";
import "package:photos/services/face_ml/face_detection/detection.dart";
import "package:photos/services/face_ml/face_detection/face_detection_exceptions.dart";
import "package:photos/services/face_ml/face_detection/face_detection_service.dart";
import "package:photos/services/face_ml/face_embedding/face_embedding_exceptions.dart";
import "package:photos/services/face_ml/face_embedding/face_embedding_service.dart";
import "package:photos/services/face_ml/face_ml_exceptions.dart";
import "package:photos/services/face_ml/face_ml_result.dart";
import "package:photos/services/search_service.dart";
import "package:photos/utils/file_util.dart";
import "package:photos/utils/thumbnail_util.dart";

class FaceMlService {
  final _logger = Logger("FaceMlService");

  late SimilarityTransform _similarityTransform;

  // singleton pattern
  FaceMlService._privateConstructor();
  static final instance = FaceMlService._privateConstructor();

  bool initialized = false;

  Future<void> init() async {
    try {
      await FaceDetection.instance.init();
    } catch (e, s) {
      _logger.severe("Could not initialize blazeface", e, s);
    }
    try {
      _similarityTransform = SimilarityTransform();
    } catch (e, s) {
      _logger.severe("Could not initialize face alignment", e, s);
    }
    try {
      await FaceEmbedding.instance.init();
    } catch (e, s) {
      _logger.severe("Could not initialize mobilefacenet", e, s);
    }
    initialized = true;
  }

  /// Analyzes the given image data by running the full pipeline (face detection, face alignment, face embedding).
  ///
  /// 'imageFile': The image file to analyze.
  ///
  /// Returns an immutable [FaceMlResult] instance containing the results of the analysis.
  Future<FaceMlResult> analyzeImage(io.File imageFile) async {
    final imageData = await imageFile.readAsBytes();

    final resultBuilder = FaceMlResultBuilder.createWithMlMethods();

    _logger.info("Analyzing image ${imageFile.path}");
    final stopwatch = Stopwatch()..start();

    try {
      // Get the faces
      final List<FaceDetectionAbsolute> faceDetectionResult =
          await detectFaces(imageData, resultBuilder: resultBuilder);

      _logger.info("Completed `detectFaces` function");

      // If no faces were detected, return a result with no faces. Otherwise, continue.
      if (faceDetectionResult.isEmpty) {
        return resultBuilder.buildNoFaceDetected();
      }

      // Align the faces
      final faceAlignmentResult = alignFaces(
        imageData,
        faceDetectionResult,
        resultBuilder: resultBuilder,
      );

      _logger.info("Completed `alignFaces` function");

      // Get the embeddings of the faces
      await embedBatchFaces(
        faceAlignmentResult,
        resultBuilder: resultBuilder,
      );

      _logger.info("Completed `embedBatchFaces` function");

      stopwatch.stop();
      _logger.info("Completed analyzing image ${imageFile.path}, in "
          "${stopwatch.elapsedMilliseconds} ms");

      return resultBuilder.build();
    } catch (e, s) {
      _logger.severe("Could not analyze image", e, s);
      throw GeneralFaceMlException("Could not analyze image");
    }
  }

  Future<void> analyseData() async {
    final List<EnteFile> enteFiles = await SearchService.instance.getAllFiles();
    final Set<int> alreadyIndexedIDs = await MlDataDB.instance.getFileIDs();
    for (final enteFile in enteFiles) {
      if (!enteFile.isUploaded || enteFile.fileType == FileType.video) {
        continue;
      }
      final id = enteFile.uploadedFileID!;
      if (alreadyIndexedIDs.contains(id)) {
        continue;
      }
      try {
        final io.File? actualIoFile = await getFileForML(enteFile, );
        if (actualIoFile == null) {
          _logger.finest("Failed to get enteFile for ${enteFile.toString()}");
          continue;
        }
        final FaceMlResult mlResult = await analyzeImage(actualIoFile);
      } catch (e, s) {
        _logger.severe("Could not analyze image", e, s);
      }
    }
  }

  Future<io.File?> getFileForML(
    EnteFile enteFile, {
    bool thumbnail = false,
    bool compressOriginalFile = false,
  }) async {
    if(thumbnail) {
      final Uint8List? thumbnailData = await getThumbnail(enteFile);
      // todo:
    }
    final io.File? actualIoFile = await getFile(enteFile);
    if (actualIoFile == null) {
      return null;
    }
    if (compressOriginalFile) {
      final String tempPath = Configuration.instance.getTempDirectory() +
          "${enteFile.uploadedFileID!}";
      final compressResult = await FlutterImageCompress.compressAndGetFile(
        actualIoFile.path,
        tempPath + ".jpg",
      );
      return compressResult;
    }
    return actualIoFile;
  }

  /// Analyzes the given image data by running the full pipeline using [analyzeImage] and stores the result in the database [MlDataDB].
  /// This function first checks if the image has already been analyzed (with latest ml version) and stored in the database. If so, it returns the stored result.
  ///
  /// 'imageFile': The image file to analyze.
  ///
  /// Returns an immutable [FaceMlResult] instance containing the results of the analysis. The result is also stored in the database.
  Future<FaceMlResult> processFacesImage(io.File imageFile, int identifier)
  async {
    // Check if the image has already been analyzed and stored in the database
    // TODO: should not using hashcode, but instead the actual fileID!!!!!!!!!!!!!!!!!!!!!!!!
    final existingResult = await MlDataDB.instance.getFaceMlResult(imageFile.path.hashCode);

    // If the image has already been analyzed and stored in the database, return the stored result
    if (existingResult != null) {
      if (existingResult.mlVersion >= faceMlVersion) {
        _logger.info(
          "Image ${imageFile.path} has already been analyzed and stored in the database with the latest ml version. Returning the stored result.",
        );
        return existingResult;
      }
    }

    // If the image has not been analyzed and stored in the database, analyze it and store the result in the database
    final result = await analyzeImage(imageFile);

    // Store the result in the database
    await MlDataDB.instance.createFaceMlResult(result);

    return result;
  }

  /// Detects faces in the given image data.
  ///
  /// `imageData`: The image data to analyze.
  ///
  /// Returns a list of face detection results.
  ///
  /// Throws [CouldNotInitializeFaceDetector], [CouldNotRunFaceDetector] or [GeneralFaceMlException] if something goes wrong.
  Future<List<FaceDetectionAbsolute>> detectFaces(
    Uint8List imageData, {
    FaceMlResultBuilder? resultBuilder,
  }) async {
    try {
      // Get the bounding boxes of the faces
      final List<FaceDetectionAbsolute> faces =
          FaceDetection.instance.predict(imageData);

      // Add detected faces to the resultBuilder
      if (resultBuilder != null) {
        resultBuilder.addNewlyDetectedFaces(faces);
      }

      return faces;
    } on BlazeFaceInterpreterInitializationException {
      throw CouldNotInitializeFaceDetector();
    } on BlazeFaceInterpreterRunException {
      throw CouldNotRunFaceDetector();
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      _logger.severe('Face detection failed: $e');
      throw GeneralFaceMlException('Face detection failed: $e');
    }
  }

  /// Aligns multiple faces from the given image data.
  ///
  /// `imageData`: The image data in [Uint8List] that contains the faces.
  /// `faces`: The face detection results in a list of [FaceDetectionAbsolute] for the faces to align.
  ///
  /// Returns a list of the aligned faces as image data.
  ///
  /// Throws [CouldNotEstimateSimilarityTransform] or [GeneralFaceMlException] if the face alignment fails.
  List<Double3DInputMatrix> alignFaces(
    Uint8List imageData,
    List<FaceDetectionAbsolute> faces, {
    FaceMlResultBuilder? resultBuilder,
  }) {
    // TODO: the image conversion below is what makes the whole pipeline slow, so come up with different solution
    final image_lib.Image inputImage = image_lib.decodeImage(imageData)!;

    final alignedFaces = <Double3DInputMatrix>[];
    for (int i = 0; i < faces.length; ++i) {
      final alignedFace = alignFaceToMatrix(
        inputImage,
        faces[i],
        resultBuilder: resultBuilder,
        faceIndex: i,
      );
      alignedFaces.add(alignedFace);
    }

    return alignedFaces;
  }

  /// Aligns a single face from the given image data.
  ///
  /// `inputImage`: The image in [image_lib.Image] format that contains the face.
  /// `face`: The face detection [FaceDetectionAbsolute] result for the face to align.
  ///
  /// Returns the aligned face as a matrix [Double3DInputMatrix].
  ///
  /// Throws [CouldNotEstimateSimilarityTransform], [CouldNotWarpAffine] or [GeneralFaceMlException] if the face alignment fails.
  Double3DInputMatrix alignFaceToMatrix(
    image_lib.Image inputImage,
    FaceDetectionAbsolute face, {
    FaceMlResultBuilder? resultBuilder,
    int? faceIndex,
  }) {
    try {
      final faceLandmarks = face.allKeypoints.sublist(0, 4);
      final isNoNanInParam = _similarityTransform.estimate(faceLandmarks);
      if (!isNoNanInParam) {
        throw CouldNotEstimateSimilarityTransform();
      }

      final transformMatrix = _similarityTransform.params;
      final transformMatrixList = _similarityTransform.paramsList;
      if (resultBuilder != null && faceIndex != null) {
        resultBuilder.addAlignmentToExistingFace(
          transformMatrixList,
          faceIndex,
        );
      }

      Double3DInputMatrix? faceAlignedData;
      try {
        faceAlignedData = _similarityTransform.warpAffineToMatrix(
          inputImage: inputImage,
          transformationMatrix: transformMatrix,
        );
      } catch (e) {
        throw CouldNotWarpAffine();
      }

      return faceAlignedData;
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      _logger.severe('Face alignment failed: $e');
      throw GeneralFaceMlException('Face alignment failed: $e');
    }
  }

  /// Aligns a single face from the given image data.
  ///
  /// WARNING: This function is not efficient for multiple faces. Use [alignFaceToMatrix] in pipelines instead.
  ///
  /// `imageData`: The image data that contains the face.
  /// `face`: The face detection result for the face to align.
  ///
  /// Returns the aligned face as image data.
  ///
  /// Throws [CouldNotEstimateSimilarityTransform], [CouldNotWarpAffine] or [GeneralFaceMlException] if the face alignment fails.
  Uint8List alignSingleFace(Uint8List imageData, FaceDetectionAbsolute face) {
    try {
      final faceLandmarks = face.allKeypoints.sublist(0, 4);
      final isNoNanInParam = _similarityTransform.estimate(faceLandmarks);
      if (!isNoNanInParam) {
        throw CouldNotEstimateSimilarityTransform();
      }

      final transformMatrix = _similarityTransform.params;

      Uint8List? faceAlignedData;
      try {
        faceAlignedData = _similarityTransform.warpAffine(
          imageData: imageData,
          transformationMatrix: transformMatrix,
        );
      } catch (e) {
        throw CouldNotWarpAffine();
      }

      return faceAlignedData;
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      _logger.severe('Face alignment failed: $e');
      throw GeneralFaceMlException('Face alignment failed: $e');
    }
  }

  /// Embeds a single face from the given image data.
  ///
  /// `faceData`: The image data of the face to embed.
  ///
  /// Returns the face embedding as a list of doubles.
  ///
  /// Throws [CouldNotInitializeFaceEmbeddor], [CouldNotRunFaceEmbeddor], [InputProblemFaceEmbeddor] or [GeneralFaceMlException] if the face embedding fails.
  Future<List<double>> embedSingleFace(Uint8List faceData) async {
    try {
      // Get the embedding of the face
      final List<double> embedding = FaceEmbedding.instance.predict(faceData);

      return embedding;
    } on MobileFaceNetInterpreterInitializationException {
      throw CouldNotInitializeFaceEmbeddor();
    } on MobileFaceNetInterpreterRunException {
      throw CouldNotRunFaceEmbeddor();
    } on MobileFaceNetEmptyInput {
      throw InputProblemFaceEmbeddor("Input is empty");
    } on MobileFaceNetWrongInputSize {
      throw InputProblemFaceEmbeddor("Input size is wrong");
    } on MobileFaceNetWrongInputRange {
      throw InputProblemFaceEmbeddor("Input range is wrong");
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      _logger.severe('Face embedding failed: $e');
      throw GeneralFaceMlException('Face embedding failed: $e');
    }
  }

  /// Embeds multiple faces from the given input matrices.
  ///
  /// `facesMatrices`: The input matrices of the faces to embed.
  ///
  /// Returns a list of the face embeddings as lists of doubles.
  ///
  /// Throws [CouldNotInitializeFaceEmbeddor], [CouldNotRunFaceEmbeddor], [InputProblemFaceEmbeddor] or [GeneralFaceMlException] if the face embedding fails.
  Future<List<List<double>>> embedBatchFaces(
    List<Double3DInputMatrix> facesMatrices, {
    FaceMlResultBuilder? resultBuilder,
  }) async {
    try {
      // Get the embedding of the faces
      final List<List<double>> embeddings =
          FaceEmbedding.instance.predictBatch(facesMatrices);

      // Add the embeddings to the resultBuilder
      if (resultBuilder != null) {
        resultBuilder.addEmbeddingsToExistingFaces(embeddings);
      }

      return embeddings;
    } on MobileFaceNetInterpreterInitializationException {
      throw CouldNotInitializeFaceEmbeddor();
    } on MobileFaceNetInterpreterRunException {
      throw CouldNotRunFaceEmbeddor();
    } on MobileFaceNetEmptyInput {
      throw InputProblemFaceEmbeddor("Input is empty");
    } on MobileFaceNetWrongInputSize {
      throw InputProblemFaceEmbeddor("Input size is wrong");
    } on MobileFaceNetWrongInputRange {
      throw InputProblemFaceEmbeddor("Input range is wrong");
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      _logger.severe('Face embedding (batch) failed: $e');
      throw GeneralFaceMlException('Face embedding (batch) failed: $e');
    }
  }
}
