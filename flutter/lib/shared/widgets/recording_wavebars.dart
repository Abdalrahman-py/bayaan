import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Height of one waveform bar at animation value [t] in [0, 1].
/// Even bars follow [t], odd bars follow 1 - t, so neighbours move in
/// counterphase (ported from the bayyan recording screen).
double waveBarHeight(int index, double base, double t, {required bool active}) {
  if (!active) return base;
  final phase = index.isEven ? t : 1 - t;
  return base * (0.5 + phase * 0.9);
}

/// Dancing waveform bars under the recording caption — animated while
/// recording, static when idle.
class RecordingWavebars extends StatefulWidget {
  final bool active;

  const RecordingWavebars({super.key, required this.active});

  @override
  State<RecordingWavebars> createState() => _RecordingWavebarsState();
}

class _RecordingWavebarsState extends State<RecordingWavebars>
    with SingleTickerProviderStateMixin {
  static const List<double> _baseHeights = [12.0, 20.0, 16.0, 28.0, 8.0, 24.0, 18.0];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant RecordingWavebars oldWidget) {
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
      height: 32,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_baseHeights.length, (index) {
              final height = waveBarHeight(
                index,
                _baseHeights[index],
                _controller.value,
                active: widget.active,
              );
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 3,
                height: height,
                decoration: BoxDecoration(
                  color: widget.active || _baseHeights[index] > 15
                      ? AppColors.gold
                      : const Color(0xFFE0DCD3),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
