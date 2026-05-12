import 'package:firepumpsim/theme.dart';
import 'package:flutter/material.dart';
import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/screens/calculator_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class PumpCardScreen extends StatelessWidget {
  const PumpCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pump Card'),
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Home',
          onPressed: () => context.go(AppRoutes.home),
          icon: const Icon(Icons.home_outlined),
        ),
        actions: [
          IconButton(
            tooltip: 'Calculator',
            onPressed: () => showCalculatorOverlay(context),
            icon: const Icon(Icons.calculate_outlined, color: FirePumpSimColors.textHigh),
          ),
        ],
      ),
      body: const SafeArea(child: PumpCardReferenceView()),
    );
  }
}

/// Opens the pump card reference as a modal overlay.
///
/// This preserves the underlying route/widget state (ex: Scenario Player progress)
/// because it does not change routes.
Future<void> showPumpCardOverlay(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (context) => const _PumpCardOverlaySheet(),
  );
}

class _PumpCardOverlaySheet extends StatelessWidget {
  const _PumpCardOverlaySheet();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewInsetsOf(context).top;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: FirePumpSimColors.charcoal,
              border: Border(top: BorderSide(color: FirePumpSimColors.red.withValues(alpha: 0.12), width: 1)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 24, offset: const Offset(0, -12))],
            ),
            child: SizedBox(
              height: (MediaQuery.sizeOf(context).height * 0.92).clamp(520.0, 860.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: FirePumpSimColors.steel.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.close, color: FirePumpSimColors.textHigh),
                          style: IconButton.styleFrom(
                            backgroundColor: FirePumpSimColors.charcoal2,
                            side: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.9)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(child: PumpCardReferenceView()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable pump card reference body.
///
/// Used by both the full screen route and the in-scenario modal overlay.
class PumpCardReferenceView extends StatefulWidget {
  const PumpCardReferenceView({super.key});

  @override
  State<PumpCardReferenceView> createState() => _PumpCardReferenceViewState();
}

class _PumpCardReferenceViewState extends State<PumpCardReferenceView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final categories = PumpCardCatalog.categories;
    final filtered = _query.trim().isEmpty
        ? categories
        : categories
            .map((c) => c.filtered(_query))
            .where((c) => c.blocks.isNotEmpty)
            .toList(growable: false);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pump Card', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  'Quick field reference (offline). Values vary by hose/nozzle/SOP—confirm locally.',
                  style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.35),
                ),
                const SizedBox(height: AppSpacing.md),
                _PumpCardSearchBar(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: filtered.isEmpty ? _PumpCardEmptyState(query: _query) : _PumpCardCategoryList(categories: filtered),
            ),
          ),
        ),
      ],
    );
  }
}

class _PumpCardSearchBar extends StatelessWidget {
  const _PumpCardSearchBar({required this.controller, required this.onChanged, required this.onClear});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline.withValues(alpha: 0.55);
    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: outline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.search, color: FirePumpSimColors.textMed.withValues(alpha: 0.9), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: theme.textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textHigh),
              cursorColor: FirePumpSimColors.red,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search pump card…',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed.withValues(alpha: 0.7)),
                border: InputBorder.none,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.text.trim().isEmpty) return const SizedBox.shrink();
              return IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close),
                color: FirePumpSimColors.textMed.withValues(alpha: 0.85),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Clear',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PumpCardEmptyState extends StatelessWidget {
  const _PumpCardEmptyState({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No matches', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            'Try “1¾”, “C value”, “standpipe”, “smooth bore”, “relay”, “tender”, or a flow like “150”.\n\nSearch: “$query”',
            style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _PumpCardCategoryList extends StatelessWidget {
  const _PumpCardCategoryList({required this.categories});
  final List<PumpCardCategory> categories;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final c in categories) {
      children.add(_PumpCardCategoryCard(category: c));
      children.add(const SizedBox(height: AppSpacing.md));
    }
    children.add(const _PumpCardDisclaimer());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _PumpCardCategoryCard extends StatelessWidget {
  const _PumpCardCategoryCard({required this.category});
  final PumpCardCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.75)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          collapsedIconColor: FirePumpSimColors.textMed.withValues(alpha: 0.85),
          iconColor: FirePumpSimColors.red,
          title: Text(category.title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          subtitle: category.subtitle == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    category.subtitle!,
                    style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed.withValues(alpha: 0.9), height: 1.3),
                  ),
                ),
          children: [
            for (int i = 0; i < category.blocks.length; i++) ...[
              _PumpCardBlockCard(block: category.blocks[i]),
              if (i != category.blocks.length - 1) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _PumpCardBlockCard extends StatelessWidget {
  const _PumpCardBlockCard({required this.block});
  final PumpCardBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.45)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          collapsedIconColor: FirePumpSimColors.textMed.withValues(alpha: 0.8),
          iconColor: FirePumpSimColors.red,
          title: Text(block.title, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
          subtitle: block.subtitle == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    block.subtitle!,
                    style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed.withValues(alpha: 0.9), height: 1.3),
                  ),
                ),
          children: [
            if (block.formula != null) ...[
              const SizedBox(height: 6),
              _MonoEquationText(equation: block.formula!),
            ],
            if (block.table != null) ...[
              const SizedBox(height: 10),
              _CompactTable(table: block.table!),
            ],
            if (block.bullets.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final b in block.bullets) _BulletLine(text: b),
            ],
            if (block.note != null) ...[
              const SizedBox(height: 10),
              _NoteBox(text: block.note!),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonoEquationText extends StatelessWidget {
  const _MonoEquationText({required this.equation});
  final String equation;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium ?? const TextStyle(fontSize: 16);
    return Text(
      equation,
      style: GoogleFonts.robotoMono(
        textStyle: base.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900, letterSpacing: 0.2, height: 1.25),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              height: 6,
              width: 6,
              decoration: BoxDecoration(
                color: FirePumpSimColors.red,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textHigh, height: 1.45))),
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.22)),
      ),
      child: Text(text, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.5)),
    );
  }
}

