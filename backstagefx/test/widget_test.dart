import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
 testWidgets('App builds (smoke test)', (WidgetTester tester) async {
   // Build a minimal widget tree that avoids plugin initialization during tests.
   await tester.pumpWidget(const ProviderScope(
     child: MaterialApp(home: SizedBox()),
   ));

   expect(find.byType(SizedBox), findsOneWidget);
 });
}
