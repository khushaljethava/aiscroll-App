import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscroll/shared/widgets/brand_wordmark.dart';
import 'package:aiscroll/core/constants/brand.dart';

void main() {
  testWidgets('wordmark renders the brand name', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BrandWordmark()),
    ));
    expect(find.text(Brand.name), findsOneWidget);
  });
}
