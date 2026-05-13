import 'dart:math';

import 'package:firepumpsim/models/daily_challenge_models.dart';
import 'package:firepumpsim/models/scenario_models.dart';
import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/screens/formulas_screen.dart';
import 'package:firepumpsim/services/daily_challenge_storage.dart';
import 'package:firepumpsim/services/scenario_repository.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  final _repo = ScenarioRepository();
  final _storage = DailyChallengeStorage();
  final _answerCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _loading = true;
  String? _loadError;

  DailyChallengeStats _stats = DailyChallengeStats.empty;
  List<DailyChallengeResult> _history = const [];
  PlayableScenarioProblem? _today;
  String _todayDate = '';
  DailyChallengeResult? _todayResult;

  bool _practiceRetryEnabled = false;
  bool _submitting = false;

  // Result UI
  bool? _lastSubmitCorrect;
  double? _lastUserAnswer;
  double? _lastCorrectAnswer;
  double? _lastDiff;
  double? _lastTol;
  String _lastUnit = 'PSI';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final today = DateTime.now();
      final todayKey = _yyyyMmDd(today);
      final stats = await _storage.loadStats();
      final history = await _storage.loadHistory();
      // Daily Challenge uses the *official* manifest ordering only.
      final playable = await _repo.loadPlayableProblems(manifestOnly: true);

      if (playable.isEmpty) {
        setState(() {
          _loading = false;
          _stats = stats;
          _history = history;
          _todayDate = todayKey;
          _today = null;
          _todayResult = null;
          _loadError = 'No scenarios found.';
        });
        return;
      }

      final yesterdayKey = _yyyyMmDd(today.subtract(const Duration(days: 1)));
      DailyChallengeResult? yesterdayResult;
      for (final r in history) {
        if (r.date == yesterdayKey) {
          yesterdayResult = r;
          break;
        }
      }

      final todayProblem = _pickDailyProblem(playable: playable, dateKey: todayKey, yesterdayProblemId: yesterdayResult?.problemId);
      DailyChallengeResult? todayResult;
      for (final r in history) {
        if (r.date == todayKey) {
          todayResult = r;
          break;
        }
      }

      setState(() {
        _loading = false;
        _stats = stats;
        _history = history;
        _todayDate = todayKey;
        _today = todayProblem;
        _todayResult = todayResult;
        _practiceRetryEnabled = false;
      });
    } catch (e) {
      debugPrint('DailyChallenge bootstrap failed: $e');
      setState(() {
        _loading = false;
        _loadError = 'Today\'s challenge could not be loaded.';
      });
    }
  }

  static String _yyyyMmDd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static int _fnv1a32(String input) {
    const int fnvPrime = 16777619;
    const int offset = 2166136261;
    var hash = offset;
    final units = input.codeUnits;
    for (final u in units) {
      hash ^= u;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash;
  }

  static PlayableScenarioProblem _pickDailyProblem({
    required List<PlayableScenarioProblem> playable,
    required String dateKey,
    required String? yesterdayProblemId,
  }) {
    final idx = _fnv1a32(dateKey).abs() % playable.length;
    var picked = playable[idx];
    if (yesterdayProblemId != null && playable.length >= 2 && picked.problemId == yesterdayProblemId) {
      picked = playable[(idx + 1) % playable.length];
    }
    return picked;
  }

  bool get _isOfficialLocked {
    // Lock the official UI only after the user has completed today correctly.
    // If they've attempted and were incorrect, allow resubmits.
    // Retry-for-practice can unlock re-submitting UI, but does not double-count.
    return (_todayResult?.isCorrect == true) && !_practiceRetryEnabled;
  }

  Future<void> _pickAnotherChallenge() async {
    await _bootstrap();
  }

  Future<void> _tryAnotherRandomScenario() async {
    final p = await _repo.randomPlayableAdvanced(searchText: '', typeFilter: 'All Types', levelFilter: 'All Levels', modeFilter: 'All Modes');
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('No scenarios available.'), backgroundColor: FirePumpSimColors.charcoal3, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    context.go('${AppRoutes.scenarioPlayer}?problemId=${Uri.encodeComponent(p.problemId)}');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: FirePumpSimColors.charcoal3,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openFullScenario() {
    final p = _today;
    if (p == null) return;
    context.go('${AppRoutes.scenarioPlayer}?problemId=${Uri.encodeComponent(p.problemId)}');
  }

  void _reviewFormula() => showFormulasOverlay(context);

  Future<void> _openPracticeStylePreview(PlayableScenarioProblem problem) async {
    final textTheme = Theme.of(context).textTheme;
    final difficulty = problem.difficulty.trim().isEmpty ? 'Intermediate' : problem.difficulty.trim();
    final category = (problem.chip.trim().isNotEmpty ? problem.chip : problem.type).trim();
    final image = _TodayChallengeCard._pickImage(problem);

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
                            problem.problemTitle,
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
                    _DailyChallengeSceneViewer(assetPath: image, overlays: problem.overlays),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PreviewChip(label: problem.type, icon: Icons.category),
                        _PreviewChip(label: difficulty, icon: Icons.trending_up),
                        if (category.isNotEmpty) _PreviewChip(label: category, icon: Icons.local_fire_department),
                        _PreviewChip(label: problem.timedModeAvailable ? 'Timed' : 'Untimed', icon: problem.timedModeAvailable ? Icons.timer : Icons.timer_off),
                        if (problem.isVariation) _PreviewChip(label: 'Variation', icon: Icons.layers),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Student Question',
                      style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(problem.studentQuestion, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textHigh, height: 1.5)),
                    if (problem.details.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Scenario Info',
                        style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      _DetailsCard(details: problem.details),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.pop();
                          context.go('${AppRoutes.scenarioPlayer}?problemId=${Uri.encodeComponent(problem.problemId)}');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FirePumpSimColors.printGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: Text('Open Full Scenario', style: textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
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

  Future<void> _submitAnswer() async {
    if (_isOfficialLocked || _submitting) return;

    FocusScope.of(context).unfocus();

    final p = _today;
    if (p == null) {
      _showSnackBar('Daily challenge could not be loaded.');
      return;
    }

    final text = _answerCtrl.text.trim();
    if (text.isEmpty) {
      _showSnackBar('Enter an answer first.');
      return;
    }

    final userAnswer = _parseUserAnswer(text);
    if (userAnswer == null) {
      _showSnackBar('Enter a number only. Example: 120');
      return;
    }

    setState(() => _submitting = true);

    try {
      final info = _CorrectAnswerInfo.fromProblem(p);
      final correct = info.correctAnswer;
      if (correct == null) {
        _showSnackBar('This challenge is missing an answer key.');
        return;
      }

      final tol = info.tolerance;
      final diff = (userAnswer - correct).abs();
      final isCorrect = diff <= tol;

      final now = DateTime.now();
      final todayKey = _yyyyMmDd(now);
      final yesterdayKey = _yyyyMmDd(now.subtract(const Duration(days: 1)));

      // Load freshest copies to avoid UI races.
      var stats = await _storage.loadStats();
      final history = await _storage.loadHistory();
      DailyChallengeResult? existing;
      for (final r in history) {
        if (r.date == todayKey) {
          existing = r;
          break;
        }
      }

      final isFirstCompletionToday = existing == null;
      final previousAttempts = existing?.attempts ?? 0;
      final attempts = previousAttempts + 1;

      var countsForStreak = existing?.countsForStreak ?? false;
      var finalIsCorrect = existing?.isCorrect ?? false;

      // If the user ever gets it correct today, treat today as a correct completion.
      if (isCorrect) finalIsCorrect = true;

      // Only credit streak once per day.
      if (finalIsCorrect && !countsForStreak) {
        final lastCorrect = stats.lastCorrectDate.trim();
        final shouldIncrement = lastCorrect == yesterdayKey;
        final isSameDay = lastCorrect == todayKey;
        final nextStreak = isSameDay ? stats.currentStreak : (shouldIncrement ? stats.currentStreak + 1 : 1);
        final nextBest = max(stats.bestStreak, nextStreak);
        stats = stats.copyWith(lastCorrectDate: todayKey, currentStreak: nextStreak, bestStreak: nextBest);
        countsForStreak = true;
      }

      // Completed count increments only once per day.
      if (isFirstCompletionToday) {
        stats = stats.copyWith(
          lastCompletedDate: todayKey,
          totalCompleted: stats.totalCompleted + 1,
        );
      } else {
        stats = stats.copyWith(lastCompletedDate: todayKey);
      }

      // Attempts increment on every submit.
      stats = stats.copyWith(totalAttempts: stats.totalAttempts + 1);

      // Correct increments once per day when first becoming correct.
      if (finalIsCorrect && (existing?.isCorrect != true)) {
        stats = stats.copyWith(totalCorrect: stats.totalCorrect + 1);
      }

      final heuristics = _ChallengeHeuristics.fromProblem(p);
      final result = DailyChallengeResult(
        date: todayKey,
        problemId: p.problemId,
        scenarioId: p.scenarioId,
        title: p.problemTitle,
        category: (p.chip.trim().isNotEmpty ? p.chip : p.type).trim(),
        difficulty: p.difficulty.trim().isEmpty ? 'Intermediate' : p.difficulty.trim(),
        questionType: info.questionType,
        correctAnswer: correct,
        userAnswer: userAnswer,
        unit: info.unit,
        isCorrect: finalIsCorrect,
        attempts: attempts,
        completedAt: existing?.completedAt.isNotEmpty == true ? existing!.completedAt : now.toIso8601String(),
        countsForStreak: countsForStreak,
        hasElevation: heuristics.hasElevation,
        hasApplianceLoss: heuristics.hasApplianceLoss,
      );

      await _storage.saveStats(stats);
      await _storage.upsertResult(result);

      if (!mounted) return;
      setState(() {
        _stats = stats;
        _todayResult = result;
        _history = [result, ...history.where((h) => h.date != todayKey)];
        _lastSubmitCorrect = isCorrect;
        _lastUserAnswer = userAnswer;
        _lastCorrectAnswer = correct;
        _lastDiff = diff;
        _lastTol = tol;
        _lastUnit = info.unit;
        _practiceRetryEnabled = false;
      });

      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
      if (_scrollCtrl.hasClients) {
        await _scrollCtrl.animateTo(
          min(_scrollCtrl.position.maxScrollExtent, _scrollCtrl.offset + 280),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e) {
      debugPrint('DailyChallenge submit failed: $e');
      _showSnackBar('Unable to submit answer. Check the scenario answer key.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static double? _parseUserAnswer(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(',', '')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return null;
    return double.tryParse(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: FirePumpSimColors.charcoal,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_loadError != null && _today == null)
                ? _EmptyState(
                    title: _loadError ?? 'Today\'s challenge could not be loaded.',
                    subtitle: 'Add scenarios to assets/scenarios and check scenario_manifest.json.',
                    primaryLabel: 'Pick Another Challenge',
                    onPrimary: _pickAnotherChallenge,
                  )
                : RefreshIndicator(
                    onRefresh: _bootstrap,
                    color: FirePumpSimColors.red,
                    backgroundColor: FirePumpSimColors.charcoal2,
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextButton.icon(
                            onPressed: () => context.go(AppRoutes.home),
                            style: TextButton.styleFrom(
                              foregroundColor: FirePumpSimColors.textHigh,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                            icon: const Icon(Icons.arrow_back, color: FirePumpSimColors.textHigh),
                            label: Text(
                              'Back to Main Menu',
                              style: textTheme.titleSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Daily Challenge',
                            style: textTheme.headlineSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'One pump problem each day. Build your streak and find weak areas.',
                            style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.35),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _StatsRow(stats: _stats),
                          const SizedBox(height: AppSpacing.md),
                          _TodayChallengeCard(
                            date: _todayDate,
                            problem: _today!,
                            locked: _isOfficialLocked,
                            answerCtrl: _answerCtrl,
                            unit: _CorrectAnswerInfo.fromProblem(_today!).unit,
                            answerLabel: _CorrectAnswerInfo.fromProblem(_today!).label,
                            submitting: _submitting,
                            onSubmit: _submitAnswer,
                            onPreview: () => _openPracticeStylePreview(_today!),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (_todayResult != null || _lastSubmitCorrect != null) ...[
                            _ResultCard(
                              isCorrect: _lastSubmitCorrect ?? _todayResult!.isCorrect,
                              userAnswer: _lastUserAnswer ?? _todayResult!.userAnswer,
                              correctAnswer: _lastCorrectAnswer ?? _todayResult!.correctAnswer,
                              unit: _lastUnit,
                              tolerance: _lastTol ?? _CorrectAnswerInfo.fromProblem(_today!).tolerance,
                              explanation: _buildExplanation(_today!),
                              formulaBreakdown: _today!.formulaBreakdown,
                              onReviewFormula: _reviewFormula,
                              onTryAnother: _tryAnotherRandomScenario,
                              onOpenFullScenario: _openFullScenario,
                              onRetryPractice: () => setState(() {
                                _practiceRetryEnabled = true;
                                _todayResult = _todayResult; // keep record
                              }),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          _WeakAreasCard(history: _history),
                          const SizedBox(height: AppSpacing.md),
                          _RecentChallengesCard(history: _history),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Come back tomorrow for a new challenge.',
                            style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed.withValues(alpha: 0.85)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  static String _buildExplanation(PlayableScenarioProblem p) {
    final expl = p.instructorExplanation.trim();
    if (expl.isNotEmpty) return expl;
    final hint = p.explainMistake.trim();
    if (hint.isNotEmpty) return hint;
    return 'Check the setup, then recompute step-by-step.';
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final DailyChallengeStats stats;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accuracy = (stats.accuracy * 100).round();
    final hasHistory = stats.totalAttempts > 0 || stats.totalCompleted > 0;

    if (!hasHistory) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: FirePumpSimColors.charcoal2,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.7)),
        ),
        child: Text(
          'Start your first challenge today.',
          style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth < 360 ? 8.0 : 10.0;
        return Row(
          children: [
            Expanded(child: _StatTile(label: 'Current', value: '${stats.currentStreak} days')),
            SizedBox(width: gap),
            Expanded(child: _StatTile(label: 'Best', value: '${stats.bestStreak} days')),
            SizedBox(width: gap),
            Expanded(child: _StatTile(label: 'Accuracy', value: '$accuracy%')),
            SizedBox(width: gap),
            Expanded(child: _StatTile(label: 'Completed', value: '${stats.totalCompleted}')),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _TodayChallengeCard extends StatelessWidget {
  const _TodayChallengeCard({
    required this.date,
    required this.problem,
    required this.locked,
    required this.answerCtrl,
    required this.unit,
    required this.answerLabel,
    required this.submitting,
    required this.onSubmit,
    required this.onPreview,
  });

  final String date;
  final PlayableScenarioProblem problem;
  final bool locked;
  final TextEditingController answerCtrl;
  final String unit;
  final String answerLabel;
  final bool submitting;
  final Future<void> Function() onSubmit;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final badgeStyle = textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900, letterSpacing: 0.2);
    final difficulty = problem.difficulty.trim().isEmpty ? 'Intermediate' : problem.difficulty.trim();
    final category = (problem.chip.trim().isNotEmpty ? problem.chip : problem.type).trim();
    final timed = problem.timedModeAvailable;
    final qType = _CorrectAnswerInfo.fromProblem(problem).questionType;
    final image = _pickImage(problem);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date,
                  style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w800),
                ),
              ),
              if (locked)
                _Badge(
                  label: 'COMPLETED',
                  color: FirePumpSimColors.printGreen,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(problem.problemTitle, style: textTheme.titleLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900, height: 1.15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(label: difficulty, color: _difficultyColor(difficulty), style: badgeStyle),
                _Badge(label: problem.type, color: FirePumpSimColors.steel, style: badgeStyle),
                if (category.isNotEmpty && ScenarioRepository.normalize(category) != ScenarioRepository.normalize(problem.type))
                  _Badge(label: category, color: FirePumpSimColors.steel, style: badgeStyle),
                if (qType.trim().isNotEmpty) _Badge(label: qType, color: FirePumpSimColors.steel, style: badgeStyle),
              _Badge(label: timed ? 'TIMED' : 'UNTIMED', color: timed ? FirePumpSimColors.challengeBlue : FirePumpSimColors.steel, style: badgeStyle),
            ],
          ),
          const SizedBox(height: 12),
          _DailyScenePreviewTapTarget(assetPath: image, overlays: problem.overlays, onTap: onPreview),
          const SizedBox(height: 12),
          Text('Student Question', style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(problem.studentQuestion, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textHigh, height: 1.4)),
          const SizedBox(height: 12),
          _AnswerRow(answerCtrl: answerCtrl, unit: unit, label: answerLabel, enabled: !locked && !submitting),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (locked || submitting) ? null : () { onSubmit(); },
              style: ElevatedButton.styleFrom(
                backgroundColor: FirePumpSimColors.red,
                disabledBackgroundColor: FirePumpSimColors.red.withValues(alpha: 0.25),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: Icon(Icons.check_circle_outline, color: locked ? FirePumpSimColors.textMed : Colors.white),
              label: Text(
                locked ? 'Challenge Completed' : (submitting ? 'Checking Answer...' : 'Submit Answer'),
                style: textTheme.titleMedium?.copyWith(color: locked ? FirePumpSimColors.textMed : Colors.white, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _pickImage(PlayableScenarioProblem p) {
    bool ok(String s) => s.trim().toLowerCase().startsWith('assets/') && s.contains('.');
    if (ok(p.scene)) return p.scene;
    if (ok(p.image)) return p.image;
    return '';
  }

  static Color _difficultyColor(String difficulty) {
    final d = ScenarioRepository.normalize(difficulty);
    if (d == ScenarioRepository.normalize('beginner')) return FirePumpSimColors.printGreen;
    if (d == ScenarioRepository.normalize('advanced')) return FirePumpSimColors.redSoft;
    return FirePumpSimColors.challengeBlue;
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.answerCtrl, required this.unit, required this.label, required this.enabled});

  final TextEditingController answerCtrl;
  final String unit;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: answerCtrl,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  hintText: 'Enter your answer',
                  hintStyle: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed.withValues(alpha: 0.75)),
                  filled: true,
                  fillColor: FirePumpSimColors.charcoal3.withValues(alpha: 0.7),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.75))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.75))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: FirePumpSimColors.red, width: 1.4)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: FirePumpSimColors.charcoal3.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.75)),
              ),
              child: Text(unit, style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
            ),
          ],
        ),
      ],
    );
  }
}