class _CompactTable extends StatelessWidget {
  const _CompactTable({required this.table});
  final PumpCardTable table;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final border = FirePumpSimColors.steel.withValues(alpha: 0.55);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: border)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 38,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 44,
            dividerThickness: 0.6,
            horizontalMargin: 12,
            columnSpacing: 18,
            headingTextStyle: textTheme.labelSmall?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w900, letterSpacing: 0.4),
            dataTextStyle: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800),
            columns: table.columns.map((c) => DataColumn(label: Text(c))).toList(growable: false),
            rows: table.rows
                .map(
                  (r) => DataRow(
                    cells: r.map((c) => DataCell(Text(c))).toList(growable: false),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _PumpCardDisclaimer extends StatelessWidget {
  const _PumpCardDisclaimer();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.75)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: FirePumpSimColors.red.withValues(alpha: 0.9), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Training reference only. Coefficients, nozzle pressures, and device losses vary by equipment and SOP. Verify locally.',
              style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Offline catalog
// =============================================================================

class PumpCardTable {
  const PumpCardTable({required this.columns, required this.rows});
  final List<String> columns;
  final List<List<String>> rows;

  bool matchesQuery(String query) {
    final q = query.toLowerCase();
    bool contains(String s) => s.toLowerCase().contains(q);
    if (columns.any(contains)) return true;
    for (final r in rows) {
      if (r.any(contains)) return true;
    }
    return false;
  }
}

class PumpCardBlock {
  const PumpCardBlock({required this.title, this.subtitle, this.formula, this.table, this.bullets = const [], this.note, this.keywords = const []});

  final String title;
  final String? subtitle;
  final String? formula;
  final PumpCardTable? table;
  final List<String> bullets;
  final String? note;
  final List<String> keywords;

  bool matchesQuery(String query) {
    final q = query.toLowerCase();
    bool contains(String s) => s.toLowerCase().contains(q);
    if (contains(title)) return true;
    if (subtitle != null && contains(subtitle!)) return true;
    if (formula != null && contains(formula!)) return true;
    if (note != null && contains(note!)) return true;
    if (table != null && table!.matchesQuery(query)) return true;
    if (bullets.any(contains)) return true;
    if (keywords.any(contains)) return true;
    return false;
  }
}

class PumpCardCategory {
  const PumpCardCategory({required this.title, this.subtitle, required this.blocks});
  final String title;
  final String? subtitle;
  final List<PumpCardBlock> blocks;

  PumpCardCategory filtered(String query) => PumpCardCategory(
        title: title,
        subtitle: subtitle,
        blocks: blocks
            .where((b) => b.matchesQuery(query) || title.toLowerCase().contains(query.toLowerCase()))
            .toList(growable: false),
      );
}

class PumpCardCatalog {
  static const List<PumpCardCategory> categories = [
    PumpCardCategory(
      title: 'Friction Loss Per 100′',
      subtitle: 'Quick estimates. Use department hose tests when available.',
      blocks: [
        PumpCardBlock(
          title: 'Common hose coefficients (C values)',
          subtitle: 'Used with FL = C × Q² × L',
          table: PumpCardTable(
            columns: ['Hose', 'C value', 'Notes'],
            rows: [
              ['1″ wildland', '≈ 55', 'Varies widely by hose/nozzle setup'],
              ['1½″ wildland', '≈ 24', 'Varies widely; confirm locally'],
              ['1¾″ attack', '15.5', 'Common training value'],
              ['2″ attack', '8', 'Common training value'],
              ['2½″', '2', 'Common training value'],
              ['3″ supply', '0.8', 'Common training value'],
              ['4″ LDH', '0.2', 'Common training value'],
              ['5″ LDH', '0.08', 'Common training value'],
            ],
          ),
          keywords: ['c', 'coefficient'],
          note: 'These are training defaults. Hose construction, coupling friction, and flow regime change results.',
        ),
        PumpCardBlock(
          title: 'Estimated FL/100′ at common flows',
          subtitle: 'Computed with FL/100 = C × (GPM/100)² using typical C values.',
          table: PumpCardTable(
            columns: ['Hose', 'GPM', 'FL/100′ (psi)', 'C'],
            rows: [
              ['1¾″', '150', '≈ 35', '15.5'],
              ['1¾″', '185', '≈ 53', '15.5'],
              ['2″', '185', '≈ 27', '8'],
              ['2½″', '250', '≈ 12.5', '2'],
              ['2½″', '300', '≈ 18', '2'],
              ['3″', '500', '≈ 20', '0.8'],
              ['4″ LDH', '1,000', '≈ 20', '0.2'],
              ['5″ LDH', '1,000', '≈ 8', '0.08'],
            ],
          ),
          note: 'Treat as ballpark numbers for training. Always use your agency’s chart where provided.',
          keywords: ['fl', 'per 100', 'attack', 'ldh'],
        ),
      ],
    ),
    PumpCardCategory(
      title: 'Attack Line Reference',
      subtitle: 'Common training set-ups (NP + typical flows).',
      blocks: [
        PumpCardBlock(
          title: 'Example flows',
          table: PumpCardTable(
            columns: ['Line', 'Typical GPM', 'Common NP'],
            rows: [
              ['1¾″ fog', '150', '50 or 100 psi (nozzle dependent)'],
              ['1¾″ fog', '185', '50 or 100 psi'],
              ['2″ fog', '185', '50 or 100 psi'],
              ['2½″ fog', '250', '50 or 100 psi'],
              ['2½″ fog', '300', '50 or 100 psi'],
              ['1¾″ smooth bore', 'varies by tip', '50 psi'],
              ['2½″ smooth bore', 'varies by tip', '50 psi'],
            ],
          ),
          note: 'Nozzle pressures vary by make/model and SOP. Smooth bore flows are tip-dependent.',
        ),
      ],
    ),
    PumpCardCategory(
      title: 'Wildland Pump Card',
      subtitle: 'Long lays + elevation are usually the driver.',
      blocks: [
        PumpCardBlock(
          title: 'Wildland reminders',
          bullets: [
            'Elevation rule of thumb: about 0.5 PSI per foot',
            'Uphill adds pressure, downhill subtracts pressure',
            'Progressive hose lay: upstream segments carry more flow once laterals open',
            'Portable pumps must overcome FL + elevation + nozzle pressure at the nozzle',
          ],
          keywords: ['wui', 'progressive lay', 'portable pump'],
        ),
        PumpCardBlock(
          title: 'Common wildland hose flows',
          table: PumpCardTable(
            columns: ['Hose', 'Common flows (GPM)', 'Notes'],
            rows: [
              ['1″', '10–50', 'Depends on nozzle and terrain'],
              ['1½″', '30–100', 'Often used for progressive lays'],
            ],
          ),
        ),
      ],
    ),
    PumpCardCategory(
      title: 'Smooth Bore Tip Flow',
      subtitle: 'Use: GPM = 29.7 × d² × √NP',
      blocks: [
        PumpCardBlock(
          title: 'Handline smooth bore (NP 50 PSI)',
          formula: 'GPM = 29.7 × d² × √NP',
          table: PumpCardTable(
            columns: ['Tip', 'NP', 'GPM (approx)'],
            rows: [
              ['7/8″', '50', '≈ 161'],
              ['15/16″', '50', '≈ 187'],
              ['1″', '50', '≈ 210'],
              ['1 1/8″', '50', '≈ 266'],
            ],
          ),
          note: 'These are approximations for training. If your department uses a different coefficient/value, update accordingly.',
          keywords: ['smooth bore', 'tip', '50'],
        ),
        PumpCardBlock(
          title: 'Master stream smooth bore (NP 80 PSI)',
          formula: 'GPM = 29.7 × d² × √NP',
          table: PumpCardTable(
            columns: ['Tip', 'NP', 'GPM (approx)'],
            rows: [
              ['1 1/4″', '80', '≈ 413'],
              ['1 3/8″', '80', '≈ 500'],
              ['1 1/2″', '80', '≈ 592'],
              ['1 3/4″', '80', '≈ 806'],
              ['2″', '80', '≈ 1,053'],
            ],
          ),
          keywords: ['master stream', 'monitor', '80'],
        ),
      ],
    ),
    PumpCardCategory(
      title: 'Nozzle Reaction',
      subtitle: 'Quick reference formulas + examples.',
      blocks: [
        PumpCardBlock(
          title: 'Fog nozzle reaction',
          formula: 'Fog NR = 0.0505 × GPM × √NP',
          bullets: [
            'Example: 150 GPM @ 100 PSI → NR ≈ 0.0505 × 150 × 10 = 75.8 lb',
          ],
          keywords: ['nr', 'fog'],
        ),
        PumpCardBlock(
          title: 'Smooth bore nozzle reaction',
          formula: 'Smooth bore NR = 1.57 × d² × NP',
          bullets: [
            'Example: 7/8″ @ 50 PSI → NR ≈ 1.57 × 0.875² × 50 ≈ 60 lb',
          ],
          keywords: ['nr', 'smooth bore'],
        ),
      ],
    ),
    PumpCardCategory(
      title: 'Standpipe Quick Card',
      subtitle: 'Build-up reminders and common shortcuts.',
      blocks: [
        PumpCardBlock(
          title: 'Standpipe build-up',
          bullets: [
            'Common FDC/system loss: 25 PSI (department dependent)',
            'Elevation estimate by floor: ~10 PSI per residential floor (shortcut)',
            '1st floor = 0 ft; 2nd = 10 ft; 3rd = 20 ft',
            'Add hose pack FL from outlet to nozzle',
            'Calculate elevation to outlet floor, not roof',
          ],
          keywords: ['fdc', 'floor', '25'],
        ),
      ],
    ),
    PumpCardCategory(
      title: 'Relay / Water Supply Quick Card',
      subtitle: 'Spacing and intake targets.',
      blocks: [
        PumpCardBlock(
          title: 'Relay reminders',
          bullets: [
            'Maintain intake/residual target, commonly 20 PSI',
            'Calculate FL in supply hose using flow per line',
            'Engine spacing = usable pressure / FL per 100′ × 100',
            'Relay PDP = FL to next engine + desired intake pressure (add elevation/appliances as needed)',
          ],
          keywords: ['relay', 'spacing', '20 psi'],
        ),
      ],
    ),
    PumpCardCategory(
      title: 'Tender / Tanker Shuttle Quick Card',
      subtitle: 'Cycle-time planning for rural water supply.',
      blocks: [
        PumpCardBlock(
          title: 'Shuttle planning',
          bullets: [
            'Cycle time = fill + travel to scene + dump + travel back',
            'Shuttle GPM = usable tank gallons ÷ cycle time (min)',
            'Tenders needed = required GPM ÷ one-tender shuttle GPM (round up)',
            'Account for dump/fill constraints and reserve if required',
          ],
          keywords: ['tanker', 'tender', 'shuttle'],
        ),
      ],
    ),
    PumpCardCategory(
      title: 'Rules of Thumb',
      subtitle: 'Fast checks—still verify with SOPs and charts.',
      blocks: [
        PumpCardBlock(
          title: 'Operational shortcuts',
          bullets: [
            '5 PSI per 10 ft elevation (shortcut) or 0.434 PSI/ft (physics)',
            '10 PSI per residential floor (shortcut)',
            'Highest-pressure branch controls wye calculations',
            'Divide flow between equal supply lines',
            'Open/close valves slowly (water hammer safety)',
            'Keep intake residual pressure (avoid cavitation)',
            'Follow department SOPs and equipment specs',
          ],
          keywords: ['water hammer', 'safety', 'wye'],
        ),
      ],
    ),
  ];
}
