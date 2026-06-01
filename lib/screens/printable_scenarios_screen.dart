import 'dart:math';
import 'dart:typed_data';

import 'package:firepumpsim/models/printable_pack.dart';
import 'package:firepumpsim/models/printable_pump_scenario.dart';
import 'package:firepumpsim/nav.dart';
import 'package:firepumpsim/services/printable_pack_storage.dart';
import 'package:firepumpsim/theme.dart';
import 'package:firepumpsim/utils/pdf_download.dart';
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
  static const starterScenario001 = 'assets/printable/FirePumpSim_printable_scenario_001.png';
  static const starterScenario002 = 'assets/printable/FirePumpSim_printable_scenario_002.png';

  static const brandedStarterPages = <_BrandedPrintablePage>[
    _BrandedPrintablePage(
      title: 'Page 1 — FirePumpSim printable scenario 001',
      assetPath: starterScenario001,
      fileName: 'FirePumpSim_printable_scenario_001.pdf',
    ),
    _BrandedPrintablePage(
      title: 'Page 2 — Master Stream Operations',
      assetPath: starterScenario002,
      fileName: 'FirePumpSim_printable_scenario_002.pdf',
    ),
  ];

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

class _BrandedPrintablePage {
  const _BrandedPrintablePage({
    required this.title,
    required this.assetPath,
    required this.fileName,
  });

  final String title;
  final String assetPath;
  final String fileName;
}

class PrintableScenariosScreen extends StatefulWidget {
  const PrintableScenariosScreen({super.key});

  @override
  State<PrintableScenariosScreen> createState() => _PrintableScenariosScreenState();
}

enum _PreviewMode { worksheet, answerKey }

class _PrintableScenariosScreenState extends State<PrintableScenariosScreen> {
  _PreviewMode _previewMode = _PreviewMode.worksheet;

  final _packStorage = PrintablePackStorage();
  final List<PrintablePack> _allPacks = PrintablePacksCatalog.allPacks();

  bool _loading = true;
  Set<String> _purchasedPrintablePackIds = <String>{};

  late PrintablePack _selectedPack;
  late List<PrintablePumpScenario> _scenarios;
  bool _includeAnswerKey = true;
  bool _printing = false;

  static const String _brandBannerAsset = 'assets/images/firepumpsim_brand_banner.jpg';

