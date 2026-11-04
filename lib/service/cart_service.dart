import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../util/log_service.dart';
import 'flash_sale_clock.dart';

/// App-wide cart. Lives for the whole session.
///
/// NOTE: the starter cart is purely local — it does not reserve stock on the
/// backend. See the "Reservations" feature task in PROBLEM.md.
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;
  Worker? _clockWorker;

  @override
  void onInit() {
    super.onInit();
    _clockWorker = ever(Get.find<FlashSaleClock>().now, (_) {
      _removeExpiredItems();
    });
  }

  void add(DealModel deal) {
    final removedNames = _removeExpiredItems(notify: false);
    if (_isExpired(deal)) {
      if (!removedNames.contains(deal.name)) removedNames.add(deal.name);
      _showExpiredNotice(removedNames, rejectedAdd: true);
      return;
    }
    _showExpiredNotice(removedNames);

    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        return;
      }
      existing.quantity++;
      items.refresh();
    } else {
      items.add(CartItemModel(deal: deal));
    }
    _recount();
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;
    existing.quantity--;
    if (existing.quantity <= 0) {
      items.removeWhere((i) => i.deal.id == dealId);
    } else {
      items.refresh();
    }
    _recount();
  }

  void remove(int dealId) {
    items.removeWhere((i) => i.deal.id == dealId);
    _recount();
  }

  void clear() {
    items.clear();
    _recount();
  }

  void removeExpiredItems() {
    _removeExpiredItems();
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }

  bool _isExpired(DealModel deal) {
    final endsAt = deal.flashSaleEndsAt;
    return endsAt != null && !endsAt.isAfter(DateTime.now());
  }

  List<String> _removeExpiredItems({bool notify = true}) {
    final expiredItems = items.where((item) => _isExpired(item.deal)).toList();
    if (expiredItems.isEmpty) return [];

    final expiredIds = expiredItems.map((item) => item.deal.id).toSet();
    items.removeWhere((item) => expiredIds.contains(item.deal.id));
    _recount();

    final names = expiredItems.map((item) => item.deal.name).toList();
    if (notify) _showExpiredNotice(names);
    return names;
  }

  void _showExpiredNotice(List<String> names, {bool rejectedAdd = false}) {
    if (names.isEmpty) return;
    final dealNames = names.join(', ');
    Get.snackbar(
      'Flash sale ended',
      rejectedAdd
          ? '$dealNames expired and could not be added. Expired bag items were removed.'
          : '$dealNames ${names.length == 1 ? 'was' : 'were'} removed from your bag because the sale expired.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  void onClose() {
    _clockWorker?.dispose();
    super.onClose();
  }
}
