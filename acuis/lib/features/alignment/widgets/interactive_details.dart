import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../main.dart';
import '../../../models/goal.dart';
import '../../../models/todo.dart';
import '../../../models/smart_scores.dart';
import '../../../shared/services/velocity_service.dart';
import '../../../shared/services/streak_service.dart';
import '../../../shared/services/gamification_service.dart';
import '../../../shared/services/storage_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
// STREAK & LEVEL DETAIL
// ─────────────────────────────────────────────────────────────────────────────

void showStreakLevelDetail(
  BuildContext context, {
  required StreakService streakService,
  required GamificationService gamificationService,
  required List<Todo> todos,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _StreakLevelDetailSheet(
      streakService: streakService,
      gamificationService: gamificationService,
      todos: todos,
    ),
  );
}

class _StreakLevelDetailSheet extends StatefulWidget {
  final StreakService streakService;
  final GamificationService gamificationService;
  final List<Todo> todos;

  const _StreakLevelDetailSheet({
    required this.streakService,
    required this.gamificationService,
    required this.todos,
  });

  @override
  State<_StreakLevelDetailSheet> createState() => _StreakLevelDetailSheetState();
}

class _StreakLevelDetailSheetState extends State<_StreakLevelDetailSheet> {
  String? _aiMotivation;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAIMotivation();
  }

  Future<void> _fetchAIMotivation() async {
    final apiKey = StorageService().loadApiKeySync() ?? '';
    if (apiKey.isEmpty) {
      setState(() {
        _aiMotivation = _getLocalMotivation();
        _loading = false;
      });
      return;
    }

    final streak = widget.streakService.getCurrentStreak();
    final level = widget.gamificationService.getLevel();
    final points = widget.gamificationService.getTotalPoints();
    final completedToday = widget.todos.where((t) {
      final today = DateTime.now();
      return t.completed &&
          t.completedAt != null &&
          t.completedAt!.year == today.year &&
          t.completedAt!.month == today.month &&
          t.completedAt!.day == today.day;
    }).length;

    try {
      final response = await http.post(
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'mistralai/mistral-small-4-119b-2603',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a motivating productivity coach. Give a short (2-3 sentences), encouraging message based on the user\'s streak and progress. Be personal and uplifting. No emojis in response.'
            },
            {
              'role': 'user',
              'content': 'My stats: $streak day streak, Level $level, $points total points, completed $completedToday tasks today. Give me motivation!'
            }
          ],
          'max_tokens': 150,
          'temperature': 0.8,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        setState(() {
          _aiMotivation = content.trim();
          _loading = false;
        });
      } else {
        setState(() {
          _aiMotivation = _getLocalMotivation();
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _aiMotivation = _getLocalMotivation();
        _loading = false;
      });
    }
  }

  String _getLocalMotivation() {
    final streak = widget.streakService.getCurrentStreak();
    if (streak == 0) return 'Start your streak today! Every journey begins with a single step.';
    if (streak < 3) return 'You\'re building momentum! Keep going, consistency is key.';
    if (streak < 7) return 'Great progress! You\'re developing a powerful habit.';
    if (streak < 14) return 'Impressive dedication! Your consistency is paying off.';
    return 'Amazing streak! You\'re unstoppable. Keep crushing it!';
  }

  @override
  Widget build(BuildContext context) {
    final streak = widget.streakService.getCurrentStreak();
    final longestStreak = widget.streakService.getLongestStreak();
    final level = widget.gamificationService.getLevel();
    final points = widget.gamificationService.getTotalPoints();
    final levelProgress = widget.gamificationService.getLevelProgress();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(24),
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('🔥', style: TextStyle(fontSize: 32)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Streak & Level',
                              style: GoogleFonts.comfortaa(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          Text('Your consistency journey',
                              style: GoogleFonts.comfortaa(fontSize: 12, color: AppColors.inkFaint)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Streak visualization
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFFFF6B35).withValues(alpha: 0.1), AppColors.surface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 48)),
                          const SizedBox(width: 12),
                          Text('$streak',
                              style: GoogleFonts.comfortaa(
                                fontSize: 56,
                                fontWeight: FontWeight.w700,
                                color: streak > 0 ? const Color(0xFFFF6B35) : AppColors.inkFaint,
                              )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('day streak',
                          style: GoogleFonts.comfortaa(fontSize: 16, color: AppColors.inkLight)),
                      if (longestStreak > streak) ...[
                        const SizedBox(height: 8),
                        Text('Personal best: $longestStreak days',
                            style: GoogleFonts.comfortaa(fontSize: 12, color: AppColors.inkFaint)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Level progress
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('⭐', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Text('Level $level',
                              style: GoogleFonts.comfortaa(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          const Spacer(),
                          Text('$points pts',
                              style: GoogleFonts.comfortaa(fontSize: 12, color: AppColors.inkFaint)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: levelProgress,
                          minHeight: 8,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB700)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${(levelProgress * 100).round()}% to next level',
                          style: GoogleFonts.comfortaa(fontSize: 11, color: AppColors.inkFaint)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // AI Motivation
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 18, color: AppColors.ink),
                          const SizedBox(width: 8),
                          Text('AI Coach Says',
                              style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        Row(
                          children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Text('Thinking...', style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.inkLight)),
                          ],
                        )
                      else
                        Text(_aiMotivation ?? '',
                            style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink, height: 1.6)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VELOCITY DETAIL
// ─────────────────────────────────────────────────────────────────────────────

void showVelocityDetail(
  BuildContext context, {
  required VelocityService velocityService,
  required List<Todo> todos,
  required List<Goal> goals,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _VelocityDetailSheet(
      velocityService: velocityService,
      todos: todos,
      goals: goals,
    ),
  );
}

class _VelocityDetailSheet extends StatefulWidget {
  final VelocityService velocityService;
  final List<Todo> todos;
  final List<Goal> goals;

  const _VelocityDetailSheet({
    required this.velocityService,
    required this.todos,
    required this.goals,
  });

  @override
  State<_VelocityDetailSheet> createState() => _VelocityDetailSheetState();
}

class _VelocityDetailSheetState extends State<_VelocityDetailSheet> {
  String? _aiAnalysis;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAIAnalysis();
  }

  Future<void> _fetchAIAnalysis() async {
    final apiKey = StorageService().loadApiKeySync() ?? '';
    final thisWeekVelocity = widget.velocityService.getVelocity(7);
    final lastWeekVelocity = widget.velocityService.getVelocity(14) - thisWeekVelocity;

    if (apiKey.isEmpty) {
      setState(() {
        _aiAnalysis = _getLocalAnalysis(thisWeekVelocity, lastWeekVelocity);
        _loading = false;
      });
      return;
    }

    final completedThisWeek = widget.todos.where((t) {
      if (!t.completed || t.completedAt == null) return false;
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      return t.completedAt!.isAfter(weekAgo);
    }).length;

    try {
      final response = await http.post(
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'mistralai/mistral-small-4-119b-2603',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a productivity analyst. Analyze the velocity data and give 2-3 specific, actionable insights to improve productivity. Be concise and practical.'
            },
            {
              'role': 'user',
              'content': 'My velocity: this week=${thisWeekVelocity.toStringAsFixed(1)}, last week=${lastWeekVelocity.toStringAsFixed(1)}. Completed $completedThisWeek tasks this week. ${widget.goals.length} active goals. Give me insights.'
            }
          ],
          'max_tokens': 200,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        setState(() {
          _aiAnalysis = content.trim();
          _loading = false;
        });
      } else {
        setState(() {
          _aiAnalysis = _getLocalAnalysis(thisWeekVelocity, lastWeekVelocity);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _aiAnalysis = _getLocalAnalysis(thisWeekVelocity, lastWeekVelocity);
        _loading = false;
      });
    }
  }

  String _getLocalAnalysis(double thisWeek, double lastWeek) {
    if (thisWeek > lastWeek * 1.2) {
      return 'Great momentum! You\'re ${((thisWeek / lastWeek - 1) * 100).round()}% more productive this week. Keep this pace!';
    } else if (thisWeek < lastWeek * 0.8) {
      return 'Velocity dropped this week. Consider breaking large tasks into smaller ones and focusing on high-impact items.';
    } else {
      return 'Steady progress! To accelerate, try time-blocking your most important tasks during peak energy hours.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final thisWeekVelocity = widget.velocityService.getVelocity(7);
    final lastWeekVelocity = widget.velocityService.getVelocity(14) - thisWeekVelocity;
    final monthVelocity = widget.velocityService.getVelocity(30);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(24),
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.speed, size: 28, color: Color(0xFF2196F3)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Velocity Analysis',
                              style: GoogleFonts.comfortaa(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          Text('Your productivity pulse',
                              style: GoogleFonts.comfortaa(fontSize: 12, color: AppColors.inkFaint)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Velocity cards
                Row(
                  children: [
                    Expanded(
                      child: _VelocityCard(
                        label: 'This Week',
                        value: thisWeekVelocity.toStringAsFixed(1),
                        color: const Color(0xFF43A047),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _VelocityCard(
                        label: 'Last Week',
                        value: lastWeekVelocity.toStringAsFixed(1),
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _VelocityCard(
                  label: '30-Day Average',
                  value: monthVelocity.toStringAsFixed(1),
                  color: const Color(0xFF2196F3),
                  fullWidth: true,
                ),
                const SizedBox(height: 24),

                // Trend indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        thisWeekVelocity >= lastWeekVelocity ? Icons.trending_up : Icons.trending_down,
                        color: thisWeekVelocity >= lastWeekVelocity ? const Color(0xFF43A047) : const Color(0xFFE53935),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              thisWeekVelocity >= lastWeekVelocity ? 'Accelerating' : 'Slowing Down',
                              style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                            ),
                            Text(
                              lastWeekVelocity > 0
                                  ? '${((thisWeekVelocity - lastWeekVelocity) / lastWeekVelocity * 100).abs().round()}% vs last week'
                                  : 'Building baseline',
                              style: GoogleFonts.comfortaa(fontSize: 11, color: AppColors.inkFaint),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // AI Analysis
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 18, color: AppColors.ink),
                          const SizedBox(width: 8),
                          Text('AI Insights',
                              style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        Row(
                          children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Text('Analyzing...', style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.inkLight)),
                          ],
                        )
                      else
                        Text(_aiAnalysis ?? '',
                            style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.ink, height: 1.6)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VelocityCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;

  const _VelocityCard({
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: fullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(value,
              style: GoogleFonts.comfortaa(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.comfortaa(fontSize: 11, color: AppColors.inkFaint)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMART IMPROVER DETAIL
// ─────────────────────────────────────────────────────────────────────────────

void showSMARTDetail(
  BuildContext context, {
  required List<Todo> scoredTodos,
  required void Function(List<Todo>) onDataChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _SMARTDetailSheet(
      scoredTodos: scoredTodos,
      onDataChanged: onDataChanged,
    ),
  );
}

class _SMARTDetailSheet extends StatefulWidget {
  final List<Todo> scoredTodos;
  final void Function(List<Todo>) onDataChanged;

  const _SMARTDetailSheet({
    required this.scoredTodos,
    required this.onDataChanged,
  });

  @override
  State<_SMARTDetailSheet> createState() => _SMARTDetailSheetState();
}

class _SMARTDetailSheetState extends State<_SMARTDetailSheet> {
  Todo? _selectedTodo;
  String? _aiSuggestion;
  bool _loading = false;

  Future<void> _getAISuggestion(Todo todo) async {
    setState(() {
      _selectedTodo = todo;
      _loading = true;
      _aiSuggestion = null;
    });

    final apiKey = StorageService().loadApiKeySync() ?? '';
    if (apiKey.isEmpty) {
      setState(() {
        _aiSuggestion = _getLocalSuggestion(todo);
        _loading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'mistralai/mistral-small-4-119b-2603',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a task improvement expert. Given a task and its SMART scores, suggest specific improvements. Be concise (2-3 sentences).'
            },
            {
              'role': 'user',
              'content': 'Task: "${todo.title}"\nSMART scores: S=${todo.smartScores?.specificity.round()}, M=${todo.smartScores?.measurability.round()}, A=${todo.smartScores?.achievability.round()}, R=${todo.smartScores?.relevance.round()}, T=${todo.smartScores?.timeBound.round()}. Suggest improvements.'
            }
          ],
          'max_tokens': 150,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        setState(() {
          _aiSuggestion = content.trim();
          _loading = false;
        });
      } else {
        setState(() {
          _aiSuggestion = _getLocalSuggestion(todo);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _aiSuggestion = _getLocalSuggestion(todo);
        _loading = false;
      });
    }
  }

  String _getLocalSuggestion(Todo todo) {
    final scores = todo.smartScores;
    if (scores == null) return 'Analyze this task to get SMART scores.';

    final lowestDimension = <String, double>{
      'Specific': scores.specificity,
      'Measurable': scores.measurability,
      'Achievable': scores.achievability,
      'Relevant': scores.relevance,
      'Time-bound': scores.timeBound,
    }.entries.reduce((a, b) => a.value < b.value ? a : b);

    return 'Your task scores lowest on "${lowestDimension.key}". Focus on improving this dimension for better task clarity.';
  }

  @override
  Widget build(BuildContext context) {
    final todosWithSMART = widget.scoredTodos.where((t) => t.smartScores != null).toList();
    final avgSMART = todosWithSMART.isEmpty ? null : SMARTScores(
      specificity: todosWithSMART.map((t) => t.smartScores!.specificity).reduce((a, b) => a + b) / todosWithSMART.length,
      measurability: todosWithSMART.map((t) => t.smartScores!.measurability).reduce((a, b) => a + b) / todosWithSMART.length,
      achievability: todosWithSMART.map((t) => t.smartScores!.achievability).reduce((a, b) => a + b) / todosWithSMART.length,
      relevance: todosWithSMART.map((t) => t.smartScores!.relevance).reduce((a, b) => a + b) / todosWithSMART.length,
      timeBound: todosWithSMART.map((t) => t.smartScores!.timeBound).reduce((a, b) => a + b) / todosWithSMART.length,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(24),
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.psychology, size: 28, color: Color(0xFF9C27B0)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SMART Improver',
                              style: GoogleFonts.comfortaa(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          Text('AI-powered task refinement',
                              style: GoogleFonts.comfortaa(fontSize: 12, color: AppColors.inkFaint)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Overall SMART
                if (avgSMART != null) ...[
                  Text('Average SMART Scores',
                      style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 12),
                  _buildSMARTBar('Specific', avgSMART.specificity, const Color(0xFF4CAF50)),
                  const SizedBox(height: 8),
                  _buildSMARTBar('Measurable', avgSMART.measurability, const Color(0xFF2196F3)),
                  const SizedBox(height: 8),
                  _buildSMARTBar('Achievable', avgSMART.achievability, const Color(0xFFFF9800)),
                  const SizedBox(height: 8),
                  _buildSMARTBar('Relevant', avgSMART.relevance, const Color(0xFF9C27B0)),
                  const SizedBox(height: 8),
                  _buildSMARTBar('Time-bound', avgSMART.timeBound, const Color(0xFFF44336)),
                  const SizedBox(height: 24),
                ],

                // Task list
                Text('Select a task for AI suggestions',
                    style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 12),
                ...todosWithSMART.map((todo) => _buildTaskItem(todo)),

                if (_selectedTodo != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, size: 18, color: AppColors.ink),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('AI Suggestion for "${_selectedTodo!.title.length > 20 ? '${_selectedTodo!.title.substring(0, 20)}...' : _selectedTodo!.title}"',
                                  style: GoogleFonts.comfortaa(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_loading)
                          Row(
                            children: [
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: 12),
                              Text('Thinking...', style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.inkLight)),
                            ],
                          )
                        else
                          Text(_aiSuggestion ?? '',
                              style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.ink, height: 1.6)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSMARTBar(String label, double score, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: GoogleFonts.comfortaa(fontSize: 11, color: AppColors.inkLight)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 8, color: AppColors.chip),
                FractionallySizedBox(
                  widthFactor: score / 100,
                  child: Container(height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${score.round()}', style: GoogleFonts.comfortaa(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink)),
      ],
    );
  }

  Widget _buildTaskItem(Todo todo) {
    final isSelected = _selectedTodo?.id == todo.id;
    return GestureDetector(
      onTap: () => _getAISuggestion(todo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.ink.withValues(alpha: 0.05) : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.ink : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.task_alt, size: 18, color: AppColors.inkLight),
            const SizedBox(width: 12),
            Expanded(
              child: Text(todo.title,
                  style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${todo.smartScore.round()}%',
                  style: GoogleFonts.comfortaa(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.inkLight)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GOAL COACH DETAIL
// ─────────────────────────────────────────────────────────────────────────────

void showGoalCoachDetail(
  BuildContext context, {
  required Goal goal,
  required List<Todo> todos,
  required VelocityService velocityService,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _GoalCoachSheet(
      goal: goal,
      todos: todos,
      velocityService: velocityService,
    ),
  );
}

class _GoalCoachSheet extends StatefulWidget {
  final Goal goal;
  final List<Todo> todos;
  final VelocityService velocityService;

  const _GoalCoachSheet({
    required this.goal,
    required this.todos,
    required this.velocityService,
  });

  @override
  State<_GoalCoachSheet> createState() => _GoalCoachSheetState();
}

class _GoalCoachSheetState extends State<_GoalCoachSheet> {
  String? _aiCoaching;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAICoaching();
  }

  Future<void> _fetchAICoaching() async {
    final apiKey = StorageService().loadApiKeySync() ?? '';
    final goalTodos = widget.todos.where((t) => t.goalId == widget.goal.id).toList();
    final completed = goalTodos.where((t) => t.completed).length;
    final prediction = widget.velocityService.predictCompletion(widget.goal, goalTodos);

    if (apiKey.isEmpty) {
      setState(() {
        _aiCoaching = _getLocalCoaching(completed, goalTodos.length, prediction.hasReliablePrediction);
        _loading = false;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'mistralai/mistral-small-4-119b-2603',
          'messages': [
            {
              'role': 'system',
              'content': 'You are an encouraging goal coach. Give specific, actionable advice to help achieve the goal. Be concise (3-4 sentences).'
            },
            {
              'role': 'user',
              'content': 'Goal: "${widget.goal.title}" (${widget.goal.type.name}). Progress: $completed/${goalTodos.length} tasks. ${prediction.hasReliablePrediction ? "ETA: ${prediction.summary}" : "No prediction yet"}. Days remaining: ${widget.goal.daysRemaining}. Coach me!'
            }
          ],
          'max_tokens': 200,
          'temperature': 0.8,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        setState(() {
          _aiCoaching = content.trim();
          _loading = false;
        });
      } else {
        setState(() {
          _aiCoaching = _getLocalCoaching(completed, goalTodos.length, prediction.hasReliablePrediction);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _aiCoaching = _getLocalCoaching(completed, goalTodos.length, prediction.hasReliablePrediction);
        _loading = false;
      });
    }
  }

  String _getLocalCoaching(int completed, int total, bool hasPrediction) {
    final progress = total > 0 ? completed / total : 0.0;
    if (progress >= 0.8) return 'Almost there! Focus on completing the remaining tasks one at a time.';
    if (progress >= 0.5) return 'Great progress! Maintain momentum by working on this goal daily.';
    if (progress >= 0.2) return 'Good start! Break down larger tasks and celebrate small wins.';
    return 'Start with the easiest task to build momentum. Small steps lead to big achievements.';
  }

  @override
  Widget build(BuildContext context) {
    final goalTodos = widget.todos.where((t) => t.goalId == widget.goal.id).toList();
    final completed = goalTodos.where((t) => t.completed).length;
    final prediction = widget.velocityService.predictCompletion(widget.goal, goalTodos);
    final status = widget.velocityService.getGoalProgressStatus(widget.goal, goalTodos);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(24),
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.flag, size: 28, color: AppColors.ink),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Goal Coach',
                              style: GoogleFonts.comfortaa(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          Text(widget.goal.title,
                              style: GoogleFonts.comfortaa(fontSize: 12, color: AppColors.inkFaint),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Progress ring
                Center(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.ink.withValues(alpha: 0.1), AppColors.surface],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            value: goalTodos.isEmpty ? 0 : completed / goalTodos.length,
                            strokeWidth: 12,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation(_getStatusColor(status)),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${(goalTodos.isEmpty ? 0 : completed / goalTodos.length * 100).round()}%',
                                style: GoogleFonts.comfortaa(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.ink)),
                            Text('complete',
                                style: GoogleFonts.comfortaa(fontSize: 12, color: AppColors.inkFaint)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _GoalStatCard(
                        label: 'Tasks',
                        value: '$completed/${goalTodos.length}',
                        icon: Icons.task_alt,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GoalStatCard(
                        label: 'Days Left',
                        value: widget.goal.daysRemaining > 0 ? '${widget.goal.daysRemaining}' : '--',
                        icon: Icons.calendar_today,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GoalStatCard(
                        label: 'Type',
                        value: widget.goal.type == GoalType.shortTerm ? 'Short' : 'Long',
                        icon: Icons.timelapse,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Prediction
                if (prediction.hasReliablePrediction)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.insights, color: _getStatusColor(status)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Prediction',
                                  style: GoogleFonts.comfortaa(fontSize: 11, color: AppColors.inkFaint)),
                              Text(prediction.summary,
                                  style: GoogleFonts.comfortaa(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // AI Coaching
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 18, color: AppColors.ink),
                          const SizedBox(width: 8),
                          Text('AI Coach',
                              style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        Row(
                          children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Text('Coaching...', style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.inkLight)),
                          ],
                        )
                      else
                        Text(_aiCoaching ?? '',
                            style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink, height: 1.6)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(GoalProgressStatus status) {
    return switch (status) {
      GoalProgressStatus.onTrack => const Color(0xFF43A047),
      GoalProgressStatus.atRisk => const Color(0xFFFFA726),
      GoalProgressStatus.behind => const Color(0xFFE53935),
      GoalProgressStatus.noDeadline => AppColors.inkFaint,
      GoalProgressStatus.insufficientData => AppColors.inkFaint,
    };
  }
}

class _GoalStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _GoalStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.inkLight),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.comfortaa(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
          Text(label, style: GoogleFonts.comfortaa(fontSize: 10, color: AppColors.inkFaint)),
        ],
      ),
    );
  }
}
