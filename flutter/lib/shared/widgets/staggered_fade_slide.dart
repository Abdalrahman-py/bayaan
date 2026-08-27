import 'package:flutter/material.dart';

class StaggeredFadeSlide extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration delayStep;
  final Duration itemDuration;

  /// Whether to play the entrance at all. The stagger belongs to the moment
  /// the list appears; a row built later — because the user scrolled to it —
  /// passes false and renders finished instead of replaying it.
  final bool animate;

  const StaggeredFadeSlide({
    super.key,
    required this.index,
    required this.child,
    this.delayStep = const Duration(milliseconds: 60),
    this.itemDuration = const Duration(milliseconds: 400),
    this.animate = true,
  });

  @override
  State<StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.itemDuration,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fade);

    if (!widget.animate) {
      _controller.value = 1;
      return;
    }

    // نحدد سقف أقصى للتأخير حتى لو القايمة طويلة كتير (114 سورة)
    final cappedIndex = widget.index.clamp(0, 12);
    Future.delayed(widget.delayStep * cappedIndex, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
