import 'dart:typed_data';
import 'dart:async';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

import 'package:firepumpsim/utils/pdf_download.dart' show PdfDownloadSession;

class _WebPdfDownloadSession implements PdfDownloadSession {
  _WebPdfDownloadSession({required this.filename, required this.popup});

  final String filename;
  final html.WindowBase? popup;
  bool _done = false;

  @override
  Future<void> complete(Uint8List bytes) async {
    if (_done) return;
    _done = true;
    try {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      if (popup != null) {
        // Navigate the pre-opened tab to the PDF blob URL.
        // This is the most reliable approach in embedded web previews.
        popup!.location.href = url;
      } else {
        // Fallback: attempt direct download.
        final a = html.AnchorElement(href: url)
          ..download = filename
          ..style.display = 'none';
        html.document.body?.append(a);
        a.click();
        a.remove();
      }

      // Best-effort cleanup. If we navigated a tab to the blob URL, revoking it
      // immediately can break the loaded document in some browsers.
      // Delay the revoke a bit.
      Timer(const Duration(seconds: 30), () {
        try {
          html.Url.revokeObjectUrl(url);
        } catch (_) {}
      });
    } catch (e, st) {
      debugPrint('Web PDF session complete failed: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> abort([Object? error]) async {
    if (_done) return;
    _done = true;
    try {
      // WindowBase does not reliably expose a writable document in all contexts.
      // Best-effort: close the blank tab if we opened one.
      popup?.close();
    } catch (e, st) {
      debugPrint('Web PDF session abort failed: $e\n$st');
    }
  }
}

PdfDownloadSession startPdfDownload({required String filename}) {
  // IMPORTANT: must be called synchronously from a user gesture.
  // If blocked, popup will be null and we'll fall back to a direct download.
  final popup = html.window.open('about:blank', '_blank');
  return _WebPdfDownloadSession(filename: filename, popup: popup);
}

Future<void> downloadPdfBytes({required Uint8List bytes, required String filename}) async {
  try {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final a = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';

    html.document.body?.append(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);
  } catch (e, st) {
    debugPrint('Web PDF download failed: $e\n$st');
    rethrow;
  }
}
