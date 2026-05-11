import 'package:firepumpsim/models/scenario_models.dart';
import 'package:firepumpsim/services/scenario_repository.dart';
import 'package:firepumpsim/theme.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Scenario Player.
///
/// Shows one playable scenario problem at a time.
class ScenarioPlayerScreen extends StatefulWidget {
  const ScenarioPlayerScreen({super.key, required this.problemId});

  final String problemId;

  @override
  State<ScenarioPlayerScreen> createState() => _ScenarioPlayerScreenState();
}

class _ScenarioPlayerScreenState extends State<ScenarioPlayerScreen> {
  final ScenarioRepository _repo = ScenarioRepository();

  final TextEditingController _answerController = TextEditingController();

  _PlayerMode _mode = _PlayerMode.photo;
  bool _hasChecked = false;
  bool _isCorrect = false;
  bool _showExplanation = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  String _expectedUnit(PlayableScenarioProblem p) {
    final candidates = <dynamic>[
      p.answers['unit'],
      p.answers['units'],
      p.answers['answerUnit'],
      p.answers['expectedUnit'],
    ];
    for (final c in candidates) {
      final s = (c ?? '').toString().trim();
      if (s.isNotEmpty) return s.toUpperCase();
    }

    for (final d in p.details) {
      if (d is Map) {
        final m = Map<String, dynamic>.from(d);
        final label = (m['label'] ?? m['title'] ?? m['name'] ?? '').toString().toLowerCase();
        if (label.contains('unit')) {
          final value = (m['value'] ?? m['text'] ?? m['display'] ?? '').toString().trim();
          if (value.isNotEmpty) return value.toUpperCase();
        }
      }
    }

    return 'PSI';
  }

  num? _expectedAnswer(PlayableScenarioProblem p) {
    if (p.correctPP is num) return p.correctPP;

    // Fall back to answers map if a pack uses it for numeric targets.
    final candidates = <dynamic>[p.answers['pp'], p.answers['PP'], p.answers['correctPP'], p.answers['target']];
    for (final c in candidates) {
      if (c is num) return c;
      final parsed = num.tryParse('$c');
      if (parsed != null) return parsed;
    }
    return null;
  }

  num _tolerance(PlayableScenarioProblem p) {
    if (p.tolerance is num) return p.tolerance!.toDouble();

    final candidates = <dynamic>[p.answers['tolerance'], p.answers['tol'], p.answers['±']];
    for (final c in candidates) {
      if (c is num) return c.toDouble();
      final parsed = num.tryParse('$c');
      if (parsed != null) return parsed.toDouble();
    }
    return 0;
  }

  bool _checkAnswer(PlayableScenarioProblem p) {
    final expected = _expectedAnswer(p);
    if (expected == null) return false;

    final raw = _answerController.text.trim().replaceAll(',', '');
    final user = num.tryParse(raw);
    if (user == null) return false;

    final tol = _tolerance(p);
    return (user - expected).abs() <= tol;
  }

