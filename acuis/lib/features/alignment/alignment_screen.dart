import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../models/goal.dart';
import '../../models/todo.dart';
import '../../models/alignment_result.dart';
import '../../models/smart_scores.dart';
import '../../shared/services/ai_alignment_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/velocity_service.dart';
import '../../shared/services/gamification_service.dart';
import '../../shared/services/streak_service.dart';
import '../../shared/services/alignment_refresh_service.dart';
import '../../shared/services/nudge_service.dart';
import '../../shared/services/smart_defaults_service.dart';
import '../../shared/services/xp_tracking_service.dart';
import '../../shared/widgets/celebration_overlay.dart';
import '../../shared/widgets/quick_add_todo_dialog.dart';
import '../../shared/widgets/ambient_animations.dart' hide FloatingIcon;
import 'widgets/eisenhower_quadrant.dart';
import 'widgets/science_backed_growth_chart.dart';
import 'widgets/smart_radar_chart.dart';
import 'widgets/alignment_detail_sheet.dart';
import 'widgets/velocity_insights.dart' as widgets;
import 'widgets/interactive_details.dart';

class AlignmentScreen extends StatefulWidget {
  final List<Goal> goals;
  final List<Todo> todos;
  final AlignmentRefreshService refreshService;
  final void Function(List<Todo> updatedTodos) onDataChanged;
  final void Function(Todo) onAddTodo;

  const AlignmentScreen({
    super.key,
    required this.goals,
    required this.todos,
    required this.refreshService,
    required this.onDataChanged,
    required this.onAddTodo,
  });

  @override
  State<AlignmentScreen> createState() => _AlignmentScreenState();
}

