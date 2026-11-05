import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Calls [onImpression] after the wrapped deal card stays at least 50% visible
/// for one uninterrupted second.
///
/// This widget only observes visibility; it does not rebuild the child as the
/// visible fraction changes.
class DealImpressionTracker extends StatefulWidget {
  final Widget child;
  final VoidCallback onImpression;

  const DealImpressionTracker({
    super.key,
    required this.child,
    required this.onImpression,
  });

  @override
  State<DealImpressionTracker> createState() => _DealImpressionTrackerState();
}

class _DealImpressionTrackerState extends State<DealImpressionTracker> {
  static const _minimumVisibleFraction = 0.5;
  static const _requiredVisibleDuration = Duration(seconds: 1);

  final Key _visibilityKey = UniqueKey();
  Timer? _dwellTimer;
  bool _isVisibleEnough = false;
  bool _reportedForCurrentVisibility = false;

  void _onVisibilityChanged(VisibilityInfo info) {
    final isVisibleEnough =
        info.visibleFraction >= _minimumVisibleFraction;

    if (!isVisibleEnough) {
      _dwellTimer?.cancel();
      _dwellTimer = null;
      _isVisibleEnough = false;
      _reportedForCurrentVisibility = false;
      return;
    }

    _isVisibleEnough = true;
    if (_reportedForCurrentVisibility || _dwellTimer != null) return;

    _dwellTimer = Timer(_requiredVisibleDuration, () {
      _dwellTimer = null;
      if (!mounted || !_isVisibleEnough || _reportedForCurrentVisibility) {
        return;
      }

      _reportedForCurrentVisibility = true;
      widget.onImpression();
    });
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    super.dispose();
  }
}
