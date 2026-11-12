import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/role_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/api_client.dart';

const _profileGreen = Color(0xFF16834A);
const _profileNavy = Color(0xFF18352A);

final docenteProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response = await ref
      .read(dioProvider)
      .get<Map<String, dynamic>>('/api/usuarios/perfil');
  final data = response.data;
  if (data == null) throw const FormatException('El perfil está vacío.');
  return data;
});

class DocentePerfilPage extends ConsumerWidget {
  const DocentePerfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(docenteProfileProvider);
    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No se pudo cargar tu perfil: $error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(docenteProfileProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      data: (data) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Mi perfil',
                    style: TextStyle(
                      color: _profileNavy,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ProfileHero(
                    name: _value(data['nombre']),
                    career: _value(data['carrera']),
                    role: _value(data['rol']),
                  ),
                  const SizedBox(height: 18),
                  _ProfileCard(
                    title: 'Información de contacto',
                    children: [
                      _ProfileRow(
                        icon: Icons.email_outlined,
                        label: 'Correo institucional',
                        value: _value(data['correo']),
                      ),
                      _ProfileRow(
                        icon: Icons.phone_outlined,
                        label: 'Teléfono',
                        value: _value(data['telefono']),
                        onTap: () =>
                            _editPhone(context, ref, _value(data['telefono'])),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ProfileCard(
                    title: 'Información institucional',
                    children: [
                      _ProfileRow(
                        icon: Icons.badge_outlined,
                        label: 'Identificador de cuenta',
                        value: _value(data['id']),
                      ),
                      _ProfileRow(
                        icon: Icons.school_outlined,
                        label: 'Programa académico',
                        value: _value(data['carrera']),
                      ),
                      _ProfileRow(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Rol',
                        value: _value(data['rol']),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ProfileCard(
                    title: 'Perfil académico',
                    children: [
                      _ProfileRow(
                        icon: Icons.menu_book_outlined,
                        label: 'Materias principales',
                        value: _capabilities(data['materiasPrincipales']),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ProfileCard(
                    title: 'Certificaciones',
                    children: [_CertificationsCard(ref: ref)],
                  ),
                  const SizedBox(height: 14),
                  _ProfileCard(
                    title: 'Seguridad',
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lock_outline,
                            color: _profileGreen),
                        title: const Text('Cambiar contraseña'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _changePassword(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _value(dynamic value) =>
      value is String && value.trim().isNotEmpty ? value : 'No registrado';

  String _capabilities(dynamic value) {
    if (value is! List || value.isEmpty) return 'Sin materias configuradas';
    return value.whereType<Map>().map((item) {
      final materia = item['materia'] ?? 'Materia';
      final carrera = item['tecnologia'] ?? '';
      return '$materia - $carrera';
    }).join('\n');
  }

  Future<void> _editPhone(
      BuildContext context, WidgetRef ref, String current) async {
    final controller =
        TextEditingController(text: current == 'No registrado' ? '' : current);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar teléfono'),
        content: TextField(
            controller: controller, keyboardType: TextInputType.phone),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await ref
          .read(dioProvider)
          .patch('/api/usuarios/perfil/telefono', data: {'telefono': value});
      ref.invalidate(docenteProfileProvider);
    } on DioException catch (error) {
      if (context.mounted) {
        RoleToast.showSnackBar(
            context, SnackBar(content: Text(_message(error))));
      }
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: current,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Contraseña actual')),
          TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (current.text.isEmpty || next.text.length < 8) return;
              try {
                await ref
                    .read(dioProvider)
                    .patch('/api/usuarios/perfil/contrasena', data: {
                  'contrasenaActual': current.text,
                  'nuevaContrasena': next.text
                });
                if (context.mounted) Navigator.pop(context, true);
              } on DioException catch (error) {
                if (context.mounted) {
                  RoleToast.showSnackBar(
                      context, SnackBar(content: Text(_message(error))));
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    if (confirmed == true && context.mounted) {
      RoleToast.showSnackBar(
          context, const SnackBar(content: Text('Contraseña actualizada.')));
    }
  }

  String _message(DioException error) {
    final data = error.response?.data;
    return data is Map && data['message'] is String
        ? data['message'] as String
        : 'No se pudo actualizar la información.';
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5ECE7)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _profileNavy)),
            const SizedBox(height: 8),
            ...children,
          ]),
        ),
      );
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.career,
    required this.role,
  });

  final String name;
  final String career;
  final String role;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF16834A), Color(0xFF18352A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 480;
            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PERFIL DOCENTE',
                  style: TextStyle(
                    color: Color(0xFFD8F0E3),
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 19 : 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  career,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE5F4EB),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
            final avatar = CircleAvatar(
              radius: compact ? 32 : 39,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person_outline,
                size: compact ? 34 : 43,
                color: const Color(0xFF16834A),
              ),
            );
            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [avatar, const SizedBox(height: 15), identity],
                  )
                : Row(
                    children: [
                      avatar,
                      const SizedBox(width: 18),
                      Expanded(child: identity),
                    ],
                  );
          },
        ),
      );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: _profileGreen),
        title: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(label),
        trailing: onTap == null ? null : const Icon(Icons.edit_outlined),
        onTap: onTap,
      );
}

