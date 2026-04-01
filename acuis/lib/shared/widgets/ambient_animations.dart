import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';

/// Animated progress ring that fills on load
class AnimatedProgressRing extends StatefulWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final Widget? child;
  final Duration duration;

  const AnimatedProgressRing({
    super.key,
    required this.value,
    this.size = 80,
    this.strokeWidth = 8,
    this.color,
    this.backgroundColor,
    this.child,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<AnimatedProgressRing> createState() => _AnimatedProgressRingState();
}

class _AnimatedProgressRingState extends State<AnimatedProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: _animation.value / 100,
                strokeWidth: widget.strokeWidth,
                backgroundColor: widget.backgroundColor ?? AppColors.bg,
                valueColor: AlwaysStoppedAnimation(
                  widget.color ?? AppColors.ink,
                ),
              ),
              if (widget.child != null) Center(child: widget.child),
            ],
          ),
        );
      },
    );
  }
}

/// Animated counter that counts up on load
class AnimatedCounter extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String? suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.suffix,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = IntTween(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = IntTween(
        begin: _animation.value,
        end: widget.value,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${_animation.value}${widget.suffix ?? ''}',
          style: widget.style,
        );
      },
    );
  }
}

/// Pulsing glow effect for important elements (e.g., streak at risk)
class PulsingGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double maxGlowRadius;
  final Duration duration;

  const PulsingGlow({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFFFF6B35),
    this.maxGlowRadius = 12,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<PulsingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: widget.maxGlowRadius), weight: 0.5),
      TweenSequenceItem(tween: Tween(begin: widget.maxGlowRadius, end: 0), weight: 0.5),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.3),
                blurRadius: _animation.value,
                spreadRadius: _animation.value * 0.5,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Subtle breathing animation for cards
class BreathingCard extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final bool enabled;

  const BreathingCard({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 3000),
    this.minScale = 0.98,
    this.enabled = true,
  });

  @override
  State<BreathingCard> createState() => _BreathingCardState();
}

class _BreathingCardState extends State<BreathingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: widget.minScale),
        weight: 0.5,
      ),
      TweenSequenceItem(
        tween: Tween(begin: widget.minScale, end: 1.0),
        weight: 0.5,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(BreathingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _controller.repeat();
    } else if (!widget.enabled && oldWidget.enabled) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}

/// Animated progress bar that fills on load
class AnimatedProgressBar extends StatefulWidget {
  final double value;
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final Duration duration;
  final BorderRadius? borderRadius;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 4,
    this.color,
    this.backgroundColor,
    this.duration = const Duration(milliseconds: 1000),
    this.borderRadius,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: _animation.value,
            minHeight: widget.height,
            backgroundColor: widget.backgroundColor ?? AppColors.border,
            valueColor: AlwaysStoppedAnimation(widget.color ?? AppColors.ink),
          ),
        );
      },
    );
  }
}

/// Shimmer effect for loading states
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.baseColor ?? AppColors.surface,
                widget.highlightColor ?? AppColors.bg,
                widget.baseColor ?? AppColors.surface,
              ],
              stops: [
                0.0,
                0.5,
                1.0,
              ],
              transform: _SlideGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double slidePercent;

  _SlideGradientTransform(this.slidePercent);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Staggered animation for list items
class StaggeredAnimatedList extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Duration itemDelay;
  final Duration itemDuration;

  const StaggeredAnimatedList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemDelay = const Duration(milliseconds: 80),
    this.itemDuration = const Duration(milliseconds: 400),
  });

  @override
  State<StaggeredAnimatedList> createState() => _StaggeredAnimatedListState();
}

class _StaggeredAnimatedListState extends State<StaggeredAnimatedList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.itemDelay.inMilliseconds * widget.itemCount +
            widget.itemDuration.inMilliseconds,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        final startDelay = widget.itemDelay.inMilliseconds * index;
        final itemAnimation = Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              startDelay / _controller.duration!.inMilliseconds,
              (startDelay + widget.itemDuration.inMilliseconds) /
                  _controller.duration!.inMilliseconds,
              curve: Curves.easeOutCubic,
            ),
          ),
        );

        final opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              startDelay / _controller.duration!.inMilliseconds,
              (startDelay + widget.itemDuration.inMilliseconds) /
                  _controller.duration!.inMilliseconds,
              curve: Curves.easeOutCubic,
            ),
          ),
        );

        return SlideTransition(
          position: itemAnimation,
          child: FadeTransition(
            opacity: opacityAnimation,
            child: widget.itemBuilder(context, index),
          ),
        );
      },
    );
  }
}

/// Floating animation for icons/emojis
class FloatingIcon extends StatefulWidget {
  final String emoji;
  final double size;

  const FloatingIcon({
    super.key,
    required this.emoji,
    this.size = 24,
  });

  @override
  State<FloatingIcon> createState() => _FloatingIconState();
}

class _FloatingIconState extends State<FloatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -4), weight: 0.5),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 0.5),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Text(widget.emoji, style: TextStyle(fontSize: widget.size)),
        );
      },
    );
  }
}
