import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// XP Tracking Service
///
/// Tracks which todos have already been rewarded with XP to prevent duplicate awards
class XPTrackingService {
  static const _rewardedTodosKey = 'xp_rewarded_todos';
  final SharedPreferences _prefs;

  XPTrackingService(this._prefs);

  static Future<XPTrackingService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return XPTrackingService(prefs);
  }

  /// Get set of todo IDs that have already been rewarded
  Set<String> getRewardedTodoIds() {
    final raw = _prefs.getString(_rewardedTodosKey);
    if (raw == null) return {};

    final list = jsonDecode(raw) as List;
    return Set<String>.from(list);
  }

  /// Mark a todo as rewarded
  Future<void> markTodoAsRewarded(String todoId) async {
    final rewarded = getRewardedTodoIds();
    rewarded.add(todoId);
    await _prefs.setString(_rewardedTodosKey, jsonEncode(rewarded.toList()));
  }

  /// Check if a todo has already been rewarded
  bool hasBeenRewarded(String todoId) {
    return getRewardedTodoIds().contains(todoId);
  }

  /// Remove a todo from rewarded list (if todo is deleted or uncompleted)
  Future<void> unmarkTodoAsRewarded(String todoId) async {
    final rewarded = getRewardedTodoIds();
    rewarded.remove(todoId);
    await _prefs.setString(_rewardedTodosKey, jsonEncode(rewarded.toList()));
  }

  /// Clean up rewarded todos that no longer exist
  Future<void> cleanupDeletedTodos(List<String> existingTodoIds) async {
    final rewarded = getRewardedTodoIds();
    final existingSet = Set<String>.from(existingTodoIds);

    // Remove any rewarded IDs that don't exist anymore
    rewarded.removeWhere((id) => !existingSet.contains(id));

    await _prefs.setString(_rewardedTodosKey, jsonEncode(rewarded.toList()));
  }
}
