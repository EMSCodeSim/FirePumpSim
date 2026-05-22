import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/screens/calculator_screen.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class FormulasScreen extends StatelessWidget {
  const FormulasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulas'),
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
      body: const SafeArea(child: FormulasReferenceView()),
    );
  }
}

/// Opens the formulas reference as a modal overlay.
///
/// This preserves the underlying route/widget state because it does not change
/// routes. Scenario Player can open this and return without losing progress.
Future<void> showFormulasOverlay(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (context) => const _FormulasOverlaySheet(),
  );
}

class _FormulasOverlaySheet extends StatelessWidget {
  const _FormulasOverlaySheet();

  @override
  Widget build(BuildContext context) {
    final topSafe = MediaQuery.paddingOf(context).top;
    return SafeArea(
      top: true,
      child: Padding(
        padding: EdgeInsets.only(top: topSafe),
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
                  const Expanded(child: FormulasReferenceView(compactHeader: true)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FormulasReferenceView extends StatefulWidget {
  const FormulasReferenceView({super.key, this.compactHeader = false});

  final bool compactHeader;

  @override
  State<FormulasReferenceView> createState() => _FormulasReferenceViewState();
}

class _FormulasReferenceViewState extends State<FormulasReferenceView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FormulaQuickItem> get _filteredItems {
    final q = _query.trim().toLowerCase();
    return FormulaCatalog.items.where((item) {
      final categoryMatch = _selectedCategory == 'All' || item.category == _selectedCategory;
      final searchMatch = q.isEmpty || item.matches(q);
      return categoryMatch && searchMatch;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
      children: [
        if (!widget.compactHeader) ...[
          Text('Quick Formulas', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            'Simple driver/operator reference for pump problems.',
            style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const _MainFormulaCard(),
        const SizedBox(height: AppSpacing.md),
        _SimpleSearchBar(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          onClear: () {
            _searchController.clear();
            setState(() => _query = '');
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _CategoryChips(
          selected: _selectedCategory,
          onSelected: (category) => setState(() => _selectedCategory = category),
        ),
        const SizedBox(height: AppSpacing.md),
        if (items.isEmpty)
          _EmptyFormulaState(query: _query)
        else
          for (int i = 0; i < items.length; i++) ...[
            _FormulaQuickCard(item: items[i]),
            if (i != items.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.md),
        const _FormulaDisclaimer(),
      ],
    );
  }
}

class _MainFormulaCard extends StatelessWidget {
  const _MainFormulaCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FirePumpSimColors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: FirePumpSimColors.red.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.local_fire_department_outlined, color: FirePumpSimColors.redSoft),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Start here for most pump problems', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BigEquation('PDP = NP + FL ± Elevation + Appliance Loss'),
          const SizedBox(height: 12),
          Text(
            '1. Find nozzle/device pressure.  2. Add friction loss.  3. Add or subtract elevation.  4. Add appliance/FDC/wye loss.',
            style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SimpleSearchBar extends StatelessWidget {
  const _SimpleSearchBar({required this.controller, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.9)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                hintText: 'Search: wye, relay, nozzle, FDC…',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed.withValues(alpha: 0.68)),
                border: InputBorder.none,
              ),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close),
              color: FirePumpSimColors.textMed,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  static const categories = ['All', 'Pump', 'Friction', 'Nozzle', 'Water', 'Reference'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final category in categories) ...[
            ChoiceChip(
              label: Text(category),
              selected: selected == category,
              onSelected: (_) => onSelected(category),
              selectedColor: FirePumpSimColors.red.withValues(alpha: 0.22),
              backgroundColor: FirePumpSimColors.charcoal2,
              labelStyle: TextStyle(
                color: selected == category ? FirePumpSimColors.textHigh : FirePumpSimColors.textMed,
                fontWeight: FontWeight.w800,
              ),
              side: BorderSide(color: selected == category ? FirePumpSimColors.red : FirePumpSimColors.steel),
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FormulaQuickCard extends StatelessWidget {
  const _FormulaQuickCard({required this.item});

  final FormulaQuickItem item;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: FirePumpSimColors.charcoal3,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: FirePumpSimColors.red.withValues(alpha: 0.35)),
                ),
                child: Icon(item.icon, color: FirePumpSimColors.redSoft, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(item.use, style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textMed, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BigEquation(item.formula),
          if (item.steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final step in item.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: FirePumpSimColors.redSoft, fontWeight: FontWeight.w900)),
                    Expanded(child: Text(step, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.35))),
                  ],
                ),
              ),
          ],
          if (item.example.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FirePumpSimColors.charcoal3,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
              ),
              child: Text('Example: ${item.example}', style: textTheme.bodySmall?.copyWith(color: FirePumpSimColors.textHigh, height: 1.35)),
            ),
          ],
        ],
      ),
    );
  }
}

