import 'dart:async';
import "dart:convert";
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive_io.dart';
import 'package:logging/logging.dart';
import "package:motion_photos/motion_photos.dart";
import 'package:motionphoto/motionphoto.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/core/errors.dart';
import 'package:photos/models/file.dart' as ente;
import 'package:photos/models/file_type.dart';
import "package:photos/models/location/location.dart";
import "package:photos/models/metadata/file_magic.dart";
import "package:photos/services/file_magic_service.dart";
import 'package:photos/utils/crypto_util.dart';
import 'package:photos/utils/file_util.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

final _logger = Logger("FileUtil");
const kMaximumThumbnailCompressionAttempts = 2;
const kLivePhotoHashSeparator = ':';

class MediaUploadData {
  final io.File? sourceFile;
  final Uint8List? thumbnail;
  final bool isDeleted;
  final FileHashData? hashData;
  final int? height;
  final int? width;
  // For android motion photos, the startIndex is the index of the first frame
  // For iOS, this value will be always null.
  final int? motionPhotoStartIndex;

  MediaUploadData(
    this.sourceFile,
    this.thumbnail,
    this.isDeleted,
    this.hashData, {
    this.height,
    this.width,
    this.motionPhotoStartIndex,
  });
}

class FileHashData {
  // For livePhotos, the fileHash value will be imageHash:videoHash
  final String? fileHash;

  // zipHash is used to take care of existing live photo uploads from older
  // mobile clients
  String? zipHash;

  FileHashData(this.fileHash, {this.zipHash});
}

Future<MediaUploadData> getUploadDataFromEnteFile(ente.File file) async {
  if (file.isSharedMediaToAppSandbox) {
    return await _getMediaUploadDataFromAppCache(file);
  } else {
    return await _getMediaUploadDataFromAssetFile(file);
  }
}

Future<MediaUploadData> _getMediaUploadDataFromAssetFile(ente.File file) async {
  io.File? sourceFile;
  Uint8List? thumbnailData;
  bool isDeleted;
  String? zipHash;
  String fileHash;

  // The timeouts are to safeguard against https://github.com/CaiJingLong/flutter_photo_manager/issues/467
  final asset = await file.getAsset
      .timeout(const Duration(seconds: 3))
      .catchError((e) async {
    if (e is TimeoutException) {
      _logger.info("Asset fetch timed out for " + file.toString());
      return await file.getAsset;
    } else {
      throw e;
    }
  });
  if (asset == null) {
    throw InvalidFileError("asset is null");
  }
  sourceFile = await asset.originFile
      .timeout(const Duration(seconds: 3))
      .catchError((e) async {
    if (e is TimeoutException) {
      _logger.info("Origin file fetch timed out for " + file.toString());
      return await asset.originFile;
    } else {
      throw e;
    }
  });
  if (sourceFile == null || !sourceFile.existsSync()) {
    throw InvalidFileError("source fill is null or do not exist");
  }

  // h4ck to fetch location data if missing (thank you Android Q+) lazily only during uploads
  await _decorateEnteFileData(file, asset);
  fileHash = CryptoUtil.bin2base64(await CryptoUtil.getHash(sourceFile));

  if (file.fileType == FileType.livePhoto && io.Platform.isIOS) {
    final io.File? videoUrl = await Motionphoto.getLivePhotoFile(file.localID!);
    if (videoUrl == null || !videoUrl.existsSync()) {
      final String errMsg =
          "missing livePhoto url for  ${file.toString()} with subType ${file.fileSubType}";
      _logger.severe(errMsg);
      throw InvalidFileUploadState(errMsg);
    }
    final String livePhotoVideoHash =
        CryptoUtil.bin2base64(await CryptoUtil.getHash(videoUrl));
    // imgHash:vidHash
    fileHash = '$fileHash$kLivePhotoHashSeparator$livePhotoVideoHash';
    final tempPath = Configuration.instance.getTempDirectory();
    // .elp -> ente live photo
    final livePhotoPath = tempPath + file.generatedID.toString() + ".elp";
    _logger.fine("Uploading zipped live photo from " + livePhotoPath);
    final encoder = ZipFileEncoder();
    encoder.create(livePhotoPath);
    encoder.addFile(videoUrl, "video" + extension(videoUrl.path));
    encoder.addFile(sourceFile, "image" + extension(sourceFile.path));
    encoder.close();
    // delete the temporary video and image copy (only in IOS)
    if (io.Platform.isIOS) {
      await sourceFile.delete();
    }
    // new sourceFile which needs to be uploaded
    sourceFile = io.File(livePhotoPath);
    zipHash = CryptoUtil.bin2base64(await CryptoUtil.getHash(sourceFile));
  }

  thumbnailData = await asset.thumbnailDataWithSize(
    const ThumbnailSize(thumbnailLargeSize, thumbnailLargeSize),
    quality: thumbnailQuality,
  );
  if (thumbnailData == null) {
    throw InvalidFileError("unable to get asset thumbData");
  }
  int compressionAttempts = 0;
  while (thumbnailData!.length > thumbnailDataLimit &&
      compressionAttempts < kMaximumThumbnailCompressionAttempts) {
    _logger.info("Thumbnail size " + thumbnailData.length.toString());
    thumbnailData = await compressThumbnail(thumbnailData);
    _logger
        .info("Compressed thumbnail size " + thumbnailData.length.toString());
    compressionAttempts++;
  }
  isDeleted = !(await asset.exists);
  int? h, w;
  if (asset.width != 0 && asset.height != 0) {
    h = asset.height;
    w = asset.width;
  }
  int? motionPhotoStartingIndex;
  if (io.Platform.isAndroid && asset.type == AssetType.image) {
    try {
      motionPhotoStartingIndex =
          (await MotionPhotos(sourceFile.path).getMotionVideoIndex())?.start;
    } catch (e) {
      _logger.severe('error while detecthing motion photo start index', e);
    }
  }
  return MediaUploadData(
    sourceFile,
    thumbnailData,
    isDeleted,
    FileHashData(fileHash, zipHash: zipHash),
    height: h,
    width: w,
    motionPhotoStartIndex: motionPhotoStartingIndex,
  );
}

