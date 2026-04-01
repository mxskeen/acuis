import '../../models/todo.dart';
import '../../models/goal.dart';

/// Recommendation Engine
///
/// Provides predictive recommendations based on velocity, alignment, and patterns
class RecommendationEngine {
  /// Get top 3 todos to focus on today based on alignment and velocity
  static List<Todo> getTopRecommendations(
    List<Todo> todos,
    List<Goal> goals, {
    int limit = 3,
  }) {
    // Filter: incomplete, linked todos with alignment scores
    final candidates = todos.where((t) =>
      !t.completed &&
      t.goalId != null &&
      t.alignmentScore != null
    ).toList();

    if (candidates.isEmpty) return [];

    // Sort by alignment score (descending)
    candidates.sort((a, b) => (b.alignmentScore ?? 0).compareTo(a.alignmentScore ?? 0));

    return candidates.take(limit).toList();
  }

  /// Identify patterns like "alignment drops on Fridays"
  static String? identifyWeekdayPattern(List<Todo> todos) {
    if (todos.length < 10) return null;

    final dayScores = <int, List<double>>{
      1: [], // Monday
      2: [], // Tuesday
      3: [], // Wednesday
      4: [], // Thursday
      5: [], // Friday
      6: [], // Saturday
      7: [], // Sunday
    };

    // Collect alignment scores by day of week
    for (final todo in todos.where((t) => t.alignmentScore != null)) {
      final dayOfWeek = todo.createdAt.weekday;
      dayScores[dayOfWeek]?.add(todo.alignmentScore!);
    }

    // Calculate average scores per day
    final dayAverages = <int, double>{};
    for (final entry in dayScores.entries) {
      if (entry.value.isNotEmpty) {
        dayAverages[entry.key] = entry.value.reduce((a, b) => a + b) / entry.value.length;
      }
    }

    if (dayAverages.length < 3) return null;

    // Find lowest scoring day
    final lowestDay = dayAverages.entries.reduce((a, b) => a.value < b.value ? a : b);
    final avgScore = dayAverages.values.reduce((a, b) => a + b) / dayAverages.length;

    // If lowest day is significantly below average (>15 points)
    if (avgScore - lowestDay.value > 15) {
      final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return 'Your alignment drops on ${dayNames[lowestDay.key]}s - schedule easier tasks then';
    }

    return null;
  }

  /// Get personalized recommendation message based on current state
  static String? getPersonalizedRecommendation(
    List<Todo> todos,
    List<Goal> goals,
    int currentStreak,
  ) {
    final now = DateTime.now();
    final hour = now.hour;

    // Morning recommendations (6am - 11am)
    if (hour >= 6 && hour < 11) {
      final topTodos = getTopRecommendations(todos, goals, limit: 3);
      if (topTodos.isNotEmpty) {
        return 'Start with "${topTodos.first.title}" - it\'s your highest-impact task today';
      }
    }

    // Afternoon check (2pm - 5pm)
    if (hour >= 14 && hour < 17) {
      final completedToday = todos.where((t) {
        return t.completed &&
               t.createdAt.year == now.year &&
               t.createdAt.month == now.month &&
               t.createdAt.day == now.day;
      }).length;

      if (completedToday == 0 && currentStreak > 0) {
        return 'Complete 1 task to maintain your $currentStreak-day streak';
      }
    }

    // Evening reflection (6pm - 10pm)
    if (hour >= 18 && hour < 22) {
      final incompleteTodos = todos.where((t) => !t.completed && t.goalId != null).length;
      if (incompleteTodos > 0) {
        return 'Review your progress and plan tomorrow\'s priorities';
      }
    }

    return null;
  }

  /// Suggest easier tasks for low-energy periods
  static List<Todo> getEasyTasksForLowEnergy(List<Todo> todos) {
    // Filter: incomplete, low effort (1-2), high alignment
    final easyTasks = todos.where((t) =>
      !t.completed &&
      t.goalId != null &&
      (t.estimatedEffort ?? 3) <= 2 &&
      (t.alignmentScore ?? 0) >= 60
    ).toList();

    // Sort by alignment
    easyTasks.sort((a, b) => (b.alignmentScore ?? 0).compareTo(a.alignmentScore ?? 0));

    return easyTasks.take(3).toList();
  }

  /// Get velocity-based recommendation
  static String? getVelocityRecommendation(
    double currentVelocity,
    double previousVelocity,
  ) {
    if (previousVelocity == 0) return null;

    final percentChange = ((currentVelocity - previousVelocity) / previousVelocity) * 100;

    if (percentChange > 20) {
      return 'You\'re on fire! 🔥 Keep this momentum going';
    } else if (percentChange < -20) {
      return 'Velocity is down. Focus on quick wins to rebuild momentum';
    }

    return null;
  }
}
