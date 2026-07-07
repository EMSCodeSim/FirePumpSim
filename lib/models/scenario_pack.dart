import 'package:flutter/foundation.dart';

@immutable
class ScenarioPack {
  const ScenarioPack({
    required this.packId,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.scenarioCount,
    required this.isFree,
    required this.isPurchased,
    required this.scenarioFiles,
    this.storeProductId = '',
    this.priceText = '',
  });

  final String packId;
  final String title;
  final String description;
  final String difficulty;
  final int scenarioCount;
  final bool isFree;
  final bool isPurchased;
  final List<String> scenarioFiles;
  final String storeProductId;
  final String priceText;

  ScenarioPack copyWith({
    String? packId,
    String? title,
    String? description,
    String? difficulty,
    int? scenarioCount,
    bool? isFree,
    bool? isPurchased,
    List<String>? scenarioFiles,
    String? storeProductId,
    String? priceText,
  }) {
    return ScenarioPack(
      packId: packId ?? this.packId,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      scenarioCount: scenarioCount ?? this.scenarioCount,
      isFree: isFree ?? this.isFree,
      isPurchased: isPurchased ?? this.isPurchased,
      scenarioFiles: scenarioFiles ?? this.scenarioFiles,
      storeProductId: storeProductId ?? this.storeProductId,
      priceText: priceText ?? this.priceText,
    );
  }

  factory ScenarioPack.fromJson(Map<String, dynamic> json) {
    final filesRaw = json['scenarioFiles'];
    final files = (filesRaw is List)
        ? filesRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false)
        : const <String>[];

    return ScenarioPack(
      packId: (json['packId'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      difficulty: (json['difficulty'] ?? '').toString().trim(),
      scenarioCount: (json['scenarioCount'] is num)
          ? (json['scenarioCount'] as num).toInt()
          : int.tryParse((json['scenarioCount'] ?? '').toString().trim()) ?? files.length,
      isFree: json['isFree'] == true,
      isPurchased: json['isPurchased'] == true,
      scenarioFiles: files,
      storeProductId: (json['storeProductId'] ?? '').toString().trim(),
      priceText: (json['priceText'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packId': packId,
      'title': title,
      'description': description,
      'difficulty': difficulty,
      'scenarioCount': scenarioCount,
      'isFree': isFree,
      'isPurchased': isPurchased,
      'scenarioFiles': scenarioFiles,
      'storeProductId': storeProductId,
      'priceText': priceText,
    };
  }
}

@immutable
class ScenarioPacksIndex {
  const ScenarioPacksIndex({required this.packs});

  final List<ScenarioPack> packs;

  factory ScenarioPacksIndex.fromJson(Map<String, dynamic> json) {
    final raw = json['packs'];
    if (raw is! List) return const ScenarioPacksIndex(packs: <ScenarioPack>[]);
    final packs = raw.whereType<Map>().map((m) => ScenarioPack.fromJson(Map<String, dynamic>.from(m))).toList(growable: false);
    return ScenarioPacksIndex(packs: packs);
  }
}
