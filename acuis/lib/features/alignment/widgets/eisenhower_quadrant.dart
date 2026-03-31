import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/todo.dart';
import '../../../models/smart_scores.dart';
import '../../../main.dart';

/// Eisenhower Matrix Quadrant Visualization
///
/// Science-backed task prioritization based on:
/// - Urgency (time-sensitive vs not)
/// - Importance (goal-aligned vs not)
///
/// Q1 (Do Now): Urgent + Important
/// Q2 (Schedule): Not Urgent + Important - MOST VALUABLE for long-term goals
/// Q3 (Delegate): Urgent + Not Important
/// Q4 (Eliminate): Not Urgent + Not Important
class EisenhowerQuadrant extends StatefulWidget {
  final List<Todo> todos;
  final void Function(Todo todo, EisenhowerClass newClass)? onReclassify;

  const EisenhowerQuadrant({
    super.key,
    required this.todos,
    this.onReclassify,
  });

  @override
  State<EisenhowerQuadrant> createState() => _EisenhowerQuadrantState();
}

class _EisenhowerQuadrantState extends State<EisenhowerQuadrant>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  EisenhowerClass? _selectedQuadrant;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim.forward();
  }

  @override
  void didUpdateWidget(EisenhowerQuadrant oldWidget) {
    if (oldWidget.todos != widget.todos) {
      _anim.forward(from: 0);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Classify todos into quadrants
  Map<EisenhowerClass, List<Todo>> _classifyTodos() {
    final result = <EisenhowerClass, List<Todo>>{
      for (final e in EisenhowerClass.values) e: []
    };

    for (final todo in widget.todos) {
      final eClass = todo.effectiveEisenhowerClass;
      result[eClass]!.add(todo);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final classified = _classifyTodos();
    final total = widget.todos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildQuadrantGrid(classified, total),
        const SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Eisenhower Matrix',
                style: GoogleFonts.comfortaa(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Science-Backed',
                  style: GoogleFonts.comfortaa(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkLight)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Prioritize by urgency and importance',
            style: GoogleFonts.comfortaa(
                fontSize: 12, color: AppColors.inkFaint)),
      ],
    );
  }

  Widget _buildQuadrantGrid(
    Map<EisenhowerClass, List<Todo>> classified,
    int total,
  ) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              children: [
                // Grid lines
                _buildGridLines(),
                // Quadrant contents
                ...EisenhowerClass.values.map((eClass) =>
                    _buildQuadrant(classified[eClass]!, eClass, total)),
                // Axis labels
                _buildAxisLabels(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridLines() {
    return Positioned.fill(
      child: CustomPaint(
        painter: _GridPainter(),
      ),
    );
  }

  Widget _buildQuadrant(
    List<Todo> todos,
    EisenhowerClass eClass,
    int total,
  ) {
    final isLeft = eClass == EisenhowerClass.doNow ||
        eClass == EisenhowerClass.delegate;
    final isTop = eClass == EisenhowerClass.doNow ||
        eClass == EisenhowerClass.schedule;

    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      width: MediaQuery.of(context).size.width / 2 - 30,
      height: MediaQuery.of(context).size.width / 2 - 30,
      child: GestureDetector(
        onTap: () => _showQuadrantDetail(todos, eClass),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getQuadrantColor(eClass).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedQuadrant == eClass
                  ? _getQuadrantColor(eClass)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              // Quadrant label
              Positioned(
                top: 8,
                left: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eClass.displayName,
                      style: GoogleFonts.comfortaa(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _getQuadrantColor(eClass),
                      ),
                    ),
                    Text(
                      '${todos.length} tasks',
                      style: GoogleFonts.comfortaa(
                        fontSize: 9,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              // Task dots
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, child) {
                    final curve = Curves.elasticOut.transform(_anim.value);
                    return CustomPaint(
                      painter: _QuadrantDotsPainter(
                        todos: todos,
                        progress: curve,
                        color: _getQuadrantColor(eClass),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAxisLabels() {
    return Stack(
      children: [
        // Top center - Important
        Positioned(
          top: 4,
          left: 0,
          right: 0,
          child: Center(
            child: Text('IMPORTANT',
                style: GoogleFonts.comfortaa(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkFaint,
                  letterSpacing: 1,
                )),
          ),
        ),
        // Right center - Urgent
        Positioned(
          right: 4,
          top: 0,
          bottom: 0,
          child: Center(
            child: RotatedBox(
              quarterTurns: 1,
              child: Text('URGENT',
                  style: GoogleFonts.comfortaa(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkFaint,
                    letterSpacing: 1,
                  )),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: EisenhowerClass.values.map((eClass) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _getQuadrantColor(eClass),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              eClass.displayName,
              style: GoogleFonts.comfortaa(
                fontSize: 10,
                color: AppColors.inkLight,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Color _getQuadrantColor(EisenhowerClass eClass) {
    return switch (eClass) {
      EisenhowerClass.doNow => const Color(0xFFE53935),    // Red - urgent
      EisenhowerClass.schedule => const Color(0xFF43A047), // Green - strategic
      EisenhowerClass.delegate => const Color(0xFFFFA726), // Orange
      EisenhowerClass.eliminate => const Color(0xFF9E9E9E), // Grey
    };
  }

  void _showQuadrantDetail(List<Todo> todos, EisenhowerClass eClass) {
    setState(() => _selectedQuadrant = eClass);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _QuadrantDetailSheet(
        todos: todos,
        eisenhowerClass: eClass,
        color: _getQuadrantColor(eClass),
        onReclassify: widget.onReclassify,
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _selectedQuadrant = null);
      }
    });
  }
}

// ── Grid Painter ────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.inkFaint.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Vertical line
    canvas.drawLine(
      Offset(cx, 20),
      Offset(cx, size.height - 20),
      paint,
    );

    // Horizontal line
    canvas.drawLine(
      Offset(20, cy),
      Offset(size.width - 20, cy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Quadrant Dots Painter ────────────────────────────────────────────

class _QuadrantDotsPainter extends CustomPainter {
  final List<Todo> todos;
  final double progress;
  final Color color;

  _QuadrantDotsPainter({
    required this.todos,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (todos.isEmpty || progress <= 0) return;

    final rng = Random(todos.hashCode);
    final padding = 40.0;

    for (int i = 0; i < todos.length; i++) {
      final todo = todos[i];

      // Cascade animation
      final delay = i * 0.05;
      final dotScale = (progress - delay).clamp(0.0, 1.0);
      if (dotScale <= 0) continue;

      // Random position within quadrant
      final x = padding + rng.nextDouble() * (size.width - padding * 2);
      final y = padding + rng.nextDouble() * (size.height - padding * 2);

      // Size based on effort (larger = more effort)
      final baseRadius = 4.0 + (todo.estimatedEffort ?? 3) * 1.5;
      final radius = baseRadius * dotScale;

      final paint = Paint()
        ..color = todo.completed
            ? color.withOpacity(0.4)
            : color.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, paint);

      // Border for completed tasks
      if (todo.completed) {
        final borderPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(Offset(x, y), radius, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QuadrantDotsPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.todos != todos;
  }
}

// ── Quadrant Detail Sheet ────────────────────────────────────────────

class _QuadrantDetailSheet extends StatelessWidget {
  final List<Todo> todos;
  final EisenhowerClass eisenhowerClass;
  final Color color;
  final void Function(Todo, EisenhowerClass)? onReclassify;

  const _QuadrantDetailSheet({
    required this.todos,
    required this.eisenhowerClass,
    required this.color,
    this.onReclassify,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eisenhowerClass.displayName,
                            style: GoogleFonts.comfortaa(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            eisenhowerClass.description,
                            style: GoogleFonts.comfortaa(
                              fontSize: 12,
                              color: AppColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${todos.length}',
                        style: GoogleFonts.comfortaa(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTip(),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: todos.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    controller: ctrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: todos.length,
                    itemBuilder: (_, i) => _buildTodoItem(todos[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip() {
    final tip = switch (eisenhowerClass) {
      EisenhowerClass.doNow => 'Focus on these first - they matter most right now.',
      EisenhowerClass.schedule => 'Block time for these - they drive long-term success!',
      EisenhowerClass.delegate => 'Consider who else could handle these.',
      EisenhowerClass.eliminate => 'Question if these are worth your time.',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: GoogleFonts.comfortaa(
                fontSize: 11,
                color: AppColors.inkLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: color.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(
            'No tasks in this quadrant',
            style: GoogleFonts.comfortaa(
              fontSize: 14,
              color: AppColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(Todo todo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            todo.completed
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            size: 20,
            color: todo.completed ? color : AppColors.inkFaint,
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
                    color: todo.completed ? AppColors.inkFaint : AppColors.ink,
                    decoration: todo.completed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                if (todo.smartScores != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'SMART: ${todo.smartScore.round()}%',
                    style: GoogleFonts.comfortaa(
                      fontSize: 10,
                      color: AppColors.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (todo.estimatedEffort != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                todo.effortLevel.displayName,
                style: GoogleFonts.comfortaa(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkLight,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
