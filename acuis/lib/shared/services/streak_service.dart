import 'package:shared_preferences/shared_preferences.dart';

/// Streak Service
///
/// Manages user streaks with ADHD-friendly features:
/// - Grace days (2 per month) for unavoidable breaks
/// - Sick day protection (streak frozen, not broken)
/// - Graceful decay instead of hard reset
class StreakService {
  // Core streak keys
  static const _lastCompletionKey = 'last_completion_date';
  static const _currentStreakKey = 'current_streak';
  static const _longestStreakKey = 'longest_streak';
  static const _completionDatesKey = 'completion_dates';

  // ADHD-friendly shield keys
  static const _graceDaysKey = 'grace_days_remaining';
  static const _graceDaysResetKey = 'grace_days_reset';
  static const _sickDaysKey = 'sick_days_used';
  static const _frozenStreakKey = 'frozen_streak_value';
  static const _sickDayDateKey = 'sick_day_date';
  static const _streakShieldUsedKey = 'streak_shield_used';

  // Configuration
  static const int _graceDaysPerMonth = 2;
  static const double _streakDecayRate = 0.5; // Lose 50% instead of 100%
  static const int _minStreakAfterDecay = 1; // Never fully zero

  final SharedPreferences _prefs;

  StreakService(this._prefs);

