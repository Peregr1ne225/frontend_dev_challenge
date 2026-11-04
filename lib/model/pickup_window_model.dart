import 'package:intl/intl.dart';

/// A store's pickup window. The API sends instants as ISO-8601 UTC strings.
class PickupWindowModel {
  final DateTime start;
  final DateTime end;

  const PickupWindowModel({required this.start, required this.end});

  factory PickupWindowModel.fromJson(Map<String, dynamic> json) {
    return PickupWindowModel(
      start: DateTime.parse(json['start'] as String? ?? '').toLocal(),
      end: DateTime.parse(json['end'] as String? ?? '').toLocal(),
    );
  }

  /// Human readable label, e.g. "17:30 – 21:00".
  String get label =>
      '${DateFormat('HH:mm').format(start.toLocal())} – '
      '${DateFormat('HH:mm').format(end.toLocal())}';

  /// Whether this pickup window overlaps the user's local calendar day.
  bool get isToday {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final localStart = start.toLocal();
    final localEnd = end.toLocal();

    return localStart.isBefore(tomorrowStart) &&
        localEnd.isAfter(todayStart);
  }

  /// Whether the store is currently accepting pickups.
  bool get isOpenNow {
    final now = DateTime.now();
    return now.isAfter(start.toLocal()) && now.isBefore(end.toLocal());
  }

  Duration get untilStart => start.toLocal().difference(DateTime.now());
}
