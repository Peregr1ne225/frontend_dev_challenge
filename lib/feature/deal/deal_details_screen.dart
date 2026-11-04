import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app_config.dart';
import '../../service/flash_sale_clock.dart';
import '../shared_widget/flash_sale_countdown.dart';
import '../shared_widget/the_network_image.dart';
import 'deal_details_controller.dart';

class DealDetailsScreen extends GetView<DealDetailsController> {
  const DealDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isLoaded.value) {
        final error = controller.loadError.value;
        return Scaffold(
          appBar: AppBar(title: const Text('Deal')),
          body: Center(
            child: error == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error),
                      TextButton(onPressed: Get.back, child: const Text('Back')),
                    ],
                  ),
          ),
        );
      }

      final deal = controller.deal;
      final expiredState = deal.flashSaleEndsAt == null
          ? null
          : Get.find<FlashSaleClock>()
              .expiredStateFor(deal.id, deal.flashSaleEndsAt!);
      return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background:
                  TheNetworkImage(url: deal.imageUrl, fit: BoxFit.cover),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deal.name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(deal.storeName,
                      style: TextStyle(
                          fontSize: 15, color: Colors.grey.shade700)),
                  Text(deal.storeAddress,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('฿${deal.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppConfig.primaryGreen)),
                      const SizedBox(width: 8),
                      Text('฿${deal.originalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                              decoration: TextDecoration.lineThrough)),
                      const Spacer(),
                      Obx(() => Chip(
                            avatar: const Icon(Icons.inventory_2_outlined,
                                size: 16),
                            label: Text('${controller.quantityLeft ?? '-'} left'),
                          )),
                    ],
                  ),
                  if (deal.isFlashSale) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.bolt,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 6),
                        const Text('Flash sale ends in',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        FlashSaleCountdown(
                          endsAt: deal.flashSaleEndsAt!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E5E2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule,
                            color: AppConfig.primaryGreen),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pickup window',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey)),
                            Text(
                              '${deal.pickupWindow.label}'
                              '${deal.pickupWindow.isToday ? ' · today' : ''}',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (deal.pickupWindow.isOpenNow)
                          const Chip(
                            label: Text('Open now'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('What you get',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(deal.description,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.grey.shade800)),
                  if (deal.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: deal.tags
                          .map((t) => Chip(
                                label: Text(t),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        color: Colors.white,
        child: SizedBox(
          width: double.infinity,
          child: expiredState == null
              ? FilledButton.icon(
                  onPressed: controller.addToCart,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Add to bag'),
                )
              : Obx(() {
                  final expired = expiredState.value;
                  return FilledButton.icon(
                    onPressed: expired ? null : controller.addToCart,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(expired ? 'Expired' : 'Add to bag'),
                  );
                }),
        ),
      ),
      );
    });
  }
}
