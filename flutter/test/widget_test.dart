import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:searchteach_mobile/core/widgets/auth_shell.dart';
import 'package:searchteach_mobile/features/auth/login_page.dart';
import 'package:searchteach_mobile/features/dashboard/dashboard_page.dart';
import 'package:searchteach_mobile/features/dashboard/director_dashboard_provider.dart';
import 'package:searchteach_mobile/features/tutorias/coordinacion_tutorias_page.dart';

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

  testWidgets('coordinator form has five projects and four student fields each',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CoordinacionTutoriasPage()),
      ),
    );

    expect(find.text('Identificación del docente líder'), findsOneWidget);
    expect(find.text('Docente de apoyo 1'), findsOneWidget);
    expect(find.text('Proyecto 1'), findsOneWidget);
    expect(find.text('Identificación del estudiante 4'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Docente de apoyo 5'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Docente de apoyo 5'), findsOneWidget);
    expect(find.text('Proyecto 5'), findsOneWidget);
    expect(find.text('Identificación del estudiante 1'), findsOneWidget);
  });

  testWidgets('director dashboard shows real-data summary and empty states',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          directorDashboardProvider.overrideWith(
            (ref) async => DirectorDashboard(
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
                  estudiantesInscritos: 4,
                  asistenciasConfirmadas: 3,
                  asistenciasRegistradas: 4,
                  tasaAsistencia: 75,
                  pronostico: PronosticoDemanda(
                    historialSolicitudes: List.generate(
                      6,
                      (index) => WeeklyTutoringCount(
                        semanaInicio:
                            DateTime(2026, 1, 5).add(Duration(days: index * 7)),
                        total: index + 1,
                      ),
                    ),
                    estimadoProximaSemana: 7,
                    minimoProximaSemana: 5,
                    maximoProximaSemana: 9,
                    estimadoProximasCuatroSemanas: 34,
                    minimoProximasCuatroSemanas: 27,
                    maximoProximasCuatroSemanas: 41,
                    tendencia: 'SUBE',
                    alertaCreciente: true,
                  ),
                ),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hola, líder del programa'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Calidad'), findsOneWidget);
    expect(find.text('Pronóstico'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
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
    expect(find.text('Demanda creciente'), findsOneWidget);
    expect(find.text('~7 solicitudes para la próxima semana'), findsOneWidget);
    expect(find.text('Intervalo predictivo 95%: 5–9'), findsOneWidget);
    await tester.tap(find.text('Próximas 4 semanas'));
    await tester.pumpAndSettle();
    expect(find.text('~34 solicitudes para las próximas 4 semanas'),
        findsOneWidget);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Cuenta del líder del programa'), findsOneWidget);
  });

}
