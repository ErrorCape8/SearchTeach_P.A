import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../core/career_catalog.dart';
import '../admin_controller.dart';
import '../models/admin_user.dart';

class AdminUsuariosView extends ConsumerStatefulWidget {
  const AdminUsuariosView({super.key});

  @override
  ConsumerState<AdminUsuariosView> createState() => _AdminUsuariosViewState();
}

class _AdminUsuariosViewState extends ConsumerState<AdminUsuariosView> {
  final _searchController = TextEditingController();
  static const _pageSize = 10;
  bool _importingUsers = false;
  bool _showFilters = false;
  bool _showUnactivatedUsers = true;

  static const _invalidCsvMessage =
      'no todos los usuairos cumplen con los parametros';

  Future<void> _importCsv() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      await _showImportError(_invalidCsvMessage);
      return;
    }

    try {
      final users = _parseCsv(utf8.decode(bytes, allowMalformed: false));
      setState(() => _importingUsers = true);
      await ref.read(dioProvider).post<void>(
        '/api/admin/users/import',
        data: {
          'usuarios': users.map((user) => <String, dynamic>{
            ...user,
            'semestre': int.tryParse(user['semestre'] ?? ''),
          }).toList(),
        },
      );
      await ref.read(adminControllerProvider.notifier).loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${users.length} usuarios importados.')),
        );
      }
    } on FormatException {
      await _showImportError(_invalidCsvMessage);
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map && body['message'] is String
          ? body['message'] as String
          : 'No se pudo importar el archivo CSV.';
      await _showImportError(message);
    } finally {
      if (mounted) setState(() => _importingUsers = false);
    }
  }

  List<Map<String, String>> _parseCsv(String source) {
    final rows = <List<String>>[];
    final row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    final text = source
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '"') {
        if (quoted && i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && char == ',') {
        row.add(cell.toString().trim());
        cell.clear();
      } else if (!quoted && char == '\n') {
        row.add(cell.toString().trim());
        cell.clear();
        if (row.any((value) => value.isNotEmpty)) rows.add(List.of(row));
        row.clear();
      } else {
        cell.write(char);
      }
    }
    if (quoted) throw const FormatException();
    row.add(cell.toString().trim());
    if (row.any((value) => value.isNotEmpty)) rows.add(row);
    if (rows.length < 2) throw const FormatException();

    const required = ['id', 'nombre', 'correo', 'telefono', 'rol', 'estado'];
    final headers = rows.first.map((value) => value.toLowerCase()).toList();
    if (headers.toSet().length != headers.length ||
        required.any((header) => !headers.contains(header))) {
      throw const FormatException();
    }
    final imported = <Map<String, String>>[];
    final ids = <String>{};
    final emails = <String>{};
    for (final values in rows.skip(1)) {
      if (values.length != headers.length) throw const FormatException();
      final record = <String, String>{
        for (var i = 0; i < headers.length; i++) headers[i]: values[i],
      };
      record.putIfAbsent('carrera', () => '');
      record.putIfAbsent('semestre', () => '');
      final id = record['id']!;
      final email = record['correo']!.toLowerCase();
      final status = record['estado']!.toLowerCase();
      final career = record['carrera']!.trim();
      final role = record['rol']!.toLowerCase();
      final semester = int.tryParse(record['semestre']!.trim());
      if (!RegExp(r'^\d{6,10}$').hasMatch(id) ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
          required.any((key) => record[key]!.isEmpty) ||
          (career.isNotEmpty && !careerCatalog.contains(career)) ||
          (role.contains('estudiante') && career.isEmpty) ||
          (role.contains('estudiante') && (semester == null || semester < 1 || semester > 6)) ||
          (record['semestre']!.trim().isNotEmpty && (semester == null || semester < 1 || semester > 6)) ||
          !const {'activo', 'revocado'}.contains(status) ||
          !ids.add(id) ||
          !emails.add(email)) {
        throw const FormatException();
      }
      record['correo'] = email;
      imported.add(record);
    }
    if (imported.isEmpty) throw const FormatException();
    return imported;
  }

  Future<void> _showImportError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
        title: const Text('Error al importar usuarios'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminControllerProvider);
    final users = state.filteredUsers;
    final pageCount = (users.length / _pageSize).ceil();
    final page = pageCount == 0 ? 0 : state.usersPage.clamp(0, pageCount - 1);
    final firstUserIndex = page * _pageSize;
    final pageUsers = users.skip(firstUserIndex).take(_pageSize).toList();

    return Column(
      children: [
        // Barra de búsqueda y filtro
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (val) {
                      ref
                          .read(adminControllerProvider.notifier)
                          .setSearchQuery(val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, correo o ID',
                      hintStyle: TextStyle(
                        color: Color(0xFF8C95A6),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Color(0xFF8C95A6),
                      ),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(adminControllerProvider.notifier)
                                    .setSearchQuery('');
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _showFilters = !_showFilters),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: state.filter != 'Todos'
                          ? const Color(0xFFEA580C)
                          : const Color(0xFFE5E7EB),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.filter_alt_outlined,
                    color: const Color(0xFFEA580C),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Actualizar lista de usuarios',
                child: IconButton(
                  onPressed: state.isLoadingUsers
                      ? null
                      : () => ref
                          .read(adminControllerProvider.notifier)
                          .loadUsers(),
                  icon: state.isLoadingUsers
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFFEA580C),
                    backgroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                          color: Color(0xFFE5E7EB), width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message:
                    'CSV: id,nombre,correo,telefono,rol,estado,carrera,semestre; semestre requerido para estudiantes',
                child: IconButton(
                  onPressed: _importingUsers ? null : _importCsv,
                  icon: _importingUsers
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFFEA580C),
                    backgroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                          color: Color(0xFFE5E7EB), width: 1.2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_showFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final option in const [
                    'Todos',
                    'Activo',
                    'Revocado',
                    'Estudiante',
                    'Docente',
                    'Coordinador',
                    'Líder de programas',
                  ])
                    ChoiceChip(
                      label: Text(option),
                      selected: state.filter == option,
                      selectedColor: const Color(0xFFFFE6D1),
                      labelStyle: TextStyle(
                        color: state.filter == option
                            ? const Color(0xFFB45309)
                            : const Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => ref
                          .read(adminControllerProvider.notifier)
                          .setFilter(option),
                    ),
                ],
              ),
            ),
          ),

        if (!state.isLoadingUsers &&
            state.usersError == null &&
            state.users.any((user) => !user.hasPassword))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE7EAF0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.person_add_alt_1_outlined,
                      color: Color(0xFFEA7408),
                      size: 19,
                    ),
                    title: Text(
                      'Cuentas sin contraseña '
                      '(${state.users.where((user) => !user.hasPassword).length})',
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    trailing: Icon(
                      _showUnactivatedUsers
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    onTap: () => setState(
                      () => _showUnactivatedUsers = !_showUnactivatedUsers,
                    ),
                  ),
                  if (_showUnactivatedUsers)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: state.users
                            .where((user) => !user.hasPassword)
                            .length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (context, index) {
                          final user = state.users
                              .where((user) => !user.hasPassword)
                              .elementAt(index);
                          return _UserListTile(
                            user: user,
                            onTap: () => ref
                                .read(adminControllerProvider.notifier)
                                .selectUser(user),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

        // Lista de usuarios
        Expanded(
          child: state.isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : state.usersError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.usersError!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => ref
                                  .read(adminControllerProvider.notifier)
                                  .loadUsers(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : users.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay usuarios que coincidan con la búsqueda.',
                            style: TextStyle(
                                color: Color(0xFF8C95A6), fontSize: 14),
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 6, 16, 12),
                                itemCount: pageUsers.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFF1F5F9),
                                ),
                                itemBuilder: (context, index) {
                                  final user = pageUsers[index];
                                  return _UserListTile(
                                    user: user,
                                    onTap: () => ref
                                        .read(adminControllerProvider.notifier)
                                        .selectUser(user),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${firstUserIndex + 1}–${firstUserIndex + pageUsers.length} de ${users.length}',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Página anterior',
                                        onPressed: page > 0
                                            ? () => ref
                                                .read(adminControllerProvider.notifier)
                                                .setUsersPage(page - 1)
                                            : null,
                                        icon: const Icon(Icons.chevron_left),
                                      ),
                                      Text('${page + 1} de $pageCount'),
                                      IconButton(
                                        tooltip: 'Página siguiente',
                                        onPressed: page + 1 < pageCount
                                            ? () => ref
                                                .read(adminControllerProvider.notifier)
                                                .setUsersPage(page + 1)
                                            : null,
                                        icon: const Icon(Icons.chevron_right),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
        ),
      ],
    );
  }
}

