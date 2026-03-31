import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../models/goal.dart';

class GoalListScreen extends StatefulWidget {
  final List<Goal> goals;
  final void Function(Goal) onAdd;
  final void Function(int, Goal) onEdit;
  final void Function(int) onDelete;
  const GoalListScreen({
    super.key,
    required this.goals,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  State<GoalListScreen> createState() => _GoalListScreenState();
}

class _GoalListScreenState extends State<GoalListScreen> {
  List<Goal> get goals => widget.goals;
  
  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
  
  String _getIllustrationForGoals() {
    if (goals.isEmpty) return 'assets/illustrations/girl-with-plant.svg';
    if (goals.length >= 5) return 'assets/illustrations/ballet-dancer.svg'; // Many goals!
    if (goals.length >= 3) return 'assets/illustrations/girl-with-plant.svg'; // Growing
    return 'assets/illustrations/girl-reading-book.svg'; // Starting
  }

  @override
  Widget build(BuildContext context) {
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
                if (goals.isNotEmpty)
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

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('assets/illustrations/girl-with-plant.svg', width: 190),
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
        ),
      );

  void _showSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    GoalType type   = GoalType.shortTerm;

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
              Text('New goal',
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
                label: 'Add goal',
                onTap: () {
                  if (titleCtrl.text.trim().isNotEmpty) {
                    widget.onAdd(Goal(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      type: type,
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
  const _GoalCard({required this.goal, required this.onLongPress});

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
            child: Text('Delete goal',
                style: GoogleFonts.comfortaa(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
        ),
      );
}