class _DailyScenePreviewTapTarget extends StatelessWidget {
  const _DailyScenePreviewTapTarget({required this.assetPath, required this.overlays, required this.onTap});

  final String assetPath;
  final List<dynamic> overlays;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Stack(
            children: [
              _DailyChallengeSceneViewer(assetPath: assetPath, overlays: overlays),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.55)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Preview', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scenario Player-style scene viewer: same sizing behavior and `BoxFit.contain`
/// so the full photo can be viewed without cropping.
class _DailyChallengeSceneViewer extends StatelessWidget {
  const _DailyChallengeSceneViewer({required this.assetPath, required this.overlays});

  final String assetPath;
  final List<dynamic> overlays;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
        color: FirePumpSimColors.charcoal3,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: _ScenarioPlayerStyleImageWithOverlays(assetPath: assetPath, overlays: overlays),
      ),
    );
  }
}

class _ScenarioPlayerStyleImageWithOverlays extends StatelessWidget {
  const _ScenarioPlayerStyleImageWithOverlays({required this.assetPath, required this.overlays, this.height});

  final String assetPath;
  final List<dynamic> overlays;
  final double? height;

  double _normalizeCoord(dynamic raw) {
    if (raw == null) return 0;
    final v = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (v == null) return 0;
    if (v >= 0 && v <= 1) return v;
    if (v >= 0 && v <= 100) return v / 100.0;
    return v.clamp(0.0, 1.0);
  }

