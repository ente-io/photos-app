import "dart:io" as io;
import "dart:typed_data" show Uint8List;

import "package:flutter/foundation.dart";
import "package:flutter_image_compress/flutter_image_compress.dart";
import "package:image/image.dart" as image_lib;
import "package:logging/logging.dart";
import "package:photos/core/configuration.dart";
import "package:photos/db/ml_data_db.dart";
import "package:photos/models/file/file.dart";
import "package:photos/models/file/file_type.dart";
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
import 'package:photos/utils/image_package_util.dart';
import "package:photos/utils/thumbnail_util.dart";

enum FileDataForML { thumbnailData, fileData, compressedFileData }

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

  // TODO: implement this function. Don't forget to run it in an isolate.
  Future<void> clusterAllImages() async {
    // Run the analysis on all images to make sure everything is analyzed
    await processAllImages();

    final allFaceMlResults = await MlDataDB.instance.getAllFaceMlResults();

    // Initialize all the lists that we will use
    final allFaceEmbeddings = <Embedding>[];
    final allFileIDs = <int>[];
    final allFaceIDs = <String>[];

    // Populate the lists for the clustering
    for (final FaceMlResult faceMlResult in allFaceMlResults) {
      allFaceEmbeddings.addAll(faceMlResult.allFaceEmbeddings);
      allFileIDs.addAll(faceMlResult.fileIdForEveryFace);
      allFaceIDs.addAll(faceMlResult.allFaceIds);
    }

    // Run the clustering
    final clusteringResult =
        await FaceClustering.instance.predict(allFaceEmbeddings);
    final labels = FaceClustering.instance.labels;

    if (labels == null) {
      _logger.severe("Clustering failed");
      throw GeneralFaceMlException("Clustering failed");
    }

    // Create the clusters
    final List<ClusterResultBuilder> clusterResultBuilders = [];
    final List<ClusterResult> clusterResults = [];
    for (final List<int> clusterIndices in clusteringResult) {
      final personId = labels[clusterIndices[0]];
      final ClusterResultBuilder clusterResultBuilder =
          ClusterResultBuilder.createFromIndices(
        personId,
        clusterIndices: clusterIndices,
        allEmbeddings: allFaceEmbeddings,
        allFileIds: allFileIDs,
        allFaceIds: allFaceIDs,
      );
      clusterResultBuilders.add(clusterResultBuilder);
      clusterResults.add(clusterResultBuilder.build());
    }

    // Store the clusters in the database
    await MlDataDB.instance.createAllClusterResults(clusterResults);
  }

  /// Analyzes all the images in the database with the latest ml version and stores the results in the database.
  ///
  /// This function first checks if the image has already been analyzed with the lastest faceMlVersion and stored in the database. If so, it skips the image.
  Future<void> processAllImages() async {
    _logger.info("`processAllImages()` called");

    final List<EnteFile> enteFiles = await SearchService.instance.getAllFiles();
    final Set<int> alreadyIndexedWithLatestVersionIDs = await MlDataDB.instance
        .getAllFaceMlResultFileIDs(mlVersion: faceMlVersion);

    // Make sure the image conversion isolate is spawned
    await ImageConversionIsolate.instance.ensureSpawned();

    int fileAnalyzedCount = 0;
    int fileSkippedCount = 0;
    final stopwatch = Stopwatch()..start();
    for (final enteFile in enteFiles) {
      // Skip if the file is not uploaded or if it's a video
      if (!enteFile.isUploaded || enteFile.fileType == FileType.video) {
        fileSkippedCount++;
        continue;
      }
      // I don't know how motionPhotos and livePhotos work, so I'm also just skipping them for now
      if (enteFile.fileType == FileType.other ||
          enteFile.fileType == FileType.livePhoto) {
        fileSkippedCount++;
        continue;
      }
      // Skip if the image has already been analyzed with the latest ml version
      final id = enteFile.uploadedFileID!;
      if (alreadyIndexedWithLatestVersionIDs.contains(id)) {
        fileSkippedCount++;
        continue;
      }

      _logger.info(
        "`processAllImages()` on file number $fileAnalyzedCount: start processing image with uploadedFileID: ${enteFile.uploadedFileID}",
      );

      try {
        final result = await analyzeImage(enteFile);
        await MlDataDB.instance.createFaceMlResult(result);
        fileAnalyzedCount++;
        continue;
      } catch (e, s) {
        _logger.severe(
          "`processAllImages()`: Could not analyze image with uploadedFileID ${enteFile.uploadedFileID}",
          e,
          s,
        );
      }
    }

    stopwatch.stop();
    _logger.info(
      "`processAllImages()` finished. Analyzed $fileAnalyzedCount images, skipped $fileSkippedCount images, in ${stopwatch.elapsedMilliseconds} ms",
    );

    // Close the image conversion isolate
    ImageConversionIsolate.instance.dispose();
  }

  /// Analyzes the given image data by running the full pipeline using [analyzeImage] and stores the result in the database [MlDataDB].
  /// This function first checks if the image has already been analyzed (with latest ml version) and stored in the database. If so, it returns the stored result.
  ///
  /// 'enteFile': The ente file to analyze.
  ///
  /// Returns an immutable [FaceMlResult] instance containing the results of the analysis. The result is also stored in the database.
  Future<FaceMlResult> processFacesImage(EnteFile enteFile) async {
    _logger.info(
      "`processFacesImage` called on image with uploadedFileID ${enteFile.uploadedFileID}",
    );
    _checkEnteFileForID(enteFile);

    // Check if the image has already been analyzed and stored in the database with the latest ml version
    final existingResult = await _checkForExistingUpToDateResult(enteFile);
    if (existingResult != null) {
      return existingResult;
    }

    // If the image has not been analyzed and stored in the database, analyze it and store the result in the database
    _logger.info(
      "Image with uploadedFileID ${enteFile.uploadedFileID} has not been analyzed and stored in the database. Analyzing it now.",
    );
    final result = await analyzeImage(enteFile);

    // Store the result in the database
    await MlDataDB.instance.createFaceMlResult(result);

    return result;
  }

  /// Analyzes the given image data by running the full pipeline (face detection, face alignment, face embedding).
  ///
  /// 'enteFile': The ente file to analyze.
  ///
  /// Returns an immutable [FaceMlResult] instance containing the results of the analysis.
  /// Throws [CouldNotRetrieveAnyFileData] or [GeneralFaceMlException] if something goes wrong.
  Future<FaceMlResult> analyzeImage(EnteFile enteFile) async {
    _checkEnteFileForID(enteFile);

    final Uint8List? thumbnailData =
        await getDataForML(enteFile, typeOfData: FileDataForML.thumbnailData);
    final Uint8List? fileData =
        await getDataForML(enteFile, typeOfData: FileDataForML.fileData);

    if (thumbnailData == null && fileData == null) {
      _logger.severe(
        "Failed to get any data for enteFile with uploadedFileID ${enteFile.uploadedFileID}",
      );
      throw CouldNotRetrieveAnyFileData();
    }
    final Uint8List smallData = thumbnailData ?? fileData!;
    final Uint8List largeData = fileData ?? thumbnailData!;

    final resultBuilder =
        FaceMlResultBuilder.createWithMlMethods(file: enteFile);

    _logger.info(
      "Analyzing image with uploadedFileID: ${enteFile.uploadedFileID}",
    );
    final stopwatch = Stopwatch()..start();

    try {
      // Get the faces
      final List<FaceDetectionAbsolute> faceDetectionResult =
          await detectFaces(smallData, resultBuilder: resultBuilder);

      _logger.info("Completed `detectFaces` function");

      // If no faces were detected, return a result with no faces. Otherwise, continue.
      if (faceDetectionResult.isEmpty) {
        return resultBuilder.buildNoFaceDetected();
      }

      // Align the faces
      final List<List<List<List<double>>>> faceAlignmentResult =
          await alignFaces(
        largeData,
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
      _logger.info(
          "Completed analyzing image with uploadedFileID ${enteFile.uploadedFileID}, in "
          "${stopwatch.elapsedMilliseconds} ms");

      return resultBuilder.build();
    } catch (e, s) {
      _logger.severe("Could not analyze image", e, s);
      throw GeneralFaceMlException("Could not analyze image");
    }
  }

  Future<Uint8List?> getDataForML(
    EnteFile enteFile, {
    FileDataForML typeOfData = FileDataForML.fileData,
  }) async {
    Uint8List? data;

    switch (typeOfData) {
      case FileDataForML.fileData:
        final stopwatch = Stopwatch()..start();
        final io.File? actualIoFile = await getFile(enteFile);
        if (actualIoFile != null) {
          data = await actualIoFile.readAsBytes();
        }
        stopwatch.stop();
        _logger.info(
          "Getting file data for uploadedFileID ${enteFile.uploadedFileID} took ${stopwatch.elapsedMilliseconds} ms",
        );

        break;

      case FileDataForML.thumbnailData:
        final stopwatch = Stopwatch()..start();
        data = await getThumbnail(enteFile);
        if (data == null) {
          final io.File? actualIoFile = await getFile(enteFile);
          if (actualIoFile != null) {
            data = await actualIoFile.readAsBytes();
          }
        }
        stopwatch.stop();
        _logger.info(
          "Getting thumbnail data for uploadedFileID ${enteFile.uploadedFileID} took ${stopwatch.elapsedMilliseconds} ms",
        );
        break;

      case FileDataForML.compressedFileData:
        final stopwatch = Stopwatch()..start();
        final String tempPath = Configuration.instance.getTempDirectory() +
            "${enteFile.uploadedFileID!}";
        final io.File? actualIoFile = await getFile(enteFile);
        if (actualIoFile != null) {
          final compressResult = await FlutterImageCompress.compressAndGetFile(
            actualIoFile.path,
            tempPath + ".jpg",
          );
          if (compressResult != null) {
            data = await compressResult.readAsBytes();
          }
        }
        stopwatch.stop();
        _logger.info(
          "Getting compressed file data for uploadedFileID ${enteFile.uploadedFileID} took ${stopwatch.elapsedMilliseconds} ms",
        );
        break;
    }

    return data;
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
          await FaceDetection.instance.predict(imageData);

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
  Future<List<Double3DInputMatrix>> alignFaces(
    Uint8List imageData,
    List<FaceDetectionAbsolute> faces, {
    FaceMlResultBuilder? resultBuilder,
  }) async {
    // TODO: the image conversion below is what makes the whole pipeline slow, so come up with different solution

    // Convert the image data to an image
    final Stopwatch faceAlignmentImageDecodingStopwatch = Stopwatch()..start();
    final image_lib.Image? inputImage =
        await ImageConversionIsolate.instance.convert(imageData);
    faceAlignmentImageDecodingStopwatch.stop();
    _logger.info(
      'image decoding for alignment is finished, in ${faceAlignmentImageDecodingStopwatch.elapsedMilliseconds}ms',
    );

    if (inputImage == null) {
      _logger.severe('Error while converting Uint8List to Image');
      throw CouldNotConvertToImageImage();
    }

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
      final List<double> embedding =
          await FaceEmbedding.instance.predict(faceData);

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
          await FaceEmbedding.instance.predictBatch(facesMatrices);

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

  /// Checks if the ente file to be analyzed actually has an uploadedFileID
  void _checkEnteFileForID(EnteFile enteFile) {
    if (enteFile.uploadedFileID == null) {
      _logger.severe(
        "Failed to analyze image with enteFile ${enteFile.toString()} because it has no uploadedFileID",
      );
      throw CouldNotRetrieveAnyFileData();
    }
  }

  Future<FaceMlResult?> _checkForExistingUpToDateResult(
    EnteFile enteFile,
  ) async {
    // Check if the image has already been analyzed and stored in the database
    final existingResult =
        await MlDataDB.instance.getFaceMlResult(enteFile.uploadedFileID!);

    // If the image has already been analyzed and stored in the database, return the stored result
    if (existingResult != null) {
      if (existingResult.mlVersion >= faceMlVersion) {
        _logger.info(
          "Image with uploadedFileID ${enteFile.uploadedFileID} has already been analyzed and stored in the database with the latest ml version. Returning the stored result.",
        );
        return existingResult;
      }
    }
    return null;
  }
}
