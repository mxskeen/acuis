import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../models/goal.dart';
import '../../models/todo.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/streak_service.dart';
import '../../shared/widgets/ambient_animations.dart';
import '../../shared/widgets/streak_sheet.dart';
import '../../shared/widgets/ai_settings_sheet.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../first_principles/first_principles_screen.dart';

/// Today View - The daily command center
///
/// This IS the home screen. It answers: "What should I do today?"
/// - Personalized greeting
/// - Suggested focus
/// - Alignment snapshot
/// - Streak status
/// - Quick navigation
class TodayView extends StatefulWidget {
  final List<Goal> goals;
  final List<Todo> todos;
  final String? userName;
  final VoidCallback onNavigateToGoals;
  final VoidCallback onNavigateToTodos;
  final VoidCallback onNavigateToAlignment;
  final void Function(Todo) onAddTodo;
  final void Function(int) onToggleTodo;
  final VoidCallback? onSettingsChanged;

  const TodayView({
    super.key,
    required this.goals,
    required this.todos,
    this.userName,
    required this.onNavigateToGoals,
    required this.onNavigateToTodos,
    required this.onNavigateToAlignment,
    required this.onAddTodo,
    required this.onToggleTodo,
    this.onSettingsChanged,
  });

  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> with AutomaticKeepAliveClientMixin {
  StreakService? _streakService;
  String? _aiFocus;
  bool _loadingFocus = true;
  bool _initialized = false;
  int _currentStreak = 0;
  double _alignmentScore = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initServicesOnce();
  }

  void _initServicesOnce() {
    if (_initialized) return;
    _initialized = true;
    _initServices();
  }

  @override
  void didUpdateWidget(covariant TodayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalculate alignment when todos change, but don't re-fetch AI
    if (oldWidget.todos != widget.todos) {
      _calculateAlignment();
    }
  }

  Future<void> _initServices() async {
    _streakService = await StreakService.init();
    await _streakService!.checkAndUpdateStreak();

    if (mounted) {
      setState(() {
        _currentStreak = _streakService!.getCurrentStreak();
      });
      _calculateAlignment();
      _fetchAIFocus();
    }
  }

  void _calculateAlignment() {
    final linkedTodos = widget.todos.where((t) => t.goalId != null).toList();
    final scoredTodos = linkedTodos.where((t) => t.alignmentScore != null).toList();
    if (scoredTodos.isNotEmpty) {
      setState(() {
        _alignmentScore = scoredTodos.map((t) => t.alignmentScore!).reduce((a, b) => a + b) / scoredTodos.length;
      });
    }
  }

