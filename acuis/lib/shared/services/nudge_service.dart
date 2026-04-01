import 'package:flutter/foundation.dart';

/// Nudge Service
///
/// Manages contextual nudges and badges to prompt users at the right moment.
/// Implements BJ Fogg's behavior model: Trigger at the right moment.
class NudgeService extends ChangeNotifier {
  int _unanalyzedTodosCount = 0;
  bool _streakAtRisk = false;
  String? _morningNudgeMessage;
  String? _eveningNudgeMessage;

  /// Get count of unanalyzed todos (for badge display)
  int get unanalyzedTodosCount => _unanalyzedTodosCount;

  /// Check if streak is at risk today
  bool get streakAtRisk => _streakAtRisk;

  /// Get morning nudge message (if applicable)
  String? get morningNudgeMessage => _morningNudgeMessage;

  /// Get evening nudge message (if applicable)
  String? get eveningNudgeMessage => _eveningNudgeMessage;

  /// Update unanalyzed todos count
  void updateUnanalyzedCount(int count) {
    if (_unanalyzedTodosCount != count) {
      _unanalyzedTodosCount = count;
      notifyListeners();
    }
  }

  /// Check if streak is at risk (no completed todos today)
  void checkStreakRisk(bool atRisk, int currentStreak) {
    if (_streakAtRisk != atRisk) {
      _streakAtRisk = atRisk;
      notifyListeners();
    }
  }

  /// Generate contextual nudge messages based on time of day
  void updateTimeBasedNudges(int todoCount, int completedToday) {
    final hour = DateTime.now().hour;

    // Morning nudge (6am - 11am)
    if (hour >= 6 && hour < 11) {
      if (todoCount > 0) {
        _morningNudgeMessage = 'Plan your day - $todoCount high-impact todos ready';
      } else {
        _morningNudgeMessage = null;
      }
    } else {
      _morningNudgeMessage = null;
    }

    // Evening nudge (6pm - 10pm)
    if (hour >= 18 && hour < 22) {
      if (completedToday > 0) {
        _eveningNudgeMessage = 'Reflect on today - mark completed todos';
      } else {
        _eveningNudgeMessage = null;
      }
    } else {
      _eveningNudgeMessage = null;
    }

    notifyListeners();
  }

  /// Clear all nudges
  void clearNudges() {
    _morningNudgeMessage = null;
    _eveningNudgeMessage = null;
    notifyListeners();
  }
}
