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

  static String _normalizeAssetPath(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    // Keep asset paths as-authored.
    // Some existing FirePumpSim assets intentionally include spaces in filenames
    // (and Flutter can load them fine), so we must not rewrite them here.
    return trimmed;
  }

  static bool _looksLikeAssetPath(String v) {
    final s = v.trim();
    if (s.isEmpty) return false;
    final lower = s.toLowerCase();
    final hasExt = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp') || lower.endsWith('.gif');
    if (!hasExt) return false;
    return lower.startsWith('assets/');
  }

  static String _pickBestImagePath(dynamic image, dynamic scene) {
    final candidates = <String>[
      if (image != null) image.toString(),
      if (scene != null) scene.toString(),
    ].map(_normalizeAssetPath).toList(growable: false);

    for (final c in candidates) {
      if (_looksLikeAssetPath(c)) return c;
    }
    // If nothing qualifies, return empty so the UI can show a graceful
    // placeholder without attempting to fetch an obviously-invalid asset path.
    return '';
  }
  static String _firstText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final raw = json[key];
      if (raw == null) continue;
      final s = raw.toString().trim();
      if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
    }
    return '';
  }

  static String _humanizeLabel(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    final cleaned = s.replaceAll('_', ' ').replaceAll('-', ' ');
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList(growable: false);
    return parts
        .map((part) {
          final lower = part.toLowerCase();
          if (lower == 'gpm' || lower == 'psi' || lower == 'ldh') return lower.toUpperCase();
          if (lower == 'xd') return 'XD';
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  static List<dynamic> _listFromAny(dynamic raw) {
    if (raw is List) return List<dynamic>.from(raw);
    if (raw is Map) {
      return raw.entries
          .map((e) => <String, dynamic>{'label': e.key.toString(), 'value': e.value.toString()})
          .toList(growable: false);
    }
    final s = (raw ?? '').toString().trim();
    if (s.isNotEmpty && s.toLowerCase() != 'null') return <dynamic>[s];
    return const [];
  }

  static Map<String, dynamic> _answersFromJson(Map<String, dynamic> json) {
    final answers = <String, dynamic>{};
    if (json['answers'] is Map) answers.addAll(Map<String, dynamic>.from(json['answers'] as Map));

    final topLevelAliases = <String>[
      'answer',
      'answerValue',
      'correctAnswer',
      'correctPP',
      'pumpPressure',
      'answerUnit',
      'unit',
      'answerLabel',
      'tolerance',
      'frictionLoss',
      'nozzlePressure',
      'elevationPressure',
      'applianceLoss',
      'totalGpm',
    ];
    for (final key in topLevelAliases) {
      if (json.containsKey(key) && !answers.containsKey(key)) answers[key] = json[key];
    }

    // Common aliases used by the player and daily challenge helpers.
    final answerValue = answers['answerValue'] ?? answers['correctAnswer'] ?? answers['answer'] ?? answers['value'] ?? answers['pumpPressure'] ?? answers['correctPP'];
    if (answerValue != null) {
      answers['answerValue'] ??= answerValue;
      answers['correctAnswer'] ??= answerValue;
      answers['value'] ??= answerValue;
      answers['pp'] ??= answerValue;
    }
    answers['answerUnit'] ??= answers['unit'] ?? json['answerUnit'] ?? 'PSI';
    answers['unit'] ??= answers['answerUnit'];
    answers['answerLabel'] ??= json['answerLabel'] ?? 'Pump Pressure';
    answers['tolerance'] ??= json['tolerance'] ?? 5;
    return answers;
  }

  static num? _numFromAny(dynamic raw) {
    if (raw is num) return raw;
    return num.tryParse((raw ?? '').toString());
  }


  static PracticeScenario fromJson(Map<String, dynamic> json) {
    final variationsRaw = json['variations'] ?? json['problems'];
    final variations = (variationsRaw is List)
        ? variationsRaw
            .whereType<Map>()
            .map((e) => ScenarioVariation.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <ScenarioVariation>[];

    final rawImage = json['image'] ?? json['thumbnail'];
    final rawScene = json['scene'] ?? json['sceneImage'] ?? json['image'];
    final bestImage = _pickBestImagePath(rawImage, rawScene);
    final normalizedScene = _normalizeAssetPath((rawScene ?? rawImage ?? '').toString());
    final bestScene = _looksLikeAssetPath(normalizedScene) ? normalizedScene : bestImage;
    final answers = _answersFromJson(json);
    final title = _firstText(json, const ['title', 'name']);
    final type = _humanizeLabel(_firstText(json, const ['type', 'scenarioType', 'skillType', 'questionType']));
    final chip = _humanizeLabel(_firstText(json, const ['chip', 'category', 'type', 'scenarioType']));
    final difficulty = _humanizeLabel(_firstText(json, const ['difficulty', 'level']));

    final topQuestion = _firstText(json, const ['studentQuestion', 'question', 'problem', 'prompt']);
    final topDetails = _listFromAny(json['details'] ?? json['info'] ?? json['facts']);
    final topOverlays = _listFromAny(json['overlays'] ?? json['labels'] ?? json['callouts']);
    final firstChildWithQuestion = variations.where((v) => v.studentQuestion.trim().isNotEmpty).isNotEmpty
        ? variations.firstWhere((v) => v.studentQuestion.trim().isNotEmpty)
        : null;
    final firstChildWithDetails = variations.where((v) => v.details.isNotEmpty).isNotEmpty
        ? variations.firstWhere((v) => v.details.isNotEmpty)
        : null;
    final firstChildWithOverlays = variations.where((v) => v.overlays.isNotEmpty).isNotEmpty
        ? variations.firstWhere((v) => v.overlays.isNotEmpty)
        : null;

    return PracticeScenario(
      id: _firstText(json, const ['id', 'scenarioId']),
      title: title,
      type: type.isEmpty ? 'Scenario' : type,
      chip: chip.isEmpty ? 'Practice' : chip,
      image: bestImage,
      scene: bestScene,
      studentQuestion: topQuestion.isNotEmpty ? topQuestion : (firstChildWithQuestion?.studentQuestion ?? ''),
      details: topDetails.isNotEmpty ? topDetails : (firstChildWithDetails?.details ?? const []),
      overlays: topOverlays.isNotEmpty ? topOverlays : (firstChildWithOverlays?.overlays ?? const []),
      answers: answers,
      formulaBreakdown: _listFromAny(json['formulaBreakdown'] ?? json['formula'] ?? json['math'] ?? json['steps']),
      correctPP: _numFromAny(json['answerValue'] ?? json['correctAnswer'] ?? json['answer'] ?? json['correctPP'] ?? json['pumpPressure'] ?? answers['answerValue'] ?? answers['correctAnswer'] ?? answers['value'] ?? answers['pp'] ?? answers['pumpPressure']),
      tolerance: _numFromAny(json['tolerance'] ?? answers['tolerance']),
      instructorExplanation: _firstText(json, const ['instructorExplanation', 'explanation', 'teachingPoint', 'teachingFeedback']),
      explainMistake: _firstText(json, const ['explainMistake', 'commonMistake', 'mistakeExplanation']),
      variations: variations,
      difficulty: difficulty.isEmpty ? null : difficulty,
      timedModeAvailable: json['timedModeAvailable'] is bool
          ? json['timedModeAvailable'] as bool
          : (json['timedMode'] is bool ? json['timedMode'] as bool : null),
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
    final answers = PracticeScenario._answersFromJson(json);
    final difficulty = PracticeScenario._humanizeLabel(PracticeScenario._firstText(json, const ['difficulty', 'level']));
    return ScenarioVariation(
      id: PracticeScenario._firstText(json, const ['id', 'problemId', 'variationId']),
      title: PracticeScenario._firstText(json, const ['title', 'name']),
      studentQuestion: PracticeScenario._firstText(json, const ['studentQuestion', 'question', 'problem', 'prompt']),
      details: PracticeScenario._listFromAny(json['details'] ?? json['info'] ?? json['facts']),
      overlays: PracticeScenario._listFromAny(json['overlays'] ?? json['labels'] ?? json['callouts']),
      answers: answers,
      correctPP: PracticeScenario._numFromAny(json['answerValue'] ?? json['correctAnswer'] ?? json['answer'] ?? json['correctPP'] ?? json['pumpPressure'] ?? answers['answerValue'] ?? answers['correctAnswer'] ?? answers['value'] ?? answers['pp'] ?? answers['pumpPressure']),
      tolerance: PracticeScenario._numFromAny(json['tolerance'] ?? answers['tolerance']),
      formulaBreakdown: PracticeScenario._listFromAny(json['formulaBreakdown'] ?? json['formula'] ?? json['math'] ?? json['steps']),
      instructorExplanation: PracticeScenario._firstText(json, const ['instructorExplanation', 'explanation', 'teachingPoint', 'teachingFeedback']),
      difficulty: difficulty.isEmpty ? null : difficulty,
      timedModeAvailable: json['timedModeAvailable'] is bool
          ? json['timedModeAvailable'] as bool
          : (json['timedMode'] is bool ? json['timedMode'] as bool : null),
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
