import 'dart:async';
import 'package:flutter/foundation.dart';

/// Alignment Refresh Service
///
/// Manages automatic refresh triggers for alignment analysis:
/// - Triggers refresh when todos are added/changed/deleted
/// - Provides periodic background refresh
/// - Debounces rapid changes to avoid excessive API calls
class AlignmentRefreshService extends ChangeNotifier {
  /// Minimum time between auto-refreshes (debounce)
  static const _minRefreshInterval = Duration(seconds: 3);

  /// Interval for periodic background refresh (when enabled)
  static const _periodicRefreshInterval = Duration(minutes: 30);

  DateTime? _lastRefreshTime;
  Timer? _debounceTimer;
  Timer? _periodicTimer;
  int _refreshVersion = 0;
  bool _periodicRefreshEnabled = true;

  /// Get the current refresh version (incremented on each refresh)
  int get refreshVersion => _refreshVersion;

  /// Check if periodic refresh is enabled
  bool get periodicRefreshEnabled => _periodicRefreshEnabled;

  /// Toggle periodic refresh
  set periodicRefreshEnabled(bool value) {
    if (_periodicRefreshEnabled != value) {
      _periodicRefreshEnabled = value;
      if (value) {
        _startPeriodicTimer();
      } else {
        _stopPeriodicTimer();
      }
    }
  }

  /// Call this when todos are added, modified, or deleted
  void onTodosChanged() {
    // Debounce rapid changes
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_minRefreshInterval, () {
      _triggerRefresh();
    });
  }

  /// Call this when goals are added, modified, or deleted
  void onGoalsChanged() {
    // Goals changes are less frequent, refresh immediately
    _triggerRefresh();
  }

  /// Manually trigger a refresh
  void manualRefresh() {
    _triggerRefresh();
  }

  /// Called when user navigates to the alignment screen
  void onScreenVisible() {
    // Check if we should refresh based on time since last refresh
    if (_shouldRefresh()) {
      _triggerRefresh();
    }

    // Start periodic timer if enabled
    if (_periodicRefreshEnabled) {
      _startPeriodicTimer();
    }
  }

  /// Called when user navigates away from alignment screen
  void onScreenHidden() {
    _stopPeriodicTimer();
  }

  bool _shouldRefresh() {
    if (_lastRefreshTime == null) return true;

    final now = DateTime.now();
    final elapsed = now.difference(_lastRefreshTime!);
    return elapsed >= _minRefreshInterval;
  }

  void _triggerRefresh() {
    _lastRefreshTime = DateTime.now();
    _refreshVersion++;
    notifyListeners();
  }

  void _startPeriodicTimer() {
    _stopPeriodicTimer();

    _periodicTimer = Timer.periodic(_periodicRefreshInterval, (_) {
      if (_periodicRefreshEnabled) {
        _triggerRefresh();
      }
    });
  }

  void _stopPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _stopPeriodicTimer();
    super.dispose();
  }
}