class _BigEquation extends StatelessWidget {
  const _BigEquation(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.robotoMono(
        textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: FirePumpSimColors.textHigh,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
      ),
    );
  }
}

class _EmptyFormulaState extends StatelessWidget {
  const _EmptyFormulaState({required this.query});
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
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No formula found', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Try “PDP”, “wye”, “relay”, “hydrant”, “reaction”, or “FDC”.', style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed)),
        ],
      ),
    );
  }
}

class _FormulaDisclaimer extends StatelessWidget {
  const _FormulaDisclaimer();

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
              'Training reference only. Formulas use common fire-service pump operator training rules. Always follow department SOPs, manufacturer pump/nozzle data, local training standards, and instructor direction before operational use.',
              style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class FormulaQuickItem {
  const FormulaQuickItem({
    required this.category,
    required this.title,
    required this.formula,
    required this.use,
    required this.steps,
    required this.example,
    required this.icon,
    this.keywords = const [],
  });

  final String category;
  final String title;
  final String formula;
  final String use;
  final List<String> steps;
  final String example;
  final IconData icon;
  final List<String> keywords;

  bool matches(String query) {
    bool contains(String value) => value.toLowerCase().contains(query);
    return contains(category) ||
        contains(title) ||
        contains(formula) ||
        contains(use) ||
        contains(example) ||
        steps.any(contains) ||
        keywords.any(contains);
  }
}

class FormulaCatalog {
  static const List<FormulaQuickItem> items = [
    FormulaQuickItem(
      category: 'Pump',
      title: 'Pump Pressure / PDP',
      formula: 'PDP = NP + FL ± Elevation + Appliance Loss',
      use: 'Use for most handline, master stream, standpipe, and FDC questions.',
      steps: ['Find nozzle/device pressure.', 'Add hose friction loss.', 'Add elevation gain or subtract elevation loss.', 'Add appliance, FDC, or wye loss if used.'],
      example: '50 NP + 106 FL + 0 elevation + 0 appliance = 156 → 155 psi.',
      icon: Icons.speed_outlined,
      keywords: ['pump pressure', 'pp', 'pdp', 'engine pressure'],
    ),
    FormulaQuickItem(
      category: 'Friction',
      title: 'Friction Loss',
      formula: 'FL = C × (GPM ÷ 100)² × (feet ÷ 100)',
      use: 'Use when hose size, flow, and length are known.',
      steps: ['Convert GPM to Q by dividing by 100.', 'Convert hose length to hundreds of feet.', 'Use the correct C value for the hose size.'],
      example: '2½″ hose, 250 GPM, 200′: FL = 2 × 2.5² × 2 = 25 psi.',
      icon: Icons.show_chart_outlined,
      keywords: ['fl', 'hose loss', 'coefficient', 'c value'],
    ),
    FormulaQuickItem(
      category: 'Reference',
      title: 'Common Hose C Values',
      formula: '1¾″=15.5   2″=8   2½″=2   3″=0.8   4″=0.2   5″=0.08',
      use: 'Use these starter values unless department setup provides different values.',
      steps: ['Use C in the friction loss formula.', 'Department hose testing may justify different values.'],
      example: '5″ LDH uses C=0.08.',
      icon: Icons.table_chart_outlined,
      keywords: ['coefficients', 'c values', 'ldh', '1.75', '1 3/4'],
    ),
    FormulaQuickItem(
      category: 'Pump',
      title: 'Elevation',
      formula: 'Elevation ≈ 0.5 psi × vertical feet',
      use: 'Add for uphill/above pump. Subtract for downhill/below pump.',
      steps: ['1st floor = 0′.', '2nd floor = 10′.', '3rd floor = 20′.', '4th floor = 30′.'],
      example: '3rd floor = 20′ × 0.5 = +10 psi.',
      icon: Icons.trending_up,
      keywords: ['floor', 'height', 'standpipe elevation'],
    ),
    FormulaQuickItem(
      category: 'Pump',
      title: 'Wye Operation',
      formula: 'PDP = supply FL + highest branch FL + NP + wye loss',
      use: 'Use when one supply line feeds a wye with two branches.',
      steps: ['Calculate supply line using total flow before the wye.', 'Calculate Branch A and Branch B separately.', 'Use the higher-pressure branch.', 'Add wye loss, usually 10 psi.'],
      example: 'If Branch B has the higher FL, Branch B controls the PDP.',
      icon: Icons.call_split,
      keywords: ['split', 'branch', 'branches', 'highest branch'],
    ),
    FormulaQuickItem(
      category: 'Pump',
      title: 'Master Stream / Dual Supply',
      formula: 'Flow per line = total GPM ÷ number of supply lines',
      use: 'Use when two or more lines feed a monitor, siamese, or master stream.',
      steps: ['Split the total flow evenly if the supply lines match.', 'Calculate FL for one supply line at its share of the flow.', 'Add master stream NP, usually 80 psi for smooth bore.'],
      example: '1000 GPM through two equal lines = 500 GPM per line.',
      icon: Icons.water_drop_outlined,
      keywords: ['monitor', 'portable monitor', 'siamese', 'deck gun'],
    ),
    FormulaQuickItem(
      category: 'Pump',
      title: 'Standpipe / FDC',
      formula: 'PDP = NP + hose FL + FDC/system loss + elevation',
      use: 'Use for standpipe or FDC support scenarios.',
      steps: ['Include hose from outlet to nozzle.', 'Add FDC/system loss, commonly 25 psi.', 'Add elevation to the outlet floor.'],
      example: '50 NP + 21 FL + 25 system + 10 elevation = 106 → 105 psi.',
      icon: Icons.apartment_outlined,
      keywords: ['standpipe', 'fdc', 'sprinkler', 'system loss'],
    ),
    FormulaQuickItem(
      category: 'Nozzle',
      title: 'Smooth Bore Flow',
      formula: 'GPM = 29.7 × diameter² × √NP',
      use: 'Use to find flow from a smooth bore tip.',
      steps: ['Use tip diameter in inches.', 'Use correct NP: handline often 50 psi, deck gun/master stream often 80 psi.'],
      example: '1½″ tip at 80 psi ≈ 29.7 × 1.5² × √80 = 598 → 600 GPM.',
      icon: Icons.water_drop,
      keywords: ['deck gun', 'tip', 'smoothbore', 'gpm'],
    ),
    FormulaQuickItem(
      category: 'Nozzle',
      title: 'Fog Nozzle Reaction',
      formula: 'NR = 0.0505 × GPM × √NP',
      use: 'Use to estimate reaction force for fog nozzles.',
      steps: ['Use flow in GPM.', 'Use nozzle pressure in psi.', 'Answer is in pounds.'],
      example: '185 GPM at 50 psi: NR ≈ 0.0505 × 185 × √50 = 66 lb.',
      icon: Icons.fitness_center,
      keywords: ['reaction', 'fog reaction', 'nr', 'lbs'],
    ),
    FormulaQuickItem(
      category: 'Nozzle',
      title: 'Smooth Bore Nozzle Reaction',
      formula: 'NR = 1.57 × diameter² × NP',
      use: 'Use to estimate reaction force for smooth bore nozzles.',
      steps: ['Use tip diameter in inches.', 'Square the diameter.', 'Use nozzle pressure in psi.'],
      example: '1⅛″ at 50 psi: NR ≈ 1.57 × 1.125² × 50 = 99 → 100 lb.',
      icon: Icons.fitness_center,
      keywords: ['smooth bore reaction', 'nr', 'lbs'],
    ),
    FormulaQuickItem(
      category: 'Water',
      title: 'Relay Pumping',
      formula: 'Relay PDP = relay hose FL + desired intake pressure ± elevation',
      use: 'Use when Engine 181 pumps to a receiving engine.',
      steps: ['Calculate FL in the relay hose.', 'Add desired intake pressure at receiving engine, commonly 20 psi.', 'Add elevation if present.'],
      example: '64 FL + 20 intake = 84 → 85 psi.',
      icon: Icons.local_shipping_outlined,
      keywords: ['relay', 'ldh', 'receiving engine', 'intake'],
    ),
    FormulaQuickItem(
      category: 'Water',
      title: 'Hydrant Pressure Drop',
      formula: 'Pressure drop = static pressure − residual pressure',
      use: 'Use when static and residual pressures are given.',
      steps: ['Static is the pressure before flowing.', 'Residual is the pressure while flowing.', 'Subtract residual from static.'],
      example: 'Static 70 − residual 50 = 20 psi drop.',
      icon: Icons.water_drop,
      keywords: ['hydrant', 'static', 'residual'],
    ),
    FormulaQuickItem(
      category: 'Water',
      title: 'Available Hydrant Flow',
      formula: 'Q₂ = Q₁ × √((Static − Target) ÷ (Static − Residual))',
      use: 'Use to estimate available flow down to a target residual, commonly 20 psi.',
      steps: ['Use known test flow as Q₁.', 'Use 20 psi as target unless SOP says otherwise.', 'Do not use below required residual.'],
      example: 'Use only when a flow test value is provided.',
      icon: Icons.water_drop,
      keywords: ['available flow', 'residual target', '20 psi'],
    ),
    FormulaQuickItem(
      category: 'Water',
      title: 'Tender Shuttle Flow',
      formula: 'Shuttle GPM = usable gallons ÷ total cycle time',
      use: 'Use for tender/tanker shuttle questions.',
      steps: ['Usable water is often 90% of tank size.', 'Cycle time = fill + travel + dump + return.', 'Round down or use a safety margin.'],
      example: '2700 usable gallons ÷ 30 min = 90 GPM.',
      icon: Icons.water_drop,
      keywords: ['tender', 'tanker', 'shuttle', 'cycle'],
    ),
    FormulaQuickItem(
      category: 'Reference',
      title: 'Common Nozzle Pressures',
      formula: 'Fog handline 50/100   Smooth bore handline 50   Smooth bore master stream 80',
      use: 'Use the nozzle rating or department standard from the problem.',
      steps: ['ChiefXD 185 = 185 GPM @ 50 psi.', 'ChiefXD 265 = 265 GPM @ 50 psi.', 'Smooth bore handlines commonly use 50 psi.'],
      example: 'Deck gun smooth bore usually uses 80 psi NP.',
      icon: Icons.fact_check_outlined,
      keywords: ['np', 'chiefxd', 'nozzle pressure'],
    ),
    FormulaQuickItem(
      category: 'Reference',
      title: 'Common Appliance Losses',
      formula: 'Wye +10   FDC/standpipe +25   Siamese 0–10   Portable monitor often +25',
      use: 'Use problem instructions or department SOP first.',
      steps: ['Only add losses for appliances actually in the layout.', 'Do not add appliance loss to a straight single attack line.'],
      example: 'Wye layout: add 10 psi wye loss.',
      icon: Icons.build_outlined,
      keywords: ['appliance', 'wye loss', 'fdc loss', 'standpipe loss'],
    ),
  ];
}