class _AlignmentScreenState extends State<AlignmentScreen> {
  final _storage = StorageService();
  bool _isAnalyzing = false;
  String _apiKey = '';
  VelocityService? _velocityService;
  GamificationService? _gamificationService;
  StreakService? _streakService;
  late NudgeService _nudgeService;
  XPTrackingService? _xpTrackingService;
  int _lastRefreshVersion = 0;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _apiKey = _storage.loadApiKeySync() ?? '';
    _nudgeService = NudgeService();
    _initServices();
    widget.refreshService.addListener(_onRefreshTriggered);
  }

  @override
  void dispose() {
    widget.refreshService.removeListener(_onRefreshTriggered);
    _nudgeService.dispose();
    super.dispose();
  }

  void _updateNudges() {
    if (!_servicesInitialized) return;

    // Update unanalyzed todos count
    final linkedTodos = widget.todos.where((t) => t.goalId != null).toList();
    final unanalyzedCount = linkedTodos.where((t) => t.alignmentScore == null).length;
    _nudgeService.updateUnanalyzedCount(unanalyzedCount);

    // Check streak risk
    final today = DateTime.now();
    final completedToday = widget.todos.where((t) {
      return t.completed &&
             t.createdAt.year == today.year &&
             t.createdAt.month == today.month &&
             t.createdAt.day == today.day;
    }).length;

    final currentStreak = _streakService!.getCurrentStreak();
    _nudgeService.checkStreakRisk(completedToday == 0 && currentStreak > 0, currentStreak);

    // Update time-based nudges
    final highImpactTodos = linkedTodos.where((t) =>
      !t.completed && (t.alignmentScore ?? 0) >= 75
    ).length;
    _nudgeService.updateTimeBasedNudges(highImpactTodos, completedToday);
  }

  void _onRefreshTriggered() {
    // Only refresh if version changed and we have API key
    if (widget.refreshService.refreshVersion != _lastRefreshVersion &&
        _apiKey.isNotEmpty &&
        !_isAnalyzing) {
      _lastRefreshVersion = widget.refreshService.refreshVersion;

      // Check if there are unanalyzed linked todos
      final linkedTodos = widget.todos.where((t) => t.goalId != null).toList();
      final unanalyzedTodos = linkedTodos.where((t) => t.alignmentScore == null).toList();

      if (unanalyzedTodos.isNotEmpty) {
        _analyze(autoRefresh: true);
      }
    }
  }

  Future<void> _initServices() async {
    _streakService = await StreakService.init();
    _velocityService = await VelocityService.init();
    _gamificationService = await GamificationService.init();
    _xpTrackingService = await XPTrackingService.init();

    // Clean up deleted todos from XP tracking
    await _xpTrackingService!.cleanupDeletedTodos(
      widget.todos.map((t) => t.id).toList(),
    );

    if (mounted) {
      setState(() {
        _servicesInitialized = true;
      });
      _updateNudges();
    }
  }

  Future<void> _analyze({bool autoRefresh = false}) async {
    if (_apiKey.isEmpty) {
      if (!autoRefresh) {
        _showSettingsSheet(context);
      }
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final service = AIAlignmentService(apiKey: _apiKey);

      // Build context with velocity data
      final velocity = _velocityService!.getVelocity(7);
      final context = ScoringContext(
        velocity: velocity,
        daysUntilTarget: widget.goals.isNotEmpty
            ? widget.goals.first.daysRemaining
            : 30,
        currentStreak: _streakService!.getCurrentStreak(),
      );

      final results = await service.analyzeAll(widget.todos, widget.goals, context: context);

      // Build a new list with updated scores
      final updatedTodos = widget.todos.map((todo) {
        if (results.containsKey(todo.id)) {
          final result = results[todo.id]!;
          return todo.copyWith(
            alignmentScore: result.score,
            alignmentExplanation: result.explanation,
            smartScores: result.smartScores,
            eisenhowerClass: result.eisenhowerClass,
            estimatedEffort: result.estimatedEffort?.index != null
                ? result.estimatedEffort!.index + 1
                : todo.estimatedEffort,
            improvementSuggestion: result.suggestion,
          );
        }
        return todo;
      }).toList();

      widget.onDataChanged(updatedTodos);

      // Only check for celebrations on manual refresh
      if (!autoRefresh) {
        _checkCelebrations(updatedTodos);
      }

      // Record velocity snapshot
      await _velocityService!.recordDaySnapshot(updatedTodos);
    } catch (e) {
      // Only show error on manual refresh
      if (mounted && !autoRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _checkCelebrations(List<Todo> todos) {
    if (!_servicesInitialized) return;

    // Check for high alignment completions
    for (final todo in todos.where((t) => t.completed)) {
      // Skip if this todo has already been rewarded
      if (_xpTrackingService!.hasBeenRewarded(todo.id)) continue;

      final goal = widget.goals.firstWhere(
        (g) => g.id == todo.goalId,
        orElse: () => widget.goals.first,
      );

      final celebration = _gamificationService!.checkCelebration(todo, goal);
      if (celebration != null) {
        showCelebration(context, celebration);

        // Mark as rewarded before adding points to prevent duplicates
        _xpTrackingService!.markTodoAsRewarded(todo.id);

        // Add points
        final levelUp = _gamificationService!.addPoints(celebration.points);
        if (levelUp != null) {
          // Show level up after celebration
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              showCelebration(
                context,
                Celebration.levelUp(level: levelUp.newLevel, points: levelUp.totalPoints),
              );
            }
          });
        }
        break; // Only show one celebration at a time
      }
    }

    // Check for achievements
    final newAchievements = _gamificationService!.checkAchievements(widget.goals, todos);
    if (newAchievements.isNotEmpty) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          showCelebration(
            context,
            Celebration.achievementUnlocked(newAchievements.first),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkedTodos = widget.todos.where((t) => t.goalId != null).toList();
    final scoredTodos = linkedTodos.where((t) => t.alignmentScore != null).toList();

    double overallScore = 0;
    if (scoredTodos.isNotEmpty) {
      overallScore = scoredTodos.map((t) => t.alignmentScore!).reduce((a, b) => a + b) / scoredTodos.length;
    }

    // Update nudges on every build
    _updateNudges();

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: widget.goals.isNotEmpty ? _buildQuickAddFAB() : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            // Show nudge banner if applicable
            if (_nudgeService.unanalyzedTodosCount > 0 || _nudgeService.streakAtRisk)
              _buildNudgeBanner(),
            if (widget.goals.isEmpty || widget.todos.isEmpty)
              _buildEmpty()
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    if (!_isAnalyzing && _apiKey.isNotEmpty) {
                      await _analyze();
                    }
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                    GestureDetector(
                      onTap: () => showAlignmentDetail(
                        context,
                        widget.goals,
                        widget.todos,
                        overallScore,
                      ),
                      child: _buildScoreCard(overallScore, scoredTodos.length, linkedTodos.length),
                    ),
                    const SizedBox(height: 24),

                    // Streak & Level card
                    if (_servicesInitialized)
                      GestureDetector(
                        onTap: () => showStreakLevelDetail(
                          context,
                          streakService: _streakService!,
                          gamificationService: _gamificationService!,
                          todos: widget.todos,
                        ),
                        child: _buildStreakLevelCard(),
                      ),

                    if (_servicesInitialized)
                      const SizedBox(height: 24),

                    // Velocity Insights
                    if (_servicesInitialized)
                      GestureDetector(
                        onTap: () => showVelocityDetail(
                          context,
                          velocityService: _velocityService!,
                          todos: widget.todos,
                          goals: widget.goals,
                        ),
                        child: widgets.VelocityInsights(
                          todos: widget.todos,
                          velocityService: _velocityService!,
                        ),
                      ),

                    if (_servicesInitialized)
                      const SizedBox(height: 24),

                    // Eisenhower Quadrant (replaces Impact Quadrant)
                    EisenhowerQuadrant(
                      todos: linkedTodos,
                      onReclassify: (todo, newClass) {
                        final updated = widget.todos.map((t) {
                          if (t.id == todo.id) {
                            return t.copyWith(eisenhowerClass: newClass);
                          }
                          return t;
                        }).toList();
                        widget.onDataChanged(updated);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Growth Charts per goal
                    Text('Progress Charts',
                        style: GoogleFonts.comfortaa(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    const SizedBox(height: 4),
                    Text('Velocity-based projections with confidence',
                        style: GoogleFonts.comfortaa(
                            fontSize: 12, color: AppColors.inkFaint)),
                    const SizedBox(height: 12),

                    if (_servicesInitialized)
                      ...widget.goals.map((goal) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ScienceBackedGrowthChart(
                          goal: goal,
                          todos: widget.todos,
                          velocityService: _velocityService!,
                        ),
                      )),

                    const SizedBox(height: 24),

                    // SMART breakdown for goals
                    if (scoredTodos.any((t) => t.smartScores != null))
                      GestureDetector(
                        onTap: () => showSMARTDetail(
                          context,
                          scoredTodos: scoredTodos,
                          onDataChanged: widget.onDataChanged,
                        ),
                        child: _buildSMARTBreakdown(scoredTodos),
                      ),

                    const SizedBox(height: 24),

                    // Goals Breakdown
                    Text('Goals Breakdown',
                        style: GoogleFonts.comfortaa(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    const SizedBox(height: 4),
                    Text('Tap a goal for coaching',
                        style: GoogleFonts.comfortaa(
                            fontSize: 11, color: AppColors.inkFaint)),
                    const SizedBox(height: 12),
                    if (_servicesInitialized)
                      ...widget.goals.map((goal) => GestureDetector(
                        onTap: () => showGoalCoachDetail(
                          context,
                          goal: goal,
                          todos: widget.todos,
                          velocityService: _velocityService!,
                        ),
                        child: _buildGoalStatsCard(goal),
                      )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alignment',
                      style: GoogleFonts.comfortaa(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.1,
                      )),
                  const SizedBox(height: 3),
                  Text('Science-backed goal alignment',
                      style: GoogleFonts.comfortaa(
                          fontSize: 12, color: AppColors.inkLight)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_nudgeService.unanalyzedTodosCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_nudgeService.unanalyzedTodosCount}',
                      style: GoogleFonts.comfortaa(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: _isAnalyzing ? null : _analyze,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.inkLight,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, color: AppColors.ink),
                ),
                IconButton(
                  onPressed: () => _showSettingsSheet(context),
                  icon: const Icon(Icons.settings_outlined, color: AppColors.ink),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildNudgeBanner() {
    String message = '';
    IconData icon = Icons.info_outline;
    Color bgColor = const Color(0xFFFFF3E0);
    Color textColor = const Color(0xFFE65100);

    if (_nudgeService.streakAtRisk && _servicesInitialized) {
      final streak = _streakService!.getCurrentStreak();
      message = 'Don\'t break your $streak-day streak! Complete 1 todo to keep it alive.';
      icon = Icons.local_fire_department_outlined;
      bgColor = const Color(0xFFFFEBEE);
      textColor = const Color(0xFFC62828);
    } else if (_nudgeService.unanalyzedTodosCount > 0) {
      message = 'You have ${_nudgeService.unanalyzedTodosCount} unanalyzed todos. Tap refresh to analyze.';
      icon = Icons.analytics_outlined;
    }

    if (message.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.comfortaa(
                fontSize: 12,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.analytics_outlined, size: 64, color: AppColors.border),
              const SizedBox(height: 20),
              Text('Not enough data',
                  style: GoogleFonts.comfortaa(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkLight,
                  )),
              const SizedBox(height: 4),
              Text('Add goals and link todos to see alignment',
                  style: GoogleFonts.comfortaa(
                      fontSize: 12, color: AppColors.inkFaint)),
            ],
          ),
        ),
      );

  Widget _buildScoreCard(double score, int scoredCount, int linkedCount) {
    String milestone = '';

    if (score >= 90) {
      milestone = 'Perfectly Aligned';
    } else if (score >= 75) {
      milestone = 'Great Alignment';
    } else if (score >= 50) {
      milestone = 'Good Progress';
    } else if (score > 0) {
      milestone = 'Getting Started';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedProgressRing(
                value: score,
                size: 80,
                strokeWidth: 8,
                child: AnimatedCounter(
                  value: score.round(),
                  suffix: '%',
                  style: GoogleFonts.comfortaa(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall Alignment',
                        style: GoogleFonts.comfortaa(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    const SizedBox(height: 6),
                    Text('$scoredCount of $linkedCount linked todos analyzed',
                        style: GoogleFonts.comfortaa(
                            fontSize: 12, color: AppColors.inkFaint, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          if (milestone.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(milestone,
                  style: GoogleFonts.comfortaa(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Tap for detailed analysis',
                  style: GoogleFonts.comfortaa(
                      fontSize: 11, color: AppColors.inkFaint)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 10, color: AppColors.inkFaint),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakLevelCard() {
    final streak = _streakService!.getCurrentStreak();
    final longestStreak = _streakService!.getLongestStreak();
    final level = _gamificationService!.getLevel();
    final points = _gamificationService!.getTotalPoints();
    final levelProgress = _gamificationService!.getLevelProgress();
    final streakAtRisk = _nudgeService.streakAtRisk;

    Widget cardContent = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: streakAtRisk ? const Color(0xFFFF6B35).withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Streak
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: streakAtRisk ? 28 : 24,
                          color: streak > 0 ? const Color(0xFFFF6B35) : AppColors.inkFaint,
                        ),
                        const SizedBox(width: 6),
                        AnimatedCounter(
                          value: streak,
                          style: GoogleFonts.comfortaa(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: streak > 0 ? const Color(0xFFFF6B35) : AppColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'day streak',
                      style: GoogleFonts.comfortaa(
                        fontSize: 11,
                        color: AppColors.inkFaint,
                      ),
                    ),
                    if (longestStreak > streak)
                      Text(
                        'Best: $longestStreak',
                        style: GoogleFonts.comfortaa(
                          fontSize: 9,
                          color: AppColors.inkFaint,
                        ),
                      ),
                  ],
                ),
              ),

              // Divider
              Container(
                width: 1,
                height: 50,
                color: AppColors.border,
              ),

              // Level
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, size: 20, color: Color(0xFFFFB700)),
                        const SizedBox(width: 4),
                        Text(
                          'Lv.$level',
                          style: GoogleFonts.comfortaa(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AnimatedProgressBar(
                      value: levelProgress,
                      height: 4,
                      color: const Color(0xFFFFB700),
                    ),
                    const SizedBox(height: 2),
                    AnimatedCounter(
                      value: points,
                      suffix: ' pts',
                      style: GoogleFonts.comfortaa(
                        fontSize: 9,
                        color: AppColors.inkFaint,
                      ),
                      duration: const Duration(milliseconds: 600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Tap for insights',
                  style: GoogleFonts.comfortaa(fontSize: 10, color: AppColors.inkFaint)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios_rounded, size: 8, color: AppColors.inkFaint),
            ],
          ),
        ],
      ),
    );

    // Wrap in pulsing glow if streak is at risk
    if (streakAtRisk && streak > 0) {
      return PulsingGlow(
        glowColor: const Color(0xFFFF6B35),
        maxGlowRadius: 8,
        child: cardContent,
      );
    }
    return cardContent;
  }

  Widget _buildSMARTBreakdown(List<Todo> scoredTodos) {
    final todosWithSMART = scoredTodos.where((t) => t.smartScores != null).toList();
    if (todosWithSMART.isEmpty) return const SizedBox.shrink();

    // Calculate average SMART scores
    final avgSMART = SMARTScores(
      specificity: todosWithSMART.map((t) => t.smartScores!.specificity).reduce((a, b) => a + b) / todosWithSMART.length,
      measurability: todosWithSMART.map((t) => t.smartScores!.measurability).reduce((a, b) => a + b) / todosWithSMART.length,
      achievability: todosWithSMART.map((t) => t.smartScores!.achievability).reduce((a, b) => a + b) / todosWithSMART.length,
      relevance: todosWithSMART.map((t) => t.smartScores!.relevance).reduce((a, b) => a + b) / todosWithSMART.length,
      timeBound: todosWithSMART.map((t) => t.smartScores!.timeBound).reduce((a, b) => a + b) / todosWithSMART.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('SMART Analysis',
                style: GoogleFonts.comfortaa(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Average',
                style: GoogleFonts.comfortaa(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkLight),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              SMARTRadarChart(
                scores: avgSMART,
                size: 140,
                showLabels: true,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSMARTBar('Specific', avgSMART.specificity, const Color(0xFF4CAF50)),
                    const SizedBox(height: 8),
                    _buildSMARTBar('Measurable', avgSMART.measurability, const Color(0xFF2196F3)),
                    const SizedBox(height: 8),
                    _buildSMARTBar('Achievable', avgSMART.achievability, const Color(0xFFFF9800)),
                    const SizedBox(height: 8),
                    _buildSMARTBar('Relevant', avgSMART.relevance, const Color(0xFF9C27B0)),
                    const SizedBox(height: 8),
                    _buildSMARTBar('Time-Bound', avgSMART.timeBound, const Color(0xFFF44336)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Tap for task suggestions',
                style: GoogleFonts.comfortaa(fontSize: 10, color: AppColors.inkFaint)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios_rounded, size: 8, color: AppColors.inkFaint),
          ],
        ),
      ],
    );
  }

  Widget _buildSMARTBar(String label, double score, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.comfortaa(
              fontSize: 10,
              color: AppColors.inkLight,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  color: AppColors.chip,
                ),
                FractionallySizedBox(
                  widthFactor: score / 100,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${score.round()}',
          style: GoogleFonts.comfortaa(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalStatsCard(Goal goal) {
    final goalTodos = widget.todos.where((t) => t.goalId == goal.id).toList();
    final completed = goalTodos.where((t) => t.completed).length;

    final scoredTodos = goalTodos.where((t) => t.alignmentScore != null).toList();
    double avgScore = 0;
    if (scoredTodos.isNotEmpty) {
      avgScore = scoredTodos.map((t) => t.alignmentScore!).reduce((a, b) => a + b) / scoredTodos.length;
    }

    // Get velocity prediction
    final prediction = _velocityService!.predictCompletion(goal, goalTodos);
    final status = _velocityService!.getGoalProgressStatus(goal, goalTodos);
    final progress = goalTodos.isEmpty ? 0.0 : completed / goalTodos.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(goal.title,
                    style: GoogleFonts.comfortaa(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
              ),
              if (scoredTodos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.chip,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${avgScore.round()}% aligned',
                      style: GoogleFonts.comfortaa(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkLight)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progress',
                        style: GoogleFonts.comfortaa(
                            fontSize: 11, color: AppColors.inkFaint)),
                    const SizedBox(height: 4),
                    AnimatedProgressBar(
                      value: progress,
                      height: 4,
                      color: _getStatusColor(status),
                    ),
                    const SizedBox(height: 6),
                    Text('$completed of ${goalTodos.length} todos done',
                        style: GoogleFonts.comfortaa(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkLight)),
                  ],
                ),
              ),
              if (prediction.hasReliablePrediction) ...[
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Prediction',
                        style: GoogleFonts.comfortaa(
                            fontSize: 11, color: AppColors.inkFaint)),
                    const SizedBox(height: 4),
                    Text(prediction.summary,
                        style: GoogleFonts.comfortaa(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _getStatusColor(status))),
                  ],
                ),
              ],
            ],
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

  Widget _buildQuickAddFAB() {
    // Find most active goal (goal with most todos)
    String? mostActiveGoalId;
    if (widget.goals.isNotEmpty) {
      mostActiveGoalId = SmartDefaultsService.getSmartGoalSuggestion(
        widget.goals,
        widget.todos,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FloatingActionButton(
        onPressed: () {
          showQuickAddTodoDialog(
            context,
            goals: widget.goals,
            todos: widget.todos,
            onAdd: widget.onAddTodo,
            preselectedGoalId: mostActiveGoalId,
          );
        },
        backgroundColor: AppColors.ink,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 22),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    final keyCtrl = TextEditingController(text: _apiKey);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 36,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 22),
            Text('AI Api Settings',
                style: GoogleFonts.comfortaa(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text('Enter your AI API key to enable SMART-based alignment scoring using Mistral (119B).',
                style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.inkLight, height: 1.4)),
            const SizedBox(height: 20),
            TextField(
              controller: keyCtrl,
              obscureText: true,
              style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Enter API Key (sk-...)',
                hintStyle: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.inkFaint),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                final key = keyCtrl.text.trim();
                await _storage.saveApiKey(key);
                setState(() => _apiKey = key);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: Text('Save Key',
                      style: GoogleFonts.comfortaa(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
