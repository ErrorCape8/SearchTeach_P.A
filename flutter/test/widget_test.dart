import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:searchteach_mobile/core/widgets/auth_shell.dart';
import 'package:searchteach_mobile/features/auth/login_page.dart';

void main() {
  testWidgets('login page renders auth form', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginPage()),
      ),
    );

    expect(find.text('Inicio de sesión'), findsOneWidget);
    expect(find.text('Inicia para continuar'), findsOneWidget);
    expect(find.text('DOCUMENTO'), findsOneWidget);
    expect(find.text('CONTRASEÑA'), findsOneWidget);
    expect(find.byType(DarkButton), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
