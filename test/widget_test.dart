import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leagueit/main.dart';

void main() {
  testWidgets('renders LeagueIt home title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('LeagueIt'), findsWidgets);
  });
}
