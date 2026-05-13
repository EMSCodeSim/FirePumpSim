import 'dart:math';
import 'dart:typed_data';

import 'package:firepumpsim/models/printable_pump_scenario.dart';
import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' as pr;

class PrintableScenarioAssetPack {
  const PrintableScenarioAssetPack._();

  static const truck = 'assets/printable/fire-truck.png';
  static const building = 'assets/printable/urban-building.png';
  static const sedan = 'assets/printable/sedan.png';
  static const hydrant = 'assets/printable/hydrant.png';
  static const bush = 'assets/printable/bush.png';

  static List<String> targetAssetsFor(PrintableTargetArtwork artwork) {
    return switch (artwork) {
      PrintableTargetArtwork.building => [building],
      PrintableTargetArtwork.sedan => [sedan],
      PrintableTargetArtwork.brush => [bush],
      PrintableTargetArtwork.hydrant => [hydrant],
      PrintableTargetArtwork.buildingAndBrush => [building, bush],
      PrintableTargetArtwork.sedanAndBrush => [sedan, bush],
    };
  }
}

class PrintableScenariosScreen extends StatefulWidget {
  const PrintableScenariosScreen({super.key});

  @override
  State<PrintableScenariosScreen> createState() => _PrintableScenariosScreenState();
}

enum _PreviewMode { worksheet, answerKey }

class _PrintableScenariosScreenState extends State<PrintableScenariosScreen> {
  final _titleController = TextEditingController(text: 'Fire Pump Pressure Practice');
  final _deptController = TextEditingController(text: 'Driver / Operator Training');

  final PrintableScenarioGenerator _generator = PrintableScenarioGenerator();

  PrintableScenarioMode _mode = PrintableScenarioMode.randomSheet;
  _PreviewMode _previewMode = _PreviewMode.worksheet;

  PrintableWorksheetDifficulty _difficulty = PrintableWorksheetDifficulty.beginner;
  int _scenarioCount = 4;
  bool _includeAnswerKey = true;

  late List<PrintablePumpScenario> _scenarios;
  bool _printing = false;

  // Builder state.
  final _builderTitleController = TextEditingController(text: 'Custom Pump Scenario');
  PrintableScenarioType _builderScenarioType = PrintableScenarioType.attackLine;
  PrintableTargetArtwork _builderTargetArtwork = PrintableTargetArtwork.building;
  PrintableHoseSize _builderHoseSize = PrintableHoseSize.inch175;
  final _builderCController = TextEditingController(text: '15.5');
  bool _cManuallyEdited = false;
  int _builderLengthFt = 200;
  bool _builderCustomLength = false;
  final _builderCustomLengthController = TextEditingController(text: '200');

  String _builderNozzle = _nozzleOptions.first.label;
  bool _builderCustomNozzle = false;
  final _builderCustomNozzleLabelController = TextEditingController(text: 'Custom Nozzle');
  final _builderCustomGpmController = TextEditingController(text: '150');
  final _builderCustomNpController = TextEditingController(text: '50');

  final _builderElevationController = TextEditingController(text: '0');
  int _builderAppliancePsi = 0;
  final _builderProblemController = TextEditingController(
    text: 'Engine 181 is stretching one attack line to a vehicle fire. Calculate the pump discharge pressure.',
  );
  int? _selectedScenarioIndex;

  @override
  void initState() {
    super.initState();
    _scenarios = _generator.generatePrintableSheet(difficulty: _difficulty, scenarioCount: _scenarioCount);
    _titleController.addListener(_onMetaChanged);
    _deptController.addListener(_onMetaChanged);
    _builderCController.addListener(_onCChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onMetaChanged);
    _deptController.removeListener(_onMetaChanged);
    _builderCController.removeListener(_onCChanged);
    _titleController.dispose();
    _deptController.dispose();
    _builderTitleController.dispose();
    _builderCController.dispose();
    _builderCustomLengthController.dispose();
    _builderCustomNozzleLabelController.dispose();
    _builderCustomGpmController.dispose();
    _builderCustomNpController.dispose();
    _builderElevationController.dispose();
    _builderProblemController.dispose();
    super.dispose();
  }

  void _onMetaChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onCChanged() {
    // If user types directly, treat as manual override.
    if (!mounted) return;
    if (!_cManuallyEdited) {
      setState(() => _cManuallyEdited = true);
    }
  }

  String get _worksheetTitle => _titleController.text.trim().isEmpty ? 'Fire Pump Pressure Practice' : _titleController.text.trim();
  String get _worksheetDept => _deptController.text.trim().isEmpty ? 'Driver / Operator Training' : _deptController.text.trim();

  void _setScenarioCount(int v) {
    if (_scenarioCount == v) return;
    setState(() {
      _scenarioCount = v;
      if (_scenarios.length > v) {
        _scenarios = _scenarios.take(v).toList(growable: true);
      }
      if (_scenarios.length < v) {
        // Keep existing work; pad with random scenarios.
        final needed = v - _scenarios.length;
        final extra = _generator.generatePrintableSheet(difficulty: _difficulty, scenarioCount: needed);
        _scenarios = [..._scenarios, ...extra];
      }
      if (_selectedScenarioIndex != null && _selectedScenarioIndex! >= _scenarios.length) {
        _selectedScenarioIndex = null;
      }
    });
  }

  void _setDifficulty(PrintableWorksheetDifficulty d) {
    if (_difficulty == d) return;
    setState(() => _difficulty = d);
  }

  void _generateRandomSheet() {
    setState(() {
      _scenarios = _generator.generatePrintableSheet(difficulty: _difficulty, scenarioCount: _scenarioCount);
      _selectedScenarioIndex = null;
      _previewMode = _PreviewMode.worksheet;
    });
  }

  void _syncDefaultCFromHose({required bool force}) {
    final next = PrintableScenarioGenerator.defaultC[_builderHoseSize] ?? 15.5;
    if (!force && _cManuallyEdited) return;
    _cManuallyEdited = false;
    _builderCController.text = _fmtC(next);
  }

  void _syncDefaultProblemFromType() {
    if (_selectedScenarioIndex != null) return; // editing existing: do not overwrite.
    _builderProblemController.text = _defaultProblemFor(_builderScenarioType);
  }

  PrintablePumpScenario _buildScenarioFromBuilder({String? id}) {
    final title = _builderTitleController.text.trim().isEmpty ? 'Custom Pump Scenario' : _builderTitleController.text.trim();
    final length = _builderCustomLength ? int.tryParse(_builderCustomLengthController.text.trim()) ?? _builderLengthFt : _builderLengthFt;
    final cVal = double.tryParse(_builderCController.text.trim()) ?? (PrintableScenarioGenerator.defaultC[_builderHoseSize] ?? 15.5);
    final elevationFeet = int.tryParse(_builderElevationController.text.trim()) ?? 0;

    final nozzle = _builderCustomNozzle
        ? (label: _builderCustomNozzleLabelController.text.trim().isEmpty ? 'Custom Nozzle' : _builderCustomNozzleLabelController.text.trim(), gpm: int.tryParse(_builderCustomGpmController.text.trim()) ?? 150, np: int.tryParse(_builderCustomNpController.text.trim()) ?? 50)
        : _nozzleOptions.firstWhere((e) => e.label == _builderNozzle, orElse: () => _nozzleOptions.first);

    final nozzleLabel = _builderCustomNozzle
        ? '${nozzle.label} — ${nozzle.gpm} GPM @ ${nozzle.np} PSI'
        : nozzle.label;

    final problem = _builderProblemController.text.trim().isEmpty ? _defaultProblemFor(_builderScenarioType) : _builderProblemController.text.trim();

    return PrintableScenarioCalculator.buildScenario(
      id: id ?? 'pws_custom_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}',
      inputs: PrintableScenarioInputs(
        title: title,
        scenarioType: _builderScenarioType,
        targetArtwork: _builderTargetArtwork,
        hoseSize: _builderHoseSize,
        cValue: cVal,
        lengthFt: max(1, length),
        nozzleLabel: nozzleLabel,
        gpm: max(1, nozzle.gpm),
        np: max(0, nozzle.np),
        elevationFeet: elevationFeet,
        appliancePsi: max(0, _builderAppliancePsi),
        problem: problem,
      ),
    );
  }

