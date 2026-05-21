import 'package:firepumpsim/models/scenario_pack.dart';
import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/services/scenario_pack_repository.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScenarioLibraryScreen extends StatefulWidget {
  const ScenarioLibraryScreen({super.key});

  @override
  State<ScenarioLibraryScreen> createState() => _ScenarioLibraryScreenState();
}

class _ScenarioLibraryScreenState extends State<ScenarioLibraryScreen> {
  bool _loading = true;
  List<ScenarioPack> _freePacks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final packs = await const ScenarioPackRepository().loadPacks();
      if (!mounted) return;
      setState(() {
        _freePacks = packs.where((p) => p.isFree || p.packId == 'free_starter_pack').toList(growable: false);
      });
    } catch (e) {
      debugPrint('ScenarioLibrary load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: FirePumpSimColors.charcoal,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: FirePumpSimColors.red,
          backgroundColor: FirePumpSimColors.charcoal2,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 110),
            children: [
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.home),
                style: TextButton.styleFrom(
                  foregroundColor: FirePumpSimColors.textHigh,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                icon: const Icon(Icons.arrow_back, color: FirePumpSimColors.textHigh),
                label: Text('Back to Main Menu', style: textTheme.titleSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 8),
              Text('Scenario Library', style: textTheme.headlineSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                'The current app includes the Free Starter Pack. More digital scenario packs and printable worksheet packs are planned, but paid packs are not active yet.',
                style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.35),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator(color: FirePumpSimColors.red)))
              else ...[
                _SectionHeader(title: 'Included Now', subtitle: 'Ready for practice', icon: Icons.verified_outlined),
                const SizedBox(height: AppSpacing.sm),
                if (_freePacks.isEmpty)
                  const _InfoCard(text: 'Free Starter Pack is not configured yet. Check assets/scenarios/scenario-packs.json.')
                else
                  for (final p in _freePacks) ...[
                    _IncludedPackCard(
                      pack: p,
                      onOpen: () => context.go(AppRoutes.practiceScenarios),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                const SizedBox(height: AppSpacing.md),
                _SectionHeader(title: 'Coming Soon', subtitle: 'Not available yet', icon: Icons.upcoming_outlined),
                const SizedBox(height: AppSpacing.sm),
                _ComingSoonCard(
                  title: 'Digital Scenario Packs',
                  subtitle: 'Additional pump operator problems for standpipe, relay, master stream, water supply, wildland, and specialty operations.',
                  icon: Icons.local_fire_department_outlined,
                  accent: FirePumpSimColors.libraryPurple,
                  bullets: const [
                    'No paid digital packs are active in this build.',
                    'Future packs can be added after the scenario content is ready.',
                    'Practice Scenarios currently uses the included starter content.',
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _ComingSoonCard(
                  title: 'Printable Scenario Packs',
                  subtitle: 'Branded worksheet sets for company drills, engineer practice, and instructor-led pump training.',
                  icon: Icons.picture_as_pdf_outlined,
                  accent: FirePumpSimColors.printGreen,
                  bullets: const [
                    'The starter printable tools remain available.',
                    'Additional printable packs will be added later.',
                    'No fake unlock or test-purchase buttons are shown.',
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle, required this.icon});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: FirePumpSimColors.red),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900))),
        Text(subtitle, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed)),
      ],
    );
  }
}

class _IncludedPackCard extends StatelessWidget {
  const _IncludedPackCard({required this.pack, required this.onOpen});

  final ScenarioPack pack;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: FirePumpSimColors.red.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.safety_check, color: FirePumpSimColors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pack.title, style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text('${pack.scenarioCount} scenarios • Included', style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed)),
                  ],
                ),
              ),
              _StatusPill(label: 'FREE', color: FirePumpSimColors.printGreen),
            ],
          ),
          const SizedBox(height: 12),
          Text(pack.description, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.4)),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: FirePumpSimColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: Text('Open Practice Scenarios', style: textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.title, required this.subtitle, required this.icon, required this.accent, required this.bullets});

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900))),
              _StatusPill(label: 'COMING SOON', color: accent),
            ],
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.4)),
          const SizedBox(height: 12),
          for (final bullet in bullets) _FeatureRow(text: bullet, accent: accent),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.35))),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

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
      child: Text(label, style: textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.7)),
      ),
      child: Text(text, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.4)),
    );
  }
}
