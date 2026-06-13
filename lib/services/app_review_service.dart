import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Requests an in-app review after a small number of meaningful sessions.
///
/// A “meaningful use” is defined as: user launches the app and reaches the home
/// screen (counted once per app session).
///
/// Design goals:
/// - Never prompt more than once (unless the app is reinstalled).
/// - Only attempt prompting from a safe place (home screen after load).
/// - Avoid breaking web/unsupported platforms.
class AppReviewService {
  AppReviewService._();

  static final AppReviewService instance = AppReviewService._();

  static const _prefsKeyUseCount = 'app_review_use_count';
  static const _prefsKeyHasRequested = 'app_review_has_requested';
  static const int _minUsesBeforePrompt = 5;

  bool _countedThisSession = false;
  bool _requestInFlight = false;

  bool get _isSupportedMobileTarget {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
  }

  /// Call this once when the user has reached the home screen for the session.
  Future<void> onHomeScreenShown() async {
    if (!_isSupportedMobileTarget) return;
    if (_countedThisSession) return;
    _countedThisSession = true;

    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // On some platforms (or misconfigured builds) this can throw. Fail silently.
      debugPrint('AppReviewService: SharedPreferences unavailable: $e');
      return;
    }

    final bool hasRequested = prefs.getBool(_prefsKeyHasRequested) ?? false;
    if (hasRequested) return;

    final int useCount = (prefs.getInt(_prefsKeyUseCount) ?? 0) + 1;
    await prefs.setInt(_prefsKeyUseCount, useCount);

    if (useCount < _minUsesBeforePrompt) return;

    // Guard against multiple triggers (e.g., hot reload, multiple homes).
    if (_requestInFlight) return;
    _requestInFlight = true;
    try {
      final inAppReview = InAppReview.instance;
      final bool available = await inAppReview.isAvailable();

      // We mark as requested after we *attempt* the flow to avoid repeated prompts.
      await prefs.setBool(_prefsKeyHasRequested, true);

      if (!available) return;
      await inAppReview.requestReview();
    } catch (e) {
      debugPrint('AppReviewService: request failed: $e');
      // Intentionally silent for the user.
    } finally {
      _requestInFlight = false;
    }
  }
}
