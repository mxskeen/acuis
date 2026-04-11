import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/goal.dart';
import '../../models/deconstruction_result.dart';
import '../../models/todo.dart';

/// First Principles Deconstruction Service
///
/// Applies Elon Musk's first principles thinking to goal achievement:
/// 1. Identify hidden assumptions the user is making
/// 2. Challenge those assumptions to find fundamental truths
/// 3. Reconstruct a minimal action plan from confirmed truths only
class FirstPrinciplesService {
  final String apiKey;
  final String apiUrl;
  final String model;

  FirstPrinciplesService({
    required this.apiKey,
    this.apiUrl = '',
    this.model = 'mistralai/mistral-small-4-119b-2603',
  });

  /// Step 1: Identify assumptions the user is making about how to achieve this goal
  ///
  /// Accepts either a [Goal] object or free-text [title] + [description].
  Future<List<Assumption>> identifyAssumptions({
    Goal? goal,
    String? title,
    String? description,
  }) async {
    final effectiveTitle = goal?.title ?? title ?? '';
    final effectiveDesc = goal?.description ?? description ?? '';
    final timeframe = goal != null
        ? (goal.type == GoalType.shortTerm
            ? 'within 1-3 months'
            : 'over 6-12 months')
        : 'unspecified';

    final prompt = '''
You are a first principles thinking coach. The user has this goal:

GOAL: $effectiveTitle
DESCRIPTION: $effectiveDesc
TIMEFRAME: $timeframe
${goal?.targetDate != null ? 'TARGET: ${goal!.daysRemaining} days remaining' : ''}

List 4-5 assumptions the user is LIKELY making about HOW to achieve this goal.
These should be common beliefs that may or may not be true — things most people
assume without questioning.

Each assumption should be a short, clear statement (under 15 words).
Start with phrases like "You need to...", "You must...", "It requires...",
"You should...", "The only way is...".

Return ONLY valid JSON (no markdown, no explanation):
{
  "assumptions": [
    {"text": "<assumption statement>"}
  ]
}
''';

    try {
      final response = await _callAI(prompt);
      if (response == null) return [];
      return _parseAssumptions(response);
    } catch (e) {
      throw Exception('Failed to identify assumptions: $e');
    }
  }

  /// Step 2: Challenge assumptions to find fundamental truths
  Future<List<Truth>> findTruths({
    Goal? goal,
    String? title,
    String? description,
    required List<Assumption> challengedAssumptions,
  }) async {
    if (challengedAssumptions.isEmpty) return [];

    final effectiveTitle = goal?.title ?? title ?? '';
    final effectiveDesc = goal?.description ?? description ?? '';

    final challengedList = challengedAssumptions
        .map((a) => '- "${a.text}"')
        .join('\n');

    final prompt = '''
The user has this goal: $effectiveTitle
${effectiveDesc.isNotEmpty ? 'Description: $effectiveDesc' : ''}

They challenged these assumptions:
$challengedList

For each challenged assumption, find the FUNDAMENTAL TRUTH.
Strip away convention, common wisdom, and "the way things are done."
What is actually, provably true about achieving this goal?

Focus on:
- What is the MINIMUM that must be true?
- What does science/evidence actually support?
- What would remain true even if conventional approaches didn't exist?

Return ONLY valid JSON (no markdown, no explanation):
{
  "truths": [
    {"text": "<fundamental truth in one sentence>", "explanation": "<1-2 sentences explaining why this is true>"}
  ]
}
''';

    try {
      final response = await _callAI(prompt);
      if (response == null) return [];
      return _parseTruths(response);
    } catch (e) {
      throw Exception('Failed to find truths: $e');
    }
  }

