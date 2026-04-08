import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/goal.dart';
import '../../models/todo.dart';

/// Smart Todo Generator using LLM Tool Calling
///
/// The LLM receives the goal and existing todos, then uses tools to:
/// - Understand current progress
/// - Create appropriate next-step todos
/// - Avoid duplicates naturally by seeing what exists
class SmartTodoGeneratorService {
  static const _defaultUrl = ''; // Always pass apiUrl from AIConfig
  static const _defaultModel = 'mistralai/mistral-small-4-119b-2603';

  final String apiKey;
  final String apiUrl;
  final String model;

  SmartTodoGeneratorService({
    required this.apiKey,
    this.apiUrl = _defaultUrl,
    this.model = _defaultModel,
  });

  /// Tool definition for creating todos
  static const _tools = [
    {
      'type': 'function',
      'function': {
        'name': 'create_todos',
        'description': 'Create new todo tasks for a goal. Use this when the user needs actionable next steps. Tasks should be specific, achievable, and build toward the goal.',
        'parameters': {
          'type': 'object',
          'properties': {
            'todos': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'title': {
                    'type': 'string',
                    'description': 'Action-oriented task title starting with a verb',
                  },
                  'reason': {
                    'type': 'string',
                    'description': 'Why this task helps achieve the goal (1 sentence)',
                  },
                  'effort': {
                    'type': 'string',
                    'enum': ['tiny', 'small', 'medium', 'large'],
                    'description': 'Estimated effort level',
                  },
                  'best_time': {
                    'type': 'string',
                    'enum': ['morning', 'afternoon', 'evening', 'anytime'],
                    'description': 'Best time to do this task',
                  },
                  'estimated_minutes': {
                    'type': 'integer',
                    'description': 'Estimated time in minutes',
                  },
                },
                'required': ['title', 'reason'],
              },
              'description': 'List of todos to create',
            },
            'progress_assessment': {
              'type': 'string',
              'description': 'Brief assessment of current progress toward the goal',
            },
            'phase': {
              'type': 'string',
              'enum': ['starting', 'building', 'advancing', 'finishing'],
              'description': 'Current phase of goal progress',
            },
          },
          'required': ['todos', 'progress_assessment', 'phase'],
        },
      },
    }
  ];

  /// Generate todos for a goal using tool calling
  Future<SmartGenerationResult> generateTodos({
    required Goal goal,
    required List<Todo> existingTodos,
    int maxTodos = 5,
  }) async {
    // Separate completed and pending todos
    final completedTodos = existingTodos
        .where((t) => t.completed)
        .map((t) => t.title)
        .toList();
    final pendingTodos = existingTodos
        .where((t) => !t.completed)
        .map((t) => t.title)
        .toList();

    final systemPrompt = '''You are a goal achievement assistant. Your job is to analyze a user's goal and current progress, then create actionable next-step todos.

RULES:
1. NEVER repeat tasks that are already in completed or pending lists
2. Build upon completed work - next logical steps
3. Match task difficulty to user's current progress phase
4. Be specific and action-oriented (start with verbs)
5. Consider the goal's timeframe and days remaining

PHASES:
- starting: Beginning the goal, focus on tiny/easy tasks to build momentum
- building: Making progress, focus on medium tasks that advance the goal
- advancing: Good progress, focus on stretch tasks that push forward
- finishing: Near completion, focus on wrap-up and milestone tasks''';

    final userPrompt = _buildPrompt(goal, completedTodos, pendingTodos, maxTodos);

    try {
      // Build headers - only add Authorization if not using backend proxy
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (apiKey != 'backend-proxy') {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'tools': _tools,
          'tool_choice': {'type': 'function', 'function': {'name': 'create_todos'}},
          'max_tokens': 2048,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('API error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      return _parseToolResponse(data, goal.id);
    } catch (e) {
      throw Exception('Failed to generate todos: $e');
    }
  }

  String _buildPrompt(Goal goal, List<String> completed, List<String> pending, int maxTodos) {
    final buffer = StringBuffer();

    buffer.writeln('GOAL: ${goal.title}');
    if (goal.description.isNotEmpty) {
      buffer.writeln('DESCRIPTION: ${goal.description}');
    }
    buffer.writeln('GOAL TYPE: ${goal.type.name}');
    buffer.writeln('CREATED: ${_formatDate(goal.createdAt)}');
    buffer.writeln('DAYS SINCE START: ${DateTime.now().difference(goal.createdAt).inDays}');

    if (goal.targetDate != null) {
      buffer.writeln('TARGET DATE: ${_formatDate(goal.targetDate!)}');
      buffer.writeln('DAYS REMAINING: ${goal.daysRemaining}');
    }

    buffer.writeln('\n--- COMPLETED TASKS (${completed.length}) ---');
    if (completed.isEmpty) {
      buffer.writeln('(none yet - just starting)');
    } else {
      for (int i = 0; i < completed.length && i < 20; i++) {
        buffer.writeln('✓ ${completed[i]}');
      }
      if (completed.length > 20) {
        buffer.writeln('... and ${completed.length - 20} more');
      }
    }

    buffer.writeln('\n--- PENDING TASKS (${pending.length}) ---');
    if (pending.isEmpty) {
      buffer.writeln('(no pending tasks)');
    } else {
      for (int i = 0; i < pending.length && i < 15; i++) {
        buffer.writeln('○ ${pending[i]}');
      }
      if (pending.length > 15) {
        buffer.writeln('... and ${pending.length - 15} more');
      }
    }

    buffer.writeln('\n--- REQUEST ---');
    buffer.writeln('Create $maxTodos NEW tasks that:');
    buffer.writeln('1. Are NOT duplicates of completed or pending tasks above');
    buffer.writeln('2. Build logically on what has been completed');
    buffer.writeln('3. Are appropriate for the current progress phase');
    buffer.writeln('4. Help the user reach their goal within the timeframe');

    return buffer.toString();
  }

  SmartGenerationResult _parseToolResponse(Map<String, dynamic> data, String goalId) {
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('No response from LLM');
    }

    final message = choices[0]['message'] as Map<String, dynamic>?;
    final toolCalls = message?['tool_calls'] as List?;

    if (toolCalls == null || toolCalls.isEmpty) {
      throw Exception('No tool calls in response');
    }

    final toolCall = toolCalls[0] as Map<String, dynamic>;
    final function = toolCall['function'] as Map<String, dynamic>;
    final arguments = jsonDecode(function['arguments'] as String) as Map<String, dynamic>;

    // Parse progress assessment
    final progressAssessment = arguments['progress_assessment'] as String? ?? '';
    final phase = arguments['phase'] as String? ?? 'starting';

    // Parse todos
    final todosJson = arguments['todos'] as List? ?? [];
    final todos = <Todo>[];

    for (int i = 0; i < todosJson.length; i++) {
      final t = todosJson[i] as Map<String, dynamic>;
      todos.add(Todo(
        id: '${DateTime.now().millisecondsSinceEpoch}_$i',
        title: t['title'] as String? ?? '',
        goalId: goalId,
        createdAt: DateTime.now(),
        aiGenerated: true,
        aiReason: t['reason'] as String?,
        estimatedEffort: _parseEffort(t['effort'] as String?),
        bestTime: t['best_time'] as String?,
        estimatedMinutes: t['estimated_minutes'] as int?,
      ));
    }

    return SmartGenerationResult(
      todos: todos,
      progressAssessment: progressAssessment,
      phase: phase,
    );
  }

  int _parseEffort(String? effort) {
    return switch (effort?.toLowerCase()) {
      'tiny' => 1,
      'small' => 2,
      'medium' => 3,
      'large' => 4,
      _ => 3,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Result from smart todo generation
class SmartGenerationResult {
  final List<Todo> todos;
  final String progressAssessment;
  final String phase;

  const SmartGenerationResult({
    required this.todos,
    required this.progressAssessment,
    required this.phase,
  });
}
