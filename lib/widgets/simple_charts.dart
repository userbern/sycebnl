import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Calcule des graduations "rondes" (0, 200 K, 400 K...) couvrant
/// [minValeur]..[maxValeur], toujours en incluant zéro (axe de référence
/// d'un graphique en barres). Utilisé pour l'axe vertical de
/// [AxisBarChart].
List<double> _graduationsRondes(double minValeur, double maxValeur) {
  var minV = minValeur > 0 ? 0.0 : minValeur;
  var maxV = maxValeur < 0 ? 0.0 : maxValeur;
  if (minV == 0 && maxV == 0) return const [0, 1];

  final range = maxV - minV;
  final rawStep = range / 4;
  final magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
  final residual = rawStep / magnitude;
  final double niceResidual;
  if (residual > 5) {
    niceResidual = 10;
  } else if (residual > 2) {
    niceResidual = 5;
  } else if (residual > 1) {
    niceResidual = 2;
  } else {
    niceResidual = 1;
  }
  final step = niceResidual * magnitude;

  final niceMin = (minV / step).floor() * step;
  final niceMax = (maxV / step).ceil() * step;

  final graduations = <double>[];
  var t = niceMin;
  var garde = 0;
  while (t <= niceMax + step * 0.5 && garde < 12) {
    graduations.add(double.parse(t.toStringAsFixed(6)));
    t += step;
    garde++;
  }
  return graduations;
}

/// Formate une valeur d'axe en milliers/millions (ex. "600 K", "9 M"),
/// pour rester lisible sur un axe étroit.
String _formatAxeCourt(double valeur) {
  final signe = valeur < 0 ? '-' : '';
  final abs = valeur.abs();
  if (abs >= 1000000) {
    final m = abs / 1000000;
    return '$signe${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)} M';
  }
  if (abs >= 1000) {
    final k = abs / 1000;
    return '$signe${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)} K';
  }
  return '$signe${abs.toStringAsFixed(0)}';
}

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

/// Graphique en barres avec axe vertical gradué (K/M), grille horizontale et
/// libellés de mois, dans le style d'un tableau de bord financier complet.
/// Variante "avec axes" de [BarTrendChart], utilisée dans la section
/// « Évolution et répartition ».
class AxisBarChart extends StatelessWidget {
  final List<ChartPoint> points;
  final Color barColor;
  final double? referenceLine;

  const AxisBarChart({
    super.key,
    required this.points,
    required this.barColor,
    this.referenceLine,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Text('Aucune donnée', style: TextStyle(color: Colors.grey)),
      );
    }
    return CustomPaint(
      size: Size.infinite,
      painter: _AxisBarPainter(
        points: points,
        barColor: barColor,
        referenceLine: referenceLine,
      ),
    );
  }
}

class _AxisBarPainter extends CustomPainter {
  final List<ChartPoint> points;
  final Color barColor;
  final double? referenceLine;