  void _addToWorksheet() {
    if (_scenarios.length >= _scenarioCount) {
      _toast('Worksheet is full ($_scenarioCount scenarios). Use “Replace Selected” or increase count.');
      return;
    }
    setState(() {
      _scenarios = [..._scenarios, _buildScenarioFromBuilder()];
      _selectedScenarioIndex = null;
    });
  }

  void _replaceSelected() {
    final idx = _selectedScenarioIndex;
    if (idx == null) {
      _toast('Select a scenario to replace first.');
      return;
    }
    setState(() {
      final existingId = _scenarios[idx].id;
      _scenarios[idx] = _buildScenarioFromBuilder(id: existingId);
    });
  }

  void _clearBuilder() {
    setState(() {
      _selectedScenarioIndex = null;
      _builderTitleController.text = 'Custom Pump Scenario';
      _builderScenarioType = PrintableScenarioType.attackLine;
      _builderTargetArtwork = PrintableTargetArtwork.building;
      _builderHoseSize = PrintableHoseSize.inch175;
      _syncDefaultCFromHose(force: true);
      _builderLengthFt = 200;
      _builderCustomLength = false;
      _builderCustomLengthController.text = '200';
      _builderNozzle = _nozzleOptions.first.label;
      _builderCustomNozzle = false;
      _builderCustomNozzleLabelController.text = 'Custom Nozzle';
      _builderCustomGpmController.text = '150';
      _builderCustomNpController.text = '50';
      _builderElevationController.text = '0';
      _builderAppliancePsi = 0;
      _builderProblemController.text = _defaultProblemFor(_builderScenarioType);
    });
  }

  void _randomizeThisScenario() {
    final randomScenario = _generator.generatePrintableScenario(index: 1, difficulty: _difficulty);
    setState(() {
      _applyScenarioToBuilder(randomScenario);
      _selectedScenarioIndex = null;
    });
  }

  void _applyScenarioToBuilder(PrintablePumpScenario s) {
    _builderTitleController.text = s.title;
    _builderScenarioType = s.scenarioType;
    _builderTargetArtwork = s.targetArtwork;
    _builderHoseSize = s.hoseSize;
    _cManuallyEdited = false;
    _builderCController.text = _fmtC(s.cValue);
    _builderLengthFt = s.lengthFt;
    _builderCustomLength = false;
    _builderCustomLengthController.text = s.lengthFt.toString();
    final match = _nozzleOptions.where((n) => n.label == s.nozzleLabel).toList(growable: false);
    if (match.isNotEmpty) {
      _builderCustomNozzle = false;
      _builderNozzle = s.nozzleLabel;
    } else {
      _builderCustomNozzle = true;
      _builderNozzle = _nozzleOptions.first.label;
      // Try to parse: "Label — 150 GPM @ 50 PSI"
      final parts = s.nozzleLabel.split('—');
      _builderCustomNozzleLabelController.text = parts.first.trim().isEmpty ? 'Custom Nozzle' : parts.first.trim();
      final gpmMatch = RegExp(r'(\d+)\s*GPM').firstMatch(s.nozzleLabel);
      final npMatch = RegExp(r'@\s*(\d+)\s*PSI', caseSensitive: false).firstMatch(s.nozzleLabel);
      _builderCustomGpmController.text = (gpmMatch?.group(1) ?? s.gpm.toString());
      _builderCustomNpController.text = (npMatch?.group(1) ?? s.np.toString());
    }
    _builderElevationController.text = s.elevationFeet.toString();
    _builderAppliancePsi = s.appliancePsi;
    _builderProblemController.text = s.problem;
  }

  void _editScenario(int index) {
    setState(() {
      _selectedScenarioIndex = index;
      _applyScenarioToBuilder(_scenarios[index]);
      _mode = PrintableScenarioMode.createScenario;
    });
  }

  void _duplicateScenario(int index) {
    if (_scenarios.length >= _scenarioCount) {
      _toast('Worksheet is full ($_scenarioCount scenarios).');
      return;
    }
    final s = _scenarios[index];
    setState(() {
      _scenarios = [
        ..._scenarios.take(index + 1),
        s.copyWith(id: 'pws_dup_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}'),
        ..._scenarios.skip(index + 1),
      ];
    });
  }

  void _deleteScenario(int index) {
    setState(() {
      _scenarios = [..._scenarios]..removeAt(index);
      if (_selectedScenarioIndex == index) _selectedScenarioIndex = null;
      if (_selectedScenarioIndex != null && _selectedScenarioIndex! > index) _selectedScenarioIndex = _selectedScenarioIndex! - 1;
    });
  }

