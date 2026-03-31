import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/goal.dart';
import '../../../models/todo.dart';
import '../../../models/velocity_prediction.dart';
import '../../../shared/services/velocity_service.dart';
import '../../../main.dart';

/// Science-Backed Growth Chart
///
/// Replaces arbitrary logistic growth with velocity-based forecasting:
/// - Solid line: Historical completion data
/// - Dashed line: Velocity-based projection
/// - Shaded band: Confidence interval (best/worst case)
/// - Target marker: Goal deadline
class ScienceBackedGrowthChart extends StatefulWidget {
  final Goal goal;
  final List<Todo> todos;
  final VelocityService velocityService;

  const ScienceBackedGrowthChart({
    super.key,
    required this.goal,
    required this.todos,
    required this.velocityService,
  });

  @override
  State<ScienceBackedGrowthChart> createState() => _ScienceBackedGrowthChartState();
}

class _ScienceBackedGrowthChartState extends State<ScienceBackedGrowthChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  VelocityPrediction? _prediction;
  List<VelocitySnapshot> _historicalData = [];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _calculatePrediction();
    _anim.forward();
  }

  @override
  void didUpdateWidget(ScienceBackedGrowthChart oldWidget) {
    if (oldWidget.todos != widget.todos || oldWidget.goal != widget.goal) {
      _calculatePrediction();
      _anim.forward(from: 0);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _calculatePrediction() {
    _prediction = widget.velocityService.predictCompletion(widget.goal, widget.todos);
    _historicalData = widget.velocityService.getDailyVelocities(30)
        .asMap()
        .entries
        .map((e) => VelocitySnapshot(
          date: DateTime.now().subtract(Duration(days: 29 - e.key)),
          tasksCompleted: e.value.toInt(),
          pointsCompleted: 0,
          totalTasks: 0,
          completedTasks: 0,
        ))
        .toList();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goalTodos = widget.todos.where((t) => t.goalId == widget.goal.id).toList();
    final completed = goalTodos.where((t) => t.completed).length;
    final total = goalTodos.length;
    final progress = total > 0 ? completed / total : 0.0;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(progress, completed, total),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: CustomPaint(
                  painter: _GrowthChartPainter(
                    goal: widget.goal,
                    todos: goalTodos,
                    prediction: _prediction,
                    historicalData: _historicalData,
                    progress: progress,
                    animation: Curves.easeOutCubic.transform(_anim.value),
                  ),
                  size: Size.infinite,
                ),
              ),
              const SizedBox(height: 16),
              _buildPredictionSummary(),
              const SizedBox(height: 12),
              _buildLegend(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(double progress, int completed, int total) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.goal.title,
                style: GoogleFonts.comfortaa(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '$completed of $total tasks completed',
                style: GoogleFonts.comfortaa(
                  fontSize: 11,
                  color: AppColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.chip,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${(progress * 100).round()}%',
            style: GoogleFonts.comfortaa(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionSummary() {
    if (_prediction == null || !_prediction!.hasReliablePrediction) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.chip,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.inkFaint),
            const SizedBox(width: 8),
            Text(
              'Complete more tasks to see predictions',
              style: GoogleFonts.comfortaa(
                fontSize: 11,
                color: AppColors.inkFaint,
              ),
            ),
          ],
        ),
      );
    }

    final statusColor = _getStatusColor();
    final status = widget.velocityService.getGoalProgressStatus(widget.goal, widget.todos);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(status), size: 18, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _prediction!.summary,
                  style: GoogleFonts.comfortaa(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'Based on ${_prediction!.velocity.toStringAsFixed(1)} tasks/day · ${_prediction!.confidenceDescription}',
                  style: GoogleFonts.comfortaa(
                    fontSize: 10,
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          if (widget.goal.targetDate != null) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${widget.goal.daysRemaining}d left',
                  style: GoogleFonts.comfortaa(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'target',
                  style: GoogleFonts.comfortaa(
                    fontSize: 9,
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        _legendItem('Actual', Colors.black, false),
        _legendItem('Projected', Colors.black54, true),
        _legendItem('Confidence', Colors.black12, false, isBox: true),
        if (widget.goal.targetDate != null)
          _legendItem('Target', const Color(0xFFE53935), false, isVertical: true),
      ],
    );
  }

  Widget _legendItem(String label, Color color, bool dashed,
      {bool isBox = false, bool isVertical = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBox)
          Container(
            width: 20,
            height: 10,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else if (isVertical)
          Container(
            width: 2,
            height: 12,
            color: color,
          )
        else
          SizedBox(
            width: 20,
            height: 10,
            child: CustomPaint(
              painter: _DashLinePainter(dashed: dashed, color: color),
            ),
          ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.comfortaa(fontSize: 9, color: AppColors.inkFaint),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    final status = widget.velocityService.getGoalProgressStatus(widget.goal, widget.todos);
    return switch (status) {
      GoalProgressStatus.onTrack => const Color(0xFF43A047),
      GoalProgressStatus.atRisk => const Color(0xFFFFA726),
      GoalProgressStatus.behind => const Color(0xFFE53935),
      GoalProgressStatus.noDeadline => AppColors.inkFaint,
      GoalProgressStatus.insufficientData => AppColors.inkFaint,
    };
  }

  IconData _getStatusIcon(GoalProgressStatus status) {
    return switch (status) {
      GoalProgressStatus.onTrack => Icons.check_circle,
      GoalProgressStatus.atRisk => Icons.warning_amber,
      GoalProgressStatus.behind => Icons.error_outline,
      GoalProgressStatus.noDeadline => Icons.calendar_today,
      GoalProgressStatus.insufficientData => Icons.help_outline,
    };
  }
}

// ── Growth Chart Painter ────────────────────────────────────────────

class _GrowthChartPainter extends CustomPainter {
  final Goal goal;
  final List<Todo> todos;
  final VelocityPrediction? prediction;
  final List<VelocitySnapshot> historicalData;
  final double progress;
  final double animation;

  static const _leftPad = 40.0;
  static const _rightPad = 16.0;
  static const _topPad = 16.0;
  static const _bottomPad = 32.0;

  _GrowthChartPainter({
    required this.goal,
    required this.todos,
    required this.prediction,
    required this.historicalData,
    required this.progress,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width - _leftPad - _rightPad;
    final ch = size.height - _topPad - _bottomPad;

    _drawGrid(canvas, cw, ch, size);
    _drawAxes(canvas, cw, ch, size);
    _drawAxisLabels(canvas, cw, ch, size);

    if (prediction != null && prediction!.hasReliablePrediction) {
      _drawConfidenceBand(canvas, cw, ch, size);
      _drawProjection(canvas, cw, ch, size);
    }

    _drawHistorical(canvas, cw, ch, size);

    if (goal.targetDate != null) {
      _drawTargetLine(canvas, cw, ch, size);
    }
  }

  void _drawGrid(Canvas canvas, double cw, double ch, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = _topPad + (ch * i / 4);
      canvas.drawLine(
        Offset(_leftPad, y),
        Offset(_leftPad + cw, y),
        paint,
      );
    }
  }

  void _drawAxes(Canvas canvas, double cw, double ch, Size size) {
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Y-axis
    canvas.drawLine(
      Offset(_leftPad, _topPad),
      Offset(_leftPad, _topPad + ch),
      paint,
    );

    // X-axis
    canvas.drawLine(
      Offset(_leftPad, _topPad + ch),
      Offset(_leftPad + cw, _topPad + ch),
      paint,
    );
  }

  void _drawAxisLabels(Canvas canvas, double cw, double ch, Size size) {
    final style = GoogleFonts.comfortaa(fontSize: 8, color: AppColors.inkFaint);

    // Y-axis labels (percentage)
    for (int i = 0; i <= 4; i++) {
      final y = _topPad + ch - (ch * i / 4);
      final tp = TextPainter(
        text: TextSpan(text: '${i * 25}%', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_leftPad - tp.width - 8, y - tp.height / 2));
    }

    // X-axis label
    final xLabel = TextPainter(
      text: TextSpan(text: 'Days', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    xLabel.paint(canvas, Offset(_leftPad + cw / 2 - xLabel.width / 2, _topPad + ch + 8));
  }

  void _drawHistorical(Canvas canvas, double cw, double ch, Size size) {
    if (historicalData.isEmpty || animation <= 0) return;

    final rng = Random(goal.id.hashCode);
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final points = <Offset>[];
    final totalDays = historicalData.length;
    final maxDays = prediction?.expectedDays ?? 30;

    // Build cumulative progress
    double cumulative = 0;
    final completed = todos.where((t) => t.completed).length;
    final total = todos.length;

    for (int i = 0; i < historicalData.length; i++) {
      final day = i.toDouble();
      final x = _leftPad + (day / (totalDays + maxDays)) * cw;

      // Cumulative completion based on historical data
      final dayProgress = (i + 1) / totalDays;
      cumulative = progress * dayProgress;

      final y = _topPad + ch - (cumulative * ch);
      points.add(Offset(x, y));
    }

    if (points.isNotEmpty && animation > 0) {
      final animatedPoints = points.take((points.length * animation).round()).toList();
      if (animatedPoints.length >= 2) {
        final path = _smoothPath(animatedPoints);
        canvas.drawPath(path, paint);
      }

      // Draw dot at end
      if (animatedPoints.isNotEmpty) {
        final dotPaint = Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.fill;
        canvas.drawCircle(animatedPoints.last, 4, dotPaint);
      }
    }
  }

  void _drawProjection(Canvas canvas, double cw, double ch, Size size) {
    if (prediction == null || !prediction!.hasReliablePrediction || animation < 0.5) return;

    final animProgress = (animation - 0.5) * 2; // Start projection after historical

    final paint = Paint()
      ..color = AppColors.ink.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final totalDays = historicalData.length + prediction!.expectedDays;
    final startDay = historicalData.length.toDouble();

    final points = <Offset>[];

    // Start from current progress
    final startX = _leftPad + (startDay / totalDays) * cw;
    final startY = _topPad + ch - (progress * ch);
    points.add(Offset(startX, startY));

    // Project to 100%
    final endX = _leftPad + cw;
    final endY = _topPad;

    // Add intermediate points for smooth curve
    final steps = 20;
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final x = startX + (endX - startX) * t;
      final y = startY + (endY - startY) * t;
      points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      // Draw dashed
      _drawDashedPath(canvas, points, paint);
    }
  }

  void _drawConfidenceBand(Canvas canvas, double cw, double ch, Size size) {
    if (prediction == null || !prediction!.hasReliablePrediction || animation < 0.6) return;

    final animProgress = (animation - 0.6) * 2.5;

    final totalDays = historicalData.length + prediction!.expectedDays;
    final startDay = historicalData.length.toDouble();

    final startX = _leftPad + (startDay / totalDays) * cw;
    final startY = _topPad + ch - (progress * ch);
    final endX = _leftPad + cw;

    // Best case path (faster completion)
    final bestPath = Path();
    final bestEndX = _leftPad + ((startDay + prediction!.bestCaseDays) / totalDays) * cw;

    bestPath.moveTo(startX, startY);
    bestPath.lineTo(bestEndX.clamp(startX, endX), _topPad);

    // Worst case path (slower completion)
    final worstPath = Path();
    final worstEndX = _leftPad + ((startDay + prediction!.worstCaseDays) / totalDays) * cw;

    worstPath.moveTo(startX, startY);
    worstPath.lineTo(worstEndX.clamp(startX, endX + 20), _topPad);

    // Draw confidence band
    final bandPath = Path();
    bandPath.moveTo(startX, startY);
    bandPath.lineTo(bestEndX.clamp(startX, endX), _topPad);
    bandPath.lineTo(worstEndX.clamp(startX, endX + 20), _topPad);
    bandPath.close();

    final bandPaint = Paint()
      ..color = AppColors.ink.withOpacity(0.08 * animProgress)
      ..style = PaintingStyle.fill;

    canvas.drawPath(bandPath, bandPaint);
  }

  void _drawTargetLine(Canvas canvas, double cw, double ch, Size size) {
    if (goal.targetDate == null || animation < 0.3) return;

    final animProgress = (animation - 0.3) * 1.4;
    final totalDays = historicalData.length +
        (prediction?.expectedDays ?? goal.daysRemaining);
    final targetDay = historicalData.length + goal.daysRemaining;

    final x = _leftPad + (targetDay / totalDays) * cw;

    final paint = Paint()
      ..color = const Color(0xFFE53935).withOpacity(0.6 * animProgress)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Dashed vertical line
    _drawDashedLine(
      canvas,
      Offset(x, _topPad),
      Offset(x, _topPad + ch),
      paint,
    );

    // Target label
    final tp = TextPainter(
      text: TextSpan(
        text: 'Target',
        style: GoogleFonts.comfortaa(fontSize: 8, color: const Color(0xFFE53935)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, _topPad + ch + 4));
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

    const dashLen = 5.0;
    const gapLen = 3.0;

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
  bool shouldRepaint(covariant _GrowthChartPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.progress != progress ||
        oldDelegate.todos != todos ||
        oldDelegate.prediction != prediction;
  }
}

class _DashLinePainter extends CustomPainter {
  final bool dashed;
  final Color color;

  _DashLinePainter({required this.dashed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    if (!dashed) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    } else {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(x + 4, size.height / 2),
          paint,
        );
        x += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
