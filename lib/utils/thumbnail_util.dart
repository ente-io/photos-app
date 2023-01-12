import 'dart:async';
import 'dart:collection';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sodium/flutter_sodium.dart';
import 'package:logging/logging.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/core/cache/thumbnail_in_memory_cache.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/core/errors.dart';
import 'package:photos/core/network.dart';
import 'package:photos/models/file.dart';
import 'package:photos/utils/crypto_util.dart';
import 'package:photos/utils/file_download_util.dart';
import 'package:photos/utils/file_uploader_util.dart';
import 'package:photos/utils/file_util.dart';

final _logger = Logger("ThumbnailUtil");
const int kMaximumConcurrentDownloads = 80;
int downloaderReqInitCounter = 0;

final _uploadIDToDownloadItem = <int, FileDownloadItem>{};
final _downloadQueue = Queue<int>();

class FileDownloadItem {
  final File file;
  final Completer<Uint8List> completer;
  final CancelToken cancelToken;
  int counter = 0; // number of times file download was requested

  FileDownloadItem(this.file, this.completer, this.cancelToken, this.counter);
}

Future<Uint8List> getThumbnailFromServer(File file) async {
  final cachedThumbnail = cachedThumbnailPath(file);
  if (await cachedThumbnail.exists()) {
    final data = await cachedThumbnail.readAsBytes();
    ThumbnailInMemoryLruCache.put(file, data);
    return data;
  }

  // Check if there's already in flight request for fetching thumbnail from the
  // server
  print(
    "Entries in uploadedIDToDownloadItem : " +
        _uploadIDToDownloadItem.entries.length.toString() +
        "---------",
  );
  if (!_uploadIDToDownloadItem.containsKey(file.uploadedFileID)) {
    final item =
        FileDownloadItem(file, Completer<Uint8List>(), CancelToken(), 1);
    _uploadIDToDownloadItem[file.uploadedFileID!] = item;
    if (_downloadQueue.length > kMaximumConcurrentDownloads) {
      print("queue length : " + _downloadQueue.length.toString() + " -+-+-+-+");

      final id = _downloadQueue.removeFirst();
      final FileDownloadItem item = _uploadIDToDownloadItem.remove(id)!;
      item.cancelToken.cancel();
      item.completer.completeError(RequestCancelledError());
    }
    print("File uploadedID : " + file.uploadedFileID.toString());

    _downloadQueue.add(file.uploadedFileID!);
    _downloadItem(item);
    return item.completer.future;
  } else {
    _uploadIDToDownloadItem[file.uploadedFileID]!.counter++;
    return _uploadIDToDownloadItem[file.uploadedFileID]!.completer.future;
  }
}

Future<Uint8List?> getThumbnailFromLocal(
  File file, {
  int size = thumbnailSmallSize,
  int quality = thumbnailQuality,
}) async {
  final lruCachedThumbnail = ThumbnailInMemoryLruCache.get(file, size);
  if (lruCachedThumbnail != null) {
    return lruCachedThumbnail;
  }
  final cachedThumbnail = cachedThumbnailPath(file);
  if ((await cachedThumbnail.exists())) {
    final data = await cachedThumbnail.readAsBytes();
    ThumbnailInMemoryLruCache.put(file, data);
    return data;
  }
  if (file.isSharedMediaToAppSandbox) {
    //todo:neeraj support specifying size/quality
    return getThumbnailFromInAppCacheFile(file).then((data) {
      if (data != null) {
        ThumbnailInMemoryLruCache.put(file, data, size);
      }
      return data;
    });
  } else {
    return file.getAsset.then((asset) async {
      if (asset == null || !(await asset.exists)) {
        return null;
      }
      return asset
          .thumbnailDataWithSize(ThumbnailSize(size, size), quality: quality)
          .then((data) {
        ThumbnailInMemoryLruCache.put(file, data, size);
        return data;
      });
    });
  }
}

void removePendingGetThumbnailRequestIfAny(File file) {
  if (_uploadIDToDownloadItem.containsKey(file.uploadedFileID)) {
    final item = _uploadIDToDownloadItem[file.uploadedFileID]!;
    item.counter--;
    if (item.counter <= 0) {
      _uploadIDToDownloadItem.remove(file.uploadedFileID);
      item.cancelToken.cancel();
      _downloadQueue.removeWhere((element) => element == file.uploadedFileID);
    }
  }
}

void _downloadItem(FileDownloadItem item) async {
  try {
    downloaderReqInitCounter++;
    debugPrint("Download counter $downloaderReqInitCounter");
    await _downloadAndDecryptThumbnail(item);
    // print("Downloaded " + item.file.uploadedFileID.toString() + "---------");
  } catch (e, s) {
    _logger.severe(
      "Failed to download thumbnail " + item.file.toString(),
      e,
      s,
    );
    item.completer.completeError(e);
  }
  print(
    "length of queue in _downloadItem: " +
        _downloadQueue.length.toString() +
        "-+-+-+",
  );
  _downloadQueue.removeWhere((element) => element == item.file.uploadedFileID);
  _uploadIDToDownloadItem.remove(item.file.uploadedFileID);
}

Future<void> _downloadAndDecryptThumbnail(FileDownloadItem item) async {
  final file = item.file;
  Uint8List encryptedThumbnail;
  try {
    encryptedThumbnail = (await Network.instance.getDio().get(
              file.thumbnailUrl,
              options: Options(
                headers: {"X-Auth-Token": Configuration.instance.getToken()},
                responseType: ResponseType.bytes,
              ),
              cancelToken: item.cancelToken,
            ))
        .data;
  } catch (e) {
    if (e is DioError && CancelToken.isCancel(e)) {
      return;
    }
    rethrow;
  }
  if (!_uploadIDToDownloadItem.containsKey(file.uploadedFileID)) {
    return;
  }
  final thumbnailDecryptionKey = decryptFileKey(file);
  var data = await CryptoUtil.decryptChaCha(
    encryptedThumbnail,
    thumbnailDecryptionKey,
    Sodium.base642bin(file.thumbnailDecryptionHeader!),
  );
  final thumbnailSize = data.length;
  if (thumbnailSize > thumbnailDataLimit) {
    data = await compressThumbnail(data);
  }
  ThumbnailInMemoryLruCache.put(item.file, data);
  final cachedThumbnail = cachedThumbnailPath(item.file);
  if (await cachedThumbnail.exists()) {
    await cachedThumbnail.delete();
  }
  // data is already cached in-memory, no need to await on dist write
  // unawaited(cachedThumbnail.writeAsBytes(data));
  if (_uploadIDToDownloadItem.containsKey(file.uploadedFileID)) {
    try {
      item.completer.complete(data);
    } catch (e) {
      _logger.severe(
        "Error while completing request for " + file.uploadedFileID.toString(),
      );
    }
  }
}

io.File cachedThumbnailPath(File file) {
  final thumbnailCacheDirectory =
      Configuration.instance.getThumbnailCacheDirectory();
  return io.File(
    thumbnailCacheDirectory + "/" + file.uploadedFileID.toString(),
  );
}
