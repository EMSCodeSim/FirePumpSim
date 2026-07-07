import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class PlatformInfoImpl {
  static bool get isIOS {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  static bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }
}
