import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/shared/widgets/app_badge.dart';

void main() {
  testWidgets('AppBadge shows label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppBadge(label: 'Level 3', color: Colors.amber)),
    ));
    expect(find.text('Level 3'), findsOneWidget);
  });

  testWidgets('AppStatusDot paints', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppStatusDot(color: Colors.green)),
    ));
    expect(find.byType(AppStatusDot), findsOneWidget);
  });
}
