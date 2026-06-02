import 'dart:typed_data';

import 'package:firepumpsim/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:js_interop';
import 'package:pdf/pdf.dart' as pdf;
import 'package:printing/printing.dart' as pr;

// Web-only imports (supported by Flutter Web as of 2024+).
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;
import 'package:web/web.dart' as web;

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
        web.URL.revokeObjectURL(_webObjectUrl!);
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
                                   ? _PdfWebIFrameViewer(
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

class _PdfWebIFrameViewer extends StatefulWidget {
  const _PdfWebIFrameViewer({
    required this.bytes,
    required this.filename,
    required this.onObjectUrlChanged,
  });

  final Uint8List bytes;
  final String filename;
  final ValueChanged<String> onObjectUrlChanged;

  @override
  State<_PdfWebIFrameViewer> createState() => _PdfWebIFrameViewerState();
}

class _PdfWebIFrameViewerState extends State<_PdfWebIFrameViewer> {
  String? _viewType;
  String? _objectUrl;
  Object? _error;
  final ValueNotifier<bool> _iframeLoaded = ValueNotifier<bool>(false);
  web.HTMLIFrameElement? _iframe;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _PdfWebIFrameViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) _init();
  }

  void _init() {
    try {
      _iframeLoaded.value = false;
      if (_objectUrl != null) {
        web.URL.revokeObjectURL(_objectUrl!);
        _objectUrl = null;
      }
      _iframe = null;
      // package:web expects a JSArray<BlobPart>. Convert the Dart bytes into a
      // JS-friendly Uint8Array and then to a JS array.
      final jsBytes = widget.bytes.toJS;
      final blobParts = <JSAny>[jsBytes].toJS;
      final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'application/pdf'));
      final url = web.URL.createObjectURL(blob);
      final viewType = 'pdf-iframe-${DateTime.now().microsecondsSinceEpoch}';
      final loadedNotifier = _iframeLoaded;

      ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final iframe = web.HTMLIFrameElement()
          ..src = url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..setAttribute('title', widget.filename);
        _iframe = iframe;
        iframe.onLoad.listen((_) {
          // Some environments briefly render a blank iframe while the browser
          // PDF plugin boots. This lets us show a friendly placeholder until
          // the first successful load event.
          loadedNotifier.value = true;
        });
        return iframe;
      });

      setState(() {
        _error = null;
        _objectUrl = url;
        _viewType = viewType;
      });
      widget.onObjectUrlChanged(url);
    } catch (e, st) {
      debugPrint('Failed to create web PDF viewer iframe: $e\n$st');
      setState(() {
        _error = e;
        _viewType = null;
      });
    }
  }

  @override
  void dispose() {
    try {
      if (_objectUrl != null) web.URL.revokeObjectURL(_objectUrl!);
    } catch (e) {
      debugPrint('Failed to revoke iframe PDF object URL: $e');
    }
    _iframeLoaded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _PdfLoadErrorCard(
        error: _error!,
        onRetry: _init,
      );
    }
    if (_viewType == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: HtmlElementView(viewType: _viewType!),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _iframeLoaded,
                builder: (context, loaded, _) {
                  return IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      opacity: loaded ? 0 : 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.picture_as_pdf_outlined, size: 72, color: Colors.black87),
                                  const SizedBox(height: 14),
                                  Text(
                                    widget.filename,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: Colors.black, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Loading preview…',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.black54, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            ],
          ),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<bool>(
          valueListenable: _iframeLoaded,
          builder: (context, loaded, _) {
            return FilledButton.icon(
              onPressed: loaded
                  ? () {
                      try {
                        final w = _iframe?.contentWindow;
                        if (w == null) throw StateError('PDF iframe not ready for printing.');
                        w.print();
                        debugPrint('Triggered browser print for: ${widget.filename}');
                      } catch (e, st) {
                        debugPrint('Web PDF print failed: $e\n$st');
                        try {
                          if (_objectUrl != null) {
                            // Fallback: open the PDF in a new tab so the user can
                            // use the browser's built-in print button.
                            web.window.open(_objectUrl!, '_blank');
                          }
                        } catch (e2, st2) {
                          debugPrint('Web PDF print fallback open-tab failed: $e2\n$st2');
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not trigger print directly. Opened the PDF in a new tab to print.')),
                          );
                        }
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(backgroundColor: FirePumpSimColors.textHigh, foregroundColor: FirePumpSimColors.charcoal),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print'),
            );
          },
        ),
      ],
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
