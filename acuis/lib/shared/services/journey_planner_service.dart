import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/goal.dart';
import '../../models/journey_plan.dart';

/// Journey Planner Service
///
/// Uses LLM tool calling to:
/// 1. Estimate realistic goal duration based on complexity
/// 2. Create structured journey plans with milestones
///
/// Evidence-based approach:
/// - Locke & Latham: Specific, challenging goals
/// - Gollwitzer: Implementation intentions (if-then plans)
/// - Fogg: Tiny habit anchors
class JourneyPlannerService {
  static const _defaultUrl = ''; // Always pass apiUrl from AIConfig
  static const _defaultModel = 'mistralai/mistral-small-4-119b-2603';

  final String apiKey;
  final String apiUrl;
  final String model;

  JourneyPlannerService({
    required this.apiKey,
    this.apiUrl = _defaultUrl,
    this.model = _defaultModel,
  });

  /// Tool for estimating goal duration
  static const _durationEstimationTool = {
    'type': 'function',
    'function': {
      'name': 'estimate_goal_duration',
      'description':
          'Estimate realistic duration for a goal based on complexity and daily time available',
      'parameters': {
        'type': 'object',
        'properties': {
          'minimum_days': {
            'type': 'integer',
            'description': 'Aggressive timeline (ambitious but doable)',
          },
          'recommended_days': {
            'type': 'integer',
            'description': 'Balanced timeline (most people succeed)',
          },
          'maximum_days': {
            'type': 'integer',
            'description': 'Relaxed timeline (comfortable pace)',
          },
          'daily_minutes_minimum': {
            'type': 'integer',
            'description': 'Minutes/day needed for aggressive timeline',
          },
          'daily_minutes_recommended': {
            'type': 'integer',
            'description': 'Minutes/day needed for balanced timeline',
          },
          'daily_minutes_maximum': {
            'type': 'integer',
            'description': 'Minutes/day needed for relaxed timeline',
          },
          'complexity': {
            'type': 'string',
            'enum': ['simple', 'moderate', 'complex', 'very_complex'],
          },
          'reasoning': {
            'type': 'string',
            'description': 'Brief explanation of why this duration',
          },
        },
        'required': [
          'minimum_days',
          'recommended_days',
          'maximum_days',
          'reasoning'
        ],
      },
    }
  };

