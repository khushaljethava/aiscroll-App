import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/shared/widgets/app_option_card.dart';

void main() {
  testWidgets('AppOptionCard shows title + subtitle and fires onTap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppOptionCard(
          title: 'Student',
          subtitle: 'Building AI skills while I study',
          selected: false,
          onTap: () => tapped = true,
        ),
      ),
    ));
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Building AI skills while I study'), findsOneWidget);
    await tester.tap(find.byType(AppOptionCard));
    expect(tapped, isTrue);
  });

  testWidgets('AppOptionCard shows a check when selected', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppOptionCard(
          title: 'Student',
          selected: true,
          onTap: () {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