  void _moveScenario(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _scenarios.length) return;
    setState(() {
      final copy = [..._scenarios];
      final item = copy.removeAt(index);
      copy.insert(newIndex, item);
      _scenarios = copy;
      if (_selectedScenarioIndex == index) {
        _selectedScenarioIndex = newIndex;
      } else if (_selectedScenarioIndex == newIndex) {
        _selectedScenarioIndex = index;
      }
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: FirePumpSimColors.charcoal3,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                subtitle: 'Build pump pressure worksheets or generate random practice sheets.',
                onBack: () => context.go(AppRoutes.home),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: _ModeSegmentedControl(
                  mode: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: _MetaCard(titleController: _titleController, departmentController: _deptController),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _mode == PrintableScenarioMode.randomSheet
                      ? _RandomSheetCard(
                          key: const ValueKey('random'),
                          difficulty: _difficulty,
                          scenarioCount: _scenarioCount,
                          includeAnswerKey: _includeAnswerKey,
                          printing: _printing,
                          onDifficultyChanged: _setDifficulty,
                          onScenarioCountChanged: _setScenarioCount,
                          onIncludeAnswerKeyChanged: (v) => setState(() => _includeAnswerKey = v),
                          onGenerate: _generateRandomSheet,
                          onPrint: _printing ? null : _handlePrint,
                        )
                      : _ScenarioBuilderCard(
                          key: const ValueKey('builder'),
                          scenarioCount: _scenarioCount,
                          currentCount: _scenarios.length,
                          selectedIndex: _selectedScenarioIndex,
                          titleController: _builderTitleController,
                          scenarioType: _builderScenarioType,
                          targetArtwork: _builderTargetArtwork,
                          hoseSize: _builderHoseSize,
                          cController: _builderCController,
                          customLength: _builderCustomLength,
                          lengthFt: _builderLengthFt,
                          customLengthController: _builderCustomLengthController,
                          nozzleValue: _builderNozzle,
                          customNozzle: _builderCustomNozzle,
                          customNozzleLabelController: _builderCustomNozzleLabelController,
                          customGpmController: _builderCustomGpmController,
                          customNpController: _builderCustomNpController,
                          elevationController: _builderElevationController,
                          appliancePsi: _builderAppliancePsi,
                          problemController: _builderProblemController,
                          calculatedScenario: _buildScenarioFromBuilder(id: 'preview'),
                          onScenarioTypeChanged: (v) {
                            setState(() {
                              _builderScenarioType = v;
                              _syncDefaultProblemFromType();
                              _builderTargetArtwork = _defaultArtworkForScenarioType(v);
                            });
                          },
                          onTargetArtworkChanged: (v) => setState(() => _builderTargetArtwork = v),
                          onHoseSizeChanged: (v) {
                            setState(() {
                              _builderHoseSize = v;
                              _syncDefaultCFromHose(force: false);
                            });
                          },
                          onCValueEdited: () => setState(() => _cManuallyEdited = true),
                          onLengthChanged: (len, isCustom) {
                            setState(() {
                              _builderLengthFt = len;
                              _builderCustomLength = isCustom;
                              if (!isCustom) _builderCustomLengthController.text = len.toString();
                            });
                          },
                          onNozzleChanged: (value, isCustom) => setState(() {
                            _builderNozzle = value;
                            _builderCustomNozzle = isCustom;
                          }),
                          onAppliancePsiChanged: (v) => setState(() => _builderAppliancePsi = v),
                          onAddToWorksheet: _addToWorksheet,
                          onReplaceSelected: _replaceSelected,
                          onClear: _clearBuilder,
                          onRandomize: _randomizeThisScenario,
                        ),
                ),
              ),
            ),
            if (_mode == PrintableScenarioMode.createScenario)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                sliver: SliverToBoxAdapter(
                  child: _WorksheetListCard(
                    textTheme: textTheme,
                    scenarios: _scenarios,
                    selectedIndex: _selectedScenarioIndex,
                    scenarioCountLimit: _scenarioCount,
                    onEdit: _editScenario,
                    onDuplicate: _duplicateScenario,
                    onDelete: _deleteScenario,
                    onMoveUp: (i) => _moveScenario(i, -1),
                    onMoveDown: (i) => _moveScenario(i, 1),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: _PreviewCard(
                  worksheetTitle: _worksheetTitle,
                  department: _worksheetDept,
                  scenarios: _scenarios,
                  includeAnswerKey: _includeAnswerKey,
                  previewMode: _previewMode,
                  printing: _printing,
                  onPreviewWorksheet: () => setState(() => _previewMode = _PreviewMode.worksheet),
                  onPreviewAnswerKey: _includeAnswerKey ? () => setState(() => _previewMode = _PreviewMode.answerKey) : null,
                  onPrint: _printing ? null : _handlePrint,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePrint() async {
    setState(() => _printing = true);
    try {
      final bytes = await _buildPdfBytes(
        worksheetTitle: _worksheetTitle,
        department: _worksheetDept,
        scenarios: _scenarios,
        includeAnswerKey: _includeAnswerKey,
      );
      await pr.Printing.layoutPdf(name: 'FirePumpSim Worksheet', onLayout: (format) async => bytes);
    } catch (e) {
      debugPrint('Print/Save PDF failed: $e');
      _toast('Unable to print / save PDF on this device.');
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
    final pdfAssets = await _loadPdfSceneImages();
    final doc = pw.Document();
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
                _pdfScenarioRow(index: i + 1, scenario: scenarios[i], t: t, assets: pdfAssets),
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

  Future<Map<String, pw.ImageProvider>> _loadPdfSceneImages() async {
    Future<pw.ImageProvider?> load(String path) async {
      try {
        final data = await rootBundle.load(path);
        return pw.MemoryImage(data.buffer.asUint8List());
      } catch (e) {
        debugPrint('Printable PDF image missing ($path): $e');
        return null;
      }
    }

    final entries = <String, pw.ImageProvider?>{
      PrintableScenarioAssetPack.truck: await load(PrintableScenarioAssetPack.truck),
      PrintableScenarioAssetPack.building: await load(PrintableScenarioAssetPack.building),
      PrintableScenarioAssetPack.sedan: await load(PrintableScenarioAssetPack.sedan),
      PrintableScenarioAssetPack.hydrant: await load(PrintableScenarioAssetPack.hydrant),
      PrintableScenarioAssetPack.bush: await load(PrintableScenarioAssetPack.bush),
    };

    return {for (final e in entries.entries) if (e.value != null) e.key: e.value!};
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

  pw.Widget _pdfScenarioRow({
    required int index,
    required PrintablePumpScenario scenario,
    required pw.TextStyle Function(double, {bool bold}) t,
    required Map<String, pw.ImageProvider> assets,
  }) {
    final truck = assets[PrintableScenarioAssetPack.truck];
    final targets = PrintableScenarioAssetPack.targetAssetsFor(scenario.targetArtwork).map((p) => assets[p]).whereType<pw.ImageProvider>().toList(growable: false);

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            children: [
              pw.Expanded(child: pw.Text('$index. ${scenario.title}', style: t(11, bold: true))),
              pw.Text(_typeLabel(scenario.scenarioType), style: t(9)),
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
                              painter: (PdfGraphics canvas, PdfPoint size) => _pdfPaintSceneBackground(
                                canvas,
                                size,
                                drawFallbackTruck: truck == null,
                                drawFallbackTarget: targets.isEmpty,
                              ),
                            ),
                          ),
                      if (truck != null)
                        pw.Positioned(left: 4, bottom: 4, child: pw.SizedBox(width: 44, height: 26, child: pw.Image(truck, fit: pw.BoxFit.contain))),
                      if (targets.isNotEmpty) ..._pdfTargetPositions(targets),
                      pw.Positioned.fill(
                        child: pw.CustomPaint(
                          painter: (PdfGraphics canvas, PdfPoint size) => _pdfPaintScene(
                            canvas,
                            size,
                            hoseLabel: '${scenario.hoseDiameterLabel} • ${scenario.lengthFt} ft',
                            flowLabel: '${scenario.gpm} GPM',
                          ),
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

  List<pw.Widget> _pdfTargetPositions(List<pw.ImageProvider> targets) {
    if (targets.length == 1) {
      return [pw.Positioned(right: 4, top: 4, child: pw.SizedBox(width: 40, height: 30, child: pw.Image(targets.first, fit: pw.BoxFit.contain)))];
    }
    return [
      pw.Positioned(right: 4, top: 4, child: pw.SizedBox(width: 40, height: 30, child: pw.Image(targets[0], fit: pw.BoxFit.contain))),
      pw.Positioned(right: 6, bottom: 6, child: pw.SizedBox(width: 18, height: 18, child: pw.Image(targets[1], fit: pw.BoxFit.contain))),
    ];
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
      columnWidths: {0: const pw.FixedColumnWidth(56), 1: const pw.FixedColumnWidth(56), 2: const pw.FixedColumnWidth(64), 3: const pw.FixedColumnWidth(56)},
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
    return pw.Container(color: fill, padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.Text(text, style: style));
  }

  pw.Widget _pdfFooter(pw.TextStyle Function(double, {bool bold}) t) {
    return pw.Text('Training worksheet only. Follow local SOPs, instructor direction, and department hydraulic guidelines.', style: t(8));
  }

  void _pdfPaintScene(
    PdfGraphics canvas,
    PdfPoint size, {
    required String hoseLabel,
    required String flowLabel,
  }) {
    final w = size.x;
    final h = size.y;

    final stroke = PdfColor.fromInt(0xFF000000);
    final faint = PdfColor.fromInt(0xFFEEEEEE);

    // Hose path.
    final truckAnchor = PdfPoint(50, h - 26);
    final targetAnchor = PdfPoint(w - 44, 28);
    final control = PdfPoint(w * 0.58, h * 0.55);
    canvas
      ..setColor(stroke)
      ..setLineWidth(1.0)
      ..moveTo(truckAnchor.x, truckAnchor.y)
      ..lineTo(control.x, control.y)
      ..lineTo(targetAnchor.x, targetAnchor.y)
      ..strokePath();

    // Nozzle at the end of the line.
    canvas
      ..drawRect(targetAnchor.x - 4, targetAnchor.y - 2, 8, 4)
      ..strokePath();

  }

  void _pdfPaintSceneBackground(
    PdfGraphics canvas,
    PdfPoint size, {
    required bool drawFallbackTruck,
    required bool drawFallbackTarget,
  }) {
    final w = size.x;
    final h = size.y;

    final stroke = PdfColor.fromInt(0xFF000000);
    final faint = PdfColor.fromInt(0xFFEEEEEE);

    // Background / groundline.
    canvas
      ..setColor(stroke)
      ..setLineWidth(1.0)
      ..moveTo(6, h - 10)
      ..lineTo(w - 6, h - 10)
      ..strokePath();

    // Fallback shapes if assets are missing.
    if (drawFallbackTruck) {
      canvas
        ..setColor(faint)
        ..drawRect(10, h - 30, 40, 16)
        ..fillPath();
      canvas
        ..setColor(stroke)
        ..drawRect(10, h - 30, 40, 16)
        ..strokePath();
    }
    if (drawFallbackTarget) {
      canvas
        ..setColor(stroke)
        ..drawRect(w - 50, 10, 36, 22)
        ..strokePath();
    }
  }
}

/// Public, reusable scene widget for phone preview.
class PrintableSceneWidget extends StatefulWidget {
  const PrintableSceneWidget({
    super.key,
    required this.targetArtwork,
    required this.hoseLabel,
    required this.flowLabel,
  });

  final PrintableTargetArtwork targetArtwork;
  final String hoseLabel;
  final String flowLabel;

  @override
  State<PrintableSceneWidget> createState() => _PrintableSceneWidgetState();
}

class _PrintableSceneWidgetState extends State<PrintableSceneWidget> {
  bool _truckOk = true;
  final Map<String, bool> _targetOkByAsset = <String, bool>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache();
  }

  @override
  void didUpdateWidget(covariant PrintableSceneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetArtwork != widget.targetArtwork) _precache();
  }

  Future<void> _precache() async {
    Future<bool> cache(String path) async {
      try {
        await precacheImage(AssetImage(path), context);
        return true;
      } catch (e) {
        debugPrint('Printable artwork missing ($path): $e');
        return false;
      }
    }

    final targets = PrintableScenarioAssetPack.targetAssetsFor(widget.targetArtwork);
    final okTruck = await cache(PrintableScenarioAssetPack.truck);
    final okMap = <String, bool>{};
    for (final t in targets) {
      okMap[t] = await cache(t);
    }

    if (!mounted) return;
    setState(() {
      _truckOk = okTruck;
      _targetOkByAsset
        ..clear()
        ..addAll(okMap);
    });
  }

  @override
  Widget build(BuildContext context) {
    final targets = PrintableScenarioAssetPack.targetAssetsFor(widget.targetArtwork);
    final anyTargetOk = targets.any((t) => _targetOkByAsset[t] == true);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _PrintableSceneBackgroundPainter(
              drawFallbackTruck: !_truckOk,
              drawFallbackTarget: !anyTargetOk,
            ),
          ),
        ),
        if (_truckOk)
          Positioned(
            left: 4,
            bottom: 4,
            width: 42,
            height: 26,
            child: Image.asset(PrintableScenarioAssetPack.truck, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
          ),
        ..._targetWidgets(targets),
        Positioned.fill(
          child: CustomPaint(
            painter: _PrintableHosePainter(
              hoseLabel: widget.hoseLabel,
              flowLabel: widget.flowLabel,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _targetWidgets(List<String> targets) {
    Widget img(String path, {double? w, double? h}) {
      if (_targetOkByAsset[path] != true) return const SizedBox();
      return Image.asset(path, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox());
    }

    if (targets.length == 1) {
      return [Positioned(right: 6, top: 4, width: 40, height: 30, child: img(targets.first))];
    }
    return [
      Positioned(right: 6, top: 4, width: 40, height: 30, child: img(targets[0])),
      Positioned(right: 6, bottom: 6, width: 18, height: 18, child: img(targets[1])),
    ];
  }
}

class _PrintableSceneBackgroundPainter extends CustomPainter {
  const _PrintableSceneBackgroundPainter({required this.drawFallbackTruck, required this.drawFallbackTarget});

  final bool drawFallbackTruck;
  final bool drawFallbackTarget;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1;
    final fill = Paint()..color = Colors.black.withValues(alpha: 0.06)..style = PaintingStyle.fill;

    // Background / groundline.
    canvas.drawLine(Offset(4, size.height - 10), Offset(size.width - 4, size.height - 10), stroke);

    // Fallback shapes ONLY if the asset image(s) are missing.
    final truck = Rect.fromLTWH(10, size.height - 30, 40, 16);
    final target = Rect.fromLTWH(size.width - 50, 10, 36, 22);

    if (drawFallbackTruck) {
      canvas.drawRect(truck, stroke);
      canvas.drawRect(truck.deflate(0.5), fill);
      canvas.drawCircle(Offset(18, size.height - 12), 3.2, stroke);
      canvas.drawCircle(Offset(38, size.height - 12), 3.2, stroke);
    }
    if (drawFallbackTarget) {
      canvas.drawRect(target, stroke);
      final roof = Path()..moveTo(target.left, target.top)..lineTo(target.left + target.width / 2, target.top - 8)..lineTo(target.right, target.top)..close();
      canvas.drawPath(roof, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _PrintableSceneBackgroundPainter oldDelegate) {
    return oldDelegate.drawFallbackTruck != drawFallbackTruck || oldDelegate.drawFallbackTarget != drawFallbackTarget;
  }
}

class _PrintableHosePainter extends CustomPainter {
  const _PrintableHosePainter({
    required this.hoseLabel,
    required this.flowLabel,
  });

  final String hoseLabel;
  final String flowLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1;
    final truck = Rect.fromLTWH(10, size.height - 30, 40, 16);
    final target = Rect.fromLTWH(size.width - 50, 10, 36, 22);

    final p0 = Offset(truck.right, truck.top);
    final p2 = Offset(target.left, target.bottom);
    final c1 = Offset(size.width * 0.55, size.height * 0.55);
    final hose = Path()..moveTo(p0.dx, p0.dy)..quadraticBezierTo(c1.dx, c1.dy, p2.dx, p2.dy);
    canvas.drawPath(hose, stroke);

    canvas.drawRect(Rect.fromCenter(center: p2, width: 8, height: 4), stroke);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(text: hoseLabel, style: const TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.w700));
    textPainter.layout(maxWidth: size.width - 8);
    textPainter.paint(canvas, const Offset(4, 2));

    textPainter.text = TextSpan(text: flowLabel, style: const TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.w700));
    textPainter.layout(maxWidth: size.width - 8);
    textPainter.paint(canvas, Offset(size.width - 4 - textPainter.width, 2));
  }

  @override
  bool shouldRepaint(covariant _PrintableHosePainter oldDelegate) {
    return oldDelegate.hoseLabel != hoseLabel || oldDelegate.flowLabel != flowLabel;
  }
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

class _ModeSegmentedControl extends StatelessWidget {
  const _ModeSegmentedControl({required this.mode, required this.onChanged});
  final PrintableScenarioMode mode;
  final ValueChanged<PrintableScenarioMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    ButtonStyle btn({required bool selected}) {
      return ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
        backgroundColor: WidgetStatePropertyAll(selected ? FirePumpSimColors.red : FirePumpSimColors.charcoal2),
        foregroundColor: WidgetStatePropertyAll(selected ? Colors.white : FirePumpSimColors.textHigh),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.9)))),
        textStyle: WidgetStatePropertyAll((t.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(fontWeight: FontWeight.w900)),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => onChanged(PrintableScenarioMode.randomSheet),
            style: btn(selected: mode == PrintableScenarioMode.randomSheet),
            child: const Text('Random Sheet'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextButton(
            onPressed: () => onChanged(PrintableScenarioMode.createScenario),
            style: btn(selected: mode == PrintableScenarioMode.createScenario),
            child: const Text('Create Scenario'),
          ),
        ),
      ],
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.titleController, required this.departmentController});

  final TextEditingController titleController;
  final TextEditingController departmentController;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      titleIcon: Icons.badge_outlined,
      title: 'Worksheet Info',
      child: Column(
        children: [
          _DarkTextField(controller: titleController, label: 'Worksheet Title', hint: 'Fire Pump Pressure Practice', textInputAction: TextInputAction.next),
          const SizedBox(height: 10),
          _DarkTextField(controller: departmentController, label: 'Class / Department', hint: 'Driver / Operator Training', textInputAction: TextInputAction.done),
        ],
      ),
    );
  }
}

class _RandomSheetCard extends StatelessWidget {
  const _RandomSheetCard({
    super.key,
    required this.difficulty,
    required this.scenarioCount,
    required this.includeAnswerKey,
    required this.printing,
    required this.onDifficultyChanged,
    required this.onScenarioCountChanged,
    required this.onIncludeAnswerKeyChanged,
    required this.onGenerate,
    required this.onPrint,
  });

