import 'package:firepumpsim/models/scenario_pack.dart';
import 'package:firepumpsim/models/printable_pack.dart';
import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/services/scenario_pack_repository.dart';
import 'package:firepumpsim/services/scenario_pack_storage.dart';
import 'package:firepumpsim/services/printable_pack_storage.dart';
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
  final _storage = ScenarioPackStorage();
  final _printableStorage = PrintablePackStorage();

  bool _loading = true;
  List<ScenarioPack> _packs = const [];

  final List<PrintablePack> _printablePacks = PrintablePacksCatalog.allPacks().where((p) => !p.isFree).toList(growable: false);
  Set<String> _purchasedPrintablePackIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ScenarioPackRepository(storage: _storage);
      final packs = await repo.loadPacks();
      final printablePurchased = await _printableStorage.loadPurchasedPackIds();
      if (!mounted) return;
      setState(() {
        _packs = packs;
        _purchasedPrintablePackIds = printablePurchased;
      });
    } catch (e) {
      debugPrint('ScenarioLibrary load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlockPack(ScenarioPack pack) async {
    if (pack.isFree) return;
    await _storage.setPurchased(packId: pack.packId, purchased: true);
    await _load();
  }

  Future<void> _unlockPrintablePack(PrintablePack pack) async {
    await _printableStorage.setPurchased(packId: pack.packId, purchased: true);
    await _load();
  }

  bool _printableUnlocked(PrintablePack pack) => _purchasedPrintablePackIds.contains(pack.packId);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final unlocked = _packs.where((p) => p.isFree || p.isPurchased).toList(growable: false);
    final locked = _packs.where((p) => !p.isFree && !p.isPurchased).toList(growable: false);

    final printableUnlocked = _printablePacks.where(_printableUnlocked).toList(growable: false);
    final printableLocked = _printablePacks.where((p) => !_printableUnlocked(p)).toList(growable: false);

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
                'Unlock scenario packs to add them to Practice Scenarios. Daily Challenge uses all bundled scenarios automatically.',
                style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.35),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator(color: FirePumpSimColors.red)))
              else ...[
                _SectionHeader(title: 'Unlocked Packs', subtitle: 'Available in Practice Scenarios', icon: Icons.verified_outlined),
                const SizedBox(height: AppSpacing.sm),
                if (unlocked.isEmpty)
                  _InfoCard(text: 'No packs unlocked yet. The Free Starter Pack will appear here once configured.')
                else
                  for (final p in unlocked) ...[
                    _PackCard(
                      pack: p,
                      locked: false,
                      primaryLabel: 'Open Practice',
                      primaryIcon: Icons.safety_check,
                      onPrimary: () => context.go(AppRoutes.practiceScenarios),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                const SizedBox(height: AppSpacing.md),
                _SectionHeader(title: 'Locked Packs', subtitle: 'Unlock to add to Practice Scenarios', icon: Icons.lock_outline),
                const SizedBox(height: AppSpacing.sm),
                if (locked.isEmpty)
                  _InfoCard(text: 'No locked packs available right now.')
                else
                  for (final p in locked) ...[
                    _PackCard(
                      pack: p,
                      locked: true,
                      primaryLabel: 'Unlock Pack',
                      primaryIcon: Icons.lock_open,
                      onPrimaryAsync: () => _unlockPack(p),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                const SizedBox(height: AppSpacing.md),
                _SectionHeader(title: 'Printable Packs', subtitle: 'Unlock branded printable worksheets', icon: Icons.picture_as_pdf_outlined),
                const SizedBox(height: AppSpacing.sm),
                if (printableUnlocked.isEmpty && printableLocked.isEmpty)
                  const _InfoCard(text: 'No printable packs configured.')
                else ...[
                  if (printableUnlocked.isNotEmpty) ...[
                    _SubHeader(title: 'Unlocked', subtitle: 'Available in Printable Scenarios'),
                    const SizedBox(height: AppSpacing.sm),
                    for (final p in printableUnlocked) ...[
                      _PrintablePackCard(pack: p, locked: false, onTap: () => context.go(AppRoutes.printableScenarios)),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (printableLocked.isNotEmpty) ...[
                    _SubHeader(title: 'Locked', subtitle: 'Unlock to print'),
                    const SizedBox(height: AppSpacing.sm),
                    for (final p in printableLocked) ...[
                      _PrintablePackCard(pack: p, locked: true, onUnlockAsync: () => _unlockPrintablePack(p)),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Expanded(child: Text(title, style: textTheme.titleSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900))),
          Text(subtitle, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed)),
        ],
      ),
    );
  }
}

class _PrintablePackCard extends StatefulWidget {
  const _PrintablePackCard({required this.pack, required this.locked, this.onTap, this.onUnlockAsync});

  final PrintablePack pack;
  final bool locked;
  final VoidCallback? onTap;
  final Future<void> Function()? onUnlockAsync;

  @override
  State<_PrintablePackCard> createState() => _PrintablePackCardState();
}

class _PrintablePackCardState extends State<_PrintablePackCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = widget.locked ? FirePumpSimColors.steel : FirePumpSimColors.printGreen;
    final badgeText = widget.locked ? 'LOCKED' : 'UNLOCKED';

    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.pack.title, style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: 0.65)),
                  ),
                  child: Text(badgeText, style: textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(widget.pack.description, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.4)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(icon: Icons.picture_as_pdf_outlined, label: '${widget.pack.pageCount} pages'),
                const _Pill(icon: Icons.checklist, label: 'Questions + work'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        if (!widget.locked && widget.onTap != null) {
                          widget.onTap!.call();
                          return;
                        }
                        if (widget.locked && widget.onUnlockAsync != null) {
                          setState(() => _busy = true);
                          try {
                            await widget.onUnlockAsync!.call();
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: FirePumpSimColors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                icon: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(widget.locked ? Icons.lock_open : Icons.print_outlined, color: Colors.white),
                label: Text(widget.locked ? 'Unlock Pack' : 'Open Printable Scenarios', style: textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
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
            child: Center(child: Icon(icon, color: FirePumpSimColors.red, size: 20)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
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
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
      ),
      child: Text(text, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.35)),
    );
  }
}

class _PackCard extends StatefulWidget {
  const _PackCard({
    required this.pack,
    required this.locked,
    required this.primaryLabel,
    required this.primaryIcon,
    this.onPrimary,
    this.onPrimaryAsync,
  });

  final ScenarioPack pack;
  final bool locked;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final Future<void> Function()? onPrimaryAsync;

  @override
  State<_PackCard> createState() => _PackCardState();
}

class _PackCardState extends State<_PackCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pack = widget.pack;
    final count = (pack.scenarioCount > 0 ? pack.scenarioCount : pack.scenarioFiles.length);
    final accent = widget.locked ? FirePumpSimColors.steel : FirePumpSimColors.printGreen;
    final badgeText = widget.locked ? 'LOCKED' : (pack.isFree ? 'FREE' : 'UNLOCKED');

    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(pack.title, style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withValues(alpha: 0.65)),
                  ),
                  child: Text(badgeText, style: textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              pack.description,
              style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.4),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(icon: Icons.trending_up, label: pack.difficulty.isEmpty ? 'mixed' : pack.difficulty),
                _Pill(icon: Icons.dashboard, label: '$count scenarios'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        if (widget.onPrimary != null) {
                          widget.onPrimary!.call();
                          return;
                        }
                        if (widget.onPrimaryAsync != null) {
                          setState(() => _busy = true);
                          try {
                            await widget.onPrimaryAsync!.call();
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: FirePumpSimColors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
                icon: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(widget.primaryIcon, color: Colors.white),
                label: Text(widget.primaryLabel, style: textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3,
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
