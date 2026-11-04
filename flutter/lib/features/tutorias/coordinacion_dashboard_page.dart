import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/tutoring_updates.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/sliding_pill_navigation_bar.dart';
import '../auth/auth_repository.dart';
import '../notifications/notifications_page.dart';
import 'coordinacion_horarios_page.dart';
import 'coordinacion_solicitudes_page.dart';

const _wine = Color(0xFFA9154F);
const _wineDark = Color(0xFF86123F);
const _pink = Color(0xFFF8EAF0);
const _canvas = Color(0xFFF3F5FA);
const _muted = Color(0xFF758093);
const _border = Color(0xFFE8EAF0);

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

  @override
  Widget build(BuildContext context) {
    ref.listen(tutoringUpdatesProvider, (_, next) {
      if (next.hasValue && mounted) _load();
    });
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final content = Column(
      children: [
        if (_tab != 1)
          _Header(
            title: _title(),
            name: _profile['nombre'] as String?,
            onProfile: () => setState(() => _tab = 4),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _wine))
              : _error != null
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
        backgroundColor: _canvas,
        body: wide
            ? Row(
                children: [
                  _Navigation(
                    index: _tab,
                    wide: true,
                    name: _profile['nombre'] as String? ?? 'Coordinador',
                    onSelect: (index) {
                      setState(() => _tab = index);
                      if (index == 0) _load();
                    },
                  ),
                  Expanded(child: content),
                ],
              )
            : content,
        bottomNavigationBar: wide
            ? null
            : _Navigation(
                index: _tab,
                wide: false,
                name: _profile['nombre'] as String? ?? 'Coordinador',
                onSelect: (index) {
                  setState(() => _tab = index);
                  if (index == 0) _load();
                },
              ),
      ),
    );
  }

  Widget _content() => switch (_tab) {
        0 => _HomeView(
            teachers: _teachers,
            schedules: _schedules,
            groups: _groups,
            publishedSessions: _publishedSessions,
            onOpen: (tab) => setState(() => _tab = tab),
          ),
        1 => const CoordinacionHorariosPage(),
        2 => _LeadersView(teachers: _teachers, groups: _groups),
        3 => const CoordinacionSolicitudesPage(),
        4 => _ProfileView(profile: _profile, onRefresh: _load),
        _ => const _FeedbackReportsView(),
      };
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.name, required this.onProfile});
  final String title;
  final String? name;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final isHome = title == 'Inicio';
    final display =
        name?.trim().isNotEmpty == true ? name!.trim() : 'Coordinación';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          28, MediaQuery.paddingOf(context).top + 15, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isHome ? 'PANEL DE COORDINACIÓN' : 'COORDINACIÓN  /  $title',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _wine,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(isHome ? 'Hola, $display' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF202536),
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(isHome ? 'Resumen de tutorías y gestión académica' : display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          tooltip: 'Mi perfil',
          onPressed: onProfile,
          style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8EAF0),
              foregroundColor: _wineDark),
          icon: CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white,
            child: Text(_initials(display),
                style: const TextStyle(
                    color: _wineDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const NotificationBellButton(accentColor: _wine),
        IconButton(
          tooltip: 'Actualizar datos',
          onPressed: () => context
              .findAncestorStateOfType<_CoordinacionDashboardPageState>()
              ?._load(),
          style: IconButton.styleFrom(foregroundColor: const Color(0xFF596174)),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ]),
    );
  }
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

