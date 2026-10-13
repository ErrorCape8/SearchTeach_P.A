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
              tutoriasPorMateria: [
                SubjectTutoringSummary(
                  materia: 'Cálculo I',
                  totalTutorias: 5,
                  tutoriasRealizadas: 4,
                  tasaAsistencia: 75,
                ),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);
    expect(find.text('Satisfacción'), findsOneWidget);
    expect(find.text('Sin datos'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -440));
    await tester.pumpAndSettle();
    expect(find.text('Tutorías por semana'), findsOneWidget);
    expect(find.text('Asistencia por materia'), findsOneWidget);
    expect(find.text('Cálculo I'), findsOneWidget);

    await tester.tap(find.text('Calidad'));
    await tester.pumpAndSettle();
    expect(find.text('Calidad de las tutorías'), findsOneWidget);
    expect(find.text('Calificaciones anónimas'), findsOneWidget);
    expect(find.text('Aún no hay evaluaciones registradas.'), findsOneWidget);

    await tester.tap(find.text('Pronóstico'));
    await tester.pumpAndSettle();
    expect(find.text('Pronóstico de tutorías'), findsOneWidget);
    expect(find.text('Estimación orientativa'), findsNothing);
    expect(
        find.textContaining('Aún no hay actividad suficiente'), findsOneWidget);
    await tester.tap(find.text('Próximas 4 semanas'));
    await tester.pumpAndSettle();
    expect(find.text('Próximas 4 semanas'), findsOneWidget);
  });

  test('weekly reference uses the last four completed weeks', () {
    final now = DateTime.now();
    final currentMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    final history = List.generate(4, (index) {
      final weekStart = currentMonday.subtract(Duration(days: 7 * (4 - index)));
      return WeeklyTutoringCount(
        semanaInicio: weekStart,
        total: index + 1,
      );
    });

    final reference = WeeklyTutoringReference.fromHistory(
      history,
      today: now,
    );

    expect(reference?.average, 2.5);
    expect(reference?.minimum, 1);
    expect(reference?.maximum, 4);
  });
}
