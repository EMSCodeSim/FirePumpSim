import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScenarioPacksComingSoonScreen extends StatelessWidget {
  const ScenarioPacksComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FirePumpSimColors.charcoal,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go(AppRoutes.home),
                    icon: const Icon(Icons.arrow_back),
                    color: FirePumpSimColors.textHigh,
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Scenario Library',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: FirePumpSimColors.textHigh,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _ComingSoonCard(),
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

class _ComingSoonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: t, child: child),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: FirePumpSimColors.charcoal2,
            border: Border.all(color: FirePumpSimColors.libraryPurple.withValues(alpha: 0.22), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: FirePumpSimColors.libraryPurple.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: FirePumpSimColors.libraryPurple.withValues(alpha: 0.22), width: 1),
                      ),
                      child: Icon(Icons.auto_stories, color: FirePumpSimColors.textHigh.withValues(alpha: 0.92), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scenario Packs',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: FirePumpSimColors.textHigh,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Browse, download, and train by pack',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Coming soon',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: FirePumpSimColors.textHigh,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This area will organize scenarios into packs (beginner, intermediate, advanced, and specialty).',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.5),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(label: 'Beginner'),
                    _Pill(label: 'Pump panel drills'),
                    _Pill(label: 'Drafting'),
                    _Pill(label: 'Standpipe'),
                    _Pill(label: 'Wildland'),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.practiceScenarios),
                  style: FilledButton.styleFrom(
                    backgroundColor: FirePumpSimColors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.safety_check),
                  label: const Text('Go to Practice Scenarios'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.home),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FirePumpSimColors.textHigh,
                    side: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.9), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(Icons.home, color: FirePumpSimColors.textHigh.withValues(alpha: 0.95)),
                  label: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.9), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
