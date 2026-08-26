import 'package:flutter/material.dart';

import '../../../core/theme/app_fonts.dart';

/// One side of the compare screen: a badge (master vs your recitation), a
/// play button with an animated progress waveform, and optional red error
/// bars where mistakes happened. Ported from the bayyan client.
class AudioCompareCard extends StatefulWidget {
  final String badgeLabel;
  final Color badgeBg;
  final Color badgeTextColor;
  final String trailingText;
  final Color trailingTextColor;
  final Color playButtonColor;
  final Color iconColor;
  final Color borderColor;
  final List<double> waveformHeights;
  final Color waveformColor;
  final Set<int> errorBarIndices;

  const AudioCompareCard({
    super.key,
    required this.badgeLabel,
    required this.badgeBg,
    required this.badgeTextColor,
    required this.trailingText,
    required this.trailingTextColor,
    required this.playButtonColor,
    required this.iconColor,
    required this.borderColor,
    required this.waveformHeights,
    required this.waveformColor,
    this.errorBarIndices = const {},
  });

  @override
  State<AudioCompareCard> createState() => _AudioCompareCardState();
}

class _AudioCompareCardState extends State<AudioCompareCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isPlaying = false);
        _progressController.reset();
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    // TODO: play the actual audio file once a reference/recording source
    // exists (lesson_audio_player currently covers bundled letter clips).
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _progressController.forward(from: 0);
    } else {
      _progressController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: widget.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.badgeLabel.toUpperCase(),
                  style: pjs(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.badgeTextColor,
                  ),
                ),
              ),
              Text(
                widget.trailingText,
                style: pjs(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.trailingTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.playButtonColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 16,
                    color: widget.iconColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildWaveform()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (context, child) {
          final int highlightCount =
              (widget.waveformHeights.length * _progressController.value)
                  .floor();
          return Row(
            children: List.generate(widget.waveformHeights.length, (index) {
              final bool isError = widget.errorBarIndices.contains(index);
              final bool isPlayed = _isPlaying && index <= highlightCount;
              Color barColor;
              if (isError) {
                barColor = const Color(0xFFE11D48);
              } else if (isPlayed) {
                barColor = widget.waveformColor;
              } else {
                barColor = widget.waveformColor.withValues(alpha: 
                  _isPlaying ? 0.35 : 1,
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  width: 3,
                  height: widget.waveformHeights[index],
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