  /// PDF rendering uses built-in Helvetica by default which does not support some
  /// Unicode punctuation (e.g. bullet "•" and em-dash "—").
  ///
  /// We sanitize text so PDF generation never fails due to missing glyphs.
  String _pdfSafeText(String input) {
    return input
        .replaceAll('•', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('→', '->')
        .replaceAll('±', '+/-')
        .replaceAll('×', 'x')
        .replaceAll('²', '^2')
        .replaceAll('³', '^3')
        .replaceAll('¼', '1/4')
        .replaceAll('½', '1/2')
        .replaceAll('¾', '3/4')
        .replaceAll('⅛', '1/8')
        .replaceAll('⅞', '7/8')
        .replaceAll('′', "'")
        .replaceAll('″', '"')
        .replaceAll('’', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"');
  }

  String _pdfHoseLabel(PrintablePumpScenario scenario) => _pdfSafeText('${scenario.hoseDiameterLabel} - ${scenario.lengthFt} ft');

  Future<void> _outputPdf({
    required Uint8List bytes,
    required String filename,
    required String title,
  }) async {
    // Web output is handled by a pre-opened download session started from the
    // button tap, to avoid popup/download blockers.
    if (kIsWeb) {
      await downloadPdfBytes(bytes: bytes, filename: filename);
      _toast('PDF downloaded. Open it to print or save.');
      return;
    }

    // sharePdf is more reliable in iOS/Android builds than only opening the
    // platform print dialog. It lets the user Save to Files, AirDrop, email,
    // or choose Print from the native share sheet.
    try {
      await pr.Printing.sharePdf(bytes: bytes, filename: filename);
      return;
    } catch (e, st) {
      debugPrint('PDF share failed, falling back to print dialog: $e\n$st');
    }

    await pr.Printing.layoutPdf(
      name: title,
      onLayout: (_) async => bytes,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedPack = _allPacks.firstWhere(
      (p) => p.packId == PrintablePacksCatalog.starterPackId,
      orElse: () => _allPacks.first,
    );
    _scenarios = _selectedPack.buildPages();
    _loadPurchases();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPurchases() async {
    setState(() => _loading = true);
    try {
      final ids = await _packStorage.loadPurchasedPackIds();
      if (!mounted) return;
      setState(() => _purchasedPrintablePackIds = ids);
    } catch (e) {
      debugPrint('Printable pack purchase load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isUnlocked(PrintablePack p) => p.isFree || _purchasedPrintablePackIds.contains(p.packId);

  void _selectPack(PrintablePack p) {
    if (!_isUnlocked(p)) {
      _toast('This printable pack is coming soon.');
      return;
    }
    setState(() {
      _selectedPack = p;
      _scenarios = p.buildPages();
      _previewMode = _PreviewMode.worksheet;
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
                subtitle: 'Only the 2 free printable starter sheets are shown in this build.',
                onBack: () => context.go(AppRoutes.home),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: _StarterPrintablePageCard(
                  printing: _printing,
                  pages: PrintableScenarioAssetPack.brandedStarterPages,
                  onPrintPage: _printing ? null : _handlePrintBrandedPage,
                  onPrintPack: _printing ? null : _handlePrintBrandedStarterPack,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: _CardShell(
                  titleIcon: Icons.info_outline,
                  title: 'Included in this build',
                  subtitle: 'The printable screen now only shows the top 2 free starter sheets.',
                  child: Text(
                    'Use the two starter page buttons above to preview, print, or save the free sheets. The larger printable pack list and bottom worksheet previews have been removed from this Android build.',
                    style: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
                      color: FirePumpSimColors.textMed,
                      height: 1.4,
                    ),
                  ),
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
    PdfDownloadSession? webSession;
    try {
      if (kIsWeb) webSession = startPdfDownload(filename: 'FirePumpSim_Worksheet.pdf');
      final bytes = await _buildPdfBytes(
        worksheetTitle: _selectedPack.title,
        department: 'FirePumpSim Training',
        scenarios: _scenarios,
        includeAnswerKey: _includeAnswerKey,
      );
      debugPrint('Printable PDF built: ${bytes.lengthInBytes} bytes. Launching output…');
      if (kIsWeb && webSession != null) {
        await webSession.complete(bytes);
        _toast('PDF opened in a new tab. Use the browser print button.');
      } else {
        await _outputPdf(
          bytes: bytes,
          filename: 'FirePumpSim_Worksheet.pdf',
          title: 'FirePumpSim Worksheet',
        );
      }
    } catch (e, st) {
      debugPrint('Print/Save PDF failed: $e\n$st');
      try {
        await webSession?.abort(e);
      } catch (_) {}
      _toast('Unable to print / save PDF on this device. If you are on web, make sure pop-ups are allowed.');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _handlePrintBrandedPage(_BrandedPrintablePage page) async {
    setState(() => _printing = true);
    PdfDownloadSession? webSession;
    try {
      if (kIsWeb) webSession = startPdfDownload(filename: page.fileName);
      final bytes = await _buildBrandedPrintablePdf([page]);
      debugPrint('Branded printable page PDF built: ${bytes.lengthInBytes} bytes. Launching output…');
      if (kIsWeb && webSession != null) {
        await webSession.complete(bytes);
        _toast('PDF opened in a new tab. Use the browser print button.');
      } else {
        await _outputPdf(
          bytes: bytes,
          filename: page.fileName,
          title: page.title,
        );
      }
    } catch (e, st) {
      debugPrint('Branded printable page failed (${page.assetPath}): $e\n$st');
      try {
        await webSession?.abort(e);
      } catch (_) {}
      _toast('Unable to print ${page.title}. Check that ${page.assetPath} exists and is listed in pubspec.yaml.');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _handlePrintBrandedStarterPack() async {
    setState(() => _printing = true);
    PdfDownloadSession? webSession;
    try {
      if (kIsWeb) webSession = startPdfDownload(filename: 'FirePumpSim_Printable_Starter_Pack.pdf');
      final pages = <_BrandedPrintablePage>[];
      for (final page in PrintableScenarioAssetPack.brandedStarterPages) {
        try {
          await rootBundle.load(page.assetPath);
          pages.add(page);
        } catch (_) {
          debugPrint('Skipping missing branded printable page: ${page.assetPath}');
        }
      }
      if (pages.isEmpty) {
        _toast('No branded printable pages were found in assets/printable/.');
        return;
      }

      final bytes = await _buildBrandedPrintablePdf(pages);
      debugPrint('Branded printable pack PDF built: ${bytes.lengthInBytes} bytes. Launching output…');
      if (kIsWeb && webSession != null) {
        await webSession.complete(bytes);
        _toast('PDF opened in a new tab. Use the browser print button.');
      } else {
        await _outputPdf(
          bytes: bytes,
          filename: 'FirePumpSim_Printable_Starter_Pack.pdf',
          title: 'FirePumpSim Printable Starter Pack',
        );
      }
    } catch (e, st) {
      debugPrint('Branded starter pack print failed: $e\n$st');
      try {
        await webSession?.abort(e);
      } catch (_) {}
      _toast('Unable to print branded starter pack. Check printable image assets and device print/share support.');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<Uint8List> _buildBrandedPrintablePdf(List<_BrandedPrintablePage> pages) async {
    final doc = pw.Document();

    for (final page in pages) {
      final imageData = await rootBundle.load(page.assetPath);
      final image = pw.MemoryImage(imageData.buffer.asUint8List());
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    return doc.save();
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

    final safeWorksheetTitle = _pdfSafeText(worksheetTitle);
    final safeDepartment = _pdfSafeText(department);

    // Worksheet pages: 1 scenario per page.
    // This allows the scene artwork to become the main visual focus (roughly ~50% of page height)
    // while keeping the student question + work area readable.
    for (var i = 0; i < scenarios.length; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 26),
          build: (context) => _pdfScenarioPage(
            index: i + 1,
            total: scenarios.length,
            worksheetTitle: safeWorksheetTitle,
            department: safeDepartment,
            scenario: scenarios[i],
            t: t,
            assets: pdfAssets,
            brandBanner: pdfAssets[_brandBannerAsset],
          ),
        ),
      );
    }

    if (includeAnswerKey) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 26),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  children: [
                    if (pdfAssets[_brandBannerAsset] != null) pw.SizedBox(height: 24, child: pw.Image(pdfAssets[_brandBannerAsset]!)),
                    if (pdfAssets[_brandBannerAsset] != null) pw.SizedBox(width: 10),
                    pw.Text('Answer Key', style: t(18, bold: true)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text('${safeWorksheetTitle} - ${safeDepartment}', style: t(10)),
                pw.SizedBox(height: 12),
                _pdfAnswerKeyTable(scenarios: scenarios, t: t),
                pw.SizedBox(height: 14),
                pw.Text('Math', style: t(12, bold: true)),
                pw.SizedBox(height: 6),
                for (var i = 0; i < scenarios.length; i++) ...[
                  pw.Text('Scenario ${i + 1}:', style: t(10, bold: true)),
                  pw.SizedBox(height: 2),
                  pw.Text(_pdfSafeText(scenarios[i].mathExplanation), style: t(9)),
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
      _brandBannerAsset: await load(_brandBannerAsset),
      PrintableScenarioAssetPack.truck: await load(PrintableScenarioAssetPack.truck),
      PrintableScenarioAssetPack.building: await load(PrintableScenarioAssetPack.building),
      PrintableScenarioAssetPack.sedan: await load(PrintableScenarioAssetPack.sedan),
      PrintableScenarioAssetPack.hydrant: await load(PrintableScenarioAssetPack.hydrant),
      PrintableScenarioAssetPack.bush: await load(PrintableScenarioAssetPack.bush),
    };

    return {for (final e in entries.entries) if (e.value != null) e.key: e.value!};
  }

  pw.Widget _pdfHeader({
    required String worksheetTitle,
    required String department,
    required pw.TextStyle Function(double, {bool bold}) t,
    required pw.ImageProvider? brandBanner,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (brandBanner != null) ...[
                pw.SizedBox(height: 22, child: pw.Image(brandBanner, fit: pw.BoxFit.contain)),
                pw.SizedBox(width: 10),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text(_pdfSafeText(worksheetTitle), style: t(14, bold: true))),
                        pw.SizedBox(width: 8),
                        pw.Text(_pdfSafeText(department), style: t(11, bold: true)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text('Name: ___________________________', style: t(9))),
                        pw.SizedBox(width: 10),
                        pw.Text('Date: __________', style: t(9)),
                        pw.SizedBox(width: 10),
                        pw.Text('Score: ______ / ______', style: t(9)),
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
    if (targets.isEmpty) return const <pw.Widget>[];
    if (targets.length == 1) {
      return [pw.Positioned(right: 4, top: 4, child: pw.SizedBox(width: 52, height: 36, child: pw.Image(targets.first, fit: pw.BoxFit.contain)))];
    }
    return [
      pw.Positioned(right: 4, top: 4, child: pw.SizedBox(width: 52, height: 34, child: pw.Image(targets[0], fit: pw.BoxFit.contain))),
      pw.Positioned(right: 18, bottom: 6, child: pw.SizedBox(width: 30, height: 22, child: pw.Image(targets[1], fit: pw.BoxFit.contain))),
    ];
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
              pw.Expanded(child: pw.Text(_pdfSafeText('$index. ${scenario.title}'), style: t(11, bold: true))),
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
                            targetArtwork: scenario.targetArtwork,
                            hoseLabel: _pdfHoseLabel(scenario),
                            flowLabel: '${scenario.gpm} GPM',
                          ),
                        ),
                      ),
                      pw.Positioned(left: 4, top: 2, child: pw.Text(_pdfHoseLabel(scenario), style: t(6, bold: true))),
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
                    pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text(_pdfSafeText(scenario.title), style: t(13, bold: true))),
                        pw.SizedBox(width: 8),
                        pw.Text(_typeLabel(scenario.scenarioType), style: t(10, bold: true)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text('Name: ___________________________', style: t(9))),
                        pw.SizedBox(width: 10),
                        pw.Text('Date: __________', style: t(9)),
                        pw.SizedBox(width: 10),
                        pw.Text('Score: ______ / ______', style: t(9)),
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

  pw.Widget _pdfScenarioPage({
    required int index,
    required int total,
    required String worksheetTitle,
    required String department,
    required PrintablePumpScenario scenario,
    required pw.TextStyle Function(double, {bool bold}) t,
    required Map<String, pw.ImageProvider> assets,
    required pw.ImageProvider? brandBanner,
  }) {
    final truck = assets[PrintableScenarioAssetPack.truck];
    final targets = PrintableScenarioAssetPack.targetAssetsFor(scenario.targetArtwork).map((p) => assets[p]).whereType<pw.ImageProvider>().toList(growable: false);

    const sceneHeight = 335.0; // ~45-55% of printable content height on letter with margins.

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _pdfHeader(worksheetTitle: worksheetTitle, department: department, t: t, brandBanner: brandBanner),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(child: pw.Text(_pdfSafeText('$index. ${scenario.title}'), style: t(14, bold: true))),
            pw.Text(_typeLabel(scenario.scenarioType), style: t(10, bold: true)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          height: sceneHeight,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.1)),
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
              if (truck != null) ...[
                pw.Positioned(
                  left: 14,
                  bottom: 14,
                  child: pw.SizedBox(width: 170, height: 110, child: pw.Image(truck, fit: pw.BoxFit.contain)),
                ),
              ],
              if (targets.isNotEmpty) ..._pdfTargetPositionsLarge(targets),
              pw.Positioned.fill(
                child: pw.CustomPaint(
                  painter: (PdfGraphics canvas, PdfPoint size) => _pdfPaintScene(
                    canvas,
                    size,
                    targetArtwork: scenario.targetArtwork,
                    hoseLabel: _pdfHoseLabel(scenario),
                    flowLabel: '${scenario.gpm} GPM',
                  ),
                ),
              ),
              pw.Positioned(left: 10, top: 8, child: pw.Text(_pdfHoseLabel(scenario), style: t(10, bold: true))),
              pw.Positioned(right: 10, top: 8, child: pw.Text('${scenario.gpm} GPM', style: t(10, bold: true))),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _pdfBox(
                title: 'Given / Reference',
                t: t,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(_pdfSafeText(scenario.problem), style: t(9)),
                    pw.SizedBox(height: 6),
                    _pdfFactsGrid(scenario: scenario, t: t),
                    pw.SizedBox(height: 6),
                    pw.Text('PP = NP + FL +/- Elev + App', style: t(9, bold: true)),
                    pw.Text('FL = C x (GPM/100)^2 x L/100', style: t(8)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: _pdfBox(
                title: 'Questions',
                t: t,
                child: _pdfQuestions(t: t, scenario: scenario),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        _pdfBox(
          title: 'Show Your Work',
          t: t,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('Final PDP (PP) = ________ PSI (round to nearest 5 PSI)', style: t(10, bold: true)),
              pw.SizedBox(height: 6),
              _pdfWorkArea(),
            ],
          ),
        ),
        pw.Spacer(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _pdfFooter(t),
            pw.Text('Page $index / $total', style: t(8)),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfBox({required String title, required pw.TextStyle Function(double, {bool bold}) t, required pw.Widget child}) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(title.toUpperCase(), style: t(9, bold: true)),
          pw.SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  pw.Widget _pdfQuestions({required pw.TextStyle Function(double, {bool bold}) t, required PrintablePumpScenario scenario}) {
    pw.Widget q(String label) {
      return pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(child: pw.Text(_pdfSafeText(label), style: t(9))),
            pw.SizedBox(width: 8),
            pw.Container(width: 120, height: 12, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.9)))),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        q('1) Nozzle pressure (NP):'),
        q('2) Friction loss (FL):'),
        q('3) Elevation PSI (+/-):'),
        q('4) Appliance loss (App):'),
        q('5) Pump pressure (raw):'),
        q('6) Pump pressure (rounded):'),
        q('7) Hose diameter & length:'),
      ],
    );
  }

  pw.Widget _pdfWorkArea() {
    // Light write-in area with several horizontal lines.
    return pw.Container(
      height: 135,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
      child: pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.CustomPaint(
              painter: (canvas, size) {
                final h = size.y;
                final w = size.x;
                canvas
                  ..setColor(PdfColors.grey300)
                  ..setLineWidth(0.7);
                const top = 14.0;
                const gap = 16.0;
                for (var y = top; y < h - 6; y += gap) {
                  canvas
                    ..moveTo(8, y)
                    ..lineTo(w - 8, y)
                    ..strokePath();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfWorkLines({required pw.TextStyle Function(double, {bool bold}) t}) {
    pw.Widget line(String label) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          children: [
            pw.SizedBox(width: 90, child: pw.Text('$label:', style: t(11, bold: true))),
            pw.Expanded(child: pw.Container(height: 14, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.9))))),
          ],
        ),
      );
    }

    return pw.Column(
      children: [
        line('NP'),
        line('FL'),
        line('Elevation'),
        line('Appliance'),
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 90, child: pw.Text('Final PP:', style: t(12, bold: true))),
              pw.Expanded(child: pw.Container(height: 16, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.2))))),
            ],
          ),
        ),
      ],
    );
  }

  List<pw.Widget> _pdfTargetPositionsLarge(List<pw.ImageProvider> targets) {
    if (targets.length == 1) {
      return [
        pw.Positioned(
          right: 18,
          top: 22,
          child: pw.SizedBox(width: 190, height: 150, child: pw.Image(targets.first, fit: pw.BoxFit.contain)),
        ),
      ];
    }
    return [
      pw.Positioned(right: 18, top: 22, child: pw.SizedBox(width: 190, height: 150, child: pw.Image(targets[0], fit: pw.BoxFit.contain))),
      pw.Positioned(right: 40, bottom: 26, child: pw.SizedBox(width: 92, height: 92, child: pw.Image(targets[1], fit: pw.BoxFit.contain))),
    ];
  }

  pw.Widget _pdfFactsGrid({required PrintablePumpScenario scenario, required pw.TextStyle Function(double, {bool bold}) t}) {
    final items = <List<String>>[
      ['Hose', _pdfHoseLabel(scenario)],
      ['C', _fmtC(scenario.cValue)],
      ['Nozzle', _pdfSafeText(scenario.nozzleLabel)],
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
              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_pdfSafeText(row[0]), style: t(8, bold: true))),
              pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_pdfSafeText(row[1]), style: t(8))),
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
    return pw.Container(color: fill, padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.Text(_pdfSafeText(text), style: style));
  }

