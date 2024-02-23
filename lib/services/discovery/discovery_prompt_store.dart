import "package:isar/isar.dart";
import "package:path_provider/path_provider.dart";
import "package:photos/services/discovery/discovery_prompt.dart";

class DiscoveryPromptStore {
  late final Isar _isar;

  DiscoveryPromptStore._privateConstructor();

  static final DiscoveryPromptStore instance =
      DiscoveryPromptStore._privateConstructor();

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open([DiscoveryPromptSchema], directory: dir.path);
  }

  Future<List<DiscoveryPrompt>> getAll() async {
    return _isar.discoveryPrompts.where().findAll();
  }

  Future<void> updatePrompts(List<DiscoveryPrompt> prompts) async {
    final ids = await getAll()
        .then((prompts) => prompts.map((prompt) => prompt.id).toList());
    await _isar.writeTxn(() async {
      await _isar.discoveryPrompts.deleteAll(ids);
      await _isar.discoveryPrompts.putAll(prompts);
    });
  }
}
