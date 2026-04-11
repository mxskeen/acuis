import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/goal.dart';
import '../../models/deconstruction_result.dart';
import '../../models/todo.dart';

/// First Principles Deconstruction Service
///
/// Applies first principles thinking to any idea, belief, or goal:
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

  /// Step 1: Identify assumptions the user is making
  ///
  /// Accepts either a [Goal] object or free-text [title] + [description].
  /// When no Goal is provided, treats the input as a general idea to deconstruct.
  Future<List<Assumption>> identifyAssumptions({
    Goal? goal,
    String? title,
    String? description,
  }) async {
    final effectiveTitle = goal?.title ?? title ?? '';
    final effectiveDesc = goal?.description ?? description ?? '';

    final contextBlock = goal != null
        ? '''
GOAL: $effectiveTitle
DESCRIPTION: $effectiveDesc
TIMEFRAME: ${goal.type == GoalType.shortTerm ? 'within 1-3 months' : 'over 6-12 months'}
${goal.targetDate != null ? 'TARGET: ${goal.daysRemaining} days remaining' : ''}'''
        : '''
IDEA: $effectiveTitle
${effectiveDesc.isNotEmpty ? 'CONTEXT: $effectiveDesc' : ''}''';

    final prompt = '''
You are a first principles thinking coach. The user wants to rethink this:

$contextBlock

List 4-5 assumptions the user is LIKELY making about this.
These should be common beliefs that may or may not be true — things most people
assume without questioning. These could be about what's necessary, how things work,
what the rules are, or what "everyone knows".

Each assumption should be a short, clear statement (under 15 words).
Start with phrases like "You need to...", "You must...", "It requires...",
"You should...", "The only way is...", "It has to be...".

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

    final assumptionsList = challengedAssumptions
        .map((a) => '- "${a.text}"')
        .join('\n');

    final subjectLabel = goal != null ? 'this goal' : 'this idea';

    final prompt = '''
The user is rethinking $subjectLabel: $effectiveTitle
${effectiveDesc.isNotEmpty ? 'Context: $effectiveDesc' : ''}

These are the assumptions they hold:
$assumptionsList

Challenge EACH assumption using Socratic questioning. Find the FUNDAMENTAL TRUTH
behind each one — what is actually, provably true vs. what is just convention?

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

    final subjectLabel = goal != null ? 'the goal: $effectiveTitle' : 'the idea: $effectiveTitle';

    final prompt = '''
These are the confirmed fundamental truths:
$truthsList

Now RECONSTRUCT $subjectLabel
Use these truths as building blocks for innovation. Discard conventional approaches
entirely — build ONLY from what these truths make possible.

Generate 5 actionable solutions.
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
      debugPrint('[FirstPrinciples] Calling API: $apiUrl');
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
                  'You are a first principles thinking coach. You help users rethink any idea, belief, or goal from scratch — identifying hidden assumptions, finding fundamental truths, and building lean action plans. Always respond with valid JSON only. Never wrap your response in markdown code blocks.'
            },
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 1024,
          'temperature': 0.7,
          'top_p': 0.9,
          'stream': false,
        }),
      );

      debugPrint('[FirstPrinciples] Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        debugPrint('[FirstPrinciples] Raw AI response:\n$content');
        return content;
      }
      final errorBody = response.body.length > 300
          ? response.body.substring(0, 300)
          : response.body;
      debugPrint('[FirstPrinciples] API error ${response.statusCode}: $errorBody');
      return null;
    } catch (e) {
      debugPrint('[FirstPrinciples] Exception in _callAI: $e');
      return null;
    }
  }

  List<Assumption> _parseAssumptions(String response) {
    try {
      final jsonStr = _extractJson(response);
      debugPrint('[FirstPrinciples] Extracted JSON for assumptions: $jsonStr');
      final decoded = jsonDecode(jsonStr);

      // Handle both {"assumptions": [...]} and direct [...]
      List<dynamic> assumptions;
      if (decoded is Map) {
        assumptions = decoded['assumptions'] as List<dynamic>? ?? [];
      } else if (decoded is List) {
        assumptions = decoded;
      } else {
        debugPrint('[FirstPrinciples] Unexpected JSON type: ${decoded.runtimeType}');
        return [];
      }

      return assumptions
          .map((a) {
            if (a is Map) {
              return Assumption(text: a['text'] as String? ?? '');
            } else if (a is String) {
              return Assumption(text: a);
            }
            return Assumption(text: '');
          })
          .where((a) => a.text.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[FirstPrinciples] Parse assumptions failed: $e');
      debugPrint('[FirstPrinciples] Response was: $response');
      return [];
    }
  }

  List<Truth> _parseTruths(String response) {
    try {
      final jsonStr = _extractJson(response);
      debugPrint('[FirstPrinciples] Extracted JSON for truths: $jsonStr');
      final decoded = jsonDecode(jsonStr);

      List<dynamic> truths;
      if (decoded is Map) {
        truths = decoded['truths'] as List<dynamic>? ?? [];
      } else if (decoded is List) {
        truths = decoded;
      } else {
        debugPrint('[FirstPrinciples] Unexpected JSON type: ${decoded.runtimeType}');
        return [];
      }

      return truths
          .map((t) {
            if (t is Map) {
              return Truth(
                text: t['text'] as String? ?? '',
                explanation: t['explanation'] as String? ?? '',
              );
            } else if (t is String) {
              return Truth(text: t, explanation: '');
            }
            return Truth(text: '', explanation: '');
          })
          .where((t) => t.text.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[FirstPrinciples] Parse truths failed: $e');
      debugPrint('[FirstPrinciples] Response was: $response');
      return [];
    }
  }

  List<ReconstructedTask> _parseReconstructedTasks(String response) {
    try {
      final jsonStr = _extractJson(response);
      debugPrint('[FirstPrinciples] Extracted JSON for tasks: $jsonStr');
      final decoded = jsonDecode(jsonStr);

      List<dynamic> tasks;
      if (decoded is Map) {
        tasks = decoded['tasks'] as List<dynamic>? ??
            decoded['steps'] as List<dynamic>? ??
            decoded['solutions'] as List<dynamic>? ??
            [];
      } else if (decoded is List) {
        tasks = decoded;
      } else {
        debugPrint('[FirstPrinciples] Unexpected JSON type: ${decoded.runtimeType}');
        return [];
      }

      return tasks
          .map((t) => ReconstructedTask.fromJson(t as Map<String, dynamic>))
          .where((t) => t.title.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[FirstPrinciples] Parse tasks failed: $e');
      debugPrint('[FirstPrinciples] Response was: $response');
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

  /// Extract JSON from AI response — handles code blocks, preamble text, etc.
  String _extractJson(String content) {
    var text = content.trim();

    // Strip markdown code blocks if present
    if (text.contains('```')) {
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();
      debugPrint('[FirstPrinciples] Stripped code blocks');
    }

    // Find first { or [ and last matching } or ]
    final firstBrace = text.indexOf('{');
    final firstBracket = text.indexOf('[');

    if (firstBrace >= 0 && (firstBracket < 0 || firstBrace < firstBracket)) {
      final lastBrace = text.lastIndexOf('}');
      if (lastBrace > firstBrace) {
        final extracted = text.substring(firstBrace, lastBrace + 1);
        debugPrint('[FirstPrinciples] Extracted JSON object (${extracted.length} chars)');
        return extracted;
      }
    }

    if (firstBracket >= 0) {
      final lastBracket = text.lastIndexOf(']');
      if (lastBracket > firstBracket) {
        final extracted = text.substring(firstBracket, lastBracket + 1);
        debugPrint('[FirstPrinciples] Extracted JSON array (${extracted.length} chars)');
        return extracted;
      }
    }

    debugPrint('[FirstPrinciples] No JSON found, returning raw (${text.length} chars)');
    return text;
  }
}
