import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/goal.dart';
import '../../models/todo.dart';
import '../../models/velocity_prediction.dart';
import '../../models/journey_plan.dart';

class StorageService {
  static const _goalsKey = 'acuis_goals';
  static const _todosKey = 'acuis_todos';
  static const _apiKeyKey = 'acuis_nvidia_api_key';
  static const _userNameKey = 'acuis_user_name';
  static const _velocitySnapshotsKey = 'acuis_velocity_snapshots';
  static const _journeyPlansKey = 'acuis_journey_plans';

  static late final SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Goals ────────────────────────────────────────────────
  Future<void> saveGoals(List<Goal> goals) async {
    final json = goals.map((g) => g.toJson()).toList();
    await _prefs.setString(_goalsKey, jsonEncode(json));
  }

  List<Goal> loadGoalsSync() {
    try {
      final raw = _prefs.getString(_goalsKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      final List<Goal> validGoals = [];
      for (var j in list) {
        try {
          validGoals.add(Goal.fromJson(j));
        } catch (e) {
          debugPrint('Error parsing goal: $e');
        }
      }
      return validGoals;
    } catch (e) {
      debugPrint('Error loading goals: $e');
      return [];
    }
  }

  // ── Todos ────────────────────────────────────────────────
  Future<void> saveTodos(List<Todo> todos) async {
    final json = todos.map((t) => t.toJson()).toList();
    await _prefs.setString(_todosKey, jsonEncode(json));
  }

  List<Todo> loadTodosSync() {
    try {
      final raw = _prefs.getString(_todosKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      final List<Todo> validTodos = [];
      for (var j in list) {
        try {
          validTodos.add(Todo.fromJson(j));
        } catch (e) {
          debugPrint('Error parsing todo: $e');
        }
      }
      return validTodos;
    } catch (e) {
      debugPrint('Error loading todos: $e');
      return [];
    }
  }

  // ── API Key ──────────────────────────────────────────────
  Future<void> saveApiKey(String key) async {
    await _prefs.setString(_apiKeyKey, key);
  }

  String? loadApiKeySync() {
    return _prefs.getString(_apiKeyKey);
  }

  // ── User Name ────────────────────────────────────────────
  Future<void> saveUserName(String name) async {
    await _prefs.setString(_userNameKey, name);
  }

  String? loadUserNameSync() {
    return _prefs.getString(_userNameKey);
  }

  // ── Velocity Snapshots ────────────────────────────────────
  Future<void> saveVelocitySnapshots(List<VelocitySnapshot> snapshots) async {
    final json = snapshots.map((s) => s.toJson()).toList();
    await _prefs.setString(_velocitySnapshotsKey, jsonEncode(json));
  }

  List<VelocitySnapshot> loadVelocitySnapshotsSync() {
    try {
      final raw = _prefs.getString(_velocitySnapshotsKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list.map((j) => VelocitySnapshot.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading velocity snapshots: $e');
      return [];
    }
  }

  // ── Journey Plans ──────────────────────────────────────────
  Future<void> saveJourneyPlans(List<JourneyPlan> plans) async {
    final json = plans.map((p) => p.toJson()).toList();
    await _prefs.setString(_journeyPlansKey, jsonEncode(json));
  }

  List<JourneyPlan> loadJourneyPlansSync() {
    try {
      final raw = _prefs.getString(_journeyPlansKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      final List<JourneyPlan> validPlans = [];
      for (var j in list) {
        try {
          validPlans.add(JourneyPlan.fromJson(j));
        } catch (e) {
          debugPrint('Error parsing journey plan: $e');
        }
      }
      return validPlans;
    } catch (e) {
      debugPrint('Error loading journey plans: $e');
      return [];
    }
  }

  JourneyPlan? loadJourneyPlanForGoal(String goalId) {
    final plans = loadJourneyPlansSync();
    return plans.where((p) => p.goalId == goalId).firstOrNull;
  }

  // ── Generic key-value storage for services ─────────────────
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  String? getString(String key) {
    return _prefs.getString(key);
  }

  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  Future<void> setStringList(String key, List<String> value) async {
    await _prefs.setStringList(key, value);
  }

  List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
