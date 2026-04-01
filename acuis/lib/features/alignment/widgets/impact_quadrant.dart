import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/todo.dart';
import '../../../main.dart'; // For AppColors

class ImpactQuadrant extends StatefulWidget {
  final List<Todo> todos;
  const ImpactQuadrant({super.key, required this.todos});

  @override
  State<ImpactQuadrant> createState() => _ImpactQuadrantState();
}

class _ImpactQuadrantState extends State<ImpactQuadrant> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _anim.forward();
  }

  @override
  void didUpdateWidget(ImpactQuadrant oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    final scoredTodos = widget.todos.where((t) => t.alignmentScore != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Impact Quadrant',
            style: GoogleFonts.comfortaa(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 4),
        Text('Are you doing the right things?',
            style: GoogleFonts.comfortaa(
                fontSize: 12, color: AppColors.inkFaint)),
        const SizedBox(height: 16),
        Text('Each dot is a task. Top = highly aligned with your goal. Right = completed.',
            style: GoogleFonts.comfortaa(
                fontSize: 10, color: AppColors.inkFaint, fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              children: [
                // Labels layer
                Positioned(top: 16, left: 16, child: _Qlabel('To-Do\nPriority')),
                Positioned(top: 16, right: 16, child: _Qlabel('Done\nBig Wins', alignRight: true)),
                Positioned(bottom: 16, left: 16, child: _Qlabel('To-Do\nLow Impact')),
                Positioned(bottom: 16, right: 16, child: _Qlabel('Done\nBusywork', alignRight: true)),
                // Canvas layer
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, child) {
                    final curve = Curves.elasticOut.transform(_anim.value);
                    return CustomPaint(
                      size: Size.infinite,
                      painter: _QuadrantPainter(todos: scoredTodos, progress: curve),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _Qlabel(String text, {bool alignRight = false}) {
    return Text(text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: GoogleFonts.comfortaa(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.inkLight,
        ));
  }
}

class _QuadrantPainter extends CustomPainter {
  final List<Todo> todos;
  final double progress;

  _QuadrantPainter({required this.todos, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = AppColors.inkFaint.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // Center axes (sketchy imperfect lines)
    final cx = size.width / 2;
    final cy = size.height / 2;
    
    // Y-axis
    canvas.drawLine(Offset(cx, 16), Offset(cx, size.height - 16), axisPaint);
    // X-axis
    canvas.drawLine(Offset(16, cy), Offset(size.width - 16, cy), axisPaint);

    final hFill = Paint()..style = PaintingStyle.fill;
    final hBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.surface;

    // Draw points
    for (int i = 0; i < todos.length; i++) {
      final t = todos[i];
      final r = Random(t.id.hashCode);

      final isDone = t.completed;
      final score = t.alignmentScore!.clamp(0.0, 100.0);

      // Jitter horizontally inside the correct half
      final pad = 30.0;
      final minX = isDone ? cx + pad : pad;
      final maxX = isDone ? size.width - pad : cx - pad;
      final x = minX + r.nextDouble() * (maxX - minX);

      // Y maps 0-100 to bottom-top
      final minY = pad;
      final maxY = size.height - pad;
      final y = maxY - (score / 100.0) * (maxY - minY);

      // Cascade animation based on index
      final delay = i * 0.05;
      final dotScale = (progress - delay).clamp(0.0, 1.0);
      if (dotScale <= 0) continue;

      hFill.color = isDone ? AppColors.inkLight : AppColors.ink;

      canvas.drawCircle(Offset(x, y), 6.0 * dotScale, hFill);
      canvas.drawCircle(Offset(x, y), 6.0 * dotScale, hBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _QuadrantPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.todos != todos;
  }
}
