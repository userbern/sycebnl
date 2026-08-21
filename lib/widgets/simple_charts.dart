import 'package:flutter/material.dart';

/// Un point d'un graphique en barres (libellé + valeur).
class ChartPoint {
  final String label;
  final double value;
  const ChartPoint(this.label, this.value);
}

/// Un segment d'un camembert (libellé, valeur, couleur).
class PieSegment {
  final String label;
  final double value;
  final Color color;
  const PieSegment(this.label, this.value, this.color);
}

/// Panneau générique de dashboard (cadre blanc, titre en italique), pour
/// reproduire la charte visuelle demandée (cf. maquette fournie).
class DashboardPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const DashboardPanel({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Graphique en barres avec une ligne de tendance/objectif en pointillés,
/// dans le style de la maquette (barres colorées + ligne horizontale
/// pointillée représentant la moyenne ou une cible).
class BarTrendChart extends StatelessWidget {
  final List<ChartPoint> points;
  final Color barColor;
  final double? referenceLine;
  final String referenceLabel;
  final String Function(double) valueFormatter;

  const BarTrendChart({
    super.key,
    required this.points,
    required this.barColor,
    required this.valueFormatter,
    this.referenceLine,
    this.referenceLabel = 'Moyenne',
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text('Aucune donnée', style: TextStyle(color: Colors.grey)),
      );
    }
    return Column(
      children: [
        if (referenceLine != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(width: 14, height: 2, color: Colors.black54),
                const SizedBox(width: 6),
                Text(
                  '$referenceLabel : ${valueFormatter(referenceLine!)}',
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarTrendPainter(
              points: points,
              barColor: barColor,
              referenceLine: referenceLine,
            ),
          ),
        ),
      ],
    );
  }
}

class _BarTrendPainter extends CustomPainter {
  final List<ChartPoint> points;
  final Color barColor;
  final double? referenceLine;

  _BarTrendPainter({
    required this.points,
    required this.barColor,
    this.referenceLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 18.0;
    final chartHeight = size.height - labelHeight;
    if (chartHeight <= 0 || points.isEmpty) return;

    final allValues = [...points.map((p) => p.value), if (referenceLine != null) referenceLine!];
    final maxPos = allValues.fold<double>(0, (a, b) => b > a ? b : a);
    final maxNeg = allValues.fold<double>(0, (a, b) => -b > a ? -b : a);
    final range = (maxPos + maxNeg) * 1.15;
    final scale = range == 0 ? 0.0 : chartHeight / range;
    final zeroY = maxPos * 1.15 * scale;

    final slotWidth = size.width / points.length;
    final barWidth = (slotWidth * 0.55).clamp(4.0, 40.0);

    final barPaint = Paint()..color = barColor;
    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), axisPaint);

    final textStyle = TextStyle(color: Colors.grey.shade700, fontSize: 9);
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final centerX = slotWidth * i + slotWidth / 2;
      final barHeight = p.value.abs() * scale;
      final top = p.value >= 0 ? zeroY - barHeight : zeroY;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(centerX - barWidth / 2, top, barWidth, barHeight),
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
      );
      canvas.drawRRect(rect, barPaint);

      final tp = TextPainter(
        text: TextSpan(text: p.label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(centerX - tp.width / 2, chartHeight + 3),
      );
    }

    if (referenceLine != null) {
      final refY = zeroY - referenceLine! * scale;
      final dashPaint = Paint()
        ..color = Colors.black54
        ..strokeWidth = 1.4;
      const dashWidth = 5.0;
      const gap = 3.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, refY),
          Offset(x + dashWidth, refY),
          dashPaint,
        );
        x += dashWidth + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.barColor != barColor ||
        oldDelegate.referenceLine != referenceLine;
  }
}

/// Camembert simple avec légende, dans le style de la maquette.
class MiniPieChart extends StatelessWidget {
  final List<PieSegment> segments;
  final String Function(double) valueFormatter;

  const MiniPieChart({
    super.key,
    required this.segments,
    required this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (s, seg) => s + seg.value);
    if (total <= 0) {
      return const Center(
        child: Text('Aucune donnée', style: TextStyle(color: Colors.grey)),
      );
    }
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: CustomPaint(
            size: Size.infinite,
            painter: _PiePainter(segments: segments, total: total),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final s in segments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.label,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(s.value / total * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<PieSegment> segments;
  final double total;

  _PiePainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide / 2) * 0.9;
    final center = Offset(size.width / 2, size.height / 2);
    var startAngle = -1.5708; // -90°

    for (final s in segments) {
      final sweep = (s.value / total) * 6.28319;
      final paint = Paint()..color = s.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      startAngle += sweep;
    }

    final holePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.5, holePaint);
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.total != total;
}
