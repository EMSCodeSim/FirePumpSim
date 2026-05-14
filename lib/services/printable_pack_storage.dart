import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only storage for which *printable* packs are purchased/unlocked.
///
/// This intentionally does not depend on any backend. It mirrors the scenario
/// pack behavior but uses a separate preference key to avoid collisions.
class PrintablePackStorage {
  static const String _purchasedPackIdsKey = 'purchased_printable_pack_ids_v1';

  Future<Set<String>> loadPurchasedPackIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_purchasedPackIdsKey) ?? const <String>[];
      return ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    } catch (e) {
      debugPrint('PrintablePackStorage.loadPurchasedPackIds failed: $e');
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
      debugPrint('PrintablePackStorage.setPurchased failed: $e');
    }
  }
}
