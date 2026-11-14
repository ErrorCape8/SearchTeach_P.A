import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/tutoring_updates.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/neu/neu.dart';
import '../auth/auth_repository.dart';
import 'coordinacion_horarios_page.dart';
import 'coordinacion_solicitudes_page.dart';
import '../pa/pa_coordinacion_pages.dart';
import '../pa/pa_store.dart';
import '../pa/pa_widgets.dart';

const _wine = Color(0xFFA9154F);

class CoordinacionDashboardPage extends ConsumerStatefulWidget {
  const CoordinacionDashboardPage({super.key});

  @override
  ConsumerState<CoordinacionDashboardPage> createState() =>
      _CoordinacionDashboardPageState();
}

class _CoordinacionDashboardPageState
    extends ConsumerState<CoordinacionDashboardPage>
    with WidgetsBindingObserver {
  int _tab = 0;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _publishedSessions = [];
  List<Map<String, dynamic>> _groups = [];
  Map<String, dynamic> _profile = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final responses = await Future.wait<Response<dynamic>>([
        dio.get<List<dynamic>>('/api/coordinacion/docentes'),
        dio.get<List<dynamic>>('/api/coordinacion/horarios'),
        dio.get<List<dynamic>>('/api/coordinacion/tutorias-colectivas'),
        dio.get<List<dynamic>>('/api/coordinacion/sesiones-grupales'),
        dio.get<Map<String, dynamic>>('/api/usuarios/perfil'),
      ]);
      List<Map<String, dynamic>> rows(int index) =>
          (responses[index].data ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _teachers = rows(0);
        _schedules = rows(1);
        _groups = rows(2);
        _publishedSessions = rows(3);
        final profile = responses[4].data;
        _profile =
            profile is Map<String, dynamic> ? profile : <String, dynamic>{};
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      setState(() {
        _error = data is Map && data['message'] is String
            ? data['message'] as String
            : 'No se pudieron cargar los datos. Revisa tu conexión e inténtalo de nuevo.';
        _loading = false;
      });
    }
  }

  String _title() => const [
        'Inicio',
        'Horarios de tutores',
        'Tutores líderes',
        'Solicitudes docentes',
        'Perfil',
        'Reportes de tutorías',
      ][_tab];

  // Perfil no es una pestaña del menú: se abre desde el avatar / bloque de usuario.
  static const _navTabs = [0, 1, 2, 5];

  String get _name {
    final n = (_profile['nombre'] as String?)?.trim();
    return n != null && n.isNotEmpty ? n : 'Coordinación';
  }

  void _select(int index) {
    setState(() => _tab = index);
    if (index == 0) _load();
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).logout();
    if (mounted) context.go('/login');
  }

  /// Avatar con las iniciales: abre el perfil (función del bloque de usuario).
  Widget _profileButton() => Semantics(
        button: true,
        label: 'Abrir perfil',
        child: GestureDetector(
          onTap: () => _select(4),
          child: SizedBox(
            width: 46,
            height: 46,
            child: NeuSurface(
              radius: 46,
              shadows: Neu.raiseS,
              child: Center(
                child: Text(_initials(_name),
                    style: neuPoppins(
                        size: 15, weight: FontWeight.w700, color: _wine)),
              ),
            ),
          ),
        ),
      );

  Widget _header(bool wide) {
    final home = _tab == 0;
    final program =
        (_profile['programa'] ?? _profile['carrera'] ?? '').toString().trim();
    return NeuHeader(
      title: home ? 'Hola, ${_name.split(RegExp(r'\s+')).first}' : _title(),
      subtitle: home
          ? (program.isEmpty ? 'Coordinador' : 'Coordinador · $program')
          : (_tab == 4 ? 'Coordinador' : null),
      leading: _profileButton(),
      actions: [
        if (wide)
          NeuButton('Actualizar',
              onPressed: _load,
              kind: NeuButtonKind.alt,
              small: true,
              icon: Icons.refresh_rounded,
              expand: false)
        else
          NeuCircleButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Actualizar',
              onTap: _load),
        NeuCircleButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notificaciones',
          onTap: () => context.push('/notificaciones', extra: _wine),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tutoringUpdatesProvider, (_, next) {
      if (next.hasValue && mounted) _load();
    });
    final wide = MediaQuery.sizeOf(context).width >= 760;
    // Horarios, Líderes y Reportes traen su propia cabecera neumórfica.
    final ownHeader = _tab == 1 || _tab == 2 || _tab == 5;
    final needsData = _tab == 0 || _tab == 4;
    final content = Column(
      children: [
        if (!ownHeader) _header(wide),
        Expanded(
          child: needsData && _loading
              ? const Center(child: CircularProgressIndicator(color: _wine))
              : needsData && _error != null
                  ? _LoadFailure(message: _error!, onRetry: _load)
                  : _content(),
        ),
      ],
    );
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _wine,
          brightness: Theme.of(context).brightness,
        ).copyWith(primary: _wine),
      ),
      child: Scaffold(
        backgroundColor: Neu.bg,
        body: wide
            ? Row(
                children: [
                  _Sidebar(
                    index: _tab,
                    name: _name,
                    onSelect: _select,
                    onLogout: _logout,
                  ),
                  Expanded(child: content),
                ],
              )
            : content,
        bottomNavigationBar: wide
            ? null
            : NeuBottomBar(
                items: const [
                  NeuNavItem(Icons.home_outlined, 'Inicio'),
                  NeuNavItem(Icons.calendar_month_outlined, 'Horarios'),
                  NeuNavItem(Icons.groups_outlined, 'Líderes'),
                  NeuNavItem(Icons.inbox_outlined, 'Reportes'),
                ],
                index: _navTabs.indexOf(_tab),
                onSelect: (i) => _select(_navTabs[i]),
              ),
      ),
    );
  }

  Widget _content() => switch (_tab) {
        0 => _HomeView(teachers: _teachers, onOpen: _select),
        1 => const CoordinacionHorariosPage(),
        2 => PaLideresPage(leading: _profileButton()),
        3 => const CoordinacionSolicitudesPage(),
        4 => _ProfileView(profile: _profile, onRefresh: _load),
        _ => PaReportesPage(leading: _profileButton()),
      };
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'CO';
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}

