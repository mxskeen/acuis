import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../models/goal.dart';
import '../../models/todo.dart';
import '../../models/journey_plan.dart';
import '../../shared/services/journey_planner_service.dart';
import '../../shared/services/smart_todo_generator_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/streak_service.dart';
import '../../shared/widgets/streak_sheet.dart';
import '../../shared/widgets/ai_settings_sheet.dart';

class GoalListScreen extends StatefulWidget {
  final List<Goal> goals;
  final String? userName;
  final void Function(Goal) onAdd;
  final void Function(int, Goal) onEdit;
  final void Function(int) onDelete;
  final void Function(List<Todo>) onAddTodos;
  final void Function(JourneyPlan) onJourneyPlanCreated;
  final List<Todo> todos;
  final String? apiKey;
  const GoalListScreen({
    super.key,
    required this.goals,
    this.userName,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onAddTodos,
    required this.onJourneyPlanCreated,
    this.todos = const [],
    this.apiKey,
  });
  @override
  State<GoalListScreen> createState() => _GoalListScreenState();
}

class _GoalListScreenState extends State<GoalListScreen> with AutomaticKeepAliveClientMixin {
  List<Goal> get goals => widget.goals;
  final _storage = StorageService();
  StreakService? _streakService;
  int _currentStreak = 0;
  bool _initialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initOnce();
  }

  void _initOnce() {
    if (_initialized) return;
    _initialized = true;
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final service = await StreakService.init();
    await service.checkAndUpdateStreak();
    if (mounted) {
      setState(() {
        _streakService = service;
        _currentStreak = service.getCurrentStreak();
      });
    }
  }
  
  String _getIllustrationForGoals() {
    if (goals.isEmpty) return 'assets/illustrations/girl-with-plant.svg';
    if (goals.length >= 5) return 'assets/illustrations/tea-lover.svg'; // 5+ goals - Taking time to plan
    if (goals.length >= 3) return 'assets/illustrations/girl-chilling-and-relaxing-while-using-phone.svg'; // 3-4 goals - Balanced
    return 'assets/illustrations/girl-with-plant.svg'; // 1-2 goals - Growing
  }

  Future<void> _showGenerateTasksDialog(int goalIndex) async {
    final goal = goals[goalIndex];
    final apiKey = _storage.loadAIConfigSync().effectiveApiKey;

    if (apiKey.isEmpty) {
      _showApiKeyRequiredDialog();
      return;
    }

    // Get existing todos for this goal
    final existingTodos = widget.todos.where((t) => t.goalId == goal.id).toList();
    final pendingTodos = existingTodos.where((t) => !t.completed).toList();

    // If there are pending todos, show a confirmation dialog first
    if (pendingTodos.isNotEmpty) {
      _showExistingTasksDialog(
        goal: goal,
        pendingCount: pendingTodos.length,
        totalCount: existingTodos.length,
        apiKey: apiKey,
        existingTodos: existingTodos,
      );
      return;
    }

    // No pending todos, proceed with generation
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SmartGenerateTasksDialog(
        goal: goal,
        existingTodos: existingTodos,
        apiKey: apiKey,
        onTasksGenerated: (todos) {
          widget.onAddTodos(todos);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showExistingTasksDialog({
    required Goal goal,
    required int pendingCount,
    required int totalCount,
    required String apiKey,
    required List<Todo> existingTodos,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.task_alt_rounded,
                size: 48,
                color: const Color(0xFFE65100),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'You have $pendingCount pending step${pendingCount == 1 ? '' : 's'}',
              style: GoogleFonts.comfortaa(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your existing steps first before generating more. This helps you stay focused!',
              style: GoogleFonts.comfortaa(
                fontSize: 13,
                color: AppColors.inkLight,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _PrimaryButton(
              label: 'View my steps',
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 12),
            _SecondaryButton(
              label: 'Generate more anyway',
              onTap: () {
                Navigator.pop(ctx);
                // Proceed with generation anyway
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx2) => _SmartGenerateTasksDialog(
                    goal: goal,
                    existingTodos: existingTodos,
                    apiKey: apiKey,
                    onTasksGenerated: (todos) {
                      widget.onAddTodos(todos);
                      Navigator.pop(ctx2);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showApiKeyRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('API Key Required',
            style: GoogleFonts.comfortaa(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        content: Text('Set your API key in the Alignment tab to generate tasks.',
            style: GoogleFonts.comfortaa(
                fontSize: 13, color: AppColors.inkLight, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK',
                style: GoogleFonts.comfortaa(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: goals.isNotEmpty ? Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton(
          onPressed: _showSheet,
          backgroundColor: AppColors.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.add, color: Colors.white, size: 22),
        ),
      ) : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: goals.isEmpty ? _buildEmpty() : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (goals.isNotEmpty) ...[
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: SvgPicture.asset(
                    _getIllustrationForGoals(),
                    key: ValueKey(_getIllustrationForGoals()),
                    width: 100,
                    height: 100,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Goals',
                        style: GoogleFonts.comfortaa(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            height: 1.1)),
                    const SizedBox(height: 3),
                    Text(
                      goals.isEmpty
                          ? 'What are you working towards?'
                          : '${goals.length} goal${goals.length == 1 ? '' : 's'}',
                      style: GoogleFonts.comfortaa(
                          fontSize: 12, color: AppColors.inkLight),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Settings icon
                    const SettingsIconButton(),
                    const SizedBox(width: 4),
                    // Streak badge
                    GestureDetector(
                      onTap: () {
                        if (_streakService != null) {
                          showStreakSheet(context, _streakService!);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department_rounded, size: 14, color: _currentStreak > 0 ? const Color(0xFFFF6B35) : AppColors.inkFaint),
                            const SizedBox(width: 5),
                            Text(
                              _currentStreak > 0 ? '$_currentStreak' : '0',
                              style: GoogleFonts.comfortaa(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink),
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
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/empty_state.png', width: 220),
            const SizedBox(height: 20),
            Text('No goals yet',
                style: GoogleFonts.comfortaa(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkLight)),
            const SizedBox(height: 4),
            Text('Your goals will appear here',
                style: GoogleFonts.comfortaa(
                    fontSize: 12, color: AppColors.inkFaint)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _showSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Add new goal',
                    style: GoogleFonts.comfortaa(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ),
          ],
        ),
      );

  Widget _buildList() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: goals.length,
        itemBuilder: (_, i) => _GoalCard(
          goal: goals[i],
          onLongPress: () => _showEditSheet(i),
          onGenerateTasks: () => _showGenerateTasksDialog(i),
        ),
      );

  void _showSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _NewGoalFlow(
        apiKey: widget.apiKey,
        onGoalCreated: (goal, plan) {
          widget.onAdd(goal);
          if (plan != null) {
            widget.onJourneyPlanCreated(plan);
          }
        },
      ),
    );
  }

  void _showEditSheet(int index) {
    final goal = goals[index];
    final titleCtrl = TextEditingController(text: goal.title);
    final descCtrl  = TextEditingController(text: goal.description);
    GoalType type   = goal.type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 36,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _SheetHandle()),
              const SizedBox(height: 22),
              Text('Edit goal',
                  style: GoogleFonts.comfortaa(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 20),
              _AppField(ctrl: titleCtrl, hint: 'Goal title', autofocus: true),
              const SizedBox(height: 10),
              _AppField(ctrl: descCtrl, hint: 'Description (optional)', maxLines: 3),
              const SizedBox(height: 16),
              Row(
                children: GoalType.values.map((t) {
                  final sel = type == t;
                  return GestureDetector(
                    onTap: () => setS(() => type = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.ink : AppColors.chip,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        t == GoalType.shortTerm ? 'Short term' : 'Long term',
                        style: GoogleFonts.comfortaa(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppColors.inkLight,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              _PrimaryButton(
                label: 'Save changes',
                onTap: () {
                  if (titleCtrl.text.trim().isNotEmpty) {
                    widget.onEdit(index, Goal(
                      id: goal.id,
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      type: type,
                      createdAt: goal.createdAt,
                    ));
                    Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(height: 10),
              _DeleteButton(
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmation(index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete goal?',
            style: GoogleFonts.comfortaa(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        content: Text('This action cannot be undone.',
            style: GoogleFonts.comfortaa(
                fontSize: 13, color: AppColors.inkLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.comfortaa(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkLight)),
          ),
          TextButton(
            onPressed: () {
              widget.onDelete(index);
              Navigator.pop(ctx);
            },
            child: Text('Delete',
                style: GoogleFonts.comfortaa(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onLongPress;
  final VoidCallback onGenerateTasks;
  const _GoalCard({
    required this.goal,
    required this.onLongPress,
    required this.onGenerateTasks,
  });

  @override
  Widget build(BuildContext context) {
    final isShort = goal.type == GoalType.shortTerm;
    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(goal.title,
                      style: GoogleFonts.comfortaa(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          height: 1.3)),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isShort ? AppColors.chip : AppColors.ink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isShort ? 'Short' : 'Long',
                    style: GoogleFonts.comfortaa(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isShort ? AppColors.inkLight : Colors.white),
                  ),
                ),
              ],
            ),
            if (goal.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(goal.description,
                  style: GoogleFonts.comfortaa(
                      fontSize: 13, color: AppColors.inkLight, height: 1.55)),
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onGenerateTasks,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('Generate Steps',
                        style: GoogleFonts.comfortaa(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared private widgets ─────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class _AppField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  final bool autofocus;
  const _AppField({
    required this.ctrl,
    required this.hint,
    this.maxLines = 1,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        maxLines: maxLines,
        autofocus: autofocus,
        style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.comfortaa(
              fontSize: 14, color: AppColors.inkFaint),
          filled: true,
          fillColor: AppColors.bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  const _PrimaryButton({required this.label, this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: onTap == null || isLoading ? AppColors.ink.withValues(alpha: 0.5) : AppColors.ink,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(label,
                    style: GoogleFonts.comfortaa(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
          ),
        ),
      );
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text('Delete goal',
                style: GoogleFonts.comfortaa(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
        ),
      );
}

// ── Smart Generate Tasks Dialog (uses tool-calling LLM) ───────────

class _SmartGenerateTasksDialog extends StatefulWidget {
  final Goal goal;
  final List<Todo> existingTodos;
  final String apiKey;
  final void Function(List<Todo>) onTasksGenerated;

  const _SmartGenerateTasksDialog({
    required this.goal,
    required this.existingTodos,
    required this.apiKey,
    required this.onTasksGenerated,
  });

  @override
  State<_SmartGenerateTasksDialog> createState() => _SmartGenerateTasksDialogState();
}

class _SmartGenerateTasksDialogState extends State<_SmartGenerateTasksDialog> {
  bool _isGenerating = true;
  bool _success = false;
  int _tasksAdded = 0;
  List<Todo>? _generatedTodos;
  List<TextEditingController> _controllers = [];
  String? _error;
  String? _progressAssessment;
  String? _phase;

  @override
  void initState() {
    super.initState();
    _generateTasks();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generateTasks() async {
    try {
      final service = SmartTodoGeneratorService(apiKey: widget.apiKey);
      final result = await service.generateTodos(
        goal: widget.goal,
        existingTodos: widget.existingTodos,
        maxTodos: 5,
      );

      if (mounted) {
        setState(() {
          _generatedTodos = result.todos;
          _controllers = result.todos.map((t) => TextEditingController(text: t.title)).toList();
          _progressAssessment = result.progressAssessment;
          _phase = result.phase;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isGenerating = false;
        });
      }
    }
  }

  void _addTasks() {
    final editedTodos = <Todo>[];
    for (int i = 0; i < (_generatedTodos?.length ?? 0); i++) {
      final original = _generatedTodos![i];
      final editedTitle = _controllers[i].text.trim();
      if (editedTitle.isNotEmpty) {
        editedTodos.add(original.copyWith(title: editedTitle));
      }
    }

    widget.onTasksGenerated(editedTodos);
    setState(() {
      _success = true;
      _tasksAdded = editedTodos.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Success state
    if (_success) {
      return AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF43A047).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 48, color: Color(0xFF43A047)),
            ),
            const SizedBox(height: 20),
            Text(
              '$_tasksAdded steps added!',
              style: GoogleFonts.comfortaa(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ready to work on "${widget.goal.title}"',
              style: GoogleFonts.comfortaa(
                fontSize: 13,
                color: AppColors.inkLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Stay Here',
                style: GoogleFonts.comfortaa(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkLight)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('View Steps',
                style: GoogleFonts.comfortaa(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF43A047))),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 20, color: AppColors.ink),
          const SizedBox(width: 8),
          Text('Smart Steps',
              style: GoogleFonts.comfortaa(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
        ],
      ),
      content: _isGenerating
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.ink),
                const SizedBox(height: 16),
                Text('Analyzing your progress...',
                    style: GoogleFonts.comfortaa(
                        fontSize: 13, color: AppColors.inkLight)),
              ],
            )
          : _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Something went wrong',
                        style: GoogleFonts.comfortaa(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: GoogleFonts.comfortaa(
                            fontSize: 12, color: AppColors.inkLight),
                        textAlign: TextAlign.center),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress assessment
                      if (_progressAssessment != null && _progressAssessment!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(_getPhaseIcon(), size: 18, color: _getPhaseColor()),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _progressAssessment!,
                                  style: GoogleFonts.comfortaa(
                                    fontSize: 12,
                                    color: AppColors.inkLight,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 14, color: AppColors.inkFaint),
                          const SizedBox(width: 6),
                          Text('Tap to edit any step before adding',
                              style: GoogleFonts.comfortaa(
                                  fontSize: 11, color: AppColors.inkFaint)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._controllers.asMap().entries.map((entry) {
                        return _EditableTaskRow(
                          index: entry.key,
                          controller: entry.value,
                        );
                      }),
                    ],
                  ),
                ),
      actions: _isGenerating
          ? null
          : _error != null
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close',
                        style: GoogleFonts.comfortaa(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: GoogleFonts.comfortaa(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkLight)),
                  ),
                  TextButton(
                    onPressed: _addTasks,
                    child: Text('Add All',
                        style: GoogleFonts.comfortaa(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                  ),
                ],
    );
  }

  IconData _getPhaseIcon() {
    return switch (_phase) {
      'starting' => Icons.rocket_launch_rounded,
      'building' => Icons.trending_up_rounded,
      'advancing' => Icons.bolt_rounded,
      'finishing' => Icons.flag_rounded,
      _ => Icons.auto_awesome,
    };
  }

  Color _getPhaseColor() {
    return switch (_phase) {
      'starting' => const Color(0xFF42A5F5),
      'building' => const Color(0xFF66BB6A),
      'advancing' => const Color(0xFFFFA726),
      'finishing' => const Color(0xFFEF5350),
      _ => AppColors.ink,
    };
  }
}

class _EditableTaskRow extends StatefulWidget {
  final int index;
  final TextEditingController controller;
  const _EditableTaskRow({required this.index, required this.controller});

  @override
  State<_EditableTaskRow> createState() => _EditableTaskRowState();
}

class _EditableTaskRowState extends State<_EditableTaskRow> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('${widget.index + 1}.',
              style: GoogleFonts.comfortaa(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkLight)),
          const SizedBox(width: 8),
          Expanded(
            child: _editing
                ? TextField(
                    controller: widget.controller,
                    autofocus: true,
                    style: GoogleFonts.comfortaa(
                        fontSize: 13, color: AppColors.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                    onSubmitted: (_) => setState(() => _editing = false),
                  )
                : Text(widget.controller.text,
                    style: GoogleFonts.comfortaa(
                        fontSize: 13,
                        color: AppColors.ink,
                        height: 1.4)),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _editing = !_editing),
            child: Icon(
              _editing ? Icons.check_rounded : Icons.edit_outlined,
              size: 16,
              color: _editing ? AppColors.ink : AppColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

// ── New Goal Creation Flow (Multi-step) ─────────────────────────────────────

class _NewGoalFlow extends StatefulWidget {
  final String? apiKey;
  final void Function(Goal, JourneyPlan?) onGoalCreated;

  const _NewGoalFlow({
    required this.apiKey,
    required this.onGoalCreated,
  });

  @override
  State<_NewGoalFlow> createState() => _NewGoalFlowState();
}

class _NewGoalFlowState extends State<_NewGoalFlow> {
  int _step = 0;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _outcomeCtrl = TextEditingController();
  int _selectedDays = 90;
  int _dailyMinutes = 15;
  DurationEstimate? _estimate;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_handleTextChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _outcomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _estimateDuration() async {
    if (widget.apiKey == null || widget.apiKey!.isEmpty) {
      // No API key, use defaults
      setState(() {
        _estimate = DurationEstimate(
          minimumDays: 30,
          recommendedDays: 90,
          maximumDays: 180,
          reasoning: 'Set your API key in Alignment for personalized estimates',
        );
        _selectedDays = 90;
        _step = 2;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = JourneyPlannerService(apiKey: widget.apiKey!);
      final estimate = await service.estimateDuration(
        goalTitle: _titleCtrl.text.trim(),
        goalDescription: _descCtrl.text.trim(),
        specificOutcome: _outcomeCtrl.text.trim().isNotEmpty
            ? _outcomeCtrl.text.trim()
            : null,
      );

      setState(() {
        _estimate = estimate;
        _selectedDays = estimate.recommendedDays;
        _dailyMinutes = estimate.dailyMinutesRecommended;
        _step = 2;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        // Use defaults on error
        _estimate = DurationEstimate(
          minimumDays: 30,
          recommendedDays: 90,
          maximumDays: 180,
          reasoning: 'Using default estimate',
        );
        _selectedDays = 90;
        _step = 2;
      });
    }
  }

  Future<void> _createGoal() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final goal = Goal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        type: _selectedDays <= 90 ? GoalType.shortTerm : GoalType.longTerm,
        createdAt: DateTime.now(),
        targetDate: DateTime.now().add(Duration(days: _selectedDays)),
      );

      JourneyPlan? plan;

      if (widget.apiKey != null && widget.apiKey!.isNotEmpty) {
        final service = JourneyPlannerService(apiKey: widget.apiKey!);
        plan = await service.createJourneyPlan(
          goal: goal,
          selectedDays: _selectedDays,
          dailyMinutes: _dailyMinutes,
        );
      }

      widget.onGoalCreated(goal, plan);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 36,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildLoadingEstimate();
      case 2:
        return _buildStep2();
      case 3:
        return _buildCreatingGoal();
      default:
        return _buildStep1();
    }
  }

  // Step 1: Goal title and outcome
  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const ValueKey('step1'),
      children: [
        Center(child: _SheetHandle()),
        const SizedBox(height: 22),
        Text('New goal',
            style: GoogleFonts.comfortaa(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 20),
        _AppField(ctrl: _titleCtrl, hint: 'What do you want to achieve?', autofocus: true),
        const SizedBox(height: 12),
        _AppField(ctrl: _outcomeCtrl, hint: 'What does "done" look like? (be specific)', maxLines: 2),
        const SizedBox(height: 6),
        Text('Specific goals are 2.5x more likely to be achieved',
            style: GoogleFonts.comfortaa(
                fontSize: 11, color: AppColors.inkFaint)),
        const SizedBox(height: 12),
        _AppField(ctrl: _descCtrl, hint: 'Any additional context (optional)', maxLines: 2),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Next',
          onTap: _titleCtrl.text.trim().isEmpty
              ? null
              : () {
                  setState(() {
                    _step = 1;
                  });
                  _estimateDuration();
                },
        ),
      ],
    );
  }

  // Loading state while estimating
  Widget _buildLoadingEstimate() {
    return Column(
      key: const ValueKey('loading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: _SheetHandle()),
        const SizedBox(height: 40),
        const CircularProgressIndicator(color: AppColors.ink),
        const SizedBox(height: 20),
        Text('Analyzing your goal...',
            style: GoogleFonts.comfortaa(
                fontSize: 14, color: AppColors.inkLight)),
      ],
    );
  }

  // Step 2: Duration selection
  Widget _buildStep2() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const ValueKey('step2'),
      children: [
        Center(child: _SheetHandle()),
        const SizedBox(height: 22),
        Text('Timeline',
            style: GoogleFonts.comfortaa(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 16),
        if (_estimate?.reasoning.isNotEmpty == true) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _estimate!.reasoning,
              style: GoogleFonts.comfortaa(
                  fontSize: 12, color: AppColors.inkLight, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('How ambitious do you want to be?',
            style: GoogleFonts.comfortaa(
                fontSize: 13, color: AppColors.ink)),
        const SizedBox(height: 12),
        _buildDurationOption(
          days: _estimate?.minimumDays ?? 30,
          minutes: _estimate?.dailyMinutesMinimum ?? 30,
          label: 'Aggressive',
          subtitle: '${_estimate?.dailyMinutesMinimum ?? 30} min/day',
        ),
        const SizedBox(height: 8),
        _buildDurationOption(
          days: _estimate?.recommendedDays ?? 90,
          minutes: _estimate?.dailyMinutesRecommended ?? 15,
          label: 'Balanced',
          subtitle: '${_estimate?.dailyMinutesRecommended ?? 15} min/day',
          isRecommended: true,
        ),
        const SizedBox(height: 8),
        _buildDurationOption(
          days: _estimate?.maximumDays ?? 180,
          minutes: _estimate?.dailyMinutesMaximum ?? 10,
          label: 'Relaxed',
          subtitle: '${_estimate?.dailyMinutesMaximum ?? 10} min/day',
        ),
        const SizedBox(height: 24),
        if (_error != null)
          Text(_error!,
              style: GoogleFonts.comfortaa(
                  fontSize: 12, color: Colors.red)),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                label: 'Back',
                onTap: () => setState(() => _step = 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PrimaryButton(
                label: 'Create goal',
                onTap: _createGoal,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationOption({
    required int days,
    required int minutes,
    required String label,
    required String subtitle,
    bool isRecommended = false,
  }) {
    final isSelected = _selectedDays == days;
    final months = (days / 30).round();

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDays = days;
          _dailyMinutes = minutes;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.ink : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRecommended && !isSelected
                ? AppColors.ink.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: GoogleFonts.comfortaa(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.ink,
                        )),
                    if (isRecommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppColors.ink.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Recommended',
                            style: GoogleFonts.comfortaa(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.ink,
                            )),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: GoogleFonts.comfortaa(
                      fontSize: 12,
                      color: isSelected ? Colors.white70 : AppColors.inkLight,
                    )),
              ],
            ),
            Text(
              months == 1 ? '1 month' : '$months months',
              style: GoogleFonts.comfortaa(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Creating goal loading state
  Widget _buildCreatingGoal() {
    return Column(
      key: const ValueKey('creating'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: _SheetHandle()),
        const SizedBox(height: 40),
        const CircularProgressIndicator(color: AppColors.ink),
        const SizedBox(height: 20),
        Text('Creating your journey plan...',
            style: GoogleFonts.comfortaa(
                fontSize: 14, color: AppColors.inkLight)),
      ],
    );
  }
}

// Secondary button for "Back" actions
class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SecondaryButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.comfortaa(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ),
      );
}
