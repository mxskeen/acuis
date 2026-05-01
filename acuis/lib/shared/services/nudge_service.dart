import 'package:flutter/foundation.dart';
import '../../models/user_energy.dart';
import 'mood_check_service.dart';

/// Nudge Service
///
/// Manages contextual nudges and badges to prompt users at the right moment.
/// Implements BJ Fogg's behavior model: Trigger at the right moment.
///
/// ADHD-Friendly: Respects user's energy level and mood for nudge tone/content.
class NudgeService extends ChangeNotifier {
  int _unanalyzedTodosCount = 0;
  bool _streakAtRisk = false;
  String? _morningNudgeMessage;
  String? _eveningNudgeMessage;
  MoodCheckService? _moodService;

  // Energy-aware properties
  bool _isSickDay = false;
  EnergyLevel _currentEnergy = EnergyLevel.medium;
  MoodTag? _currentMood;

  /// Get count of unanalyzed todos (for badge display)
  int get unanalyzedTodosCount => _unanalyzedTodosCount;

  /// Check if streak is at risk today
  bool get streakAtRisk => _streakAtRisk;

  /// Get morning nudge message (if applicable)
  String? get morningNudgeMessage => _morningNudgeMessage;

  /// Get evening nudge message (if applicable)
  String? get eveningNudgeMessage => _eveningNudgeMessage;

  /// Current energy level from mood check
  EnergyLevel get currentEnergy => _currentEnergy;

  /// Current mood from mood check
  MoodTag? get currentMood => _currentMood;

  /// Whether today is marked as sick day
  bool get isSickDay => _isSickDay;

  /// Whether nudges should be suppressed
  bool get shouldSuppressNudges => _isSickDay || _currentEnergy == EnergyLevel.low;

  /// Set mood service (call after initialization)
  void setMoodService(MoodCheckService service) {
    _moodService = service;
    _refreshEnergyState();
  }

  /// Refresh energy state from mood service
  void _refreshEnergyState() {
    if (_moodService == null) return;

    final energy = _moodService!.getTodaysEnergy();
    if (energy != null) {
      _currentEnergy = energy.level;
      _currentMood = energy.mood;
      _isSickDay = energy.mood == MoodTag.sick;
    }
  }

  /// Update nudges based on energy and time
  void updateNudges({
    int todoCount = 0,
    int completedToday = 0,
  }) {
    _refreshEnergyState();

    if (shouldSuppressNudges) {
      _generateSupportiveNudge();
    } else {
      updateTimeBasedNudges(todoCount, completedToday);
    }

    notifyListeners();
  }

  /// Generate supportive nudge for low energy/sick days
  void _generateSupportiveNudge() {
    if (_isSickDay) {
      _morningNudgeMessage = 'Rest is productive too. Take care!';
      _eveningNudgeMessage = null;
    } else if (_currentEnergy == EnergyLevel.low) {
      _morningNudgeMessage = 'Low energy day? Even 5 minutes counts!';
      _eveningNudgeMessage = _morningNudgeMessage != null
          ? 'Nice work today despite low energy!'
          : 'No pressure today. Rest is ok too.';
    }
  }

  /// Update unanalyzed todos count
  void updateUnanalyzedCount(int count) {
    if (_unanalyzedTodosCount != count) {
      _unanalyzedTodosCount = count;
      notifyListeners();
    }
  }

  /// Check if streak is at risk (no completed todos today)
  /// Now generates supportive messages instead of anxiety-inducing warnings
  void checkStreakRisk(bool atRisk, int currentStreak) {
    if (_streakAtRisk != atRisk) {
      _streakAtRisk = atRisk;
      if (atRisk && currentStreak >= 3) {
        // Generate supportive streak message
        _streakSupportMessage = currentStreak >= 7
            ? '$currentStreak-day streak! Take it easy today if you need to.'
            : '$currentStreak days so far! Even a tiny task keeps the momentum.';
      } else {
        _streakSupportMessage = null;
      }
      notifyListeners();
    }
  }

  /// Supportive streak message (replaces anxiety-inducing warning text)
  String? _streakSupportMessage;

  String? get streakSupportMessage => _streakSupportMessage;

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
