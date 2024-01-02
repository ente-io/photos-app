import "dart:io" as io;
import "dart:typed_data" show Uint8List;

import "package:flutter/foundation.dart";
import "package:flutter_image_compress/flutter_image_compress.dart";
import "package:logging/logging.dart";
import "package:photos/core/configuration.dart";
import "package:photos/db/ml_data_db.dart";
import "package:photos/models/file/file.dart";
import "package:photos/models/file/file_type.dart";
import 'package:photos/models/ml/ml_typedefs.dart';
import "package:photos/models/ml/ml_versions.dart";
import "package:photos/services/face_ml/face_clustering/face_clustering_service.dart";
import "package:photos/services/face_ml/face_detection/detection.dart";
import "package:photos/services/face_ml/face_detection/yolov5face/yolo_face_detection_exceptions.dart";
import "package:photos/services/face_ml/face_detection/yolov5face/yolo_face_detection_onnx.dart";
import "package:photos/services/face_ml/face_embedding/face_embedding_exceptions.dart";
import "package:photos/services/face_ml/face_embedding/face_embedding_service.dart";
import "package:photos/services/face_ml/face_ml_exceptions.dart";
import "package:photos/services/face_ml/face_ml_result.dart";
import "package:photos/services/search_service.dart";
import "package:photos/utils/file_util.dart";
import 'package:photos/utils/image_ml_isolate.dart';
import "package:photos/utils/thumbnail_util.dart";

enum FileDataForML { thumbnailData, fileData, compressedFileData }

/// This class is responsible for running the full face ml pipeline on images.
///
/// WARNING: For getting the ML results needed for the UI, you should use `FaceSearchService` instead of this class!
///
/// The pipeline consists of face detection, face alignment and face embedding.
class FaceMlService {
  final _logger = Logger("FaceMlService");

  // late SimilarityTransform _similarityTransform;

  // singleton pattern
  FaceMlService._privateConstructor();
  static final instance = FaceMlService._privateConstructor();
  factory FaceMlService() => instance;

  bool initialized = false;

  Future<void> init() async {
    if (initialized) {
      return;
    }
    _logger.info("init called");
    try {
      await YoloOnnxFaceDetection.instance.init();
    } catch (e, s) {
      _logger.severe("Could not initialize blazeface", e, s);
    }
    try {
      await ImageMlIsolate.instance.init();
    } catch (e, s) {
      _logger.severe("Could not initialize image ml isolate", e, s);
    }
    try {
      await FaceEmbedding.instance.init();
    } catch (e, s) {
      _logger.severe("Could not initialize mobilefacenet", e, s);
    }
    initialized = true;
  }

  Future<void> indexAndClusterAllImages() async {
    // Run the analysis on all images to make sure everything is analyzed
    await indexAllImages();

    // Cluster all the images
    await clusterAllImages();
  }

  Future<void> clusterAllImages() async {
    _logger.info("`clusterAllImages()` called");

    try {
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

      _logger.info(
        "`clusterAllImages`: Starting clustering, on ${allFaceEmbeddings.length} face embeddings",
      );
      if (allFaceEmbeddings.isEmpty) {
        _logger.warning("No face embeddings found, skipping clustering");
        return;
      }

      // Run the clustering
      // final clusteringResult =
      //     await FaceClustering.instance.predict(allFaceEmbeddings);
      // final labels = FaceClustering.instance.labels;
      // if (labels == null) {
      //   _logger.severe("Clustering failed");
      //   throw GeneralFaceMlException("Clustering failed");
      // }

      // Create the clusters
      // final List<ClusterResultBuilder> clusterResultBuilders = [
      //   for (final clusterIndices in clusteringResult)
      //     ClusterResultBuilder.createFromIndices(
      //       clusterIndices: clusterIndices,
      //       labels: labels,
      //       allEmbeddings: allFaceEmbeddings,
      //       allFileIds: allFileIDs,
      //       allFaceIds: allFaceIDs,
      //     ),
      // ];
      // final List<ClusterResult> clusterResults =
      //     await ClusterResultBuilder.buildClusters(clusterResultBuilders);
      // _logger.info(
      //   "`clusterAllImages`: Finished clustering,  ${clusterResults.length} clusters found (after feedback)",
      // );

      // Store the clusters in the database
      // await MlDataDB.instance.createAllClusterResults(clusterResults);
    } catch (e, s) {
      _logger.severe("`clusterAllImages` failed", e, s);
    }
  }

