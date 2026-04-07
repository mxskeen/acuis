import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/goal.dart';
import '../../../models/todo.dart';
import '../../../models/smart_scores.dart';
import '../../../models/alignment_result.dart';

/// AI-powered multi-factor alignment scoring with science-backed criteria
///
/// Based on:
/// - Goal Setting Theory (Locke & Latham): Clarity, Challenge, Commitment, Feedback
/// - SMART Goals Framework: Specific, Measurable, Achievable, Relevant, Time-bound
/// - Eisenhower Matrix: Urgent vs Important classification
/// - Velocity-Based Forecasting (Agile/Scrum)
/// - COM-B Model for Behavior Change
class AlignmentScorer {
  static const _defaultUrl =
      'https://integrate.api.nvidia.com/v1/chat/completions';
  static const _defaultModel = 'mistralai/mistral-small-4-119b-2603';

  final String apiKey;
  final String apiUrl;
  final String model;

  AlignmentScorer({
    required this.apiKey,
    this.apiUrl = _defaultUrl,
    this.model = _defaultModel,
  });

  /// AI-powered comprehensive alignment analysis
  Future<AlignmentResult> analyze(
    Todo todo,
    Goal goal,
    ScoringContext context,
  ) async {
    final prompt = _buildAnalysisPrompt(todo, goal, context);

    try {
      final response = await _callAI(prompt);

      if (response == null) {
        return _fallbackAnalysis(todo, goal, context);
      }

      return _parseAIResponse(response, todo, goal);
    } catch (e) {
      // Graceful degradation to rule-based heuristics
      return _fallbackAnalysis(todo, goal, context);
    }
  }

  /// Build the AI prompt for alignment analysis
  String _buildAnalysisPrompt(Todo todo, Goal goal, ScoringContext context) {
    return '''
You are a supportive goal achievement coach. Analyze this task for goal alignment.

GOAL: ${goal.title}
GOAL DESCRIPTION: ${goal.description}
GOAL TYPE: ${goal.type.name} (${goal.timeContext})
TARGET DATE: ${goal.targetDate != null ? '${goal.daysRemaining} days remaining' : 'No specific deadline'}

TASK: ${todo.title}
TASK CREATED: ${todo.daysPending} days ago
USER'S VELOCITY: ${context.velocity.toStringAsFixed(1)} tasks/day

Score each SMART dimension 0-100:

1. SPECIFICITY: Is this task action-oriented with clear verbs?
   - "Write 500 words" = 95, "Write something" = 25

2. MEASURABILITY: Can completion be objectively verified?
   - "Run 5km" = 95, "Exercise" = 20

3. ACHIEVABILITY: Is this realistic given user's pace?
   - User completes ${context.velocity.toStringAsFixed(1)} tasks/day

4. RELEVANCE: How directly does this task contribute to the goal?
   - Direct action = 90+, Supporting = 70-85, Tangential = 40-60, Unrelated = 0-30

5. TIME-BOUND: Does it have a deadline or timeframe?
   - Specific deadline = 95, Linked to goal = 70, No timeframe = 20

6. EISENHOWER CLASS: "doNow" | "schedule" | "delegate" | "eliminate"

7. EFFORT: "tiny" | "small" | "medium" | "large" | "huge"

Return ONLY valid JSON:
{
  "smartScores": {
    "specificity": <0-100>,
    "measurability": <0-100>,
    "achievability": <0-100>,
    "relevance": <0-100>,
    "timeBound": <0-100>
  },
  "eisenhowerClass": "<doNow|schedule|delegate|eliminate>",
  "estimatedEffort": "<tiny|small|medium|large|huge>",
  "estimatedMinutes": <number>,
  "overallScore": <0-100>,
  "explanation": "<1-2 friendly sentences explaining how this task connects to the goal. Be encouraging and specific. Example: 'This task directly moves you closer to your goal of learning Spanish by building vocabulary daily.'>",
  "suggestion": "<optional: one practical tip to make this task more effective>"
}
''';
  }

