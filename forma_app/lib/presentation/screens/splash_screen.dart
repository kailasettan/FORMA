import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const double _baseCircleSize = 80;

  late final AnimationController _controller;
  late final Animation<double> _circleProgress;
  late final Animation<double> _textOpacity;
  late final Animation<double> _textOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _circleProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.7, curve: Curves.easeInOutCubic),
    );
    _textOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
    );
    _textOffset = Tween<double>(begin: 22, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward().whenComplete(() {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.background : Colors.white;
    final circleColor = isDark ? AppTheme.primary : const Color(0xFF111827);
    final textColor = Colors.white;
    final textStyle = theme.textTheme.headlineLarge?.copyWith(
      color: textColor,
      fontSize: 34,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      height: 1,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final screenDiagonal = math.sqrt(width * width + height * height);
          final requiredScale = (screenDiagonal / _baseCircleSize) * 1.2;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Transform.scale(
                      scale: requiredScale * _circleProgress.value,
                      child: Container(
                        width: _baseCircleSize,
                        height: _baseCircleSize,
                        decoration: BoxDecoration(
                          color: circleColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, _textOffset.value),
                    child: Opacity(
                      opacity: _textOpacity.value,
                      child: Text(
                        'FORMA',
                        textAlign: TextAlign.center,
                        style: textStyle,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
