import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:ui' as ui show Image;
import 'dart:ui';
import 'package:image/image.dart' as imglib;

import 'package:computer/computer.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/services/file_magic_service.dart';
import 'package:photos/services/facenet_service.dart';
import 'package:photos/utils/thumbnail_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photos/models/file.dart';
import 'package:simple_cluster/src/dbscan.dart';

class MLService {
  final _logger = Logger("MLService");
  final _db = FilesDB.instance;
  final Computer _computer = Computer();
  bool _isBackground = false;
  SharedPreferences _prefs;
  var faceImages = <imglib.Image>[];
  var faceFeatures = <List<double>>[];
  Map<int, List<imglib.Image>> faceWithLabels = {};

  final faceDetector = GoogleMlKit.vision
      .faceDetector(FaceDetectorOptions(mode: FaceDetectorMode.accurate));
  final imageLabeler = GoogleMlKit.vision.imageLabeler();
  final textDetector = GoogleMlKit.vision.textDetector();

  MLService._privateConstructor();

  static final MLService instance = MLService._privateConstructor();

  Future<void> init(bool isBackground) async {
    _isBackground = isBackground;
    _prefs = await SharedPreferences.getInstance();
    if (_isBackground) {
      await PhotoManager.setIgnorePermissionCheck(true);
    }
    await _computer.turnOn(workersCount: 1);
    await FaceNetService.instance.init();
  }

  Future<Map<int, List<imglib.Image>>> sync() async {
    await FaceNetService.instance.init();
    faceFeatures = <List<double>>[];
    final fileLoadResult = await _db.getAllUploadedFiles(
        0,
        DateTime.now().microsecondsSinceEpoch,
        Configuration.instance.getUserID(),
        limit: 15);
    for (final file in fileLoadResult.files) {
      await _syncFile(file);
    }

    DBSCAN dbscan = DBSCAN(
      epsilon: 1.0,
      minPoints: 2,
    );

    List<List<int>> clusterOutput2 = dbscan.run(faceFeatures);
    _logger.info("Clusters output");
    _logger.info(clusterOutput2); //or dbscan.cluster
    _logger.info("Noise");
    _logger.info(dbscan.noise);
    _logger.info("Cluster label for points");
    _logger.info(dbscan.label);

    dbscan.label.asMap().forEach((index, label) {
      if (faceWithLabels[label] == null) {
        faceWithLabels[label] = [];
      }

      faceWithLabels[label].add(faceImages[index]);
    });

    return faceWithLabels;
    // Bus.instance.fire(ForceReloadHomeGalleryEvent());
  }

  Future<Map<int, List<imglib.Image>>> getFaceWithLabels() {
    return Future.value(faceWithLabels);
  }

  // TODO: Remove once MLKit plugin is modified to get inmemory image
  Future<io.File> getTempFile(File file, Uint8List thumbData) async {
    io.Directory tempDir = await getTemporaryDirectory();
    String tempFileName = (file.title ?? file.uploadedFileID); //uuid.v1();
    tempFileName = tempFileName.replaceAll("/", "-");
    // _logger.fine(
    // "Creating Temp file for ${file.localID} - ${file.uploadedFileID} - $uuidStr in ${tempDir.path}");
    String tempPath = '${tempDir.path}/$tempFileName.jpeg';
    io.File tempFile = io.File(tempPath);
    tempFile.writeAsBytesSync(thumbData);
    return tempFile;
  }

  Future<void> _syncFile(File file) async {
    // Map<String, dynamic> args File file = args["file"];
    Uint8List thumbData;
    if (file.isRemoteFile()) {
      thumbData = await getThumbnailFromServer(file);
      // _logger
      // .fine("Remote File: ${file.title}, thumbSize: ${thumbData.length}");
    } else {
      // TODO: kThumbnailQuality = 50 may be less for some models
      thumbData = await getThumbnailFromLocal(file,
          size: kThumbnailLargeSize); //, updateCache: false
      // _logger.fine("Local File: ${file.title}, thumbSize: ${thumbData.length}");
    }

    // final thumbImage = await decodeImageFromList(thumbData);
    // final thumbnail = await fromThumbImage(thumbImage);
    // await _sync(file, thumbnail);

    // final thumbnailFile = await getTempFile(file, thumbData);
    // final thumbnail = fromThumbFile(thumbnailFile);
    // await _sync(file, thumbnail);
    // thumbnailFile.deleteSync();

    final thumbnail = fromThumbData(thumbData);
    await _sync(file, thumbData, thumbnail);
  }

