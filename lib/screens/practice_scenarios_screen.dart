import 'package:firepumpsim/models/scenario_models.dart';
import 'package:firepumpsim/nav.dart';
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

  /// Prevents rapid double-taps from pushing the same route twice.
  /// Duplicate route keys will crash Navigator with `!keyReservation.contains(key)`.
  bool _navInFlight = false;

  static const List<String> _typeFilters = [
    'All',
    'Attack Line',
    'Standpipe',
    'Wye',
    'Relay',
    'Master Stream',
    'Nozzle Reaction',
    'Rural Water',
    'Troubleshooting',
  ];

  static const List<String> _difficultyFilters = ['All', 'Beginner', 'Intermediate', 'Advanced'];

  String _selectedType = 'All';
  String _selectedDifficulty = 'All';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _TopBar(onBack: () => context.pop())),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                child: _TopActions(
                  onPick: () => _scrollToList(context),
                  onRandom: _startRandom,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                child: _FilterPanel(
                  selectedType: _selectedType,
                  selectedDifficulty: _selectedDifficulty,
                  typeFilters: _typeFilters,
                  difficultyFilters: _difficultyFilters,
                  onTypeChanged: (v) => setState(() => _selectedType = v),
                  onDifficultyChanged: (v) => setState(() => _selectedDifficulty = v),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
              sliver: FutureBuilder<List<PracticeScenario>>(
                future: _repo.queryScenarios(typeFilter: _selectedType, difficultyFilter: _selectedDifficulty),
                builder: (context, snapshot) {
                  final scenarios = snapshot.data ?? const <PracticeScenario>[];

                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SliverToBoxAdapter(child: _LoadingState());
                  }

                  if (scenarios.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: Text(
                          'No scenarios found for this category.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.5),
                        ),
                      ),
                    );
                  }

                  return SliverList.separated(
                    itemCount: scenarios.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final s = scenarios[index];
                      final difficulty = (s.difficulty ?? 'Intermediate').trim().isEmpty ? 'Intermediate' : (s.difficulty ?? 'Intermediate').trim();
                      final timed = s.timedModeAvailable ?? false;
                      return _ScenarioCard(
                        title: s.title,
                        type: s.type,
                        chip: s.chip,
                        difficulty: difficulty,
                        timedModeAvailable: timed,
                        variations: s.variations.length,
                        imageAssetPath: s.image,
                        onTap: () => _openPreview(s),
                        onStart: () => _startBaseScenario(s),
                      );
                    },
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }

  void _scrollToList(BuildContext context) {
    // Kept intentionally simple: on real devices the user is already near the list.
    // If needed later, we can add a ScrollController + animateTo.
    debugPrint('Pick Scenario tapped');
  }

  Future<void> _startRandom() async {
    final playable = await _repo.randomPlayable(typeFilter: _selectedType, difficultyFilter: _selectedDifficulty);
    if (!mounted) return;
    if (playable == null) {
      debugPrint('Random scenario requested but no playable problems matched filters.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No scenarios available for these filters.'),
          backgroundColor: FirePumpSimColors.charcoal2,
        ),
      );
      return;
    }
    await _goToPlayer(playable.problemId);
  }

  Future<void> _startBaseScenario(PracticeScenario scenario) async {
    final playable = await _repo.startBaseProblem(scenario.id);
    if (!mounted) return;
    if (playable == null) {
      debugPrint('Failed to start base scenario. scenarioId=${scenario.id} title=${scenario.title}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to start this scenario. Check the scenario manifest/JSON.'),
          backgroundColor: FirePumpSimColors.charcoal2,
        ),
      );
      return;
    }
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
                          label: '${1 + scenario.variations.length} problem${scenario.variations.length == 0 ? '' : 's'}',
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
                            label: 'Start Base Scenario',
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
                            label: 'Start Random Variation',
                            enabled: scenario.variations.isNotEmpty,
                            onPressed: () async {
                              final playable = await _repo.startRandomVariation(scenario.id);
                              if (!context.mounted) return;
                              if (playable == null) {
                                debugPrint('Failed to start random variation from preview. scenarioId=${scenario.id}');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('No variations available for this scenario.'),
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: FirePumpSimColors.textHigh),
            style: IconButton.styleFrom(
              backgroundColor: FirePumpSimColors.charcoal2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Practice Scenarios',
                  style: textTheme.headlineSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose a scenario or start random practice',
                  style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopActions extends StatelessWidget {
  const _TopActions({required this.onPick, required this.onRandom});

  final VoidCallback onPick;
  final VoidCallback onRandom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PrimaryActionButton(
            icon: Icons.list_alt,
            label: 'Pick Scenario',
            onPressed: onPick,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _SecondaryActionButton(
            icon: Icons.shuffle,
            label: 'Random Scenario',
            enabled: true,
            onPressed: onRandom,
          ),
        ),
      ],
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.selectedType,
    required this.selectedDifficulty,
    required this.typeFilters,
    required this.difficultyFilters,
    required this.onTypeChanged,
    required this.onDifficultyChanged,
  });

  final String selectedType;
  final String selectedDifficulty;
  final List<String> typeFilters;
  final List<String> difficultyFilters;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onDifficultyChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category', style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          _ChipRow(
            values: typeFilters,
            selectedValue: selectedType,
            onSelected: onTypeChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Difficulty', style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          _ChipRow(
            values: difficultyFilters,
            selectedValue: selectedDifficulty,
            onSelected: onDifficultyChanged,
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.values, required this.selectedValue, required this.onSelected});

  final List<String> values;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final v in values) ...[
            ChoiceChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  v,
                  style: textTheme.labelLarge?.copyWith(
                    color: selectedValue == v ? FirePumpSimColors.textHigh : FirePumpSimColors.textMed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              selected: selectedValue == v,
              onSelected: (_) => onSelected(v),
              backgroundColor: FirePumpSimColors.charcoal3.withValues(alpha: 0.8),
              selectedColor: FirePumpSimColors.steel.withValues(alpha: 0.95),
              showCheckmark: false,
              side: BorderSide(
                color: (selectedValue == v ? FirePumpSimColors.red : FirePumpSimColors.steel).withValues(alpha: 0.7),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.title,
    required this.type,
    required this.chip,
    required this.difficulty,
    required this.timedModeAvailable,
    required this.variations,
    required this.imageAssetPath,
    required this.onTap,
    required this.onStart,
  });

  final String title;
  final String type;
  final String chip;
  final String difficulty;
  final bool timedModeAvailable;
  final int variations;
  final String imageAssetPath;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.white.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ScenarioThumbnail(assetPath: imageAssetPath),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900, height: 1.15),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetaChip(label: chip, icon: Icons.local_fire_department, accent: FirePumpSimColors.red),
                            _MetaChip(label: type, icon: Icons.category),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _MiniStat(icon: Icons.trending_up, label: difficulty),
                            _MiniStat(icon: timedModeAvailable ? Icons.timer : Icons.timer_off, label: timedModeAvailable ? 'Timed' : 'Untimed'),
                            if (variations > 0) _MiniStat(icon: Icons.layers, label: 'Variations: $variations'),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: _PrimaryActionButton(
                            icon: Icons.play_arrow,
                            label: 'Start Scenario',
                            onPressed: onStart,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenarioThumbnail extends StatelessWidget {
  const _ScenarioThumbnail({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    if (assetPath.trim().isEmpty) {
      return Container(
        height: 92,
        width: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
          color: FirePumpSimColors.charcoal3,
        ),
        child: const Center(child: Icon(Icons.image_not_supported, color: FirePumpSimColors.textMed)),
      );
    }
    return Container(
      height: 92,
      width: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
        color: FirePumpSimColors.charcoal3,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(FirePumpSimColors.charcoal.withValues(alpha: 0.55), BlendMode.darken),
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
