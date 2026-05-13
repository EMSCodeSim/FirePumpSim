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
  _ScenarioAssetResolver? _assetResolver;

  static const String scenariosDir = 'assets/scenarios/';

  /// Some scenario indexes (or older generated manifests) may contain URL-encoded
  /// asset keys like `assets/scenarios/My%20Scenario.json`.
  ///
  /// On Flutter Web, those get encoded again when fetched, producing
  /// `...My%2520Scenario.json` and a 404.
  ///
  /// Normalize those inputs back to the real asset key.
  static String _sanitizeAssetKey(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;

    // Only attempt decode when it looks encoded.
    if (!s.contains('%')) return s;

    // Flutter Web asset fetching will URL-encode the provided key.
    // If the key itself already contains encoded sequences (e.g. "%20"),
    // the browser fetch can encode again ("%2520"), causing 404s.
    //
    // Some inputs can even be double-encoded already. Decode a few times until
    // stable (or decoding fails).
    for (var i = 0; i < 3; i++) {
      if (!s.contains('%')) break;
      try {
        final decoded = Uri.decodeFull(s);
        if (decoded == s) break;
        s = decoded;
      } catch (_) {
        break;
      }
    }
    return s;
  }

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

  Future<List<PracticeScenario>> loadScenarios({bool manifestOnly = false}) async {
    // Only cache the default (non-manifestOnly) load to avoid confusing callers
    // that need different source sets.
    if (!manifestOnly && _cachedScenarios != null) return _cachedScenarios!;

    try {
      _assetResolver ??= await _ScenarioAssetResolver.create();

      // Prefer our explicit scenario manifest (keeps a stable recommended order),
      // but gracefully fall back to enumerating bundled assets via AssetManifest.
      // This prevents regressions when new scenario packs are added without
      // updating scenario_manifest.json.
      final files = await _loadScenarioFileList(manifestOnly: manifestOnly);

      final scenarios = <PracticeScenario>[];
      for (final file in files) {
        try {
          final jsonStr = await rootBundle.loadString(file);
          final obj = jsonDecode(jsonStr);
          if (obj is Map) {
            // Support both normal single-scenario JSON and pack/container JSON
            // with a top-level `scenarios: []` array.
            final map = Map<String, dynamic>.from(obj);
            final expanded = _expandScenarioContainer(map, containerAssetPath: file);
            scenarios.addAll(expanded);
          }
        } catch (e) {
          debugPrint('Failed to load scenario file $file: $e');
        }
      }

      if (!manifestOnly) _cachedScenarios = scenarios;
      return scenarios;
    } catch (e) {
      debugPrint('Failed to load scenarios: $e');
      if (!manifestOnly) _cachedScenarios = const [];
      return const [];
    }
  }

  /// Loads scenarios from an explicit list of filenames or asset paths.
  ///
  /// Accepted inputs:
  /// - "foo.json" (assumes `assets/scenarios/foo.json`)
  /// - "assets/scenarios/foo.json" (used as-is)
  Future<List<PracticeScenario>> loadScenariosFromFiles(List<String> files) async {
    try {
      _assetResolver ??= await _ScenarioAssetResolver.create();
      final assetPaths = files
          .map((f) => f.toString().trim())
          .where((f) => f.isNotEmpty)
          .map(_sanitizeAssetKey)
          .map(_toScenarioAssetPath)
          .toList(growable: false);

      final scenarios = <PracticeScenario>[];
      for (final assetPath in assetPaths) {
        try {
          final jsonStr = await rootBundle.loadString(assetPath);
          final obj = jsonDecode(jsonStr);
          if (obj is Map) {
            final map = Map<String, dynamic>.from(obj);
            final expanded = _expandScenarioContainer(map, containerAssetPath: assetPath);
            scenarios.addAll(expanded);
          }
        } catch (e) {
          debugPrint('Failed to load scenario file $assetPath: $e');
        }
      }
      return scenarios;
    } catch (e) {
      debugPrint('Failed to load scenarios from explicit file list: $e');
      return const <PracticeScenario>[];
    }
  }

  /// Supports both:
  /// 1) A normal scenario JSON that maps directly to [PracticeScenario].
  /// 2) A "pack JSON" that contains `scenarios: []` where each entry is a
  ///    scenario object.
  ///
  /// This enables packs like:
  /// `assets/scenarios/packs/free_starter_pack.json`
  /// without requiring each scenario to live in its own JSON file.
  List<PracticeScenario> _expandScenarioContainer(Map<String, dynamic> json, {required String containerAssetPath}) {
    try {
      final rawScenarios = json['scenarios'];
      if (rawScenarios is List) {
        final packId = (json['packId'] ?? '').toString().trim();
        final idPrefix = packId.isNotEmpty ? packId : _basenameNoExt(containerAssetPath);
        final seenIds = <String>{};

        final out = <PracticeScenario>[];
        for (var i = 0; i < rawScenarios.length; i++) {
          final raw = rawScenarios[i];
          if (raw is! Map) continue;

          final child = Map<String, dynamic>.from(raw);
          // Ensure each embedded scenario has a stable, non-empty ID.
          final existingId = (child['id'] ?? child['scenarioId'] ?? '').toString().trim();
          var id = existingId;
          if (id.isEmpty) id = '${idPrefix}__s$i';
          if (seenIds.contains(id)) id = '${idPrefix}__s${i}_${seenIds.length}';
          seenIds.add(id);
          child['id'] = id;

          _assetResolver?.rewriteScenarioImageFields(child, scenarioJsonAssetPath: containerAssetPath);
          final scenario = PracticeScenario.fromJson(child);
          if (scenario.id.trim().isNotEmpty && scenario.title.trim().isNotEmpty) out.add(scenario);
        }
        return out;
      }

      // Normal single-scenario file.
      _assetResolver?.rewriteScenarioImageFields(json, scenarioJsonAssetPath: containerAssetPath);
      final scenario = PracticeScenario.fromJson(json);
      if (scenario.id.trim().isNotEmpty && scenario.title.trim().isNotEmpty) return <PracticeScenario>[scenario];
      return const <PracticeScenario>[];
    } catch (e) {
      debugPrint('Failed to parse scenario container $containerAssetPath: $e');
      return const <PracticeScenario>[];
    }
  }

  static String _basenameNoExt(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';
    final i = trimmed.lastIndexOf('/');
    final base = i >= 0 ? trimmed.substring(i + 1) : trimmed;
    final dot = base.toLowerCase().lastIndexOf('.json');
    return dot > 0 ? base.substring(0, dot) : base;
  }

  Future<List<PlayableScenarioProblem>> loadPlayableProblemsFromScenarioFiles(List<String> files) async {
    final scenarios = await loadScenariosFromFiles(files);
    return _flattenPlayableFromScenarios(scenarios);
  }

  List<PlayableScenarioProblem> _flattenPlayableFromScenarios(List<PracticeScenario> scenarios) {
    final playable = <PlayableScenarioProblem>[];
    for (final s in scenarios) {
      final baseDifficulty = (s.difficulty ?? 'Intermediate').trim();
      final baseTimed = s.timedModeAvailable ?? false;

      if (s.variations.isEmpty) {
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
            variationCount: 1,
          ),
        );
      }

      for (var i = 0; i < s.variations.length; i++) {
        final v = s.variations[i];
        final variationDifficulty = (v.difficulty ?? s.difficulty ?? 'Intermediate').trim();
        final variationTimed = v.timedModeAvailable ?? s.timedModeAvailable ?? false;
        final variationId = v.id.trim().isNotEmpty ? v.id.trim() : '${s.id}__v$i';
        final variationTitle = v.title.trim().isNotEmpty ? v.title.trim() : '${s.title} (Problem ${i + 1})';
        final variationQuestion = v.studentQuestion.trim().isNotEmpty ? v.studentQuestion : s.studentQuestion;
        final variationDetails = v.details.isNotEmpty ? v.details : s.details;
        final variationOverlays = v.overlays.isNotEmpty ? v.overlays : s.overlays;
        final variationAnswers = v.answers.isNotEmpty ? v.answers : s.answers;
        final variationFormula = v.formulaBreakdown.isNotEmpty ? v.formulaBreakdown : s.formulaBreakdown;
        final variationExplanation = v.instructorExplanation.trim().isNotEmpty ? v.instructorExplanation : s.instructorExplanation;
        final variationMistake = v.explainMistake.trim().isNotEmpty ? v.explainMistake : s.explainMistake;
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
            explainMistake: variationMistake,
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
    return playable;
  }

  static String _toScenarioAssetPath(String fileOrPath) {
    final f = fileOrPath.trim();
    if (f.toLowerCase().startsWith('assets/')) return f;
    return '$scenariosDir$f';
  }

  Future<List<String>> _loadScenarioFileList({required bool manifestOnly}) async {
    // 1) Try explicit manifest first.
    final ordered = <String>[];

    void addUnique(Iterable<String> rawFiles) {
      for (final raw in rawFiles) {
        final cleaned = _sanitizeAssetKey(raw.toString()).trim();
        if (cleaned.isEmpty) continue;
        final assetPath = _toScenarioAssetPath(cleaned);
        if (!ordered.contains(assetPath)) ordered.add(assetPath);
      }
    }

    try {
      final manifestStr = await rootBundle.loadString('assets/scenarios/scenario_manifest.json');
      final decoded = jsonDecode(manifestStr);
      final files = (decoded is Map && decoded['files'] is List) ? List<String>.from(decoded['files'] as List) : <String>[];
      addUnique(files);

      // If a caller explicitly requests manifest-only loading, respect it.
      if (manifestOnly && ordered.isNotEmpty) return ordered;

      // If a manifest exists, keep its ordering as "Recommended", but also
      // include any additional scenario JSON files that are bundled but not
      // listed yet. This prevents the common "only the manifest scenarios load"
      // issue when new packs are added.
      if (!manifestOnly && ordered.isNotEmpty) {
        final extra = await _enumerateAllScenarioJsonAssets();
        if (extra.isNotEmpty) {
          final orderedSet = ordered.toSet();
          final missing = extra.where((p) => !orderedSet.contains(p)).toList(growable: false);
          if (missing.isNotEmpty) {
            final sortedMissing = [...missing]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            addUnique(sortedMissing);
          }
        }
      }
    } catch (e) {
      // Ignore and fall back to pack index / AssetManifest.
      debugPrint('Scenario manifest not usable; trying pack index / AssetManifest: $e');
    }

    // 2) Always include scenario files referenced by scenario-packs.json.
    //
    // This fixes the starter-pack issue where Practice Scenarios can load the
    // pack from scenario-packs.json, but Scenario Player later searches only the
    // scenario_manifest/AssetManifest list and cannot find the selected problem.
    // It also keeps pack JSON working in environments where AssetManifest.json
    // is unavailable or incomplete.
    try {
      final packFiles = await _loadScenarioFilesFromPackIndex();
      addUnique(packFiles);
    } catch (e) {
      debugPrint('Scenario pack index not usable while loading scenarios: $e');
    }

    // When a caller explicitly requests manifest-only loading, respect the
    // curated manifest + pack index list.
    if (manifestOnly && ordered.isNotEmpty) return ordered;

    // 3) If possible, append any remaining bundled scenario JSON files from
    // AssetManifest. This keeps older/current bundled scenarios eligible without
    // requiring every file to be manually listed.
    if (!manifestOnly) {
      try {
        final extra = await _enumerateAllScenarioJsonAssets();
        final sortedExtra = [...extra]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        addUnique(sortedExtra);
      } catch (e) {
        debugPrint('Failed to enumerate scenario assets via AssetManifest: $e');
      }
    }

    return ordered;
  }

  Future<List<String>> _loadScenarioFilesFromPackIndex() async {
    final packStr = await rootBundle.loadString('assets/scenarios/scenario-packs.json');
    final decoded = jsonDecode(packStr);
    if (decoded is! Map) return const <String>[];
    final packs = decoded['packs'];
    if (packs is! List) return const <String>[];

    final files = <String>[];
    for (final rawPack in packs) {
      if (rawPack is! Map) continue;
      final pack = Map<String, dynamic>.from(rawPack);
      final rawFiles = pack['scenarioFiles'];
      if (rawFiles is! List) continue;
      for (final rawFile in rawFiles) {
        final s = rawFile.toString().trim();
        if (s.isNotEmpty) files.add(s);
      }
    }
    return files;
  }

  /// Public wrapper used by Daily Challenge and other flows that need a raw list
  /// of scenario JSON assets included in the bundle.
  Future<List<String>> enumerateScenarioJsonAssets() => _enumerateAllScenarioJsonAssets();

  Future<List<String>> _enumerateAllScenarioJsonAssets() async {
    final assetManifestStr = await rootBundle.loadString('AssetManifest.json');
    final decoded = jsonDecode(assetManifestStr);
    if (decoded is! Map) return const [];

    final keys = decoded.keys.map((e) => e.toString()).toList(growable: false);
    final scenarioJsons = keys
        .where((k) => k.startsWith('assets/scenarios/'))
        .where((k) => k.toLowerCase().endsWith('.json'))
        .where((k) => !k.toLowerCase().endsWith('/scenario_manifest.json'))
        .map(_sanitizeAssetKey)
        .toList(growable: false);
    return scenarioJsons;
  }

  Future<List<PlayableScenarioProblem>> loadPlayableProblems({bool manifestOnly = false}) async {
    if (!manifestOnly && _cachedPlayable != null) return _cachedPlayable!;
    final scenarios = await loadScenarios(manifestOnly: manifestOnly);

    final playable = _flattenPlayableFromScenarios(scenarios);
    if (!manifestOnly) _cachedPlayable = playable;
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
    final matches = playable.where((p) => p.scenarioId == scenarioId).toList(growable: false);
    if (matches.isEmpty) return null;

    // Prefer a true base problem for legacy one-problem packs, otherwise open
    // the first real standalone problem from `problems[]` / `variations[]`.
    for (final p in matches) {
      if (!p.isVariation) return p;
    }
    return matches.first;
  }

  Future<PlayableScenarioProblem?> startRandomVariation(String scenarioId) async {
    final playable = await loadPlayableProblems();
    final variations = playable.where((p) => p.scenarioId == scenarioId && p.isVariation).toList(growable: false);
    if (variations.isEmpty) return null;
    return variations[_random.nextInt(variations.length)];
  }
}

