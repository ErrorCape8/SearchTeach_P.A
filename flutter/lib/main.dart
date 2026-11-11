import 'dart:async';

import 'package:flutter/material.dart';
import 'package:searchteach_mobile/core/api_client.dart';
import 'core/session_persistence.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/admin/admin_main_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/session_restore_page.dart';
import 'features/auth/register_page.dart';
import 'features/auth/forgot_password_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/tutorias/coordinacion_tutorias_page.dart';
import 'features/tutorias/coordinacion_programar_tutorias_page.dart';
import 'features/tutorias/coordinacion_dashboard_page.dart';
import 'features/tutorias/docente_dashboard_page.dart';
import 'features/estudiante/student_dashboard_page.dart';
import 'features/notifications/notifications_page.dart';
import 'core/widgets/app_error_page.dart';
import 'core/app_error.dart';

final _router = GoRouter(
  initialLocation: '/session',
  errorBuilder: (context, state) => AppErrorPage(
    error: state.error,
    info: const AppErrorInfo(AppErrorKind.notFound),
  ),
  routes: [
    GoRoute(path: '/session', builder: (_, __) => const SessionRestorePage()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
    GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordPage()),
    GoRoute(
      path: '/notificaciones',
      builder: (_, state) => NotificationsPage(
        accentColor: state.extra is Color ? state.extra as Color : null,
      ),
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const DashboardPage(),
    ),
    GoRoute(
      path: '/coordinacion',
      builder: (_, __) => const CoordinacionDashboardPage(),
    ),
    GoRoute(
      path: '/coordinacion/tutorias-colectivas',
      builder: (_, __) => const CoordinacionTutoriasPage(),
    ),
    GoRoute(
      path: '/coordinacion/programar-tutorias',
      builder: (_, __) => const CoordinacionProgramarTutoriasPage(),
    ),
    GoRoute(
      path: '/docente',
      builder: (_, __) => const DocenteDashboardPage(),
    ),
    GoRoute(
      path: '/estudiante',
      builder: (_, __) => const StudentDashboardPage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (_, __) => const AdminMainPage(),
    ),
    GoRoute(
      path: '/error',
      builder: (_, state) => AppErrorPage(
        info: state.extra is AppErrorInfo
            ? state.extra! as AppErrorInfo
            : const AppErrorInfo(AppErrorKind.server),
      ),
    ),
  ],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSessionPersistence();
  ErrorWidget.builder = (details) => AppErrorPage(error: details.exception);
  runApp(const ProviderScope(child: App()));
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  StreamSubscription<void>? _authExpiredSubscription;
  StreamSubscription<AppErrorInfo>? _appErrorSubscription;

  @override
  void initState() {
    super.initState();
    _authExpiredSubscription = authExpiredEvents.listen((_) {
      _router.go('/login');
    });
    _appErrorSubscription = appErrorEvents.listen((info) {
      if (_router.state.uri.path != '/error') {
        _router.go('/error', extra: info);
      }
    });
  }

  @override
  void dispose() {
    _authExpiredSubscription?.cancel();
    _appErrorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'SearchTeach',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFA9154F),
            primary: const Color(0xFFA9154F),
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F7FB),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 2,
            shadowColor: const Color(0xFF14203C).withValues(alpha: .07),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFEEF1F6),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF1E3FA8), width: 2),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          chipTheme: ChipThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            side: const BorderSide(color: Color(0xFFDCE2EB)),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          ),
          dividerTheme: const DividerThemeData(
            color: Color(0xFFE8EBF1),
            thickness: 1,
            space: 1,
          ),
          useMaterial3: true,
        ),
        routerConfig: _router,
      );
}