  _AxisBarPainter({
    required this.points,
    required this.barColor,
    this.referenceLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const axisWidth = 44.0;
    const bottomLabelHeight = 18.0;
    const topPadding = 14.0;
    final chartWidth = size.width - axisWidth;
    final chartHeight = size.height - bottomLabelHeight - topPadding;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final values = points.map((p) => p.value).toList();
    var maxV = values.fold<double>(0, (a, b) => b > a ? b : a);
    var minV = values.fold<double>(0, (a, b) => b < a ? b : a);
    if (referenceLine != null) {
      if (referenceLine! > maxV) maxV = referenceLine!;
      if (referenceLine! < minV) minV = referenceLine!;
    }
    // Marge de respiration au-dessus/en dessous des données, pour que les
    // barres ne touchent jamais le bord du graphique.
    final graduations = _graduationsRondes(minV * 1.3, maxV * 1.3);
    final axeMin = graduations.first;
    final axeMax = graduations.last;
    final range = (axeMax - axeMin) == 0 ? 1.0 : (axeMax - axeMin);

    double yPour(double v) =>
        topPadding + chartHeight - ((v - axeMin) / range) * chartHeight;

    // Unité, grille et libellés de l'axe vertical.
    final unitTp = TextPainter(
      text: TextSpan(
        text: 'FCFA',
        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    unitTp.paint(canvas, const Offset(0, 0));

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;
    final axisLabelStyle = TextStyle(fontSize: 10, color: Colors.grey.shade500);
    for (final g in graduations) {
      final y = yPour(g);
      canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: _formatAxeCourt(g), style: axisLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: axisWidth - 6);
      tp.paint(canvas, Offset(axisWidth - 6 - tp.width, y - tp.height / 2));
    }

    final zeroY = yPour(0);
    if (axeMin < 0 && axeMax > 0) {
      final axisPaint = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 1;
      canvas.drawLine(Offset(axisWidth, zeroY), Offset(size.width, zeroY), axisPaint);
    }

    // Barres et libellés de mois.
    final slotWidth = chartWidth / points.length;
    final barWidth = (slotWidth * 0.5).clamp(4.0, 36.0);
    final barPaint = Paint()..color = barColor;
    final monthLabelStyle = TextStyle(fontSize: 9, color: Colors.grey.shade600);
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final centerX = axisWidth + slotWidth * i + slotWidth / 2;
      final valY = yPour(p.value);
      final top = p.value >= 0 ? valY : zeroY;
      final height = (p.value >= 0 ? zeroY - valY : valY - zeroY).clamp(0.0, chartHeight);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(centerX - barWidth / 2, top, barWidth, height),
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
      );
      canvas.drawRRect(rect, barPaint);

      final tp = TextPainter(
        text: TextSpan(text: p.label, style: monthLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(centerX - tp.width / 2, size.height - bottomLabelHeight + 3),
      );
    }

    // Ligne de référence (moyenne mensuelle) en pointillés.
    if (referenceLine != null) {
      final refY = yPour(referenceLine!);
      final dashPaint = Paint()
        ..color = Colors.black45
        ..strokeWidth = 1.2;
      const dashWidth = 5.0;
      const gap = 3.0;
      var x = axisWidth;
      while (x < size.width) {
        canvas.drawLine(Offset(x, refY), Offset(x + dashWidth, refY), dashPaint);
        x += dashWidth + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AxisBarPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.barColor != barColor ||
        oldDelegate.referenceLine != referenceLine;
  }
}

/// Panneau complet d'évolution mensuelle (titre, sous-titre, moyenne
/// mensuelle, graphique à axes et légende), pour la section « Évolution et
/// répartition » de la page Indicateurs. Cliquable pour ouvrir le détail de
/// l'indicateur (comptes et écritures), si [onTap] est fourni.
class EvolutionPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final String seriesLabel;
  final Color color;
  final List<ChartPoint> points;
  final String Function(double) valueFormatter;
  final VoidCallback? onTap;

  const EvolutionPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.seriesLabel,
    required this.color,
    required this.points,
    required this.valueFormatter,
    this.onTap,
  });

  double? get _moyenne {
    if (points.isEmpty) return null;
    return points.fold<double>(0, (s, p) => s + p.value) / points.length;
  }