  Future<PlayableScenarioProblem?> _loadProblem(String problemId) async {
    if (problemId.trim().isEmpty) return null;
    try {
      return await _repo.findPlayableByProblemId(problemId);
    } catch (e) {
      debugPrint('Failed to load playable problemId=$problemId: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<PlayableScenarioProblem?>(
          future: _loadProblem(widget.problemId),
          builder: (context, snapshot) {
            final p = snapshot.data;

            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(
                  color: FirePumpSimColors.red,
                  strokeWidth: 2,
                ),
              );
            }

            if (p == null) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: FirePumpSimColors.textHigh,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: FirePumpSimColors.charcoal2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: FirePumpSimColors.steel.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Scenario not found',
                      style: textTheme.titleLarge?.copyWith(
                        color: FirePumpSimColors.textHigh,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.problemId.trim().isEmpty
                          ? 'No problemId was provided to the player route.'
                          : 'This scenario problem may have been removed, or the pack manifest/JSON is out of date.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: FirePumpSimColors.textMed,
                        height: 1.5,
                      ),
                    ),
                    if (widget.problemId.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'problemId: ${widget.problemId}',
                        style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed.withValues(alpha: 0.9)),
                      ),
                    ],
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final unit = _expectedUnit(p);
                  final totalH = constraints.maxHeight;
                  // Header + segmented control + answer card (collapsed) + bottom breathing room.
                  // Note: the answer card can expand; in that case the page will scroll.
                  const reserved = 84.0 + 12.0 + 44.0 + 12.0 + 132.0 + 18.0;
                  final cardH = (totalH - reserved).clamp(360.0, 620.0);

                  return SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
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
                                    p.problemTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleLarge?.copyWith(
                                      color: FirePumpSimColors.textHigh,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${p.type} • ${p.difficulty}${p.timedModeAvailable ? ' • Timed mode' : ' • Untimed'}',
                                    style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        SizedBox(
                          height: cardH,
                          width: double.infinity,
                          child: _MainDisplayCard(
                            mode: _mode,
                            photo: _ScenarioImageWithOverlays(
                              assetPath: p.image,
                              overlays: p.overlays,
                              height: cardH,
                            ),
                            problem: _ProblemView(problem: p),
                            info: _InfoView(problem: p, unit: unit),
                          ),
                        ),

                        const SizedBox(height: 12),
                        _ModeSegmentedControl(
                          mode: _mode,
                          onChanged: (m) => setState(() => _mode = m),
                        ),

                        const SizedBox(height: 12),
                        _AnswerCard(
                          problem: p,
                          unit: unit,
                          answerController: _answerController,
                          hasChecked: _hasChecked,
                          isCorrect: _isCorrect,
                          showExplanation: _showExplanation,
                          onCheck: () {
                            setState(() {
                              _hasChecked = true;
                              _isCorrect = _checkAnswer(p);
                              _showExplanation = false;
                            });
                          },
                          onToggleExplanation: () => setState(() => _showExplanation = !_showExplanation),
                        ),

                        const SizedBox(height: 18),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _PlayerMode { photo, problem, info }

class _MainDisplayCard extends StatelessWidget {
  const _MainDisplayCard({required this.mode, required this.photo, required this.problem, required this.info});

  final _PlayerMode mode;
  final Widget photo;
  final Widget problem;
  final Widget info;

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (mode) {
      case _PlayerMode.photo:
        child = photo;
        break;
      case _PlayerMode.problem:
        child = problem;
        break;
      case _PlayerMode.info:
        child = info;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: KeyedSubtree(
            key: ValueKey(mode),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ModeSegmentedControl extends StatelessWidget {
  const _ModeSegmentedControl({required this.mode, required this.onChanged});

  final _PlayerMode mode;
  final ValueChanged<_PlayerMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _ModeSegmentButton(
              label: 'Photo',
              selected: mode == _PlayerMode.photo,
              onTap: () => onChanged(_PlayerMode.photo),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ModeSegmentButton(
              label: 'Question',
              selected: mode == _PlayerMode.problem,
              onTap: () => onChanged(_PlayerMode.problem),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ModeSegmentButton(
              label: 'Info',
              selected: mode == _PlayerMode.info,
              onTap: () => onChanged(_PlayerMode.info),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSegmentButton extends StatelessWidget {
  const _ModeSegmentButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bg = selected ? FirePumpSimColors.red : FirePumpSimColors.charcoal2;
    final fg = selected ? Colors.white : FirePumpSimColors.textHigh;
    final border = selected ? Colors.transparent : FirePumpSimColors.steel.withValues(alpha: 0.85);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: fg,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _ScenarioImageWithOverlays extends StatelessWidget {
  const _ScenarioImageWithOverlays({required this.assetPath, required this.overlays, this.height});

  final String assetPath;
  final List<dynamic> overlays;
  final double? height;

  double _normalizeCoord(dynamic raw) {
    if (raw == null) return 0;
    final v = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    if (v == null) return 0;
    // New format: 0.0 - 1.0
    if (v >= 0 && v <= 1) return v;
    // Old format: 0 - 100 (percent)
    if (v >= 0 && v <= 100) return v / 100.0;
    // Fallback: clamp
    return v.clamp(0.0, 1.0);
  }

  _ParsedOverlay? _parseOverlay(dynamic o) {
    if (o is! Map) return null;
    final m = Map<String, dynamic>.from(o);
    // Prefer the overlay's `text` (value) over `label` (category).
    // This keeps the image overlays actionable: "200′ 1¾\"", "Fog 150 @ 50", etc.
    final valueText = (m['text'] ?? m['value'] ?? m['display'] ?? '').toString().trim();
    final fallback = (m['label'] ?? m['title'] ?? m['name'] ?? '').toString().trim();
    final text = valueText.isNotEmpty ? valueText : fallback;
    if (text.isEmpty) return null;
    final x = _normalizeCoord(m['x'] ?? m['left'] ?? m['px'] ?? m['cx']);
    final y = _normalizeCoord(m['y'] ?? m['top'] ?? m['py'] ?? m['cy']);
    return _ParsedOverlay(label: text, x: x, y: y);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = overlays.map(_parseOverlay).whereType<_ParsedOverlay>().toList(growable: false);

    final screenH = MediaQuery.sizeOf(context).height;
    final targetH = height ?? (screenH * 0.52).clamp(380.0, 560.0);

    return SizedBox(
      width: double.infinity,
      height: targetH,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
          color: FirePumpSimColors.charcoal,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (assetPath.trim().isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'No image provided for this scenario.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: FirePumpSimColors.textMed,
                            height: 1.4,
                          ),
                    ),
                  ),
                )
              else
                Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Scenario image failed to load ($assetPath): $error');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Image not found:\n$assetPath',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: FirePumpSimColors.textMed,
                                height: 1.4,
                              ),
                        ),
                      ),
                    );
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
                            .map(
                              (o) => _OverlayLabel(
                                label: o.label,
                                x: o.x,
                                y: o.y,
                                maxWidth: w,
                                maxHeight: h,
                              ),
                            )
                            .toList(growable: false),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class _ParsedOverlay {
  const _ParsedOverlay({required this.label, required this.x, required this.y});
  final String label;
  final double x;
  final double y;
}

class _OverlayLabel extends StatelessWidget {
  const _OverlayLabel({
    required this.label,
    required this.x,
    required this.y,
    required this.maxWidth,
    required this.maxHeight,
  });

  final String label;
  final double x;
  final double y;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final safeX = x.clamp(0.02, 0.98);
    final safeY = y.clamp(0.02, 0.98);
    final anchorX = safeX * maxWidth;
    final anchorY = safeY * maxHeight;

    const labelMaxW = 180.0;
    const labelPad = 10.0;
    const dotR = 3.6;
    const offset = 10.0;

    final preferredLeft = anchorX + offset;
    final preferredTop = anchorY - 18;
    final clampedLeft = math.max(labelPad, math.min(preferredLeft, maxWidth - labelMaxW - labelPad));
    final clampedTop = math.max(labelPad, math.min(preferredTop, maxHeight - 44 - labelPad));

    return Stack(
      children: [
        Positioned(
          left: anchorX - dotR,
          top: anchorY - dotR,
          child: Container(
            width: dotR * 2,
            height: dotR * 2,
            decoration: BoxDecoration(
              color: FirePumpSimColors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.55), width: 1),
            ),
          ),
        ),
        Positioned(
          left: clampedLeft,
          top: clampedTop,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: labelMaxW),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: FirePumpSimColors.charcoal2.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.7), width: 1),
              ),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: FirePumpSimColors.textHigh,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProblemView extends StatelessWidget {
  const _ProblemView({required this.problem});

  final PlayableScenarioProblem problem;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: FirePumpSimColors.charcoal2,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'THE PROBLEM',
              style: textTheme.labelLarge?.copyWith(
                color: FirePumpSimColors.textHigh,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              problem.studentQuestion,
              style: textTheme.bodyMedium?.copyWith(
                color: FirePumpSimColors.textHigh,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.problem,
    required this.unit,
    required this.answerController,
    required this.hasChecked,
    required this.isCorrect,
    required this.showExplanation,
    required this.onCheck,
    required this.onToggleExplanation,
  });

  final PlayableScenarioProblem problem;
  final String unit;
  final TextEditingController answerController;
  final bool hasChecked;
  final bool isCorrect;
  final bool showExplanation;
  final VoidCallback onCheck;
  final VoidCallback onToggleExplanation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showExplanationButton =
        problem.instructorExplanation.trim().isNotEmpty || problem.formulaBreakdown.isNotEmpty || problem.explainMistake.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your Answer',
                style: textTheme.labelLarge?.copyWith(
                  color: FirePumpSimColors.textHigh,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              if (hasChecked) _ResultPill(isCorrect: isCorrect),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: answerController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                  textInputAction: TextInputAction.done,
                  style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Enter PSI',
                    hintStyle: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed.withValues(alpha: 0.85)),
                    filled: true,
                    fillColor: FirePumpSimColors.charcoal3.withValues(alpha: 0.75),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.6)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: const BorderSide(color: FirePumpSimColors.red, width: 1.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: FirePumpSimColors.charcoal3.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.55)),
                ),
                child: Text(
                  unit,
                  style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: onCheck,
                  style: FilledButton.styleFrom(
                    backgroundColor: FirePumpSimColors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Check', style: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (hasChecked) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isCorrect ? 'Correct.' : 'Try again.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isCorrect ? FirePumpSimColors.textHigh : FirePumpSimColors.textMed,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (showExplanationButton)
                  TextButton(
                    onPressed: onToggleExplanation,
                    style: TextButton.styleFrom(
                      foregroundColor: FirePumpSimColors.red,
                      textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                    ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                    child: Text(showExplanation ? 'Hide explanation' : 'Explanation'),
                  ),
              ],
            ),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: (!hasChecked || !showExplanation)
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        if (problem.formulaBreakdown.isNotEmpty) ...[
                          _ExplanationSection(
                            title: 'Formula breakdown',
                            lines: problem.formulaBreakdown.map((e) => e.toString()).toList(growable: false),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (problem.instructorExplanation.trim().isNotEmpty) ...[
                          _ExplanationSection(
                            title: 'Instructor explanation',
                            lines: [problem.instructorExplanation.trim()],
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (!isCorrect && problem.explainMistake.trim().isNotEmpty)
                          _ExplanationSection(
                            title: 'Common mistake',
                            lines: [problem.explainMistake.trim()],
                            accent: FirePumpSimColors.redSoft,
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _InfoView extends StatelessWidget {
  const _InfoView({required this.problem, required this.unit});

  final PlayableScenarioProblem problem;
  final String unit;

  List<_InfoRow> _parseDetails(List<dynamic> details) {
    final rows = <_InfoRow>[];
    for (final d in details) {
      if (d is Map) {
        final m = Map<String, dynamic>.from(d);
        final label = (m['label'] ?? m['title'] ?? m['name'] ?? '').toString().trim();
        final value = (m['value'] ?? m['text'] ?? m['display'] ?? '').toString().trim();
        if (label.isNotEmpty && value.isNotEmpty) rows.add(_InfoRow(label: label, value: value));
      } else if (d is List && d.length >= 2) {
        final label = d[0].toString().trim();
        final value = d[1].toString().trim();
        if (label.isNotEmpty && value.isNotEmpty) rows.add(_InfoRow(label: label, value: value));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rows = _parseDetails(problem.details);

    final effective = <_InfoRow>[...rows];
    if (!rows.any((r) => r.label.toLowerCase().contains('unit'))) {
      effective.add(_InfoRow(label: 'Expected Answer Unit', value: unit));
    }

    return Container(
      color: FirePumpSimColors.charcoal2,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SCENARIO INFO',
              style: textTheme.labelLarge?.copyWith(
                color: FirePumpSimColors.textHigh,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 12),
            _InfoGrid(rows: effective),
          ],
        ),
      ),
    );
  }
}

@immutable
class _InfoRow {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.rows});
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final textTheme = Theme.of(context).textTheme;
        final twoCol = c.maxWidth >= 420;
        final itemW = twoCol ? (c.maxWidth - 12) / 2 : c.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: rows
              .map(
                (r) => SizedBox(
                  width: itemW,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FirePumpSimColors.charcoal3.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: FirePumpSimColors.textMed,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          r.value,
                          style: textTheme.bodyMedium?.copyWith(
                            color: FirePumpSimColors.textHigh,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.isCorrect});

  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bg = isCorrect
        ? FirePumpSimColors.steel.withValues(alpha: 0.22)
        : FirePumpSimColors.red.withValues(alpha: 0.18);
    final border = isCorrect
        ? FirePumpSimColors.steel.withValues(alpha: 0.6)
        : FirePumpSimColors.red.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCorrect ? Icons.verified_outlined : Icons.error_outline,
            size: 16,
            color: isCorrect ? FirePumpSimColors.textHigh : FirePumpSimColors.redSoft,
          ),
          const SizedBox(width: 6),
          Text(
            isCorrect ? 'Correct' : 'Try again',
            style: textTheme.labelSmall?.copyWith(
              color: FirePumpSimColors.textHigh,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplanationSection extends StatelessWidget {
  const _ExplanationSection({required this.title, required this.lines, this.accent});

  final String title;
  final List<String> lines;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final a = accent ?? FirePumpSimColors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: a.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.labelLarge?.copyWith(
              color: FirePumpSimColors.textHigh,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...lines
              .where((l) => l.trim().isNotEmpty)
              .map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l,
                    style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.5),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}


