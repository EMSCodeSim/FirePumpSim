import 'dart:typed_data';

import 'package:firepumpsim/models/printable_pump_scenario.dart';
import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' as pr;

class PrintableScenariosScreen extends StatefulWidget {
  const PrintableScenariosScreen({super.key});

  @override
  State<PrintableScenariosScreen> createState() => _PrintableScenariosScreenState();
}

class _PrintableScenariosScreenState extends State<PrintableScenariosScreen> {
  final _titleController = TextEditingController(text: 'Fire Pump Pressure Practice');
  final _deptController = TextEditingController(text: 'Driver / Operator Training');

  final PrintableScenarioGenerator _generator = PrintableScenarioGenerator();

  PrintableWorksheetDifficulty _difficulty = PrintableWorksheetDifficulty.beginner;
  bool _includeAnswerKey = true;
  late List<PrintablePumpScenario> _scenarios;

  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _scenarios = _generator.generatePrintableSheet(_difficulty);
    _titleController.addListener(_onMetaChanged);
    _deptController.addListener(_onMetaChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onMetaChanged);
    _deptController.removeListener(_onMetaChanged);
    _titleController.dispose();
    _deptController.dispose();
    super.dispose();
  }

  void _onMetaChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _regenerate() {
    setState(() => _scenarios = _generator.generatePrintableSheet(_difficulty));
  }

  void _setDifficulty(PrintableWorksheetDifficulty d) {
    if (_difficulty == d) return;
    setState(() {
      _difficulty = d;
      _scenarios = _generator.generatePrintableSheet(_difficulty);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: FirePumpSimColors.charcoal,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _PrintableHeader(
                title: 'Printable Scenarios',
                subtitle: 'Create pump pressure worksheets for driver/operator training.',
                onBack: () => context.go(AppRoutes.home),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: _BuilderCard(
                  titleController: _titleController,
                  departmentController: _deptController,
                  difficulty: _difficulty,
                  includeAnswerKey: _includeAnswerKey,
                  onDifficultyChanged: _setDifficulty,
                  onIncludeAnswerKeyChanged: (v) => setState(() => _includeAnswerKey = v),
                  onGenerate: _regenerate,
                  onPrint: _printing ? null : _handlePrint,
                  printing: _printing,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Preview', style: (textTheme.titleMedium ?? const TextStyle(fontSize: 16)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text('Four wide scenarios per page.', style: (textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, height: 1.45)),
                    const SizedBox(height: 12),
                    _WorksheetPreview(
                      worksheetTitle: _titleController.text.trim().isEmpty ? 'Fire Pump Pressure Practice' : _titleController.text.trim(),
                      department: _deptController.text.trim().isEmpty ? 'Driver / Operator Training' : _deptController.text.trim(),
                      scenarios: _scenarios,
                      includeAnswerKey: _includeAnswerKey,
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePrint() async {
    setState(() => _printing = true);
    try {
      final bytes = await _buildPdfBytes(
        worksheetTitle: _titleController.text.trim().isEmpty ? 'Fire Pump Pressure Practice' : _titleController.text.trim(),
        department: _deptController.text.trim().isEmpty ? 'Driver / Operator Training' : _deptController.text.trim(),
        scenarios: _scenarios,
        includeAnswerKey: _includeAnswerKey,
      );

      await pr.Printing.layoutPdf(
        name: 'FirePumpSim Worksheet',
        onLayout: (format) async => bytes,
      );
    } catch (e) {
      debugPrint('Print/Save PDF failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to print / save PDF on this device.'),
            backgroundColor: FirePumpSimColors.charcoal3,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<Uint8List> _buildPdfBytes({
    required String worksheetTitle,
    required String department,
    required List<PrintablePumpScenario> scenarios,
    required bool includeAnswerKey,
  }) async {
    final doc = pw.Document();
    // Keep PDF generation dependency-light and robust across platforms.
    // Built-in Helvetica avoids the need for Google font downloads.
    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    pw.TextStyle t(double size, {bool bold = false}) => pw.TextStyle(font: bold ? boldFont : baseFont, fontSize: size);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 26),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _pdfHeader(worksheetTitle: worksheetTitle, department: department, t: t),
              pw.SizedBox(height: 10),
              for (var i = 0; i < scenarios.length; i++) ...[
                _pdfScenarioRow(index: i + 1, scenario: scenarios[i], t: t),
                if (i != scenarios.length - 1) pw.SizedBox(height: 8),
              ],
              pw.Spacer(),
              _pdfFooter(t),
            ],
          );
        },
      ),
    );

    if (includeAnswerKey) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 26),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text('Answer Key', style: t(18, bold: true)),
                pw.SizedBox(height: 6),
                pw.Text('$worksheetTitle • $department', style: t(10)),
                pw.SizedBox(height: 12),
                _pdfAnswerKeyTable(scenarios: scenarios, t: t),
                pw.SizedBox(height: 14),
                pw.Text('Math', style: t(12, bold: true)),
                pw.SizedBox(height: 6),
                for (var i = 0; i < scenarios.length; i++) ...[
                  pw.Text('Scenario ${i + 1}:', style: t(10, bold: true)),
                  pw.SizedBox(height: 2),
                  pw.Text(scenarios[i].mathExplanation, style: t(9)),
                  if (i != scenarios.length - 1) pw.SizedBox(height: 10),
                ],
                pw.Spacer(),
                _pdfFooter(t),
              ],
            );
          },
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _pdfHeader({required String worksheetTitle, required String department, required pw.TextStyle Function(double, {bool bold}) t}) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: pw.Text(worksheetTitle, style: t(14, bold: true))),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Align(alignment: pw.Alignment.topRight, child: pw.Text(department, style: t(11, bold: true), textAlign: pw.TextAlign.right))),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Expanded(child: pw.Text('Generated by FirePumpSim', style: t(9))),
              pw.Text('Date: __________', style: t(9)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfScenarioRow({required int index, required PrintablePumpScenario scenario, required pw.TextStyle Function(double, {bool bold}) t}) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            children: [
              pw.Expanded(child: pw.Text('$index. ${scenario.title}', style: t(11, bold: true))),
              pw.Text('Single Line', style: t(9)),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 120,
                height: 64,
                child: pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
                  child: pw.Stack(
                    children: [
                      pw.Positioned.fill(
                        child: pw.CustomPaint(
                          painter: (PdfGraphics canvas, PdfPoint size) => _pdfPaintScene(canvas, size),
                        ),
                      ),
                      pw.Positioned(left: 4, top: 2, child: pw.Text('${scenario.hoseDiameterLabel} • ${scenario.lengthFt} ft', style: t(6, bold: true))),
                      pw.Positioned(right: 4, top: 2, child: pw.Text('${scenario.gpm} GPM', style: t(6, bold: true))),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(scenario.problem, style: t(9)),
                    pw.SizedBox(height: 6),
                    _pdfFactsGrid(scenario: scenario, t: t),
                    pw.SizedBox(height: 6),
                    pw.Text('PP = NP + FL ± Elevation + Appliance', style: t(9, bold: true)),
                    pw.Text('FL = C × (GPM/100)² × Length/100', style: t(8)),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text('NP: ______', style: t(9))),
                        pw.Expanded(child: pw.Text('FL: ______', style: t(9))),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text('Elev/App: ______', style: t(9))),
                        pw.Expanded(child: pw.Text('Final PP: ______', style: t(9))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfFactsGrid({required PrintablePumpScenario scenario, required pw.TextStyle Function(double, {bool bold}) t}) {
    final items = <List<String>>[
      ['Hose', '${scenario.hoseDiameterLabel} • ${scenario.lengthFt} ft'],
      ['C', _fmtC(scenario.cValue)],
      ['Nozzle', scenario.nozzleLabel],
      ['Flow', '${scenario.gpm} GPM @ ${scenario.np} PSI'],
      ['Elevation', '${scenario.elevationFeet} ft (${scenario.elevationPsi} PSI)'],
      ['Appliance', '${scenario.appliancePsi} PSI'],
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.7),
      columnWidths: {0: const pw.FixedColumnWidth(62)},
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        for (final row in items)
          pw.TableRow(
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(row[0], style: t(8, bold: true))),
              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(row[1], style: t(8))),
            ],
          ),
      ],
    );
  }

  pw.Widget _pdfAnswerKeyTable({required List<PrintablePumpScenario> scenarios, required pw.TextStyle Function(double, {bool bold}) t}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      columnWidths: {
        0: const pw.FixedColumnWidth(56),
        1: const pw.FixedColumnWidth(56),
        2: const pw.FixedColumnWidth(64),
        3: const pw.FixedColumnWidth(56),
      },
      children: [
        pw.TableRow(
          children: [
            _pdfCell('Scenario', t(9, bold: true), fill: PdfColors.grey200),
            _pdfCell('FL', t(9, bold: true), fill: PdfColors.grey200),
            _pdfCell('Elev/App', t(9, bold: true), fill: PdfColors.grey200),
            _pdfCell('PP', t(9, bold: true), fill: PdfColors.grey200),
          ],
        ),
        for (var i = 0; i < scenarios.length; i++)
          pw.TableRow(
            children: [
              _pdfCell('${i + 1}', t(9)),
              _pdfCell('${scenarios[i].frictionLoss}', t(9)),
              _pdfCell('${scenarios[i].elevationPsi + scenarios[i].appliancePsi}', t(9)),
              _pdfCell('${scenarios[i].pumpPressureRounded}', t(9, bold: true)),
            ],
          ),
      ],
    );
  }

  pw.Widget _pdfCell(String text, pw.TextStyle style, {PdfColor? fill}) {
    return pw.Container(
      color: fill,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text, style: style),
    );
  }

  pw.Widget _pdfFooter(pw.TextStyle Function(double, {bool bold}) t) {
    return pw.Text(
      'Training worksheet only. Follow local SOPs, instructor direction, and department hydraulic guidelines.',
      style: t(8),
    );
  }

  void _pdfPaintScene(PdfGraphics canvas, PdfPoint size) {
    final w = size.x;
    final h = size.y;
    final stroke = PdfColor.fromInt(0xFF000000);
    final fill = PdfColor.fromInt(0xFFE6E6E6);

    canvas
      ..setColor(stroke)
      ..setLineWidth(1.0)
      ..moveTo(6, h - 10)
      ..lineTo(w - 6, h - 10)
      ..strokePath();

    final truckX = 10.0;
    final truckY = h - 30.0;
    const truckW = 40.0;
    const truckH = 16.0;
    canvas
      ..setColor(fill)
      ..drawRect(truckX, truckY, truckW, truckH)
      ..fillPath();
    canvas
      ..setColor(stroke)
      ..drawRect(truckX, truckY, truckW, truckH)
      ..strokePath();
    canvas
      ..drawEllipse(truckX + 8 - 3.3, (h - 12) - 3.3, 6.6, 6.6)
      ..strokePath();
    canvas
      ..drawEllipse(truckX + 28 - 3.3, (h - 12) - 3.3, 6.6, 6.6)
      ..strokePath();

    final targetX = w - 50.0;
    const targetY = 10.0;
    const targetW = 36.0;
    const targetH = 22.0;
    canvas
      ..setColor(stroke)
      ..drawRect(targetX, targetY, targetW, targetH)
      ..strokePath();
    canvas
      ..moveTo(targetX, targetY)
      ..lineTo(targetX + targetW / 2, targetY - 8)
      ..lineTo(targetX + targetW, targetY)
      ..closePath()
      ..strokePath();

    final p0x = truckX + truckW;
    final p0y = truckY;
    final p1x = w * 0.55;
    final p1y = h * 0.55;
    final p2x = targetX;
    final p2y = targetY + targetH;
    canvas
      ..moveTo(p0x, p0y)
      ..lineTo(p1x, p1y)
      ..lineTo(p2x, p2y)
      ..strokePath();

    canvas
      ..drawRect(p2x - 4, p2y - 2, 8, 4)
      ..strokePath();
  }

  String _fmtC(double c) => c == c.roundToDouble() ? c.toStringAsFixed(0) : c.toStringAsFixed(1);
}