  Future<void> _fetchAIFocus() async {
    final aiConfig = StorageService().loadAIConfigSync();
    final apiKey = aiConfig.effectiveApiKey;
    final apiUrl = aiConfig.effectiveApiUrl;
    final model = aiConfig.effectiveModel;

    // Get pending todos sorted by alignment score
    final pendingTodos = widget.todos
        .where((t) => !t.completed && t.goalId != null)
        .toList()
      ..sort((a, b) => (b.alignmentScore ?? 0).compareTo(a.alignmentScore ?? 0));

    if (pendingTodos.isEmpty) {
      setState(() {
        _aiFocus = null;
        _loadingFocus = false;
      });
      return;
    }

    // Always have a fallback
    final topTask = pendingTodos.first;
    final localFocus = _getLocalFocus(topTask);

    if (apiKey.isEmpty) {
      setState(() {
        _aiFocus = localFocus;
        _loadingFocus = false;
      });
      return;
    }

    try {
      // Build headers - only add Authorization if not using backend proxy
      final headers = <String, String>{
        'Content-Type': 'application/json',
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
              'content': 'You are a productivity coach. Given a user\'s tasks and goals, suggest their #1 focus for today. Be concise (1-2 sentences), specific, and motivating. No emojis.'
            },
            {
              'role': 'user',
              'content': 'My top tasks: ${pendingTodos.take(3).map((t) => t.title).join(", ")}. My goals: ${widget.goals.take(2).map((g) => g.title).join(", ")}. Streak: $_currentStreak days. What should I focus on today?'
            }
          ],
          'max_tokens': 100,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        if (mounted) {
          setState(() {
            _aiFocus = content.trim();
            _loadingFocus = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _aiFocus = localFocus;
            _loadingFocus = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiFocus = localFocus;
          _loadingFocus = false;
        });
      }
    }
  }

  String _getLocalFocus(Todo topTask) {
    return 'Start with "${topTask.title}"';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final name = widget.userName != null ? ', ${widget.userName}' : '';
    if (hour < 12) return 'Good morning$name';
    if (hour < 17) return 'Good afternoon$name';
    return 'Good evening$name';
  }

  String _getDateSuffix() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'What matters today?';
    if (hour < 17) return 'Keep going.';
    return 'Finish strong.';
  }

  bool get _isNewUser => widget.goals.isEmpty && widget.todos.isEmpty;

  Widget _buildNewUserTutorial() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Alignment Card for new users - clicking Start takes to Goals
        GestureDetector(
          onTap: widget.onNavigateToGoals,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.ink.withValues(alpha: 0.08),
                  AppColors.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.insights_rounded, size: 24, color: AppColors.ink),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Alignment',
                            style: GoogleFonts.comfortaa(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'See how tasks connect to goals',
                            style: GoogleFonts.comfortaa(
                              fontSize: 12,
                              color: AppColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Start',
                        style: GoogleFonts.comfortaa(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Tutorial header
        Text(
          'How Acuis Works',
          style: GoogleFonts.comfortaa(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Turn your goals into actionable steps',
          style: GoogleFonts.comfortaa(
            fontSize: 13,
            color: AppColors.inkLight,
          ),
        ),
        const SizedBox(height: 20),

        // Step 1: Goals
        _buildTutorialStep(
          number: '1',
          icon: Icons.flag_rounded,
          title: 'Define Your Goals',
          description: 'Start by adding what you want to achieve. Big or small, short-term or long-term — every goal matters.',
          color: const Color(0xFF4CAF50),
        ),
        const SizedBox(height: 16),

        // Step 2: Actionable Steps
        _buildTutorialStep(
          number: '2',
          icon: Icons.psychology_rounded,
          title: 'AI Generates Actionable Steps',
          description: 'Acuis breaks down your goals into specific, doable steps. No more vague to-dos — each task has purpose.',
          color: const Color(0xFF2196F3),
        ),
        const SizedBox(height: 16),

        // Step 3: Alignment
        _buildTutorialStep(
          number: '3',
          icon: Icons.insights_rounded,
          title: 'Stay Aligned Daily',
          description: 'See how every step connects to your bigger goals. Focus on what truly moves the needle.',
          color: const Color(0xFF9C27B0),
        ),
        const SizedBox(height: 32),

        // CTA Button
        GestureDetector(
          onTap: widget.onNavigateToGoals,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add Your First Goal',
                    style: GoogleFonts.comfortaa(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTutorialStep({
    required String number,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.comfortaa(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: GoogleFonts.comfortaa(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.comfortaa(
                    fontSize: 12,
                    color: AppColors.inkLight,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pendingTodos = widget.todos.where((t) => !t.completed).toList();
    final completedToday = widget.todos.where((t) {
      if (!t.completed || t.completedAt == null) return false;
      final today = DateTime.now();
      return t.completedAt!.year == today.year &&
          t.completedAt!.month == today.month &&
          t.completedAt!.day == today.day;
    }).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _fetchAIFocus();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              // Header with greeting
              _buildHeader(),
              const SizedBox(height: 24),

              // New user onboarding OR regular content
              if (_isNewUser) ...[
                _buildNewUserTutorial(),
                const SizedBox(height: 20),
                _buildFirstPrinciplesCard(),
              ] else ...[
                // Streak & Quick Stats
                _buildStatsRow(completedToday),
                const SizedBox(height: 20),

                // Alignment Score Card (USP front and center)
                _buildAlignmentCard(),
                const SizedBox(height: 20),

                // Focus Recommendation
                if (pendingTodos.isNotEmpty) ...[
                  _buildFocusCard(),
                  const SizedBox(height: 20),
                ],

                // Today's Tasks
                _buildTodayTasks(pendingTodos),
                const SizedBox(height: 24),

                // First Principles — Deconstruct any idea
                _buildFirstPrinciplesCard(),
                const SizedBox(height: 24),

                // Quick Actions
                _buildQuickActions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: GoogleFonts.comfortaa(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDateSuffix(),
                    style: GoogleFonts.comfortaa(
                      fontSize: 13,
                      color: AppColors.inkLight,
                    ),
                  ),
                ],
              ),
            ),
            // Settings and Streak badges
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Settings icon
                SettingsIconButton(
                  onSettingsChanged: widget.onSettingsChanged,
                ),
                const SizedBox(width: 4),
                // Streak badge
                GestureDetector(
                  onTap: () {
                    if (_streakService != null) {
                      showStreakSheet(context, _streakService!);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _currentStreak > 0
                          ? const Color(0xFFFF6B35).withValues(alpha: 0.1)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _currentStreak > 0
                            ? const Color(0xFFFF6B35).withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: _currentStreak > 0
                              ? const Color(0xFFFF6B35)
                              : AppColors.inkFaint,
                        ),
                        const SizedBox(width: 6),
                        AnimatedCounter(
                          value: _currentStreak,
                          style: GoogleFonts.comfortaa(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _currentStreak > 0
                                ? const Color(0xFFFF6B35)
                                : AppColors.inkFaint,
                          ),
                          duration: const Duration(milliseconds: 600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(int completedToday) {
    final pendingTodos = widget.todos.where((t) => !t.completed).length;
    final totalGoals = widget.goals.length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Steps',
            value: '$pendingTodos',
            icon: Icons.task_alt_rounded,
            color: AppColors.ink,
            onTap: widget.onNavigateToTodos,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Goals',
            value: '$totalGoals',
            icon: Icons.flag_rounded,
            color: AppColors.ink,
            onTap: widget.onNavigateToGoals,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Done',
            value: '$completedToday',
            icon: Icons.check_rounded,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildAlignmentCard() {
    final hasData = widget.goals.isNotEmpty && widget.todos.isNotEmpty;

    return GestureDetector(
      onTap: widget.onNavigateToAlignment,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.ink.withValues(alpha: 0.05),
              AppColors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.insights_rounded, size: 20, color: AppColors.ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Alignment',
                        style: GoogleFonts.comfortaa(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        hasData ? 'Goals ↔️ Steps match' : 'Add goals & steps',
                        style: GoogleFonts.comfortaa(
                          fontSize: 11,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasData)
                  AnimatedProgressRing(
                    value: _alignmentScore,
                    size: 56,
                    strokeWidth: 5,
                    child: Text(
                      '${_alignmentScore.round()}%',
                      style: GoogleFonts.comfortaa(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Start',
                      style: GoogleFonts.comfortaa(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    hasData
                        ? 'See how your daily tasks connect to your bigger goals'
                        : 'Define goals, add tasks, and see how they align',
                    style: GoogleFonts.comfortaa(
                      fontSize: 12,
                      color: AppColors.inkLight,
                      height: 1.4,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: AppColors.inkFaint,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppColors.ink),
              ),
              const SizedBox(width: 12),
              Text(
                'Suggested Focus',
                style: GoogleFonts.comfortaa(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              if (_loadingFocus)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkLight),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _aiFocus ?? 'Focus on your most important step first.',
            style: GoogleFonts.comfortaa(
              fontSize: 14,
              color: AppColors.ink,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTasks(List<Todo> pendingTodos) {
    final todayTodos = pendingTodos.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Today\'s Steps',
              style: GoogleFonts.comfortaa(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            if (pendingTodos.length > 5)
              GestureDetector(
                onTap: widget.onNavigateToTodos,
                child: Text(
                  'See all ${pendingTodos.length}',
                  style: GoogleFonts.comfortaa(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkLight,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (todayTodos.isEmpty)
          _buildEmptyTasks()
        else
          ...todayTodos.asMap().entries.map((entry) {
            final index = widget.todos.indexOf(entry.value);
            return _TodayTaskItem(
              todo: entry.value,
              goals: widget.goals,
              onToggle: () => widget.onToggleTodo(index),
            );
          }),
      ],
    );
  }

  Widget _buildEmptyTasks() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SvgPicture.asset(
            'assets/illustrations/girl-reading-book.svg',
            width: 100,
            height: 100,
          ),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: GoogleFonts.comfortaa(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No pending steps for today',
            style: GoogleFonts.comfortaa(
              fontSize: 12,
              color: AppColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstPrinciplesCard() {
    return GestureDetector(
      onTap: _showDeconstructDialog,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF5C6BC0).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.psychology, size: 24, color: Color(0xFF5C6BC0)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'First Principles',
                    style: GoogleFonts.comfortaa(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rethink any idea from scratch. Challenge assumptions. Find what\'s actually true.',
                    style: GoogleFonts.comfortaa(
                      fontSize: 12,
                      color: AppColors.inkLight,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }

  void _showDeconstructDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FirstPrinciplesScreen(),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.comfortaa(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.add_task_rounded,
                label: 'Add Step',
                onTap: widget.onNavigateToTodos,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.flag_rounded,
                label: 'Add Goal',
                onTap: widget.onNavigateToGoals,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.insights_outlined,
                label: 'Analyze',
                onTap: widget.onNavigateToAlignment,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.comfortaa(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.comfortaa(
                fontSize: 10,
                color: AppColors.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayTaskItem extends StatelessWidget {
  final Todo todo;
  final List<Goal> goals;
  final VoidCallback onToggle;

  const _TodayTaskItem({
    required this.todo,
    required this.goals,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final goal = goals.where((g) => g.id == todo.goalId).firstOrNull;
    final score = todo.alignmentScore;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Checkbox
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: todo.completed ? AppColors.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: todo.completed ? AppColors.ink : AppColors.inkFaint,
                  width: 1.8,
                ),
              ),
              child: todo.completed
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  style: GoogleFonts.comfortaa(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: todo.completed ? AppColors.inkFaint : AppColors.ink,
                    decoration: todo.completed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: AppColors.inkFaint,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (goal != null)
                  Text(
                    goal.title,
                    style: GoogleFonts.comfortaa(
                      fontSize: 10,
                      color: AppColors.inkFaint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (score != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getScoreColor(score).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${score.round()}%',
                style: GoogleFonts.comfortaa(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _getScoreColor(score),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 75) return const Color(0xFF43A047);
    if (score >= 50) return const Color(0xFFFFA726);
    return const Color(0xFFE53935);
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.comfortaa(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
