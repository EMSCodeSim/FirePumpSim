import 'dart:typed_data';

import 'package:firepumpsim/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:printing/printing.dart' as pr;

import 'package:firepumpsim/screens/pdf_viewer_web_stub.dart'
    if (dart.library.html) 'package:firepumpsim/screens/pdf_viewer_web.dart' as pdf_web;

class PdfViewerArgs {
  const PdfViewerArgs({
    required this.title,
    required this.assetPath,
    required this.filename,
    this.previewAssetPath,
  });

  final String title;
  final String assetPath;
  final String filename;
  final String? previewAssetPath;
}

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.args});
  final PdfViewerArgs args;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _bytes;
  Object? _error;
  bool _loading = true;
  String? _webObjectUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final path = widget.args.assetPath;
      if (path.isEmpty) throw StateError('Missing PDF asset path.');
      final data = await rootBundle.load(path);
      if (!mounted) return;
      setState(() => _bytes = data.buffer.asUint8List());
    } catch (e, st) {
      debugPrint('Failed to load PDF asset for viewer: $e\n$st');
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    try {
      if (kIsWeb && _webObjectUrl != null) {
        pdf_web.revokePdfObjectUrl(_webObjectUrl!);
      }
    } catch (e) {
      debugPrint('Failed to revoke PDF object URL: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_error != null)
                    ? _PdfLoadErrorCard(
                        error: _error!,
                        onRetry: _load,
                      )
                    : (bytes == null)
                        ? _PdfLoadErrorCard(
                            error: StateError('No PDF bytes loaded.'),
                            onRetry: _load,
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: FirePumpSimColors.charcoal2,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: kIsWeb
                                  ? pdf_web.PdfWebViewer(
                                      bytes: bytes,
                                      filename: widget.args.filename,
                                      onObjectUrlChanged: (url) {
                                        // Track so we can revoke it on dispose.
                                        _webObjectUrl = url;
                                      },
                                    )
                                  : pr.PdfPreview(
                                      allowSharing: true,
                                      allowPrinting: true,
                                      canChangeOrientation: false,
                                      canChangePageFormat: false,
                                      pdfFileName: widget.args.filename,
                                      build: (_) async => bytes,
                                      initialPageFormat: pdf.PdfPageFormat.letter,
                                      loadingWidget: const Center(child: CircularProgressIndicator()),
                                      onError: (context, error) {
                                        debugPrint('PdfPreview error: $error');
                                        return _PdfLoadErrorCard(error: error, onRetry: _load);
                                      },
                                      onPrinted: (context) => debugPrint('PDF printed: ${widget.args.filename}'),
                                      onShared: (context) => debugPrint('PDF shared: ${widget.args.filename}'),
                                    ),
                            ),
                          ),
          ),
        ),
      ),
    );
  }
}

class _PdfLoadErrorCard extends StatelessWidget {
  const _PdfLoadErrorCard({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: FirePumpSimColors.charcoal2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, color: FirePumpSimColors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Could not open this PDF', style: textTheme.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$error',
                  style: textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: FirePumpSimColors.textHigh,
                      foregroundColor: FirePumpSimColors.charcoal,
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
