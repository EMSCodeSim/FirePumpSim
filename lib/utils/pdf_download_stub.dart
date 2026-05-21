import 'dart:typed_data';

import 'package:firepumpsim/utils/pdf_download.dart' show PdfDownloadSession;

class _UnsupportedPdfDownloadSession implements PdfDownloadSession {
  @override
  Future<void> complete(Uint8List bytes) async {
    throw UnsupportedError('Web-only PDF download is not supported on this platform.');
  }

  @override
  Future<void> abort([Object? error]) async {
    throw UnsupportedError('Web-only PDF download is not supported on this platform.');
  }
}

PdfDownloadSession startPdfDownload({required String filename}) => _UnsupportedPdfDownloadSession();

Future<void> downloadPdfBytes({required Uint8List bytes, required String filename}) async {
  throw UnsupportedError('Web-only PDF download is not supported on this platform.');
}
