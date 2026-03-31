import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  static const _lastCompletionKey = 'last_completion_date';
  static const _currentStreakKey = 'current_streak';
  static const _longestStreakKey = 'longest_streak';

  final SharedPreferences _prefs;

  StreakService(this._prefs);

  static Future<StreakService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StreakService(prefs);
  }

  int getCurrentStreak() => _prefs.getInt(_currentStreakKey) ?? 0;
  int getLongestStreak() => _prefs.getInt(_longestStreakKey) ?? 0;
  String? getLastCompletionDate() => _prefs.getString(_lastCompletionKey);

  Future<void> recordCompletion() async {
    final today = _getTodayString();
    final lastDate = getLastCompletionDate();
    
    if (lastDate == today) {
      // Already recorded today
      return;
    }

    int currentStreak = getCurrentStreak();
    
    if (lastDate == null) {
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
        // Streak broken
        currentStreak = 1;
      }
    }

    await _prefs.setString(_lastCompletionKey, today);
    await _prefs.setInt(_currentStreakKey, currentStreak);
    
    // Update longest streak if needed
    final longestStreak = getLongestStreak();
    if (currentStreak > longestStreak) {
      await _prefs.setInt(_longestStreakKey, currentStreak);
    }
  }

  Future<void> checkAndUpdateStreak() async {
    final lastDate = getLastCompletionDate();
    if (lastDate == null) return;

    final today = _getTodayString();
    final lastDateTime = DateTime.parse(lastDate);
    final todayDateTime = DateTime.parse(today);
    final difference = todayDateTime.difference(lastDateTime).inDays;

    if (difference > 1) {
      // Streak broken, reset
      await _prefs.setInt(_currentStreakKey, 0);
    }
  }

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
