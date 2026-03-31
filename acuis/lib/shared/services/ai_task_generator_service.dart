import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/goal.dart';
import '../../models/todo.dart';

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

  /// Generate actionable tasks from a goal
  Future<List<String>> generateTasks(Goal goal, {int maxTasks = 5}) async {
    final timeframe = goal.type == GoalType.shortTerm 
        ? 'within 1-3 months' 
        : 'over 6-12 months';
    
    final prompt = '''
Break down this goal into ${maxTasks} specific, actionable daily/weekly tasks.
Make them concrete, measurable, and achievable.

Goal: ${goal.title}
Description: ${goal.description.isNotEmpty ? goal.description : 'No additional details'}
Type: ${goal.type.name} ($timeframe)

Return ONLY valid JSON array of task strings, no markdown, no explanation.
Format: ["task 1", "task 2", "task 3", ...]

Make tasks:
- Specific and actionable (start with verbs)
- Realistic for daily/weekly completion
- Progressive (easier tasks first)
- Relevant to the goal
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
          'max_tokens': 512,
          'temperature': 0.7,
          'top_p': 0.9,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        // Extract JSON from response
        final jsonStr = _extractJson(content);
        final List<dynamic> tasks = jsonDecode(jsonStr);

        return tasks.map((t) => t.toString()).take(maxTasks).toList();
      } else {
        throw Exception('API error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to generate tasks: $e');
    }
  }

  /// Generate todos from tasks
  List<Todo> createTodosFromTasks(List<String> tasks, String goalId) {
    return tasks.map((task) {
      return Todo(
        id: DateTime.now().millisecondsSinceEpoch.toString() + 
            tasks.indexOf(task).toString(),
        title: task,
        goalId: goalId,
        createdAt: DateTime.now(),
      );
    }).toList();
  }

  /// Extract JSON from potentially markdown-wrapped response
  String _extractJson(String content) {
    // Try to find JSON in code blocks first
    final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = codeBlock.firstMatch(content);
    if (match != null) return match.group(1)!.trim();

    // Try to find raw JSON array
    final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(content);
    if (jsonMatch != null) return jsonMatch.group(0)!;

    return content.trim();
  }
}
