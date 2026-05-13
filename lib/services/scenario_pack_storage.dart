import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only storage for which scenario packs are purchased/unlocked.
///
/// No backend is required. This is intentionally lightweight so Dreamflow
/// projects can demo pack gating while remaining offline.
class ScenarioPackStorage {
  static const String _purchasedPackIdsKey = 'purchased_pack_ids_v1';

  Future<Set<String>> loadPurchasedPackIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_purchasedPackIdsKey) ?? const <String>[];
      return ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    } catch (e) {
      debugPrint('ScenarioPackStorage.loadPurchasedPackIds failed: $e');
      return <String>{};
    }
  }

  Future<void> setPurchased({required String packId, required bool purchased}) async {
    final id = packId.trim();
    if (id.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = (prefs.getStringList(_purchasedPackIdsKey) ?? const <String>[]).map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
      if (purchased) {
        current.add(id);
      } else {
        current.remove(id);
      }
      await prefs.setStringList(_purchasedPackIdsKey, current.toList(growable: false));
    } catch (e) {
      debugPrint('ScenarioPackStorage.setPurchased failed: $e');
    }
  }
}
