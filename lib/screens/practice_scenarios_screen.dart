import 'dart:math';

import 'package:firepumpsim/models/scenario_models.dart';
import 'package:firepumpsim/models/scenario_pack.dart';
import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/services/scenario_pack_repository.dart';
import 'package:firepumpsim/services/scenario_pack_storage.dart';
import 'package:firepumpsim/services/scenario_repository.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PracticeScenariosScreen extends StatefulWidget {
  const PracticeScenariosScreen({super.key});

  @override
  State<PracticeScenariosScreen> createState() => _PracticeScenariosScreenState();
}

class _PracticeScenariosScreenState extends State<PracticeScenariosScreen> {
  final ScenarioRepository _repo = ScenarioRepository();
  final ScenarioPackStorage _packStorage = ScenarioPackStorage();

  final TextEditingController _searchController = TextEditingController();

  List<PracticeScenario> _allScenarios = const [];
  List<ScenarioPack> _unlockedPacks = const [];
  Map<String, List<PracticeScenario>> _scenariosByPackId = const {};
  bool _loading = true;

  /// Prevents rapid double-taps from pushing the same route twice.
  /// Duplicate route keys will crash Navigator with `!keyReservation.contains(key)`.
  bool _navInFlight = false;

  String _selectedType = 'All Categories';
  String _selectedLevel = 'All Levels';
  String _selectedMode = 'All Modes';
  String _selectedSort = 'Recommended';

  List<String> get typeOptions {
    final set = <String>{};
    for (final s in _allScenarios) {
      final t = s.type.trim();
      if (t.isNotEmpty) set.add(t);
    }
    final sorted = set.toList(growable: false)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return <String>['All Categories', ...sorted];
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      // Live updates on keystroke.
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final packsRepo = ScenarioPackRepository(storage: _packStorage);
      // Per app rules: Practice Scenarios should only use the Free Starter Pack.
      final unlocked = (await packsRepo.loadUnlockedPacks()).where((p) => p.packId == 'free_starter_pack').toList(growable: false);

      final byPack = <String, List<PracticeScenario>>{};
      final all = <PracticeScenario>[];
      for (final p in unlocked) {
        final scenarios = await _repo.loadScenariosFromFiles(p.scenarioFiles);
        byPack[p.packId] = scenarios;
        all.addAll(scenarios);
      }

      if (!mounted) return;
      setState(() {
        _unlockedPacks = unlocked;
        _scenariosByPackId = byPack;
        _allScenarios = all;
      });
    } catch (e) {
      debugPrint('Failed to load scenarios: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _activePickerFilterCount {
    var count = 0;
    if (_selectedType != 'All Categories') count++;
    if (_selectedLevel != 'All Levels') count++;
    if (_selectedMode != 'All Modes') count++;
    if (_selectedSort != 'Recommended') count++;
    return count;
  }

  int get _activeFilterCount {
    var count = _activePickerFilterCount;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  bool get _hasActiveFilters => _activeFilterCount > 0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxContentWidth = width >= 900 ? 980.0 : double.infinity;

    final filtered = _filterLocal(_allScenarios);
    final grouped = _groupFilteredByPack(filtered);

    Widget pageContent(Widget child) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      );
    }

