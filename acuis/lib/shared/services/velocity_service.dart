import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/todo.dart';
import '../../models/goal.dart';
import '../../models/velocity_prediction.dart';
import '../../models/smart_scores.dart';

/// Velocity Tracking Service
///
/// Based on Agile/Scrum velocity tracking methodology:
/// - Tracks historical completion rate (tasks/day or points/day)
/// - Uses rolling average for predictions
/// - Calculates confidence intervals (best/worst case)
/// - Stores daily completion snapshots
class VelocityService {
  static const _snapshotsKey = 'velocity_snapshots';
  static const _lastSnapshotDateKey = 'last_snapshot_date';

  final SharedPreferences _prefs;

  VelocityService(this._prefs);

  static Future<VelocityService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return VelocityService(prefs);
  }

  // ── Velocity Calculations ──────────────────────────────────────

  /// Calculate rolling velocity (tasks completed per day)
  double getVelocity(int days) {
    final snapshots = _getRecentSnapshots(days);
    if (snapshots.isEmpty) return 0.0;

    final totalTasks = snapshots.fold<int>(0, (sum, s) => sum + s.tasksCompleted);
    return totalTasks / days;
  }

  /// Calculate weighted velocity (points per day)
  /// Points are based on effort estimates
  double getWeightedVelocity(int days) {
    final snapshots = _getRecentSnapshots(days);
    if (snapshots.isEmpty) return 0.0;

    final totalPoints = snapshots.fold<int>(0, (sum, s) => sum + s.pointsCompleted);
    return totalPoints / days;
  }

  /// Get velocity for each of the last N days
  List<double> getDailyVelocities(int days) {
    final snapshots = _getRecentSnapshots(days);
    final result = <double>[];

    // Create a map of date to tasks completed
    final dateMap = <String, int>{};
    for (final s in snapshots) {
      final dateStr = _dateToString(s.date);
      dateMap[dateStr] = (dateMap[dateStr] ?? 0) + s.tasksCompleted;
    }

    // Fill in the last N days
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = _dateToString(date);
      result.add((dateMap[dateStr] ?? 0).toDouble());
    }

    return result;
  }

  /// Predict completion date with confidence intervals
  VelocityPrediction predictCompletion(Goal goal, List<Todo> todos) {
    final goalTodos = todos.where((t) => t.goalId == goal.id).toList();
    final remainingTodos = goalTodos.where((t) => !t.completed).toList();

    if (remainingTodos.isEmpty) {
      return const VelocityPrediction(
        expectedDays: 0,
        bestCaseDays: 0,
        worstCaseDays: 0,
        confidence: 100,
        velocity: 0,
        remainingTasks: 0,
        dataQuality: VelocityDataQuality.excellent,
      );
    }

    // Get velocity (7-day rolling average)
    final velocity = getVelocity(7);
    final weightedVelocity = getWeightedVelocity(7);

    if (velocity <= 0) {
      return VelocityPrediction.insufficientData();
    }

    // Calculate remaining work
    final remainingTasks = remainingTodos.length;
    final remainingPoints = remainingTodos.fold<int>(
      0,
      (sum, t) => sum + (t.estimatedEffort ?? 3),
    );

    // Calculate expected days
    final avgDays = remainingTasks / velocity;

    // Calculate standard deviation for confidence intervals
    final stdDev = _calculateStdDeviation();

    // Calculate confidence based on data quality
    final dataQuality = _assessDataQuality();
    final confidence = _calculateConfidence(dataQuality, avgDays);

    return VelocityPrediction(
      expectedDays: avgDays.round(),
      bestCaseDays: max(1, (avgDays - stdDev).round()),
      worstCaseDays: (avgDays + stdDev).round(),
      confidence: confidence,
      velocity: velocity,
      remainingTasks: remainingTasks,
      dataQuality: dataQuality,
    );
  }

  /// Calculate if user is on track to meet goal deadline
  GoalProgressStatus getGoalProgressStatus(Goal goal, List<Todo> todos) {
    if (goal.targetDate == null) {
      return GoalProgressStatus.noDeadline;
    }

    final prediction = predictCompletion(goal, todos);

    if (!prediction.hasReliablePrediction) {
      return GoalProgressStatus.insufficientData;
    }

    final daysRemaining = goal.daysRemaining;

    if (prediction.expectedDays <= daysRemaining) {
      return GoalProgressStatus.onTrack;
    } else if (prediction.bestCaseDays <= daysRemaining) {
      return GoalProgressStatus.atRisk;
    } else {
      return GoalProgressStatus.behind;
    }
  }

  // ── Snapshot Management ────────────────────────────────────────

  /// Record a completion event
  Future<void> recordCompletion(Todo todo) async {
    await _ensureTodaySnapshot();
    // The snapshot will be updated with the completion
  }

  /// Store daily completion snapshot
  /// Called once per day to track historical velocity
  Future<void> recordDaySnapshot(List<Todo> allTodos) async {
    final today = DateTime.now();
    final todayStr = _dateToString(today);
    final lastSnapshotDate = _prefs.getString(_lastSnapshotDateKey);

    // Only record once per day
    if (lastSnapshotDate == todayStr) {
      return;
    }

    // Calculate today's completions
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayCompletions = allTodos.where((t) =>
      t.completed &&
      t.completedAt != null &&
      t.completedAt!.isAfter(todayStart)
    ).toList();

    final tasksCompleted = todayCompletions.length;
    final pointsCompleted = todayCompletions.fold<int>(
      0,
      (sum, t) => sum + (t.estimatedEffort ?? 3),
    );

    final totalTasks = allTodos.length;
    final completedTasks = allTodos.where((t) => t.completed).length;

    final snapshot = VelocitySnapshot(
      date: today,
      tasksCompleted: tasksCompleted,
      pointsCompleted: pointsCompleted,
      totalTasks: totalTasks,
      completedTasks: completedTasks,
    );

    // Save snapshot
    final snapshots = _loadSnapshots();
    snapshots.add(snapshot);

    // Keep only last 90 days
    final cutoff = today.subtract(const Duration(days: 90));
    snapshots.removeWhere((s) => s.date.isBefore(cutoff));

    await _saveSnapshots(snapshots);
    await _prefs.setString(_lastSnapshotDateKey, todayStr);
  }

  /// Ensure today's snapshot exists
  Future<void> _ensureTodaySnapshot() async {
    final today = DateTime.now();
    final todayStr = _dateToString(today);
    final lastSnapshotDate = _prefs.getString(_lastSnapshotDateKey);

    if (lastSnapshotDate != todayStr) {
      // Create empty snapshot for today
      final snapshot = VelocitySnapshot(
        date: today,
        tasksCompleted: 0,
        pointsCompleted: 0,
        totalTasks: 0,
        completedTasks: 0,
      );

      final snapshots = _loadSnapshots();
      snapshots.add(snapshot);
      await _saveSnapshots(snapshots);
      await _prefs.setString(_lastSnapshotDateKey, todayStr);
    }
  }

  // ── Data Persistence ────────────────────────────────────────────

  List<VelocitySnapshot> _loadSnapshots() {
    try {
      final raw = _prefs.getString(_snapshotsKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list.map((j) => VelocitySnapshot.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading velocity snapshots: $e');
      return [];
    }
  }

  Future<void> _saveSnapshots(List<VelocitySnapshot> snapshots) async {
    final json = snapshots.map((s) => s.toJson()).toList();
    await _prefs.setString(_snapshotsKey, jsonEncode(json));
  }

  List<VelocitySnapshot> _getRecentSnapshots(int days) {
    final snapshots = _loadSnapshots();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return snapshots.where((s) => s.date.isAfter(cutoff)).toList();
  }

  // ── Statistical Helpers ──────────────────────────────────────────

  double _calculateStdDeviation() {
    final velocities = getDailyVelocities(14); // 2 weeks of data
    if (velocities.length < 3) return 5.0; // Default std dev

    final mean = velocities.reduce((a, b) => a + b) / velocities.length;
    final variance = velocities.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / velocities.length;
    return sqrt(variance);
  }

  VelocityDataQuality _assessDataQuality() {
    final snapshots = _loadSnapshots();
    final daysWithData = snapshots.length;

    return switch (daysWithData) {
      < 3 => VelocityDataQuality.insufficient,
      < 7 => VelocityDataQuality.poor,
      < 14 => VelocityDataQuality.moderate,
      < 28 => VelocityDataQuality.good,
      _ => VelocityDataQuality.excellent,
    };
  }

  int _calculateConfidence(VelocityDataQuality quality, double expectedDays) {
    int base = switch (quality) {
      VelocityDataQuality.insufficient => 10,
      VelocityDataQuality.poor => 30,
      VelocityDataQuality.moderate => 50,
      VelocityDataQuality.good => 70,
      VelocityDataQuality.excellent => 85,
    };

    // Adjust for prediction horizon (further = less confident)
    if (expectedDays > 30) base -= 20;
    else if (expectedDays > 14) base -= 10;
    else if (expectedDays > 7) base -= 5;

    return base.clamp(5, 95);
  }

  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ── Analytics & Insights ────────────────────────────────────────

  /// Get productivity insights for the user
  VelocityInsights getInsights() {
    final snapshots = _loadSnapshots();

    if (snapshots.length < 3) {
      return VelocityInsights.insufficient();
    }

    // Best day of the week
    final dayCompletions = <int, List<int>>{};
    for (final s in snapshots) {
      final weekday = s.date.weekday;
      dayCompletions.putIfAbsent(weekday, () => []);
      dayCompletions[weekday]!.add(s.tasksCompleted);
    }

    int? bestDay;
    double? bestDayAvg;
    for (final entry in dayCompletions.entries) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      if (bestDayAvg == null || avg > bestDayAvg) {
        bestDay = entry.key;
        bestDayAvg = avg;
      }
    }

    // Trend direction
    final recentVelocity = getVelocity(7);
    final olderVelocity = getVelocity(14) * 2 - recentVelocity; // Approximation
    final trendDirection = recentVelocity > olderVelocity * 1.1
        ? TrendDirection.improving
        : recentVelocity < olderVelocity * 0.9
            ? TrendDirection.declining
            : TrendDirection.stable;

    return VelocityInsights(
      currentVelocity: recentVelocity,
      trendDirection: trendDirection,
      bestDayOfWeek: bestDay,
      bestDayAverage: bestDayAvg ?? 0,
      totalDaysTracked: snapshots.length,
      totalTasksCompleted: snapshots.fold<int>(0, (sum, s) => sum + s.tasksCompleted),
    );
  }

  /// Get streak information for velocity
  int getActiveVelocityStreak() {
    final snapshots = _loadSnapshots();
    if (snapshots.isEmpty) return 0;

    // Sort by date descending
    snapshots.sort((a, b) => b.date.compareTo(a.date));

    int streak = 0;
    DateTime? lastDate;

    for (final s in snapshots) {
      if (s.tasksCompleted == 0) break;

      if (lastDate == null) {
        streak = 1;
      } else {
        final diff = lastDate.difference(s.date).inDays;
        if (diff == 1) {
          streak++;
        } else {
          break;
        }
      }

      lastDate = s.date;
    }

    return streak;
  }
}

