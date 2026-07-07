import 'dart:async';

import 'package:firepumpsim/services/scenario_pack_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Store-backed unlocks for paid scenario packs.
///
/// Pump Operations Pack 1 is a non-consumable purchase. The same product ID must
/// be created in App Store Connect and Play Console:
///   firepumpsim.pump_ops_pack_01
class ScenarioPurchaseService extends ChangeNotifier {
  ScenarioPurchaseService._();

  static final ScenarioPurchaseService instance = ScenarioPurchaseService._();

  static const Map<String, String> packProductIds = <String, String>{
    'pump_ops_pack_01': 'firepumpsim.pump_ops_pack_01',
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  final ScenarioPackStorage _storage = ScenarioPackStorage();

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _initialized = false;
  bool _initializing = false;
  bool _storeAvailable = false;
  bool _queryingProducts = false;
  bool _restoring = false;
  String? _pendingProductId;
  String? _errorMessage;
  int _unlockRevision = 0;

  final Map<String, ProductDetails> _productsById = <String, ProductDetails>{};
  final Set<String> _notFoundProductIds = <String>{};

  bool get initialized => _initialized;
  bool get initializing => _initializing;
  bool get storeAvailable => _storeAvailable;
  bool get queryingProducts => _queryingProducts;
  bool get restoring => _restoring;
  bool get isBusy => _initializing || _queryingProducts || _restoring || _pendingProductId != null;
  String? get errorMessage => _errorMessage;
  int get unlockRevision => _unlockRevision;

  String? productIdForPack(String packId) => packProductIds[packId.trim()];

  ProductDetails? productForPack(String packId) {
    final productId = productIdForPack(packId);
    if (productId == null) return null;
    return _productsById[productId];
  }

  bool productNotFoundForPack(String packId) {
    final productId = productIdForPack(packId);
    if (productId == null) return true;
    return _notFoundProductIds.contains(productId);
  }

  bool isPurchasePendingForPack(String packId) {
    final productId = productIdForPack(packId);
    return productId != null && _pendingProductId == productId;
  }

  Future<void> initialize() async {
    if (_initialized || _initializing) return;

    _initializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _subscription ??= _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (Object error) {
          _pendingProductId = null;
          _errorMessage = 'Purchase update failed: $error';
          notifyListeners();
        },
      );

      _storeAvailable = await _iap.isAvailable();
      if (_storeAvailable) {
        await _loadProducts();
      } else {
        _errorMessage = 'Store purchases are not available on this device yet.';
      }
    } catch (e) {
      _storeAvailable = false;
      _errorMessage = 'Store purchase setup failed: $e';
    } finally {
      _initialized = true;
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshProducts() async {
    if (!_initialized) {
      await initialize();
      return;
    }
    if (!_storeAvailable) return;
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    _queryingProducts = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _iap.queryProductDetails(packProductIds.values.toSet());

      _productsById
        ..clear()
        ..addEntries(response.productDetails.map((p) => MapEntry<String, ProductDetails>(p.id, p)));

      _notFoundProductIds
        ..clear()
        ..addAll(response.notFoundIDs);

      if (response.error != null) {
        _errorMessage = response.error!.message;
      } else if (_productsById.isEmpty) {
        _errorMessage = 'No store products were found. Make sure the product ID is active in App Store Connect and Play Console.';
      }
    } catch (e) {
      _errorMessage = 'Could not load store products: $e';
    } finally {
      _queryingProducts = false;
      notifyListeners();
    }
  }

  Future<bool> purchasePack(String packId) async {
    await initialize();
    if (!_storeAvailable) {
      _errorMessage = 'Store purchases are not available on this device yet.';
      notifyListeners();
      return false;
    }

    final product = productForPack(packId);
    if (product == null) {
      _errorMessage = 'This add-on is not available from the store yet. Check that firepumpsim.pump_ops_pack_01 is created, active, and approved for this app.';
      notifyListeners();
      return false;
    }

    try {
      _pendingProductId = product.id;
      _errorMessage = null;
      notifyListeners();

      final purchaseParam = PurchaseParam(productDetails: product);
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started) {
        _pendingProductId = null;
        _errorMessage = 'The purchase did not start.';
        notifyListeners();
      }
      return started;
    } catch (e) {
      _pendingProductId = null;
      _errorMessage = 'Purchase failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    await initialize();
    if (!_storeAvailable) {
      _errorMessage = 'Store purchases are not available on this device yet.';
      notifyListeners();
      return;
    }

    _restoring = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _iap.restorePurchases();
    } catch (e) {
      _errorMessage = 'Restore purchases failed: $e';
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      if (!packProductIds.values.contains(purchase.productID)) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _pendingProductId = purchase.productID;
          break;
        case PurchaseStatus.error:
          _pendingProductId = null;
          _errorMessage = purchase.error?.message ?? 'Purchase failed.';
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliverPurchasedProduct(purchase.productID);
          _pendingProductId = null;
          _errorMessage = null;
          break;
        case PurchaseStatus.canceled:
          _pendingProductId = null;
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }

    notifyListeners();
  }

  Future<void> _deliverPurchasedProduct(String productId) async {
    String? packId;
    for (final entry in packProductIds.entries) {
      if (entry.value == productId) {
        packId = entry.key;
        break;
      }
    }
    if (packId == null) return;

    await _storage.setPurchased(packId: packId, purchased: true);
    _unlockRevision += 1;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
