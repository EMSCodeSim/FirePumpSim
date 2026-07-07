import 'package:firepumpsim/utils/platform_info_stub.dart'
    if (dart.library.io) 'package:firepumpsim/utils/platform_info_io.dart';

abstract class PlatformInfo {
  static bool get isIOS => PlatformInfoImpl.isIOS;
  static bool get isAndroid => PlatformInfoImpl.isAndroid;
}
