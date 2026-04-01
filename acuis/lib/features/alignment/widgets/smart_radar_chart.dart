import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/smart_scores.dart';
import '../../../main.dart';

/// SMART Radar Chart Widget
///
/// Visualizes SMART criteria scores in a radar/spider chart format:
/// - Specificity (top)
/// - Measurability (top-right)
/// - Achievability (bottom-right)
/// - Relevance (bottom-left)
/// - Time-Bound (top-left)
class SMARTRadarChart extends StatelessWidget {
  final SMARTScores scores;
  final double size;
  final bool showLabels;

  const SMARTRadarChart({
    super.key,
    required this.scores,
    this.size = 200,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Radar chart
          CustomPaint(
            painter: _RadarChartPainter(
              scores: scores,
              color: AppColors.ink,
            ),
            size: Size(size, size),
          ),

          // Labels
          if (showLabels) _buildLabels(),
        ],
      ),
    );
  }

  Widget _buildLabels() {
    return Stack(
      children: _getLabelPositions().map((pos) {
        return Positioned(
          left: pos.x - 30,
          top: pos.y - 10,
          child: Container(
            width: 60,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pos.label,
                  style: GoogleFonts.comfortaa(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${pos.score.round()}',
                  style: GoogleFonts.comfortaa(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  List<_LabelPosition> _getLabelPositions() {
    final cx = size / 2;
    final labelRadius = size / 2 + 20;

    return [
      _LabelPosition(
        x: cx,
        y: cx - labelRadius,
        label: 'Specific',
        score: scores.specificity,
      ),
      _LabelPosition(
        x: cx + labelRadius * cos(18 * pi / 180),
        y: cx - labelRadius * sin(18 * pi / 180),
        label: 'Measurable',
        score: scores.measurability,
      ),
      _LabelPosition(
        x: cx + labelRadius * cos(54 * pi / 180),
        y: cx + labelRadius * sin(54 * pi / 180),
        label: 'Achievable',
        score: scores.achievability,
      ),
      _LabelPosition(
        x: cx - labelRadius * cos(54 * pi / 180),
        y: cx + labelRadius * sin(54 * pi / 180),
        label: 'Relevant',
        score: scores.relevance,
      ),
      _LabelPosition(
        x: cx - labelRadius * cos(18 * pi / 180),
        y: cx - labelRadius * sin(18 * pi / 180),
        label: 'Time-Bound',
        score: scores.timeBound,
      ),
    ];
  }
}

class _LabelPosition {
  final double x;
  final double y;
  final String label;
  final double score;

  _LabelPosition({
    required this.x,
    required this.y,
    required this.label,
    required this.score,
  });
}

class _RadarChartPainter extends CustomPainter {
  final SMARTScores scores;
  final Color color;

  _RadarChartPainter({
    required this.scores,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2 - 30;

    // Draw background rings
    _drawBackgroundRings(canvas, cx, cy, radius);

    // Draw axis lines
    _drawAxisLines(canvas, cx, cy, radius);

    // Draw data polygon
    _drawDataPolygon(canvas, cx, cy, radius);
  }

  void _drawBackgroundRings(Canvas canvas, double cx, double cy, double radius) {
    final ringPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 4; i++) {
      final r = radius * i / 4;
      canvas.drawCircle(Offset(cx, cy), r, ringPaint);
    }
  }

  void _drawAxisLines(Canvas canvas, double cx, double cy, double radius) {
    final axisPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final angles = [270, 342, 54, 126, 198]; // Degrees for each axis

    for (final angle in angles) {
      final radians = angle * pi / 180;
      final x = cx + radius * cos(radians);
      final y = cy + radius * sin(radians);
      canvas.drawLine(Offset(cx, cy), Offset(x, y), axisPaint);
    }
  }

  void _drawDataPolygon(Canvas canvas, double cx, double cy, double radius) {
    final values = [
      scores.specificity,
      scores.measurability,
      scores.achievability,
      scores.relevance,
      scores.timeBound,
    ];

    final angles = [270, 342, 54, 126, 198]; // Degrees for each axis

    final points = <Offset>[];
    for (int i = 0; i < 5; i++) {
      final value = values[i] / 100;
      final radians = angles[i] * pi / 180;
      final x = cx + radius * value * cos(radians);
      final y = cy + radius * value * sin(radians);
      points.add(Offset(x, y));
    }

    // Draw filled polygon
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final fillPath = Path()..addPolygon(points, true);
    canvas.drawPath(fillPath, fillPaint);

    // Draw polygon border
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final strokePath = Path()..addPolygon(points, true);
    canvas.drawPath(strokePath, strokePaint);

    // Draw dots at each point
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.scores != scores;
  }
}

/// Compact SMART indicator for task cards
class SMARTIndicator extends StatelessWidget {
  final SMARTScores scores;
  final double width;

  const SMARTIndicator({
    super.key,
    required this.scores,
    this.width = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          _buildBar('S', scores.specificity, const Color(0xFF4CAF50)),
          _buildBar('M', scores.measurability, const Color(0xFF2196F3)),
          _buildBar('A', scores.achievability, const Color(0xFFFF9800)),
          _buildBar('R', scores.relevance, const Color(0xFF9C27B0)),
          _buildBar('T', scores.timeBound, const Color(0xFFF44336)),
        ],
      ),
    );
  }

  Widget _buildBar(String label, double score, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FractionallySizedBox(
                      heightFactor: 1,
                      widthFactor: score / 100,
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      label,
                      style: GoogleFonts.comfortaa(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