class _UserListTile extends StatelessWidget {
  const _UserListTile({
    required this.user,
    required this.onTap,
  });

  final AdminUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActivo = user.isActivo;
    final isRevocado = user.isRevocado;
    final stateLabel = isActivo
        ? 'Activo'
        : isRevocado
            ? 'Revocado'
            : 'Sin estado';
    final stateColor = isActivo
        ? const Color(0xFF16A34A)
        : isRevocado
            ? const Color(0xFFDC2626)
            : const Color(0xFF64748B);
    final stateBackground = isActivo
        ? const Color(0xFFDCFCE7)
        : isRevocado
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFE2E8F0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            // Avatar con icono de persona
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF1E6),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFFEA580C),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Nombre y Rol
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nombre.isEmpty ? 'Sin nombre registrado' : user.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.rol.isEmpty ? 'Sin rol registrado' : user.rol,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  if (user.carrera.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.carrera,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF8C95A6),
                      ),
                    ),
                  ],
                  if (user.rol.toLowerCase().contains('estudiante') && user.semestre > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Semestre ${user.semestre}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF8C95A6),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Badges de acceso y activación reportados por el servidor.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stateBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    stateLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: stateColor,
                    ),
                  ),
                ),
                if (!user.hasPassword) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Sin contraseña',
                    style: TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
