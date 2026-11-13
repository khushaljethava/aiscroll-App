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

  testWidgets('AppStatusDot is a sized circle', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: AppStatusDot(color: Colors.green, size: 8))),
    ));
    expect(tester.getSize(find.byType(AppStatusDot)), const Size(8, 8));
  });

  testWidgets('AppBadge renders an icon when provided', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppBadge(label: 'X', color: Colors.amber, icon: Icons.star)),
    ));
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('AppBadge.micro shows label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppBadge.micro(label: 'EARNED', color: Colors.green)),
    ));
    expect(find.text('EARNED'), findsOneWidget);
  });
}
