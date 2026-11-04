import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/analytics_service.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class DealDetailsController extends GetxController {
  final DealRepo dealRepo;
  final CartService cartService;
  final AnalyticsService analytics;

  DealDetailsController({
    required this.dealRepo,
    required this.cartService,
    required this.analytics,
  });

  late DealModel deal;
  bool _hasDeal = false;
  final isLoaded = false.obs;
  final loadError = RxnString();

  final _quantityLeft = RxnInt();
  int? get quantityLeft => _quantityLeft.value;
  Worker? _cartWorker;

  @override
  void onInit() {
    super.onInit();
    final argument = Get.arguments;
    if (argument is DealModel) {
      initializeDeal(argument);
    } else {
      _loadDealFromRoute();
    }
  }

  void initializeDeal(DealModel value) {
    if (_hasDeal && deal.id == value.id) return;
    deal = value;
    _hasDeal = true;
    isLoaded.value = true;
    loadError.value = null;
    _quantityLeft.value = value.quantityLeft;
    analytics.logEvent('deal_details_view', {
      'deal_id': value.id,
      'source': Get.parameters['source'] ?? 'unknown',
    });
    // Whenever the cart changes, re-check this deal's remaining stock so the
    // details screen never shows stale availability.
    _cartWorker ??= ever(cartService.itemCount, (_) => _recheckAvailability());
  }

  Future<void> _loadDealFromRoute() async {
    final id = int.tryParse(Get.parameters['id'] ?? '');
    if (id == null) {
      loadError.value = 'This deal link is invalid.';
      return;
    }

    try {
      initializeDeal(await dealRepo.fetchById(id));
    } catch (e) {
      LogService.error('failed to load deal $id', e);
      loadError.value = 'This deal could not be found.';
    }
  }

  Future<void> _recheckAvailability() async {
    if (!_hasDeal) return;

    LogService.log('re-checking availability for deal ${deal.id}');
    final fresh = await dealRepo.fetchById(deal.id);
    _quantityLeft.value = fresh.quantityLeft;
  }

  void addToCart() {
    if (!_hasDeal) return;

    cartService.add(deal);
    Get.snackbar(
      'Added to bag',
      '${deal.name} — pick up ${deal.pickupWindow.label}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void onClose() {
    _cartWorker?.dispose();
    super.onClose();
  }
}
