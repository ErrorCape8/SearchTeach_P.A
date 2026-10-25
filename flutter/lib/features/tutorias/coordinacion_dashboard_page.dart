import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../auth/auth_repository.dart';
import '../auth/profile_change_dialog.dart';
import '../notifications/notifications_page.dart';
import 'coordinacion_horarios_page.dart';
import 'coordinacion_solicitudes_page.dart';

const _wine = Color(0xFFA9154F);
const _wineDark = Color(0xFF86123F);
const _pink = Color(0xFFFCE7EF);
const _canvas = Color(0xFFF3F5FA);
const _muted = Color(0xFF758093);

class CoordinacionDashboardPage extends ConsumerStatefulWidget {
  const CoordinacionDashboardPage({super.key});

  @override
  ConsumerState<CoordinacionDashboardPage> createState() =>
      _CoordinacionDashboardPageState();
}

class _CoordinacionDashboardPageState
    extends ConsumerState<CoordinacionDashboardPage> {
  int _tab = 0;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _groups = [];
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _load();
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
        final profile = responses[3].data;
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
      ][_tab];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final content = Column(
      children: [
        if (_tab != 1)
          _Header(title: _title(), name: _profile['nombre'] as String?),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _wine))
              : _error != null
                  ? _LoadFailure(message: _error!, onRetry: _load)
                  : _content(),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: _canvas,
      body: wide
          ? Row(
              children: [
                _Navigation(
                  index: _tab,
                  wide: true,
                  onSelect: (index) => setState(() => _tab = index),
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
              onSelect: (index) => setState(() => _tab = index),
            ),
    );
  }

  Widget _content() => switch (_tab) {
        0 => _HomeView(
            teachers: _teachers,
            schedules: _schedules,
            groups: _groups,
            onOpen: (tab) => setState(() => _tab = tab),
          ),
        1 => const CoordinacionHorariosPage(),
        2 => _LeadersView(teachers: _teachers, groups: _groups),
        3 => const CoordinacionSolicitudesPage(),
        _ => _ProfileView(profile: _profile, onRefresh: _load),
      };
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.name});
  final String title;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final isHome = title == 'Inicio';
    final display =
        name?.trim().isNotEmpty == true ? name!.trim() : 'Coordinación';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.paddingOf(context).top + 12, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_wine, _wineDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(_initials(display),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isHome ? 'Hola, $display' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            Text(isHome ? 'Coordinador' : display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .82), fontSize: 13)),
          ]),
        ),
        const NotificationBellButton(),
        IconButton(
          tooltip: 'Actualizar datos',
          onPressed: () => context
              .findAncestorStateOfType<_CoordinacionDashboardPageState>()
              ?._load(),
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
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
      {required this.index, required this.wide, required this.onSelect});
  final int index;
  final bool wide;
  final ValueChanged<int> onSelect;
  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Horarios'),
    (Icons.groups_outlined, Icons.groups_rounded, 'Líderes'),
    (
      Icons.event_available_outlined,
      Icons.event_available_rounded,
      'Cambios'
    ),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return Container(
        color: Colors.white,
        child: NavigationRail(
          selectedIndex: index,
          onDestinationSelected: onSelect,
          labelType: NavigationRailLabelType.all,
          indicatorColor: _pink,
          selectedIconTheme: const IconThemeData(color: _wine),
          selectedLabelTextStyle:
              const TextStyle(color: _wine, fontWeight: FontWeight.w700),
          destinations: [
            for (var i = 0; i < _items.length; i++)
              NavigationRailDestination(
                icon: Icon(_items[i].$1),
                selectedIcon: Icon(_items[i].$2),
                label: Text(_items[i].$3),
              ),
          ],
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .1),
                blurRadius: 18,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(i == index ? _items[i].$2 : _items[i].$1,
                          color: i == index ? _wine : const Color(0xFFA4ADBB),
                          size: 22),
                      const SizedBox(height: 2),
                      Text(_items[i].$3,
                          style: TextStyle(
                              color: i == index ? _wine : _muted,
                              fontSize: 10.5,
                              fontWeight: i == index
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView(
      {required this.teachers,
      required this.schedules,
      required this.groups,
      required this.onOpen});
  final List<Map<String, dynamic>> teachers, schedules, groups;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final scheduledIds = schedules.map((row) => row['docenteId']).toSet();
    final unscheduled = teachers
        .where((teacher) => !scheduledIds.contains(teacher['id']))
        .toList();
    final assignedLeaders =
        groups.where((group) => group['docenteLiderId'] is String).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
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
              child: _Metric(value: '${groups.length}', label: 'Grupos PA')),
        ]),
        const SizedBox(height: 24),
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
    Widget row(IconData icon, String title, String value,
            {bool editable = false}) =>
        _RecordRow(
            icon: icon,
            title: title,
            subtitle: value,
            badge: editable ? 'Editar' : null);
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
            badge: 'Editar',
            onTap: () => showProfileChangeDialog(context, ref, onUpdated: onRefresh),
          ),
        ]),
        const SizedBox(height: 20),
        const Text('Seguridad',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _CardList(children: [
          _RecordRow(
            icon: Icons.lock_outline_rounded,
            title: 'Cambiar contraseña',
            subtitle: 'Mínimo 8 caracteres.',
            onTap: () => showProfileChangeDialog(context, ref, onUpdated: onRefresh),
          ),
        ]),
        const SizedBox(height: 20),
        const Text('Datos institucionales',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _CardList(children: [
          _RecordRow(
            icon: Icons.email_outlined,
            title: 'Correo para códigos de seguridad',
            subtitle: _text(profile['correo'], 'No registrado'),
            badge: 'Cambiar',
            onTap: () => showProfileChangeDialog(context, ref, onUpdated: onRefresh),
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

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .05),
                  blurRadius: 12,
                  offset: const Offset(0, 3))
            ]),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  color: _wine, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 10.5)),
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

String _date(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return 'Fecha no disponible';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
