import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sycebnl_accounting/main.dart';

void main() {
  testWidgets('loads the welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SYCEBNL ACCOUNTING'), findsOneWidget);
    expect(find.text('Créer un nouveau fichier'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance), findsOneWidget);
  });
}
