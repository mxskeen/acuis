import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/goal.dart';
import '../../models/todo.dart';
import '../../models/smart_scores.dart';

/// AI Task Generator Service
///
/// Science-backed task generation using:
/// - SMART Goal Methodology
/// - BJ Fogg's Tiny Habits (start small, build momentum)
/// - Progressive Difficulty (easier tasks first)
/// - Eisenhower Prioritization
/// - Velocity-Realistic estimates
class AITaskGeneratorService {
  static const _defaultUrl =
      'https://integrate.api.nvidia.com/v1/chat/completions';
  static const _defaultModel = 'mistralai/mistral-small-4-119b-2603';

  final String apiKey;
  final String apiUrl;
  final String model;

  AITaskGeneratorService({
    required this.apiKey,
    this.apiUrl = _defaultUrl,
    this.model = _defaultModel,
  });

  /// Generate science-backed tasks from a goal
  Future<List<GeneratedTask>> generateTasks(
    Goal goal, {
    double avgVelocity = 2.0,
    int maxTasks = 5,
  }) async {
    final timeframe = goal.type == GoalType.shortTerm
        ? 'within 1-3 months'
        : 'over 6-12 months';

    final prompt = '''
You are a goal achievement coach using SMART goal methodology and behavioral science.

USER'S GOAL: ${goal.title}
GOAL DESCRIPTION: ${goal.description}
GOAL TYPE: ${goal.type.name} ($timeframe)
TARGET DATE: ${goal.targetDate != null ? '${goal.daysRemaining} days remaining' : 'No specific deadline'}
CURRENT DATE: ${DateTime.now().toString().split(' ')[0]}
USER'S TYPICAL VELOCITY: ${avgVelocity.toStringAsFixed(1)} tasks/day

Generate $maxTasks tasks that follow these science-backed principles:

1. SMART CRITERIA: Each task should be Specific, Measurable, Achievable, Relevant, Time-bound

2. BJ FOGG'S TINY HABITS: For new behaviors, start tiny:
   - Instead of "Run 5km daily", start with "Put on running shoes each morning"
   - Build momentum with small wins first

3. PROGRESSIVE DIFFICULTY: Order tasks from easiest to hardest
   - Tasks 1-2: Tiny/easy (builds momentum, dopamine hit from quick wins)
   - Tasks 3-4: Medium effort (real progress toward the goal)
   - Task 5: Stretch goal (ambitious but achievable)

4. EISENHOWER PRIORITIZATION: Include a mix of urgent+important tasks

5. VELOCITY-REALISTIC: Given user completes ${avgVelocity.toStringAsFixed(1)} tasks/day,
   ensure tasks are achievable within the goal timeframe.

Return ONLY valid JSON array (no markdown, no explanation outside JSON):
[
  {
    "title": "<action-oriented task starting with a verb>",
    "effort": "<tiny|small|medium|large|huge>",
    "eisenhowerClass": "<doNow|schedule|delegate|eliminate>",
    "smartScores": {
      "specificity": <0-100>,
      "measurability": <0-100>,
      "achievability": <0-100>,
      "relevance": <0-100>,
      "timeBound": <0-100>
    },
    "reason": "<why this task matters for the goal - 1 sentence>",
    "bestTime": "<morning|afternoon|evening|anytime>",
    "estimatedMinutes": <number>
  }
]
''';

    try {
      final response = await _callAI(prompt);
      if (response == null) return [];

      return _parseGeneratedTasks(response);
    } catch (e) {
      throw Exception('Failed to generate tasks: $e');
    }
  }

