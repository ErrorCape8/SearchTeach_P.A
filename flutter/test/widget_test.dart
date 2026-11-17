import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:searchteach_mobile/core/widgets/academic_role_switcher.dart';

void main() {
  testWidgets('dual-role switcher lists teacher before student and switches',
      (WidgetTester tester) async {
    String? selectedRole;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AcademicRoleSwitcher(
            role: 'Docente / Estudiante',
            activeRole: 'estudiante',
            onProfile: () => selectedRole = 'perfil',
            onSwitchToTeacher: () => selectedRole = 'docente',
            onSwitchToStudent: () => selectedRole = 'estudiante',
            child: const Text('Cuenta'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Docente')).dy,
        lessThan(tester.getTopLeft(find.text('Estudiante')).dy));
    await tester.tap(find.text('Docente'));
    await tester.pumpAndSettle();
    expect(selectedRole, 'docente');
  });

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