  final PrintableWorksheetDifficulty difficulty;
  final int scenarioCount;
  final bool includeAnswerKey;
  final bool printing;
  final ValueChanged<PrintableWorksheetDifficulty> onDifficultyChanged;
  final ValueChanged<int> onScenarioCountChanged;
  final ValueChanged<bool> onIncludeAnswerKeyChanged;
  final VoidCallback onGenerate;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _CardShell(
      titleIcon: Icons.auto_awesome,
      title: 'Random Worksheet',
      subtitle: 'Generate a full sheet instantly. Then switch to “Create Scenario” to edit anything.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DarkDropdown<PrintableWorksheetDifficulty>(
            label: 'Difficulty',
            value: difficulty,
            items: const [
              DropdownMenuItem(value: PrintableWorksheetDifficulty.beginner, child: Text('Beginner')),
              DropdownMenuItem(value: PrintableWorksheetDifficulty.mixedBeginnerIntermediate, child: Text('Mixed beginner/intermediate')),
              DropdownMenuItem(value: PrintableWorksheetDifficulty.advanced, child: Text('Advanced')),
            ],
            onChanged: (v) {
              if (v != null) onDifficultyChanged(v);
            },
          ),
          const SizedBox(height: 10),
          _DarkDropdown<int>(
            label: 'Number of scenarios',
            value: scenarioCount,
            items: const [
              DropdownMenuItem(value: 2, child: Text('2')),
              DropdownMenuItem(value: 4, child: Text('4')),
              DropdownMenuItem(value: 6, child: Text('6')),
              DropdownMenuItem(value: 8, child: Text('8')),
            ],
            onChanged: (v) {
              if (v != null) onScenarioCountChanged(v);
            },
          ),
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            value: includeAnswerKey,
            onChanged: onIncludeAnswerKeyChanged,
            contentPadding: EdgeInsets.zero,
            dense: false,
            activeColor: FirePumpSimColors.red,
            title: Text('Include answer key', style: (t.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800)),
            subtitle: Text('Adds a second page with answers + math', style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, height: 1.35)),
          ),
          const SizedBox(height: 12),
          _PrimaryActionButton(label: 'Generate Random Sheet', icon: Icons.auto_awesome, onTap: onGenerate),
          const SizedBox(height: 10),
          _SecondaryActionButton(label: printing ? 'Preparing PDF…' : 'Print / Save PDF', icon: Icons.picture_as_pdf_outlined, onTap: onPrint),
        ],
      ),
    );
  }
}