  @override
  Widget build(BuildContext context) {
    final moyenne = _moyenne;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.show_chart, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  if (moyenne != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Moyenne mensuelle',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${valueFormatter(moyenne)} FCFA',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 220,
                child: AxisBarChart(points: points, barColor: color, referenceLine: moyenne),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(seriesLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panneau complet de répartition de l'actif (donut, légende détaillée et
/// bandeau de total), pour la section « Évolution et répartition ».
class AssetRepartitionPanel extends StatelessWidget {
  final String subtitle;
  final List<PieSegment> segments;
  final String Function(double) valueFormatter;

  const AssetRepartitionPanel({
    super.key,
    required this.subtitle,
    required this.segments,
    required this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (s, seg) => s + seg.value);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.pie_chart, color: Color(0xFF6A1B9A), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Répartition de l\'actif',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: total <= 0
                ? const Center(
                    child: Text('Aucune donnée', style: TextStyle(color: Colors.grey)),
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: Size.infinite,
                              painter: _PiePainter(segments: segments, total: total),
                            ),
                            const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '100%',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Total Actif',
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final s in segments)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: s.color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            s.label,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${(s.value / total * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 18, top: 2),
                                      child: Text(
                                        '${valueFormatter(s.value)} FCFA',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: s.color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Actif total : ${valueFormatter(total)} FCFA',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Petite courbe de tendance sans axe ni légende (sparkline), utilisée dans
/// les cartes compactes pour donner une lecture rapide de l'évolution d'un
/// indicateur sur les derniers mois : aire remplie en dégradé, repère sur la
/// dernière valeur (mois courant) et ligne de référence à zéro quand la
/// série change de signe, dans le même esprit que [BarTrendChart].
class Sparkline extends StatelessWidget {
  final List<ChartPoint> points;
  final Color color;

  const Sparkline({super.key, required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    return CustomPaint(
      size: Size.infinite,
      painter: _SparklinePainter(points: points, color: color),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<ChartPoint> points;
  final Color color;

  _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const topPadding = 4.0;
    const labelHeight = 12.0;
    final values = points.map((p) => p.value).toList();
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final plotHeight =
        (size.height - topPadding - labelHeight).clamp(0.0, size.height);
    final baselineY = topPadding + plotHeight;
    final stepX = size.width / (points.length - 1);

    Offset offsetAt(int i) {
      final y = topPadding +
          plotHeight -
          ((values[i] - minV) / range) * plotHeight;
      return Offset(stepX * i, y.clamp(0.0, baselineY));
    }

    final linePath = Path()..moveTo(offsetAt(0).dx, offsetAt(0).dy);
    for (var i = 1; i < points.length; i++) {
      final prev = offsetAt(i - 1);
      final curr = offsetAt(i);
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      linePath.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    final last = offsetAt(points.length - 1);
    linePath.lineTo(last.dx, last.dy);

    // Ligne de référence à zéro, uniquement si la série change de signe
    // (repère utile pour lire un mois négatif dans une tendance positive).
    if (minV < 0 && maxV > 0) {
      final zeroY = topPadding + plotHeight - ((0 - minV) / range) * plotHeight;
      final dashPaint = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 1;
      const dashWidth = 3.0;
      const gap = 2.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, zeroY),
          Offset(x + dashWidth, zeroY),
          dashPaint,
        );
        x += dashWidth + gap;
      }
    }

    // Aire remplie en dégradé, du même ton que la courbe.
    final areaPath = Path.from(linePath)
      ..lineTo(last.dx, baselineY)
      ..lineTo(offsetAt(0).dx, baselineY)
      ..close();
    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, baselineY));
    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Repère (mois + point) sur le pic et le creux de la série : identifie
    // en un coup d'œil à quel moment la fluctuation a eu lieu.
    final maxIndex = values.indexOf(maxV);
    final minIndex = values.indexOf(minV);
    final lastIndex = points.length - 1;
    final labelStyle = TextStyle(fontSize: 7, color: Colors.grey.shade600);

    void drawMarker(int index, {required bool isLast}) {
      final pos = offsetAt(index);
      if (!isLast) {
        canvas.drawCircle(pos, 2.6, Paint()..color = Colors.white);
        canvas.drawCircle(pos, 1.9, Paint()..color = color);
      }
      final tp = TextPainter(
        text: TextSpan(text: points[index].label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (pos.dx - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, baselineY + 1));
    }

    final labelled = <int>{};
    if (maxIndex != lastIndex) {
      drawMarker(maxIndex, isLast: false);
      labelled.add(maxIndex);
    }
    if (minIndex != lastIndex && !labelled.contains(minIndex)) {
      drawMarker(minIndex, isLast: false);
    }

    // Repère sur la dernière valeur (mois courant de la série), toujours
    // affiché en dernier pour rester au premier plan.
    drawMarker(lastIndex, isLast: true);
    canvas.drawCircle(last, 3.2, Paint()..color = Colors.white);
    canvas.drawCircle(last, 2.4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
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