class _PrintableHeader extends StatelessWidget {
  const _PrintableHeader({required this.title, required this.subtitle, required this.onBack});

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButton(onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: (textTheme.titleLarge ?? const TextStyle(fontSize: 22)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(subtitle, style: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: FirePumpSimColors.textMed, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.98 : 1,
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: FirePumpSimColors.charcoal2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.8)),
          ),
          child: const Icon(Icons.arrow_back, color: FirePumpSimColors.textHigh, size: 20),
        ),
      ),
    );
  }
}

class _BuilderCard extends StatelessWidget {
  const _BuilderCard({
    required this.titleController,
    required this.departmentController,
    required this.difficulty,
    required this.includeAnswerKey,
    required this.onDifficultyChanged,
    required this.onIncludeAnswerKeyChanged,
    required this.onGenerate,
    required this.onPrint,
    required this.printing,
  });

  final TextEditingController titleController;
  final TextEditingController departmentController;
  final PrintableWorksheetDifficulty difficulty;
  final bool includeAnswerKey;
  final ValueChanged<PrintableWorksheetDifficulty> onDifficultyChanged;
  final ValueChanged<bool> onIncludeAnswerKeyChanged;
  final VoidCallback onGenerate;
  final VoidCallback? onPrint;
  final bool printing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.print_outlined, color: FirePumpSimColors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Worksheet Builder', style: (textTheme.titleMedium ?? const TextStyle(fontSize: 16)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DarkTextField(
              controller: titleController,
              label: 'Worksheet Title',
              hint: 'Fire Pump Pressure Practice',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            _DarkTextField(
              controller: departmentController,
              label: 'Class / Department',
              hint: 'Driver / Operator Training',
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 10),
            _DarkDropdown<PrintableWorksheetDifficulty>(
              label: 'Difficulty',
              value: difficulty,
              items: const [
                DropdownMenuItem(value: PrintableWorksheetDifficulty.beginner, child: Text('Beginner')),
                DropdownMenuItem(value: PrintableWorksheetDifficulty.mixedBeginnerIntermediate, child: Text('Mixed beginner/intermediate')),
              ],
              onChanged: (v) {
                if (v != null) onDifficultyChanged(v);
              },
            ),
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              value: includeAnswerKey,
              onChanged: onIncludeAnswerKeyChanged,
              contentPadding: EdgeInsets.zero,
              dense: false,
              activeColor: FirePumpSimColors.red,
              title: Text('Include answer key', style: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800)),
              subtitle: Text('Adds a second page with answers + math', style: (textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, height: 1.35)),
            ),
            const SizedBox(height: 12),
            _PrimaryActionButton(
              label: 'Generate New Sheet',
              icon: Icons.auto_awesome,
              onTap: onGenerate,
            ),
            const SizedBox(height: 10),
            _SecondaryActionButton(
              label: printing ? 'Preparing PDF…' : 'Print / Save PDF',
              icon: Icons.picture_as_pdf_outlined,
              onTap: onPrint,
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  const _DarkTextField({required this.controller, required this.label, required this.hint, required this.textInputAction});

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      style: (textTheme.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: FirePumpSimColors.charcoal3.withValues(alpha: 0.6),
        labelStyle: (textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w700),
        hintStyle: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: FirePumpSimColors.textMed.withValues(alpha: 0.6)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: FirePumpSimColors.red, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _DarkDropdown<T> extends StatelessWidget {
  const _DarkDropdown({required this.label, required this.value, required this.items, required this.onChanged});

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: FirePumpSimColors.charcoal2,
      iconEnabledColor: FirePumpSimColors.textHigh,
      style: (textTheme.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: FirePumpSimColors.charcoal3.withValues(alpha: 0.6),
        labelStyle: (textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w700),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: FirePumpSimColors.red, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _PrimaryActionButton extends StatefulWidget {
  const _PrimaryActionButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.985 : 1,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: FirePumpSimColors.red,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(widget.label, style: (textTheme.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatefulWidget {
  const _SecondaryActionButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_SecondaryActionButton> createState() => _SecondaryActionButtonState();
}

class _SecondaryActionButtonState extends State<_SecondaryActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.985 : 1,
        child: Opacity(
          opacity: enabled ? 1 : 0.65,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: FirePumpSimColors.charcoal3.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.95)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: FirePumpSimColors.textHigh, size: 20),
                const SizedBox(width: 10),
                Text(widget.label, style: (textTheme.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorksheetPreview extends StatelessWidget {
  const _WorksheetPreview({required this.worksheetTitle, required this.department, required this.scenarios, required this.includeAnswerKey});

  final String worksheetTitle;
  final String department;
  final List<PrintablePumpScenario> scenarios;
  final bool includeAnswerKey;

  static const _optionalTruckAsset = 'assets/printable-scenarios/fire-truck.png';
  static const _optionalHouseAsset = 'assets/printable-scenarios/house-fire.png';
  static const _optionalBuildingAsset = 'assets/printable-scenarios/urban-building.png';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 8.5 / 11.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.22)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: DefaultTextStyle(
                      style: (textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: Colors.black, height: 1.25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PreviewHeader(title: worksheetTitle, department: department),
                          const SizedBox(height: 10),
                          for (var i = 0; i < scenarios.length; i++) ...[
                            _PreviewScenarioRow(
                              index: i + 1,
                              scenario: scenarios[i],
                              includeAnswerKeyInline: false,
                              showAnswer: false,
                              truckAssetPath: _optionalTruckAsset,
                              targetAssetPath: scenarios[i].targetType.startsWith('House') ? _optionalHouseAsset : _optionalBuildingAsset,
                            ),
                            if (i != scenarios.length - 1) const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 10),
                          const _PreviewFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (includeAnswerKey) ...[
              const SizedBox(height: 12),
              Text('Answer key will print as page 2.', style: (textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, height: 1.35)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.title, required this.department});

  final String title;
  final String department;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: (t.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(fontWeight: FontWeight.w900, color: Colors.black))),
              const SizedBox(width: 10),
              Expanded(child: Text(department, textAlign: TextAlign.right, style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(fontWeight: FontWeight.w800, color: Colors.black))),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(child: Text('Generated by FirePumpSim', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87))),
              Text('Date: __________', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewScenarioRow extends StatelessWidget {
  const _PreviewScenarioRow({
    required this.index,
    required this.scenario,
    required this.truckAssetPath,
    required this.targetAssetPath,
    required this.showAnswer,
    required this.includeAnswerKeyInline,
  });

  final int index;
  final PrintablePumpScenario scenario;
  final String truckAssetPath;
  final String targetAssetPath;
  final bool showAnswer;
  final bool includeAnswerKeyInline;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('$index. ${scenario.title}', style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(fontWeight: FontWeight.w900, color: Colors.black))),
              Text('Single Line', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 118,
                height: 64,
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 0.8)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: 4,
                        bottom: 4,
                        width: 42,
                        height: 26,
                        child: Image.asset(truckAssetPath, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                      ),
                      Positioned(
                        right: 6,
                        top: 4,
                        width: 40,
                        height: 30,
                        child: Image.asset(targetAssetPath, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                      ),
                      CustomPaint(
                        painter: _PrintableScenePainter(
                          hoseLabel: '${scenario.hoseDiameterLabel} • ${scenario.lengthFt} ft',
                          flowLabel: '${scenario.gpm} GPM',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(scenario.problem, style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87, height: 1.25)),
                    const SizedBox(height: 6),
                    _FactsGrid(scenario: scenario),
                    const SizedBox(height: 6),
                    Text('PP = NP + FL ± Elevation + Appliance', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(fontWeight: FontWeight.w900, color: Colors.black)),
                    Text('FL = C × (GPM/100)² × Length/100', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: Text('NP: ______', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black))),
                        Expanded(child: Text('FL: ______', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black))),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(child: Text('Elev/App: ______', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black))),
                        Expanded(child: Text('Final PP: ______', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black))),
                      ],
                    ),
                    if (includeAnswerKeyInline && showAnswer) ...[
                      const SizedBox(height: 6),
                      Text('Answer: ${scenario.pumpPressureRounded} PSI', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(fontWeight: FontWeight.w900, color: Colors.black)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FactsGrid extends StatelessWidget {
  const _FactsGrid({required this.scenario});
  final PrintablePumpScenario scenario;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = <({String k, String v})>[
      (k: 'Hose', v: '${scenario.hoseDiameterLabel} • ${scenario.lengthFt} ft'),
      (k: 'C', v: scenario.cValue == scenario.cValue.roundToDouble() ? scenario.cValue.toStringAsFixed(0) : scenario.cValue.toStringAsFixed(1)),
      (k: 'Nozzle', v: scenario.nozzleLabel),
      (k: 'Flow', v: '${scenario.gpm} GPM @ ${scenario.np} PSI'),
      (k: 'Elevation', v: '${scenario.elevationFeet} ft (${scenario.elevationPsi} PSI)'),
      (k: 'Appliance', v: '${scenario.appliancePsi} PSI'),
    ];

    return Table(
      border: TableBorder.all(color: Colors.black, width: 0.7),
      columnWidths: const {0: FixedColumnWidth(58)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final r in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(3),
                child: Text(r.k, style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(fontWeight: FontWeight.w900, color: Colors.black)),
              ),
              Padding(
                padding: const EdgeInsets.all(3),
                child: Text(r.v, style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87)),
              ),
            ],
          ),
      ],
    );
  }
}

class _PreviewFooter extends StatelessWidget {
  const _PreviewFooter();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Text(
      'Training worksheet only. Follow local SOPs, instructor direction, and department hydraulic guidelines.',
      style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87, height: 1.25),
    );
  }
}