  /// Fetch a short reason why this task helps achieve the goal
  Future<String> fetchTaskReason(String taskTitle, Goal goal) async {
    final prompt = '''
In 2-3 sentences, explain why this specific task is important for achieving the goal.
Use behavioral science principles. Be encouraging and concrete.
No bullet points, just plain text.

Goal: ${goal.title}
Task: $taskTitle

Return ONLY the explanation text, nothing else.
''';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 128,
          'temperature': 0.6,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        throw Exception('API error ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch reason: $e');
    }
  }

  /// Generate a smart nudge for the user
  Future<SmartNudgeResult> generateSmartNudge({
    required String userName,
    required List<Goal> goals,
    required List<Todo> todos,
    required int currentStreak,
  }) async {
    final pendingTodos = todos.where((t) => !t.completed).toList();
    final completedToday = todos.where((t) =>
      t.completed &&
      t.completedAt != null &&
      _isToday(t.completedAt!)
    ).length;

    final prompt = '''
You are a supportive productivity coach using behavioral science principles.

USER CONTEXT:
- Name: $userName
- Current streak: $currentStreak days
- Goals: ${goals.map((g) => g.title).take(3).join(', ')}
- Pending tasks: ${pendingTodos.length}
- Completed today: $completedToday
- Last pending task: ${pendingTodos.isNotEmpty ? pendingTodos.first.title : 'none'}

RULES:
1. Be encouraging, NOT guilt-inducing
2. Reference specific goals when possible
3. Suggest ONE specific action (not a list)
4. Use loss aversion carefully (streak at risk) only if streak >= 3
5. Celebrate recent wins if applicable
6. Apply BJ Fogg's prompt design: "After [existing routine], I will [new behavior]"

Return ONLY valid JSON (no markdown):
{
  "type": "<celebration|reminder|suggestion|streak_warning>",
  "title": "<short headline, max 5 words>",
  "message": "<personalized 1-2 sentence message>",
  "suggestedAction": "<specific task to do now, or null>",
  "urgency": "<low|medium|high>"
}
''';

    try {
      final response = await _callAI(prompt);
      if (response == null) {
        return SmartNudgeResult.defaultNudge();
      }

      return _parseSmartNudge(response);
    } catch (e) {
      return SmartNudgeResult.defaultNudge();
    }
  }

  /// Call the AI API
  Future<String?> _callAI(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a productivity expert specializing in goal achievement and behavioral science. Always respond with valid JSON only.'
            },
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 1024,
          'temperature': 0.7,
          'top_p': 0.9,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  List<GeneratedTask> _parseGeneratedTasks(String response) {
    try {
      final jsonStr = _extractJson(response);
      final List<dynamic> tasks = jsonDecode(jsonStr);

      return tasks.map((t) {
        final smartJson = t['smartScores'] as Map<String, dynamic>?;
        final smartScores = smartJson != null
            ? SMARTScores(
                specificity: (smartJson['specificity'] as num?)?.toDouble() ?? 50.0,
                measurability: (smartJson['measurability'] as num?)?.toDouble() ?? 50.0,
                achievability: (smartJson['achievability'] as num?)?.toDouble() ?? 50.0,
                relevance: (smartJson['relevance'] as num?)?.toDouble() ?? 50.0,
                timeBound: (smartJson['timeBound'] as num?)?.toDouble() ?? 50.0,
              )
            : null;

        return GeneratedTask(
          title: t['title'] as String? ?? '',
          effort: _parseEffortLevel(t['effort'] as String?),
          eisenhowerClass: _parseEisenhowerClass(t['eisenhowerClass'] as String?),
          smartScores: smartScores,
          reason: t['reason'] as String?,
          bestTime: t['bestTime'] as String?,
          estimatedMinutes: t['estimatedMinutes'] as int?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  SmartNudgeResult _parseSmartNudge(String response) {
    try {
      final jsonStr = _extractJson(response);
      final json = jsonDecode(jsonStr);

      return SmartNudgeResult(
        type: json['type'] as String? ?? 'suggestion',
        title: json['title'] as String? ?? 'Keep going!',
        message: json['message'] as String? ?? '',
        suggestedAction: json['suggestedAction'] as String?,
        urgency: json['urgency'] as String? ?? 'low',
      );
    } catch (e) {
      return SmartNudgeResult.defaultNudge();
    }
  }

  /// Create todos from generated tasks
  List<Todo> createTodosFromTasks(List<GeneratedTask> tasks, String goalId) {
    return tasks.asMap().entries.map((entry) {
      final task = entry.value;
      return Todo(
        id: DateTime.now().millisecondsSinceEpoch.toString() + entry.key.toString(),
        title: task.title,
        goalId: goalId,
        createdAt: DateTime.now(),
        aiGenerated: true,
        aiReason: task.reason,
        smartScores: task.smartScores,
        eisenhowerClass: task.eisenhowerClass,
        estimatedEffort: _effortToNumber(task.effort),
        estimatedMinutes: task.estimatedMinutes,
        bestTime: task.bestTime,
      );
    }).toList();
  }

  int _effortToNumber(EffortLevel? effort) {
    return switch (effort) {
      EffortLevel.tiny => 1,
      EffortLevel.small => 2,
      EffortLevel.medium => 3,
      EffortLevel.large => 4,
      EffortLevel.huge => 5,
      null => 3,
    };
  }

  EffortLevel _parseEffortLevel(String? value) {
    return switch (value?.toLowerCase()) {
      'tiny' => EffortLevel.tiny,
      'small' => EffortLevel.small,
      'medium' => EffortLevel.medium,
      'large' => EffortLevel.large,
      'huge' => EffortLevel.huge,
      _ => EffortLevel.medium,
    };
  }

  EisenhowerClass _parseEisenhowerClass(String? value) {
    return switch (value?.toLowerCase()) {
      'donow' || 'do_now' || 'do now' => EisenhowerClass.doNow,
      'schedule' => EisenhowerClass.schedule,
      'delegate' => EisenhowerClass.delegate,
      'eliminate' => EisenhowerClass.eliminate,
      _ => EisenhowerClass.schedule,
    };
  }

  String _extractJson(String content) {
    // Try to find JSON in code blocks first
    final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = codeBlock.firstMatch(content);
    if (match != null) return match.group(1)!.trim();

    // Try to find raw JSON array
    final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(content);
    if (jsonMatch != null) return jsonMatch.group(0)!;

    // Try to find JSON object
    final objectMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
    if (objectMatch != null) return objectMatch.group(0)!;

    return content.trim();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}

// ── Data Models ────────────────────────────────────────────────────

class GeneratedTask {
  final String title;
  final EffortLevel? effort;
  final EisenhowerClass? eisenhowerClass;
  final SMARTScores? smartScores;
  final String? reason;
  final String? bestTime;
  final int? estimatedMinutes;

  const GeneratedTask({
    required this.title,
    this.effort,
    this.eisenhowerClass,
    this.smartScores,
    this.reason,
    this.bestTime,
    this.estimatedMinutes,
  });

  double get smartScore => smartScores?.overall ?? 50.0;
}

class SmartNudgeResult {
  final String type;
  final String title;
  final String message;
  final String? suggestedAction;
  final String urgency;

  const SmartNudgeResult({
    required this.type,
    required this.title,
    required this.message,
    this.suggestedAction,
    required this.urgency,
  });

  factory SmartNudgeResult.defaultNudge() => const SmartNudgeResult(
    type: 'suggestion',
    title: 'Keep going!',
    message: "You're making progress on your goals.",
    urgency: 'low',
  );
}
