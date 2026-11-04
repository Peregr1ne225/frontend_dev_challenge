import 'dart:async';

import 'package:get/get.dart';

/// A single app-wide clock shared by visible flash-sale countdowns.
class FlashSaleClock extends GetxService {
  DateTime _currentTime = DateTime.now();
  final now = DateTime.now().obs;
  final _endsAtByDealId = <int, DateTime>{};
  final _expiredFlags = <int, bool>{};
  final _expiredByDealId = <int, RxBool>{};
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
  }

  RxBool expiredStateFor(int dealId, DateTime endsAt) {
    final previousEnd = _endsAtByDealId[dealId];
    var state = _expiredByDealId[dealId];
    if (previousEnd == null || !previousEnd.isAtSameMomentAs(endsAt)) {
      _endsAtByDealId[dealId] = endsAt;
      final expired = !endsAt.isAfter(_currentTime);
      _expiredFlags[dealId] = expired;
      state = RxBool(expired);
      _expiredByDealId[dealId] = state;
    } else if (_expiredFlags[dealId] != true &&
        !endsAt.isAfter(_currentTime)) {
      _markExpired(dealId);
    }
    return state!;
  }

  void _tick() {
    _currentTime = DateTime.now();
    now.value = _currentTime;
    for (final entry in _endsAtByDealId.entries) {
      if (_expiredFlags[entry.key] != true &&
          !entry.value.isAfter(_currentTime)) {
        _markExpired(entry.key);
      }
    }
  }

  void _markExpired(int dealId) {
    _expiredFlags[dealId] = true;
    _expiredByDealId[dealId]?.value = true;
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
