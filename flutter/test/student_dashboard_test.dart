import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:searchteach_mobile/features/estudiante/student_dashboard_models.dart';
import 'package:searchteach_mobile/features/estudiante/student_dashboard_page.dart';

void main() {
  const data = StudentDashboardData(
    profile: StudentProfile(
      id: '12345678',
      name: 'Camila Torres',
      email: 'camila@example.edu',
      phone: '3001234567',
      role: 'Estudiante y Docente',
    ),
    tutors: [
      AvailableTutor(
        teacherId: '900100',
        name: 'Laura Martínez',
        career: 'Ingeniería',
        semester: 4,
        day: 'Jueves',
        startTime: '14:00',
        endTime: '15:00',
        modality: 'Virtual',
        location: '',
      ),
    ],
    tutorings: [],
  );

  testWidgets('student dashboard keeps four mobile destinations',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentDashboardProvider.overrideWith((ref) async => data),
        ],
        child: const MaterialApp(home: StudentDashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Tutorías'), findsOneWidget);
    expect(find.text('Perfil'), findsWidgets);
    expect(find.text('Avisos'), findsOneWidget);
    expect(find.textContaining('Estos datos los gestiona'), findsNothing);
  });

  testWidgets('tutor catalog supports name search and Inscribirse',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentDashboardProvider.overrideWith((ref) async => data),
        ],
        child: const MaterialApp(home: StudentDashboardPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutorías'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sesiones disponibles'));
    await tester.pumpAndSettle();

    expect(
        find.text('Buscar tutor por nombre o identificación'), findsOneWidget);
    expect(find.text('Ingeniería'), findsOneWidget);
    expect(find.text('Inscribirse'), findsOneWidget);
    expect(find.text('ID 900100'), findsOneWidget);
  });

  testWidgets('dual-role profile keeps access to teacher view', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentDashboardProvider.overrideWith((ref) async => data),
        ],
        child: const MaterialApp(home: StudentDashboardPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();

    expect(find.text('Estudiante y docente'), findsNWidgets(2));
    expect(find.text('Cambiar a vista docente'), findsOneWidget);
  });

  testWidgets('desktop dashboard uses a persistent side navigation',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentDashboardProvider.overrideWith((ref) async => data),
        ],
        child: const MaterialApp(home: StudentDashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('Panel de estudiante'), findsOneWidget);
  });

  test('enrollment creates a one-hour request for the signed-in student',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    Map<String, dynamic>? sentBody;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        sentBody = Map<String, dynamic>.from(options.data as Map);
        handler.resolve(Response<void>(
          requestOptions: options,
          statusCode: 201,
        ));
      },
    ));

    await enrollInTutoring(
      dio: dio,
      student: data.profile,
      tutor: data.tutors.single,
      subject: 'Cálculo',
      start: DateTime(2026, 10, 15),
    );

    expect(sentBody?['estudianteId'], '12345678');
    expect(sentBody?['docenteId'], '900100');
    expect(sentBody?['modalidad'], 'VIRTUAL');
    expect(
        DateTime.parse(sentBody!['fechaFin'] as String)
            .difference(DateTime.parse(sentBody!['fechaInicio'] as String))
            .inHours,
        1);
  });
}
