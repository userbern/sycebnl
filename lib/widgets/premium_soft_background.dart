import 'dart:math';

import 'package:flutter/material.dart';

/// Arrière-plan décoratif « premium doux » : dégradé bleu très clair vers
/// blanc cassé, halos lumineux flous, courbes abstraites discrètes et
/// micro-particules quasi imperceptibles, avec un très léger mouvement des
/// halos.
///
/// Purement visuel : ne contient aucune logique métier, ne modifie ni ne
/// contraint [child] — il est simplement peint derrière lui.
class PremiumSoftBackground extends StatefulWidget {
  final Widget child;

  const PremiumSoftBackground({super.key, required this.child});

  @override
  State<PremiumSoftBackground> createState() => _PremiumSoftBackgroundState();
}

class _PremiumSoftBackgroundState extends State<PremiumSoftBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Boucle très lente (~28s) : le mouvement des halos doit rester
    // quasi imperceptible, jamais distrayant.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEAF2FC), Color(0xFFFAFBFC)],
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _SoftBackgroundPainter(_controller.value),
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _SoftBackgroundPainter extends CustomPainter {
  final double t; // 0..1, boucle continue

  _SoftBackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final driftA = sin(t * 2 * pi);
    final driftB = sin(t * 2 * pi + pi / 2);

    // Grands halos lumineux flous et translucides (déplacement à peine
    // perceptible autour de leur position de repos).
    _paintHalo(
      canvas,
      Offset(w * 0.08 + driftA * w * 0.015, h * 0.06 + driftB * h * 0.012),
      w * 0.42,
      const Color(0xFF6FA8F0),
      0.16,
    );
    _paintHalo(
      canvas,
      Offset(w * 0.96 - driftB * w * 0.015, h * 0.9 - driftA * h * 0.012),
      w * 0.5,
      const Color(0xFF4C7FE0),
      0.13,
    );
    _paintHalo(
      canvas,
      Offset(w * 0.8 + driftA * w * 0.01, h * 0.16 - driftB * h * 0.008),
      w * 0.26,
      const Color(0xFF34B37A), // légère touche verte (bouton "Démarrer")
      0.045,
    );
    _paintHalo(
      canvas,
      Offset(w * 0.14 - driftB * w * 0.01, h * 0.78 + driftA * h * 0.008),
      w * 0.3,
      Colors.white,
      0.4,
    );

    _paintSwooshes(canvas, size);
    _paintParticles(canvas, size);
  }

  void _paintHalo(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    final paint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _paintSwooshes(Canvas canvas, Size size) {
    final path1 =
        Path()
          ..moveTo(-size.width * 0.1, size.height * 0.35)
          ..quadraticBezierTo(
            size.width * 0.5,
            size.height * 0.05,
            size.width * 1.1,
            size.height * 0.45,
          );
    canvas.drawPath(
      path1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.22
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFBFD7F5).withValues(alpha: 0.10),
    );

    final path2 =
        Path()
          ..moveTo(size.width * 0.1, size.height * 1.05)
          ..quadraticBezierTo(
            size.width * 0.6,
            size.height * 0.78,
            size.width * 1.05,
            size.height * 1.0,
          );
    canvas.drawPath(
      path2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.16
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFCFE0F7).withValues(alpha: 0.09),
    );
  }

  /// Micro-particules très fines et fixes (positions stables d'un frame à
  /// l'autre grâce à une graine constante) : presque imperceptibles, elles
  /// ne doivent jamais attirer l'œil.
  void _paintParticles(Canvas canvas, Size size) {
    final random = Random(7);
    final paint = Paint()..color = const Color(0xFF7FA6E0).withValues(alpha: 0.05);
    for (var i = 0; i < 36; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final r = 1.0 + random.nextDouble() * 1.5;
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoftBackgroundPainter oldDelegate) =>
      oldDelegate.t != t;
}