class _ScenarioBuilderCard extends StatelessWidget {
  const _ScenarioBuilderCard({
    super.key,
    required this.scenarioCount,
    required this.currentCount,
    required this.selectedIndex,
    required this.titleController,
    required this.scenarioType,
    required this.targetArtwork,
    required this.hoseSize,
    required this.cController,
    required this.customLength,
    required this.lengthFt,
    required this.customLengthController,
    required this.nozzleValue,
    required this.customNozzle,
    required this.customNozzleLabelController,
    required this.customGpmController,
    required this.customNpController,
    required this.elevationController,
    required this.appliancePsi,
    required this.problemController,
    required this.calculatedScenario,
    required this.onScenarioTypeChanged,
    required this.onTargetArtworkChanged,
    required this.onHoseSizeChanged,
    required this.onCValueEdited,
    required this.onLengthChanged,
    required this.onNozzleChanged,
    required this.onAppliancePsiChanged,
    required this.onAddToWorksheet,
    required this.onReplaceSelected,
    required this.onClear,
    required this.onRandomize,
  });

  final int scenarioCount;
  final int currentCount;
  final int? selectedIndex;

  final TextEditingController titleController;
  final PrintableScenarioType scenarioType;
  final PrintableTargetArtwork targetArtwork;
  final PrintableHoseSize hoseSize;
  final TextEditingController cController;
  final bool customLength;
  final int lengthFt;
  final TextEditingController customLengthController;
  final String nozzleValue;
  final bool customNozzle;
  final TextEditingController customNozzleLabelController;
  final TextEditingController customGpmController;
  final TextEditingController customNpController;
  final TextEditingController elevationController;
  final int appliancePsi;
  final TextEditingController problemController;
  final PrintablePumpScenario calculatedScenario;

  final ValueChanged<PrintableScenarioType> onScenarioTypeChanged;
  final ValueChanged<PrintableTargetArtwork> onTargetArtworkChanged;
  final ValueChanged<PrintableHoseSize> onHoseSizeChanged;
  final VoidCallback onCValueEdited;
  final void Function(int lengthFt, bool isCustom) onLengthChanged;
  final void Function(String value, bool isCustom) onNozzleChanged;
  final ValueChanged<int> onAppliancePsiChanged;
  final VoidCallback onAddToWorksheet;
  final VoidCallback onReplaceSelected;
  final VoidCallback onClear;
  final VoidCallback onRandomize;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final selectedLabel = selectedIndex == null ? 'None' : '#${selectedIndex! + 1}';

