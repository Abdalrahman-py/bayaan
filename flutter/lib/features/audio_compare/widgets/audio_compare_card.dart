import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_palette.dart';
import '../../../services/reciter_audio.dart';

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

  /// Real audio to play. Without one the card keeps its simulated playback —
  /// the user's own recitation is never kept after upload, so that card has
  /// nothing to stream.
  final Uri? audioUrl;

  /// Audio held in memory — the user's own recording. Takes precedence over
  /// [audioUrl] when both are somehow set.
  final Uint8List? audioBytes;

  /// Start playing as soon as the card is ready, without a tap. Browsers may
  /// still refuse — the gesture exemption is spent by the time the source has
  /// loaded — in which case the card just sits there waiting for the button.
  final bool autoPlay;

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
    this.audioUrl,
    this.audioBytes,
    this.autoPlay = false,
  });

  @override
  State<AudioCompareCard> createState() => _AudioCompareCardState();
}

class _AudioCompareCardState extends State<AudioCompareCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  bool _isPlaying = false;

  ReciterPlayer? _player;

  /// Playback position as a 0..1 fraction, for the real-audio case.
  double _progress = 0;

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

    if (widget.audioUrl == null && widget.audioBytes == null) return;
    final player = _player = ReciterPlayer();
    Duration total = Duration.zero;
    player.onDuration.listen((d) => total = d);
    player.onPosition.listen((pos) {
      if (!mounted || total.inMilliseconds == 0) return;
      setState(() {
        _progress = (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
      });
    });
    player.onComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _progress = 0;
      });
    });
    final url = widget.audioUrl;
    if (url != null && widget.audioBytes == null) {
      player.preload(url).then((_) {
        if (mounted && widget.autoPlay) _togglePlay();
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _player?.dispose();
    super.dispose();
  }

  bool get _hasRealAudio =>
      widget.audioBytes != null || widget.audioUrl != null;

  Future<void> _togglePlay() async {
    final player = _player;
    // ponytail: no real source for this card, so the waveform is still an
    // animated stand-in. Drop this branch once recordings are kept.
    if (!_hasRealAudio || player == null) {
      setState(() => _isPlaying = !_isPlaying);
      if (_isPlaying) {
        _progressController.forward(from: 0);
      } else {
        _progressController.stop();
      }
      return;
    }

    if (_isPlaying) {
      await player.pause();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }
    setState(() => _isPlaying = true);
    try {
      final bytes = widget.audioBytes;
      if (bytes != null) {
        await player.playBytes(bytes);
      } else {
        await player.play(widget.audioUrl!);
      }
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
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
          final double played =
              _hasRealAudio ? _progress : _progressController.value;
          final int highlightCount =
              (widget.waveformHeights.length * played).floor();
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
