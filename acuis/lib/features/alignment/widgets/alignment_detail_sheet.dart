import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../main.dart';
import '../../../models/goal.dart';
import '../../../models/todo.dart';

void showAlignmentDetail(
  BuildContext context,
  List<Goal> goals,
  List<Todo> todos,
  double overallScore,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AlignmentDetailSheet(
      goals: goals,
      todos: todos,
      overallScore: overallScore,
    ),
  );
}

// ── Computed series data ───────────────────────────────────

class _GoalSeries {
  final String label;
  final Color color;
  final int wobbleSeed;

  /// Actual historical points: (dayIndex, completionFraction 0–1)
  final List<(int, double)> actual;

  /// Projected future points from today onward
  final List<(int, double)> projected;

  /// Day index of "today" relative to goal creation
  final int todayDay;

  const _GoalSeries({
    required this.label,
    required this.color,
    required this.wobbleSeed,
    required this.actual,
    required this.projected,
    required this.todayDay,
  });
}

_GoalSeries _buildSeries(
  Goal goal,
  List<Todo> allTodos,
  Color color,
) {
  final goalTodos = allTodos.where((t) => t.goalId == goal.id).toList();
  final now = DateTime.now();
  final createdAt = goal.createdAt;
  final todayDay = now.difference(createdAt).inDays.clamp(0, 365);

  // ── Actual history ─────────────────────────────────────
  // We don't have per-day snapshots, so we reconstruct from
  // todo createdAt dates: on each day a todo existed, count
  // how many were completed vs total at that point.
  // Simplification: treat completed todos as "done on createdAt day"
  // and incomplete as still pending.
  final completedTodos = goalTodos.where((t) => t.completed).toList();
  final total = goalTodos.length;

  // Build sparse actual points: day 0 = 0%, today = current completion
  final actual = <(int, double)>[];
  actual.add((0, 0.0));

  if (total > 0) {
    // Sort completed todos by creation date to simulate incremental progress
    completedTodos.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (int i = 0; i < completedTodos.length; i++) {
      final day = completedTodos[i].createdAt.difference(createdAt).inDays.clamp(0, todayDay);
      final fraction = (i + 1) / total;
      actual.add((day, fraction));
    }
    // Ensure today's real value is the last actual point
    final currentFraction = completedTodos.length / total;
    if (actual.last.$1 != todayDay) {
      actual.add((todayDay, currentFraction));
    }
  } else {
    actual.add((todayDay, 0.0));
  }

  // ── Projected future ───────────────────────────────────
  // Use alignment score as the growth driver.
  // Higher alignment = faster approach to 100%.
  // Model: logistic growth from current point.
  final scored = goalTodos.where((t) => t.alignmentScore != null).toList();
  final avgAlignment = scored.isEmpty
      ? 50.0
      : scored.map((t) => t.alignmentScore!).reduce((a, b) => a + b) / scored.length;

  final currentFraction = total == 0 ? 0.0 : completedTodos.length / total;
  // Growth rate: alignment 100 → reaches ~95% in 30 days; alignment 0 → flat
  final k = (avgAlignment / 100) * 0.12; // logistic rate
  final projectionDays = goal.type == GoalType.shortTerm ? 30 : 90;

  final projected = <(int, double)>[];
  for (int d = 0; d <= projectionDays; d++) {
    // Logistic: f(d) = 1 / (1 + e^(-k*(d - midpoint)))
    // Shifted so f(0) = currentFraction
    double y;
    if (k < 0.001) {
      y = currentFraction; // no growth if alignment is 0
    } else {
      // Solve for L0 such that logistic(0) = currentFraction
      final L0 = currentFraction <= 0.001
          ? 0.001
          : currentFraction >= 0.999
              ? 0.999
              : currentFraction;
      final shift = log(L0 / (1 - L0)) / k;
      y = 1 / (1 + exp(-k * (d + shift)));
    }
    projected.add((todayDay + d, y.clamp(0.0, 1.0)));
  }

  // Wobble seed from goal id hash so it's deterministic per goal
  final seed = goal.id.codeUnits.fold(0, (a, b) => a ^ b);

  return _GoalSeries(
    label: goal.title,
    color: color,
    wobbleSeed: seed,
    actual: actual,
    projected: projected,
    todayDay: todayDay,
  );
}

// ── Sheet ──────────────────────────────────────────────────

class _AlignmentDetailSheet extends StatelessWidget {
  final List<Goal> goals;
  final List<Todo> todos;
  final double overallScore;

  const _AlignmentDetailSheet({
    required this.goals,
    required this.todos,
    required this.overallScore,
  });

  static const _palette = [
    Color(0xFF2D2D2D),
    Color(0xFFB05C3A),
    Color(0xFF3A7AB0),
    Color(0xFF5A9E6F),
    Color(0xFF9B5EA2),
  ];