    return _CardShell(
      titleIcon: Icons.build_outlined,
      title: 'Scenario Builder',
      subtitle: 'Build one scenario, then add it to the worksheet. Selected: $selectedLabel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DarkTextField(controller: titleController, label: 'Scenario title', hint: 'Custom Pump Scenario', textInputAction: TextInputAction.next),
          const SizedBox(height: 10),
          _DarkDropdown<PrintableScenarioType>(
            label: 'Scenario type',
            value: scenarioType,
            items: const [
              DropdownMenuItem(value: PrintableScenarioType.attackLine, child: Text('Attack Line')),
              DropdownMenuItem(value: PrintableScenarioType.vehicleFire, child: Text('Vehicle Fire')),
              DropdownMenuItem(value: PrintableScenarioType.commercialBuilding, child: Text('Commercial Building')),
              DropdownMenuItem(value: PrintableScenarioType.hydrantSupply, child: Text('Hydrant Supply')),
              DropdownMenuItem(value: PrintableScenarioType.brushWildland, child: Text('Brush / Wildland')),
              DropdownMenuItem(value: PrintableScenarioType.standpipeStyleLine, child: Text('Standpipe-style Line')),
            ],
            onChanged: (v) {
              if (v != null) onScenarioTypeChanged(v);
            },
          ),
          const SizedBox(height: 10),
          _DarkDropdown<PrintableTargetArtwork>(
            label: 'Target artwork',
            value: targetArtwork,
            items: const [
              DropdownMenuItem(value: PrintableTargetArtwork.building, child: Text('Building')),
              DropdownMenuItem(value: PrintableTargetArtwork.sedan, child: Text('Sedan / Vehicle')),
              DropdownMenuItem(value: PrintableTargetArtwork.brush, child: Text('Brush')),
              DropdownMenuItem(value: PrintableTargetArtwork.hydrant, child: Text('Hydrant')),
              DropdownMenuItem(value: PrintableTargetArtwork.buildingAndBrush, child: Text('Building + Brush')),
              DropdownMenuItem(value: PrintableTargetArtwork.sedanAndBrush, child: Text('Vehicle + Brush')),
            ],
            onChanged: (v) {
              if (v != null) onTargetArtworkChanged(v);
            },
          ),
          const SizedBox(height: 10),
          _DarkDropdown<PrintableHoseSize>(
            label: 'Hose size',
            value: hoseSize,
            items: const [
              DropdownMenuItem(value: PrintableHoseSize.inch175, child: Text('1¾ inch')),
              DropdownMenuItem(value: PrintableHoseSize.inch25, child: Text('2½ inch')),
              DropdownMenuItem(value: PrintableHoseSize.inch2, child: Text('2 inch')),
              DropdownMenuItem(value: PrintableHoseSize.inch3, child: Text('3 inch')),
              DropdownMenuItem(value: PrintableHoseSize.ldh5, child: Text('5 inch LDH')),
            ],
            onChanged: (v) {
              if (v != null) onHoseSizeChanged(v);
            },
          ),
          const SizedBox(height: 10),
          _DarkTextField(
            controller: cController,
            label: 'C value',
            hint: '15.5',
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
            textInputAction: TextInputAction.next,
            onChanged: (_) => onCValueEdited(),
          ),
          const SizedBox(height: 10),
          _LengthPicker(customLength: customLength, lengthFt: lengthFt, customLengthController: customLengthController, onChanged: onLengthChanged),
          const SizedBox(height: 10),
          _NozzlePicker(
            nozzleValue: nozzleValue,
            customNozzle: customNozzle,
            onChanged: onNozzleChanged,
            customNozzleLabelController: customNozzleLabelController,
            customGpmController: customGpmController,
            customNpController: customNpController,
          ),
          const SizedBox(height: 10),
          _DarkTextField(
            controller: elevationController,
            label: 'Elevation (ft)',
            hint: '-20, 0, 10, 20',
            keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: true),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          _ApplianceLossPicker(value: appliancePsi, onChanged: onAppliancePsiChanged),
          const SizedBox(height: 10),
          _DarkTextArea(controller: problemController, label: 'Student problem text', hint: 'Engine 181 is stretching one attack line…'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: FirePumpSimColors.charcoal3.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined, color: FirePumpSimColors.textHigh, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Calculated PP: ${calculatedScenario.pumpPressureRounded} PSI  •  FL ${calculatedScenario.frictionLoss}  •  Elev/App ${calculatedScenario.elevationPsi + calculatedScenario.appliancePsi}',
                    style: (t.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _PrimaryActionButton(label: 'Add to Worksheet', icon: Icons.playlist_add, onTap: onAddToWorksheet)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _SecondaryActionButton(label: 'Replace Selected Scenario', icon: Icons.swap_horiz, onTap: onReplaceSelected)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _SecondaryActionButton(label: 'Clear Builder', icon: Icons.refresh, onTap: onClear)),
              const SizedBox(width: 10),
              Expanded(child: _SecondaryActionButton(label: 'Randomize This Scenario', icon: Icons.casino_outlined, onTap: onRandomize)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Worksheet slots: $currentCount / $scenarioCount', style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed)),
        ],
      ),
    );
  }
}