  _ParsedOverlay? _parseOverlay(dynamic o) {
    if (o is! Map) return null;
    final m = Map<String, dynamic>.from(o);
    final valueText = (m['text'] ?? m['value'] ?? m['display'] ?? '').toString().trim();
    final fallback = (m['label'] ?? m['title'] ?? m['name'] ?? '').toString().trim();
    final text = valueText.isNotEmpty ? valueText : fallback;
    if (text.isEmpty) return null;
    final x = _normalizeCoord(m['x'] ?? m['left'] ?? m['px'] ?? m['cx']);
    final y = _normalizeCoord(m['y'] ?? m['top'] ?? m['py'] ?? m['cy']);
    final canonical = _canonicalOverlayLabel(text);
    final snapped = _snappedPositionForCanonical(canonical);
    return _ParsedOverlay(label: text, canonical: canonical, x: snapped?.$1 ?? x, y: snapped?.$2 ?? y);
  }

  String _canonicalOverlayLabel(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.contains('vehicle') && s.contains('fire')) return 'vehicle_fire';
    if (s.contains('fog') || (s.contains('gpm') && s.contains('psi'))) return 'fog_flow_pressure';
    if (s.contains('engine')) return 'engine';
    if (s.contains('1¾') || s.contains('1 3/4') || s.contains('1.75') || s.contains('1 ¾') || s.contains('1-3/4')) {
      return 'hose_200_1_3_4';
    }
    if (s.contains('200') && (s.contains('1¾') || s.contains('1 3/4') || s.contains('1.75'))) return 'hose_200_1_3_4';
    if (s.contains('no elevation')) return 'no_elevation';
    if (s.contains('no appliance')) return 'no_appliance';
    return 'generic';
  }

  (double, double)? _snappedPositionForCanonical(String canonical) {
    switch (canonical) {
      case 'vehicle_fire':
        return (0.84, 0.10);
      case 'fog_flow_pressure':
        return (0.78, 0.30);
      case 'engine':
        return (0.14, 0.74);
      case 'hose_200_1_3_4':
        return (0.50, 0.80);
      case 'no_appliance':
        return (0.84, 0.86);
      case 'no_elevation':
        return (0.84, 0.93);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = overlays.map(_parseOverlay).whereType<_ParsedOverlay>().toList(growable: false);
    final screenH = MediaQuery.sizeOf(context).height;
    final targetH = height ?? (screenH * 0.56).clamp(400.0, 620.0);

    return SizedBox(
      width: double.infinity,
      height: targetH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: FirePumpSimColors.charcoal),
          if (assetPath.trim().isEmpty)
            const Center(child: Icon(Icons.image_not_supported, color: FirePumpSimColors.textMed))
          else
            Image.asset(
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Scenario image failed to load ($assetPath): $error');
                return const Center(child: Icon(Icons.image_not_supported, color: FirePumpSimColors.textMed));
              },
            ),
          if (parsed.isNotEmpty)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final h = c.maxHeight;
                  return Stack(
                    children: parsed
                        .map((o) => _OverlayLabel(label: o.label, canonical: o.canonical, x: o.x, y: o.y, maxWidth: w, maxHeight: h))
                        .toList(growable: false),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

@immutable
class _ParsedOverlay {
  const _ParsedOverlay({required this.label, required this.canonical, required this.x, required this.y});
  final String label;
  final String canonical;
  final double x;
  final double y;
}

class _OverlayLabel extends StatelessWidget {
  const _OverlayLabel({required this.label, required this.canonical, required this.x, required this.y, required this.maxWidth, required this.maxHeight});

  final String label;
  final String canonical;
  final double x;
  final double y;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final clampedX = x.clamp(0.02, 0.98);
    final clampedY = y.clamp(0.02, 0.98);

    final pillColor = canonical == 'vehicle_fire' ? FirePumpSimColors.redSoft : FirePumpSimColors.charcoal3;

    return Positioned(
      left: (clampedX * maxWidth).clamp(0.0, maxWidth),
      top: (clampedY * maxHeight).clamp(0.0, maxHeight),
      child: Transform.translate(
        offset: const Offset(-8, -8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth * 0.62),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: pillColor.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.6)),
            ),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: FirePumpSimColors.textMed),
          const SizedBox(width: 6),
          Text(label, style: textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.details});

  final List<dynamic> details;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rows = <Widget>[];

    for (final d in details) {
      if (d == null) continue;
      if (d is String) {
        final t = d.trim();
        if (t.isEmpty) continue;
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('• $t', style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textHigh, height: 1.35)),
        ));
        continue;
      }
      if (d is Map) {
        final label = (d['label'] ?? d['title'] ?? '').toString().trim();
        final value = (d['value'] ?? d['text'] ?? '').toString().trim();
        if (label.isEmpty && value.isEmpty) continue;
        final left = label.isEmpty ? '•' : label;
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(left, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(value, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textHigh, height: 1.35))),
            ],
          ),
        ));
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.style});

  final String label;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(label, style: style ?? textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.isCorrect,
    required this.userAnswer,
    required this.correctAnswer,
    required this.unit,
    required this.tolerance,
    required this.explanation,
    required this.formulaBreakdown,
    required this.onReviewFormula,
    required this.onTryAnother,
    required this.onOpenFullScenario,
    required this.onRetryPractice,
  });

  final bool isCorrect;
  final double userAnswer;
  final double correctAnswer;
  final String unit;
  final double tolerance;
  final String explanation;
  final List<dynamic> formulaBreakdown;
  final VoidCallback onReviewFormula;
  final Future<void> Function() onTryAnother;
  final VoidCallback onOpenFullScenario;
  final VoidCallback onRetryPractice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final diff = (userAnswer - correctAnswer).abs();
    final color = isCorrect ? FirePumpSimColors.printGreen : Colors.orange;
    final title = isCorrect ? 'Correct — nice work.' : 'Not quite. Review the explanation below.';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(isCorrect ? Icons.verified_outlined : Icons.error_outline, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          _KeyValueRow(label: 'Your answer', value: '${_fmt(userAnswer)} $unit'),
          _KeyValueRow(label: 'Correct answer', value: '${_fmt(correctAnswer)} $unit'),
          _KeyValueRow(label: 'Difference', value: '${_fmt(diff)} $unit'),
          _KeyValueRow(label: 'Tolerance', value: '±${_fmt(tolerance)} $unit'),
          const SizedBox(height: 10),
          Text('Teaching Feedback', style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(explanation, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textHigh, height: 1.4)),
          if (formulaBreakdown.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Formula Breakdown', style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            _FormulaList(lines: formulaBreakdown),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(label: 'Review Formula', icon: Icons.functions_outlined, color: FirePumpSimColors.red, onTap: onReviewFormula),
              _ActionButton(label: 'Try Another Random Scenario', icon: Icons.shuffle, color: FirePumpSimColors.challengeBlue, onTapAsync: onTryAnother),
              _ActionButton(label: 'Open Full Scenario', icon: Icons.play_circle_outline, color: FirePumpSimColors.printGreen, onTap: onOpenFullScenario),
              _ActionButton(label: 'Retry for Practice', icon: Icons.refresh, color: FirePumpSimColors.steel, onTap: onRetryPractice),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    final asInt = v.roundToDouble();
    if ((v - asInt).abs() < 1e-9) return asInt.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({required this.label, required this.icon, required this.color, this.onTap, this.onTapAsync});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Future<void> Function()? onTapAsync;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enabled = !_busy && (widget.onTap != null || widget.onTapAsync != null);
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: !enabled
            ? null
            : () async {
                if (widget.onTap != null) {
                  widget.onTap!.call();
                  return;
                }
                if (widget.onTapAsync != null) {
                  setState(() => _busy = true);
                  try {
                    await widget.onTapAsync!.call();
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                }
              },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: widget.color.withValues(alpha: 0.75)),
          backgroundColor: widget.color.withValues(alpha: 0.08),
          foregroundColor: FirePumpSimColors.textHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _busy
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(widget.color)),
              )
            : Icon(widget.icon, color: widget.color, size: 20),
        label: Text(widget.label, style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed))),
          const SizedBox(width: 10),
          Text(value, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _FormulaList extends StatelessWidget {
  const _FormulaList({required this.lines});

  final List<dynamic> lines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rendered = <String>[];
    for (final l in lines) {
      if (l == null) continue;
      if (l is String && l.trim().isNotEmpty) rendered.add(l.trim());
      if (l is Map) {
        final label = l['label']?.toString().trim() ?? '';
        final value = l['value']?.toString().trim() ?? '';
        final joined = [label, value].where((e) => e.isNotEmpty).join(': ');
        if (joined.isNotEmpty) rendered.add(joined);
      }
    }
    if (rendered.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rendered
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $t', style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textHigh, height: 1.35)),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _WeakAreasCard extends StatelessWidget {
  const _WeakAreasCard({required this.history});

  final List<DailyChallengeResult> history;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recent = history.take(25).toList(growable: false);
    final weak = _computeWeakAreas(recent);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Areas to Work On', style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (weak.isEmpty)
            Text(
              'Complete a few daily challenges and practice scenarios to unlock personalized weak-area feedback.',
              style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.35),
            )
          else
            Column(
              children: weak
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _WeakAreaTile(area: w.area, accuracy: w.accuracy, recommendation: w.recommendation),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  static List<_WeakArea> _computeWeakAreas(List<DailyChallengeResult> history) {
    if (history.length < 3) return const [];

    final byArea = <String, List<DailyChallengeResult>>{};
    for (final r in history) {
      final area = _areaKey(r);
      byArea.putIfAbsent(area, () => []).add(r);
    }

    final scored = <_WeakArea>[];
    for (final entry in byArea.entries) {
      final attempts = entry.value.length;
      if (attempts < 2) continue;
      final correct = entry.value.where((e) => e.isCorrect).length;
      final acc = correct / attempts;
      scored.add(_WeakArea(area: entry.key, accuracy: acc, recommendation: _recommend(entry.key)));
    }

    scored.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return scored.take(3).toList(growable: false);
  }

  static String _areaKey(DailyChallengeResult r) {
    final cat = r.category.trim().isEmpty ? 'General' : r.category.trim();
    final q = r.questionType.trim();
    final bits = <String>[cat];
    if (q.isNotEmpty) bits.add(q);
    if (r.difficulty.trim().isNotEmpty) bits.add(r.difficulty.trim());
    if (r.hasElevation) bits.add('Elevation');
    if (r.hasApplianceLoss) bits.add('Appliance Loss');
    return bits.join(' • ');
  }

  static String _recommend(String area) {
    final a = area.toLowerCase();
    if (a.contains('elev')) return 'Remember: uphill adds pressure, downhill subtracts pressure.';
    if (a.contains('nozzle') || a.contains('reaction')) return 'Review fog vs smooth bore nozzle reaction formulas and units.';
    if (a.contains('standpipe')) return 'Review system loss, hose stretch, and floor elevation adds.';
    if (a.contains('relay')) return 'Review relay spacing and friction loss over supply hose.';
    if (a.contains('water') || a.contains('supply') || a.contains('hydrant')) return 'Review available flow, intake limits, and water supply constraints.';
    if (a.contains('appliance') || a.contains('wye') || a.contains('gated')) return 'Review appliance loss values and when to add them.';
    if (a.contains('pump') || a.contains('pressure') || a.contains('pp')) return 'Review PP = NP + FL ± Elevation + Appliance.';
    return 'Rework the problem slowly and compare each step to the formula breakdown.';
  }
}

@immutable
class _WeakArea {
  const _WeakArea({required this.area, required this.accuracy, required this.recommendation});
  final String area;
  final double accuracy;
  final String recommendation;
}

class _WeakAreaTile extends StatelessWidget {
  const _WeakAreaTile({required this.area, required this.accuracy, required this.recommendation});

  final String area;
  final double accuracy;
  final String recommendation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pct = (accuracy * 100).round();
    final barColor = pct >= 85 ? FirePumpSimColors.printGreen : (pct >= 70 ? Colors.orange : FirePumpSimColors.redSoft);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(area, style: textTheme.titleSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900))),
              _Badge(label: '$pct%', color: barColor),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: accuracy.clamp(0, 1),
              backgroundColor: FirePumpSimColors.steel.withValues(alpha: 0.35),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text('Recommendation: $recommendation', style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.35)),
        ],
      ),
    );
  }
}

