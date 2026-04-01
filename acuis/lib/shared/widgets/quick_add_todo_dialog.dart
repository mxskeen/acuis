import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../models/todo.dart';
import '../../models/goal.dart';
import '../services/smart_defaults_service.dart';

/// Quick Add Todo Dialog
///
/// A streamlined dialog for quickly adding todos from any screen.
/// Features smart defaults and minimal friction.
void showQuickAddTodoDialog(
  BuildContext context, {
  required List<Goal> goals,
  required List<Todo> todos,
  required Function(Todo) onAdd,
  String? preselectedGoalId,
}) {
  final titleCtrl = TextEditingController();

  // Use smart defaults
  String? goalId = preselectedGoalId ??
                   SmartDefaultsService.getSmartGoalSuggestion(goals, todos);

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Quick Add',
                      style: GoogleFonts.comfortaa(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 20, color: AppColors.inkLight),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  hintStyle: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.inkFaint),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) {
                  if (titleCtrl.text.trim().isNotEmpty) {
                    final completedTodos = todos.where((t) => t.completed).toList();
                    final predictedEffort = SmartDefaultsService.predictEffort(
                      titleCtrl.text.trim(),
                      completedTodos,
                    );

                    onAdd(Todo(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleCtrl.text.trim(),
                      goalId: goalId,
                      estimatedEffort: predictedEffort,
                      createdAt: DateTime.now(),
                    ));
                    Navigator.pop(ctx);
                  }
                },
              ),
              if (goals.isNotEmpty) ...[
                const SizedBox(height: 12),
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
                      style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.ink),
                      hint: Text('Link to a goal',
                          style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.inkFaint)),
                      items: goals
                          .map((g) => DropdownMenuItem(value: g.id, child: Text(g.title)))
                          .toList(),
                      onChanged: (v) => setS(() => goalId = v),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  if (titleCtrl.text.trim().isNotEmpty) {
                    final completedTodos = todos.where((t) => t.completed).toList();
                    final predictedEffort = SmartDefaultsService.predictEffort(
                      titleCtrl.text.trim(),
                      completedTodos,
                    );

                    onAdd(Todo(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleCtrl.text.trim(),
                      goalId: goalId,
                      estimatedEffort: predictedEffort,
                      createdAt: DateTime.now(),
                    ));
                    Navigator.pop(ctx);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('Add',
                        style: GoogleFonts.comfortaa(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
