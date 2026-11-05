import 'package:get/get.dart';

import '../util/log_service.dart';

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime at;

  AnalyticsEvent(this.name, this.properties) : at = DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'properties': properties,
        'at': at.toIso8601String(),
      };
}

/// In-memory analytics sink. Events are visible on the debug screen
/// (overflow menu on Home -> "Analytics debug") and in the console.
///
/// The "Impression tracking" feature task builds on top of this service.
class AnalyticsService extends GetxService {
  final events = <AnalyticsEvent>[].obs;

  // Retained for the lifetime of this GetX service, so impressions are
  // deduplicated across screens during the app session.
  final Set<int> _impressedDealIds = <int>{};

  /// Marks [dealId] as impressed for this app session.
  ///
  /// Returns true only the first time the deal is accepted. Call this after
  /// the visibility and dwell-time requirements have been met.
  bool markDealImpression(int dealId) => _impressedDealIds.add(dealId);

  void logEvent(String name, [Map<String, dynamic> properties = const {}]) {
    final event = AnalyticsEvent(name, properties);
    events.add(event);
    LogService.log('analytics: $name $properties');
  }
}
