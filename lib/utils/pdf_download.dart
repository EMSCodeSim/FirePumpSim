import 'dart:typed_data';

import 'package:firepumpsim/utils/pdf_download_stub.dart'
    if (dart.library.html) 'package:firepumpsim/utils/pdf_download_web.dart' as impl;

/// Downloads [bytes] as a file called [filename] on web.
///
/// On non-web platforms, this throws [UnsupportedError].
Future<void> downloadPdfBytes({required Uint8List bytes, required String filename}) => impl.downloadPdfBytes(bytes: bytes, filename: filename);
