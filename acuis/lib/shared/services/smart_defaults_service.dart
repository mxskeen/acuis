import '../../models/todo.dart';
import '../../models/goal.dart';

/// Smart Defaults Service
///
/// Provides intelligent defaults for todo creation based on historical data
class SmartDefaultsService {
  /// Get the most active goal (goal with most todos)
  static String? getMostActiveGoal(List<Goal> goals, List<Todo> todos) {
    if (goals.isEmpty) return null;

    final goalTodoCounts = <String, int>{};
    for (final goal in goals) {
      goalTodoCounts[goal.id] = todos.where((t) => t.goalId == goal.id).length;
    }

    if (goalTodoCounts.isEmpty) return goals.first.id;

    return goalTodoCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Get the most recently used goal
  static String? getMostRecentGoal(List<Goal> goals, List<Todo> todos) {
    if (goals.isEmpty || todos.isEmpty) return goals.isNotEmpty ? goals.first.id : null;

    final linkedTodos = todos.where((t) => t.goalId != null).toList();
    if (linkedTodos.isEmpty) return goals.first.id;

    linkedTodos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return linkedTodos.first.goalId;
  }

  /// Predict estimated effort based on similar completed todos
  /// Returns effort level (1-5) or null if no data
  static int? predictEffort(String todoTitle, List<Todo> completedTodos) {
    if (completedTodos.isEmpty) return null;

    // Simple heuristic: look for similar keywords
    final titleWords = todoTitle.toLowerCase().split(' ');
    final similarTodos = <Todo>[];

    for (final todo in completedTodos) {
      if (todo.estimatedEffort == null) continue;

      final todoWords = todo.title.toLowerCase().split(' ');
      final commonWords = titleWords.where((w) => todoWords.contains(w)).length;

      if (commonWords >= 2) {
        similarTodos.add(todo);
      }
    }

    if (similarTodos.isEmpty) {
      // Fallback: return average effort of all completed todos
      final todosWithEffort = completedTodos.where((t) => t.estimatedEffort != null).toList();
      if (todosWithEffort.isEmpty) return null;

      final avgEffort = todosWithEffort
          .map((t) => t.estimatedEffort!)
          .reduce((a, b) => a + b) / todosWithEffort.length;
      return avgEffort.round();
    }

    // Return average effort of similar todos
    final avgEffort = similarTodos
        .map((t) => t.estimatedEffort!)
        .reduce((a, b) => a + b) / similarTodos.length;
    return avgEffort.round();
  }

  /// Get smart goal suggestion based on context
  /// Prioritizes: 1) Most recent, 2) Most active, 3) First goal
  static String? getSmartGoalSuggestion(List<Goal> goals, List<Todo> todos) {
    final recentGoal = getMostRecentGoal(goals, todos);
    if (recentGoal != null) return recentGoal;

    final activeGoal = getMostActiveGoal(goals, todos);
    if (activeGoal != null) return activeGoal;

    return goals.isNotEmpty ? goals.first.id : null;
  }
}
