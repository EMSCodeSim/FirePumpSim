import 'dart:typed_data';
import 'dart:js_interop';

import 'package:firepumpsim/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Web-only imports.
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;
import 'package:web/web.dart' as web;

/// Web-only PDF renderer using an `<iframe>` + Blob URL.
///
/// This is isolated behind a conditional import to avoid breaking iOS/Android
/// builds (which cannot import `dart:ui_web`, `package:web`, etc.).
class PdfWebViewer extends StatefulWidget {
  const PdfWebViewer({
    super.key,
    required this.bytes,
    required this.filename,
    required this.onObjectUrlChanged,
  });

  final Uint8List bytes;
  final String filename;
  final ValueChanged<String> onObjectUrlChanged;

  @override
  State<PdfWebViewer> createState() => _PdfWebViewerState();
}

/// Revoke a Blob/Object URL created by this viewer.
void revokePdfObjectUrl(String url) {
  try {
    web.URL.revokeObjectURL(url);
  } catch (e, st) {
    debugPrint('Failed to revoke PDF object URL: $e\n$st');
  }
}

class _PdfWebViewerState extends State<PdfWebViewer> {
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
  void didUpdateWidget(covariant PdfWebViewer oldWidget) {
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
        iframe.onLoad.listen((_) => loadedNotifier.value = true);
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('Could not open PDF preview.\n$_error', textAlign: TextAlign.center),
        ),
      );
    }
    if (_viewType == null) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(16), child: HtmlElementView(viewType: _viewType!)),
              ValueListenableBuilder<bool>(
                valueListenable: _iframeLoaded,
                builder: (context, loaded, _) {
                  return IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      opacity: loaded ? 0 : 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Loading preview…',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54, height: 1.35),
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
              ),
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
                          if (_objectUrl != null) web.window.open(_objectUrl!, '_blank');
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
