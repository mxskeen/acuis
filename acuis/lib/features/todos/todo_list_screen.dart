import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../models/todo.dart';
import '../../models/goal.dart';
import '../../shared/services/streak_service.dart';

class TodoListScreen extends StatefulWidget {
  final List<Goal> goals;
  final List<Todo> todos;
  final void Function(Todo) onAdd;
  final void Function(int) onToggle;
  final void Function(int, Todo) onEdit;
  final void Function(int) onDelete;
  const TodoListScreen({
    super.key,
    required this.goals,
    required this.todos,
    required this.onAdd,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  List<Todo> get todos => widget.todos;
  int get _done => todos.where((t) => t.completed).length;
  StreakService? _streakService;
  int _currentStreak = 0;
  int _longestStreak = 0;
  
  @override
  void initState() {
    super.initState();
    _loadStreak();
  }
  
  Future<void> _loadStreak() async {
    _streakService = await StreakService.init();
    await _streakService!.checkAndUpdateStreak();
    setState(() {
      _currentStreak = _streakService!.getCurrentStreak();
      _longestStreak = _streakService!.getLongestStreak();
    });
  }
  
  Future<void> _checkStreakUpdate() async {
    if (_streakService == null) return;
    if (_done == todos.length && todos.isNotEmpty) {
      await _streakService!.recordCompletion();
      setState(() {
        _currentStreak = _streakService!.getCurrentStreak();
        _longestStreak = _streakService!.getLongestStreak();
      });
    }
  }
  
  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
  
  String _getIllustrationForProgress() {
    if (todos.isEmpty) return 'assets/illustrations/girl-reading-book.svg';
    final progress = _done / todos.length;
    if (progress == 1.0) return 'assets/illustrations/ballet-dancer.svg'; // Celebration!
    if (progress >= 0.5) return 'assets/illustrations/girl-with-plant.svg'; // Growing
    return 'assets/illustrations/girl-reading-book.svg'; // Starting
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: todos.isNotEmpty ? _buildFAB() : null,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (todos.isNotEmpty) _buildProgress(),
                Expanded(
                  child: todos.isEmpty ? _buildEmpty() : _buildList(),
                ),
              ],
            ),
          ),
          if (_done == todos.length && todos.isNotEmpty)
            _buildCelebrationOverlay(),
        ],
      ),
    );
  }
  
  Widget _buildCelebrationOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: 0.3,
          duration: const Duration(milliseconds: 500),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.ink.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton(
          onPressed: _showSheet,
          backgroundColor: AppColors.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.add, color: Colors.white, size: 22),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (todos.isNotEmpty) ...[
              Center(
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: SvgPicture.asset(
                        _getIllustrationForProgress(),
                        key: ValueKey(_getIllustrationForProgress()),
                        width: 100,
                        height: 100,
                      ),
                    ),
                    if (_done == todos.length && todos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('🎉 All done!',
                          style: GoogleFonts.comfortaa(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                      const SizedBox(height: 4),
                      Text('You crushed it today',
                          style: GoogleFonts.comfortaa(
                              fontSize: 12, color: AppColors.inkLight)),
                    ],
                  ],
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
                    Text('Todos',
                        style: GoogleFonts.comfortaa(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            height: 1.1)),
                    const SizedBox(height: 3),
                    Text(
                      todos.isEmpty
                          ? 'What needs doing today?'
                          : '$_done of ${todos.length} done',
                      style: GoogleFonts.comfortaa(
                          fontSize: 12, color: AppColors.inkLight),
                    ),
                  ],
                ),
                if (todos.isNotEmpty)
                  Text(_getTimeBasedGreeting(),
                      style: GoogleFonts.comfortaa(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkLight)),
              ],
            ),
          ],
        ),
      );

  Widget _buildProgress() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _done / todos.length,
                minHeight: 3,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.ink),
              ),
            ),
            if (_currentStreak > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text('$_currentStreak day streak',
                            style: GoogleFonts.comfortaa(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink)),
                        if (_longestStreak > _currentStreak) ...[
                          const SizedBox(width: 8),
                          Text('(best: $_longestStreak)',
                              style: GoogleFonts.comfortaa(
                                  fontSize: 11,
                                  color: AppColors.inkFaint)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('assets/illustrations/girl-reading-book.svg', width: 190),
            const SizedBox(height: 20),
            Text('Nothing here yet',
                style: GoogleFonts.comfortaa(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkLight)),
            const SizedBox(height: 4),
            Text('Your tasks will appear here',
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
                child: Text('Add new task',
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
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        itemCount: todos.length,
        itemBuilder: (_, i) => _TodoCard(
          todo: todos[i],
          goals: widget.goals,
          onToggle: () {
            widget.onToggle(i);
            _checkStreakUpdate();
          },
          onLongPress: () => _showEditSheet(i),
        ),
      );

  void _showSheet() {
    final titleCtrl = TextEditingController();
    String? goalId =
        widget.goals.isNotEmpty ? widget.goals.first.id : null;

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
              Text('New todo',
                  style: GoogleFonts.comfortaa(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 20),
              _AppField(
                  ctrl: titleCtrl,
                  hint: 'What needs to be done?',
                  autofocus: true),
              if (widget.goals.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: goalId,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      style: GoogleFonts.comfortaa(
                          fontSize: 13, color: AppColors.ink),
                      hint: Text('Link to a goal',
                          style: GoogleFonts.comfortaa(
                              fontSize: 13, color: AppColors.inkFaint)),
                      items: widget.goals
                          .map((g) => DropdownMenuItem(
                              value: g.id, child: Text(g.title)))
                          .toList(),
                      onChanged: (v) => setS(() => goalId = v),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _PrimaryButton(
                label: 'Add todo',
                onTap: () {
                  if (titleCtrl.text.trim().isNotEmpty) {
                    widget.onAdd(Todo(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleCtrl.text.trim(),
                      goalId: goalId,
                      createdAt: DateTime.now(),
                    ));
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(int index) {
    final todo = todos[index];
    final titleCtrl = TextEditingController(text: todo.title);
    String? goalId = todo.goalId;

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
              Text('Edit todo',
                  style: GoogleFonts.comfortaa(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 20),
              _AppField(
                  ctrl: titleCtrl,
                  hint: 'What needs to be done?',
                  autofocus: true),
              if (widget.goals.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: goalId,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      style: GoogleFonts.comfortaa(
                          fontSize: 13, color: AppColors.ink),
                      hint: Text('Link to a goal',
                          style: GoogleFonts.comfortaa(
                              fontSize: 13, color: AppColors.inkFaint)),
                      items: widget.goals
                          .map((g) => DropdownMenuItem(
                              value: g.id, child: Text(g.title)))
                          .toList(),
                      onChanged: (v) => setS(() => goalId = v),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _PrimaryButton(
                label: 'Save changes',
                onTap: () {
                  if (titleCtrl.text.trim().isNotEmpty) {
                    widget.onEdit(index, Todo(
                      id: todo.id,
                      title: titleCtrl.text.trim(),
                      goalId: goalId,
                      completed: todo.completed,
                      createdAt: todo.createdAt,
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
        title: Text('Delete todo?',
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

class _TodoCard extends StatelessWidget {
  final Todo todo;
  final List<Goal> goals;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;
  const _TodoCard({
    required this.todo,
    required this.goals,
    required this.onToggle,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final goal = goals.where((g) => g.id == todo.goalId).firstOrNull;
    return GestureDetector(
      onTap: onToggle,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: todo.completed ? AppColors.bg : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    style: GoogleFonts.comfortaa(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: todo.completed ? AppColors.inkFaint : AppColors.ink,
                      decoration: todo.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: AppColors.inkFaint,
                    ),
                  ),
                  if (goal != null) ...[
                    const SizedBox(height: 3),
                    Text(goal.title,
                        style: GoogleFonts.comfortaa(
                            fontSize: 11, color: AppColors.inkFaint)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private widgets ────────────────────────────────────────

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
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(label,
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
            child: Text('Delete todo',
                style: GoogleFonts.comfortaa(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
        ),
      );
}
