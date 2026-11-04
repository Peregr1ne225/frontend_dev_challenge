import 'dart:async';

import 'package:get/get.dart';

/// A single app-wide clock shared by visible flash-sale countdowns.
class FlashSaleClock extends GetxService {
  final now = DateTime.now().obs;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      now.value = DateTime.now();
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
