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

  static String normalize(String input) => input.toLowerCase().trim().replaceAll(RegExp(r'[_\-\s]+'), ' ');

  static bool _matchesFilter(String value, String filter) {
    final v = normalize(value);
    final f = normalize(filter);
    if (f.isEmpty) return true;
    return v == f;
  }

  static bool matchesSearch({required String searchText, required List<String> fields}) {
    final q = normalize(searchText);
    if (q.isEmpty) return true;

    final tokens = q.split(RegExp(r'\s+')).where((t) => t.trim().isNotEmpty).toList(growable: false);
    if (tokens.isEmpty) return true;

    final haystack = normalize(fields.where((f) => f.trim().isNotEmpty).join(' '));
    // For multi-token searches, require each token to appear somewhere.
    return tokens.every(haystack.contains);
  }

  static int difficultyRank(String difficulty) {
    switch (normalize(difficulty)) {
      case 'beginner':
        return 0;
      case 'intermediate':
        return 1;
      case 'advanced':
        return 2;
      default:
        return 1; // default to Intermediate
    }
  }

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
        final variationQuestion = v.studentQuestion.trim().isNotEmpty ? v.studentQuestion : s.studentQuestion;
        final variationDetails = v.details.isNotEmpty ? v.details : s.details;
        final variationOverlays = v.overlays.isNotEmpty ? v.overlays : s.overlays;
        final variationAnswers = v.answers.isNotEmpty ? v.answers : s.answers;
        final variationFormula = v.formulaBreakdown.isNotEmpty ? v.formulaBreakdown : s.formulaBreakdown;
        final variationExplanation = v.instructorExplanation.trim().isNotEmpty ? v.instructorExplanation : s.instructorExplanation;
        playable.add(
          PlayableScenarioProblem(
            scenarioId: s.id,
            scenarioTitle: s.title,
            type: s.type,
            chip: s.chip,
            image: s.image,
            scene: s.scene,
            studentQuestion: variationQuestion,
            details: variationDetails,
            overlays: variationOverlays,
            answers: variationAnswers,
            formulaBreakdown: variationFormula,
            correctPP: v.correctPP ?? s.correctPP,
            tolerance: v.tolerance ?? s.tolerance,
            instructorExplanation: variationExplanation,
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
  Future<List<PracticeScenario>> queryScenarios({required String typeFilter, required String difficultyFilter}) async {
    // Backwards compatible wrapper.
    return queryScenariosAdvanced(
      searchText: '',
      typeFilter: typeFilter == 'All' ? 'All Types' : typeFilter,
      levelFilter: difficultyFilter == 'All' ? 'All Levels' : difficultyFilter,
      modeFilter: 'All Modes',
      sortMode: 'Recommended',
    );
  }

  /// Advanced scenario query used by the modern picker.
  ///
  /// Filters are human-readable UI labels:
  /// - typeFilter: "All Types" or a scenario type
  /// - levelFilter: "All Levels" / Beginner / Intermediate / Advanced
  /// - modeFilter: "All Modes" / Timed Available / Untimed
  /// - sortMode: Recommended / A-Z / Beginner First / Advanced First
  Future<List<PracticeScenario>> queryScenariosAdvanced({
    required String searchText,
    required String typeFilter,
    required String levelFilter,
    required String modeFilter,
    required String sortMode,
  }) async {
    final scenarios = await loadScenarios();

    bool typeOk(PracticeScenario s) {
      if (normalize(typeFilter) == normalize('All Types') || typeFilter.trim().isEmpty) return true;
      // Compare safely even if JSON uses lowercase/underscore variations.
      return normalize(s.type) == normalize(typeFilter);
    }

    bool levelOk(PracticeScenario s) {
      if (normalize(levelFilter) == normalize('All Levels') || levelFilter.trim().isEmpty) return true;
      final d = (s.difficulty ?? 'Intermediate').trim();
      return _matchesFilter(d.isEmpty ? 'Intermediate' : d, levelFilter);
    }

    bool modeOk(PracticeScenario s) {
      final timed = s.timedModeAvailable ?? false;
      if (normalize(modeFilter) == normalize('All Modes') || modeFilter.trim().isEmpty) return true;
      if (normalize(modeFilter) == normalize('Timed Available')) return timed;
      if (normalize(modeFilter) == normalize('Untimed')) return !timed;
      return true;
    }

    final filtered = scenarios.where((s) {
      final difficulty = (s.difficulty ?? 'Intermediate').trim();
      final safeDifficulty = difficulty.isEmpty ? 'Intermediate' : difficulty;
      final matches = matchesSearch(
        searchText: searchText,
        fields: [s.title, s.type, s.chip, safeDifficulty, s.studentQuestion],
      );
      return matches && typeOk(s) && levelOk(s) && modeOk(s);
    }).toList(growable: true);

    final sm = normalize(sortMode);
    if (sm == normalize('A-Z')) {
      filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (sm == normalize('Beginner First')) {
      filtered.sort((a, b) {
        final ar = difficultyRank((a.difficulty ?? 'Intermediate').trim());
        final br = difficultyRank((b.difficulty ?? 'Intermediate').trim());
        final diff = ar.compareTo(br);
        return diff != 0 ? diff : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    } else if (sm == normalize('Advanced First')) {
      filtered.sort((a, b) {
        final ar = difficultyRank((a.difficulty ?? 'Intermediate').trim());
        final br = difficultyRank((b.difficulty ?? 'Intermediate').trim());
        final diff = br.compareTo(ar);
        return diff != 0 ? diff : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    } else {
      // Recommended = original manifest order.
    }

    return filtered.toList(growable: false);
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
    // Backwards compatible wrapper.
    return randomPlayableAdvanced(
      searchText: '',
      typeFilter: typeFilter == 'All' ? 'All Types' : typeFilter,
      levelFilter: difficultyFilter == 'All' ? 'All Levels' : difficultyFilter,
      modeFilter: 'All Modes',
    );
  }

  /// Random playable from *filtered* playable problems (includes variations).
  Future<PlayableScenarioProblem?> randomPlayableAdvanced({
    required String searchText,
    required String typeFilter,
    required String levelFilter,
    required String modeFilter,
  }) async {
    final playable = await loadPlayableProblems();

    bool typeOk(PlayableScenarioProblem p) {
      if (normalize(typeFilter) == normalize('All Types') || typeFilter.trim().isEmpty) return true;
      return normalize(p.type) == normalize(typeFilter);
    }

    bool levelOk(PlayableScenarioProblem p) {
      if (normalize(levelFilter) == normalize('All Levels') || levelFilter.trim().isEmpty) return true;
      final d = (p.difficulty).trim().isEmpty ? 'Intermediate' : p.difficulty.trim();
      return _matchesFilter(d, levelFilter);
    }

    bool modeOk(PlayableScenarioProblem p) {
      final timed = p.timedModeAvailable;
      if (normalize(modeFilter) == normalize('All Modes') || modeFilter.trim().isEmpty) return true;
      if (normalize(modeFilter) == normalize('Timed Available')) return timed;
      if (normalize(modeFilter) == normalize('Untimed')) return !timed;
      return true;
    }

    final filtered = playable.where((p) {
      final matches = matchesSearch(
        searchText: searchText,
        fields: [p.problemTitle, p.scenarioTitle, p.type, p.chip, p.difficulty, p.studentQuestion],
      );
      return matches && typeOk(p) && levelOk(p) && modeOk(p);
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
