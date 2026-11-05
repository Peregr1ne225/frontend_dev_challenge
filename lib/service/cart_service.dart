import 'dart:async';

import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../repository/order_repo.dart';
import '../util/log_service.dart';
import 'flash_sale_clock.dart';

class _PendingCartAdd {
  bool cancelled = false;
}

/// App-wide cart. Lives for the whole session.
///
/// Bag state and stock reservations are managed for the whole app session.
class CartService extends GetxService {
  final OrderRepo orderRepo;

  CartService({required this.orderRepo});

  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;
  final Map<int, List<_PendingCartAdd>> _pendingAddsByDeal = {};
  Worker? _clockWorker;

  @override
  void onInit() {
    super.onInit();
    _clockWorker = ever(Get.find<FlashSaleClock>().now, (_) {
      _removeExpiredItems();
    });
  }

  Future<void> add(DealModel deal) async {
    final removedNames = _removeExpiredItems(notify: false);
    if (_isExpired(deal)) {
      if (!removedNames.contains(deal.name)) removedNames.add(deal.name);
      _showExpiredNotice(removedNames, rejectedAdd: true);
      return;
    }
    _showExpiredNotice(removedNames);

    var existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        return;
      }
      existing.quantity++;
      existing.pendingReservations++;
      items.refresh();
    } else {
      existing = CartItemModel(
        deal: deal,
        quantity: 1,
        pendingReservations: 1,
      );
      items.add(existing);
    }
    _recount();

    final item = existing;
    final operation = _PendingCartAdd();
    (_pendingAddsByDeal[deal.id] ??= <_PendingCartAdd>[]).add(operation);

    try {
      final reservation = await orderRepo.reserve(deal.id, quantity: 1);
      _removePendingAdd(deal.id, operation);

      if (operation.cancelled ||
          !items.any((current) => identical(current, item))) {
        await _releaseReservation(reservation.id);
        return;
      }

      item.reservations.add(reservation);
      item.pendingReservations--;
      items.refresh();
    } catch (error) {
      _removePendingAdd(deal.id, operation);
      if (operation.cancelled ||
          !items.any((current) => identical(current, item))) {
        return;
      }

      item.pendingReservations--;
      item.quantity--;
      if (item.quantity <= 0) {
        items.remove(item);
      } else {
        items.refresh();
      }
      _recount();
      LogService.error('cart reservation failed for deal ${deal.id}', error);
      Get.snackbar(
        'Could not add this deal',
        'It could not be reserved and was removed from your bag. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;

    final pendingAdds = _pendingAddsByDeal[dealId];
    _PendingCartAdd? pendingAdd;
    if (pendingAdds != null) {
      for (final add in pendingAdds.reversed) {
        if (!add.cancelled) {
          pendingAdd = add;
          break;
        }
      }
    }
    if (pendingAdd != null) {
      pendingAdd.cancelled = true;
      existing.pendingReservations--;
    } else if (existing.reservations.isNotEmpty) {
      final reservation = existing.reservations.removeLast();
      unawaited(_releaseReservation(reservation.id));
    }

    existing.quantity--;
    if (existing.quantity <= 0) {
      items.removeWhere((i) => i.deal.id == dealId);
    } else {
      items.refresh();
    }
    _recount();
  }

  void remove(int dealId) {
    final item = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (item == null) return;

    _cancelPendingAdds(dealId);
    items.remove(item);
    _recount();

    _releaseReservations(item);
    item.reservations.clear();
  }

  void clear({bool releaseReservations = true}) {
    final removedItems = items.toList();
    for (final item in removedItems) {
      _cancelPendingAdds(item.deal.id);
    }

    items.clear();
    _recount();

    for (final item in removedItems) {
      if (releaseReservations) _releaseReservations(item);
      item.reservations.clear();
    }
  }

  void removeExpiredItems() {
    _removeExpiredItems();
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _removePendingAdd(int dealId, _PendingCartAdd operation) {
    final pendingAdds = _pendingAddsByDeal[dealId];
    pendingAdds?.remove(operation);
    if (pendingAdds?.isEmpty ?? false) {
      _pendingAddsByDeal.remove(dealId);
    }
  }

  Future<void> _releaseReservation(String reservationId) async {
    try {
      await orderRepo.releaseReservation(reservationId);
    } catch (error) {
      LogService.error('failed to release reservation $reservationId', error);
    }
  }

  void _releaseReservations(CartItemModel item) {
    for (final reservation in item.reservations) {
      unawaited(_releaseReservation(reservation.id));
    }
  }

  void _cancelPendingAdds(int dealId) {
    for (final pendingAdd
        in _pendingAddsByDeal[dealId] ?? const <_PendingCartAdd>[]) {
      pendingAdd.cancelled = true;
    }
  }

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
    for (final item in expiredItems) {
      _cancelPendingAdds(item.deal.id);
      _releaseReservations(item);
      item.reservations.clear();
    }
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
