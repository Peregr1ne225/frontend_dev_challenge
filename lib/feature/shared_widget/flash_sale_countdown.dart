import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../service/flash_sale_clock.dart';

/// Displays one flash-sale countdown; only this text observes the shared clock.
class FlashSaleCountdown extends StatelessWidget {
  final DateTime endsAt;
  final TextStyle? style;

  const FlashSaleCountdown({
    super.key,
    required this.endsAt,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final clock = Get.find<FlashSaleClock>();
    return Obx(() {
      final remaining = endsAt.difference(clock.now.value);
      if (remaining <= Duration.zero) {
        return Text('Expired', style: style);
      }

      final totalSeconds = (remaining.inMilliseconds + 999) ~/ 1000;
      final seconds = totalSeconds % 60;
      final minutes = (totalSeconds ~/ 60) % 60;
      final hours = totalSeconds ~/ 3600;
      final label = hours > 0
          ? '${hours.toString().padLeft(2, '0')}:'
              '${minutes.toString().padLeft(2, '0')}:'
              '${seconds.toString().padLeft(2, '0')}'
          : '${(totalSeconds ~/ 60).toString().padLeft(2, '0')}:'
              '${seconds.toString().padLeft(2, '0')}';

      return Text(label, style: style);
    });
  }
}
