import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sycebnl_accounting/widgets/download_button.dart';

/// Place le curseur de la souris sur [finder] puis laisse le temps à
/// l'info-bulle d'apparaître (délai d'attente + fondu).
Future<TestGesture> _hover(WidgetTester tester, Finder finder) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pumpAndSettle();
  return gesture;
}

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('DownloadIcon', () {
    testWidgets('affiche l\'icône du format suivie d\'une flèche vers le bas',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const DownloadIcon(Icons.picture_as_pdf, size: 16)),
      );

      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('la flèche reste plus petite que l\'icône du format',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const DownloadIcon(Icons.table_chart, size: 16)),
      );

      final format = tester.widget<Icon>(find.byIcon(Icons.table_chart));
      final arrow =
          tester.widget<Icon>(find.byIcon(Icons.arrow_downward_rounded));
      expect(arrow.size, lessThan(format.size!));
    });

    testWidgets('hérite de la taille du thème d\'icône quand aucune n\'est '
        'fournie', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const IconTheme(
            data: IconThemeData(size: 24),
            child: DownloadIcon(Icons.picture_as_pdf_outlined),
          ),
        ),
      );

      final format =
          tester.widget<Icon>(find.byIcon(Icons.picture_as_pdf_outlined));
      expect(format.size, 24);
    });

    testWidgets('ne déborde pas dans un IconButton', (tester) async {
      await tester.pumpWidget(
        _wrap(
          IconButton(
            onPressed: () {},
            icon: const DownloadIcon(Icons.picture_as_pdf_outlined, size: 20),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('DownloadTooltip', () {
    testWidgets('n\'affiche rien tant que la souris ne survole pas le bouton',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DownloadTooltip.pdf(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const DownloadIcon(Icons.picture_as_pdf, size: 16),
              label: const Text('PDF'),
            ),
          ),
        ),
      );

      expect(find.text(kDownloadPdfLabel), findsNothing);
    });

    testWidgets('affiche « Télécharger PDF » sous le bouton au survol, '
        'puis le masque à la sortie', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DownloadTooltip.pdf(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const DownloadIcon(Icons.picture_as_pdf, size: 16),
              label: const Text('PDF'),
            ),
          ),
        ),
      );

      final button = find.bySubtype<ElevatedButton>();
      final gesture = await _hover(tester, button);

      expect(find.text(kDownloadPdfLabel), findsOneWidget);
      // Le libellé est bien rendu sous le bouton.
      expect(
        tester.getTopLeft(find.text(kDownloadPdfLabel)).dy,
        greaterThan(tester.getBottomLeft(button).dy),
      );

      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(find.text(kDownloadPdfLabel), findsNothing);
    });

    testWidgets('affiche « Télécharger Excel » au survol', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DownloadTooltip.excel(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const DownloadIcon(Icons.table_chart, size: 16),
              label: const Text('Excel'),
            ),
          ),
        ),
      );

      await _hover(tester, find.bySubtype<ElevatedButton>());
      expect(find.text(kDownloadExcelLabel), findsOneWidget);
    });

    testWidgets('apparaît en fondu', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DownloadTooltip.pdf(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const DownloadIcon(Icons.picture_as_pdf, size: 16),
              label: const Text('PDF'),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.bySubtype<ElevatedButton>()));

      // Délai d'attente écoulé, fondu entamé mais pas terminé.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 50));

      final opacity = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text(kDownloadPdfLabel),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(opacity.opacity.value, greaterThan(0.0));
      expect(opacity.opacity.value, lessThan(1.0));

      await tester.pumpAndSettle();
    });

    testWidgets('le clic de téléchargement passe toujours au bouton',
        (tester) async {
      var appuis = 0;
      await tester.pumpWidget(
        _wrap(
          DownloadTooltip.excel(
            child: ElevatedButton.icon(
              onPressed: () => appuis++,
              icon: const DownloadIcon(Icons.table_chart, size: 16),
              label: const Text('Excel'),
            ),
          ),
        ),
      );

      await tester.tap(find.bySubtype<ElevatedButton>());
      await tester.pumpAndSettle();
      expect(appuis, 1);
    });
  });
}
