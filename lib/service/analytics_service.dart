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

  /// Records a qualifying impression once per deal for this app session.
  ///
  /// [source] must identify the list containing the card, and [position] is
  /// its zero-based index in that list.
  bool logDealImpression({
    required int dealId,
    required String source,
    required int position,
  }) {
    const validSources = {'home_feed', 'flash_rail', 'search'};
    if (!validSources.contains(source)) {
      throw ArgumentError.value(source, 'source', 'Unsupported impression source');
    }

    if (!markDealImpression(dealId)) return false;

    logEvent('deal_impression', {
      'deal_id': dealId,
      'source': source,
      'position': position,
    });
    return true;
  }

  void logEvent(String name, [Map<String, dynamic> properties = const {}]) {
    final event = AnalyticsEvent(name, properties);
    events.add(event);
    LogService.log('analytics: $name $properties');
  }
}