// ── Supporting Types ──────────────────────────────────────────────

enum GoalProgressStatus {
  onTrack,
  atRisk,
  behind,
  noDeadline,
  insufficientData,
}

enum TrendDirection {
  improving,
  stable,
  declining,
}

class VelocityInsights {
  final double currentVelocity;
  final TrendDirection trendDirection;
  final int? bestDayOfWeek;
  final double bestDayAverage;
  final int totalDaysTracked;
  final int totalTasksCompleted;

  const VelocityInsights({
    required this.currentVelocity,
    required this.trendDirection,
    this.bestDayOfWeek,
    required this.bestDayAverage,
    required this.totalDaysTracked,
    required this.totalTasksCompleted,
  });

  factory VelocityInsights.insufficient() => const VelocityInsights(
    currentVelocity: 0,
    trendDirection: TrendDirection.stable,
    bestDayAverage: 0,
    totalDaysTracked: 0,
    totalTasksCompleted: 0,
  );

  String get bestDayName {
    if (bestDayOfWeek == null) return 'Not enough data';
    return switch (bestDayOfWeek!) {
      1 => 'Monday',
      2 => 'Tuesday',
      3 => 'Wednesday',
      4 => 'Thursday',
      5 => 'Friday',
      6 => 'Saturday',
      7 => 'Sunday',
      _ => 'Unknown',
    };
  }

  String get trendEmoji => switch (trendDirection) {
    TrendDirection.improving => '📈',
    TrendDirection.stable => '➡️',
    TrendDirection.declining => '📉',
  };

  String get trendDescription => switch (trendDirection) {
    TrendDirection.improving => 'Your productivity is improving!',
    TrendDirection.stable => 'Your productivity is steady',
    TrendDirection.declining => 'Your productivity has slowed down',
  };
}