  /// Step 3: Create solutions by reconstructing the problem from confirmed truths
  Future<List<ReconstructedTask>> reconstructPlan({
    Goal? goal,
    String? title,
    String? description,
    required List<Truth> confirmedTruths,
  }) async {
    if (confirmedTruths.isEmpty) return [];

    final effectiveTitle = goal?.title ?? title ?? '';
    final effectiveDesc = goal?.description ?? description ?? '';

    final truthsList = confirmedTruths
        .map((t) => '- ${t.text}: ${t.explanation}')
        .join('\n');

    final prompt = '''
These are the confirmed fundamental truths:
$truthsList

Now RECONSTRUCT the problem. Use these truths as building blocks for innovation.
Generate 5 actionable solutions for: $effectiveTitle
${effectiveDesc.isNotEmpty ? 'Context: $effectiveDesc' : ''}

RULES:
1. Each solution is built ONLY from the confirmed truths — discard conventional approaches
2. Think like an innovator: what's the SIMPLEST path that these truths enable?
3. Start with the SMALLEST possible action (BJ Fogg Tiny Habits principle)
4. Progressive ambition:
   - Solutions 1-2: Tiny/easy (build momentum, prove the approach works)
   - Solutions 3-4: Medium effort (real breakthrough using truths as levers)
   - Solution 5: Stretch goal (ambitious innovation made possible by these truths)
5. Each solution starts with a verb and is specific enough to do today

Return ONLY valid JSON array (no markdown, no explanation):
[
  {
    "title": "<action-oriented solution>",
    "reason": "<why this follows from the truths>",
    "effort": "<tiny|small|medium|large>",
    "best_time": "<morning|afternoon|evening|anytime>",
    "estimated_minutes": <number>
  }
]
''';

    try {
      final response = await _callAI(prompt);
      if (response == null) return [];
      return _parseReconstructedTasks(response);
    } catch (e) {
      throw Exception('Failed to reconstruct plan: $e');
    }
  }

  /// Convert reconstructed tasks to Todo objects for the existing system
  List<Todo> createTodosFromReconstruction(
    List<ReconstructedTask> tasks,
    String? goalId,
  ) {
    return tasks.asMap().entries.map((entry) {
      final task = entry.value;
      return Todo(
        id: '${DateTime.now().millisecondsSinceEpoch}_fp_${entry.key}',
        title: task.title,
        goalId: goalId,
        createdAt: DateTime.now(),
        aiGenerated: true,
        aiReason: task.reason,
        estimatedEffort: _parseEffort(task.effort),
        bestTime: task.bestTime,
        estimatedMinutes: task.estimatedMinutes,
      );
    }).toList();
  }

  // ── Private helpers ──────────────────────────────────────────

  Future<String?> _callAI(String prompt) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // Backend proxy doesn't need Authorization header
      if (apiKey != 'backend-proxy') {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a first principles thinking coach specializing in goal deconstruction. You help users identify hidden assumptions, find fundamental truths, and build lean action plans. Always respond with valid JSON only.'
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

  List<Assumption> _parseAssumptions(String response) {
    try {
      final jsonStr = _extractJson(response);
      final json = jsonDecode(jsonStr);
      final List<dynamic> assumptions = json['assumptions'] ?? [];
      return assumptions
          .map((a) => Assumption(
                text: a['text'] as String? ?? '',
              ))
          .where((a) => a.text.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  List<Truth> _parseTruths(String response) {
    try {
      final jsonStr = _extractJson(response);
      final json = jsonDecode(jsonStr);
      final List<dynamic> truths = json['truths'] ?? [];
      return truths
          .map((t) => Truth(
                text: t['text'] as String? ?? '',
                explanation: t['explanation'] as String? ?? '',
              ))
          .where((t) => t.text.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  List<ReconstructedTask> _parseReconstructedTasks(String response) {
    try {
      final jsonStr = _extractJson(response);
      final List<dynamic> tasks = jsonDecode(jsonStr);
      return tasks
          .map((t) => ReconstructedTask.fromJson(t as Map<String, dynamic>))
          .where((t) => t.title.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  int _parseEffort(String? effort) {
    return switch (effort?.toLowerCase()) {
      'tiny' => 1,
      'small' => 2,
      'medium' => 3,
      'large' => 4,
      'huge' => 5,
      _ => 3,
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
}