  static Future<StreakService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StreakService(prefs);
  }

  // ── Core Getters ──────────────────────────────────────────

  int getCurrentStreak() => _prefs.getInt(_currentStreakKey) ?? 0;
  int getLongestStreak() => _prefs.getInt(_longestStreakKey) ?? 0;
  String? getLastCompletionDate() => _prefs.getString(_lastCompletionKey);

  /// Returns a set of date strings (yyyy-MM-dd) on which todos were completed.
  Set<String> getCompletionDates() {
    final list = _prefs.getStringList(_completionDatesKey) ?? [];
    return list.toSet();
  }

  // ── Shield/Grace Day Getters ──────────────────────────────

  /// Get remaining grace days (2 per month, reset on 1st)
  int getGraceDaysRemaining() {
    _maybeResetGraceDays();
    return _prefs.getInt(_graceDaysKey) ?? _graceDaysPerMonth;
  }

  /// Check if streak is currently frozen (sick day protection)
  bool get isStreakFrozen => getFrozenStreakValue() != null;

  /// Get frozen streak value (if sick day was marked)
  int? getFrozenStreakValue() {
    final frozen = _prefs.getInt(_frozenStreakKey);
    if (frozen == null) return null;

    // Check if sick day was today - if so, streak is frozen
    final sickDayDate = _prefs.getString(_sickDayDateKey);
    if (sickDayDate == null) return null;

    final today = _getTodayString();
    if (sickDayDate == today) return frozen;

    // Sick day was yesterday or earlier - unfreeze
    return null;
  }

  /// Check if a streak shield was used to preserve today's streak
  bool get wasStreakShieldUsedToday {
    final usedDate = _prefs.getString(_streakShieldUsedKey);
    return usedDate == _getTodayString();
  }

  /// Get sick days used this month
  int getSickDaysUsedThisMonth() {
    _maybeResetGraceDays(); // Sick days reset with grace days
    return _prefs.getInt(_sickDaysKey) ?? 0;
  }

  // ── Streak Recording ──────────────────────────────────────

  Future<void> _addCompletionDate(String date) async {
    final dates = getCompletionDates();
    dates.add(date);
    await _prefs.setStringList(_completionDatesKey, dates.toList());
  }

  Future<void> recordCompletion() async {
    final today = _getTodayString();
    final lastDate = getLastCompletionDate();

    if (lastDate == today) {
      // Already recorded today
      return;
    }

    int currentStreak = getCurrentStreak();

    // Check if streak was frozen (sick day protection)
    final frozenValue = getFrozenStreakValue();
    if (frozenValue != null && lastDate != null) {
      final sickDay = _prefs.getString(_sickDayDateKey)!;
      final lastDateTime = DateTime.parse(lastDate);
      final sickDayTime = DateTime.parse(sickDay);
      final todayTime = DateTime.parse(today);

      // If completing on the day after sick day, restore frozen streak
      if (todayTime.difference(sickDayTime).inDays == 1) {
        currentStreak = frozenValue;
      } else if (lastDateTime.difference(sickDayTime).inDays > 0) {
        // Continuing after sick day gap
        final lastTime = DateTime.parse(lastDate);
        final diff = todayTime.difference(lastTime).inDays;
        if (diff == 1) {
          currentStreak++;
        } else {
          currentStreak = 1;
        }
      }
    } else if (lastDate == null) {
      // First time
      currentStreak = 1;
    } else {
      final lastDateTime = DateTime.parse(lastDate);
      final todayDateTime = DateTime.parse(today);
      final difference = todayDateTime.difference(lastDateTime).inDays;

      if (difference == 1) {
        // Consecutive day
        currentStreak++;
      } else if (difference > 1) {
        // Gap detected - check grace days first
        currentStreak = await _handleStreakGap(currentStreak, difference);
      }
    }

    // Clear any frozen streak since we're completing today
    await _prefs.remove(_frozenStreakKey);
    await _prefs.remove(_sickDayDateKey);
    await _prefs.remove(_streakShieldUsedKey);

    await _prefs.setString(_lastCompletionKey, today);
    await _prefs.setInt(_currentStreakKey, currentStreak);
    await _addCompletionDate(today);

    // Update longest streak if needed
    final longestStreak = getLongestStreak();
    if (currentStreak > longestStreak) {
      await _prefs.setInt(_longestStreakKey, currentStreak);
    }
  }

  /// Handle a streak gap with grace days or decay
  Future<int> _handleStreakGap(int currentStreak, int gapDays) async {
    final graceDays = getGraceDaysRemaining();

    if (graceDays > 0) {
      // Use a grace day to preserve streak
      await _useGraceDay();
      await _prefs.setString(_streakShieldUsedKey, _getTodayString());
      return currentStreak;
    }

    // No grace days left - apply graceful decay
    final decayedStreak = (currentStreak * _streakDecayRate).floor();
    return decayedStreak < _minStreakAfterDecay
        ? _minStreakAfterDecay
        : decayedStreak;
  }

  // ── Shield Methods ─────────────────────────────────────────

  /// Use one grace day
  Future<void> _useGraceDay() async {
    final current = getGraceDaysRemaining();
    if (current > 0) {
      await _prefs.setInt(_graceDaysKey, current - 1);
    }
  }

  /// Mark today as a sick day - streak is frozen, not broken
  Future<void> markSickDay() async {
    final currentStreak = getCurrentStreak();
    await _prefs.setInt(_frozenStreakKey, currentStreak);
    await _prefs.setString(_sickDayDateKey, _getTodayString());

    final sickDaysUsed = getSickDaysUsedThisMonth();
    await _prefs.setInt(_sickDaysKey, sickDaysUsed + 1);
  }

  /// Reset streak to zero (rare - only if explicitly abandoning)
  Future<void> resetStreak() async {
    await _prefs.setInt(_currentStreakKey, 0);
    await _prefs.remove(_frozenStreakKey);
    await _prefs.remove(_sickDayDateKey);
  }

  // ── Grace Day Management ──────────────────────────────────

  void _maybeResetGraceDays() {
    final lastReset = _prefs.getString(_graceDaysResetKey);
    final now = DateTime.now();
    final thisMonth = '${now.year}-${now.month}';

    if (lastReset != thisMonth) {
      _prefs.setInt(_graceDaysKey, _graceDaysPerMonth);
      _prefs.setInt(_sickDaysKey, 0); // Also reset sick days
      _prefs.setString(_graceDaysResetKey, thisMonth);
    }
  }

  // ── Legacy Compatibility ───────────────────────────────────

  /// Check and update streak status (called on app startup)
  /// Now includes grace day and decay logic
  Future<void> checkAndUpdateStreak() async {
    final lastDate = getLastCompletionDate();
    if (lastDate == null) return;

    final today = _getTodayString();
    final lastDateTime = DateTime.parse(lastDate);
    final todayDateTime = DateTime.parse(today);
    final difference = todayDateTime.difference(lastDateTime).inDays;

    if (difference > 1) {
      // Gap detected but not yet handled
      final currentStreak = getCurrentStreak();

      // Check if we auto-applied grace days already
      final didUseShield = wasStreakShieldUsedToday ||
          (getGraceDaysRemaining() < _graceDaysPerMonth &&
              difference == 2 &&
              _prefs.getStringList(_completionDatesKey)?.contains(today) == false);

      if (!didUseShield) {
        // Apply decay
        final newStreak = (currentStreak * _streakDecayRate).floor();
        final finalStreak =
            newStreak < _minStreakAfterDecay ? _minStreakAfterDecay : newStreak;
        await _prefs.setInt(_currentStreakKey, finalStreak);
      }
    }
  }

  // ── Helper Methods ─────────────────────────────────────────

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get streak status for UI display
  StreakStatus getStreakStatus() {
    final lastDate = getLastCompletionDate();
    if (lastDate == null) return StreakStatus.inactive;

    final today = _getTodayString();
    if (lastDate == today) return StreakStatus.active;

    final yesterdayDate = DateTime.now().subtract(const Duration(days: 1));
    final yesterday =
        '${yesterdayDate.year}-${yesterdayDate.month.toString().padLeft(2, '0')}-${yesterdayDate.day.toString().padLeft(2, '0')}';
    if (lastDate == yesterday) return StreakStatus.atRisk;

    if (isStreakFrozen) return StreakStatus.frozen;

    return StreakStatus.broken;
  }
}

/// Streak status for UI indicators
enum StreakStatus {
  inactive, // No streak yet
  active, // Completed today
  atRisk, // Completed yesterday (due today)
  frozen, // Sick day protection
  broken, // Gap with no protection
  shielded, // Grace day used
}

/// Streak event for tracking
class StreakEvent {
  final String type; // 'completion', 'grace_used', 'sick_day', 'decay'
  final int streakBefore;
  final int streakAfter;
  final DateTime timestamp;

  StreakEvent({
    required this.type,
    required this.streakBefore,
    required this.streakAfter,
    required this.timestamp,
  });
}
