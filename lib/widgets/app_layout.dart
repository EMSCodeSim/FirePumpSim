import 'package:flutter/material.dart';

/// Shared layout constants for screens that sit above the reference launcher bar.
class AppLayout {
  AppLayout._();

  /// Approximate height of the bottom reference launcher bar (excluding safe area).
  static const double referenceBarHeight = 72;

  /// Bottom padding for scrollable content so the last item clears the launcher bar.
  static double scrollBottomPadding(BuildContext context) {
    return referenceBarHeight + MediaQuery.paddingOf(context).bottom + 16;
  }

  /// Max content width on wide screens for readable line lengths.
  static const double maxContentWidth = 720;
}
