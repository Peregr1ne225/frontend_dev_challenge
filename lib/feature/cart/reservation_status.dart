import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../model/cart_item_model.dart';
import '../../service/flash_sale_clock.dart';

/// Shows pending/unreserved units and the earliest confirmed hold expiry.
/// Only this status text observes the shared one-second clock.
class ReservationStatus extends StatelessWidget {
  final CartItemModel item;
  final VoidCallback? onRetryReservations;

  const ReservationStatus({
    super.key,
    required this.item,
    this.onRetryReservations,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final now = Get.find<FlashSaleClock>().now.value.toUtc();
      final messages = <String>[];

      if (item.pendingReservations > 0) {
        messages.add('Reserving ${item.pendingReservations}…');
      }
      if (item.unreservedQuantity > 0) {
        messages.add('Reservation needed for ${item.unreservedQuantity}');
      }

      if (item.reservations.isNotEmpty) {
        final earliestExpiry = item.reservations
            .map((reservation) => reservation.expiresAt)
            .reduce((first, next) => first.isBefore(next) ? first : next);
        final remaining = earliestExpiry.difference(now);

        if (remaining.inSeconds <= 0) {
          messages.add('Reservation expired');
        } else {
          final minutes = remaining.inMinutes.toString().padLeft(2, '0');
          final seconds = remaining.inSeconds
              .remainder(60)
              .toString()
              .padLeft(2, '0');
          messages.add('Reserved · $minutes:$seconds left');
        }
      }

      if (messages.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            messages.join(' · '),
            style: TextStyle(
              fontSize: 11.5,
              color: item.unreservedQuantity > 0 ||
                      item.reservations
                          .any((reservation) => reservation.isExpired)
                  ? Colors.red.shade700
                  : Colors.grey.shade600,
            ),
          ),
          if (item.unreservedQuantity > 0 &&
              item.pendingReservations == 0 &&
              onRetryReservations != null)
            TextButton(
              onPressed: onRetryReservations,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
              child: const Text('Reserve again'),
            ),
        ],
      );
    });
  }
}
