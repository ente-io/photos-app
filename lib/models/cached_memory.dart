import "package:isar/isar.dart";

part 'cached_memory.g.dart';

@collection
class CachedMemory {
  Id id = Isar.autoIncrement;
  final int uploadedID;
  int seenTime;

  CachedMemory(this.uploadedID, this.seenTime);
}
