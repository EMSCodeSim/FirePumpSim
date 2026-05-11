import 'package:flutter/foundation.dart';

/// FirePumpSim Scenario JSON model.
///
/// This intentionally keeps many fields as `dynamic` / `Map<String, dynamic>`
/// because scenario packs may evolve over time (and because the prompt’s JSON
/// structure includes nested arrays/maps with no strict schema defined).
@immutable
class PracticeScenario {
  const PracticeScenario({
    required this.id,
    required this.title,
    required this.type,
    required this.chip,
    required this.image,
    required this.scene,
    required this.studentQuestion,
    required this.details,
    required this.overlays,
    required this.answers,
    required this.formulaBreakdown,
    required this.correctPP,
    required this.tolerance,
    required this.instructorExplanation,
    required this.explainMistake,
    required this.variations,
    this.difficulty,
    this.timedModeAvailable,
  });

  final String id;
  final String title;
  final String type;
  final String chip;

  /// A small thumbnail asset path (e.g., `assets/images/...jpg`).
  final String image;

  /// A larger scene/hero image asset path (can be the same as [image]).
  final String scene;

  final String studentQuestion;
  final List<dynamic> details;
  final List<dynamic> overlays;
  final Map<String, dynamic> answers;
  final List<dynamic> formulaBreakdown;
  final num? correctPP;
  final num? tolerance;
  final String instructorExplanation;
  final String explainMistake;
  final List<ScenarioVariation> variations;

  /// Optional extension fields (not in the prompt’s required schema, but
  /// needed for UI requirements like difficulty and “Timed Mode available”).
  final String? difficulty;
  final bool? timedModeAvailable;

  static PracticeScenario fromJson(Map<String, dynamic> json) {
    final variationsRaw = json['variations'];
    return PracticeScenario(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      chip: (json['chip'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      scene: (json['scene'] ?? json['image'] ?? '').toString(),
      studentQuestion: (json['studentQuestion'] ?? '').toString(),
      details: (json['details'] is List) ? List<dynamic>.from(json['details'] as List) : const [],
      overlays: (json['overlays'] is List) ? List<dynamic>.from(json['overlays'] as List) : const [],
      answers: (json['answers'] is Map)
          ? Map<String, dynamic>.from(json['answers'] as Map)
          : const <String, dynamic>{},
      formulaBreakdown: (json['formulaBreakdown'] is List)
          ? List<dynamic>.from(json['formulaBreakdown'] as List)
          : const [],
      correctPP: json['correctPP'] is num ? json['correctPP'] as num : num.tryParse('${json['correctPP']}'),
      tolerance: json['tolerance'] is num ? json['tolerance'] as num : num.tryParse('${json['tolerance']}'),
      instructorExplanation: (json['instructorExplanation'] ?? '').toString(),
      explainMistake: (json['explainMistake'] ?? '').toString(),
      variations: (variationsRaw is List)
          ? variationsRaw
              .whereType<Map>()
              .map((e) => ScenarioVariation.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const [],
      difficulty: json['difficulty']?.toString(),
      timedModeAvailable: json['timedModeAvailable'] is bool ? json['timedModeAvailable'] as bool : null,
    );
  }
}

@immutable
class ScenarioVariation {
  const ScenarioVariation({
    required this.id,
    required this.title,
    required this.studentQuestion,
    required this.details,
    required this.overlays,
    required this.answers,
    required this.correctPP,
    required this.tolerance,
    required this.formulaBreakdown,
    required this.instructorExplanation,
    this.difficulty,
    this.timedModeAvailable,
  });

  /// Optional variation id. If not provided, the repository will synthesize one.
  final String id;
  final String title;

  final String studentQuestion;
  final List<dynamic> details;
  final List<dynamic> overlays;
  final Map<String, dynamic> answers;
  final num? correctPP;
  final num? tolerance;
  final List<dynamic> formulaBreakdown;
  final String instructorExplanation;

  final String? difficulty;
  final bool? timedModeAvailable;

  static ScenarioVariation fromJson(Map<String, dynamic> json) {
    return ScenarioVariation(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      studentQuestion: (json['studentQuestion'] ?? '').toString(),
      details: (json['details'] is List) ? List<dynamic>.from(json['details'] as List) : const [],
      overlays: (json['overlays'] is List) ? List<dynamic>.from(json['overlays'] as List) : const [],
      answers: (json['answers'] is Map)
          ? Map<String, dynamic>.from(json['answers'] as Map)
          : const <String, dynamic>{},
      correctPP: json['correctPP'] is num ? json['correctPP'] as num : num.tryParse('${json['correctPP']}'),
      tolerance: json['tolerance'] is num ? json['tolerance'] as num : num.tryParse('${json['tolerance']}'),
      formulaBreakdown: (json['formulaBreakdown'] is List)
          ? List<dynamic>.from(json['formulaBreakdown'] as List)
          : const [],
      instructorExplanation: (json['instructorExplanation'] ?? '').toString(),
      difficulty: json['difficulty']?.toString(),
      timedModeAvailable: json['timedModeAvailable'] is bool ? json['timedModeAvailable'] as bool : null,
    );
  }
}

/// A single playable problem.
///
/// Base scenario == one playable problem.
/// Each variation == its own playable problem.
@immutable
class PlayableScenarioProblem {
  const PlayableScenarioProblem({
    required this.scenarioId,
    required this.scenarioTitle,
    required this.type,
    required this.chip,
    required this.image,
    required this.scene,
    required this.studentQuestion,
    required this.details,
    required this.overlays,
    required this.answers,
    required this.formulaBreakdown,
    required this.correctPP,
    required this.tolerance,
    required this.instructorExplanation,
    required this.explainMistake,
    required this.problemId,
    required this.problemTitle,
    required this.isVariation,
    required this.variationIndex,
    required this.difficulty,
    required this.timedModeAvailable,
    required this.variationCount,
  });

  final String scenarioId;
  final String scenarioTitle;
  final String type;
  final String chip;
  final String image;
  final String scene;

  final String studentQuestion;
  final List<dynamic> details;
  final List<dynamic> overlays;
  final Map<String, dynamic> answers;
  final List<dynamic> formulaBreakdown;
  final num? correctPP;
  final num? tolerance;
  final String instructorExplanation;
  final String explainMistake;

  /// Unique id for the playable problem (base or variation).
  final String problemId;

  /// Display title for the playable problem.
  ///
  /// For base problems, this equals the scenario title.
  /// For variations, this can be the variation title (or a synthesized one).
  final String problemTitle;

  final bool isVariation;
  final int? variationIndex;

  final String difficulty;
  final bool timedModeAvailable;
  final int variationCount;
}
