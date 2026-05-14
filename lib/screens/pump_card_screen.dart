import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/screens/calculator_screen.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
/// This preserves the underlying route/widget state because it does not change
/// routes. It is used from the Scenario Player and other training screens.
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
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 24, offset: const Offset(0, -12)),
              ],
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

class PumpCardReferenceView extends StatefulWidget {
  const PumpCardReferenceView({super.key});

  @override
  State<PumpCardReferenceView> createState() => _PumpCardReferenceViewState();
}

class _PumpCardReferenceViewState extends State<PumpCardReferenceView> {
  String _selectedCategory = 'All';

  List<PumpCardSection> get _visibleSections {
    if (_selectedCategory == 'All') return PumpCardData.sections;
    return PumpCardData.sections.where((s) => s.category == _selectedCategory).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final categories = ['All', ...PumpCardData.categories];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pump Card', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  'Fast reference charts for pump operators. Built for quick use during scenarios.',
                  style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.35),
                ),
                const SizedBox(height: 12),
                const _FormulaHeroCard(),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in categories) ...[
                        _CategoryChip(
                          label: c,
                          selected: _selectedCategory == c,
                          onTap: () => setState(() => _selectedCategory = c),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
          sliver: SliverList.separated(
            itemCount: _visibleSections.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == _visibleSections.length) return const _PumpCardDisclaimer();
              return _PumpCardSectionCard(section: _visibleSections[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _FormulaHeroCard extends StatelessWidget {
  const _FormulaHeroCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [FirePumpSimColors.red.withValues(alpha: 0.24), FirePumpSimColors.charcoal2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Core PDP Formula', style: textTheme.labelLarge?.copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'PDP = NP + FL ± Elevation + Appliance Loss',
            style: textTheme.titleMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900, height: 1.25),
          ),
          const SizedBox(height: 8),
          Text(
            'Most pump problems are just this formula plus the correct chart value.',
            style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? FirePumpSimColors.red : FirePumpSimColors.charcoal2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? FirePumpSimColors.red : FirePumpSimColors.steel.withValues(alpha: 0.9)),
        ),
        child: Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: selected ? Colors.white : FirePumpSimColors.textHigh,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PumpCardSectionCard extends StatelessWidget {
  const _PumpCardSectionCard({required this.section});
  final PumpCardSection section;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: FirePumpSimColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.25)),
                  ),
                  child: Icon(section.icon, color: FirePumpSimColors.redSoft, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section.title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      if (section.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(section.subtitle!, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.3)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (section.formula != null) ...[
              const SizedBox(height: 12),
              _FormulaStrip(text: section.formula!),
            ],
            const SizedBox(height: 12),
            _ChartTable(chart: section.chart),
            if (section.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final n in section.notes) _SimpleNote(text: n),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormulaStrip extends StatelessWidget {
  const _FormulaStrip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
      ),
      child: Text(text, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900, height: 1.35)),
    );
  }
}

class _ChartTable extends StatelessWidget {
  const _ChartTable({required this.chart});
  final PumpChart chart;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final border = FirePumpSimColors.steel.withValues(alpha: 0.65);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: border)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 44,
            horizontalMargin: 10,
            columnSpacing: 18,
            dividerThickness: 0.5,
            headingTextStyle: textTheme.labelSmall?.copyWith(
              color: FirePumpSimColors.textMed,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.35,
            ),
            dataTextStyle: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800, height: 1.2),
            columns: chart.columns.map((c) => DataColumn(label: Text(c))).toList(growable: false),
            rows: chart.rows.map((r) => DataRow(cells: r.map((c) => DataCell(Text(c))).toList(growable: false))).toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _SimpleNote extends StatelessWidget {
  const _SimpleNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: FirePumpSimColors.red, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.35))),
        ],
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
              'Training reference only. Hose coefficients, nozzle pressures, device losses, and SOPs vary by department. Verify with your local pump chart and equipment specs.',
              style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class PumpChart {
  const PumpChart({required this.columns, required this.rows});
  final List<String> columns;
  final List<List<String>> rows;
}

class PumpCardSection {
  const PumpCardSection({
    required this.category,
    required this.title,
    required this.icon,
    required this.chart,
    this.subtitle,
    this.formula,
    this.notes = const [],
  });

  final String category;
  final String title;
  final IconData icon;
  final String? subtitle;
  final String? formula;
  final PumpChart chart;
  final List<String> notes;
}

class PumpCardData {
  static const List<String> categories = ['Friction', 'Smooth Bore', 'Reaction', 'Losses', 'Water', 'Rules'];

