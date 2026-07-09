import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Indicador de áudio vivo (elemento assinatura). Respeita
/// `prefers-reduced-motion` exibindo barras estáticas.
class AudioLevelIndicator extends StatefulWidget {
  final bool active;
  const AudioLevelIndicator({super.key, required this.active});

  @override
  State<AudioLevelIndicator> createState() => _AudioLevelIndicatorState();
}

class _AudioLevelIndicatorState extends State<AudioLevelIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  static const _seeds = [0.4, 0.8, 0.55, 0.95, 0.6, 0.75, 0.45];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final color = widget.active ? AppColors.success : AppColors.textMuted;

    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _seeds.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: (reduceMotion || !widget.active)
                  ? _bar(_seeds[i] * 48, color)
                  : AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final phase = (_controller.value + i / _seeds.length);
                        final h = 12 + (sin(phase * 2 * pi).abs()) * 36;
                        return _bar(h, color);
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _bar(double height, Color color) {
    return Container(
      width: 6,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
