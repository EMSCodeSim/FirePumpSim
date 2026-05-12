import 'package:firepumpsim/theme.dart';
import 'package:flutter/material.dart';
import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/screens/calculator_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class FormulasScreen extends StatefulWidget {
  const FormulasScreen({super.key});

  @override
  State<FormulasScreen> createState() => _FormulasScreenState();
}

class _FormulasScreenState extends State<FormulasScreen> {
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
      body: SafeArea(
        child: const FormulasReferenceView(),
      ),
    );
  }
}

/// Opens the formulas reference as a modal overlay.
///
/// This preserves the underlying route/widget state (ex: Scenario Player progress)
/// because it does not change routes.
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
                  const Expanded(child: FormulasReferenceView()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable formulas reference body.
///
/// This is used both by the full screen `FormulasScreen` route and by the
/// in-scenario modal reference overlay.
class FormulasReferenceView extends StatefulWidget {
  const FormulasReferenceView({super.key});

  @override
  State<FormulasReferenceView> createState() => _FormulasReferenceViewState();
}

class _FormulasReferenceViewState extends State<FormulasReferenceView> {
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

    final categories = FormulaCatalog.categories;
    final filtered = _query.trim().isEmpty
        ? categories
        : categories
            .map((c) => c.filtered(_query))
            .where((c) => c.formulas.isNotEmpty)
            .toList(growable: false);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Formulas', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  'Pumping, hydraulics, wildland, and fireground references',
                  style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.35),
                ),
                const SizedBox(height: AppSpacing.md),
                _FormulaSearchBar(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
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
              child: filtered.isEmpty ? _EmptySearchState(query: _query) : _FormulaCategoryList(categories: filtered),
            ),
          ),
        ),
      ],
    );
  }
}

class _FormulaSearchBar extends StatelessWidget {
  const _FormulaSearchBar({required this.controller, required this.onChanged, required this.onClear});

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
                hintText: 'Search formulas…',
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

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});
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
            'Try a category name (e.g., “Friction Loss”), a variable (e.g., “GPM”), or an equation fragment (e.g., “C × Q²”).\n\nSearch: “$query”',
            style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _FormulaCategoryList extends StatelessWidget {
  const _FormulaCategoryList({required this.categories});
  final List<FormulaCategory> categories;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final c in categories) {
      children.add(_FormulaCategoryCard(category: c));
      children.add(const SizedBox(height: AppSpacing.md));
    }
    children.add(const _FormulaDisclaimer());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _FormulaCategoryCard extends StatelessWidget {
  const _FormulaCategoryCard({required this.category});
  final FormulaCategory category;

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
            for (int i = 0; i < category.formulas.length; i++) ...[
              _FormulaItemCard(item: category.formulas[i]),
              if (i != category.formulas.length - 1) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormulaItemCard extends StatelessWidget {
  const _FormulaItemCard({required this.item});
  final FormulaItem item;

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
          title: Text(item.title, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _EquationText(equation: item.equation),
          ),
          children: [
            if (item.variables.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _SectionLabel(icon: Icons.tune, label: 'Variables'),
              const SizedBox(height: 8),
              _VariablesList(items: item.variables),
            ],
            if (item.example != null) ...[
              const SizedBox(height: AppSpacing.md),
              _SectionLabel(icon: Icons.bolt, label: 'Quick example'),
              const SizedBox(height: 8),
              Text(item.example!, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textHigh, height: 1.45)),
            ],
            if (item.note != null) ...[
              const SizedBox(height: AppSpacing.md),
              _SectionLabel(icon: Icons.info_outline, label: 'Note'),
              const SizedBox(height: 8),
              Text(item.note!, style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed, height: 1.45)),
            ],
          ],
        ),
      ),
    );
  }
}