  /// Analyzes all the images in the database with the latest ml version and stores the results in the database.
  ///
  /// This function first checks if the image has already been analyzed with the lastest faceMlVersion and stored in the database. If so, it skips the image.
  Future<void> indexAllImages() async {
    _logger.info("`indexAllImages()` called");

    final List<EnteFile> enteFiles = await SearchService.instance.getAllFiles();
    final Set<int> alreadyIndexedWithLatestVersionIDs = await MlDataDB.instance
        .getAllFaceMlResultFileIDs(mlVersion: faceMlVersion);

    // Make sure the image conversion isolate is spawned
    await ImageMlIsolate.instance.ensureSpawned();

    int fileAnalyzedCount = 0;
    int fileSkippedCount = 0;
    final stopwatch = Stopwatch()..start();
    for (final enteFile in enteFiles) {
      if (_skipAnalysisEnteFile(
        enteFile,
        alreadyIndexedWithLatestVersionIDs: alreadyIndexedWithLatestVersionIDs,
      )) {
        fileSkippedCount++;
        continue;
      }

      _logger.info(
        "`indexAllImages()` on file number $fileAnalyzedCount: start processing image with uploadedFileID: ${enteFile.uploadedFileID}",
      );

      try {
        final result = await analyzeImage(
          enteFile,
          preferUsingThumbnailForEverything: false,
          disposeImageIsolateAfterUse: false,
        );
        await MlDataDB.instance.createFaceMlResult(result);
        fileAnalyzedCount++;
        continue;
      } catch (e, s) {
        _logger.severe(
          "`indexAllImages()`: Could not analyze image with uploadedFileID ${enteFile.uploadedFileID}",
          e,
          s,
        );
      }
    }

    stopwatch.stop();
    _logger.info(
      "`indexAllImages()` finished. Analyzed $fileAnalyzedCount images, skipped $fileSkippedCount images, in ${stopwatch.elapsedMilliseconds} ms",
    );

    // Close the image conversion isolate
    ImageMlIsolate.instance.dispose();
  }

  /// Updates the results of the given images in the database. Updates regardless of the ml version, set [updateHigherVersionOnly] to true to only update if the ml version is higher than the one in the database.
  Future<int> updateResultSelectedImages(
    List<EnteFile> enteFiles, {
    bool updateHigherVersionOnly = false,
  }) async {
    int updatedImagesCount = 0;
    for (final enteFile in enteFiles) {
      if (_skipAnalysisEnteFile(enteFile)) {
        continue;
      }

      _logger.info(
        "`updateResultSelectedImages()`: start processing image with uploadedFileID: ${enteFile.uploadedFileID}",
      );

      try {
        final result = await analyzeImage(
          enteFile,
          preferUsingThumbnailForEverything: false,
          disposeImageIsolateAfterUse: false,
        );
        await MlDataDB.instance.updateFaceMlResult(
          result,
          updateHigherVersionOnly: updateHigherVersionOnly,
        );
        updatedImagesCount++;
        continue;
      } catch (e, s) {
        _logger.severe(
          "`indexAllImages()`: Could not analyze image with uploadedFileID ${enteFile.uploadedFileID}",
          e,
          s,
        );
      }
    }

    // Close the image conversion isolate
    ImageMlIsolate.instance.dispose();

    return updatedImagesCount;
  }