/// Resolves scenario JSON image references to actual Flutter asset keys.
///
/// Why: Scenario packs often store only the image filename (or a relative path)
/// in the JSON (e.g. "car_fire.png"). Our UI widgets expect a valid
/// `assets/...` path for `Image.asset()`.
class _ScenarioAssetResolver {
  _ScenarioAssetResolver._(this._assetsByBasenameLower);

  final Map<String, String> _assetsByBasenameLower;

  static Future<_ScenarioAssetResolver> create() async {
    try {
      final manifestStr = await rootBundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(manifestStr);
      if (decoded is! Map) return _ScenarioAssetResolver._(const {});

      final keys = decoded.keys.map((e) => e.toString()).toList(growable: false);

      // Prefer `assets/images/` first because that’s where scenarios currently live.
      int score(String p) {
        final lower = p.toLowerCase();
        if (lower.startsWith('assets/images/')) return 0;
        if (lower.startsWith('assets/scenarios/')) return 1;
        if (lower.startsWith('assets/')) return 2;
        return 3;
      }

      final byBase = <String, String>{};
      for (final k in keys) {
        final base = _basename(k).toLowerCase();
        if (base.isEmpty) continue;
        final existing = byBase[base];
        if (existing == null || score(k) < score(existing)) byBase[base] = k;
      }
      return _ScenarioAssetResolver._(byBase);
    } catch (e) {
      debugPrint('Failed to build AssetManifest resolver: $e');
      return _ScenarioAssetResolver._(const {});
    }
  }

