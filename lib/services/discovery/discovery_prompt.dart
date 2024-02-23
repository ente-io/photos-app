import "dart:convert";

import "package:isar/isar.dart";

part 'discovery_prompt.g.dart';

@collection
class DiscoveryPrompt {
  Id id = Isar.autoIncrement;
  final String prompt;
  final String title;
  final double minimumScore;
  final double? minimumSize;

  DiscoveryPrompt(
    this.prompt,
    this.title,
    this.minimumScore,
    this.minimumSize,
  );

  Map<String, dynamic> toMap() {
    return {
      'prompt': prompt,
      'title': title,
      'minimumScore': minimumScore,
      'minimumSize': minimumSize,
    };
  }

  factory DiscoveryPrompt.fromMap(Map<String, dynamic> map) {
    return DiscoveryPrompt(
      map['prompt'] ?? '',
      map['title'] ?? '',
      map['minimumScore']?.toDouble() ?? 0.0,
      map['minimumSize']?.toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory DiscoveryPrompt.fromJson(String source) =>
      DiscoveryPrompt.fromMap(json.decode(source));

  @override
  String toString() {
    return 'DiscoveryPrompt(prompt: $prompt, title: $title, minimumScore: $minimumScore, minimumSize: $minimumSize)';
  }
}
