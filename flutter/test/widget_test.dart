import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:searchteach_mobile/core/widgets/auth_shell.dart';
import 'package:searchteach_mobile/features/auth/login_page.dart';
import 'package:searchteach_mobile/features/dashboard/dashboard_page.dart';
import 'package:searchteach_mobile/features/dashboard/director_dashboard_provider.dart';

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

  testWidgets('director dashboard shows real-data summary and empty states',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          directorDashboardProvider.overrideWith(
            (ref) async => const DirectorDashboard(
              totalTutorias: 12,
              tutoriasRealizadas: 8,
              tutoriasProgramadas: 3,
              tasaAsistencia: 75,
              historialSemanal: [],
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);
    expect(find.text('Tutorías por semana'), findsOneWidget);

    await tester.tap(find.text('Calidad'));
    await tester.pumpAndSettle();
    expect(find.text('Calidad de las tutorías'), findsOneWidget);
    expect(find.textContaining('al menos 5 respuestas'), findsOneWidget);

    await tester.tap(find.text('Pronóstico'));
    await tester.pumpAndSettle();
    expect(find.text('Pronóstico'), findsWidgets);
    expect(find.textContaining('modelo predictivo validado'), findsOneWidget);
  });
}