  pw.Widget _pdfFooter(pw.TextStyle Function(double, {bool bold}) t) {
    return pw.Text('Training worksheet only. Follow local SOPs, instructor direction, and department hydraulic guidelines.', style: t(8));
  }

  void _pdfPaintScene(
    PdfGraphics canvas,
    PdfPoint size, {
    required PrintableTargetArtwork targetArtwork,
    required String hoseLabel,
    required String flowLabel,
  }) {
    final w = size.x;
    final h = size.y;

    final outline = PdfColor.fromInt(0xFF1A1A1A);
    final hose = PdfColor.fromInt(0xFFEDEDED);
    final shadow = PdfColor.fromInt(0x66000000);

    final layout = _PdfSceneLayout.forSize(w: w, h: h, targetArtwork: targetArtwork);

    // Shadow (slight offset) so the hose reads over artwork.
    canvas
      ..setColor(shadow)
      ..setLineWidth(layout.hoseWidth + 2.2)
      ..moveTo(layout.engine.x + 1.6, layout.engine.y + 1.6)
      ..curveTo(layout.hydrant.x + 1.6, layout.hydrant.y + 1.6, layout.wye.x + 1.6, layout.wye.y + 1.6, layout.fdc.x + 1.6, layout.fdc.y + 1.6)
      ..curveTo(layout.nozzle.x + 1.6, layout.nozzle.y + 1.6, layout.target.x + 1.6, layout.target.y + 1.6, layout.target.x + 1.6, layout.target.y + 1.6)
      ..strokePath();

    // Outer dark outline.
    canvas
      ..setColor(outline)
      ..setLineWidth(layout.hoseWidth + 2.6)
      ..moveTo(layout.engine.x, layout.engine.y)
      ..curveTo(layout.hydrant.x, layout.hydrant.y, layout.wye.x, layout.wye.y, layout.fdc.x, layout.fdc.y)
      ..curveTo(layout.nozzle.x, layout.nozzle.y, layout.target.x, layout.target.y, layout.target.x, layout.target.y)
      ..strokePath();

    // Inner hose body.
    canvas
      ..setColor(hose)
      ..setLineWidth(layout.hoseWidth)
      ..moveTo(layout.engine.x, layout.engine.y)
      ..curveTo(layout.hydrant.x, layout.hydrant.y, layout.wye.x, layout.wye.y, layout.fdc.x, layout.fdc.y)
      ..curveTo(layout.nozzle.x, layout.nozzle.y, layout.target.x, layout.target.y, layout.target.x, layout.target.y)
      ..strokePath();

    // Anchor markers.
    canvas
      ..setColor(outline)
      ..setLineWidth(1.2)
      ..drawEllipse(layout.engine.x - 4, layout.engine.y - 4, 8, 8)
      ..strokePath();
    canvas
      ..drawEllipse(layout.hydrant.x - 4, layout.hydrant.y - 4, 8, 8)
      ..strokePath();
    canvas
      ..drawEllipse(layout.wye.x - 4, layout.wye.y - 4, 8, 8)
      ..strokePath();
    canvas
      ..drawEllipse(layout.fdc.x - 4, layout.fdc.y - 4, 8, 8)
      ..strokePath();
    canvas
      ..drawEllipse(layout.nozzle.x - 4, layout.nozzle.y - 4, 8, 8)
      ..strokePath();
    canvas
      ..drawRect(layout.target.x - 6, layout.target.y - 4, 12, 8)
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

/// Shared layout math for the printable scene so the asset placement and hose anchors
/// stay physically connected even as the scene scales up/down.
class _PrintableSceneLayout {
  const _PrintableSceneLayout({
    required this.truckRect,
    required this.primaryTargetRect,
    required this.secondaryTargetRect,
    required this.engineAnchor,
    required this.hydrantAnchor,
    required this.wyeAnchor,
    required this.fdcAnchor,
    required this.nozzleAnchor,
    required this.targetAnchor,
  });

  final Rect truckRect;
  final Rect primaryTargetRect;
  final Rect secondaryTargetRect;

  final Offset engineAnchor;
  final Offset hydrantAnchor;
  final Offset wyeAnchor;
  final Offset fdcAnchor;
  final Offset nozzleAnchor;
  final Offset targetAnchor;

  static _PrintableSceneLayout forSize({required Size size, required PrintableTargetArtwork targetArtwork}) {
    final w = size.width;
    final h = size.height;
    final safe = Rect.fromLTWH(10, 10, max(1, w - 20), max(1, h - 20));

    // Composition goals:
    // - engine lower-left
    // - target upper-right / upper-center
    // - hose travels across the page with a natural S-curve
    final truck = Rect.fromLTWH(safe.left + safe.width * 0.02, safe.top + safe.height * 0.62, safe.width * 0.40, safe.height * 0.30);

    final primaryTarget = Rect.fromLTWH(safe.left + safe.width * 0.58, safe.top + safe.height * 0.06, safe.width * 0.38, safe.height * 0.36);
    final secondaryTarget = Rect.fromLTWH(safe.left + safe.width * 0.74, safe.top + safe.height * 0.62, safe.width * 0.16, safe.height * 0.16);

    final engineAnchor = Offset(truck.right - 12, truck.top + truck.height * 0.55);

    // Fixed anchor points (even if not all are contextually used) so the hose reads realistic.
    final hydrantAnchor = Offset(safe.left + safe.width * 0.30, safe.top + safe.height * 0.78);
    final wyeAnchor = Offset(safe.left + safe.width * 0.44, safe.top + safe.height * 0.62);
    final fdcAnchor = Offset(safe.left + safe.width * 0.54, safe.top + safe.height * 0.48);
    final nozzleAnchor = Offset(safe.left + safe.width * 0.66, safe.top + safe.height * 0.40);

    // Target point depends slightly on artwork selection.
    final targetAnchor = switch (targetArtwork) {
      PrintableTargetArtwork.hydrant => Offset(primaryTarget.left + primaryTarget.width * 0.35, primaryTarget.top + primaryTarget.height * 0.62),
      PrintableTargetArtwork.brush => Offset(primaryTarget.left + primaryTarget.width * 0.55, primaryTarget.top + primaryTarget.height * 0.40),
      PrintableTargetArtwork.sedan => Offset(primaryTarget.left + primaryTarget.width * 0.55, primaryTarget.top + primaryTarget.height * 0.55),
      PrintableTargetArtwork.sedanAndBrush => Offset(primaryTarget.left + primaryTarget.width * 0.56, primaryTarget.top + primaryTarget.height * 0.52),
      PrintableTargetArtwork.buildingAndBrush => Offset(primaryTarget.left + primaryTarget.width * 0.56, primaryTarget.top + primaryTarget.height * 0.46),
      PrintableTargetArtwork.building => Offset(primaryTarget.left + primaryTarget.width * 0.62, primaryTarget.top + primaryTarget.height * 0.40),
    };

    return _PrintableSceneLayout(
      truckRect: truck,
      primaryTargetRect: primaryTarget,
      secondaryTargetRect: secondaryTarget,
      engineAnchor: engineAnchor,
      hydrantAnchor: hydrantAnchor,
      wyeAnchor: wyeAnchor,
      fdcAnchor: fdcAnchor,
      nozzleAnchor: nozzleAnchor,
      targetAnchor: targetAnchor,
    );
  }
}

class _PdfSceneLayout {
  const _PdfSceneLayout({
    required this.engine,
    required this.hydrant,
    required this.wye,
    required this.fdc,
    required this.nozzle,
    required this.target,
    required this.hoseWidth,
  });

  final PdfPoint engine;
  final PdfPoint hydrant;
  final PdfPoint wye;
  final PdfPoint fdc;
  final PdfPoint nozzle;
  final PdfPoint target;
  final double hoseWidth;

  static _PdfSceneLayout forSize({required double w, required double h, required PrintableTargetArtwork targetArtwork}) {
    final safeLeft = 12.0;
    final safeTop = 12.0;
    final safeW = max(1.0, w - 24.0);
    final safeH = max(1.0, h - 24.0);

    final engine = PdfPoint(safeLeft + safeW * 0.29, safeTop + safeH * 0.80);
    final hydrant = PdfPoint(safeLeft + safeW * 0.34, safeTop + safeH * 0.84);
    final wye = PdfPoint(safeLeft + safeW * 0.46, safeTop + safeH * 0.66);
    final fdc = PdfPoint(safeLeft + safeW * 0.56, safeTop + safeH * 0.52);
    final nozzle = PdfPoint(safeLeft + safeW * 0.68, safeTop + safeH * 0.42);

    final target = switch (targetArtwork) {
      PrintableTargetArtwork.hydrant => PdfPoint(safeLeft + safeW * 0.76, safeTop + safeH * 0.34),
      PrintableTargetArtwork.brush => PdfPoint(safeLeft + safeW * 0.84, safeTop + safeH * 0.26),
      PrintableTargetArtwork.sedan => PdfPoint(safeLeft + safeW * 0.84, safeTop + safeH * 0.30),
      PrintableTargetArtwork.sedanAndBrush => PdfPoint(safeLeft + safeW * 0.84, safeTop + safeH * 0.30),
      PrintableTargetArtwork.buildingAndBrush => PdfPoint(safeLeft + safeW * 0.86, safeTop + safeH * 0.22),
      PrintableTargetArtwork.building => PdfPoint(safeLeft + safeW * 0.86, safeTop + safeH * 0.22),
    };

    final hoseWidth = max(3.6, min(w, h) * 0.018);
    return _PdfSceneLayout(engine: engine, hydrant: hydrant, wye: wye, fdc: fdc, nozzle: nozzle, target: target, hoseWidth: hoseWidth);
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

    return LayoutBuilder(
      builder: (context, c) {
        final layout = _PrintableSceneLayout.forSize(size: c.biggest, targetArtwork: widget.targetArtwork);

        Widget img(String path) => Image.asset(path, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox());

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
            if (_truckOk) Positioned.fromRect(rect: layout.truckRect, child: img(PrintableScenarioAssetPack.truck)),
            ..._targetWidgetsWithLayout(targets, layout: layout),
            Positioned.fill(
              child: CustomPaint(
                painter: _PrintableHosePainter(
                  targetArtwork: widget.targetArtwork,
                  hoseLabel: widget.hoseLabel,
                  flowLabel: widget.flowLabel,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _targetWidgetsWithLayout(List<String> targets, {required _PrintableSceneLayout layout}) {
    Widget img(String path) {
      if (_targetOkByAsset[path] != true) return const SizedBox();
      return Image.asset(path, fit: BoxFit.contain, color: Colors.black, colorBlendMode: BlendMode.srcIn, errorBuilder: (_, __, ___) => const SizedBox());
    }

    if (targets.length == 1) {
      return [Positioned.fromRect(rect: layout.primaryTargetRect, child: img(targets.first))];
    }
    return [
      Positioned.fromRect(rect: layout.primaryTargetRect, child: img(targets[0])),
      Positioned.fromRect(rect: layout.secondaryTargetRect, child: img(targets[1])),
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

    // Background / groundline (lighter + positioned so it sits behind engine wheels).
    final groundY = size.height * 0.90;
    canvas.drawLine(Offset(10, groundY), Offset(size.width - 10, groundY), stroke);

    // Fallback shapes ONLY if the asset image(s) are missing.
    final truck = Rect.fromLTWH(size.width * 0.06, size.height * 0.66, size.width * 0.34, size.height * 0.22);
    final target = Rect.fromLTWH(size.width * 0.62, size.height * 0.10, size.width * 0.30, size.height * 0.22);

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
    required this.targetArtwork,
    required this.hoseLabel,
    required this.flowLabel,
  });

  final PrintableTargetArtwork targetArtwork;
  final String hoseLabel;
  final String flowLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _PrintableSceneLayout.forSize(size: size, targetArtwork: targetArtwork);

    final hoseShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    final hoseOutline = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final hoseFill = Paint()
      ..color = const Color(0xFFF2F2F2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final markerStroke = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.4;
    final markerFill = Paint()..color = Colors.white..style = PaintingStyle.fill;

    // Hose path: multi-anchor, multi-curve so it reads like a real routing.
    final p0 = layout.engineAnchor;
    final p1 = layout.hydrantAnchor;
    final p2 = layout.wyeAnchor;
    final p3 = layout.fdcAnchor;
    final p4 = layout.nozzleAnchor;
    final p5 = layout.targetAnchor;

    final hosePath = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(p0.dx + (p1.dx - p0.dx) * 0.55, p0.dy, p1.dx, p1.dy + (p2.dy - p1.dy) * 0.25, p2.dx, p2.dy)
      ..cubicTo(p2.dx + (p3.dx - p2.dx) * 0.35, p2.dy + (p3.dy - p2.dy) * 0.2, p3.dx - 10, p3.dy + 16, p3.dx, p3.dy)
      ..cubicTo(p3.dx + 40, p3.dy - 30, p4.dx - 30, p4.dy + 10, p4.dx, p4.dy)
      ..cubicTo(p4.dx + 28, p4.dy - 18, p5.dx - 26, p5.dy + 10, p5.dx, p5.dy);

    canvas.drawPath(hosePath.shift(const Offset(1.5, 2.0)), hoseShadow);
    canvas.drawPath(hosePath, hoseOutline);
    canvas.drawPath(hosePath, hoseFill);

    void drawAnchor(Offset p, String label) {
      canvas.drawCircle(p, 4.2, markerFill);
      canvas.drawCircle(p, 4.2, markerStroke);
      final tp = TextPainter(textDirection: TextDirection.ltr);
      tp.text = TextSpan(text: label, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800));
      tp.layout(maxWidth: size.width);
      final offset = Offset((p.dx + 8).clamp(4, size.width - tp.width - 4), (p.dy - 14).clamp(4, size.height - tp.height - 4));
      tp.paint(canvas, offset);
    }

    drawAnchor(p0, 'Engine');
    drawAnchor(p1, 'Hydrant');
    drawAnchor(p2, 'Wye');
    drawAnchor(p3, 'FDC');
    drawAnchor(p4, 'Nozzle');

    // Target marker.
    canvas.drawRect(Rect.fromCenter(center: p5, width: 16, height: 10), markerFill);
    canvas.drawRect(Rect.fromCenter(center: p5, width: 16, height: 10), markerStroke);

    // Overlay labels (hose + flow) stay pinned at top for readability.
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(text: hoseLabel, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900));
    textPainter.layout(maxWidth: size.width - 16);
    textPainter.paint(canvas, const Offset(10, 8));

    textPainter.text = TextSpan(text: flowLabel, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900));
    textPainter.layout(maxWidth: size.width - 16);
    textPainter.paint(canvas, Offset(size.width - 10 - textPainter.width, 8));
  }

  @override
  bool shouldRepaint(covariant _PrintableHosePainter oldDelegate) {
    return oldDelegate.targetArtwork != targetArtwork || oldDelegate.hoseLabel != hoseLabel || oldDelegate.flowLabel != flowLabel;
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


class _StarterPrintablePageCard extends StatelessWidget {
  const _StarterPrintablePageCard({
    required this.printing,
    required this.pages,
    required this.onPrintPage,
    required this.onPrintPack,
  });

  final bool printing;
  final List<_BrandedPrintablePage> pages;
  final ValueChanged<_BrandedPrintablePage>? onPrintPage;
  final VoidCallback? onPrintPack;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _CardShell(
      titleIcon: Icons.article_outlined,
      title: 'Free Printable Starter Pack',
      subtitle: 'Branded PNG worksheet pages that print exactly as designed.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < pages.length; i++) ...[
            if (i != 0) const SizedBox(height: 14),
            _PrintableImagePreview(page: pages[i]),
            const SizedBox(height: 10),
            _SecondaryActionButton(
              label: printing ? 'Preparing printable…' : 'View / Print ${pages[i].title.split('—').first.trim()}',
              icon: Icons.print_outlined,
              onTap: printing || onPrintPage == null ? null : () => onPrintPage!(pages[i]),
            ),
          ],
          const SizedBox(height: 12),
          _PrimaryActionButton(
            label: printing ? 'Preparing starter pack…' : 'Print Free Starter Pack Pages',
            icon: Icons.picture_as_pdf_outlined,
            onTap: onPrintPack,
          ),
          const SizedBox(height: 8),
          Text(
            'Each branded PNG is converted to a full-page letter-size PDF before opening the print/share dialog.',
            style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
              color: FirePumpSimColors.textMed,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrintableImagePreview extends StatelessWidget {
  const _PrintableImagePreview({required this.page});

  final _BrandedPrintablePage page;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Text(
                page.title,
                style: (t.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            AspectRatio(
              aspectRatio: 8.5 / 11,
              child: Image.asset(
                page.assetPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'Missing image asset:\n${page.assetPath}',
                        textAlign: TextAlign.center,
                        style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
                          color: FirePumpSimColors.textMed,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
      subtitle: 'Phone-friendly preview of what will print on letter paper (1 scenario per page).',
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
          Container(
            height: 540,
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
                      ? _WorksheetMultiPagePreview(worksheetTitle: worksheetTitle, department: department, scenarios: scenarios)
                      : _AnswerKeyPagePreview(worksheetTitle: worksheetTitle, department: department, scenarios: scenarios),
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

class _WorksheetMultiPagePreview extends StatelessWidget {
  const _WorksheetMultiPagePreview({required this.worksheetTitle, required this.department, required this.scenarios});
  final String worksheetTitle;
  final String department;
  final List<PrintablePumpScenario> scenarios;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < scenarios.length; i++) ...[
          _PrintablePageFrame(
            child: _WorksheetScenarioPagePreview(
              worksheetTitle: worksheetTitle,
              department: department,
              scenario: scenarios[i],
              index: i + 1,
              total: scenarios.length,
            ),
          ),
          if (i != scenarios.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _PrintablePageFrame extends StatelessWidget {
  const _PrintablePageFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = w * (11 / 8.5);
        return SizedBox(
          width: w,
          height: h,
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
            child: Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 12), child: child),
          ),
        );
      },
    );
  }
}

class _WorksheetScenarioPagePreview extends StatelessWidget {
  const _WorksheetScenarioPagePreview({
    required this.worksheetTitle,
    required this.department,
    required this.scenario,
    required this.index,
    required this.total,
  });

  final String worksheetTitle;
  final String department;
  final PrintablePumpScenario scenario;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) {
        final sceneH = c.maxHeight * 0.50;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PreviewHeader(title: worksheetTitle, department: department),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('$index. ${scenario.title}', style: (t.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(fontWeight: FontWeight.w900, color: Colors.black))),
                Text(_typeLabel(scenario.scenarioType), style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: sceneH,
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
                child: PrintableSceneWidget(
                  targetArtwork: scenario.targetArtwork,
                  hoseLabel: '${scenario.hoseDiameterLabel} • ${scenario.lengthFt} ft',
                  flowLabel: '${scenario.gpm} GPM',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PreviewBox(
                    title: 'Given / Reference',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(scenario.problem, style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87, height: 1.25)),
                        const SizedBox(height: 6),
                        _FactsGrid(scenario: scenario),
                        const SizedBox(height: 6),
                        Text('PP = NP + FL ± Elev + App', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black, fontWeight: FontWeight.w900)),
                        Text('FL = C × (GPM/100)² × L/100', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(child: _PreviewQuestionsBox()),
              ],
            ),
            const SizedBox(height: 10),
            const _PreviewShowWorkBox(),
            const Spacer(),
            Row(
              children: [
                const Expanded(child: _PreviewFooter()),
                Text('Page $index / $total', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title.toUpperCase(), style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _PreviewQuestionsBox extends StatelessWidget {
  const _PreviewQuestionsBox();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget q(String label) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(label, style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black))),
            const SizedBox(width: 8),
            const Expanded(child: Divider(height: 12, thickness: 1, color: Colors.black)),
          ],
        ),
      );
    }

    return _PreviewBox(
      title: 'Questions',
      child: Column(
        children: [
          q('1) Nozzle pressure (NP)'),
          q('2) Friction loss (FL)'),
          q('3) Elevation PSI (±)'),
          q('4) Appliance loss (App)'),
          q('5) Pump pressure (raw)'),
          q('6) Pump pressure (rounded)'),
          q('7) Hose diameter & length'),
        ],
      ),
    );
  }
}

class _PreviewShowWorkBox extends StatelessWidget {
  const _PreviewShowWorkBox();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _PreviewBox(
      title: 'Show Your Work',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Final PDP (PP) = ________ PSI (round to nearest 5 PSI)', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Container(
            height: 84,
            decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 0.8)),
            child: CustomPaint(painter: _WorkAreaLinesPainter()),
          ),
        ],
      ),
    );
  }
}

class _WorkAreaLinesPainter extends CustomPainter {
  const _WorkAreaLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withValues(alpha: 0.14)..strokeWidth = 1;
    const top = 14.0;
    const gap = 16.0;
    for (var y = top; y < size.height - 6; y += gap) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WorkLines extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget line(String label) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(width: 74, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black))),
            const Expanded(child: Divider(height: 14, thickness: 1, color: Colors.black)),
          ],
        ),
      );
    }

    return Column(
      children: [
        line('NP'),
        line('FL'),
        line('Elevation'),
        line('Appliance'),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const SizedBox(width: 74, child: Text('Final PP:', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black))),
              const Expanded(child: Divider(height: 16, thickness: 1.4, color: Colors.black)),
            ],
          ),
        ),
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
              Image.asset(
                _PrintableScenariosScreenState._brandBannerAsset,
                height: 18,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(width: 0, height: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: (t.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(fontWeight: FontWeight.w900, color: Colors.black))),
              const SizedBox(width: 10),
              Text(department, style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(fontWeight: FontWeight.w800, color: Colors.black)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('Name: ___________________________', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              Text('Date: __________', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Text('Score: ______ / ______', style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.black87, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

// _PreviewScenarioRow removed in favor of full-page preview.

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

class _PrintablePackTile extends StatefulWidget {
  const _PrintablePackTile({required this.pack, required this.selected, required this.unlocked, required this.onTap});

  final PrintablePack pack;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  State<_PrintablePackTile> createState() => _PrintablePackTileState();
}

class _PrintablePackTileState extends State<_PrintablePackTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = widget.unlocked ? FirePumpSimColors.printGreen : FirePumpSimColors.steel;
    final badgeText = widget.unlocked ? (widget.pack.isFree ? 'INCLUDED' : 'UNLOCKED') : 'LOCKED';
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.99 : 1,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FirePumpSimColors.charcoal3.withValues(alpha: widget.selected ? 0.65 : 0.45),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.selected ? FirePumpSimColors.red : accent.withValues(alpha: 0.55), width: widget.selected ? 1.3 : 1),
          ),
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Center(child: Icon(widget.unlocked ? Icons.description_outlined : Icons.lock_outline, color: widget.unlocked ? FirePumpSimColors.textHigh : FirePumpSimColors.textMed, size: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(widget.pack.title, style: (t.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900))),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: accent.withValues(alpha: 0.55))),
                          child: Text(badgeText, style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(widget.pack.description, style: (t.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: FirePumpSimColors.textMed, height: 1.35)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PrintablePill(icon: Icons.picture_as_pdf_outlined, label: '${widget.pack.pageCount} pages'),
                        const _PrintablePill(icon: Icons.checklist, label: 'Questions + work'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrintablePill extends StatelessWidget {
  const _PrintablePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FirePumpSimColors.charcoal2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FirePumpSimColors.steel.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: FirePumpSimColors.textMed),
          const SizedBox(width: 6),
          Text(label, style: (t.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: FirePumpSimColors.textHigh, fontWeight: FontWeight.w900)),
        ],
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
  final VoidCallback? onTap;

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.985 : 1,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: enabled ? FirePumpSimColors.red : FirePumpSimColors.red.withValues(alpha: 0.45),
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