  static String _basename(String p) {
    final s = p.trim();
    if (s.isEmpty) return '';
    final i = s.lastIndexOf('/');
    return i >= 0 ? s.substring(i + 1) : s;
  }

  static bool _hasImageExt(String s) {
    final lower = s.toLowerCase();
    return lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp') || lower.endsWith('.gif');
  }

  String _resolve(String raw) {
    final trimmed = ScenarioRepository._sanitizeAssetKey(raw).trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.toLowerCase().startsWith('assets/')) return trimmed;
    if (!_hasImageExt(trimmed)) return trimmed;

    final baseLower = _basename(trimmed).toLowerCase();
    final fromManifest = _assetsByBasenameLower[baseLower];
    if (fromManifest != null) return fromManifest;

    // Fallback for packs that assume assets/images.
    return 'assets/images/$trimmed';
  }

  void rewriteScenarioImageFields(Map<String, dynamic> json, {required String scenarioJsonAssetPath}) {
    void rewriteKey(String key) {
      final v = json[key];
      if (v is! String) return;
      final resolved = _resolve(v);
      if (resolved != v) json[key] = resolved;
      if (resolved.isEmpty) {
        debugPrint('Scenario image not resolved ($key) for $scenarioJsonAssetPath: "$v"');
      }
    }

    rewriteKey('image');
    rewriteKey('scene');
  }
}