  /// Analyzes the given image data by running the full pipeline using [analyzeImage] and stores the result in the database [MlDataDB].
  /// This function first checks if the image has already been analyzed (with latest ml version) and stored in the database. If so, it returns the stored result.
  ///
  /// 'enteFile': The ente file to analyze.
  ///
  /// Returns an immutable [FaceMlResult] instance containing the results of the analysis. The result is also stored in the database.
  Future<FaceMlResult> indexImage(EnteFile enteFile) async {
    _logger.info(
      "`indexImage` called on image with uploadedFileID ${enteFile.uploadedFileID}",
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
    FaceMlResult result;
    try {
      result = await analyzeImage(enteFile);
    } catch (e, s) {
      _logger.severe(
        "`indexImage` failed on image with uploadedFileID ${enteFile.uploadedFileID}",
        e,
        s,
      );
      throw GeneralFaceMlException(
        "`indexImage` failed on image with uploadedFileID ${enteFile.uploadedFileID}",
      );
    }

    // Store the result in the database
    await MlDataDB.instance.createFaceMlResult(result);

    return result;
  }

  /// Analyzes the given image data by running the full pipeline (face detection, face alignment, face embedding).
  ///
  /// [enteFile] The ente file to analyze.
  ///
  /// [preferUsingThumbnailForEverything] If true, the thumbnail will be used for everything (face detection, face alignment, face embedding), and file data will be used only if a thumbnail is unavailable.
  /// If false, thumbnail will only be used for detection, and the original image will be used for face alignment and face embedding.
  ///
  /// Returns an immutable [FaceMlResult] instance containing the results of the analysis.
  /// Does not store the result in the database, for that you should use [indexImage].
  /// Throws [CouldNotRetrieveAnyFileData] or [GeneralFaceMlException] if something goes wrong.
  /// TODO: improve function such that it only uses full image if it is already on the device, otherwise it uses thumbnail. And make sure to store what is used!
  Future<FaceMlResult> analyzeImage(
    EnteFile enteFile, {
    bool preferUsingThumbnailForEverything = false,
    bool disposeImageIsolateAfterUse = true,
  }) async {
    _checkEnteFileForID(enteFile);

    final Uint8List? thumbnailData =
        await _getDataForML(enteFile, typeOfData: FileDataForML.fileData);
    Uint8List? fileData;

    // // TODO: remove/optimize this later. Not now though: premature optimization
    // fileData =
    //     await _getDataForML(enteFile, typeOfData: FileDataForML.fileData);

    if (thumbnailData == null) {
      fileData =
          await _getDataForML(enteFile, typeOfData: FileDataForML.fileData);
      if (thumbnailData == null && fileData == null) {
        _logger.severe(
          "Failed to get any data for enteFile with uploadedFileID ${enteFile.uploadedFileID}",
        );
        throw CouldNotRetrieveAnyFileData();
      }
    }
    // TODO: use smallData and largeData instead of thumbnailData and fileData again!
    final Uint8List smallData = thumbnailData ?? fileData!;

    final resultBuilder = FaceMlResultBuilder.fromEnteFile(enteFile);

    _logger.info(
      "Analyzing image with uploadedFileID: ${enteFile.uploadedFileID}",
    );
    final stopwatch = Stopwatch()..start();

    try {
      // Get the faces
      final List<FaceDetectionRelative> faceDetectionResult =
          await _detectFaces(
        smallData,
        resultBuilder: resultBuilder,
      );

      _logger.info("Completed `detectFaces` function");

      // If no faces were detected, return a result with no faces. Otherwise, continue.
      if (faceDetectionResult.isEmpty) {
        return resultBuilder.buildNoFaceDetected();
      }

      if (!preferUsingThumbnailForEverything) {
        fileData ??=
            await _getDataForML(enteFile, typeOfData: FileDataForML.fileData);
      }
      resultBuilder.onlyThumbnailUsed = fileData == null;
      final Uint8List largeData = fileData ?? thumbnailData!;

      // Align the faces
      final List<List<List<List<num>>>> faceAlignmentResult = await _alignFaces(
        largeData,
        faceDetectionResult,
        resultBuilder: resultBuilder,
      );

      _logger.info("Completed `alignFaces` function");

      // Get the embeddings of the faces
      await _embedFaces(
        faceAlignmentResult,
        resultBuilder: resultBuilder,
      );

      _logger.info("Completed `embedBatchFaces` function");

      stopwatch.stop();
      _logger.info(
          "Completed analyzing image with uploadedFileID ${enteFile.uploadedFileID}, in "
          "${stopwatch.elapsedMilliseconds} ms");

      if (disposeImageIsolateAfterUse) {
        // Close the image conversion isolate
        ImageMlIsolate.instance.dispose();
      }

      return resultBuilder.build();
    } catch (e, s) {
      _logger.severe("Could not analyze image", e, s);
      throw GeneralFaceMlException("Could not analyze image");
    }
  }

  Future<Uint8List?> _getDataForML(
    EnteFile enteFile, {
    FileDataForML typeOfData = FileDataForML.fileData,
  }) async {
    Uint8List? data;

    switch (typeOfData) {
      case FileDataForML.fileData:
        final stopwatch = Stopwatch()..start();
        final io.File? actualIoFile = await getFile(enteFile, isOrigin: true);
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
  Future<List<FaceDetectionRelative>> _detectFaces(
    Uint8List thumbnailData,
    // Uint8List fileData,
    {
    FaceMlResultBuilder? resultBuilder,
  }) async {
    try {
      // Get the bounding boxes of the faces
      final List<FaceDetectionRelative> faces =
          await YoloOnnxFaceDetection.instance.predict(thumbnailData);

      // Add detected faces to the resultBuilder
      if (resultBuilder != null) {
        resultBuilder.addNewlyDetectedFaces(faces);
      }

      return faces;
    } on YOLOInterpreterInitializationException {
      throw CouldNotInitializeFaceDetector();
    } on YOLOInterpreterRunException {
      throw CouldNotRunFaceDetector();
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
  /// Throws [CouldNotWarpAffine] or [GeneralFaceMlException] if the face alignment fails.
  Future<List<Num3DInputMatrix>> _alignFaces(
    Uint8List imageData,
    List<FaceDetectionRelative> faces, {
    FaceMlResultBuilder? resultBuilder,
  }) async {
    try {
      final (alignedFaces, alignmentResults) = await ImageMlIsolate.instance
          .preprocessMobileFaceNet(imageData, faces);

      if (resultBuilder != null) {
        for (int faceIndex = 0; faceIndex < faces.length; ++faceIndex) {
          resultBuilder.addAlignmentToExistingFace(
            alignmentResults[faceIndex],
            faceIndex,
          );
        }
      }

      return alignedFaces;
    } catch (e, s) {
      _logger.severe('Face alignment failed: $e', e, s);
      throw CouldNotWarpAffine();
    }
  }

  /// Embeds multiple faces from the given input matrices.
  ///
  /// `facesMatrices`: The input matrices of the faces to embed.
  ///
  /// Returns a list of the face embeddings as lists of doubles.
  ///
  /// Throws [CouldNotInitializeFaceEmbeddor], [CouldNotRunFaceEmbeddor], [InputProblemFaceEmbeddor] or [GeneralFaceMlException] if the face embedding fails.
  Future<List<List<double>>> _embedFaces(
    List<Num3DInputMatrix> facesMatrices, {
    FaceMlResultBuilder? resultBuilder,
  }) async {
    try {
      // Get the embedding of the faces
      final List<List<double>> embeddings =
          await FaceEmbedding.instance.predict(facesMatrices);

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

  /// Checks if the ente file to be analyzed actually can be analyzed: it must be uploaded and in the correct format.
  void _checkEnteFileForID(EnteFile enteFile) {
    if (_skipAnalysisEnteFile(enteFile)) {
      _logger.severe(
        "Skipped analysis of image with enteFile ${enteFile.toString()} because it is the wrong format or has no uploadedFileID",
      );
      throw CouldNotRetrieveAnyFileData();
    }
  }

  bool _skipAnalysisEnteFile(
    EnteFile enteFile, {
    Set<int>? alreadyIndexedWithLatestVersionIDs,
  }) {
    // Skip if the file is not uploaded
    if (!enteFile.isUploaded) {
      return true;
    }

    // Skip if the file is a video
    if (enteFile.fileType == FileType.video) {
      return true;
    }

    // I don't know how motionPhotos and livePhotos work, so I'm also just skipping them for now
    if (enteFile.fileType == FileType.other ||
        enteFile.fileType == FileType.livePhoto) {
      return true;
    }

    // Skip if the file is already analyzed with the latest ml version
    if (alreadyIndexedWithLatestVersionIDs != null) {
      final id = enteFile.uploadedFileID!;
      if (alreadyIndexedWithLatestVersionIDs.contains(id)) {
        return true;
      }
    }

    return false;
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
