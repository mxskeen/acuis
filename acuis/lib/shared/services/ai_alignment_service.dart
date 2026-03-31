import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/goal.dart';
import '../../models/todo.dart';

class AlignmentResult {
  final double score;
  final String explanation;

  AlignmentResult({required this.score, required this.explanation});
}

class AIAlignmentService {
  static const _defaultUrl =
      'https://integrate.api.nvidia.com/v1/chat/completions';
  static const _defaultModel = 'mistralai/mistral-small-4-119b-2603';

  final String apiKey;
  final String apiUrl;
  final String model;

  AIAlignmentService({
    required this.apiKey,
    this.apiUrl = _defaultUrl,
    this.model = _defaultModel,
  });

  /// Score how well a single todo aligns with its linked goal (0-100).
  Future<AlignmentResult> analyzeAlignment(Todo todo, Goal goal) async {
    final prompt = '''
Analyze how well this todo task aligns with the given goal.
Return ONLY valid JSON, no markdown, no explanation outside the JSON.

Goal: ${goal.title}
Goal Description: ${goal.description}
Goal Type: ${goal.type.name}

Todo: ${todo.title}

Respond in this exact JSON format:
{"score": <number 0-100>, "explanation": "<one sentence>"}
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
          'max_tokens': 256,
          'temperature': 0.1,
          'top_p': 1.0,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        // Extract JSON from response (handle potential markdown wrapping)
        final jsonStr = _extractJson(content);
        final result = jsonDecode(jsonStr);

        return AlignmentResult(
          score: (result['score'] as num).toDouble(),
          explanation: result['explanation'] ?? '',
        );
      } else {
        throw Exception('API error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      return AlignmentResult(
        score: -1,
        explanation: 'Unable to analyze: $e',
      );
    }
  }

  /// Batch-analyze all linked todo-goal pairs.
  Future<Map<String, AlignmentResult>> analyzeAll(
    List<Todo> todos,
    List<Goal> goals,
  ) async {
    final goalMap = {for (var g in goals) g.id: g};
    final results = <String, AlignmentResult>{};

    for (final todo in todos) {
      if (todo.goalId != null && goalMap.containsKey(todo.goalId)) {
        results[todo.id] =
            await analyzeAlignment(todo, goalMap[todo.goalId]!);
        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    return results;
  }

  /// Calculate overall alignment as average score of analyzed todos.
  double calculateOverallScore(Map<String, AlignmentResult> results) {
    if (results.isEmpty) return 0;
    final valid = results.values.where((r) => r.score >= 0);
    if (valid.isEmpty) return 0;
    return valid.map((r) => r.score).reduce((a, b) => a + b) / valid.length;
  }

  /// Extract JSON string from potentially markdown-wrapped response.
  String _extractJson(String content) {
    // Try to find JSON in code blocks first
    final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = codeBlock.firstMatch(content);
    if (match != null) return match.group(1)!.trim();

    // Try to find raw JSON object
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
    if (jsonMatch != null) return jsonMatch.group(0)!;

    return content.trim();
  }
}