class _Navigation extends StatelessWidget {
  const _Navigation(
      {required this.index,
      required this.wide,
      required this.name,
      required this.onSelect});
  final int index;
  final bool wide;
  final String name;
  final ValueChanged<int> onSelect;
  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Horarios'),
    (Icons.groups_outlined, Icons.groups_rounded, 'Líderes'),
    (Icons.event_available_outlined, Icons.event_available_rounded, 'Cambios'),
    (Icons.assessment_outlined, Icons.assessment_rounded, 'Reportes'),
  ];
  static const _tabIndexes = [0, 1, 2, 3, 5];

  @override
  Widget build(BuildContext context) {
    if (wide) {
      final selectedPosition =
          _tabIndexes.contains(index) ? _tabIndexes.indexOf(index) : null;
      return Container(
        width: 208,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: _border)),
        ),
        child: Column(children: [
          const SizedBox(height: 14),
          const SizedBox(
            height: 64,
            width: 150,
            child: BrandLogo(width: 150, height: 64),
          ),
          const SizedBox(height: 8),
          const Text('COORDINACIÓN',
              style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  letterSpacing: .7,
                  fontWeight: FontWeight.w600)),
          const Divider(color: _border, indent: 12, endIndent: 12),
          Expanded(
              child: NavigationRail(
            backgroundColor: Colors.white,
            minWidth: 208,
            selectedIndex: selectedPosition,
            onDestinationSelected: (position) =>
                onSelect(_tabIndexes[position]),
            labelType: NavigationRailLabelType.all,
            indicatorColor: const Color(0xFFF8EAF0),
            selectedIconTheme: const IconThemeData(color: _wine),
            unselectedIconTheme: const IconThemeData(color: _muted),
            selectedLabelTextStyle:
                const TextStyle(color: _wineDark, fontWeight: FontWeight.w700),
            unselectedLabelTextStyle: const TextStyle(color: _muted),
            destinations: [
              for (var i = 0; i < _items.length; i++)
                NavigationRailDestination(
                  icon: Icon(_items[i].$1),
                  selectedIcon: Icon(_items[i].$2),
                  label: Text(_items[i].$3),
                ),
            ],
          )),
          const Divider(color: _border, indent: 10, endIndent: 10),
          InkWell(
            onTap: () => onSelect(4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 14),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFF8EAF0),
                  child: Text(_initials(name),
                      style: const TextStyle(
                          color: _wineDark,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 7),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF202536),
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                      const Text('Coordinador',
                          style: TextStyle(color: _muted, fontSize: 10)),
                    ])),
                const Icon(Icons.chevron_right, color: _muted, size: 16),
              ]),
            ),
          ),
        ]),
      );
    }
    final selectedPosition = _tabIndexes.indexOf(index);
    return SlidingPillNavigationBar(
      selectedIndex: selectedPosition < 0 ? 0 : selectedPosition,
      selectedColor: _wine,
      indicatorColor: const Color(0xFFF8EAF0),
      onDestinationSelected: (position) => onSelect(_tabIndexes[position]),
      destinations: [
        for (final item in _items)
          SlidingPillDestination(
            icon: item.$1,
            selectedIcon: item.$2,
            label: item.$3,
          ),
      ],
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView(
      {required this.teachers,
      required this.schedules,
      required this.groups,
      required this.publishedSessions,
      required this.onOpen});
  final List<Map<String, dynamic>> teachers,
      schedules,
      groups,
      publishedSessions;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final scheduledIds = schedules
        .map((row) => row['docenteId'])
        .followedBy(publishedSessions.map((session) => session['docenteId']))
        .toSet();
    final unscheduled = teachers
        .where((teacher) => !scheduledIds.contains(teacher['id']))
        .toList();
    final assignedLeaders =
        groups.where((group) => group['docenteLiderId'] is String).length;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_wine, _wineDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _wine.withValues(alpha: .16),
                    blurRadius: 22,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: Row(children: [
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GESTIÓN DE TUTORÍAS',
                            style: TextStyle(
                                color: Color(0xFFEFD3DE),
                                fontSize: 10,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 8),
                        Text('Todo listo para coordinar',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 6),
                        Text(
                          'Consulta horarios, asigna liderazgos y atiende solicitudes desde un solo lugar.',
                          style: TextStyle(
                              color: Color(0xFFDCC7CF),
                              fontSize: 13,
                              height: 1.4),
                        ),
                      ]),
                ),
                if (MediaQuery.sizeOf(context).width >= 620) ...[
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () => onOpen(1),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _wineDark,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text('Gestionar horarios'),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                  child: _Metric(
                      value: '${teachers.length}', label: 'Tutores activos')),
              const SizedBox(width: 10),
              Expanded(
                  child: _Metric(
                      value: '$assignedLeaders/${groups.length}',
                      label: 'Con líder')),
              const SizedBox(width: 10),
              Expanded(
                  child:
                      _Metric(value: '${groups.length}', label: 'Grupos PA')),
            ]),
            const SizedBox(height: 30),
            _SectionTitle(
                title: 'Por asignar',
                action: 'Ver horarios',
                onTap: () => onOpen(1)),
            const SizedBox(height: 10),
            if (unscheduled.isEmpty)
              const _EmptyCard(
                  message: 'Todos los tutores tienen un horario registrado.')
            else
              _CardList(children: [
                for (final teacher in unscheduled.take(4))
                  _RecordRow(
                    icon: Icons.groups_2_outlined,
                    title: _text(teacher['nombre'], 'Tutor'),
                    subtitle: 'ID ${_text(teacher['id'], '—')}',
                    badge: 'Sin horario',
                    onTap: () => onOpen(1),
                  ),
              ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _LeadersView extends StatelessWidget {
  const _LeadersView({required this.teachers, required this.groups});
  final List<Map<String, dynamic>> teachers, groups;

  @override
  Widget build(BuildContext context) {
    final names = {
      for (final teacher in teachers) teacher['id']: teacher['nombre']
    };
    final projects = <Map<String, dynamic>>[];
    for (final group in groups) {
      final items = group['proyectos'];
      if (items is List) {
        for (final item in items.whereType<Map<String, dynamic>>()) {
          projects.add({
            ...item,
            '_leaderId': group['docenteLiderId'],
            '_supportId': item['docenteResponsableId'],
          });
        }
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: _pink, borderRadius: BorderRadius.circular(18)),
          child: const Text(
              'Proyectos y responsables de tutorías colectivas guardados en el sistema.',
              style: TextStyle(color: _wineDark, height: 1.35)),
        ),
        const SizedBox(height: 18),
        if (projects.isEmpty)
          const _EmptyCard(
              message: 'No hay proyectos de tutoría colectiva registrados.')
        else
          for (final project in projects)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RecordRow(
                icon: Icons.groups_2_outlined,
                title: _text(project['nombre'], 'Proyecto'),
                subtitle:
                    'Semestre ${_text(project['semestre'], '—')} · Líder: ${_text(names[project['_leaderId']], 'No registrado')} · Apoyo: ${_text(names[project['_supportId']], 'No registrado')}',
                badge: 'Asignado',
              ),
            ),
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
    Widget row(IconData icon, String title, String value) =>
        _RecordRow(icon: icon, title: title, subtitle: value);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        const Text('Datos de la cuenta',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _CardList(children: [
          _RecordRow(
            icon: Icons.phone_outlined,
            title: 'Teléfono',
            subtitle: _text(profile['telefono'], 'No registrado'),
          ),
        ]),
        const SizedBox(height: 20),
        const Text('Seguridad',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _CardList(children: [
          _RecordRow(
            icon: Icons.lock_outline_rounded,
            title: 'Contraseña',
            subtitle: 'Solicita el restablecimiento al administrador.',
          ),
        ]),
        const SizedBox(height: 20),
        const Text('Datos institucionales',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _CardList(children: [
          _RecordRow(
            icon: Icons.email_outlined,
            title: 'Correo',
            subtitle: _text(profile['correo'], 'No registrado'),
          ),
          row(Icons.lock_outline, 'Documento',
              _text(profile['id'], 'No registrado')),
          row(Icons.lock_outline, 'Programa', 'No registrado'),
          row(Icons.lock_outline, 'Rol', _text(profile['rol'], 'Coordinador')),
        ]),
        const SizedBox(height: 10),
        const Text(
            'El perfil institucional muestra únicamente los campos disponibles en la cuenta.',
            style: TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _pink, foregroundColor: _wineDark),
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Cerrar sesión',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
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

  // ignore: unused_element
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

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF1F2937).withValues(alpha: .035),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF202536),
                  fontSize: 25,
                  height: 1,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                  color: _pink, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.insights_rounded, color: _wine, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600))),
          ]),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
      {required this.title, required this.action, required this.onTap});
  final String title, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800))),
        TextButton(
            onPressed: onTap,
            child: Text(action,
                style: const TextStyle(
                    color: _wine, fontWeight: FontWeight.w700))),
      ]);
}

class _CardList extends StatelessWidget {
  const _CardList({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .05),
                  blurRadius: 14,
                  offset: const Offset(0, 3))
            ]),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFEDF0F5)),
            children[i]
          ]
        ]),
      );
}

class _RecordRow extends StatelessWidget {
  const _RecordRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.badge,
      this.onTap});
  final IconData icon;
  final String title, subtitle;
  final String? badge;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: _pink, borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: _wine, size: 21)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11.5)),
                ])),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF1DC),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(badge!,
                      style: const TextStyle(
                          color: Color(0xFFAA6A13),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700))),
            ],
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFA4ADBB)),
          ]),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Text(message,
          textAlign: TextAlign.center, style: const TextStyle(color: _muted)));
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
