import 'dart:convert';
import '../../models/goal.dart';
import '../../models/todo.dart';
import 'storage_service.dart';
import 'smart_todo_generator_service.dart';

/// Daily Todo Scheduler
///
/// Automatically generates new todos for active goals each day.
/// Tracks when todos were last generated to avoid over-generation.
class DailyTodoScheduler {
  static const _generationLogKey = 'acuis_todo_generation_log';

  final StorageService _storage;

  DailyTodoScheduler({StorageService? storage})
      : _storage = storage ?? StorageService();

  /// Check if todos need to be generated for any goal today
  /// Returns the goals that need new todos
  List<Goal> getGoalsNeedingTodos(List<Goal> goals, List<Todo> todos) {
    final today = _todayString();
    final log = _loadGenerationLog();

    return goals.where((goal) {
      // Skip non-active goals
      if (goal.status != GoalStatus.active) return false;

      // Get todos for this goal
      final goalTodos = todos.where((t) => t.goalId == goal.id).toList();
      final pendingTodos = goalTodos.where((t) => !t.completed).toList();

      // Check if we generated todos today
      final lastGenerated = log[goal.id];
      if (lastGenerated == today) {
        return false; // Already generated today
      }

      // Generate if:
      // 1. No todos yet (new goal)
      // 2. Fewer than 3 pending todos (running low)
      // 3. All existing todos are completed (need more)
      final hasNoTodos = goalTodos.isEmpty;
      final hasFewPending = pendingTodos.length < 3;
      final allCompleted = goalTodos.isNotEmpty && pendingTodos.isEmpty;

      return hasNoTodos || hasFewPending || allCompleted;
    }).toList();
  }

  /// Generate todos for goals that need them
  Future<GenerationBatchResult> generateForGoals({
    required List<Goal> goalsNeedingTodos,
    required List<Todo> allTodos,
    required String apiKey,
    int maxTodosPerGoal = 5,
  }) async {
    final results = <GoalGenerationResult>[];
    final allNewTodos = <Todo>[];

    for (final goal in goalsNeedingTodos) {
      final goalTodos = allTodos.where((t) => t.goalId == goal.id).toList();

      try {
        final aiConfig = StorageService().loadAIConfigSync();
        final service = SmartTodoGeneratorService(apiKey: apiKey, apiUrl: aiConfig.effectiveApiUrl, model: aiConfig.effectiveModel);
        final result = await service.generateTodos(
          goal: goal,
          existingTodos: goalTodos,
          maxTodos: maxTodosPerGoal,
        );

        results.add(GoalGenerationResult(
          goalId: goal.id,
          goalTitle: goal.title,
          success: true,
          todosGenerated: result.todos.length,
          phase: result.phase,
          progressAssessment: result.progressAssessment,
        ));

        allNewTodos.addAll(result.todos);

        // Mark as generated today
        _markGenerated(goal.id);
      } catch (e) {
        results.add(GoalGenerationResult(
          goalId: goal.id,
          goalTitle: goal.title,
          success: false,
          error: e.toString(),
        ));
      }
    }

    return GenerationBatchResult(
      results: results,
      newTodos: allNewTodos,
    );
  }

  /// Auto-generate todos on app launch if needed
  /// This is the main entry point for automatic generation
  Future<AutoGenerationResult> autoGenerateIfNeeded({
    required List<Goal> goals,
    required List<Todo> todos,
    required String apiKey,
    int maxTodosPerGoal = 5,
  }) async {
    final goalsNeedingTodos = getGoalsNeedingTodos(goals, todos);

    if (goalsNeedingTodos.isEmpty) {
      return AutoGenerationResult(
        generated: false,
        goalsProcessed: 0,
        newTodos: [],
        results: [],
      );
    }

    final batchResult = await generateForGoals(
      goalsNeedingTodos: goalsNeedingTodos,
      allTodos: todos,
      apiKey: apiKey,
      maxTodosPerGoal: maxTodosPerGoal,
    );

    return AutoGenerationResult(
      generated: true,
      goalsProcessed: goalsNeedingTodos.length,
      newTodos: batchResult.newTodos,
      results: batchResult.results,
    );
  }

  /// Generate todos immediately for a newly created goal
  Future<GoalGenerationResult> generateForNewGoal({
    required Goal goal,
    required String apiKey,
    int maxTodos = 5,
  }) async {
    try {
      final service = SmartTodoGeneratorService(apiKey: apiKey);
      final result = await service.generateTodos(
        goal: goal,
        existingTodos: [], // New goal, no existing todos
        maxTodos: maxTodos,
      );

      // Mark as generated today
      _markGenerated(goal.id);

      return GoalGenerationResult(
        goalId: goal.id,
        goalTitle: goal.title,
        success: true,
        todosGenerated: result.todos.length,
        phase: result.phase,
        progressAssessment: result.progressAssessment,
        generatedTodos: result.todos,
      );
    } catch (e) {
      return GoalGenerationResult(
        goalId: goal.id,
        goalTitle: goal.title,
        success: false,
        error: e.toString(),
      );
    }
  }

  // --- Storage helpers ---

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Map<String, String> _loadGenerationLog() {
    final raw = _storage.getString(_generationLogKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  void _markGenerated(String goalId) {
    final log = _loadGenerationLog();
    log[goalId] = _todayString();
    _storage.setString(_generationLogKey, jsonEncode(log));
  }

  /// Clear generation log (for testing or reset)
  Future<void> clearLog() async {
    await _storage.remove(_generationLogKey);
  }
}

// --- Result classes ---

class AutoGenerationResult {
  final bool generated;
  final int goalsProcessed;
  final List<Todo> newTodos;
  final List<GoalGenerationResult> results;

  const AutoGenerationResult({
    required this.generated,
    required this.goalsProcessed,
    required this.newTodos,
    required this.results,
  });
}

class GenerationBatchResult {
  final List<GoalGenerationResult> results;
  final List<Todo> newTodos;

  const GenerationBatchResult({
    required this.results,
    required this.newTodos,
  });
}

class GoalGenerationResult {
  final String goalId;
  final String goalTitle;
  final bool success;
  final int todosGenerated;
  final String? phase;
  final String? progressAssessment;
  final String? error;
  final List<Todo> generatedTodos;

  const GoalGenerationResult({
    required this.goalId,
    required this.goalTitle,
    required this.success,
    this.todosGenerated = 0,
    this.phase,
    this.progressAssessment,
    this.error,
    this.generatedTodos = const [],
  });
}