class _CertificationsCard extends ConsumerStatefulWidget {
  const _CertificationsCard({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_CertificationsCard> createState() =>
      _CertificationsCardState();
}

class _CertificationsCardState extends ConsumerState<_CertificationsCard> {
  final _where = TextEditingController();
  final _duration = TextEditingController();
  final _place = TextEditingController();
  List<dynamic> _items = const [];
  PlatformFile? _file;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _where.dispose();
    _duration.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final response = await widget.ref
          .read(dioProvider)
          .get<List<dynamic>>('/api/usuarios/perfil/certificaciones');
      if (mounted) {
        setState(() {
          _items = response.data ?? const [];
          _loading = false;
        });
      }
    } on DioException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = _message(error);
        });
      }
    }
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() => _file = result.files.single);
    }
  }

  Future<void> _submit() async {
    if (_where.text.trim().isEmpty ||
        _duration.text.trim().isEmpty ||
        _place.text.trim().isEmpty ||
        _file?.bytes == null) {
      RoleToast.showSnackBar(
        context,
        const SnackBar(content: Text('Completa los datos y adjunta el PDF.')),
      );
      return;
    }
    final form = FormData.fromMap({
      'dondeLaDio': _where.text.trim(),
      'duracion': _duration.text.trim(),
      'lugar': _place.text.trim(),
      'pdf': MultipartFile.fromBytes(_file!.bytes!, filename: _file!.name),
    });
    try {
      await widget.ref
          .read(dioProvider)
          .post('/api/usuarios/perfil/certificaciones', data: form);
      _where.clear();
      _duration.clear();
      _place.clear();
      setState(() => _file = null);
      await _load();
      if (mounted) {
        RoleToast.showSnackBar(
          context,
          const SnackBar(content: Text('Certificación enviada a TI.')),
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        RoleToast.showSnackBar(
            context, SnackBar(content: Text(_message(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => _ProfileCard(
        title: 'Certificaciones',
        children: [
          TextField(
              controller: _where,
              decoration: const InputDecoration(labelText: 'Dónde la dio')),
          TextField(
              controller: _duration,
              decoration: const InputDecoration(labelText: 'Duración')),
          TextField(
              controller: _place,
              decoration: const InputDecoration(labelText: 'Lugar')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(_file?.name ?? 'Ningún PDF seleccionado')),
            OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.attach_file),
                label: const Text('PDF')),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: const Text('Enviar a TI')),
          if (_loading) const LinearProgressIndicator(),
          if (_loadError != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'No se pudieron cargar las certificaciones: $_loadError',
                style: const TextStyle(color: Colors.red),
              ),
              trailing: IconButton(
                tooltip: 'Reintentar',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ),
          for (final item in _items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title:
                  Text('${item['dondeLaDio'] ?? ''} · ${item['lugar'] ?? ''}'),
              subtitle: Text(
                  'Duración: ${item['duracion'] ?? ''} · Estado: ${item['estado'] ?? ''}'),
            ),
        ],
      );

  String _message(DioException error) {
    final data = error.response?.data;
    return data is Map && data['message'] is String
        ? data['message'] as String
        : 'No se pudo enviar la certificación.';
  }
}
