import '../../models/goal.dart';
import '../../models/todo.dart';
import '../../models/alignment_result.dart';
import '../../models/smart_scores.dart';
import 'scoring/alignment_scorer.dart';

/// AI Alignment Service
///
/// Main service for AI-powered goal-task alignment analysis.
/// Uses the science-backed AlignmentScorer for comprehensive analysis.
class AIAlignmentService {
  static const _defaultUrl = ''; // Always pass apiUrl from AIConfig
  static const _defaultModel = 'mistralai/mistral-small-4-119b-2603';

  final String apiKey;
  final String apiUrl;
  final String model;
  late final AlignmentScorer _scorer;

  AIAlignmentService({
    required this.apiKey,
    this.apiUrl = _defaultUrl,
    this.model = _defaultModel,
  }) {
    _scorer = AlignmentScorer(
      apiKey: apiKey,
      apiUrl: apiUrl,
      model: model,
    );
  }

  /// Analyze alignment for a single todo-goal pair
  Future<AlignmentResult> analyzeAlignment(
    Todo todo,
    Goal goal, {
    ScoringContext? context,
  }) async {
    return _scorer.analyze(
      todo,
      goal,
      context ?? ScoringContext.empty(),
    );
  }

  /// Batch-analyze all linked todo-goal pairs
  Future<Map<String, AlignmentResult>> analyzeAll(
    List<Todo> todos,
    List<Goal> goals, {
    ScoringContext? context,
  }) async {
    final goalMap = {for (var g in goals) g.id: g};
    final results = <String, AlignmentResult>{};
    final ctx = context ?? ScoringContext.empty();

    for (final todo in todos) {
      if (todo.goalId != null && goalMap.containsKey(todo.goalId)) {
        results[todo.id] = await analyzeAlignment(
          todo,
          goalMap[todo.goalId]!,
          context: ctx,
        );
        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    return results;
  }

  /// Calculate overall alignment as average score of analyzed todos
  double calculateOverallScore(Map<String, AlignmentResult> results) {
    if (results.isEmpty) return 0;
    final valid = results.values.where((r) => r.score >= 0);
    if (valid.isEmpty) return 0;
    return valid.map((r) => r.score).reduce((a, b) => a + b) / valid.length;
  }

  /// Get alignment statistics for a goal
  AlignmentStats getStatsForGoal(Goal goal, List<Todo> todos) {
    final goalTodos = todos.where((t) => t.goalId == goal.id).toList();
    final completed = goalTodos.where((t) => t.completed).length;

    final scoredTodos = goalTodos.where((t) => t.alignmentScore != null).toList();
    double avgScore = 0;
    if (scoredTodos.isNotEmpty) {
      avgScore = scoredTodos.map((t) => t.alignmentScore!).reduce((a, b) => a + b) / scoredTodos.length;
    }

    // Count by Eisenhower class
    final eisenhowerCounts = <EisenhowerClass, int>{
      for (final e in EisenhowerClass.values) e: 0
    };

    for (final todo in goalTodos) {
      final eClass = todo.effectiveEisenhowerClass;
      eisenhowerCounts[eClass] = eisenhowerCounts[eClass]! + 1;
    }

    // Average SMART scores
    SMARTScores? avgSMART;
    final todosWithSMART = goalTodos.where((t) => t.smartScores != null).toList();
    if (todosWithSMART.isNotEmpty) {
      avgSMART = SMARTScores(
        specificity: todosWithSMART.map((t) => t.smartScores!.specificity).reduce((a, b) => a + b) / todosWithSMART.length,
        measurability: todosWithSMART.map((t) => t.smartScores!.measurability).reduce((a, b) => a + b) / todosWithSMART.length,
        achievability: todosWithSMART.map((t) => t.smartScores!.achievability).reduce((a, b) => a + b) / todosWithSMART.length,
        relevance: todosWithSMART.map((t) => t.smartScores!.relevance).reduce((a, b) => a + b) / todosWithSMART.length,
        timeBound: todosWithSMART.map((t) => t.smartScores!.timeBound).reduce((a, b) => a + b) / todosWithSMART.length,
      );
    }

    return AlignmentStats(
      totalTodos: goalTodos.length,
      completedTodos: completed,
      analyzedTodos: scoredTodos.length,
      avgAlignmentScore: avgScore,
      eisenhowerCounts: eisenhowerCounts,
      avgSMARTScores: avgSMART,
    );
  }
}

/// Alignment statistics for a goal
class AlignmentStats {
  final int totalTodos;
  final int completedTodos;
  final int analyzedTodos;
  final double avgAlignmentScore;
  final Map<EisenhowerClass, int> eisenhowerCounts;
  final SMARTScores? avgSMARTScores;

  const AlignmentStats({
    required this.totalTodos,
    required this.completedTodos,
    required this.analyzedTodos,
    required this.avgAlignmentScore,
    required this.eisenhowerCounts,
    this.avgSMARTScores,
  });

  double get completionRate =>
      totalTodos > 0 ? completedTodos / totalTodos : 0;

  int get highPriorityTasks =>
      (eisenhowerCounts[EisenhowerClass.doNow] ?? 0) +
      (eisenhowerCounts[EisenhowerClass.schedule] ?? 0);

  double get highPriorityPercentage =>
      totalTodos > 0 ? highPriorityTasks / totalTodos : 0;
}
