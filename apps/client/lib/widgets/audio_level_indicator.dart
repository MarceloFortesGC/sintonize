import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Indicador de áudio vivo (elemento assinatura). Mostra o nível REAL
/// (RMS) medido no áudio recebido (web) — as barras mexem de acordo com o
/// som de verdade, não com uma animação decorativa. Em plataformas sem
/// medição real (nativo), [level] permanece 0 e as barras ficam nas
/// alturas mínimas. Respeita `prefers-reduced-motion` exibindo barras
/// estáticas.
class AudioLevelIndicator extends StatelessWidget {
  final bool active;

  /// Nível RMS 0.0-1.0 do áudio recebido. 0 quando não há dado real.
  final double level;

  const AudioLevelIndicator({super.key, required this.active, this.level = 0.0});

  static const _seeds = [0.4, 0.8, 0.55, 0.95, 0.6, 0.75, 0.45];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final color = active ? AppColors.success : AppColors.textMuted;
    // RMS de fala normal fica em ~0.05-0.15; um mapeamento linear deixaria
    // a barra quase parada. A raiz quadrada expande os níveis baixos
    // (0.09 → 0.3, 0.16 → 0.4) mantendo o teto em 1.0.
    final clampedLevel =
        math.pow(level.clamp(0.0, 1.0), 0.5).toDouble();

    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _seeds.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: (reduceMotion || !active)
                  ? _bar(_seeds[i] * 48, color)
                  : AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      width: 6,
                      height: 12 + _seeds[i] * clampedLevel * 36,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
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