  /// Tool for creating journey plan
  static const _journeyPlanTool = {
    'type': 'function',
    'function': {
      'name': 'create_journey_plan',
      'description':
          'Create a structured goal achievement journey with milestones',
      'parameters': {
        'type': 'object',
        'properties': {
          'commitment_prompt': {
            'type': 'string',
            'description': 'Question to ask user about why this goal matters',
          },
          'milestones': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'title': {'type': 'string'},
                'description': {'type': 'string'},
                'start_day': {'type': 'integer'},
                'end_day': {'type': 'integer'},
                'phase': {
                  'type': 'string',
                  'enum': ['foundation', 'building', 'advancing', 'finishing']
                },
                'key_outcomes': {
                  'type': 'array',
                  'items': {'type': 'string'}
                },
              },
              'required': ['title', 'start_day', 'end_day', 'phase'],
            },
          },
          'primary_anchor': {
            'type': 'object',
            'properties': {
              'trigger': {
                'type': 'string',
                'description': 'Existing daily habit to anchor to',
              },
              'action': {
                'type': 'string',
                'description': 'Tiny version of goal behavior',
              },
              'time_of_day': {
                'type': 'string',
                'enum': ['morning', 'afternoon', 'evening'],
              },
            },
          },
          'difficulty': {
            'type': 'string',
            'enum': ['easy', 'moderate', 'challenging'],
          },
        },
        'required': ['commitment_prompt', 'milestones'],
      },
    }
  };

  /// Estimate goal duration
  Future<DurationEstimate> estimateDuration({
    required String goalTitle,
    required String goalDescription,
    String? specificOutcome,
  }) async {
    final systemPrompt = '''You are a goal planning expert. Estimate realistic durations for goals based on:
- Goal complexity and scope
- Skills/knowledge required
- Typical learning curves
- Common obstacles

Be realistic, not optimistic. Most people overestimate what they can do in a month.''';

    final userPrompt = '''
GOAL: $goalTitle
${goalDescription.isNotEmpty ? 'DESCRIPTION: $goalDescription' : ''}
${specificOutcome != null ? 'SUCCESS MEANS: $specificOutcome' : ''}

Estimate how long this goal typically takes to achieve.
Consider:
- Learning/skill development time
- Habit formation (takes 66 days on average)
- Real-life interruptions
- Starting from zero vs. some experience

Use the estimate_goal_duration tool.''';

    try {
      final response = await _callLLM(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        tools: [_durationEstimationTool],
        toolChoice: {
          'type': 'function',
          'function': {'name': 'estimate_goal_duration'}
        },
      );

      return _parseDurationEstimate(response);
    } catch (e) {
      // Fallback defaults
      return DurationEstimate(
        minimumDays: 30,
        recommendedDays: 90,
        maximumDays: 180,
        reasoning: 'Unable to estimate. Using default values.',
      );
    }
  }

  /// Create full journey plan
  Future<JourneyPlan> createJourneyPlan({
    required Goal goal,
    required int selectedDays,
    required int dailyMinutes,
    String? commitmentStatement,
  }) async {
    final systemPrompt = '''You are a goal achievement coach using behavioral science:
- Break goals into 3-5 milestones (front-load easier ones)
- Each milestone should have clear outcomes
- Suggest a tiny daily anchor habit
- Make the first milestone very achievable (build confidence)''';

    final userPrompt = '''
GOAL: ${goal.title}
${goal.description.isNotEmpty ? 'DESCRIPTION: ${goal.description}' : ''}
SELECTED DURATION: $selectedDays days
DAILY TIME AVAILABLE: $dailyMinutes minutes

Create a journey plan:
1. 3-5 milestones spread across $selectedDays days
2. First milestone should be easiest (build momentum)
3. Each milestone has specific, measurable outcomes
4. Suggest one tiny daily anchor habit

Use the create_journey_plan tool.''';

    try {
      final response = await _callLLM(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        tools: [_journeyPlanTool],
        toolChoice: {
          'type': 'function',
          'function': {'name': 'create_journey_plan'}
        },
      );

      return _parseJourneyPlan(response, goal.id, selectedDays, dailyMinutes);
    } catch (e) {
      // Fallback: create simple plan
      return _createFallbackPlan(goal, selectedDays, dailyMinutes);
    }
  }

  Future<String> _callLLM({
    required String systemPrompt,
    required String userPrompt,
    required List<Map<String, dynamic>> tools,
    required Map<String, dynamic> toolChoice,
  }) async {
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
        'tools': tools,
        'tool_choice': toolChoice,
        'max_tokens': 2048,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode}');
    }

    return response.body;
  }

  DurationEstimate _parseDurationEstimate(String responseBody) {
    final data = jsonDecode(responseBody);
    final choices = data['choices'] as List;
    final message = choices[0]['message'] as Map<String, dynamic>;
    final toolCalls = message['tool_calls'] as List;
    final toolCall = toolCalls[0] as Map<String, dynamic>;
    final function = toolCall['function'] as Map<String, dynamic>;
    final arguments =
        jsonDecode(function['arguments'] as String) as Map<String, dynamic>;

    return DurationEstimate(
      minimumDays: arguments['minimum_days'] as int? ?? 30,
      recommendedDays: arguments['recommended_days'] as int? ?? 90,
      maximumDays: arguments['maximum_days'] as int? ?? 180,
      dailyMinutesMinimum: arguments['daily_minutes_minimum'] as int? ?? 10,
      dailyMinutesRecommended:
          arguments['daily_minutes_recommended'] as int? ?? 15,
      dailyMinutesMaximum: arguments['daily_minutes_maximum'] as int? ?? 30,
      complexity: arguments['complexity'] as String? ?? 'moderate',
      reasoning: arguments['reasoning'] as String? ?? '',
    );
  }

  JourneyPlan _parseJourneyPlan(
    String responseBody,
    String goalId,
    int selectedDays,
    int dailyMinutes,
  ) {
    final data = jsonDecode(responseBody);
    final choices = data['choices'] as List;
    final message = choices[0]['message'] as Map<String, dynamic>;
    final toolCalls = message['tool_calls'] as List;
    final toolCall = toolCalls[0] as Map<String, dynamic>;
    final function = toolCall['function'] as Map<String, dynamic>;
    final arguments =
        jsonDecode(function['arguments'] as String) as Map<String, dynamic>;

    // Parse milestones
    final milestonesJson = arguments['milestones'] as List? ?? [];
    final milestones = milestonesJson.asMap().entries.map((entry) {
      final m = entry.value as Map<String, dynamic>;
      return JourneyMilestone(
        id: '${goalId}_m${entry.key}',
        title: m['title'] as String? ?? 'Milestone ${entry.key + 1}',
        description: m['description'] as String? ?? '',
        startDay: m['start_day'] as int? ?? 1,
        endDay: m['end_day'] as int? ?? selectedDays,
        phase: m['phase'] as String? ?? 'building',
        keyOutcomes: (m['key_outcomes'] as List?)
                ?.map((o) => o.toString())
                .toList() ??
            [],
      );
    }).toList();

    // Parse anchor
    HabitAnchor? anchor;
    if (arguments['primary_anchor'] != null) {
      final a = arguments['primary_anchor'] as Map<String, dynamic>;
      anchor = HabitAnchor(
        trigger: a['trigger'] as String? ?? 'After waking up',
        action: a['action'] as String? ?? 'Open the app',
        timeOfDay: a['time_of_day'] as String? ?? 'morning',
      );
    }

    return JourneyPlan(
      id: '${goalId}_journey',
      goalId: goalId,
      commitmentStatement: arguments['commitment_prompt'] as String?,
      milestones: milestones,
      primaryAnchor: anchor,
      estimatedDaysTotal: selectedDays,
      difficulty: arguments['difficulty'] as String? ?? 'moderate',
      createdAt: DateTime.now(),
      dailyMinutesCommitted: dailyMinutes,
    );
  }

  JourneyPlan _createFallbackPlan(
    Goal goal,
    int selectedDays,
    int dailyMinutes,
  ) {
    // Create simple 3-milestone fallback
    final milestoneDuration = (selectedDays / 3).round();

    return JourneyPlan(
      id: '${goal.id}_journey',
      goalId: goal.id,
      milestones: [
        JourneyMilestone(
          id: '${goal.id}_m0',
          title: 'Getting Started',
          description: 'Build the foundation and daily habit',
          startDay: 1,
          endDay: milestoneDuration,
          phase: 'foundation',
          keyOutcomes: ['Establish daily practice', 'Learn the basics'],
        ),
        JourneyMilestone(
          id: '${goal.id}_m1',
          title: 'Making Progress',
          description: 'Build on your foundation',
          startDay: milestoneDuration + 1,
          endDay: milestoneDuration * 2,
          phase: 'building',
          keyOutcomes: ['Consistent practice', 'Noticeable improvement'],
        ),
        JourneyMilestone(
          id: '${goal.id}_m2',
          title: 'Crossing the Finish Line',
          description: 'Push through to achieve your goal',
          startDay: milestoneDuration * 2 + 1,
          endDay: selectedDays,
          phase: 'finishing',
          keyOutcomes: ['Reach your goal', 'Celebrate success'],
        ),
      ],
      estimatedDaysTotal: selectedDays,
      createdAt: DateTime.now(),
      dailyMinutesCommitted: dailyMinutes,
    );
  }
}
