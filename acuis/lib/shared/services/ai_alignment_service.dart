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
  final String apiKey;
  final String apiUrl;

  AIAlignmentService({
    required this.apiKey,
    this.apiUrl = 'https://api.openai.com/v1/chat/completions',
  });

  Future<AlignmentResult> analyzeAlignment(Todo todo, Goal goal) async {
    final prompt = '''
Analyze how well this todo aligns with the given goal. Return a score from 0-100 and a brief explanation.

Goal: ${goal.title}
Goal Description: ${goal.description}
Goal Type: ${goal.type.name}

Todo: ${todo.title}

Respond in JSON format:
{
  "score": <number 0-100>,
  "explanation": "<brief explanation>"
}
''';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        final result = jsonDecode(content);

        return AlignmentResult(
          score: result['score'].toDouble(),
          explanation: result['explanation'],
        );
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      return AlignmentResult(
        score: 50.0,
        explanation: 'Unable to analyze alignment: $e',
      );
    }
  }

  Future<double> calculateOverallProgress(List<Todo> todos, List<Goal> goals) async {
    if (todos.isEmpty || goals.isEmpty) return 0.0;

    double totalAlignment = 0.0;
    int completedTodos = 0;

    for (var todo in todos) {
      if (todo.completed && todo.alignmentScore != null) {
        totalAlignment += todo.alignmentScore!;
        completedTodos++;
      }
    }

    if (completedTodos == 0) return 0.0;
    return totalAlignment / completedTodos;
  }
}
