import 'package:firepumpsim/models/scenario_pack.dart';
import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/services/scenario_pack_repository.dart';
import 'package:firepumpsim/services/scenario_pack_storage.dart';
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
  final ScenarioPackStorage _packStorage = ScenarioPackStorage();

  bool _loading = true;
  List<ScenarioPack> _includedPacks = const [];
  List<ScenarioPack> _paidPacks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final packs = await ScenarioPackRepository(storage: _packStorage).loadPacks();
      if (!mounted) return;
      setState(() {
        _includedPacks = packs.where((p) => p.isFree).toList(growable: false);
        _paidPacks = packs.where((p) => !p.isFree).toList(growable: false);
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
                'Browse included scenarios and paid add-on packs. Purchased packs appear in Practice Scenarios after they are unlocked.',
                style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.35),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator(color: FirePumpSimColors.red)))
              else ...[
                _SectionHeader(title: 'Included Now', subtitle: 'Ready for practice', icon: Icons.verified_outlined),
                const SizedBox(height: AppSpacing.sm),
                if (_includedPacks.isEmpty)
                  const _InfoCard(text: 'No included packs are configured yet. Check assets/scenarios/scenario-packs.json.')
                else
                  for (final p in _includedPacks) ...[
                    _PackCard(
                      pack: p,
                      statusLabel: p.isFree ? 'FREE' : 'UNLOCKED',
                      statusColor: p.isFree ? FirePumpSimColors.printGreen : FirePumpSimColors.libraryPurple,
                      buttonLabel: 'Open Practice Scenarios',
                      buttonIcon: Icons.play_arrow,
                      onPressed: () => context.go(AppRoutes.practiceScenarios),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                const SizedBox(height: AppSpacing.md),
                _SectionHeader(title: 'Paid Add-On Packs', subtitle: 'One-time unlocks', icon: Icons.workspace_premium_outlined),
                const SizedBox(height: AppSpacing.sm),
                if (_paidPacks.isEmpty)
                  const _InfoCard(text: 'No paid scenario packs are configured yet.')
                else
                  for (final p in _paidPacks) ...[
                    _PackCard(
                      pack: p,
                      statusLabel: p.isPurchased ? 'UNLOCKED' : 'LOCKED',
                      statusColor: p.isPurchased ? FirePumpSimColors.printGreen : FirePumpSimColors.libraryPurple,
                      buttonLabel: p.isPurchased ? 'Open Practice Scenarios' : 'Available after purchase',
                      buttonIcon: p.isPurchased ? Icons.play_arrow : Icons.lock_outline,
                      onPressed: p.isPurchased ? () => context.go(AppRoutes.practiceScenarios) : null,
                      lockedNote: p.isPurchased ? null : 'Connect this pack to the non-consumable in-app purchase firepumpsim.pump_ops_pack_01.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
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

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.statusLabel,
    required this.statusColor,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.onPressed,
    this.lockedNote,
  });

  final ScenarioPack pack;
  final String statusLabel;
  final Color statusColor;
  final String buttonLabel;
  final IconData buttonIcon;
  final VoidCallback? onPressed;
  final String? lockedNote;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final locked = onPressed == null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: statusColor.withValues(alpha: 0.55)),
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
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Icon(locked ? Icons.lock_outline : Icons.safety_check, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pack.title, style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text('${pack.scenarioCount} scenarios • ${pack.difficulty.isEmpty ? 'Mixed difficulty' : pack.difficulty}', style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed)),
                  ],
                ),
              ),
              _StatusPill(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(pack.description, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.4)),
          if (lockedNote != null) ...[
            const SizedBox(height: 10),
            Text(lockedNote!, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.35)),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: locked ? FirePumpSimColors.charcoal3 : FirePumpSimColors.red,
              disabledBackgroundColor: FirePumpSimColors.charcoal3,
              disabledForegroundColor: FirePumpSimColors.textMed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
            icon: Icon(buttonIcon, color: locked ? FirePumpSimColors.textMed : Colors.white),
            label: Text(buttonLabel, style: textTheme.titleSmall?.copyWith(color: locked ? FirePumpSimColors.textMed : Colors.white, fontWeight: FontWeight.w900)),
          ),
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