class _WorksheetListCard extends StatelessWidget {
  const _WorksheetListCard({
    required this.textTheme,
    required this.scenarios,
    required this.selectedIndex,
    required this.scenarioCountLimit,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final TextTheme textTheme;
  final List<PrintablePumpScenario> scenarios;
  final int? selectedIndex;
  final int scenarioCountLimit;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDuplicate;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onMoveUp;
  final ValueChanged<int> onMoveDown;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      titleIcon: Icons.view_list_outlined,
      title: 'Worksheet Scenarios',
      subtitle: 'Edit, duplicate, delete, or reorder. Limit: $scenarioCountLimit',
      child: Column(
        children: [
          if (scenarios.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('No scenarios yet. Add one from the builder above.', style: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: FirePumpSimColors.textMed)),
            ),
          for (var i = 0; i < scenarios.length; i++) ...[
            if (i != 0) const SizedBox(height: 10),
            _ScenarioListItem(
              index: i,
              scenario: scenarios[i],
              selected: selectedIndex == i,
              onEdit: () => onEdit(i),
              onDuplicate: () => onDuplicate(i),
              onDelete: () => onDelete(i),
              onMoveUp: () => onMoveUp(i),
              onMoveDown: () => onMoveDown(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScenarioListItem extends StatelessWidget {
  const _ScenarioListItem({
    required this.index,
    required this.scenario,
    required this.selected,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final PrintablePumpScenario scenario;
  final bool selected;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal3.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? FirePumpSimColors.red : FirePumpSimColors.steel.withValues(alpha: 0.9), width: selected ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('${index + 1}. ${scenario.title}', style: (t.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900))),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: FirePumpSimColors.charcoal2, borderRadius: BorderRadius.circular(999), border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.9))),
                child: Text('${scenario.pumpPressureRounded} PSI', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ScenarioFactsLine(label: 'Type', value: _typeLabel(scenario.scenarioType)),
          _ScenarioFactsLine(label: 'Hose', value: '${scenario.hoseDiameterLabel} • ${scenario.lengthFt} ft  (C ${_fmtC(scenario.cValue)})'),
          _ScenarioFactsLine(label: 'Nozzle', value: scenario.nozzleLabel),
          _ScenarioFactsLine(label: 'Elevation', value: '${scenario.elevationFeet} ft (${scenario.elevationPsi} PSI)  •  Appliance ${scenario.appliancePsi} PSI'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniActionButton(icon: Icons.edit_outlined, label: 'Edit', onTap: onEdit),
              _MiniActionButton(icon: Icons.copy_outlined, label: 'Duplicate', onTap: onDuplicate),
              _MiniActionButton(icon: Icons.delete_outline, label: 'Delete', onTap: onDelete, danger: true),
              _MiniActionButton(icon: Icons.arrow_upward, label: 'Up', onTap: onMoveUp),
              _MiniActionButton(icon: Icons.arrow_downward, label: 'Down', onTap: onMoveDown),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScenarioFactsLine extends StatelessWidget {
  const _ScenarioFactsLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(child: Text(value, style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textHigh, height: 1.35))),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.worksheetTitle,
    required this.department,
    required this.scenarios,
    required this.includeAnswerKey,
    required this.previewMode,
    required this.printing,
    required this.onPreviewWorksheet,
    required this.onPreviewAnswerKey,
    required this.onPrint,
  });

  final String worksheetTitle;
  final String department;
  final List<PrintablePumpScenario> scenarios;
  final bool includeAnswerKey;
  final _PreviewMode previewMode;
  final bool printing;
  final VoidCallback onPreviewWorksheet;
  final VoidCallback? onPreviewAnswerKey;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _CardShell(
      titleIcon: Icons.preview_outlined,
      title: 'Preview',
      subtitle: 'Phone-friendly preview of what will print on letter paper.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SecondaryActionButton(
                  label: 'Preview Worksheet',
                  icon: Icons.description_outlined,
                  onTap: onPreviewWorksheet,
                  tight: true,
                  selected: previewMode == _PreviewMode.worksheet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SecondaryActionButton(
                  label: 'Preview Answer Key',
                  icon: Icons.checklist,
                  onTap: onPreviewAnswerKey,
                  tight: true,
                  selected: previewMode == _PreviewMode.answerKey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SecondaryActionButton(label: printing ? 'Preparing PDF…' : 'Print / Save PDF', icon: Icons.picture_as_pdf_outlined, onTap: onPrint),
          const SizedBox(height: 12),
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
                    style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: Colors.black, height: 1.25),
                    child: previewMode == _PreviewMode.worksheet
                        ? _WorksheetPagePreview(worksheetTitle: worksheetTitle, department: department, scenarios: scenarios)
                        : _AnswerKeyPagePreview(worksheetTitle: worksheetTitle, department: department, scenarios: scenarios),
                  ),
                ),
              ),
            ),
          ),
          if (includeAnswerKey) ...[
            const SizedBox(height: 12),
            Text('Answer key prints as page 2.', style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, height: 1.35)),
          ],
        ],
      ),
    );
  }
}

class _WorksheetPagePreview extends StatelessWidget {
  const _WorksheetPagePreview({required this.worksheetTitle, required this.department, required this.scenarios});
  final String worksheetTitle;
  final String department;
  final List<PrintablePumpScenario> scenarios;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PreviewHeader(title: worksheetTitle, department: department),
        const SizedBox(height: 10),
        for (var i = 0; i < scenarios.length; i++) ...[
          _PreviewScenarioRow(index: i + 1, scenario: scenarios[i]),
          if (i != scenarios.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        const _PreviewFooter(),
      ],
    );
  }
}

class _AnswerKeyPagePreview extends StatelessWidget {
  const _AnswerKeyPagePreview({required this.worksheetTitle, required this.department, required this.scenarios});
  final String worksheetTitle;
  final String department;
  final List<PrintablePumpScenario> scenarios;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Answer Key', style: (t.titleMedium ?? const TextStyle(fontSize: 16)).copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text('$worksheetTitle • $department', style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: Colors.black87)),
        const SizedBox(height: 10),
        Table(
          border: TableBorder.all(color: Colors.black, width: 0.7),
          columnWidths: const {0: FixedColumnWidth(54), 1: FixedColumnWidth(54), 2: FixedColumnWidth(72)},
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06)),
              children: [
                _akCell(context, 'Scenario', bold: true),
                _akCell(context, 'FL', bold: true),
                _akCell(context, 'Elev/App', bold: true),
                _akCell(context, 'PP', bold: true),
              ],
            ),
            for (var i = 0; i < scenarios.length; i++)
              TableRow(
                children: [
                  _akCell(context, '${i + 1}'),
                  _akCell(context, '${scenarios[i].frictionLoss}'),
                  _akCell(context, '${scenarios[i].elevationPsi + scenarios[i].appliancePsi}'),
                  _akCell(context, '${scenarios[i].pumpPressureRounded}', bold: true),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Math explanation (per scenario):', style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (var i = 0; i < scenarios.length; i++) ...[
          Text('Scenario ${i + 1}:', style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(scenarios[i].mathExplanation, style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: Colors.black87, height: 1.25)),
          if (i != scenarios.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        const _PreviewFooter(),
      ],
    );
  }

  Widget _akCell(BuildContext context, String text, {bool bold = false}) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(text, style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
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
  const _PreviewScenarioRow({required this.index, required this.scenario});
  final int index;
  final PrintablePumpScenario scenario;

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
              Text(_typeLabel(scenario.scenarioType), style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87)),
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
                  child: PrintableSceneWidget(
                    targetArtwork: scenario.targetArtwork,
                    hoseLabel: '${scenario.hoseDiameterLabel} • ${scenario.lengthFt} ft',
                    flowLabel: '${scenario.gpm} GPM',
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
      (k: 'C', v: _fmtC(scenario.cValue)),
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
              Padding(padding: const EdgeInsets.all(3), child: Text(r.k, style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(fontWeight: FontWeight.w900, color: Colors.black))),
              Padding(padding: const EdgeInsets.all(3), child: Text(r.v, style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87))),
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

class _CardShell extends StatelessWidget {
  const _CardShell({required this.titleIcon, required this.title, this.subtitle, required this.child});
  final IconData titleIcon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
                Icon(titleIcon, color: FirePumpSimColors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: (t.titleMedium ?? const TextStyle(fontSize: 16)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900))),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, height: 1.35)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.textInputAction,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: (textTheme.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: FirePumpSimColors.charcoal3.withValues(alpha: 0.6),
        labelStyle: (textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w700),
        hintStyle: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: FirePumpSimColors.textMed.withValues(alpha: 0.6)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.9))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: FirePumpSimColors.red, width: 1.2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _DarkTextArea extends StatelessWidget {
  const _DarkTextArea({required this.controller, required this.label, required this.hint});
  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      maxLines: 4,
      minLines: 3,
      textInputAction: TextInputAction.newline,
      style: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w700, height: 1.35),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: FirePumpSimColors.charcoal3.withValues(alpha: 0.6),
        labelStyle: (textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w700),
        hintStyle: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: FirePumpSimColors.textMed.withValues(alpha: 0.6)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.9))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: FirePumpSimColors.red, width: 1.2)),
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
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.9))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: FirePumpSimColors.red, width: 1.2)),
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
          decoration: BoxDecoration(color: FirePumpSimColors.red, borderRadius: BorderRadius.circular(18)),
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
  const _SecondaryActionButton({required this.label, required this.icon, required this.onTap, this.tight = false, this.selected = false});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool tight;
  final bool selected;

  @override
  State<_SecondaryActionButton> createState() => _SecondaryActionButtonState();
}

