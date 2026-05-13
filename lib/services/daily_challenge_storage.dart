import 'dart:convert';

import 'package:firepumpsim/models/daily_challenge_models.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyChallengeStorage {
  static const _statsKey = 'firepumpsim.dailyChallenge.stats';
  static const _historyKey = 'firepumpsim.dailyChallenge.history';

  Future<DailyChallengeStats> loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_statsKey);
      if (raw == null || raw.trim().isEmpty) return DailyChallengeStats.empty;
      return DailyChallengeStats.tryParse(raw) ?? DailyChallengeStats.empty;
    } catch (e) {
      debugPrint('DailyChallengeStorage.loadStats failed: $e');
      return DailyChallengeStats.empty;
    }
  }

  Future<void> saveStats(DailyChallengeStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statsKey, jsonEncode(stats.toJson()));
    } catch (e) {
      debugPrint('DailyChallengeStorage.saveStats failed: $e');
    }
  }

  Future<List<DailyChallengeResult>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final results = <DailyChallengeResult>[];
      for (final item in decoded) {
        if (item is Map) {
          try {
            results.add(DailyChallengeResult.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('Skipping corrupt daily history entry: $e');
          }
        }
      }
      // Auto-sanitize ordering newest-first for storage consistency.
      results.sort((a, b) => b.date.compareTo(a.date));
      await saveHistory(results);
      return results;
    } catch (e) {
      debugPrint('DailyChallengeStorage.loadHistory failed: $e');
      return const [];
    }
  }

  Future<void> saveHistory(List<DailyChallengeResult> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sanitized = [...history]..sort((a, b) => b.date.compareTo(a.date));
      await prefs.setString(_historyKey, jsonEncode(sanitized.map((e) => e.toJson()).toList(growable: false)));
    } catch (e) {
      debugPrint('DailyChallengeStorage.saveHistory failed: $e');
    }
  }

  Future<DailyChallengeResult?> getResultForDate(String yyyyMmDd) async {
    final history = await loadHistory();
    try {
      return history.firstWhere((r) => r.date == yyyyMmDd);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertResult(DailyChallengeResult result) async {
    final history = await loadHistory();
    final idx = history.indexWhere((r) => r.date == result.date);
    if (idx >= 0) {
      history[idx] = result;
    } else {
      history.add(result);
    }
    history.sort((a, b) => b.date.compareTo(a.date));
    await saveHistory(history);
  }
}
