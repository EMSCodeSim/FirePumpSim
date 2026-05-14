import 'dart:typed_data';

Future<void> downloadPdfBytes({required Uint8List bytes, required String filename}) async {
  throw UnsupportedError('Web-only PDF download is not supported on this platform.');
}