class _PrintableScenePainter extends CustomPainter {
  _PrintableScenePainter({required this.hoseLabel, required this.flowLabel});

  final String hoseLabel;
  final String flowLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final fill = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    // Ground line.
    canvas.drawLine(Offset(4, size.height - 10), Offset(size.width - 4, size.height - 10), stroke);

    // Truck fallback (bottom-left).
    final truck = Rect.fromLTWH(10, size.height - 30, 40, 16);
    canvas.drawRect(truck, stroke);
    canvas.drawRect(truck.deflate(0.5), fill);
    canvas.drawCircle(Offset(18, size.height - 12), 3.2, stroke);
    canvas.drawCircle(Offset(38, size.height - 12), 3.2, stroke);

    // Target fallback (top-right).
    final target = Rect.fromLTWH(size.width - 50, 10, 36, 22);
    canvas.drawRect(target, stroke);
    final roof = Path()
      ..moveTo(target.left, target.top)
      ..lineTo(target.left + target.width / 2, target.top - 8)
      ..lineTo(target.right, target.top)
      ..close();
    canvas.drawPath(roof, stroke);

    // Hose.
    final p0 = Offset(truck.right, truck.top);
    final p2 = Offset(target.left, target.bottom);
    final c1 = Offset(size.width * 0.55, size.height * 0.55);
    final hose = Path()..moveTo(p0.dx, p0.dy)..quadraticBezierTo(c1.dx, c1.dy, p2.dx, p2.dy);
    canvas.drawPath(hose, stroke);

    // Nozzle.
    canvas.drawRect(Rect.fromCenter(center: p2, width: 8, height: 4), stroke);

    // Labels (printer-friendly).
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(text: hoseLabel, style: const TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.w700));
    textPainter.layout(maxWidth: size.width - 8);
    textPainter.paint(canvas, const Offset(4, 2));

    textPainter.text = TextSpan(text: flowLabel, style: const TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.w700));
    textPainter.layout(maxWidth: size.width - 8);
    textPainter.paint(canvas, Offset(size.width - 4 - textPainter.width, 2));
  }

  @override
  bool shouldRepaint(covariant _PrintableScenePainter oldDelegate) {
    return oldDelegate.hoseLabel != hoseLabel || oldDelegate.flowLabel != flowLabel;
  }
}
