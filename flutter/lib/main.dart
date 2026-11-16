import 'dart:async';

import 'package:flutter/material.dart';
import 'package:searchteach_mobile/core/api_client.dart';
import 'core/session_persistence.dart';
import 'core/neu/neu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/admin/admin_main_page.dart';
import 'features/auth/auth_repository.dart';
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

final _container = ProviderContainer();

const _publicPaths = {
  '/session',
  '/login',
  '/register',
  '/forgot-password',
  '/error'
};
String? _guardToken;
String? _guardHome;

/// Protege las rutas: sin sesión se envía a /login y, con sesión, solo se
/// permite el área que corresponde al rol de la cuenta (estudiante, docente,
/// coordinación, administrador o dirección).
Future<String?> _routeGuard(BuildContext context, GoRouterState state) async {
  final path = state.uri.path;
  if (_publicPaths.contains(path)) return null;

  final token = await _container.read(secureStorageProvider).read(key: 'token');
  if (token == null) {
    _guardToken = null;
    _guardHome = null;
    return '/login';
  }
  if (path == '/notificaciones') return null;

  try {
    if (_guardToken != token || _guardHome == null) {
      _guardHome = await _container.read(authRepositoryProvider).landingRoute();
      _guardToken = token;
    }
  } catch (_) {
    // No se pudo verificar el rol: la pantalla de sesión permite reintentar.
    return '/session';
  }

  final home = _guardHome!;
  final segments = state.uri.pathSegments;
  final area = segments.isEmpty ? '/' : '/${segments.first}';
  return area == home ? null : home;
}

final _router = GoRouter(
  initialLocation: '/session',
  redirect: _routeGuard,
  errorBuilder: (context, state) {
    final error = state.error;
    final errorStr = error?.toString().toLowerCase() ?? '';
    final isRouteNotFound = errorStr.contains('no routes') ||
        errorStr.contains('not found') ||
        errorStr.contains('no route for location') ||
        (error is GoException && errorStr.contains('location'));

    return AppErrorPage(
      error: error,
      info: AppErrorInfo(
        isRouteNotFound ? AppErrorKind.notFound : AppErrorKind.server,
      ),
    );
  },
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
  ErrorWidget.builder = (details) => AppErrorPage(
        error: details.exception,
        info: const AppErrorInfo(AppErrorKind.server),
      );
  runApp(UncontrolledProviderScope(container: _container, child: const App()));
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
      // API 404s indicate missing resources, not missing page routes;
      // individual screens handle resource errors inline with retry buttons.
      if (info.kind == AppErrorKind.notFound) return;

      // Do not replace screens that handle errors inline with the full error page.
      final currentPath = _router.state.uri.path;
      if (currentPath == '/docente' || currentPath == '/estudiante') return;

      if (currentPath != '/error') {
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
          canvasColor: Neu.bg,
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
          dialogTheme: DialogThemeData(
            backgroundColor: Neu.bg,
            surfaceTintColor: Colors.transparent,
            shadowColor: Neu.shadowDark,
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Neu.bg,
            surfaceTintColor: Colors.transparent,
            shadowColor: Neu.shadowDark,
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            headerBackgroundColor: Neu.bg,
            headerForegroundColor: Neu.heading,
            weekdayStyle:
                neuBody(size: 12, weight: FontWeight.w700, color: Neu.muted),
            dayStyle: neuBody(size: 13, weight: FontWeight.w500),
            dayForegroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? Neu.chevron
                    : states.contains(WidgetState.selected)
                        ? Colors.white
                        : Neu.text),
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: Neu.bg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            hourMinuteShape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          popupMenuTheme: PopupMenuThemeData(
            color: Neu.bg,
            surfaceTintColor: Colors.transparent,
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: neuBody(size: 14, color: Neu.text),
          ),
          listTileTheme: ListTileThemeData(
            iconColor: Neu.muted,
            textColor: Neu.text,
            selectedTileColor: Neu.quietBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