Future<void> _decorateEnteFileData(ente.File file, AssetEntity asset) async {
  // h4ck to fetch location data if missing (thank you Android Q+) lazily only during uploads
  if (file.location == null ||
      (file.location!.latitude == 0 && file.location!.longitude == 0)) {
    final latLong = await asset.latlngAsync();
    file.location =
        Location(latitude: latLong.latitude, longitude: latLong.longitude);
  }

  if (file.title == null || file.title!.isEmpty) {
    _logger.warning("Title was missing ${file.tag}");
    file.title = await asset.titleAsync;
  }
}

Future<MetadataRequest> getPubMetadataRequest(
  ente.File file,
  Map<String, dynamic> newData,
  Uint8List fileKey,
) async {
  final Map<String, dynamic> jsonToUpdate =
      jsonDecode(file.pubMmdEncodedJson ?? '{}');
  newData.forEach((key, value) {
    jsonToUpdate[key] = value;
  });

  // update the local information so that it's reflected on UI
  file.pubMmdEncodedJson = jsonEncode(jsonToUpdate);
  file.pubMagicMetadata = PubMagicMetadata.fromJson(jsonToUpdate);
  final encryptedMMd = await CryptoUtil.encryptChaCha(
    utf8.encode(jsonEncode(jsonToUpdate)) as Uint8List,
    fileKey,
  );
  return MetadataRequest(
    version: file.pubMmdVersion == 0 ? 1 : file.pubMmdVersion,
    count: jsonToUpdate.length,
    data: CryptoUtil.bin2base64(encryptedMMd.encryptedData!),
    header: CryptoUtil.bin2base64(encryptedMMd.header!),
  );
}

Future<MediaUploadData> _getMediaUploadDataFromAppCache(ente.File file) async {
  io.File sourceFile;
  Uint8List? thumbnailData;
  const bool isDeleted = false;
  final localPath = getSharedMediaFilePath(file);
  sourceFile = io.File(localPath);
  if (!sourceFile.existsSync()) {
    _logger.warning("File doesn't exist in app sandbox");
    throw InvalidFileError("File doesn't exist in app sandbox");
  }
  try {
    thumbnailData = await getThumbnailFromInAppCacheFile(file);
    final fileHash =
        CryptoUtil.bin2base64(await CryptoUtil.getHash(sourceFile));
    Map<String, int>? dimensions;
    if (file.fileType == FileType.image) {
      dimensions = await getImageHeightAndWith(imagePath: localPath);
    } else {
      // for video, we need to use the thumbnail data with any max width/height
      final thumbnailFilePath = await VideoThumbnail.thumbnailFile(
        video: localPath,
        imageFormat: ImageFormat.JPEG,
        thumbnailPath: (await getTemporaryDirectory()).path,
        quality: 10,
      );
      dimensions = await getImageHeightAndWith(imagePath: thumbnailFilePath);
    }
    return MediaUploadData(
      sourceFile,
      thumbnailData,
      isDeleted,
      FileHashData(fileHash),
      height: dimensions?['height'],
      width: dimensions?['width'],
    );
  } catch (e, s) {
    _logger.severe("failed to generate thumbnail", e, s);
    throw InvalidFileError(
      "thumbnail generation failed for fileType: ${file.fileType.toString()}",
    );
  }
}

Future<Map<String, int>?> getImageHeightAndWith({
  String? imagePath,
  Uint8List? imageBytes,
}) async {
  if (imagePath == null && imageBytes == null) {
    throw ArgumentError("imagePath and imageBytes cannot be null");
  }
  try {
    late Uint8List bytes;
    if (imagePath != null) {
      final io.File imageFile = io.File(imagePath);
      bytes = await imageFile.readAsBytes();
    } else {
      bytes = imageBytes!;
    }
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    if (frameInfo.image.width == 0 || frameInfo.image.height == 0) {
      return null;
    } else {
      return {
        "width": frameInfo.image.width,
        "height": frameInfo.image.height,
      };
    }
  } catch (e) {
    _logger.severe("Failed to get image size", e);
    return null;
  }
}

Future<Uint8List?> getThumbnailFromInAppCacheFile(ente.File file) async {
  var localFile = io.File(getSharedMediaFilePath(file));
  if (!localFile.existsSync()) {
    return null;
  }
  if (file.fileType == FileType.video) {
    final thumbnailFilePath = await VideoThumbnail.thumbnailFile(
      video: localFile.path,
      imageFormat: ImageFormat.JPEG,
      thumbnailPath: (await getTemporaryDirectory()).path,
      maxWidth: thumbnailLargeSize,
      quality: 80,
    );
    localFile = io.File(thumbnailFilePath!);
  }
  var thumbnailData = await localFile.readAsBytes();
  int compressionAttempts = 0;
  while (thumbnailData.length > thumbnailDataLimit &&
      compressionAttempts < kMaximumThumbnailCompressionAttempts) {
    _logger.info("Thumbnail size " + thumbnailData.length.toString());
    thumbnailData = await compressThumbnail(thumbnailData);
    _logger
        .info("Compressed thumbnail size " + thumbnailData.length.toString());
    compressionAttempts++;
  }
  return thumbnailData;
}