class _RecentChallengesCard extends StatelessWidget {
  const _RecentChallengesCard({required this.history});

  final List<DailyChallengeResult> history;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final items = history.take(5).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Recent Challenges', style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text('No completed challenges yet.', style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed))
          else
            ...items.map((r) => _RecentRow(result: r)),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.result});

  final DailyChallengeResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = result.isCorrect ? FirePumpSimColors.printGreen : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          _Badge(label: result.isCorrect ? 'CORRECT' : 'INCORRECT', color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.date, style: textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  'You: ${result.userAnswer} ${result.unit}  •  Correct: ${result.correctAnswer} ${result.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle, required this.primaryLabel, required this.onPrimary});

  final String title;
  final String subtitle;
  final String primaryLabel;
  final Future<void> Function() onPrimary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 44, color: FirePumpSimColors.textMed.withValues(alpha: 0.85)),
            const SizedBox(height: 12),
            Text(title, style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.35), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              width: 220,
              child: ElevatedButton(
                onPressed: () async => onPrimary(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FirePumpSimColors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(primaryLabel, style: textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrectAnswerInfo {
  const _CorrectAnswerInfo({
    required this.correctAnswer,
    required this.unit,
    required this.tolerance,
    required this.label,
    required this.questionType,
  });

  final double? correctAnswer;
  final String unit;
  final double tolerance;
  final String label;
  final String questionType;

  static _CorrectAnswerInfo fromProblem(PlayableScenarioProblem p) {
    final qt = _inferQuestionType(p);
    final correct = _extractCorrectAnswer(p) ?? (p.correctPP is num ? (p.correctPP as num).toDouble() : null);

    final jsonTol = p.tolerance is num ? (p.tolerance as num).toDouble() : double.tryParse('${p.tolerance}') ?? 0;
    final baseTol = jsonTol > 0 ? jsonTol : _defaultTolerance(qt);

    final unit = _pickUnit(p, qt);
    final label = _pickLabel(p);

    return _CorrectAnswerInfo(correctAnswer: correct, unit: unit, tolerance: baseTol, label: label, questionType: qt);
  }

  static String _inferQuestionType(PlayableScenarioProblem p) {
    final a = p.answers;
    final fromAnswers = (a['questionType'] ?? a['type'] ?? a['kind'])?.toString().trim();
    if (fromAnswers != null && fromAnswers.isNotEmpty) return fromAnswers;
    return p.type.trim();
  }

  static String _pickLabel(PlayableScenarioProblem p) {
    final a = p.answers;
    final label = (a['answerLabel'] ?? a['label'] ?? a['answer_name'] ?? a['name'])?.toString().trim() ?? '';
    if (label.isNotEmpty) return label;
    // Sensible default for most FirePumpSim problems.
    return 'Pump Pressure';
  }

  static String _pickUnit(PlayableScenarioProblem p, String questionType) {
    final a = p.answers;
    final fromJson = (a['answerUnit'] ?? a['unit'] ?? a['units'])?.toString().trim();
    if (fromJson != null && fromJson.isNotEmpty) return fromJson;

    final qt = questionType.toLowerCase();
    if (qt.contains('nozzle') || qt.contains('reaction')) return 'lbs';
    if (qt.contains('gpm') || qt.contains('flow') || qt.contains('shuttle')) return 'GPM';
    if (qt.contains('relay') && qt.contains('distance')) return 'ft';
    if (qt.contains('distance')) return 'ft';
    if (qt.contains('elev') || qt.contains('elevation')) return 'PSI';
    return 'PSI';
  }

  static double _defaultTolerance(String questionType) {
    final qt = questionType.toLowerCase();
    if (qt.contains('nozzle') || qt.contains('reaction')) return 5;
    if (qt.contains('gpm') || qt.contains('flow') || qt.contains('shuttle')) return 10;
    if (qt.contains('relay') && qt.contains('distance')) return 50;
    if (qt.contains('distance')) return 50;
    return 5;
  }

  static double? _extractCorrectAnswer(PlayableScenarioProblem p) {
    // Common top-level numeric fields.
    final direct = <dynamic>[
      // Newer scenario JSONs often use `answerValue` for non-PP questions
      // while leaving `correctPP` / `pumpPressure` at 0 as placeholders.
      p.answers['answerValue'],
      p.answers['correctAnswer'],
      p.answers['answer'],
      p.answers['value'],
      p.answers['nozzleReaction'],
      p.answers['solidBoreFlow'],
      p.answers['flow'],
      p.answers['gpm'],
      p.answers['pumpPressure'],
      p.answers['correctPP'],
      p.correctPP,
    ];
    for (final v in direct) {
      final d = _asDouble(v);
      if (d != null) return d;
    }

    final a = p.answers;
    // Nested objects like answers.correct, answers.correctAnswer, answers.nozzleReaction, etc.
    final nestedCandidates = <dynamic>[
      a['correct'],
      a['answers'],
      a['answerValue'],
      a['correctAnswer'],
      a['nozzleReaction'],
      a['pumpPressure'],
    ];

    for (final n in nestedCandidates) {
      final d = _searchForNumericAnswer(n);
      if (d != null) return d;
    }

    return null;
  }

  static double? _searchForNumericAnswer(dynamic node) {
    if (node == null) return null;
    if (node is num) return node.toDouble();
    if (node is String) return double.tryParse(node.trim());
    if (node is Map) {
      final map = node;
      const preferredKeys = [
        'correct',
        'answerValue',
        'correctAnswer',
        'answer',
        'value',
        'nozzleReaction',
        'solidBoreFlow',
        'flow',
        'gpm',
        'pumpPressure',
      ];
      for (final k in preferredKeys) {
        final v = map[k];
        final d = _asDouble(v);
        if (d != null) return d;
      }
      for (final v in map.values) {
        final d = _searchForNumericAnswer(v);
        if (d != null) return d;
      }
    }
    if (node is List) {
      for (final v in node) {
        final d = _searchForNumericAnswer(v);
        if (d != null) return d;
      }
    }
    return null;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }
}

@immutable
class _ChallengeHeuristics {
  const _ChallengeHeuristics({required this.hasElevation, required this.hasApplianceLoss});

  final bool hasElevation;
  final bool hasApplianceLoss;

  static _ChallengeHeuristics fromProblem(PlayableScenarioProblem p) {
    bool hasElevation = false;
    bool hasAppliance = false;

    bool markIfNonZero(dynamic v, void Function() mark) {
      if (v == null) return false;
      if (v is num) {
        if (v.toDouble().abs() > 1e-9) {
          mark();
          return true;
        }
        return false;
      }
      final s = v.toString().toLowerCase().trim();
      final parsed = double.tryParse(s.replaceAll(RegExp(r'[^0-9\-\.]'), ''));
      if (parsed != null && parsed.abs() > 1e-9) {
        mark();
        return true;
      }
      return false;
    }

    // Scan the answers map for common fields.
    final a = p.answers;
    final elevCandidates = <dynamic>[a['elevation'], a['elevationFeet'], a['elevFt'], a['elev'], a['elevationPsi'], a['elevPsi']];
    for (final v in elevCandidates) {
      markIfNonZero(v, () => hasElevation = true);
      if (hasElevation) break;
    }

    final appCandidates = <dynamic>[a['appliance'], a['applianceLoss'], a['appliancePsi'], a['appliance_loss'], a['lossAppliance']];
    for (final v in appCandidates) {
      markIfNonZero(v, () => hasAppliance = true);
      if (hasAppliance) break;
    }

    // Also look for keywords in details lines.
    for (final d in p.details) {
      final s = d.toString().toLowerCase();
      if (!hasElevation && s.contains('elev')) hasElevation = true;
      if (!hasAppliance && (s.contains('appliance') || s.contains('wye') || s.contains('gated') || s.contains('standpipe'))) hasAppliance = true;
    }

    return _ChallengeHeuristics(hasElevation: hasElevation, hasApplianceLoss: hasAppliance);
  }
}