    return Scaffold(
      backgroundColor: FirePumpSimColors.charcoal,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            pageContent(
              _CompactHeader(
                title: 'Practice Scenarios',
                subtitle: 'Choose a Driver Operator problem, search by topic, or start random practice.',
                // Locked behavior: Back from Scenario Picker always returns to Home.
                // (This screen may be opened from multiple entry points, so pop() can be ambiguous.)
                onBack: () => context.go(AppRoutes.home),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
              child: pageContent(
                _FilterCard(
                  activeFilterCount: _activePickerFilterCount,
                  searchController: _searchController,
                  onRandom: _startRandomFromCurrentFilters,
                  onOpenFilters: _openFilterSheet,
                  onClear: _clearAll,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: pageContent(_ResultsSummary(count: filtered.length, filtered: _hasActiveFilters, onClear: _clearAll)),
            ),
            Expanded(
              child: _loading
                  ? const _LoadingState()
                  : filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.lg),
                          child: pageContent(_EmptyState(onClear: _clearAll)),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                          children: [
                            pageContent(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [...grouped, const SizedBox(height: 90)],
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final textTheme = Theme.of(context).textTheme;

    var pendingType = typeOptions.contains(_selectedType) ? _selectedType : typeOptions.first;
    var pendingLevel = _selectedLevel;
    var pendingMode = _selectedMode;
    var pendingSort = _selectedSort;

    const levels = ['All Levels', 'Beginner', 'Intermediate', 'Advanced'];
    const modes = ['All Modes', 'Timed Available', 'Untimed'];
    const sorts = ['Recommended', 'A-Z', 'Beginner First', 'Advanced First'];

    void applyPending() {
      setState(() {
        _selectedType = pendingType;
        _selectedLevel = levels.contains(pendingLevel) ? pendingLevel : levels.first;
        _selectedMode = modes.contains(pendingMode) ? pendingMode : modes.first;
        _selectedSort = sorts.contains(pendingSort) ? pendingSort : sorts.first;
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md + bottomInset),
              child: Container(
                decoration: BoxDecoration(
                  color: FirePumpSimColors.charcoal2,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: FirePumpSimColors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.45)),
                              ),
                              child: const Icon(Icons.tune_rounded, color: FirePumpSimColors.red, size: 22),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Filter Practice',
                                    style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Choose what type of scenario to practice.',
                                    style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close, color: FirePumpSimColors.textMed),
                              style: IconButton.styleFrom(backgroundColor: FirePumpSimColors.charcoal3),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _DropdownField(
                          label: 'Category',
                          value: typeOptions.contains(pendingType) ? pendingType : typeOptions.first,
                          options: typeOptions,
                          onChanged: (v) => setSheetState(() => pendingType = v),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _DropdownField(
                          label: 'Level',
                          value: levels.contains(pendingLevel) ? pendingLevel : levels.first,
                          options: levels,
                          onChanged: (v) => setSheetState(() => pendingLevel = v),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _DropdownField(
                          label: 'Mode',
                          value: modes.contains(pendingMode) ? pendingMode : modes.first,
                          options: modes,
                          onChanged: (v) => setSheetState(() => pendingMode = v),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _DropdownField(
                          label: 'Sort',
                          value: sorts.contains(pendingSort) ? pendingSort : sorts.first,
                          options: sorts,
                          onChanged: (v) => setSheetState(() => pendingSort = v),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setSheetState(() {
                                    pendingType = typeOptions.first;
                                    pendingLevel = levels.first;
                                    pendingMode = modes.first;
                                    pendingSort = sorts.first;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: FirePumpSimColors.textHigh,
                                  side: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                                icon: const Icon(Icons.refresh_rounded, color: FirePumpSimColors.textHigh, size: 18),
                                label: Text('Clear', style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  applyPending();
                                  Navigator.of(sheetContext).pop();
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: FirePumpSimColors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                                icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                label: Text('Apply', style: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FilledButton.icon(
                          onPressed: () {
                            applyPending();
                            Navigator.of(sheetContext).pop();
                            Future<void>.microtask(_startRandomFromCurrentFilters);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: FirePumpSimColors.charcoal3,
                            foregroundColor: FirePumpSimColors.textHigh,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            side: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.90)),
                          ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                          icon: const Icon(Icons.shuffle_rounded, color: FirePumpSimColors.textHigh, size: 18),
                          label: Text('Apply & Start Random', style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  List<Widget> _groupFilteredByPack(List<PracticeScenario> filtered) {
    if (_unlockedPacks.isEmpty) return const <Widget>[];

    final byId = <String, List<PracticeScenario>>{};
    for (final p in _unlockedPacks) {
      byId[p.packId] = const <PracticeScenario>[];
    }

    // Create fast lookup: scenarioId -> packId based on original pack loading.
    final scenarioToPack = <String, String>{};
    for (final entry in _scenariosByPackId.entries) {
      for (final s in entry.value) {
        if (s.id.trim().isNotEmpty) scenarioToPack[s.id] = entry.key;
      }
    }

    for (final s in filtered) {
      final pid = scenarioToPack[s.id] ?? _unlockedPacks.first.packId;
      final existing = byId[pid] ?? const <PracticeScenario>[];
      byId[pid] = [...existing, s];
    }

    final out = <Widget>[];
    var firstSection = true;
    for (final pack in _unlockedPacks) {
      final items = byId[pack.packId] ?? const <PracticeScenario>[];
      if (items.isEmpty) continue;
      if (!firstSection) out.add(const SizedBox(height: AppSpacing.md));
      firstSection = false;

      out.add(_PackHeader(pack: pack, scenarioCount: items.length));
      out.add(const SizedBox(height: AppSpacing.sm));

      for (var i = 0; i < items.length; i++) {
        final s = items[i];
        final difficulty = (s.difficulty ?? 'Intermediate').trim().isEmpty ? 'Intermediate' : (s.difficulty ?? 'Intermediate').trim();
        final timed = s.timedModeAvailable ?? false;
        out.add(
          _ScenarioListCard(
            title: s.title,
            type: s.type,
            chip: s.chip,
            difficulty: difficulty,
            timedModeAvailable: timed,
            variations: s.variations.length,
            questionPreview: s.studentQuestion,
            imageAssetPath: s.image,
            onPreview: () => _openPreview(s),
            onStart: () => _startBaseScenario(s),
          ),
        );
        if (i != items.length - 1) out.add(const SizedBox(height: AppSpacing.sm));
      }
    }
    return out;
  }

  List<String> _buildTypeOptions(List<PracticeScenario> scenarios) {
    final set = <String>{};
    for (final s in scenarios) {
      final t = s.type.trim();
      if (t.isNotEmpty) set.add(t);
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All Categories', ...list];
  }

  List<PracticeScenario> _filterLocal(List<PracticeScenario> scenarios) {
    if (_loading) return const [];

    // Use the repository filtering logic so behavior stays consistent.
    // We call the advanced query method, but since it’s async, we replicate its logic locally
    // for a snappy, per-keystroke UI.
    final q = _searchController.text.trim();
    bool matchSearch(PracticeScenario s) {
      final d = (s.difficulty ?? 'Intermediate').trim();
      final diff = d.isEmpty ? 'Intermediate' : d;
      return ScenarioRepository.matchesSearch(
        searchText: q,
        fields: [s.title, s.type, s.chip, diff, s.studentQuestion],
      );
    }

    bool typeOk(PracticeScenario s) {
      if (_selectedType == 'All Categories' || _selectedType == 'All Types') return true;
      return ScenarioRepository.normalize(s.type) == ScenarioRepository.normalize(_selectedType);
    }

    bool levelOk(PracticeScenario s) {
      if (_selectedLevel == 'All Levels') return true;
      final d = (s.difficulty ?? 'Intermediate').trim();
      final diff = d.isEmpty ? 'Intermediate' : d;
      return ScenarioRepository.normalize(diff) == ScenarioRepository.normalize(_selectedLevel);
    }

    bool modeOk(PracticeScenario s) {
      final timed = s.timedModeAvailable ?? false;
      if (_selectedMode == 'All Modes') return true;
      if (_selectedMode == 'Timed Available') return timed;
      if (_selectedMode == 'Untimed') return !timed;
      return true;
    }

    final out = scenarios.where((s) => matchSearch(s) && typeOk(s) && levelOk(s) && modeOk(s)).toList(growable: true);

    if (_selectedSort == 'A-Z') {
      out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_selectedSort == 'Beginner First') {
      out.sort((a, b) {
        final ar = ScenarioRepository.difficultyRank((a.difficulty ?? 'Intermediate').trim());
        final br = ScenarioRepository.difficultyRank((b.difficulty ?? 'Intermediate').trim());
        final diff = ar.compareTo(br);
        return diff != 0 ? diff : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    } else if (_selectedSort == 'Advanced First') {
      out.sort((a, b) {
        final ar = ScenarioRepository.difficultyRank((a.difficulty ?? 'Intermediate').trim());
        final br = ScenarioRepository.difficultyRank((b.difficulty ?? 'Intermediate').trim());
        final diff = br.compareTo(ar);
        return diff != 0 ? diff : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }

    return out.toList(growable: false);
  }

  Future<void> _startRandomFromCurrentFilters() async {
    // Random should only come from the currently unlocked packs.
    final unlockedFiles = _unlockedPacks.expand((p) => p.scenarioFiles).toList(growable: false);
    final playablePool = await _repo.loadPlayableProblemsFromScenarioFiles(unlockedFiles);

    bool typeOk(PlayableScenarioProblem p) {
      if (_selectedType == 'All Categories' || _selectedType == 'All Types') return true;
      return ScenarioRepository.normalize(p.type) == ScenarioRepository.normalize(_selectedType);
    }

    bool levelOk(PlayableScenarioProblem p) {
      if (_selectedLevel == 'All Levels') return true;
      final d = p.difficulty.trim().isEmpty ? 'Intermediate' : p.difficulty.trim();
      return ScenarioRepository.normalize(d) == ScenarioRepository.normalize(_selectedLevel);
    }

    bool modeOk(PlayableScenarioProblem p) {
      if (_selectedMode == 'All Modes') return true;
      if (_selectedMode == 'Timed Available') return p.timedModeAvailable;
      if (_selectedMode == 'Untimed') return !p.timedModeAvailable;
      return true;
    }

    final q = _searchController.text.trim();
    final filtered = playablePool.where((p) {
      final matches = ScenarioRepository.matchesSearch(
        searchText: q,
        fields: [p.problemTitle, p.scenarioTitle, p.type, p.chip, p.difficulty, p.studentQuestion],
      );
      return matches && typeOk(p) && levelOk(p) && modeOk(p);
    }).toList(growable: false);

    final playable = filtered.isEmpty ? null : filtered[Random().nextInt(filtered.length)];

    if (!mounted) return;

    if (playable == null) {
      debugPrint('Random requested but no playable problems matched current search/filters.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No matching scenarios found.'),
          backgroundColor: FirePumpSimColors.charcoal2,
        ),
      );
      return;
    }
    await _goToPlayer(playable.problemId);
  }

  void _clearAll() {
    _searchController.clear();
    setState(() {
      _selectedType = 'All Categories';
      _selectedLevel = 'All Levels';
      _selectedMode = 'All Modes';
      _selectedSort = 'Recommended';
    });
  }

  Future<void> _startBaseScenario(PracticeScenario scenario) async {
    // Practice Scenarios are loaded from unlocked pack files. Start the selected
    // scenario from that same unlocked-pack pool instead of relying on the
    // global scenario manifest. This prevents starter-pack scenarios from
    // appearing in the picker but failing to open in the player.
    final unlockedFiles = _unlockedPacks.expand((p) => p.scenarioFiles).toList(growable: false);
    final playablePool = await _repo.loadPlayableProblemsFromScenarioFiles(unlockedFiles);
    var matches = playablePool.where((p) => p.scenarioId == scenario.id).toList(growable: false);

    // Fallback for older/current scenarios that may not be in a pack yet.
    if (matches.isEmpty) {
      final fallback = await _repo.startBaseProblem(scenario.id);
      if (fallback != null) matches = <PlayableScenarioProblem>[fallback];
    }

    if (!mounted) return;
    if (matches.isEmpty) {
      debugPrint('Failed to start base scenario. scenarioId=${scenario.id} title=${scenario.title}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to start this scenario. Check the pack JSON and scenario-packs.json.'),
          backgroundColor: FirePumpSimColors.charcoal2,
        ),
      );
      return;
    }

    // Prefer the first real problem from problems[].
    final playable = matches.firstWhere((p) => p.isVariation, orElse: () => matches.first);
    await _goToPlayer(playable.problemId);
  }

  Future<void> _goToPlayer(String problemId) async {
    if (problemId.trim().isEmpty) {
      debugPrint('Attempted to navigate to Scenario Player with empty problemId.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This scenario is missing a problemId.'),
          backgroundColor: FirePumpSimColors.charcoal2,
        ),
      );
      return;
    }

    if (_navInFlight) {
      debugPrint('Navigation ignored: Scenario Player push already in flight.');
      return;
    }
    _navInFlight = true;

    debugPrint('Navigating to Scenario Player. problemId=$problemId');
    try {
      await context.push('${AppRoutes.scenarioPlayer}?problemId=${Uri.encodeComponent(problemId)}');
    } catch (e) {
      debugPrint('Failed to navigate to Scenario Player: $e');
    } finally {
      _navInFlight = false;
    }
  }

  Future<void> _openPreview(PracticeScenario scenario) async {
    final textTheme = Theme.of(context).textTheme;
    final difficulty = (scenario.difficulty ?? 'Intermediate').trim().isEmpty
        ? 'Intermediate'
        : (scenario.difficulty ?? 'Intermediate').trim();

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: Container(
            decoration: BoxDecoration(
              color: FirePumpSimColors.charcoal2,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            scenario.title,
                            style: textTheme.titleLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.close, color: FirePumpSimColors.textMed),
                          style: IconButton.styleFrom(backgroundColor: FirePumpSimColors.charcoal3.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ScenePreviewImage(assetPath: scenario.scene),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(label: scenario.type, icon: Icons.category),
                        _MetaChip(label: difficulty, icon: Icons.trending_up),
                        _MetaChip(
                          label: '${scenario.variations.isEmpty ? 1 : scenario.variations.length} problem${(scenario.variations.isEmpty ? 1 : scenario.variations.length) == 1 ? '' : 's'}',
                          icon: Icons.dashboard,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      scenario.studentQuestion,
                      style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.5),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _PrimaryActionButton(
                            icon: Icons.play_arrow,
                            label: scenario.variations.isEmpty ? 'Start Scenario' : 'Start First Problem',
                            onPressed: () async {
                              final playable = await _repo.startBaseProblem(scenario.id);
                              if (!context.mounted) return;
                              if (playable == null) {
                                debugPrint('Failed to start base scenario from preview. scenarioId=${scenario.id}');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Unable to start this scenario.'),
                                    backgroundColor: FirePumpSimColors.charcoal2,
                                  ),
                                );
                                return;
                              }
                              context.pop();
                               await _goToPlayer(playable.problemId);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _SecondaryActionButton(
                            icon: Icons.shuffle,
                            label: 'Start Random Problem',
                            enabled: scenario.variations.length > 1,
                            onPressed: () async {
                              final playable = await _repo.startRandomVariation(scenario.id);
                              if (!context.mounted) return;
                              if (playable == null) {
                                debugPrint('Failed to start random variation from preview. scenarioId=${scenario.id}');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('No additional problems available for this scenario.'),
                                    backgroundColor: FirePumpSimColors.charcoal2,
                                  ),
                                );
                                return;
                              }
                              context.pop();
                               await _goToPlayer(playable.problemId);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.title, required this.subtitle, required this.onBack});

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
        decoration: BoxDecoration(
          color: FirePumpSimColors.charcoal2,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: FirePumpSimColors.textHigh),
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: FirePumpSimColors.charcoal3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
                padding: const EdgeInsets.all(10),
                minimumSize: const Size(44, 44),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: FirePumpSimColors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.45)),
              ),
              child: const Icon(Icons.local_fire_department_rounded, color: FirePumpSimColors.red, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900, height: 1.05),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: FirePumpSimColors.charcoal3,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.75)),
                        ),
                        child: Text(
                          'Starter Pack',
                          style: textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.35, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w700),
      cursorColor: FirePumpSimColors.red,
      decoration: InputDecoration(
        hintText: 'Search title, type, or question…',
        hintStyle: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: FirePumpSimColors.charcoal2,
        prefixIcon: const Icon(Icons.search, color: FirePumpSimColors.textMed),
        suffixIcon: controller.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close, color: FirePumpSimColors.textMed),
                style: IconButton.styleFrom(backgroundColor: Colors.transparent),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: FirePumpSimColors.red.withValues(alpha: 0.95), width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _RandomButton extends StatelessWidget {
  const _RandomButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: FirePumpSimColors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
      icon: const Icon(Icons.shuffle, size: 18, color: Colors.white),
      label: Text('Random', style: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.activeFilterCount,
    required this.searchController,
    required this.onRandom,
    required this.onOpenFilters,
    required this.onClear,
  });

  final int activeFilterCount;
  final TextEditingController searchController;
  final VoidCallback onRandom;
  final VoidCallback onOpenFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.80)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.manage_search_rounded, color: FirePumpSimColors.red, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Find a scenario',
                        style: textTheme.titleSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (activeFilterCount > 0)
                      TextButton(
                        onPressed: onClear,
                        style: TextButton.styleFrom(
                          foregroundColor: FirePumpSimColors.textHigh,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                        child: Text('Reset', style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackSearch = constraints.maxWidth < 620;
                    final actionRow = Row(
                      children: [
                        Expanded(child: _RandomButton(onPressed: onRandom)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _FilterSheetButton(
                            activeFilterCount: activeFilterCount,
                            onPressed: onOpenFilters,
                          ),
                        ),
                      ],
                    );

                    if (stackSearch) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SearchField(controller: searchController),
                          const SizedBox(height: AppSpacing.sm),
                          actionRow,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: _SearchField(controller: searchController)),
                        const SizedBox(width: AppSpacing.sm),
                        SizedBox(width: 150, child: _RandomButton(onPressed: onRandom)),
                        const SizedBox(width: AppSpacing.sm),
                        SizedBox(
                          width: activeFilterCount > 0 ? 155 : 130,
                          child: _FilterSheetButton(activeFilterCount: activeFilterCount, onPressed: onOpenFilters),
                        ),
                      ],
                    );
                  },
                ),
                if (activeFilterCount > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$activeFilterCount active filter${activeFilterCount == 1 ? '' : 's'} applied',
                    style: textTheme.labelMedium?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w800),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSheetButton extends StatelessWidget {
  const _FilterSheetButton({required this.activeFilterCount, required this.onPressed});

  final int activeFilterCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = activeFilterCount > 0 ? 'Filter ($activeFilterCount)' : 'Filter';
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: FirePumpSimColors.textHigh,
        side: BorderSide(color: activeFilterCount > 0 ? FirePumpSimColors.red.withValues(alpha: 0.8) : FirePumpSimColors.steel.withValues(alpha: 0.9)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: activeFilterCount > 0 ? FirePumpSimColors.red.withValues(alpha: 0.10) : FirePumpSimColors.charcoal3,
      ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
      icon: const Icon(Icons.tune_rounded, size: 18, color: FirePumpSimColors.textHigh),
      label: Text(label, style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({required this.label, required this.value, required this.options, required this.onChanged});

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DropdownButtonFormField<String>(
      value: options.contains(value) ? value : options.first,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, color: FirePumpSimColors.textMed),
      dropdownColor: FirePumpSimColors.charcoal2,
      style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w900),
        filled: true,
        fillColor: FirePumpSimColors.charcoal3,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        constraints: const BoxConstraints(minHeight: 52),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: FirePumpSimColors.red.withValues(alpha: 0.95), width: 1.2),
        ),
      ),
      items: [
        for (final o in options)
          DropdownMenuItem<String>(
            value: o,
            child: Text(o, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
    );
  }
}

class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({required this.count, required this.filtered, required this.onClear});

  final int count;
  final bool filtered;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(Icons.view_list_rounded, size: 16, color: FirePumpSimColors.textMed.withValues(alpha: 0.85)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            filtered ? '$count matching scenarios' : '$count scenarios ready',
            style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w800),
          ),
        ),
        if (filtered)
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: FirePumpSimColors.textHigh,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
            child: Text('Reset', style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.search_off, color: FirePumpSimColors.textMed, size: 30),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No scenarios match your filters.',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Try widening your search or clearing filters.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onClear,
            style: FilledButton.styleFrom(
              backgroundColor: FirePumpSimColors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
            child: Text('Clear Filters', style: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _ScenarioListCard extends StatelessWidget {
  const _ScenarioListCard({
    required this.title,
    required this.type,
    required this.chip,
    required this.difficulty,
    required this.timedModeAvailable,
    required this.variations,
    required this.questionPreview,
    required this.imageAssetPath,
    required this.onPreview,
    required this.onStart,
  });

  final String title;
  final String type;
  final String chip;
  final String difficulty;
  final bool timedModeAvailable;
  final int variations;
  final String questionPreview;
  final String imageAssetPath;
  final VoidCallback onPreview;
  final VoidCallback onStart;

  String get _problemCountLabel {
    final count = variations <= 0 ? 1 : variations;
    return '$count problem${count == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.80)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPreview,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.white.withValues(alpha: 0.035),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ScenarioThumbnail(assetPath: imageAssetPath, size: compact ? 78 : 96),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: _ScenarioCardBody(card: this)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (chip.trim().isNotEmpty) _Badge(label: chip, icon: Icons.local_fire_department, accent: FirePumpSimColors.red),
                          if (type.trim().isNotEmpty) _Badge(label: type, icon: Icons.category, accent: FirePumpSimColors.textMed),
                          _Badge(label: difficulty, icon: Icons.trending_up, accent: FirePumpSimColors.textMed),
                          _Badge(
                            label: timedModeAvailable ? 'Timed mode' : 'Untimed',
                            icon: timedModeAvailable ? Icons.timer : Icons.timer_off,
                            accent: FirePumpSimColors.textMed,
                          ),
                          _Badge(label: _problemCountLabel, icon: Icons.layers, accent: FirePumpSimColors.textMed),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ScenarioCardActions(onStart: onStart, onPreview: onPreview),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenarioCardBody extends StatelessWidget {
  const _ScenarioCardBody({required this.card});

  final _ScenarioListCard card;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (card.type.trim().isNotEmpty) ...[
          Text(
            card.type.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: FirePumpSimColors.redSoft,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          card.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900, height: 1.16),
        ),
        const SizedBox(height: 8),
        Text(
          card.questionPreview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.4, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ScenarioCardActions extends StatelessWidget {
  const _ScenarioCardActions({required this.onStart, required this.onPreview});

  final VoidCallback onStart;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPreview,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              side: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.9)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              foregroundColor: FirePumpSimColors.textHigh,
              backgroundColor: FirePumpSimColors.charcoal3.withValues(alpha: 0.55),
            ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
            icon: const Icon(Icons.visibility_rounded, size: 18, color: FirePumpSimColors.textHigh),
            label: Text('Details', style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton.icon(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              backgroundColor: FirePumpSimColors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
            icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
            label: Text('Start', style: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, required this.accent});

  final String label;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioThumbnail extends StatelessWidget {
  const _ScenarioThumbnail({required this.assetPath, this.size = 92});

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (assetPath.trim().isEmpty) {
      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
          color: FirePumpSimColors.charcoal3,
        ),
        child: const Center(child: Icon(Icons.image_not_supported, color: FirePumpSimColors.textMed)),
      );
    }
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
        color: FirePumpSimColors.charcoal3,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(FirePumpSimColors.charcoal.withValues(alpha: 0.28), BlendMode.darken),
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Scenario thumbnail failed to load ($assetPath): $error');
              return const Center(child: Icon(Icons.image_not_supported, color: FirePumpSimColors.textMed));
            },
          ),
        ),
      ),
    );
  }
}

class _ScenePreviewImage extends StatelessWidget {
  const _ScenePreviewImage({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    if (assetPath.trim().isEmpty) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
          color: FirePumpSimColors.charcoal3,
        ),
        child: const Center(child: Icon(Icons.image_not_supported, color: FirePumpSimColors.textMed)),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
          color: FirePumpSimColors.charcoal3,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(FirePumpSimColors.charcoal.withValues(alpha: 0.55), BlendMode.darken),
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Scenario scene image failed to load ($assetPath): $error');
                return const Center(child: Icon(Icons.image_not_supported, color: FirePumpSimColors.textMed));
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.icon, this.accent});

  final String label;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final a = accent ?? FirePumpSimColors.textMed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: a.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: a),
          const SizedBox(width: 6),
          Text(label, style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: FirePumpSimColors.textMed),
        const SizedBox(width: 6),
        Text(label, style: textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: FirePumpSimColors.red,
        foregroundColor: Colors.white,
        padding: dense
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(label, style: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        side: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: enabled ? 0.9 : 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        foregroundColor: FirePumpSimColors.textHigh,
        backgroundColor: FirePumpSimColors.charcoal2,
      ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
      icon: Icon(icon, size: 18, color: enabled ? FirePumpSimColors.textHigh : FirePumpSimColors.textMed),
      label: Text(
        label,
        style: textTheme.labelLarge?.copyWith(
          color: enabled ? FirePumpSimColors.textHigh : FirePumpSimColors.textMed,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: FirePumpSimColors.red),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Loading scenarios…', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed)),
          ],
        ),
      ),
    );
  }
}

class _PackHeader extends StatelessWidget {
  const _PackHeader({required this.pack, required this.scenarioCount});

  final ScenarioPack pack;
  final int scenarioCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = pack.description.trim().isNotEmpty ? pack.description : '${pack.difficulty} • $scenarioCount scenarios';
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: FirePumpSimColors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.35)),
            ),
            child: const Center(child: Icon(Icons.auto_stories, color: FirePumpSimColors.red, size: 20)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pack.title, style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: FirePumpSimColors.charcoal3,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.65)),
            ),
            child: Text('$scenarioCount', style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
