import "package:isar/isar.dart";
import "package:path_provider/path_provider.dart";
import 'package:photos/models/cached_memory.dart';

class CachedMemoriesDB {
  late final Isar _isar;

  CachedMemoriesDB._privateConstructor();

  static final instance = CachedMemoriesDB._privateConstructor();

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [CachedMemorySchema],
      directory: dir.path,
    );
  }

  Future<void> clearTable() async {
    await _isar.writeTxn(() => _isar.clear());
  }

  Future<List<CachedMemory>> getAll() async {
    return _isar.cachedMemorys.where().findAll();
  }

  Future<void> clearAndPut(List<CachedMemory> cachedMemories) async {
    await _isar.writeTxn(() => _isar.clear());
    return _isar.writeTxn(() => _isar.cachedMemorys.putAll(cachedMemories));
  }

  Future<bool> isNotEmpty() {
    return _isar.cachedMemorys.where().isNotEmpty();
  }
}
