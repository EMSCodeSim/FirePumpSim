import 'dart:convert';

import 'package:firepumpsim/models/scenario_pack.dart';
import 'package:firepumpsim/services/scenario_pack_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScenarioPackRepository {
  const ScenarioPackRepository({ScenarioPackStorage? storage}) : _storage = storage;

  final ScenarioPackStorage? _storage;

  Future<List<ScenarioPack>> loadPacks() async {
    try {
      final raw = await rootBundle.loadString('assets/scenarios/scenario-packs.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const <ScenarioPack>[];

      final index = ScenarioPacksIndex.fromJson(decoded);
      final purchasedIds = _storage == null ? <String>{} : await _storage.loadPurchasedPackIds();

      final packs = index.packs
          .where((p) => p.packId.trim().isNotEmpty)
          .map((p) {
            // Free packs are always unlocked.
            final unlocked = p.isFree || p.isPurchased || purchasedIds.contains(p.packId);
            return p.copyWith(isPurchased: unlocked);
          })
          .toList(growable: true);

      // Ensure Free Starter Pack is always first when present.
      packs.sort((a, b) {
        if (a.packId == 'free_starter_pack') return -1;
        if (b.packId == 'free_starter_pack') return 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

      return packs.toList(growable: false);
    } catch (e) {
      debugPrint('ScenarioPackRepository.loadPacks failed: $e');
      return const <ScenarioPack>[];
    }
  }

  Future<List<ScenarioPack>> loadUnlockedPacks() async {
    final packs = await loadPacks();
    return packs.where((p) => p.isFree || p.isPurchased).toList(growable: false);
  }

  Future<List<ScenarioPack>> loadLockedPacks() async {
    final packs = await loadPacks();
    return packs.where((p) => !p.isFree && !p.isPurchased).toList(growable: false);
  }
}