  static const List<PumpCardSection> sections = [
    PumpCardSection(
      category: 'Friction',
      title: 'Friction Loss Per 100′',
      subtitle: 'Most-used quick chart for FirePumpSim scenarios.',
      icon: Icons.table_chart_outlined,
      formula: 'FL/100′ = C × (GPM ÷ 100)²',
      chart: PumpChart(
        columns: ['Hose', 'Flow', 'FL/100′', 'C'],
        rows: [
          ['1¾″', '150 GPM', '35 psi', '15.5'],
          ['1¾″', '185 GPM', '53 psi', '15.5'],
          ['1¾″', '200 GPM', '62 psi', '15.5'],
          ['2″', '185 GPM', '27 psi', '8'],
          ['2″', '265 GPM', '56 psi', '8'],
          ['2½″', '250 GPM', '13 psi', '2'],
          ['2½″', '300 GPM', '18 psi', '2'],
          ['3″', '500 GPM', '20 psi', '0.8'],
          ['4″ LDH', '1000 GPM', '20 psi', '0.2'],
          ['5″ LDH', '1000 GPM', '8 psi', '0.08'],
        ],
      ),
      notes: ['Multiply FL/100′ by hose length in hundreds of feet.', 'Use department-tested values when available.'],
    ),
    PumpCardSection(
      category: 'Friction',
      title: 'Hose Coefficient Quick Chart',
      subtitle: 'Use these C values with the FirePumpSim formula.',
      icon: Icons.straighten,
      chart: PumpChart(
        columns: ['Hose', 'C value', 'Typical use'],
        rows: [
          ['1″', '55', 'Wildland / forestry'],
          ['1½″', '24', 'Wildland / skid load'],
          ['1¾″', '15.5', 'Attack line'],
          ['2″', '8', 'High-flow attack'],
          ['2½″', '2', 'Handline / supply'],
          ['3″', '0.8', 'Supply / master stream'],
          ['4″ LDH', '0.2', 'Supply / relay'],
          ['5″ LDH', '0.08', 'Supply / relay'],
        ],
      ),
    ),
    PumpCardSection(
      category: 'Smooth Bore',
      title: 'Smooth Bore Handline Flow',
      subtitle: 'Handline tips at 50 psi nozzle pressure.',
      icon: Icons.water_drop_outlined,
      formula: 'GPM = 29.7 × diameter² × √NP',
      chart: PumpChart(
        columns: ['Tip', 'NP', 'Flow'],
        rows: [
          ['7/8″', '50 psi', '160 GPM'],
          ['15/16″', '50 psi', '185 GPM'],
          ['1″', '50 psi', '210 GPM'],
          ['1⅛″', '50 psi', '265 GPM'],
          ['1¼″', '50 psi', '330 GPM'],
        ],
      ),
    ),
    PumpCardSection(
      category: 'Smooth Bore',
      title: 'Smooth Bore Master Stream Flow',
      subtitle: 'Deck gun / monitor tips at 80 psi nozzle pressure.',
      icon: Icons.water,
      formula: 'GPM = 29.7 × diameter² × √NP',
      chart: PumpChart(
        columns: ['Tip', 'NP', 'Flow'],
        rows: [
          ['1¼″', '80 psi', '415 GPM'],
          ['1⅜″', '80 psi', '500 GPM'],
          ['1½″', '80 psi', '600 GPM'],
          ['1¾″', '80 psi', '805 GPM'],
          ['2″', '80 psi', '1050 GPM'],
        ],
      ),
    ),
    PumpCardSection(
      category: 'Reaction',
      title: 'Fog Nozzle Reaction',
      subtitle: 'Quick reaction-force chart.',
      icon: Icons.speed_outlined,
      formula: 'Fog NR = 0.0505 × GPM × √NP',
      chart: PumpChart(
        columns: ['Flow', 'NP', 'Reaction'],
        rows: [
          ['150 GPM', '50 psi', '54 lb'],
          ['185 GPM', '50 psi', '66 lb'],
          ['265 GPM', '50 psi', '95 lb'],
          ['150 GPM', '100 psi', '76 lb'],
          ['185 GPM', '100 psi', '93 lb'],
          ['265 GPM', '100 psi', '134 lb'],
        ],
      ),
    ),
    PumpCardSection(
      category: 'Reaction',
      title: 'Smooth Bore Nozzle Reaction',
      subtitle: 'Handline smooth bore reaction at 50 psi.',
      icon: Icons.speed,
      formula: 'Smooth Bore NR = 1.57 × diameter² × NP',
      chart: PumpChart(
        columns: ['Tip', 'NP', 'Reaction'],
        rows: [
          ['7/8″', '50 psi', '60 lb'],
          ['15/16″', '50 psi', '69 lb'],
          ['1″', '50 psi', '79 lb'],
          ['1⅛″', '50 psi', '99 lb'],
          ['1¼″', '50 psi', '123 lb'],
        ],
      ),
    ),
    PumpCardSection(
      category: 'Losses',
      title: 'Appliance / System Losses',
      subtitle: 'Common training defaults.',
      icon: Icons.account_tree_outlined,
      chart: PumpChart(
        columns: ['Item', 'Add'],
        rows: [
          ['Wye', '+10 psi'],
          ['Siamese', '+10 psi'],
          ['Portable monitor', '0–25 psi'],
          ['Standpipe / FDC', '+25 psi'],
          ['Sprinkler FDC target', '150 psi typical'],
          ['Relay receiving intake', '20 psi target'],
        ],
      ),
      notes: ['Use the scenario value when provided. Local equipment may require different losses.'],
    ),
    PumpCardSection(
      category: 'Losses',
      title: 'Elevation Quick Chart',
      subtitle: 'Use for uphill/downhill and floor problems.',
      icon: Icons.height,
      formula: 'Elevation ≈ 0.5 psi per foot',
      chart: PumpChart(
        columns: ['Change', 'Add/Subtract'],
        rows: [
          ['10 ft', '5 psi'],
          ['20 ft', '10 psi'],
          ['30 ft', '15 psi'],
          ['40 ft', '20 psi'],
          ['50 ft', '25 psi'],
          ['1st floor', '0 psi'],
          ['2nd floor', '5 psi'],
          ['3rd floor', '10 psi'],
          ['4th floor', '15 psi'],
        ],
      ),
      notes: ['FirePumpSim floor rule: 1st floor = 0′, 2nd = 10′, 3rd = 20′, 4th = 30′.'],
    ),
    PumpCardSection(
      category: 'Water',
      title: 'Hydrant Pressure Drop / Available Flow',
      subtitle: 'Quick hydrant math reminders.',
      icon: Icons.local_fire_department_outlined,
      chart: PumpChart(
        columns: ['Task', 'Formula / Rule'],
        rows: [
          ['Pressure drop', 'Static − residual'],
          ['Minimum residual', '20 psi'],
          ['Good drop', '≤ 10%'],
          ['Watch closely', '10–25%'],
          ['Near max', '> 25%'],
          ['Added hydrant lines', 'Round DOWN'],
        ],
      ),
      notes: ['For available-flow formula problems, use the calculator/formula screen. This chart is for fast field interpretation.'],
    ),
    PumpCardSection(
      category: 'Water',
      title: 'Relay / Tender Shuttle',
      subtitle: 'Rural water supply quick checks.',
      icon: Icons.route_outlined,
      chart: PumpChart(
        columns: ['Problem', 'Formula'],
        rows: [
          ['Relay PDP', 'Supply FL + elevation + intake target'],
          ['Engine spacing', 'Usable pressure ÷ FL/100 × 100'],
          ['Tender usable water', 'Tank size × 0.90'],
          ['Cycle time', 'Fill + travel + dump + return'],
          ['Shuttle GPM', 'Usable gallons ÷ cycle minutes'],
          ['Tenders needed', 'Required GPM ÷ one-tender GPM'],
        ],
      ),
    ),
    PumpCardSection(
      category: 'Rules',
      title: 'Rules of Thumb',
      subtitle: 'Fast checks for scenario solving.',
      icon: Icons.rule_outlined,
      chart: PumpChart(
        columns: ['Rule', 'Quick value'],
        rows: [
          ['PDP', 'NP + FL ± elevation + appliance'],
          ['Elevation', '5 psi per 10 ft'],
          ['Residential floor', '≈ 5 psi per floor above 1st'],
          ['Wye', 'Highest-pressure branch governs'],
          ['Dual supply', 'Split GPM between equal lines'],
          ['Smooth bore handline NP', '50 psi'],
          ['Master stream NP', '80 psi'],
          ['Standpipe/FDC loss', '25 psi'],
          ['Relay intake target', '20 psi'],
        ],
      ),
    ),
    PumpCardSection(
      category: 'Rules',
      title: 'Common Scenario Setups',
      subtitle: 'Fast examples used in FirePumpSim.',
      icon: Icons.fact_check_outlined,
      chart: PumpChart(
        columns: ['Setup', 'Pump math'],
        rows: [
          ['200′ 1¾″, 185 @ 50', '50 + 106 = 155 psi'],
          ['300′ 1¾″, 185 @ 50', '50 + 159 = 210 psi'],
          ['200′ 2″, 265 @ 50', '50 + 112 = 160 psi'],
          ['200′ 2½″, 265 @ 50', '50 + 28 = 80 psi'],
          ['2 × 200′ 2½″ to 500 GPM monitor', '80 + 25 = 105 psi'],
          ['800′ 5″ LDH @ 1000 GPM relay', '64 + 20 = 85 psi'],
        ],
      ),
    ),
  ];
}
