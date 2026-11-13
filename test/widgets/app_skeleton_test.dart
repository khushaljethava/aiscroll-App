import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/shared/widgets/app_skeleton.dart';

void main() {
  testWidgets('AppSkeleton renders with given height/width', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: AppSkeleton(height: 20, width: 100))),
    ));
    expect(find.byType(AppSkeleton), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300)); // advance animation
    expect(tester.takeException(), isNull);
  });
}
