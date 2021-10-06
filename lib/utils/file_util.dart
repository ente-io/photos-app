import 'dart:async';
import 'dart:io' as io;
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:logging/logging.dart';
import 'package:motionphoto/motionphoto.dart';
import 'package:path/path.dart';
import 'package:photos/core/cache/image_cache.dart';
import 'package:photos/core/cache/video_cache_manager.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/models/file.dart' as ente;
import 'package:photos/models/file_type.dart';
import 'package:photos/utils/file_download_util.dart';
import 'package:photos/utils/thumbnail_util.dart';

final _logger = Logger("FileUtil");

void preloadFile(ente.File file) {
  if (file.fileType == FileType.video) {
    return;
  }
  getFile(file);
}

// IMPORTANT: Delete the returned file if `isOrigin` is set to true
// https://github.com/CaiJingLong/flutter_photo_manager#cache-problem-of-ios
Future<io.File> getFile(
  ente.File file, {
  bool liveVideo = false,
  bool isOrigin = false,
} // only relevant for live photos
    ) async {
  if (file.isRemoteFile()) {
    return getFileFromServer(file, liveVideo: liveVideo);
  } else {
    String key = file.tag() + liveVideo.toString() + isOrigin.toString();
    final cachedFile = FileLruCache.get(key);
    if (cachedFile == null) {
      final diskFile = await _getLocalDiskFile(
        file,
        liveVideo: liveVideo,
        isOrigin: isOrigin,
      );
      // do not cache origin file for IOS as they are immediately deleted
      // after usage
      if (!(isOrigin && Platform.isIOS)) {
        FileLruCache.put(key, diskFile);
      }
      return diskFile;
    }
    return cachedFile;
  }
}

Future<bool> doesLocalFileExist(ente.File file) async {
  return await _getLocalDiskFile(file) != null;
}

Future<io.File> _getLocalDiskFile(
  ente.File file, {
  bool liveVideo = false,
  bool isOrigin = false,
}) async {
  if (file.isSharedMediaToAppSandbox()) {
    var localFile = io.File(getSharedMediaFilePath(file));
    return localFile.exists().then((exist) {
      return exist ? localFile : null;
    });
  } else if (file.fileType == FileType.livePhoto && liveVideo) {
    return Motionphoto.getLivePhotoFile(file.localID);
  } else {
    return file.getAsset().then((asset) async {
      if (asset == null || !(await asset.exists)) {
        return null;
      }
      return isOrigin ? asset.originFile : asset.file;
    });
  }
}

String getSharedMediaFilePath(ente.File file) {
  return Configuration.instance.getSharedMediaCacheDirectory() +
      "/" +
      file.localID.replaceAll(kSharedMediaIdentifier, '');
}

void preloadThumbnail(ente.File file) {
  if (file.isRemoteFile()) {
    getThumbnailFromServer(file);
  } else {
    getThumbnailFromLocal(file);
  }
}

final Map<String, Future<io.File>> fileDownloadsInProgress =
    Map<String, Future<io.File>>();

Future<io.File> getFileFromServer(
  ente.File file, {
  ProgressCallback progressCallback,
  bool liveVideo = false, // only needed in case of live photos
}) async {
  final cacheManager = (file.fileType == FileType.video || liveVideo)
      ? VideoCacheManager.instance
      : DefaultCacheManager();
  final fileInfo = await cacheManager.getFileFromCache(file.getDownloadUrl());
  if (fileInfo != null) {
    return fileInfo.file;
  }
  final String downloadID = file.uploadedFileID.toString() + liveVideo.toString();
  if (!fileDownloadsInProgress.containsKey(file.uploadedFileID)) {
    if (file.fileType == FileType.livePhoto) {
      fileDownloadsInProgress[downloadID] = _downloadLivePhoto(file,
              progressCallback: progressCallback, liveVideo: liveVideo)
          .whenComplete(() => fileDownloadsInProgress.remove(downloadID));
    } else {
      fileDownloadsInProgress[downloadID] = _downloadAndCache(
        file,
        cacheManager,
        progressCallback: progressCallback,
      ).whenComplete(() => fileDownloadsInProgress.remove(downloadID));
    }
  }
  return fileDownloadsInProgress[file.uploadedFileID];
}

Future<bool> isFileCached(ente.File file,
    {bool liveVideo = false}) async {
  final cacheManager = (file.fileType == FileType.video || liveVideo)
      ? VideoCacheManager.instance
      : DefaultCacheManager();
  final fileInfo = await cacheManager.getFileFromCache(file.getDownloadUrl());
  return fileInfo != null;
}

