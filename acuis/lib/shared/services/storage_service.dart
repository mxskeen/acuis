import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/goal.dart';
import '../../models/todo.dart';

class StorageService {
  static const _goalsKey = 'acuis_goals';
  static const _todosKey = 'acuis_todos';
  static const _apiKeyKey = 'acuis_nvidia_api_key';

  // ── Goals ────────────────────────────────────────────────
  Future<void> saveGoals(List<Goal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    final json = goals.map((g) => g.toJson()).toList();
    await prefs.setString(_goalsKey, jsonEncode(json));
  }

  Future<List<Goal>> loadGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_goalsKey);
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
    final prefs = await SharedPreferences.getInstance();
    final json = todos.map((t) => t.toJson()).toList();
    await prefs.setString(_todosKey, jsonEncode(json));
  }

  Future<List<Todo>> loadTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_todosKey);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
  }

  Future<String?> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
  }
}
