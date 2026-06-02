import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Non-web stub for the web PDF viewer.
///
/// This file exists so `pdf_viewer_screen.dart` can use conditional imports
/// without pulling in any web-only libraries on iOS/Android.
class PdfWebViewer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Web PDF viewer is not available on this platform.'),
    );
  }
}

/// Web-only cleanup hook. No-op on non-web platforms.
void revokePdfObjectUrl(String url) {}