Future<io.File> _downloadLivePhoto(ente.File file,
    {ProgressCallback progressCallback, bool liveVideo = false}) async {
  return downloadAndDecrypt(file, progressCallback: progressCallback)
      .then((decryptedFile) async {
    if (decryptedFile == null) {
      return null;
    }
    _logger.fine("Decoded zipped live photo from " + decryptedFile.path);
    io.File imageFileCache, videoFileCache;
    List<int> bytes = await decryptedFile.readAsBytes();
    Archive archive = ZipDecoder().decodeBytes(bytes);
    final tempPath = Configuration.instance.getTempDirectory();
    // Extract the contents of Zip compressed archive to disk
    for (ArchiveFile archiveFile in archive) {
      if (archiveFile.isFile) {
        String filename = archiveFile.name;
        String fileExtension = getExtension(archiveFile.name);
        String decodePath =
            tempPath + file.uploadedFileID.toString() + filename;
        List<int> data = archiveFile.content;
        if (filename.startsWith("image")) {
          final imageFile = io.File(decodePath);
          await imageFile.create(recursive: true);
          await imageFile.writeAsBytes(data);
          io.File imageConvertedFile = imageFile;
          if ((fileExtension == "unknown") ||
              (io.Platform.isAndroid && fileExtension == "heic")) {
            imageConvertedFile = await FlutterImageCompress.compressAndGetFile(
              decodePath,
              decodePath + ".jpg",
              keepExif: true,
            );
            await imageFile.delete();
          }
          imageFileCache = await DefaultCacheManager().putFile(
            file.getDownloadUrl(),
            await imageConvertedFile.readAsBytes(),
            eTag: file.getDownloadUrl(),
            maxAge: Duration(days: 365),
            fileExtension: fileExtension,
          );
          await imageConvertedFile.delete();
        } else if (filename.startsWith("video")) {
          final videoFile = io.File(decodePath);
          await videoFile.create(recursive: true);
          await videoFile.writeAsBytes(data);
          videoFileCache = await VideoCacheManager.instance.putFile(
            file.getDownloadUrl(),
            await videoFile.readAsBytes(),
            eTag: file.getDownloadUrl(),
            maxAge: Duration(days: 365),
            fileExtension: fileExtension,
          );
          await videoFile.delete();
        }
      }
    }
    return liveVideo ? videoFileCache : imageFileCache;
  }).catchError((e) {
    _logger.warning("failed to download live photos" + e.toString());
    throw e;
  });
}

Future<io.File> _downloadAndCache(ente.File file, BaseCacheManager cacheManager,
    {ProgressCallback progressCallback}) async {
  return downloadAndDecrypt(file, progressCallback: progressCallback)
      .then((decryptedFile) async {
    if (decryptedFile == null) {
      return null;
    }
    var decryptedFilePath = decryptedFile.path;
    String fileExtension = getExtension(file.title);
    var outputFile = decryptedFile;
    if ((fileExtension == "unknown" && file.fileType == FileType.image) ||
        (io.Platform.isAndroid && fileExtension == "heic")) {
      outputFile = await FlutterImageCompress.compressAndGetFile(
        decryptedFilePath,
        decryptedFilePath + ".jpg",
        keepExif: true,
      );
      await decryptedFile.delete();
    }
    final cachedFile = await cacheManager.putFile(
      file.getDownloadUrl(),
      await outputFile.readAsBytes(),
      eTag: file.getDownloadUrl(),
      maxAge: Duration(days: 365),
      fileExtension: fileExtension,
    );
    await outputFile.delete();
    return cachedFile;
  }).catchError((e) {
    _logger.warning("failed to download file" + e.toString());
    throw e;
  });
}

String getExtension(String nameOrPath) {
  var fileExtension = "unknown";
  try {
    fileExtension = extension(nameOrPath).substring(1).toLowerCase();
  } catch (e) {
    _logger.severe("Could not capture file extension");
  }
  return fileExtension;
}

Future<Uint8List> compressThumbnail(Uint8List thumbnail) {
  return FlutterImageCompress.compressWithList(
    thumbnail,
    minHeight: kCompressedThumbnailResolution,
    minWidth: kCompressedThumbnailResolution,
    quality: 25,
  );
}

Future<void> clearCache(ente.File file) async {
  if (file.fileType == FileType.video) {
    VideoCacheManager.instance.removeFile(file.getDownloadUrl());
  } else {
    DefaultCacheManager().removeFile(file.getDownloadUrl());
  }
  final cachedThumbnail = io.File(
      Configuration.instance.getThumbnailCacheDirectory() +
          "/" +
          file.uploadedFileID.toString());
  if (cachedThumbnail.existsSync()) {
    await cachedThumbnail.delete();
  }
}
