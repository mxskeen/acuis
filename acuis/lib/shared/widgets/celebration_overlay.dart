import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../services/gamification_service.dart';

/// Celebration Overlay Widget
///
/// Displays celebratory animations when users achieve milestones:
/// - Confetti burst
/// - Level up animation
/// - Achievement unlock
/// - Streak warnings (loss aversion)
class CelebrationOverlay extends StatefulWidget {
  final Celebration celebration;
  final VoidCallback onDismiss;

  const CelebrationOverlay({
    super.key,
    required this.celebration,
    required this.onDismiss,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late List<_ConfettiParticle> _confetti;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Generate confetti particles
    _confetti = List.generate(30, (i) => _ConfettiParticle.random(i));

    _controller.forward();

    // Auto dismiss after animation
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      child: Stack(
        children: [
          // Confetti
          if (widget.celebration.type != CelebrationType.streakWarning)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _confetti,
                    progress: _controller.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),

          // Center content
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnim.value,
                  child: Opacity(
                    opacity: _fadeAnim.value,
                    child: _buildContent(),
                  ),
                );
              },
            ),
          ),

          // Tap to dismiss
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onDismiss,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final isWarning = widget.celebration.type == CelebrationType.streakWarning;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji
          Text(
            widget.celebration.emoji,
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            _getTitle(),
            style: GoogleFonts.comfortaa(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isWarning ? const Color(0xFFE53935) : AppColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Message
          Text(
            widget.celebration.message,
            style: GoogleFonts.comfortaa(
              fontSize: 14,
              color: AppColors.inkLight,
            ),
            textAlign: TextAlign.center,
          ),

          // Points badge
          if (widget.celebration.points > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB700)),
                  const SizedBox(width: 6),
                  Text(
                    '+${widget.celebration.points} points',
                    style: GoogleFonts.comfortaa(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Achievement badge
          if (widget.celebration.achievement != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.celebration.achievement!.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.celebration.achievement!.title,
                        style: GoogleFonts.comfortaa(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        widget.celebration.achievement!.description,
                        style: GoogleFonts.comfortaa(
                          fontSize: 10,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Streak warning urgency
          if (isWarning && widget.celebration.hoursLeft != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, size: 20, color: Color(0xFFE53935)),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.celebration.hoursLeft} hours left today',
                    style: GoogleFonts.comfortaa(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE53935),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Dismiss button
          Text(
            'Tap anywhere to continue',
            style: GoogleFonts.comfortaa(
              fontSize: 11,
              color: AppColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    return switch (widget.celebration.type) {
      CelebrationType.highAlignment => 'Perfect Alignment!',
      CelebrationType.smartExcellence => 'SMART Move!',
      CelebrationType.highImpact => 'High Impact!',
      CelebrationType.goalComplete => 'Goal Achieved!',
      CelebrationType.streakWarning => 'Streak at Risk!',
      CelebrationType.levelUp => 'Level Up!',
      CelebrationType.achievement => 'Achievement Unlocked!',
    };
  }
}

// ── Confetti Particle ────────────────────────────────────────────

class _ConfettiParticle {
  final double x;
  final double y;
  final double size;
  final Color color;
  final double rotation;
  final double speed;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.rotation,
    required this.speed,
  });

  factory _ConfettiParticle.random(int index) {
    final colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFFFFE66D),
      const Color(0xFF95E1D3),
      const Color(0xFFF38181),
      const Color(0xFFAA96DA),
    ];

    final rng = Random(index);
    return _ConfettiParticle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: 6 + rng.nextDouble() * 8,
      color: colors[rng.nextInt(colors.length)],
      rotation: rng.nextDouble() * 2 * pi,
      speed: 0.5 + rng.nextDouble() * 0.5,
    );
  }
}

// ── Confetti Painter ────────────────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final animation = Curves.easeOut.transform(progress);

      // Calculate position (falling from top)
      final startX = p.x * size.width;
      final startY = -50.0;
      final endY = size.height + 50;

      final currentY = startY + (endY - startY) * animation * p.speed;
      final currentX = startX + sin(progress * pi * 4 + p.rotation) * 50;

      // Draw confetti
      final paint = Paint()..color = p.color;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(p.rotation + progress * pi * 2);

      // Draw rectangle confetti
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Helper function to show celebration
void showCelebration(BuildContext context, Celebration celebration) {
  showDialog(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    builder: (ctx) => CelebrationOverlay(
      celebration: celebration,
      onDismiss: () => Navigator.of(ctx).pop(),
    ),
  );
}