  InputImage fromThumbData(Uint8List thumbData) {
    return InputImage.fromFileBytes(bytes: thumbData);
  }

  InputImage fromThumbFile(io.File thumbnailFile) {
    return InputImage.fromFile(thumbnailFile);
  }

  Future<InputImage> fromThumbImage(ui.Image thumbImage) async {
    InputImagePlaneMetadata metadata = InputImagePlaneMetadata(
        bytesPerRow: thumbImage.width * thumbImage.height * 4);
    InputImageData data = InputImageData(
        inputImageFormat: InputImageFormat.BGRA8888,
        size: Size(thumbImage.width as double, thumbImage.height as double),
        imageRotation: InputImageRotation.Rotation_0deg,
        planeData: [metadata]);
    final rgbaThumbData =
        await thumbImage.toByteData(format: ImageByteFormat.rawRgba);
    final rgbaThumbList = rgbaThumbData.buffer
        .asUint8List(rgbaThumbData.offsetInBytes, rgbaThumbData.lengthInBytes);
    return InputImage.fromBytes(bytes: rgbaThumbList, inputImageData: data);
  }

  Future<List<Face>> detectFaces(
      InputImage inputImage, Uint8List thumbData) async {
    List<Face> faces = await faceDetector.processImage(inputImage);
    return faces;
  }

  Future<List<ImageLabel>> detectLabels(InputImage inputImage) async {
    List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
    return labels;
  }

  Future<RecognisedText> detectText(InputImage inputImage) async {
    RecognisedText text = await textDetector.processImage(inputImage);
    return text;
  }

  imglib.Image getFaceImage(imglib.Image image, Face face) {
    return imglib.copyCrop(
      image,
      face.boundingBox.topLeft.dx.toInt(),
      face.boundingBox.topLeft.dy.toInt(),
      face.boundingBox.width.toInt(),
      face.boundingBox.height.toInt(),
    );
  }

  Future<List<double>> getFaceFeatures(imglib.Image faceImage) async {
    return FaceNetService.instance.getFeatures(faceImage);
  }

  Future<void> _sync(
      File file, Uint8List thumbData, InputImage thumbnail) async {
    // _logger.fine("Syncing ML state for photo $cacheThumbnailPath");
    final startTime = DateTime.now();

    final List<Face> faces = await detectFaces(thumbnail, thumbData);
    // await Future.delayed(Duration(milliseconds: 200));
    final List<ImageLabel> labels = await detectLabels(thumbnail);
    // await Future.delayed(Duration(milliseconds: 50));
    final recognisedText = await detectText(thumbnail);
    // await Future.delayed(Duration(milliseconds: 50));

    final thumbImage = imglib.decodeJpg(thumbData);
    for (final face in faces) {
      final faceImage = getFaceImage(thumbImage, face);
      faceImages.add(faceImage);
      faceFeatures.add(await getFaceFeatures(faceImage));
      // await Future.delayed(Duration(milliseconds: 200));
    }

    final endTime = DateTime.now();
    final duration = Duration(
        microseconds:
            endTime.microsecondsSinceEpoch - startTime.microsecondsSinceEpoch);
    _logger.info("Detected ${faces.length} faces, " +
        "with boundingBoxes: ${faces.map((f) => f.boundingBox)}, " +
        // "faceFeatures: ${faceFeatures}, " +
        "lables: ${labels.map((l) => l.label)}, " +
        "textBlocks: ${recognisedText.blocks.map((b) => b.lines.map((l) => l.text))}" +
        "in ${file.isRemoteFile() ? "Remote" : "Local"} file ${file.title}, " +
        "time taken: ${duration.inMilliseconds}ms");
    // await FileMagicService.instance.updateDetectedMLKitV1Faces(file, faces);
  }
}
