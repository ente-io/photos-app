import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:computer/computer.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/utils/thumbnail_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photos/models/file.dart';

class MLService {
  final _logger = Logger("MLService");
  final _db = FilesDB.instance;
  final Computer _computer = Computer();
  bool _isBackground = false;
  SharedPreferences _prefs;

  final faceDetector = GoogleMlKit.vision.faceDetector();

  MLService._privateConstructor();

  static final MLService instance = MLService._privateConstructor();

  Future<void> init(bool isBackground) async {
    _isBackground = isBackground;
    _prefs = await SharedPreferences.getInstance();
    if (_isBackground) {
      await PhotoManager.setIgnorePermissionCheck(true);
    }
    await _computer.turnOn(workersCount: 1);
  }

  Future<void> sync() async {
    final files = await _db.getLatestCollectionFiles();
    for (final file in files) {
      await _syncFile(file);
    }
  }

  Future<void> _syncFile(File file) async {
    Uint8List thumbData;
    if (file.isRemoteFile()) {
      thumbData = await getThumbnailFromServer(file);
    } else {
      // TODO: kThumbnailQuality = 50 may be less for some models
      thumbData = await getThumbnailFromLocal(file,
          size: kThumbnailLargeSize); //, updateCache: false
    }

    io.Directory tempDir = await getTemporaryDirectory();
    String tempPath = '${tempDir.path}/${file.localID ?? file.uploadedFileID}';
    io.File tempFile = io.File(tempPath);
    tempFile.writeAsBytesSync(thumbData);
    await _sync(tempPath);
    tempFile.deleteSync();
  }

  Future<void> _sync(String cacheThumbnailPath) async {
    _logger.info("Syncing ML state for photo $cacheThumbnailPath");
    final inputImage = InputImage.fromFilePath(cacheThumbnailPath);

    final startTime = DateTime.now();

    final List<Face> faces = await faceDetector.processImage(inputImage);

    final endTime = DateTime.now();
    final duration = Duration(
        microseconds:
            endTime.microsecondsSinceEpoch - startTime.microsecondsSinceEpoch);
    _logger.info(
        "Detected ${faces.length} faces in $cacheThumbnailPath, time taken: ${duration.inMilliseconds}ms");
  }
}
