import "dart:async";

import "package:logging/logging.dart";

import "package:photos/core/network/network.dart";
import "package:photos/services/discovery/discovery_prompt.dart";
import "package:photos/services/discovery/discovery_prompt_store.dart";

class DiscoveryService {
  DiscoveryService._privateConstructor();

  static final DiscoveryService instance =
      DiscoveryService._privateConstructor();

  static const kDiscoveryPrompts = "https://discover.ente.io/v1.json";

  final _logger = Logger("DiscoveryService");
  final _dio = NetworkClient.instance.getDio();
  final List<DiscoveryPrompt> _prompts = [];

  Future<void> init() async {
    await DiscoveryPromptStore.instance.init();
    _prompts.addAll(await DiscoveryPromptStore.instance.getAll());
    _logger.info("Loaded prompts: $_prompts");
    unawaited(_fetchPrompts());
  }

  Future<void> _fetchPrompts() async {
    final response = await _dio.get(kDiscoveryPrompts);
    final List<dynamic> jsonData = response.data['prompts'];
    final prompts = jsonData.map<DiscoveryPrompt>((jsonItem) {
      return DiscoveryPrompt.fromMap(jsonItem);
    }).toList();
    await DiscoveryPromptStore.instance.updatePrompts(prompts);
  }
}
