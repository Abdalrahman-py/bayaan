import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Pulsing rings around the record button while recording (ported from the
/// bayyan client). Idle: two static rings. Active: an expanding, fading ring.
class PulsingRings extends StatefulWidget {
  final bool active;
  final Color color;

  const PulsingRings({super.key, required this.active, this.color = AppColors.tealStart});

  @override
  State<PulsingRings> createState() => _PulsingRingsState();
}

class _PulsingRingsState extends State<PulsingRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PulsingRings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && oldWidget.active) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.active)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final scale = 1.0 + (_controller.value * 0.25);
                final opacity = 0.25 * (1 - _controller.value);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    key: const Key('pulsing-ring'),
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withValues(alpha: opacity + 0.05),
                    ),
                  ),
                );
              },
            ),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.08),
            ),
          ),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
