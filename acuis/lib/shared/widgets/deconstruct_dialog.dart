import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../models/goal.dart';
import '../../models/todo.dart';
import '../../models/deconstruction_result.dart';
import '../../shared/services/first_principles_service.dart';
import '../../shared/services/storage_service.dart';

/// First Principles Deconstruct Dialog
///
/// A 3-step wizard that applies Elon Musk's first principles thinking:
/// 1. Identify assumptions the user is making
/// 2. Challenge assumptions to find fundamental truths
/// 3. Reconstruct a minimal action plan from confirmed truths
///
/// Can be used in two modes:
/// - **Goal mode**: Pass a [goal] — starts directly at assumptions
/// - **Standalone mode**: Leave [goal] null — shows a text input first
class DeconstructDialog extends StatefulWidget {
  final Goal? goal;
  final String apiKey;
  final void Function(List<Todo>) onTasksGenerated;

  const DeconstructDialog({
    super.key,
    this.goal,
    required this.apiKey,
    required this.onTasksGenerated,
  });

  @override
  State<DeconstructDialog> createState() => _DeconstructDialogState();
}

class _DeconstructDialogState extends State<DeconstructDialog> {
  // -1: free-text input (standalone mode only), 0: assumptions, 1: truths, 2: tasks
  int _step = 0;
  bool _isLoading = true;
  String? _error;

  // Standalone mode: free-text input
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool get _isStandalone => widget.goal == null;

  // Step 0: Assumptions
  List<Assumption> _assumptions = [];

  // Step 1: Truths
  List<Truth> _truths = [];

