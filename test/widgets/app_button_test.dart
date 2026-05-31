import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/shared/widgets/app_button.dart';

void main() {
  testWidgets('AppButton shows label and fires onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AppButton(label: 'Go', onPressed: () => tapped = true)),
    ));
    expect(find.text('Go'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    expect(tapped, isTrue);
  });

  testWidgets('AppButton renders an icon when provided', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppButton(label: 'Go', icon: Icons.star, onPressed: () {}),
      ),
    ));
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('AppButton disables + shows spinner when loading', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppButton(label: 'Go', loading: true, onPressed: () => tapped = true),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    expect(tapped, isFalse);
  });
}
