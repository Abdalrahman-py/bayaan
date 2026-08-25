import 'package:flutter/material.dart';

class AnimatedArabicText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration duration;
  final VoidCallback? onComplete;

  const AnimatedArabicText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.center,
    this.duration = const Duration(milliseconds: 1800),
    this.onComplete,
  });

  @override
  State<AnimatedArabicText> createState() => _AnimatedArabicTextState();
}

class _AnimatedArabicTextState extends State<AnimatedArabicText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late Characters _clusters; // كل حرف + حركاته كوحدة واحدة

  @override
  void initState() {
    super.initState();
    _clusters = widget.text.characters;

    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete?.call();
    });

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedArabicText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // لو تغيّرت الآية (مثلاً جاية جديدة من الـ API) نعيد الحركة من الصفر
    if (oldWidget.text != widget.text) {
      _clusters = widget.text.characters;
      _controller
        ..reset()
        ..forward();
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
        final int visibleCount = (_clusters.length * _animation.value).round();
        final String visibleText = _clusters.take(visibleCount).toString();
        return Text(
          visibleText,
          textDirection: TextDirection.rtl,
          textAlign: widget.textAlign,
          style: widget.style,
        );
      },
    );
  }
}