  // Step 2: Reconstructed tasks
  List<Todo> _reconstructedTodos = [];
  List<TextEditingController> _taskControllers = [];

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_onTextChanged);
    if (_isStandalone) {
      _step = -1;
      _isLoading = false;
    } else {
      _loadAssumptions();
    }
  }

  void _onTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onTextChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _taskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAssumptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final aiConfig = StorageService().loadAIConfigSync();
      final service = FirstPrinciplesService(
        apiKey: widget.apiKey,
        apiUrl: aiConfig.effectiveApiUrl,
        model: aiConfig.effectiveModel,
      );
      final assumptions = await service.identifyAssumptions(
        goal: widget.goal,
        title: _isStandalone ? _titleCtrl.text.trim() : null,
        description: _isStandalone ? _descCtrl.text.trim() : null,
      );

      if (mounted) {
        setState(() {
          _assumptions = assumptions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTruths() async {
    // Send assumptions the user KEPT (not challenged/removed) to find truths
    final kept = _assumptions.where((a) => !a.isChallenged).toList();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final aiConfig = StorageService().loadAIConfigSync();
      final service = FirstPrinciplesService(
        apiKey: widget.apiKey,
        apiUrl: aiConfig.effectiveApiUrl,
        model: aiConfig.effectiveModel,
      );
      final truths = await service.findTruths(
        goal: widget.goal,
        title: _isStandalone ? _titleCtrl.text.trim() : null,
        description: _isStandalone ? _descCtrl.text.trim() : null,
        challengedAssumptions: kept,
      );

      if (mounted) {
        setState(() {
          _truths = truths;
          _isLoading = false;
          _step = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReconstructedTasks() async {
    final confirmed = _truths.where((t) => t.isConfirmed).toList();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final aiConfig = StorageService().loadAIConfigSync();
      final service = FirstPrinciplesService(
        apiKey: widget.apiKey,
        apiUrl: aiConfig.effectiveApiUrl,
        model: aiConfig.effectiveModel,
      );
      final tasks = await service.reconstructPlan(
        goal: widget.goal,
        title: _isStandalone ? _titleCtrl.text.trim() : null,
        description: _isStandalone ? _descCtrl.text.trim() : null,
        confirmedTruths: confirmed,
      );
      final todos = service.createTodosFromReconstruction(tasks, widget.goal?.id);

      if (mounted) {
        setState(() {
          _reconstructedTodos = todos;
          _taskControllers = todos.map((t) => TextEditingController(text: t.title)).toList();
          _isLoading = false;
          _step = 2;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _addTasks() {
    final editedTodos = <Todo>[];
    for (int i = 0; i < _reconstructedTodos.length; i++) {
      final original = _reconstructedTodos[i];
      final editedTitle = _taskControllers[i].text.trim();
      if (editedTitle.isNotEmpty) {
        editedTodos.add(original.copyWith(title: editedTitle));
      }
    }
    widget.onTasksGenerated(editedTodos);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.psychology, size: 20, color: AppColors.ink),
          const SizedBox(width: 8),
          Text(_stepTitle,
              style: GoogleFonts.comfortaa(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
        ],
      ),
      content: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildStepContent(),
      actions: _isLoading
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
              : _buildActions(),
    );
  }

  String get _stepTitle => switch (_step) {
        -1 => 'What are you thinking about?',
        0 => 'Identify Assumptions',
        1 => 'Find Truths',
        2 => 'Create Solutions',
        _ => 'Deconstruct',
      };

  String get _stepSubtitle => switch (_step) {
        -1 => 'A goal, belief, problem, or idea — anything you want to rethink from scratch',
        0 => 'List common beliefs and assumptions. Identify what you think you know.',
        1 => 'Use Socratic questioning. Challenge assumptions until you reach fundamental truths.',
        2 => 'Reconstruct the problem. Use truths as building blocks for innovation.',
        _ => '',
      };

  Widget _buildLoading() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.ink),
          const SizedBox(height: 16),
          Text(
            switch (_step) {
              -1 => 'Thinking...',
              0 => 'Identifying assumptions...',
              1 => 'Finding fundamental truths...',
              2 => 'Creating solutions...',
              _ => 'Thinking...',
            },
            style: GoogleFonts.comfortaa(fontSize: 13, color: AppColors.inkLight),
          ),
        ],
      );

  Widget _buildError() => Column(
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
      );

  Widget _buildStepContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_step >= 0) ...[
            _buildStepIndicator(),
            const SizedBox(height: 12),
          ],
          Text(_stepSubtitle,
              style: GoogleFonts.comfortaa(
                  fontSize: 12, color: AppColors.inkLight, height: 1.4)),
          const SizedBox(height: 16),
          switch (_step) {
            -1 => _buildFreeTextStep(),
            0 => _buildAssumptionsStep(),
            1 => _buildTruthsStep(),
            2 => _buildTasksStep(),
            _ => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(3, (i) {
        final isActive = i == _step;
        final isComplete = i < _step;
        return Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isComplete
                  ? AppColors.ink
                  : isActive
                      ? AppColors.ink.withValues(alpha: 0.5)
                      : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  // ── Step -1: Free-text input (standalone mode) ────────

  Widget _buildFreeTextStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _titleCtrl,
          autofocus: true,
          style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'e.g. I need to go to gym to get fit',
            hintStyle: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.inkFaint),
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _descCtrl,
          maxLines: 2,
          style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'What do you believe about this? (optional)',
            hintStyle: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.inkFaint),
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ── Step 0: Assumptions ──────────────────────────────

  Widget _buildAssumptionsStep() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _assumptions.asMap().entries.map((entry) {
        final index = entry.key;
        final assumption = entry.value;
        final isChallenged = assumption.isChallenged;
        return GestureDetector(
          onTap: () {
            setState(() {
              _assumptions[index] = assumption.copyWith(
                isChallenged: !isChallenged,
              );
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isChallenged ? AppColors.bg : const Color(0xFFE8EAF6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isChallenged
                    ? AppColors.border
                    : const Color(0xFF5C6BC0).withValues(alpha: 0.3),
                width: isChallenged ? 1 : 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isChallenged ? Icons.close : Icons.lightbulb_outline,
                  size: 14,
                  color: isChallenged
                      ? AppColors.inkFaint
                      : const Color(0xFF5C6BC0),
                ),
                const SizedBox(width: 6),
                Text(
                  assumption.text,
                  style: GoogleFonts.comfortaa(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isChallenged ? AppColors.inkFaint : AppColors.ink,
                    decoration: isChallenged ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Step 1: Truths ──────────────────────────────────

  Widget _buildTruthsStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _truths.asMap().entries.map((entry) {
        final index = entry.key;
        final truth = entry.value;
        final isConfirmed = truth.isConfirmed;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _truths[index] = truth.copyWith(isConfirmed: !isConfirmed);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isConfirmed
                    ? const Color(0xFFE8F5E9)
                    : AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isConfirmed
                      ? const Color(0xFF66BB6A).withValues(alpha: 0.5)
                      : AppColors.border,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isConfirmed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: isConfirmed
                        ? const Color(0xFF43A047)
                        : AppColors.inkFaint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          truth.text,
                          style: GoogleFonts.comfortaa(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isConfirmed ? AppColors.ink : AppColors.inkLight,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          truth.explanation,
                          style: GoogleFonts.comfortaa(
                            fontSize: 11,
                            color: AppColors.inkFaint,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Step 2: Reconstructed Tasks ──────────────────────

  Widget _buildTasksStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        ..._taskControllers.asMap().entries.map((entry) {
          return _EditableTaskRow(
            index: entry.key,
            controller: entry.value,
          );
        }),
      ],
    );
  }

  List<Widget> _buildActions() {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel',
            style: GoogleFonts.comfortaa(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.inkLight)),
      ),
      if (_step == -1)
        TextButton(
          onPressed: _titleCtrl.text.trim().isEmpty ? null : _startDeconstruction,
          child: Text('Deconstruct',
              style: GoogleFonts.comfortaa(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _titleCtrl.text.trim().isEmpty ? AppColors.inkFaint : AppColors.ink)),
        )
      else if (_step < 2)
        TextButton(
          onPressed: _step == 0 ? _loadTruths : _loadReconstructedTasks,
          child: Text(
            _step == 0 ? 'Challenge Them' : 'Create Solutions',
            style: GoogleFonts.comfortaa(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink),
          ),
        )
      else
        TextButton(
          onPressed: _addTasks,
          child: Text('Add to Steps',
              style: GoogleFonts.comfortaa(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF43A047))),
        ),
    ];
  }

  void _startDeconstruction() {
    setState(() {
      _step = 0;
    });
    _loadAssumptions();
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