class _SecondaryActionButtonState extends State<_SecondaryActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final textTheme = Theme.of(context).textTheme;
    final bg = widget.selected ? FirePumpSimColors.charcoal3.withValues(alpha: 0.85) : FirePumpSimColors.charcoal3.withValues(alpha: 0.5);
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
            height: widget.tight ? 48 : 54,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: widget.selected ? FirePumpSimColors.red : FirePumpSimColors.steel.withValues(alpha: 0.95)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: FirePumpSimColors.textHigh, size: 20),
                const SizedBox(width: 10),
                Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis, style: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({required this.icon, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: FirePumpSimColors.charcoal2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: (danger ? FirePumpSimColors.red : FirePumpSimColors.steel).withValues(alpha: 0.9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: danger ? FirePumpSimColors.red : FirePumpSimColors.textHigh, size: 18),
            const SizedBox(width: 8),
            Text(label, style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _LengthPicker extends StatelessWidget {
  const _LengthPicker({required this.customLength, required this.lengthFt, required this.customLengthController, required this.onChanged});
  final bool customLength;
  final int lengthFt;
  final TextEditingController customLengthController;
  final void Function(int lengthFt, bool isCustom) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DarkDropdown<int>(
          label: 'Hose length (ft)',
          value: customLength ? -1 : lengthFt,
          items: const [
            DropdownMenuItem(value: 100, child: Text('100')),
            DropdownMenuItem(value: 150, child: Text('150')),
            DropdownMenuItem(value: 200, child: Text('200')),
            DropdownMenuItem(value: 250, child: Text('250')),
            DropdownMenuItem(value: 300, child: Text('300')),
            DropdownMenuItem(value: -1, child: Text('Custom')),
          ],
          onChanged: (v) {
            if (v == null) return;
            if (v == -1) {
              onChanged(lengthFt, true);
            } else {
              onChanged(v, false);
            }
          },
        ),
        if (customLength) ...[
          const SizedBox(height: 10),
          _DarkTextField(
            controller: customLengthController,
            label: 'Custom length (ft)',
            hint: '350',
            keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
            textInputAction: TextInputAction.next,
          ),
        ],
      ],
    );
  }
}

class _NozzlePicker extends StatelessWidget {
  const _NozzlePicker({
    required this.nozzleValue,
    required this.customNozzle,
    required this.onChanged,
    required this.customNozzleLabelController,
    required this.customGpmController,
    required this.customNpController,
  });

  final String nozzleValue;
  final bool customNozzle;
  final void Function(String value, bool isCustom) onChanged;
  final TextEditingController customNozzleLabelController;
  final TextEditingController customGpmController;
  final TextEditingController customNpController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DarkDropdown<String>(
          label: 'Nozzle',
          value: customNozzle ? '__custom__' : nozzleValue,
          items: [
            for (final n in _nozzleOptions) DropdownMenuItem(value: n.label, child: Text(n.label)),
            const DropdownMenuItem(value: '__custom__', child: Text('Custom Nozzle')),
          ],
          onChanged: (v) {
            if (v == null) return;
            onChanged(v == '__custom__' ? nozzleValue : v, v == '__custom__');
          },
        ),
        if (customNozzle) ...[
          const SizedBox(height: 10),
          _DarkTextField(controller: customNozzleLabelController, label: 'Nozzle label', hint: 'Custom Nozzle', textInputAction: TextInputAction.next),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DarkTextField(
                  controller: customGpmController,
                  label: 'GPM',
                  hint: '185',
                  keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DarkTextField(
                  controller: customNpController,
                  label: 'Nozzle pressure',
                  hint: '50',
                  keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ApplianceLossPicker extends StatelessWidget {
  const _ApplianceLossPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Appliance loss (PSI)', style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final v in const [0, 10, 15, 25])
              _MiniActionButton(
                icon: Icons.tune,
                label: v == value ? '$v (selected)' : '$v',
                onTap: () => onChanged(v),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: value.toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
          onChanged: (s) {
            final v = int.tryParse(s.trim());
            if (v != null) onChanged(max(0, v));
          },
          style: (t.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: 'Appliance loss (manual)',
            hintText: '0',
            filled: true,
            fillColor: FirePumpSimColors.charcoal3.withValues(alpha: 0.6),
            labelStyle: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, fontWeight: FontWeight.w700),
            hintStyle: (t.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: FirePumpSimColors.textMed.withValues(alpha: 0.6)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: FirePumpSimColors.steel.withValues(alpha: 0.9))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: FirePumpSimColors.red, width: 1.2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// -----------------
// Domain helpers
// -----------------

const _nozzleOptions = <({String label, int gpm, int np})>[
  (label: 'Chief XD Fog — 185 GPM @ 50 PSI', gpm: 185, np: 50),
  (label: 'Fog Nozzle — 150 GPM @ 50 PSI', gpm: 150, np: 50),
  (label: 'Fog Nozzle — 250 GPM @ 50 PSI', gpm: 250, np: 50),
  (label: 'Smooth Bore 15/16 — 185 GPM @ 50 PSI', gpm: 185, np: 50),
  (label: 'Smooth Bore 1 1/8 — 265 GPM @ 50 PSI', gpm: 265, np: 50),
];

String _fmtC(double c) => c == c.roundToDouble() ? c.toStringAsFixed(0) : c.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');

String _typeLabel(PrintableScenarioType type) {
  return switch (type) {
    PrintableScenarioType.attackLine => 'Attack Line',
    PrintableScenarioType.vehicleFire => 'Vehicle Fire',
    PrintableScenarioType.commercialBuilding => 'Commercial',
    PrintableScenarioType.hydrantSupply => 'Hydrant',
    PrintableScenarioType.brushWildland => 'Brush',
    PrintableScenarioType.standpipeStyleLine => 'Standpipe',
  };
}

PrintableTargetArtwork _defaultArtworkForScenarioType(PrintableScenarioType type) {
  return switch (type) {
    PrintableScenarioType.vehicleFire => PrintableTargetArtwork.sedan,
    PrintableScenarioType.commercialBuilding => PrintableTargetArtwork.building,
    PrintableScenarioType.hydrantSupply => PrintableTargetArtwork.hydrant,
    PrintableScenarioType.brushWildland => PrintableTargetArtwork.brush,
    PrintableScenarioType.attackLine => PrintableTargetArtwork.building,
    PrintableScenarioType.standpipeStyleLine => PrintableTargetArtwork.building,
  };
}

String _defaultProblemFor(PrintableScenarioType type) {
  return switch (type) {
    PrintableScenarioType.attackLine => 'Engine 181 is stretching one attack line to a fire. Calculate the pump discharge pressure.',
    PrintableScenarioType.vehicleFire => 'Engine 181 is stretching one attack line to a vehicle fire. Calculate the pump discharge pressure.',
    PrintableScenarioType.commercialBuilding => 'Engine 181 is stretching one attack line to a commercial building fire. Calculate the pump discharge pressure.',
    PrintableScenarioType.hydrantSupply => 'Engine 181 is laying a supply line from a hydrant. Calculate the pump discharge pressure.',
    PrintableScenarioType.brushWildland => 'Engine 181 is stretching one line for a brush fire. Calculate the pump discharge pressure.',
    PrintableScenarioType.standpipeStyleLine => 'Engine 181 is supplying a standpipe-style line. Calculate the pump discharge pressure.',
  };
}
