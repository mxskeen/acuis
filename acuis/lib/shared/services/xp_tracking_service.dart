import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// XP Tracking Service
///
/// Tracks XP rewards for both task completion AND initiation (ADHD-friendly)
class XPTrackingService {
  // Completion tracking (existing)
  static const _rewardedTodosKey = 'xp_rewarded_todos';

  // Initiation tracking (NEW - ADHD-friendly)
  static const _startedTodosKey = 'xp_started_todos';

  // Session tracking for continuation XP
  static const _activeSessionStartKey = 'xp_active_session_start';
  static const _todaySessionsKey = 'xp_today_sessions';
  static const _todaySessionsDateKey = 'xp_today_sessions_date';

  final SharedPreferences _prefs;

  XPTrackingService(this._prefs);

  static Future<XPTrackingService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return XPTrackingService(prefs);
  }

  // ── Completion XP (Existing) ───────────────────────────────

  /// Get set of todo IDs that have already been rewarded for completion
  Set<String> getRewardedTodoIds() {
    final raw = _prefs.getString(_rewardedTodosKey);
    if (raw == null) return {};

    final list = jsonDecode(raw) as List;
    return Set<String>.from(list);
  }

  /// Mark a todo as rewarded for completion
  Future<void> markTodoAsRewarded(String todoId) async {
    final rewarded = getRewardedTodoIds();
    rewarded.add(todoId);
    await _prefs.setString(_rewardedTodosKey, jsonEncode(rewarded.toList()));
  }

  /// Check if a todo has already been rewarded for completion
  bool hasBeenRewarded(String todoId) {
    return getRewardedTodoIds().contains(todoId);
  }

  /// Remove a todo from rewarded list (if todo is deleted or uncompleted)
  Future<void> unmarkTodoAsRewarded(String todoId) async {
    final rewarded = getRewardedTodoIds();
    rewarded.remove(todoId);
    await _prefs.setString(_rewardedTodosKey, jsonEncode(rewarded.toList()));
  }

  // ── Initiation XP (NEW - ADHD-Friendly) ────────────────────

  /// Get set of todo IDs that have been started (awarded initiation XP)
  Set<String> getStartedTodoIds() {
    final raw = _prefs.getString(_startedTodosKey);
    if (raw == null) return {};

    final list = jsonDecode(raw) as List;
    return Set<String>.from(list);
  }

  /// Mark a todo as started (awarded initiation XP)
  Future<void> markTodoAsStarted(String todoId) async {
    final started = getStartedTodoIds();
    started.add(todoId);
    await _prefs.setString(_startedTodosKey, jsonEncode(started.toList()));

    // Start tracking a focus session
    await startFocusSession(todoId);
  }

  /// Check if a todo has already been started (initiation XP awarded)
  bool hasBeenStarted(String todoId) {
    return getStartedTodoIds().contains(todoId);
  }

  /// Remove a todo from started list
  Future<void> unmarkTodoAsStarted(String todoId) async {
    final started = getStartedTodoIds();
    started.remove(todoId);
    await _prefs.setString(_startedTodosKey, jsonEncode(started.toList()));
  }

  // ── Continuation/Session XP ────────────────────────────────

  /// Start a focus session for a todo
  Future<void> startFocusSession(String todoId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _prefs.setInt('${_activeSessionStartKey}_$todoId', now);
  }

  /// End a focus session and check if it qualifies for continuation XP
  /// Returns minutes focused, or null if session wasn't started
  int? endFocusSession(String todoId) {
    final startKey = '${_activeSessionStartKey}_$todoId';
    final startMs = _prefs.getInt(startKey);
    if (startMs == null) return null;

    final endMs = DateTime.now().millisecondsSinceEpoch;
    final minutes = ((endMs - startMs) / 60000).round();

    // Clear the session
    _prefs.remove(startKey);

    // Track completed session if substantial (5+ minutes)
    if (minutes >= 5) {
      _recordSession(minutes);
    }

    return minutes;
  }

  /// Record a completed focus session
  Future<void> _recordSession(int minutes) async {
    _maybeResetDailySessions();

    final sessions = _prefs.getInt(_todaySessionsKey) ?? 0;
    await _prefs.setInt(_todaySessionsKey, sessions + 1);
  }

  void _maybeResetDailySessions() {
    final lastDate = _prefs.getString(_todaySessionsDateKey);
    final today = _getTodayString();

    if (lastDate != today) {
      _prefs.setInt(_todaySessionsKey, 0);
      _prefs.setString(_todaySessionsDateKey, today);
    }
  }

  /// Get today's completed focus sessions count
  int getTodaysSessionCount() {
    _maybeResetDailySessions();
    return _prefs.getInt(_todaySessionsKey) ?? 0;
  }

  /// Check if user has an active focus session for a todo
  bool hasActiveSession(String todoId) {
    return _prefs.getInt('${_activeSessionStartKey}_$todoId') != null;
  }

  /// Get active session duration in minutes (or 0 if no session)
  int getActiveSessionDuration(String todoId) {
    final startMs = _prefs.getInt('${_activeSessionStartKey}_$todoId');
    if (startMs == null) return 0;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return ((nowMs - startMs) / 60000).round();
  }

  // ── Cleanup ───────────────────────────────────────────────

  /// Clean up rewarded/started todos that no longer exist
  Future<void> cleanupDeletedTodos(List<String> existingTodoIds) async {
    final existingSet = Set<String>.from(existingTodoIds);

    // Clean up completion rewards
    final rewarded = getRewardedTodoIds();
    rewarded.removeWhere((id) => !existingSet.contains(id));
    await _prefs.setString(_rewardedTodosKey, jsonEncode(rewarded.toList()));

    // Clean up initiation rewards
    final started = getStartedTodoIds();
    started.removeWhere((id) => !existingSet.contains(id));
    await _prefs.setString(_startedTodosKey, jsonEncode(started.toList()));

    // Clean up orphaned session keys
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_activeSessionStartKey)) {
        final todoId = key.substring(_activeSessionStartKey.length + 1);
        if (!existingSet.contains(todoId)) {
          await _prefs.remove(key);
        }
      }
    }
  }

  // ── Stats ───────────────────────────────────────────────────

  /// Get XP statistics for the user
  XPStats getStats() {
    return XPStats(
      completedTasks: getRewardedTodoIds().length,
      startedTasks: getStartedTodoIds().length,
      todaysFocusSessions: getTodaysSessionCount(),
    );
  }

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// XP Statistics
class XPStats {
  final int completedTasks;
  final int startedTasks;
  final int todaysFocusSessions;

  const XPStats({
    required this.completedTasks,
    required this.startedTasks,
    required this.todaysFocusSessions,
  });

  /// Total tasks touched (started or completed)
  int get totalTasksEngaged => completedTasks + startedTasks;

  /// Initiation rate: what % of engaged tasks were started but not completed
  double get initiationRate =>
      totalTasksEngaged > 0 ? startedTasks / totalTasksEngaged : 0.0;
}

/// XP Types for different achievements
enum XPType {
  taskInitiation, // Starting a task (ADHD-friendly dopamine hit)
  taskCompletion, // Finishing a task
  focusSession, // 25+ min Pomodoro session
  streakMaintenance, // Keeping streak alive
  streakMilestone, // 7, 30, 100 day streaks
  eisenhowerBonus, // Appropriate prioritization
  reflectionBonus, // Daily/weekly reflection
}

/// XP Award record
class XPAward {
  final XPType type;
  final int points;
  final String? todoId;
  final DateTime awardedAt;
  final String? description;

  XPAward({
    required this.type,
    required this.points,
    this.todoId,
    required this.awardedAt,
    this.description,
  });
}