/// Barra lateral (tablet / escritorio). Sin «Perfil»: se abre desde el bloque
/// de usuario del pie, que además trae el botón de cerrar sesión.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.index,
    required this.name,
    required this.onSelect,
    required this.onLogout,
  });
  final int index;
  final String name;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  static const _items = [
    (Icons.home_outlined, 'Inicio', 0),
    (Icons.calendar_month_outlined, 'Horarios', 1),
    (Icons.groups_outlined, 'Líderes', 2),
    (Icons.inbox_outlined, 'Reportes', 5),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Neu.bg,
        boxShadow: [
          BoxShadow(
              color: Neu.shadowDark, offset: Offset(4, 0), blurRadius: 12),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Column(children: [
            const SizedBox(
              height: 64,
              width: 170,
              child: BrandLogo(width: 170, height: 64, accentColor: _wine),
            ),
            const SizedBox(height: 22),
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: NeuSurface(
                  radius: 16,
                  shadows: const [],
                  sunken: index == item.$3,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  onTap: () => onSelect(item.$3),
                  child: Row(children: [
                    Icon(item.$1,
                        size: 22,
                        color: index == item.$3 ? _wine : Neu.navIdle),
                    const SizedBox(width: 12),
                    Text(item.$2,
                        style: neuBody(
                            size: 15,
                            weight: FontWeight.w700,
                            color: index == item.$3 ? _wine : Neu.muted)),
                  ]),
                ),
              ),
            const Spacer(),
            NeuSurface(
              radius: 16,
              shadows: const [],
              sunken: index == 4,
              padding: const EdgeInsets.all(10),
              onTap: () => onSelect(4),
              child: Row(children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: NeuSurface(
                    radius: 40,
                    shadows: Neu.raiseS,
                    child: Center(
                      child: Text(_initials(name),
                          style: neuBody(
                              size: 13,
                              weight: FontWeight.w700,
                              color: Neu.muted)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: neuBody(size: 14, weight: FontWeight.w700)),
                        Text('Coordinador',
                            style: neuBody(size: 12, color: Neu.muted)),
                      ]),
                ),
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded, color: Neu.muted),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HomeView extends ConsumerWidget {
  const _HomeView({required this.teachers, required this.onOpen});
  final List<Map<String, dynamic>> teachers;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(paStoreProvider);
    final sinLider = st.colectivas.where((c) => c.lider.isEmpty).toList();
    final conLider = st.colectivas.length - sinLider.length;
    final reportes = st.reportesDeLider; // solo los del docente líder
    final nuevos = reportes.where((r) => !r.visto).length;
    return ListView(
      padding: EdgeInsets.fromLTRB(
          18, 4, 18, 32 + MediaQuery.paddingOf(context).bottom),
      children: [
        PaKpiRow([
          ('${teachers.length}', 'Tutores activos'),
          ('$conLider/${st.colectivas.length}', 'Con líder'),
          ('$nuevos', 'Reportes nuevos'),
        ]),
        PaSection('Por asignar', action: 'Ver todo', onAction: () => onOpen(2)),
        PaRowList([
          for (final c in sinLider)
            PaRow(
              icon: Icons.groups_2_outlined,
              title: c.materia,
              subtitle:
                  '${c.carrera} · Sem ${c.semestreRomano} · Sec ${c.seccion}',
              trailing: const PaTag('Sin líder', tone: PaTone.warn),
              onTap: () => paPush(context, PaAsignacionPage(colId: c.id)),
            ),
        ], empty: 'Todas las tutorías tienen líder.'),
        PaSection('Reportes recientes',
            action: 'Ver todo', onAction: () => onOpen(5)),
        PaRowList([
          for (final r in reportes.take(3))
            PaRow(
              icon: Icons.inbox_outlined,
              title: st.colectiva(r.colId).materia,
              subtitle: 'Líder ${r.por} · ${r.fecha}',
              trailing: PaTag(r.visto ? 'Revisado' : 'Nuevo',
                  tone: r.visto ? PaTone.ok : PaTone.warn),
              onTap: () =>
                  paPush(context, PaReporteDetallePage(reporte: r)),
            ),
        ], empty: 'Aún no hay reportes de líderes.'),
      ],
    );
  }
}

class _ProfileView extends ConsumerWidget {
  const _ProfileView({required this.profile, required this.onRefresh});
  final Map<String, dynamic> profile;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    PaRow locked(String title, String value) =>
        PaRow(icon: Icons.lock_outline_rounded, title: title, subtitle: value);
    final programa =
        _text(profile['programa'] ?? profile['carrera'], 'No registrado');
    return ListView(
      padding: EdgeInsets.fromLTRB(
          18, 4, 18, 32 + MediaQuery.paddingOf(context).bottom),
      children: [
        const PaSection('Datos que puedes editar'),
        PaRowList([
          PaRow(
            icon: Icons.phone_outlined,
            title: _text(profile['telefono'], 'No registrado'),
            subtitle: 'Teléfono',
            onTap: () => _editPhone(context, ref),
          ),
        ]),
        const PaSection('Seguridad'),
        PaRowList([
          PaRow(
            icon: Icons.lock_outline_rounded,
            title: 'Cambiar contraseña',
            subtitle: 'Mínimo 8 caracteres.',
            onTap: () => _editPassword(context, ref),
          ),
        ]),
        const PaSection('Datos institucionales'),
        PaRowList([
          locked('Correo', _text(profile['correo'], 'No registrado')),
          locked('Documento', _text(profile['id'], 'No registrado')),
          locked('Programa', programa),
          locked('Rol', _text(profile['rol'], 'Coordinador')),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
          child: Text('Estos datos los gestiona TI.',
              style: neuBody(size: 12.5, color: Neu.muted)),
        ),
        NeuButton(
          'Cerrar sesión',
          kind: NeuButtonKind.danger,
          icon: Icons.logout_rounded,
          onPressed: () async {
            await ref.read(authRepositoryProvider).logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }

  Future<void> _editPhone(BuildContext context, WidgetRef ref) async {
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    final controller =
        TextEditingController(text: profile['telefono'] as String? ?? '');
    final phone = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Actualizar teléfono'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          maxLength: 30,
          decoration: const InputDecoration(labelText: 'Teléfono'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
    controller.dispose();
    if (phone == null || phone.isEmpty) return;
    try {
      await ref.read(dioProvider).put<Map<String, dynamic>>(
        '/api/usuarios/perfil/telefono',
        data: {'telefono': phone},
      );
      onRefresh();
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'No se pudo actualizar el teléfono.';
      scaffoldMessenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _editPassword(BuildContext context, WidgetRef ref) async {
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    final current = TextEditingController();
    final next = TextEditingController();
    final passwords = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: current,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Contraseña actual')),
          const SizedBox(height: 12),
          TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  helperText: 'Mínimo 8 caracteres'),
              maxLength: 100),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (current.text, next.text)),
              child: const Text('Guardar')),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    if (passwords == null) return;
    if (passwords.$1.isEmpty || passwords.$2.length < 8) {
      scaffoldMessenger?.showSnackBar(const SnackBar(
          content: Text(
              'Ingresa la contraseña actual y una nueva de al menos 8 caracteres.')));
      return;
    }
    try {
      await ref.read(dioProvider).put<void>(
        '/api/usuarios/perfil/contrasena',
        data: {
          'contrasenaActual': passwords.$1,
          'nuevaContrasena': passwords.$2
        },
      );
      scaffoldMessenger?.showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada.')));
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'No se pudo actualizar la contraseña.';
      scaffoldMessenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _FeedbackReportsView extends ConsumerStatefulWidget {
  const _FeedbackReportsView();

  @override
  ConsumerState<_FeedbackReportsView> createState() =>
      _FeedbackReportsViewState();
}

class _FeedbackReportsViewState extends ConsumerState<_FeedbackReportsView> {
  bool _loading = false;
  String? _preview;

  Future<void> _download() async {
    final now = DateTime.now();
    setState(() => _loading = true);
    try {
      final response = await ref.read(dioProvider).get<String>(
            '/api/coordinacion/reportes-tutorias/mensual',
            queryParameters: {'anio': now.year, 'mes': now.month},
            options: Options(responseType: ResponseType.plain),
          );
      final csv = response.data;
      if (csv == null || csv.isEmpty) {
        throw const FormatException('El servidor devolvió un informe vacío.');
      }
      if (!mounted) return;
      setState(() => _preview = csv);
      final opened = await launchUrl(
        Uri.dataFromString(csv, mimeType: 'text/csv', encoding: utf8),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo abrir la descarga del informe.')));
      }
    } on DioException catch (error) {
      if (!mounted) return;
      final message = error.response?.data is String
          ? error.response!.data as String
          : 'No se pudo generar el informe mensual.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Reportes de satisfacción',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
            'Descarga el resumen de ${month.month.toString().padLeft(2, '0')}/${month.year} con promedio, categorías frecuentes y comentarios.'),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _loading ? null : _download,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_outlined),
          label: Text(_loading ? 'Generando...' : 'Descargar informe mensual'),
        ),
        if (_preview != null) ...[
          const SizedBox(height: 18),
          const Text('Vista previa',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SelectableText(_preview!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ],
      ],
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'))
          ])));
}

String _text(Object? value, String fallback) =>
    value == null || value.toString().trim().isEmpty
        ? fallback
        : value.toString();

// ignore: unused_element
String _projectName(List<Map<String, dynamic>> groups, Object? projectId) {
  for (final group in groups) {
    final projects = group['proyectos'];
    if (projects is List) {
      for (final project in projects.whereType<Map<String, dynamic>>()) {
        if (project['proyectoId'] == projectId) {
          return _text(project['nombre'], 'Proyecto');
        }
      }
    }
  }
  return 'Proyecto';
}

// ignore: unused_element
String _date(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return 'Fecha no disponible';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
