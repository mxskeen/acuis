import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/goal.dart';
import '../../models/todo.dart';

class StorageService {
  static const _goalsKey = 'acuis_goals';
  static const _todosKey = 'acuis_todos';
  static const _apiKeyKey = 'acuis_nvidia_api_key';
  static const _userNameKey = 'acuis_user_name';

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
}
