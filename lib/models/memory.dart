import "package:photos/models/cached_memory.dart";
import 'package:photos/models/file/file.dart';

class Memory {
  final EnteFile file;
  int _seenTime;

  Memory(this.file, this._seenTime);

  bool isSeen() {
    return _seenTime != -1;
  }

  int seenTime() {
    return _seenTime;
  }

  void markSeen() {
    _seenTime = DateTime.now().microsecondsSinceEpoch;
  }
}

extension MemoryExtension on Memory {
  CachedMemory get toCachedMemory =>
      CachedMemory(file.uploadedFileID!, _seenTime);
}
