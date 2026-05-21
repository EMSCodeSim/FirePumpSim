import 'dart:typed_data';

import 'package:firepumpsim/utils/pdf_download_stub.dart'
    if (dart.library.html) 'package:firepumpsim/utils/pdf_download_web.dart' as impl;

/// A download session that is started synchronously from a user gesture.
///
/// On web, this is used to avoid popup blockers that prevent opening/downloading
/// a PDF after a long async computation.
abstract class PdfDownloadSession {
  Future<void> complete(Uint8List bytes);
  Future<void> abort([Object? error]);
}

/// Starts a web PDF download session.
///
/// On web, this will try to open a new tab/window *immediately* (while still
/// in the button's onTap call stack). Later, call [PdfDownloadSession.complete]
/// with the final PDF bytes.
///
/// On non-web platforms, this throws [UnsupportedError].
PdfDownloadSession startPdfDownload({required String filename}) => impl.startPdfDownload(filename: filename);

/// One-shot helper for simple cases (web only).
Future<void> downloadPdfBytes({required Uint8List bytes, required String filename}) => impl.downloadPdfBytes(bytes: bytes, filename: filename);
