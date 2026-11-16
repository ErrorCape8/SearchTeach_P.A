import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SearchTeach smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('SearchTeach'),
        ),
      ),
    );

    expect(find.text('SearchTeach'), findsOneWidget);
  });
}