  @override
  Widget build(BuildContext context) {
    final series = <_GoalSeries>[];
    for (int i = 0; i < goals.length; i++) {
      final goalTodos = todos.where((t) => t.goalId == goals[i].id).toList();
      if (goalTodos.isEmpty) continue;
      series.add(_buildSeries(goals[i], todos, _palette[i % _palette.length]));
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 36),
              children: [
                _buildTitle(),
                const SizedBox(height: 24),
                _buildChart(series),
                const SizedBox(height: 28),
                _buildConnectionsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alignment Analysis',
              style: GoogleFonts.comfortaa(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 4),
          Text('Actual progress + projected growth per goal',
              style: GoogleFonts.comfortaa(
                  fontSize: 12, color: AppColors.inkFaint)),
        ],
      );

  Widget _buildChart(List<_GoalSeries> series) {
    if (series.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.chip,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('Add todos linked to goals to see chart',
              style: GoogleFonts.comfortaa(
                  fontSize: 13, color: AppColors.inkFaint)),
        ),
      );
    }

    // Determine total X span across all series
    final maxDay = series
        .map((s) => s.projected.isEmpty ? s.todayDay : s.projected.last.$1)
        .reduce(max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Growth Chart',
                style: GoogleFonts.comfortaa(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
            const Spacer(),
            // Solid = actual, dashed = projected
            _LegendItem(label: 'actual', dashed: false),
            const SizedBox(width: 12),
            _LegendItem(label: 'projected', dashed: true),
          ],
        ),
        const SizedBox(height: 4),
        Text('Completion % over time · dashed = forecast',
            style: GoogleFonts.comfortaa(
                fontSize: 11, color: AppColors.inkFaint)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
          child: SizedBox(
            height: 240,
            child: CustomPaint(
              painter: _HandDrawnChartPainter(
                series: series,
                maxDay: maxDay,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: series.map((s) {
            final label = s.label.length > 22
                ? '${s.label.substring(0, 20)}…'
                : s.label;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20, height: 3,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(label,
                    style: GoogleFonts.comfortaa(
                        fontSize: 11, color: AppColors.inkLight)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConnectionsSection() {
    final linkedTodos = todos.where((t) => t.goalId != null).toList();
    if (linkedTodos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Todo Connections',
            style: GoogleFonts.comfortaa(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 4),
        Text('How each task connects to your goals',
            style: GoogleFonts.comfortaa(
                fontSize: 11, color: AppColors.inkFaint)),
        const SizedBox(height: 12),
        ...goals.map((goal) {
          final goalTodos =
              linkedTodos.where((t) => t.goalId == goal.id).toList();
          if (goalTodos.isEmpty) return const SizedBox.shrink();
          return _GoalConnectionCard(goal: goal, todos: goalTodos);
        }),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final bool dashed;
  const _LegendItem({required this.label, required this.dashed});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 10,
          child: CustomPaint(
            painter: _DashLinePainter(dashed: dashed),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.comfortaa(
                fontSize: 10, color: AppColors.inkFaint)),
      ],
    );
  }
}

class _DashLinePainter extends CustomPainter {
  final bool dashed;
  const _DashLinePainter({required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.inkFaint
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    if (!dashed) {
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    } else {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, size.height / 2), Offset(x + 4, size.height / 2), paint);
        x += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Chart painter ──────────────────────────────────────────

class _HandDrawnChartPainter extends CustomPainter {
  final List<_GoalSeries> series;
  final int maxDay;

  const _HandDrawnChartPainter({
    required this.series,
    required this.maxDay,
  });

  static const _leftPad = 36.0;
  static const _bottomPad = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width - _leftPad;
    final ch = size.height - _bottomPad;

    _drawGrid(canvas, cw, ch);
    _drawAxes(canvas, cw, ch);
    _drawAxisLabels(canvas, cw, ch);

    for (final s in series) {
      _drawSeriesActual(canvas, s, cw, ch);
      _drawSeriesProjected(canvas, s, cw, ch);
    }

    // "Today" vertical line
    if (maxDay > 0) {
      final todayX = _leftPad + (series.first.todayDay / maxDay) * cw;
      final todayPaint = Paint()
        ..color = AppColors.inkFaint.withValues(alpha: 0.4)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      _drawDashedLine(canvas, Offset(todayX, 0), Offset(todayX, ch), todayPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: 'today',
          style: GoogleFonts.comfortaa(fontSize: 8, color: AppColors.inkFaint),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(todayX - tp.width / 2, ch + 6));
    }
  }

  void _drawAxes(Canvas canvas, double cw, double ch) {
    final p = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(_leftPad, 0), Offset(_leftPad, ch), p);
    canvas.drawLine(Offset(_leftPad, ch), Offset(_leftPad + cw, ch), p);
  }

  void _drawGrid(Canvas canvas, double cw, double ch) {
    final p = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    for (int i = 1; i <= 4; i++) {
      final y = ch - (ch * i / 4);
      canvas.drawLine(Offset(_leftPad, y), Offset(_leftPad + cw, y), p);
    }
  }

  void _drawAxisLabels(Canvas canvas, double cw, double ch) {
    final style = GoogleFonts.comfortaa(fontSize: 8, color: AppColors.inkFaint);

    for (int i = 0; i <= 4; i++) {
      final y = ch - (ch * i / 4);
      final tp = TextPainter(
        text: TextSpan(text: '${i * 25}%', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // X: show day markers at 0, 25%, 50%, 75%, 100% of maxDay
    if (maxDay > 0) {
      for (final frac in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final day = (frac * maxDay).round();
        final x = _leftPad + frac * cw;
        final tp = TextPainter(
          text: TextSpan(text: 'd$day', style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        if (frac < 0.9) { // skip "today" label overlap
          tp.paint(canvas, Offset(x - tp.width / 2, ch + 16));
        }
      }
    }
  }

  void _drawSeriesActual(Canvas canvas, _GoalSeries s, double cw, double ch) {
    if (s.actual.length < 2) return;
    final rng = Random(s.wobbleSeed);

    final paint = Paint()
      ..color = s.color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final points = s.actual.map((p) {
      final x = _leftPad + (maxDay == 0 ? 0.0 : p.$1 / maxDay) * cw
          + (rng.nextDouble() - 0.5) * 2.0;
      final y = ch - p.$2 * ch
          + (rng.nextDouble() - 0.5) * 2.5;
      return Offset(x, y);
    }).toList();

    final path = _smoothPath(points);
    canvas.drawPath(path, paint);

    // Dot at each actual data point
    final dotPaint = Paint()..color = s.color..style = PaintingStyle.fill;
    for (final pt in points) {
      canvas.drawCircle(pt, 3.0, dotPaint);
    }
  }

  void _drawSeriesProjected(Canvas canvas, _GoalSeries s, double cw, double ch) {
    if (s.projected.isEmpty) return;
    final rng = Random(s.wobbleSeed + 1);

    final paint = Paint()
      ..color = s.color.withValues(alpha: 0.55)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final points = s.projected.map((p) {
      final x = _leftPad + (maxDay == 0 ? 0.0 : p.$1 / maxDay) * cw
          + (rng.nextDouble() - 0.5) * 2.0;
      final y = ch - p.$2 * ch
          + (rng.nextDouble() - 0.5) * 2.5;
      return Offset(x, y);
    }).toList();

    // Draw as dashed path
    _drawDashedPath(canvas, points, paint);
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length - 1; i++) {
      final cp = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, cp.dx, cp.dy);
    }
    if (points.length > 1) {
      path.lineTo(points.last.dx, points.last.dy);
    }
    return path;
  }

  void _drawDashedPath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    const dashLen = 6.0;
    const gapLen = 4.0;

    double remaining = dashLen;
    bool drawing = true;

    for (int i = 1; i < points.length; i++) {
      final start = points[i - 1];
      final end = points[i];
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final segLen = sqrt(dx * dx + dy * dy);
      if (segLen == 0) continue;
      final ux = dx / segLen;
      final uy = dy / segLen;

      double traveled = 0;
      Offset cur = start;

      while (traveled < segLen) {
        final step = min(remaining, segLen - traveled);
        final next = Offset(cur.dx + ux * step, cur.dy + uy * step);
        if (drawing) canvas.drawLine(cur, next, paint);
        traveled += step;
        cur = next;
        remaining -= step;
        if (remaining <= 0) {
          drawing = !drawing;
          remaining = drawing ? dashLen : gapLen;
        }
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    _drawDashedPath(canvas, [start, end], paint);
  }

  @override
  bool shouldRepaint(covariant _HandDrawnChartPainter old) =>
      old.series != series || old.maxDay != maxDay;
}

// ── Connection cards ───────────────────────────────────────

class _GoalConnectionCard extends StatelessWidget {
  final Goal goal;
  final List<Todo> todos;

  const _GoalConnectionCard({required this.goal, required this.todos});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(goal.title,
                      style: GoogleFonts.comfortaa(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.chip,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    goal.type == GoalType.shortTerm ? 'Short' : 'Long',
                    style: GoogleFonts.comfortaa(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkLight),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...todos.map((todo) => _TodoConnectionRow(todo: todo)),
        ],
      ),
    );
  }
}

class _TodoConnectionRow extends StatelessWidget {
  final Todo todo;
  const _TodoConnectionRow({required this.todo});

  @override
  Widget build(BuildContext context) {
    final score = todo.alignmentScore;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                todo.completed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: todo.completed ? AppColors.ink : AppColors.inkFaint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(todo.title,
                    style: GoogleFonts.comfortaa(
                      fontSize: 13,
                      color: todo.completed ? AppColors.inkFaint : AppColors.ink,
                      decoration: todo.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: AppColors.inkFaint,
                    )),
              ),
              if (score != null) ...[
                const SizedBox(width: 8),
                Text('${score.round()}%',
                    style: GoogleFonts.comfortaa(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _scoreColor(score))),
              ],
            ],
          ),
          if (score != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: score / 100,
                  minHeight: 3,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation(_scoreColor(score)),
                ),
              ),
            ),
          ],
          if (todo.alignmentExplanation != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(todo.alignmentExplanation!,
                  style: GoogleFonts.comfortaa(
                      fontSize: 11,
                      color: AppColors.inkFaint,
                      height: 1.5)),
            ),
          ],
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 75) return const Color(0xFF3A7A4A);
    if (score >= 50) return const Color(0xFFB07A2A);
    return const Color(0xFFB04A3A);
  }
}
