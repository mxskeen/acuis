import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../models/goal.dart';
import '../../models/todo.dart';
import '../../models/deconstruction_result.dart';
import '../../shared/services/first_principles_service.dart';
import '../../shared/services/storage_service.dart';

/// First Principles Thinking — Full-Screen Experience
///
/// Matches the website's working flow:
/// 1. User enters a problem (or taps a suggestion chip)
/// 2. Hits "Start →"
/// 3. System auto-runs all 3 steps sequentially, showing results
///    progressively as each completes:
///    - Step 1: Identify Assumptions
///    - Step 2: Find Truths (Socratic questioning)
///    - Step 3: Create Solutions (reconstruct from truths)
/// 4. User can add generated steps to their todo list
class FirstPrinciplesScreen extends StatefulWidget {
  final Goal? goal;
  final void Function(List<Todo>)? onTasksGenerated;

  const FirstPrinciplesScreen({
    super.key,
    this.goal,
    this.onTasksGenerated,
  });

  @override
  State<FirstPrinciplesScreen> createState() => _FirstPrinciplesScreenState();
}

class _FirstPrinciplesScreenState extends State<FirstPrinciplesScreen>
    with SingleTickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Flow state
  bool _hasStarted = false;
  bool _isRunning = false;
  String _statusText = '';

  // Step results
  int _currentStep = 0; // 0 = not started, 1 = assumptions, 2 = truths, 3 = solutions
  List<Assumption> _assumptions = [];
  List<Truth> _truths = [];

  List<Todo> _todos = [];
  List<ReconstructedTask> _solutions = [];
  String? _error;

  // Task editing controllers
  List<TextEditingController> _taskControllers = [];

  static const _suggestions = [
    'Why is college so expensive?',
    'How can we make electric cars affordable?',
    'Why do startups fail?',
    'How to learn faster?',
    'Why is healthcare costly?',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.goal != null) {
      _inputCtrl.text = widget.goal!.title;
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    for (final c in _taskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// The main flow: auto-run all 3 steps sequentially
  Future<void> _startDeconstruction() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    final aiConfig = StorageService().loadAIConfigSync();
    final apiKey = aiConfig.effectiveApiKey;

    if (apiKey.isEmpty) {
      _showApiKeyRequired();
      return;
    }

    setState(() {
      _hasStarted = true;
      _isRunning = true;
      _error = null;
      _currentStep = 0;
      _assumptions = [];
      _truths = [];
      _solutions = [];
      _todos = [];
    });

    final service = FirstPrinciplesService(
      apiKey: apiKey,
      apiUrl: aiConfig.effectiveApiUrl,
      model: aiConfig.effectiveModel,
    );

    try {
      // ── Step 1: Identify Assumptions ──────────────────
      setState(() {
        _currentStep = 1;
        _statusText = 'Scanning topic for core assumptions...';
      });

      final assumptions = await service.identifyAssumptions(
        goal: widget.goal,
        title: text,
      );

      if (!mounted) return;
      if (assumptions.isEmpty) {
        setState(() {
          _error = 'Could not identify assumptions. Try rephrasing your problem.';
          _isRunning = false;
        });
        return;
      }

      setState(() {
        _assumptions = assumptions;
      });
      _scrollToBottom();

      // Small pause so the user can see Step 1 results before Step 2 starts
      await Future.delayed(const Duration(milliseconds: 800));

      // ── Step 2: Find Truths ───────────────────────────
      if (!mounted) return;
      setState(() {
        _currentStep = 2;
        _statusText = 'Challenging assumptions with Socratic questioning...';
      });

      final truths = await service.findTruths(
        goal: widget.goal,
        title: text,
        challengedAssumptions: _assumptions,
      );

      if (!mounted) return;
      if (truths.isEmpty) {
        setState(() {
          _error = 'Could not find fundamental truths. Try again.';
          _isRunning = false;
        });
        return;
      }

      setState(() {
        _truths = truths;
      });
      _scrollToBottom();

      await Future.delayed(const Duration(milliseconds: 800));

      // ── Step 3: Create Solutions ──────────────────────
      if (!mounted) return;
      setState(() {
        _currentStep = 3;
        _statusText = 'Reconstructing first principles into solutions...';
      });

      final tasks = await service.reconstructPlan(
        goal: widget.goal,
        title: text,
        confirmedTruths: truths,
      );

      if (!mounted) return;
      final todos = service.createTodosFromReconstruction(tasks, widget.goal?.id);

      setState(() {
        _solutions = tasks;
        _todos = todos;
        _taskControllers = todos.map((t) => TextEditingController(text: t.title)).toList();
        _isRunning = false;
        _statusText = '';
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Please try again.';
          _isRunning = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addTasks() {
    final editedTodos = <Todo>[];
    for (int i = 0; i < _todos.length; i++) {
      final original = _todos[i];
      final editedTitle = _taskControllers[i].text.trim();
      if (editedTitle.isNotEmpty) {
        editedTodos.add(original.copyWith(title: editedTitle));
      }
    }
    widget.onTasksGenerated?.call(editedTodos);
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _hasStarted = false;
      _isRunning = false;
      _currentStep = 0;
      _error = null;
      _assumptions = [];
      _truths = [];
      _solutions = [];
      _todos = [];
      _statusText = '';
      if (widget.goal == null) {
        _inputCtrl.clear();
      }
      for (final c in _taskControllers) {
        c.dispose();
      }
      _taskControllers = [];
    });
  }

  void _showApiKeyRequired() {
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
        content: Text(
            'Set your API key in the Alignment tab to use First Principles.',
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _buildHeroSection(),
                  const SizedBox(height: 24),
                  _buildInputSection(),
                  if (!_hasStarted) ...[
                    const SizedBox(height: 16),
                    _buildSuggestionChips(),
                    const SizedBox(height: 32),
                    _buildHowItWorks(),
                  ],
                  if (_hasStarted) ...[
                    const SizedBox(height: 24),
                    if (_error != null) _buildErrorCard(),
                    if (_currentStep >= 1) _buildStepCard(
                      stepNumber: 1,
                      title: 'Deconstruct',
                      subtitle: 'Identify Assumptions',
                      icon: Icons.layers_outlined,
                      isLoading: _currentStep == 1 && _isRunning,
                      child: _assumptions.isNotEmpty
                          ? _buildAssumptionsList()
                          : null,
                    ),
                    if (_currentStep >= 2) ...[
                      const SizedBox(height: 16),
                      _buildStepCard(
                        stepNumber: 2,
                        title: 'Probe',
                        subtitle: 'Find Truths',
                        icon: Icons.search_rounded,
                        isLoading: _currentStep == 2 && _isRunning,
                        child: _truths.isNotEmpty
                            ? _buildTruthsList()
                            : null,
                      ),
                    ],
                    if (_currentStep >= 3) ...[
                      const SizedBox(height: 16),
                      _buildStepCard(
                        stepNumber: 3,
                        title: 'Rebuild',
                        subtitle: 'Create Solutions',
                        icon: Icons.build_outlined,
                        isLoading: _currentStep == 3 && _isRunning,
                        child: _solutions.isNotEmpty
                            ? (widget.onTasksGenerated != null
                                ? _buildSolutionsList()
                                : _buildReadOnlySolutionsList())
                            : null,
                      ),
                    ],
                    if (_todos.isNotEmpty && !_isRunning && widget.onTasksGenerated != null) ...[
                      const SizedBox(height: 24),
                      _buildAddTasksButton(),
                    ],
                    if (!_isRunning && _currentStep >= 1) ...[
                      const SizedBox(height: 12),
                      _buildTryAgainButton(),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          ),
          Text(
            'First Principles',
            style: GoogleFonts.comfortaa(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const Spacer(),
          if (_hasStarted && !_isRunning)
            GestureDetector(
              onTap: _reset,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 14, color: AppColors.inkLight),
                    const SizedBox(width: 4),
                    Text('New',
                        style: GoogleFonts.comfortaa(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkLight)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    // Collapse hero when results are showing to save vertical space


    if (_hasStarted) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          'Rethink your problems',
          style: GoogleFonts.comfortaa(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deconstruct.\nInnovate. Rebuild.',
          style: GoogleFonts.comfortaa(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Break down complex problems into their fundamental truths.',
          style: GoogleFonts.comfortaa(
            fontSize: 13,
            color: AppColors.inkLight,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              enabled: !_isRunning,
              style: GoogleFonts.comfortaa(fontSize: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'What problem do you want to solve?',
                hintStyle: GoogleFonts.comfortaa(
                    fontSize: 13, color: AppColors.inkFaint),
                filled: false,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onSubmitted: (_) => _startDeconstruction(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: _isRunning ? null : _startDeconstruction,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _isRunning
                      ? AppColors.ink.withValues(alpha: 0.5)
                      : AppColors.ink,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Start',
                            style: GoogleFonts.comfortaa(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 14, color: Colors.white),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _suggestions.map((s) {
        return GestureDetector(
          onTap: () {
            _inputCtrl.text = s;
            _startDeconstruction();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              s,
              style: GoogleFonts.comfortaa(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.inkLight,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHowItWorks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How it works',
          style: GoogleFonts.comfortaa(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 14),
        _buildInfoCard(
          number: '1',
          icon: Icons.layers_outlined,
          title: 'Identify Assumptions',
          description:
              'List common beliefs and assumptions. Identify what you think you know.',
          color: const Color(0xFF5C6BC0),
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          number: '2',
          icon: Icons.search_rounded,
          title: 'Find Truths',
          description:
              'Use Socratic questioning. Challenge assumptions until you reach fundamental truths.',
          color: const Color(0xFF26A69A),
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          number: '3',
          icon: Icons.build_outlined,
          title: 'Create Solutions',
          description:
              'Reconstruct the problem. Use truths as building blocks for innovation.',
          color: const Color(0xFFEF6C00),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String number,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, size: 18, color: color),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. $title',
                  style: GoogleFonts.comfortaa(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.comfortaa(
                    fontSize: 11,
                    color: AppColors.inkLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step Cards ──────────────────────────────────────────────

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isLoading,
    Widget? child,
  }) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLoading
                ? const Color(0xFF5C6BC0).withValues(alpha: 0.3)
                : AppColors.border,
          ),
          boxShadow: [
            if (isLoading)
              BoxShadow(
                color: const Color(0xFF5C6BC0).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(icon, size: 18, color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP $stepNumber',
                        style: GoogleFonts.comfortaa(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkFaint,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$title — $subtitle',
                        style: GoogleFonts.comfortaa(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF5C6BC0),
                    ),
                  )
                else
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: const Color(0xFF43A047).withValues(alpha: 0.7),
                  ),
              ],
            ),
            if (isLoading && child == null) ...[
              const SizedBox(height: 14),
              Text(
                _statusText,
                style: GoogleFonts.comfortaa(
                  fontSize: 12,
                  color: const Color(0xFF5C6BC0),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (child != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),
              child,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssumptionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, size: 14, color: const Color(0xFF5C6BC0).withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text(
              'Common assumptions identified:',
              style: GoogleFonts.comfortaa(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.inkLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_assumptions.length, (i) {
          final a = _assumptions[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF5C6BC0).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF5C6BC0).withValues(alpha: 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C6BC0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.comfortaa(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF5C6BC0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    a.text,
                    style: GoogleFonts.comfortaa(
                      fontSize: 12,
                      color: AppColors.ink,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTruthsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified_rounded, size: 14, color: const Color(0xFF43A047).withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text(
              'Fundamental truths discovered:',
              style: GoogleFonts.comfortaa(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.inkLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_truths.length, (i) {
          final t = _truths[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF43A047).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF43A047).withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: const Color(0xFF43A047).withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.text,
                          style: GoogleFonts.comfortaa(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (t.explanation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: Text(
                        t.explanation,
                        style: GoogleFonts.comfortaa(
                          fontSize: 11,
                          color: AppColors.inkLight,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSolutionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.rocket_launch_rounded, size: 14, color: const Color(0xFFEF6C00).withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Actionable solutions built from truths:',
                style: GoogleFonts.comfortaa(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            'Tap the pencil icon to edit before adding',
            style: GoogleFonts.comfortaa(
              fontSize: 10,
              color: AppColors.inkFaint,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_taskControllers.length, (i) {
          return _EditableTaskRow(
            index: i,
            controller: _taskControllers[i],
          );
        }),
      ],
    );
  }

  Widget _buildReadOnlySolutionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.rocket_launch_rounded, size: 14, color: const Color(0xFFEF6C00).withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Text(
              'Solutions built from first principles:',
              style: GoogleFonts.comfortaa(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.inkLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_solutions.length, (i) {
          final s = _solutions[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF6C00).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEF6C00).withValues(alpha: 0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF6C00).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.comfortaa(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF6C00),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: GoogleFonts.comfortaa(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          height: 1.4,
                        ),
                      ),
                      if (s.reason != null && s.reason!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          s.reason!,
                          style: GoogleFonts.comfortaa(
                            fontSize: 11,
                            color: AppColors.inkLight,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (s.effort != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.ink.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.effort!,
                            style: GoogleFonts.comfortaa(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAddTasksButton() {
    return GestureDetector(
      onTap: _addTasks,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Add to Steps',
                style: GoogleFonts.comfortaa(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTryAgainButton() {
    return GestureDetector(
      onTap: _reset,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            'Try another problem',
            style: GoogleFonts.comfortaa(
              color: AppColors.inkLight,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.comfortaa(
                fontSize: 12,
                color: Colors.red.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Editable Task Row (reused from deconstruct_dialog) ──────

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
                    style:
                        GoogleFonts.comfortaa(fontSize: 13, color: AppColors.ink),
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
