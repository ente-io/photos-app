import 'dart:async';
import 'dart:io' as dartio;

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/models/file.dart';
import 'package:photos/models/file_type.dart';
import 'package:photos/utils/dialog_util.dart';
import 'package:photos/utils/exif_util.dart';
import 'package:photos/utils/file_util.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart';

final _logger = Logger("ShareUtil");
// share is used to share media/files from ente to other apps
Future<void> share(BuildContext context, List<File> files) async {
  final dialog = createProgressDialog(context, "preparing...");
  await dialog.show();
  final List<Future<String>> pathFutures = [];
  for (File file in files) {
    // Note: We are requesting the origin file for performance reasons on iOS.
    // This will eat up storage, which will be reset only when the app restarts.
    // We could have cleared the cache had there been a callback to the share API.
    pathFutures.add(getFile(file, isOrigin: true)!.then((file) => file!.path));
    if (file.fileType == FileType.livePhoto) {
      pathFutures
          .add(getFile(file, liveVideo: true)!.then((file) => file!.path));
    }
  }
  final paths = await Future.wait(pathFutures);
  await dialog.hide();
  return Share.shareFiles(paths);
}

Future<void> shareText(String text) async {
  return Share.share(text);
}

Future<List<File>> convertIncomingSharedMediaToFile(
    List<SharedMediaFile> sharedMedia, int? collectionID) async {
  List<File> localFiles = [];
  for (var media in sharedMedia) {
    if (!(media.type == SharedMediaType.IMAGE ||
        media.type == SharedMediaType.VIDEO)) {
      _logger.warning(
          "ignore unsupported file type ${media.type.toString()} path: ${media.path}");
      continue;
    }
    var enteFile = File();
    // fileName: img_x.jpg
    enteFile.title = basename(media.path);
    var ioFile = dartio.File(media.path);
    ioFile = ioFile.renameSync(
        Configuration.instance.getSharedMediaCacheDirectory() +
            "/" +
            enteFile.title!);
    enteFile.localID = kSharedMediaIdentifier + enteFile.title!;
    enteFile.collectionID = collectionID;
    enteFile.fileType =
        media.type == SharedMediaType.IMAGE ? FileType.image : FileType.video;
    if (enteFile.fileType == FileType.image) {
      final exifTime = await getCreationTimeFromEXIF(ioFile);
      if (exifTime != null) {
        enteFile.creationTime = exifTime.microsecondsSinceEpoch;
      }
    } else if (enteFile.fileType == FileType.video) {
      enteFile.duration = media.duration ?? 0;
    }
    if (enteFile.creationTime == null || enteFile.creationTime == 0) {
      final parsedDateTime =
          parseDateFromFileName(basenameWithoutExtension(media.path));
      if (parsedDateTime != null) {
        enteFile.creationTime = parsedDateTime.microsecondsSinceEpoch;
      } else {
        enteFile.creationTime = DateTime.now().microsecondsSinceEpoch;
      }
    }
    enteFile.modificationTime = enteFile.creationTime;
    localFiles.add(enteFile);
  }
  return localFiles;
}

DateTime? parseDateFromFileName(String fileName) {
  if (fileName.startsWith('IMG-') || fileName.startsWith('VID-')) {
    // Whatsapp media files
    return DateTime.tryParse(fileName.split('-')[1]);
  } else if (fileName.startsWith("Screenshot_")) {
    // Screenshots on droid
    return DateTime.tryParse(
        (fileName).replaceAll('Screenshot_', '').replaceAll('-', 'T'));
  } else {
    return DateTime.tryParse((fileName)
        .replaceAll("IMG_", "")
        .replaceAll("VID_", "")
        .replaceAll("DCIM_", "")
        .replaceAll("_", " "));
  }
}