class _EquationText extends StatelessWidget {
  const _EquationText({required this.equation});
  final String equation;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium ?? const TextStyle(fontSize: 16);
    return Text(
      equation,
      style: GoogleFonts.robotoMono(
        textStyle: base.copyWith(
          color: FirePumpSimColors.textHigh,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          height: 1.25,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: FirePumpSimColors.red.withValues(alpha: 0.9)),
        const SizedBox(width: 8),
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: FirePumpSimColors.textMed.withValues(alpha: 0.95),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _VariablesList extends StatelessWidget {
  const _VariablesList({required this.items});
  final List<FormulaVariable> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final v in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: FirePumpSimColors.charcoal2,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.85)),
                  ),
                  child: Text(
                    v.symbol,
                    style: GoogleFonts.robotoMono(
                      textStyle: (textTheme.labelLarge ?? const TextStyle(fontSize: 13)).copyWith(
                        color: FirePumpSimColors.textHigh,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    v.description,
                    style: textTheme.bodyMedium?.copyWith(color: FirePumpSimColors.textMed.withValues(alpha: 0.95), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
      ],
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
              'Training reference only. Always follow department SOPs, manufacturer specifications, and local training standards.',
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

class FormulaVariable {
  const FormulaVariable(this.symbol, this.description);
  final String symbol;
  final String description;
}

class FormulaItem {
  const FormulaItem({required this.title, required this.equation, this.variables = const [], this.example, this.note, this.keywords = const []});

  final String title;
  final String equation;
  final List<FormulaVariable> variables;
  final String? example;
  final String? note;
  final List<String> keywords;

  bool matchesQuery(String query) {
    final q = query.toLowerCase();
    bool contains(String s) => s.toLowerCase().contains(q);
    if (contains(title) || contains(equation)) return true;
    for (final k in keywords) {
      if (contains(k)) return true;
    }
    for (final v in variables) {
      if (contains(v.symbol) || contains(v.description)) return true;
    }
    if (example != null && contains(example!)) return true;
    if (note != null && contains(note!)) return true;
    return false;
  }
}

class FormulaCategory {
  const FormulaCategory({required this.title, this.subtitle, required this.formulas});

  final String title;
  final String? subtitle;
  final List<FormulaItem> formulas;

  FormulaCategory filtered(String query) => FormulaCategory(
        title: title,
        subtitle: subtitle,
        formulas: formulas.where((f) => f.matchesQuery(query) || title.toLowerCase().contains(query.toLowerCase())).toList(growable: false),
      );
}

class FormulaCatalog {
  static const List<FormulaCategory> categories = [
    FormulaCategory(
      title: 'Pump Pressure / PDP',
      subtitle: 'Common pressure build-ups for attack lines, standpipes, and appliances.',
      formulas: [
        FormulaItem(
          title: 'Pump Pressure (PP)',
          equation: 'PP = NP + FL ± EP + AL',
          variables: [
            FormulaVariable('PP', 'Pump pressure / discharge pressure'),
            FormulaVariable('NP', 'Nozzle pressure'),
            FormulaVariable('FL', 'Friction loss (hose + plumbing as applicable)'),
            FormulaVariable('EP', 'Elevation pressure (gain/loss)'),
            FormulaVariable('AL', 'Appliance loss'),
          ],
          example: 'Example: NP 50 + FL 60 + EP +10 + AL 10 = 130 psi.',
          note: 'Use your department’s standard NP and appliance losses when applicable.',
          keywords: ['pdp', 'engine pressure', 'elevation', 'appliance loss'],
        ),
        FormulaItem(
          title: 'PDP (expanded)',
          equation: 'PDP = NP + total FL + appliance loss ± elevation',
          variables: [
            FormulaVariable('PDP', 'Pump discharge pressure'),
            FormulaVariable('NP', 'Nozzle pressure'),
            FormulaVariable('total FL', 'Total friction loss across hose/layout'),
          ],
          example: 'Example: NP 50 + FL 75 + AL 25 − EP 10 = 140 psi.',
        ),
        FormulaItem(
          title: 'Elevation (quick rule)',
          equation: 'EP ≈ 0.5 × height (ft)',
          variables: [
            FormulaVariable('EP', 'Elevation pressure (psi)'),
            FormulaVariable('height', 'Elevation change in feet'),
          ],
          example: '20 ft above the pump ≈ 10 psi added.',
          note: 'This is a fire service shortcut; see the Elevation section for the 0.434 psi/ft method.',
          keywords: ['5 psi per floor', '0.5'],
        ),
        FormulaItem(
          title: 'Elevation by floors (approx.)',
          equation: 'EP ≈ 5 psi per floor above/below pump',
          variables: [
            FormulaVariable('EP', 'Elevation pressure (psi)'),
            FormulaVariable('floor', 'Floor difference (typical ~10 ft increments)'),
          ],
          example: '3 floors above pump ≈ +15 psi.',
          note: 'Confirm floor-to-floor heights locally; standpipes often use 10 ft per floor as a shortcut.',
        ),
        FormulaItem(
          title: 'Standpipe PDP (full build-up)',
          equation: 'Standpipe PDP = NP + hose FL + appliance loss + standpipe/system loss + elevation',
          variables: [
            FormulaVariable('standpipe/system loss', 'Often a department standard (e.g., 25 psi)'),
          ],
          example: 'NP 50 + hose FL 35 + system loss 25 + EP 20 = 130 psi (plus appliance loss if used).',
          note: 'Standpipe/FDC losses vary; follow SOPs and preplans.',
          keywords: ['fdc', 'system loss', 'standpipe'],
        ),
      ],
    ),
    FormulaCategory(
      title: 'Friction Loss',
      subtitle: 'Hose friction loss relationships and quick operational shortcuts.',
      formulas: [
        FormulaItem(
          title: 'Friction Loss (general)',
          equation: 'FL = C × Q² × L',
          variables: [
            FormulaVariable('FL', 'Friction loss (psi)'),
            FormulaVariable('C', 'Hose coefficient'),
            FormulaVariable('Q', 'Flow (GPM ÷ 100)'),
            FormulaVariable('L', 'Hose length (ft ÷ 100)'),
          ],
          example: '2½" (C=2), 250 GPM (Q=2.5), 200 ft (L=2): FL = 2 × 2.5² × 2 = 25 psi.',
          keywords: ['q', 'l', 'coefficient'],
        ),
        FormulaItem(
          title: 'Q (flow factor)',
          equation: 'Q = GPM ÷ 100',
          variables: [FormulaVariable('GPM', 'Gallons per minute')],
          example: '150 GPM → Q = 1.5.',
        ),
        FormulaItem(
          title: 'L (length factor)',
          equation: 'L = hose length ÷ 100',
          variables: [FormulaVariable('hose length', 'Hose length in feet')],
          example: '300 ft → L = 3.',
        ),
        FormulaItem(
          title: 'FL per 100′',
          equation: 'FL per 100′ = C × Q²',
          variables: [
            FormulaVariable('C', 'Hose coefficient'),
            FormulaVariable('Q', 'GPM ÷ 100'),
          ],
          example: '1¾" (C=15.5), 150 GPM (Q=1.5): FL/100 = 15.5 × 1.5² ≈ 34.9 psi.',
        ),
        FormulaItem(
          title: 'Total FL (multi-sections)',
          equation: 'Total FL = (FL per 100′) × (# of 100′ sections)',
          variables: [FormulaVariable('# of 100′ sections', 'Total hose length divided by 100')],
          example: 'FL/100 35 psi over 3 sections → total FL 105 psi.',
        ),
        FormulaItem(
          title: 'Two equal supply lines (split flow)',
          equation: 'Flow per line = total GPM ÷ 2',
          variables: [FormulaVariable('total GPM', 'Total flow required at the appliance/nozzle')],
          example: '500 GPM master stream on two equal lines → 250 GPM per line.',
          note: 'Then compute FL per line using that per-line flow.',
          keywords: ['parallel lines', 'split'],
        ),
        FormulaItem(
          title: 'Master stream supply (multiple lines)',
          equation: 'Calculate FL per supply line using flow per line',
          example: 'If a monitor needs 600 GPM supplied by 3 equal lines → 200 GPM per line; compute FL for 200 GPM in each line.',
        ),
      ],
    ),
    FormulaCategory(
      title: 'Common C Values',
      subtitle: 'Typical hose coefficients. Editable later for department setup.',
      formulas: [
        FormulaItem(
          title: '1¾″ hose',
          equation: 'C = 15.5',
          note: 'Department hose construction and testing may support different values.',
          keywords: ['1.75', '1 3/4'],
        ),
        FormulaItem(title: '2″ hose', equation: 'C = 8'),
        FormulaItem(title: '2½″ hose', equation: 'C = 2', keywords: ['2.5']),
        FormulaItem(title: '3″ hose', equation: 'C = 0.8'),
        FormulaItem(title: '4″ LDH', equation: 'C = 0.2', keywords: ['ldh']),
        FormulaItem(title: '5″ LDH', equation: 'C = 0.08', keywords: ['ldh']),
      ],
    ),
    FormulaCategory(
      title: 'Nozzle Pressure / Flow',
      subtitle: 'Common NP targets and smooth-bore flow calculations.',
      formulas: [
        FormulaItem(
          title: 'Fog handline NP',
          equation: 'NP = 50 psi or 100 psi (nozzle dependent)',
          note: 'Confirm nozzle rating and department SOP.',
          keywords: ['fog', 'combination nozzle'],
        ),
        FormulaItem(title: 'Smooth bore handline NP', equation: 'NP = 50 psi', keywords: ['smoothbore']),
        FormulaItem(title: 'Smooth bore master stream NP', equation: 'NP = 80 psi'),
        FormulaItem(title: 'Fog master stream NP', equation: 'NP = 100 psi'),
        FormulaItem(
          title: 'Smooth bore GPM (handline)',
          equation: 'GPM = 29.7 × d² × √NP',
          variables: [
            FormulaVariable('d', 'Nozzle diameter (inches)'),
            FormulaVariable('NP', 'Nozzle pressure (psi)'),
          ],
          example: 'Tip 7/8" (0.875), NP 50: GPM ≈ 29.7 × 0.875² × √50 ≈ 161 GPM.',
          keywords: ['flow', 'sqrt'],
        ),
        FormulaItem(
          title: 'Smooth bore GPM (master stream)',
          equation: 'GPM = 29.7 × d² × √NP',
          variables: [
            FormulaVariable('d', 'Nozzle diameter (inches)'),
            FormulaVariable('NP', 'Nozzle pressure (psi)'),
          ],
          note: 'Same equation; use the correct NP for the device (often 80 psi).',
        ),
      ],
    ),
    FormulaCategory(
      title: 'Nozzle Reaction',
      subtitle: 'Reaction forces in pounds (lb).',
      formulas: [
        FormulaItem(
          title: 'Fog nozzle reaction',
          equation: 'Fog NR = 0.0505 × GPM × √NP',
          variables: [
            FormulaVariable('GPM', 'Flow rate'),
            FormulaVariable('NP', 'Nozzle pressure'),
          ],
          example: '150 GPM at 100 psi → NR ≈ 0.0505 × 150 × 10 = 75.8 lb.',
          keywords: ['reaction'],
        ),
        FormulaItem(
          title: 'Smooth bore nozzle reaction',
          equation: 'Smooth bore NR = 1.57 × d² × NP',
          variables: [
            FormulaVariable('d', 'Nozzle diameter (inches)'),
            FormulaVariable('NP', 'Nozzle pressure (psi)'),
          ],
          example: '7/8" at 50 psi → NR ≈ 1.57 × 0.875² × 50 ≈ 60 lb.',
        ),
      ],
    ),
    FormulaCategory(
      title: 'Appliance Loss',
      subtitle: 'Typical appliance losses (department dependent).',
      formulas: [
        FormulaItem(title: 'Wye', equation: 'Usually 10 psi', note: 'Appliance losses vary by department policy and equipment.'),
        FormulaItem(title: 'Siamese', equation: 'Usually 0–10 psi', note: 'Appliance losses vary by department policy and equipment.'),
        FormulaItem(title: 'Gated wye', equation: 'Usually 10 psi', note: 'Appliance losses vary by department policy and equipment.'),
        FormulaItem(title: 'Standpipe/FDC/system loss', equation: 'Often 25 psi', note: 'Appliance losses vary by department policy and equipment.'),
        FormulaItem(title: 'Master stream appliance', equation: 'Often 25 psi', note: 'Appliance losses vary by department policy and equipment.'),
        FormulaItem(title: 'Eductor', equation: 'Usually 200 psi inlet pressure', note: 'Follow device specs; eductors are highly flow/pressure sensitive.'),
      ],
    ),
    FormulaCategory(
      title: 'Elevation',
      subtitle: 'Elevation gain/loss methods and floor approximations.',
      formulas: [
        FormulaItem(
          title: 'Elevation pressure (physics)',
          equation: 'EP = height × 0.434 psi/ft',
          variables: [
            FormulaVariable('height', 'Elevation change (ft)'),
          ],
          example: '50 ft uphill: EP ≈ 50 × 0.434 = 21.7 psi added.',
          keywords: ['0.434'],
        ),
        FormulaItem(title: 'Fire service shortcut', equation: 'EP = height × 0.5 psi/ft', example: '50 ft uphill: EP ≈ 25 psi.'),
        FormulaItem(
          title: 'Floors above pump (shortcut)',
          equation: 'EP ≈ floor difference × 10 ft × 0.5',
          example: '4th floor outlet (30 ft) ≈ 15 psi.',
        ),
        FormulaItem(
          title: 'Floor height reference',
          equation: '1st=0 ft, 2nd=10 ft, 3rd=20 ft, 4th=30 ft',
          note: 'For standpipes, calculate to the floor outlet/connection, not the roof.',
        ),
      ],
    ),
    FormulaCategory(
      title: 'Relay Pumping',
      subtitle: 'Spacing, residual targets, and relay build-ups.',
      formulas: [
        FormulaItem(
          title: 'Available pressure',
          equation: 'Available = source pressure − desired residual',
          variables: [
            FormulaVariable('source pressure', 'Hydrant/supply pressure at relay start'),
            FormulaVariable('desired residual', 'Target intake/residual (often ≥20 psi)'),
          ],
          example: 'Source 70 psi, residual target 20 psi → available 50 psi for FL.',
        ),
        FormulaItem(
          title: 'Distance per engine (estimate)',
          equation: 'Distance per engine = usable pressure ÷ FL per 100′ × 100',
          variables: [
            FormulaVariable('usable pressure', 'Available pressure for friction loss'),
            FormulaVariable('FL per 100′', 'Computed for relay hose size and flow'),
          ],
          example: 'Usable 50 psi, FL/100 5 psi → 50/5×100 = 1,000 ft per engine.',
        ),
        FormulaItem(
          title: 'Number of relay engines (rough)',
          equation: '# engines = total distance ÷ distance per engine',
          note: 'Round up and account for terrain, elevation, appliances, and intake targets.',
        ),
        FormulaItem(
          title: 'Intake safety target',
          equation: 'Maintain at least 20 psi residual/intake',
          note: 'Unless department policy differs.',
        ),
        FormulaItem(
          title: 'Relay PDP (concept)',
          equation: 'Relay PDP = relay hose FL + desired intake at next engine',
          note: 'Add elevation and appliances if applicable.',
        ),
      ],
    ),
    FormulaCategory(
      title: 'Hydrant Flow / Available Water',
      subtitle: 'Quick hydrant flow estimate and pressure-drop relationships.',
      formulas: [
        FormulaItem(
          title: 'Hydrant flow estimate',
          equation: 'GPM = 29.83 × C × d² × √P',
          variables: [
            FormulaVariable('C', 'Hydrant coefficient'),
            FormulaVariable('d', 'Outlet diameter (inches)'),
            FormulaVariable('P', 'Pitot pressure (psi)'),
          ],
          note: 'Field estimates vary; follow local testing standards and method.',
          keywords: ['pitot', 'hydrant'],
        ),
        FormulaItem(
          title: 'Available flow using pressure drop',
          equation: 'Q₂ = Q₁ × √((P_static − P_target) ÷ (P_static − P_residual))',
          variables: [
            FormulaVariable('P_target', 'Residual target pressure (often 20 psi)'),
          ],
          note: 'Use consistent units and validated starting measurements.',
        ),
        FormulaItem(
          title: 'Common residual target',
          equation: 'Residual target: 20 psi',
          note: 'Department policy may vary.',
        ),
        FormulaItem(
          title: 'Hydrant coefficient examples',
          equation: 'C = 0.9 smooth, 0.8 square, 0.7 rough',
          note: 'Coefficient depends on outlet geometry/condition.',
        ),
      ],
    ),
    FormulaCategory(
      title: 'Tanker / Tender Shuttle',
      subtitle: 'Cycle-time and flow planning for water shuttle ops.',
      formulas: [
        FormulaItem(
          title: 'Cycle time',
          equation: 'Cycle = fill + travel to scene + dump + travel to fill site',
          variables: [
            FormulaVariable('time', 'All times in minutes'),
          ],
        ),
        FormulaItem(
          title: 'Shuttle flow',
          equation: 'Shuttle flow = usable tank gallons ÷ cycle time (min)',
          variables: [
            FormulaVariable('usable tank gallons', 'Account for dump constraints and reserve if required'),
          ],
          example: '2,000 gal ÷ 20 min = 100 GPM.',
        ),
        FormulaItem(
          title: 'Number of tenders needed',
          equation: '# tenders = required GPM ÷ one tender shuttle GPM',
          note: 'Round up; consider reliability, traffic, and turnaround constraints.',
        ),
        FormulaItem(
          title: 'Dump time',
          equation: 'Dump time = tank gallons ÷ dump rate',
        ),
        FormulaItem(
          title: 'Fill time',
          equation: 'Fill time = tank gallons ÷ fill rate',
        ),
      ],
    ),
    FormulaCategory(
      title: 'Drafting / Static Water Supply',
      subtitle: 'Lift limits, intake considerations, and cavitation prevention.',
      formulas: [
        FormulaItem(title: 'Max theoretical lift', equation: '≈ 33.9 ft at sea level', note: 'Practical fire service lift is usually much lower.'),
        FormulaItem(title: 'Lift loss', equation: '≈ 1 psi per 2.3 ft', note: 'Use as a rough relationship for suction lift effects.'),
        FormulaItem(title: 'Strainer depth', equation: 'Keep strainer submerged with clearance', note: 'Avoid vortexing; maintain adequate water above strainer.'),
        FormulaItem(title: 'Operational focus', equation: 'Maintain intake pressure; avoid cavitation', note: 'Watch gauges and water supply stability.'),
      ],
    ),
    FormulaCategory(
      title: 'Foam',
      subtitle: 'Concentrate percentages and quick calculations.',
      formulas: [
        FormulaItem(
          title: 'Foam concentrate GPM',
          equation: 'Concentrate GPM = total GPM × foam %',
          variables: [
            FormulaVariable('foam %', 'Use as a decimal (1% = 0.01; 3% = 0.03)'),
          ],
          example: '3% at 200 GPM → 200 × 0.03 = 6 GPM concentrate.',
        ),
        FormulaItem(title: '1% foam example', equation: '1% at 100 GPM = 1 GPM concentrate'),
        FormulaItem(title: '3% foam example', equation: '3% at 100 GPM = 3 GPM concentrate'),
        FormulaItem(
          title: 'Concentrate needed (volume)',
          equation: 'Concentrate = flow GPM × percent × time (min)',
          example: '200 GPM, 3%, 10 min → 200 × 0.03 × 10 = 60 gal concentrate.',
        ),
        FormulaItem(
          title: 'Finished foam solution',
          equation: 'Finished solution = water + concentrate',
        ),
        FormulaItem(
          title: 'Eductor operations',
          equation: 'Follow rated flow and inlet pressure',
          note: 'Eductors are performance sensitive; use manufacturer specs.',
        ),
      ],
    ),
    FormulaCategory(
      title: 'Master Streams',
      subtitle: 'Monitor/stream build-ups and split supply planning.',
      formulas: [
        FormulaItem(title: 'Master stream PDP', equation: 'PDP = NP + FL + appliance loss ± elevation'),
        FormulaItem(title: 'Portable monitor appliance loss', equation: 'Often 25 psi', note: 'Department/device dependent.'),
        FormulaItem(title: 'Deck gun NP (smooth bore)', equation: 'NP = 80 psi'),
        FormulaItem(title: 'Deck gun NP (fog)', equation: 'NP = 100 psi'),
        FormulaItem(
          title: 'Split supply lines',
          equation: 'Flow per line = total master stream GPM ÷ # supply lines',
          note: 'Compute FL for each line using its per-line flow.',
        ),
      ],
    ),
    FormulaCategory(
      title: 'Standpipe / FDC',
      subtitle: 'Standpipe build-ups and floor-based elevation shortcuts.',
      formulas: [
        FormulaItem(title: 'Standpipe PDP', equation: 'PDP = NP + hose FL + standpipe/FDC loss + elevation'),
        FormulaItem(title: 'Common standpipe/FDC loss', equation: '25 psi', note: 'Department policy may vary.'),
        FormulaItem(title: 'Floor elevations', equation: '1st=0 ft, 2nd=10 ft, 3rd=20 ft, 4th=30 ft', note: 'Elevation should be based on outlet floor height.'),
        FormulaItem(title: 'Attack hose from outlet', equation: 'Attack hose still has friction loss', note: 'Include hose FL after the standpipe outlet.'),
      ],
    ),
    FormulaCategory(
      title: 'Sprinkler Support',
      subtitle: 'FDC support pressures and safe system support considerations.',
      formulas: [
        FormulaItem(
          title: 'Basic FDC support (common)',
          equation: 'Often 150 psi (department standard)',
          note: 'Follow local SOP and system type; do not overpressurize older systems.',
          keywords: ['sprinkler', 'fdc'],
        ),
        FormulaItem(
          title: 'If system demand known',
          equation: 'PDP = system demand pressure + FDC loss ± elevation',
          note: 'Use verified system demand and manufacturer/system documentation.',
        ),
        FormulaItem(
          title: 'If demand unknown',
          equation: 'Follow department SOP/preplan',
          note: 'Avoid overpressurizing. Confirm valve positions and system configuration.',
        ),
      ],
    ),
    FormulaCategory(
      title: 'Wildland / WUI',
      subtitle: 'Long lays, progressive flow changes, and portable pump considerations.',
      formulas: [
        FormulaItem(
          title: 'Wildland pump pressure (concept)',
          equation: 'Pump pressure = nozzle pressure + hose FL ± elevation',
          note: 'Wildland nozzle flows often lower, but long lays can create high FL.',
        ),
        FormulaItem(title: 'Elevation gain (uphill)', equation: '+0.5 psi per foot uphill'),
        FormulaItem(title: 'Elevation loss (downhill)', equation: '−0.5 psi per foot downhill'),
        FormulaItem(
          title: 'Progressive hose lay',
          equation: 'Total FL = sum of each segment based on flow through that segment',
          note: 'As laterals/branches open, upstream segments carry more flow than downstream segments.',
        ),
        FormulaItem(title: 'Laterals', equation: 'Calculate each branch separately'),
        FormulaItem(
          title: 'Siamese / wye logic',
          equation: 'Highest-pressure branch controls',
          note: 'Balance flows and ensure adequate supply to the controlling branch.',
        ),
        FormulaItem(
          title: 'Wildland hose coefficients',
          equation: 'C values vary by hose type and department',
          note: 'Confirm hose type (single-jacket, double-jacket, forestry) and local guidance.',
        ),
        FormulaItem(
          title: 'Portable pump (concept)',
          equation: 'Discharge must overcome FL + elevation + nozzle pressure',
        ),
      ],
    ),
    FormulaCategory(
      title: 'Water Hammer / Safety',
      subtitle: 'Operational reminders to reduce system shocks and hazards.',
      formulas: [
        FormulaItem(title: 'Valve operation', equation: 'Open and close valves slowly'),
        FormulaItem(title: 'Avoid sudden closure', equation: 'Avoid sudden valve closure'),
        FormulaItem(title: 'Maintain intake pressure', equation: 'Maintain intake pressure; watch for cavitation'),
        FormulaItem(title: 'Pressure ratings', equation: 'Do not exceed hose/appliance ratings'),
      ],
    ),
    FormulaCategory(
      title: 'Unit Conversions',
      subtitle: 'Common quick conversions used in training and documentation.',
      formulas: [
        FormulaItem(title: 'Gallons to liters', equation: '1 gallon = 3.785 liters'),
        FormulaItem(title: 'PSI to kPa', equation: '1 psi = 6.895 kPa'),
        FormulaItem(title: 'Feet to meters', equation: '1 foot = 0.3048 meters'),
        FormulaItem(title: 'Meters to feet', equation: '1 meter = 3.281 feet'),
        FormulaItem(title: 'GPM to L/min', equation: '1 gpm = 3.785 L/min'),
        FormulaItem(title: 'kPa to PSI', equation: '1 kPa = 0.145 psi'),
      ],
    ),
  ];
}