  /// Call the AI API
  Future<String?> _callAI(String prompt) async {
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
            {
              'role': 'system',
              'content': 'You are a productivity expert specializing in goal achievement and behavioral science. Always respond with valid JSON only, no markdown formatting.'
            },
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 512,
          'temperature': 0.3,
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

  /// Parse AI response into AlignmentResult
  AlignmentResult _parseAIResponse(String response, Todo todo, Goal goal) {
    try {
      final jsonStr = _extractJson(response);
      final result = jsonDecode(jsonStr);

      final smartScoresJson = result['smartScores'] as Map<String, dynamic>?;
      final smartScores = smartScoresJson != null
          ? SMARTScores(
              specificity: (smartScoresJson['specificity'] as num?)?.toDouble() ?? 50.0,
              measurability: (smartScoresJson['measurability'] as num?)?.toDouble() ?? 50.0,
              achievability: (smartScoresJson['achievability'] as num?)?.toDouble() ?? 50.0,
              relevance: (smartScoresJson['relevance'] as num?)?.toDouble() ?? 50.0,
              timeBound: (smartScoresJson['timeBound'] as num?)?.toDouble() ?? 50.0,
            )
          : SMARTScores.defaultScores();

      final eisenhowerStr = result['eisenhowerClass'] as String?;
      final eisenhowerClass = _parseEisenhowerClass(eisenhowerStr);

      final effortStr = result['estimatedEffort'] as String?;
      final estimatedEffort = _parseEffortLevel(effortStr);

      final overallScore = (result['overallScore'] as num?)?.toDouble() ?? smartScores.overall;

      // Calculate component scores
      final components = AlignmentComponents(
        smartScore: smartScores.overall,
        eisenhowerWeight: _eisenhowerToWeight(eisenhowerClass),
        velocityFit: smartScores.achievability,
      );

      return AlignmentResult(
        score: overallScore.clamp(0.0, 100.0),
        explanation: result['explanation'] as String? ?? 'Task analyzed for goal alignment.',
        smartScores: smartScores,
        eisenhowerClass: eisenhowerClass,
        estimatedEffort: estimatedEffort,
        suggestion: result['suggestion'] as String?,
        components: components,
        isAIGenerated: true,
      );
    } catch (e) {
      return AlignmentResult.error('Failed to parse AI response: $e');
    }
  }

  /// Fallback analysis using rule-based heuristics when AI is unavailable
  AlignmentResult _fallbackAnalysis(Todo todo, Goal goal, ScoringContext context) {
    // Rule-based SMART scoring
    final specificity = _scoreSpecificity(todo.title);
    final measurability = _scoreMeasurability(todo.title);
    final relevance = _scoreRelevance(todo.title, goal.title, goal.description);
    final timeBound = _scoreTimeBound(todo, goal);
    final achievability = _scoreAchievability(todo, goal, context);

    final smartScores = SMARTScores(
      specificity: specificity,
      measurability: measurability,
      achievability: achievability,
      relevance: relevance,
      timeBound: timeBound,
    );

    // Rule-based Eisenhower classification
    final eisenhowerClass = _classifyEisenhower(todo, goal);

    // Calculate overall score
    final components = AlignmentComponents(
      smartScore: smartScores.overall,
      eisenhowerWeight: _eisenhowerToWeight(eisenhowerClass),
      velocityFit: achievability,
    );

    return AlignmentResult(
      score: components.weightedOverall,
      explanation: _generateFallbackExplanation(smartScores, eisenhowerClass, todo, goal),
      smartScores: smartScores,
      eisenhowerClass: eisenhowerClass,
      estimatedEffort: todo.effortLevel,
      components: components,
      isAIGenerated: false,
    );
  }

  // ── Rule-based scoring helpers (fallback) ───────────────────────

  double _scoreSpecificity(String title) {
    double score = 30.0; // Base score

    // Check for action verbs
    final actionVerbs = [
      'write', 'read', 'run', 'walk', 'call', 'email', 'send', 'create',
      'build', 'design', 'complete', 'finish', 'study', 'practice', 'review',
      'update', 'fix', 'implement', 'prepare', 'schedule', 'organize',
      'plan', 'research', 'analyze', 'draft', 'edit', 'publish', 'launch',
    ];

    final lowerTitle = title.toLowerCase();
    if (actionVerbs.any((v) => lowerTitle.startsWith(v))) {
      score += 30;
    }

    // Check for specific details (numbers, time, quantities)
    if (RegExp(r'\d+').hasMatch(title)) score += 20;
    if (RegExp(r'\d+\s*(minutes?|hours?|km|miles?|pages?|words?|times?)',
            caseSensitive: false)
        .hasMatch(title)) {
      score += 15;
    }

    // Penalize vague words
    final vagueWords = ['something', 'some', 'maybe', 'try to', 'think about'];
    for (final word in vagueWords) {
      if (lowerTitle.contains(word)) score -= 15;
    }

    return score.clamp(0.0, 100.0);
  }

  double _scoreMeasurability(String title) {
    double score = 25.0;

    // Check for quantifiable elements
    if (RegExp(r'\d+').hasMatch(title)) score += 25;
    if (RegExp(r'(for|in)\s+\d+\s*(minutes?|hours?)', caseSensitive: false)
        .hasMatch(title)) {
      score += 25;
    }
    if (RegExp(r'\d+\s*(km|miles?|pages?|words?|reps?|sets?|times?)',
            caseSensitive: false)
        .hasMatch(title)) {
      score += 25;
    }

    // Check for completion indicators
    final completableWords = ['complete', 'finish', 'submit', 'send', 'publish'];
    if (completableWords.any((w) => title.toLowerCase().contains(w))) {
      score += 15;
    }

    return score.clamp(0.0, 100.0);
  }

  double _scoreRelevance(String title, String goalTitle, String goalDesc) {
    double score = 40.0;

    final titleWords = title.toLowerCase().split(RegExp(r'\s+'));
    final goalText = '${goalTitle} ${goalDesc}'.toLowerCase();

    // Word overlap scoring
    int matches = 0;
    for (final word in titleWords) {
      if (word.length > 3 && goalText.contains(word)) {
        matches++;
      }
    }

    score += (matches * 15).clamp(0, 40);

    // Boost if goal keywords appear
    final goalKeywords = goalTitle.toLowerCase().split(RegExp(r'\s+'));
    for (final keyword in goalKeywords) {
      if (keyword.length > 3 && title.toLowerCase().contains(keyword)) {
        score += 10;
      }
    }

    return score.clamp(0.0, 100.0);
  }

  double _scoreTimeBound(Todo todo, Goal goal) {
    double score = 30.0;

    // If goal has target date
    if (goal.targetDate != null) {
      score += 30;
    }

    // If task is old (overdue)
    if (todo.daysPending > 7) {
      score -= 10;
    }

    // If goal has deadline soon
    if (goal.daysRemaining > 0 && goal.daysRemaining <= 7) {
      score += 20;
    }

    return score.clamp(0.0, 100.0);
  }

  double _scoreAchievability(Todo todo, Goal goal, ScoringContext context) {
    double score = 60.0;

    // If we have velocity data
    if (context.hasVelocityData) {
      // Can user reasonably complete this?
      final effortMinutes = todo.effortLevel.estimatedMinutes;
      if (effortMinutes <= 30) score += 20;
      else if (effortMinutes <= 60) score += 10;
      else if (effortMinutes > 120) score -= 15;
    }

    // Consider goal urgency
    if (goal.isOverdue) {
      score -= 20;
    } else if (goal.isApproachingDeadline) {
      score += 10;
    }

    // Consider days pending
    if (todo.daysPending > 14) {
      score -= 15;
    }

    return score.clamp(0.0, 100.0);
  }

  EisenhowerClass _classifyEisenhower(Todo todo, Goal goal) {
    final urgent = todo.isUrgent ??
        (goal.daysRemaining > 0 && goal.daysRemaining <= 3) ||
        todo.daysPending > 5;

    final important = todo.isImportant ??
        (todo.alignmentScore ?? 50) >= 50 ||
        goal.isHighCommitment;

    if (urgent && important) return EisenhowerClass.doNow;
    if (!urgent && important) return EisenhowerClass.schedule;
    if (urgent && !important) return EisenhowerClass.delegate;
    return EisenhowerClass.eliminate;
  }

  double _eisenhowerToWeight(EisenhowerClass eisenhowerClass) {
    return switch (eisenhowerClass) {
      EisenhowerClass.doNow => 95.0,    // Highest priority
      EisenhowerClass.schedule => 85.0, // Strategic value
      EisenhowerClass.delegate => 40.0, // Lower personal impact
      EisenhowerClass.eliminate => 15.0, // Should be removed
    };
  }

  String _generateFallbackExplanation(
    SMARTScores scores,
    EisenhowerClass eisenhower,
    Todo todo,
    Goal goal,
  ) {
    final relevance = scores.relevance;

    // Generate a friendly, encouraging explanation
    if (relevance >= 70) {
      return 'This task is well-aligned with your goal "${goal.title}". '
          'It directly contributes to your progress.';
    } else if (relevance >= 50) {
      return 'This task supports your goal "${goal.title}". '
          'Consider making it more specific to boost its impact.';
    } else {
      return 'This task has some connection to "${goal.title}". '
          'Try adding specific actions that directly move you toward the goal.';
    }
  }

  // ── Parsing helpers ─────────────────────────────────────────────

  EisenhowerClass _parseEisenhowerClass(String? value) {
    return switch (value?.toLowerCase()) {
      'donow' || 'do_now' || 'do now' => EisenhowerClass.doNow,
      'schedule' => EisenhowerClass.schedule,
      'delegate' => EisenhowerClass.delegate,
      'eliminate' => EisenhowerClass.eliminate,
      _ => EisenhowerClass.schedule,
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

  /// Batch analyze all todos for a goal
  Future<List<AlignmentResult>> analyzeBatch(
    List<Todo> todos,
    Goal goal,
    ScoringContext context,
  ) async {
    final results = <AlignmentResult>[];

    for (final todo in todos) {
      if (todo.goalId == goal.id) {
        results.add(await analyze(todo, goal, context));
        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    return results;
  }
}
