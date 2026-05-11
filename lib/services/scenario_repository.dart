import 'dart:convert';
import 'dart:math';

import 'package:firepumpsim/models/scenario_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loads practice scenarios from JSON assets.
///
/// Because Flutter cannot reliably enumerate bundled assets at runtime, we use a
/// simple manifest file (`assets/scenarios/scenario_manifest.json`) that lists
/// the scenario JSON files to load.
class ScenarioRepository {
  ScenarioRepository({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<PracticeScenario>? _cachedScenarios;
  List<PlayableScenarioProblem>? _cachedPlayable;

  Future<List<PracticeScenario>> loadScenarios() async {
    if (_cachedScenarios != null) return _cachedScenarios!;

    try {
      final manifestStr = await rootBundle.loadString('assets/scenarios/scenario_manifest.json');
      final decoded = jsonDecode(manifestStr);
      final files = (decoded is Map && decoded['files'] is List) ? List<String>.from(decoded['files'] as List) : <String>[];

      final scenarios = <PracticeScenario>[];
      for (final file in files) {
        try {
          final jsonStr = await rootBundle.loadString(file);
          final obj = jsonDecode(jsonStr);
          if (obj is Map<String, dynamic>) {
            final scenario = PracticeScenario.fromJson(obj);
            if (scenario.id.trim().isNotEmpty && scenario.title.trim().isNotEmpty) scenarios.add(scenario);
          }
        } catch (e) {
          debugPrint('Failed to load scenario file $file: $e');
        }
      }

      _cachedScenarios = scenarios;
      return scenarios;
    } catch (e) {
      debugPrint('Failed to load scenario manifest: $e');
      _cachedScenarios = const [];
      return const [];
    }
  }

  Future<List<PlayableScenarioProblem>> loadPlayableProblems() async {
    if (_cachedPlayable != null) return _cachedPlayable!;
    final scenarios = await loadScenarios();

    final playable = <PlayableScenarioProblem>[];
    for (final s in scenarios) {
      final baseDifficulty = (s.difficulty ?? 'Intermediate').trim();
      final baseTimed = s.timedModeAvailable ?? false;
      playable.add(
        PlayableScenarioProblem(
          scenarioId: s.id,
          scenarioTitle: s.title,
          type: s.type,
          chip: s.chip,
          image: s.image,
          scene: s.scene,
          studentQuestion: s.studentQuestion,
          details: s.details,
          overlays: s.overlays,
          answers: s.answers,
          formulaBreakdown: s.formulaBreakdown,
          correctPP: s.correctPP,
          tolerance: s.tolerance,
          instructorExplanation: s.instructorExplanation,
          explainMistake: s.explainMistake,
          problemId: s.id,
          problemTitle: s.title,
          isVariation: false,
          variationIndex: null,
          difficulty: baseDifficulty.isEmpty ? 'Intermediate' : baseDifficulty,
          timedModeAvailable: baseTimed,
          variationCount: s.variations.length,
        ),
      );

      for (var i = 0; i < s.variations.length; i++) {
        final v = s.variations[i];
        final variationDifficulty = (v.difficulty ?? s.difficulty ?? 'Intermediate').trim();
        final variationTimed = v.timedModeAvailable ?? s.timedModeAvailable ?? false;
        final variationId = v.id.trim().isNotEmpty ? v.id.trim() : '${s.id}__v$i';
        final variationTitle = v.title.trim().isNotEmpty ? v.title.trim() : '${s.title} (Variation ${i + 1})';
        playable.add(
          PlayableScenarioProblem(
            scenarioId: s.id,
            scenarioTitle: s.title,
            type: s.type,
            chip: s.chip,
            image: s.image,
            scene: s.scene,
            studentQuestion: v.studentQuestion,
            details: v.details,
            overlays: v.overlays,
            answers: v.answers,
            formulaBreakdown: v.formulaBreakdown,
            correctPP: v.correctPP,
            tolerance: v.tolerance,
            instructorExplanation: v.instructorExplanation,
            explainMistake: s.explainMistake,
            problemId: variationId,
            problemTitle: variationTitle,
            isVariation: true,
            variationIndex: i,
            difficulty: variationDifficulty.isEmpty ? 'Intermediate' : variationDifficulty,
            timedModeAvailable: variationTimed,
            variationCount: s.variations.length,
          ),
        );
      }
    }

    _cachedPlayable = playable;
    return playable;
  }

  /// Returns scenarios for browsing (base scenarios only).
  /// Variations are shown only as counts, and are playable from the player.
  Future<List<PracticeScenario>> queryScenarios({
    required String typeFilter,
    required String difficultyFilter,
  }) async {
    final scenarios = await loadScenarios();
    return scenarios.where((s) {
      final difficulty = (s.difficulty ?? 'Intermediate').trim();
      final typeOk = typeFilter == 'All' || s.type == typeFilter;
      final diffOk = difficultyFilter == 'All' || difficulty == difficultyFilter;
      return typeOk && diffOk;
    }).toList(growable: false);
  }

  Future<PlayableScenarioProblem?> findPlayableByProblemId(String problemId) async {
    final playable = await loadPlayableProblems();
    try {
      return playable.firstWhere((p) => p.problemId == problemId);
    } catch (_) {
      return null;
    }
  }

  Future<PlayableScenarioProblem?> randomPlayable({
    required String typeFilter,
    required String difficultyFilter,
  }) async {
    final playable = await loadPlayableProblems();
    final filtered = playable.where((p) {
      final typeOk = typeFilter == 'All' || p.type == typeFilter;
      final diffOk = difficultyFilter == 'All' || p.difficulty == difficultyFilter;
      return typeOk && diffOk;
    }).toList(growable: false);
    if (filtered.isEmpty) return null;
    return filtered[_random.nextInt(filtered.length)];
  }

  Future<PlayableScenarioProblem?> startBaseProblem(String scenarioId) async {
    final playable = await loadPlayableProblems();
    try {
      return playable.firstWhere((p) => p.scenarioId == scenarioId && !p.isVariation);
    } catch (_) {
      return null;
    }
  }

  Future<PlayableScenarioProblem?> startRandomVariation(String scenarioId) async {
    final playable = await loadPlayableProblems();
    final variations = playable.where((p) => p.scenarioId == scenarioId && p.isVariation).toList(growable: false);
    if (variations.isEmpty) return null;
    return variations[_random.nextInt(variations.length)];
  }
}
