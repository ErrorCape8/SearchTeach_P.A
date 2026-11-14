import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/role_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../core/career_catalog.dart';
import '../../../core/neu/neu.dart';
import '../../pa/pa_widgets.dart';
import '../admin_controller.dart';

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

  static const _invalidImportMessage =
      'no todos los usuairos cumplen con los parametros';

  Future<void> _importUsers() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      await _showImportError(_invalidImportMessage);
      return;
    }

    try {
      final extension = picked.files.single.extension?.toLowerCase();
      final users = switch (extension) {
        'csv' => _parseCsv(utf8.decode(bytes, allowMalformed: false)),
        'xlsx' => _parseXlsx(bytes),
        _ => throw const FormatException(),
      };
      setState(() => _importingUsers = true);
      await ref.read(dioProvider).post<void>(
        '/api/admin/users/import',
        data: {
          'usuarios': users
              .map((user) => <String, dynamic>{
                    ...user,
                    'semestre': int.tryParse(user['semestre'] ?? ''),
                  })
              .toList(),
        },
      );
      await ref.read(adminControllerProvider.notifier).loadUsers();
      if (mounted) {
        RoleToast.showSnackBar(
          context,
          SnackBar(content: Text('${users.length} usuarios importados.')),
        );
      }
    } on FormatException {
      await _showImportError(_invalidImportMessage);
    } on UnsupportedError {
      await _showImportError('El archivo no es un libro XLSX válido.');
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map && body['message'] is String
          ? body['message'] as String
          : 'No se pudo importar el archivo de usuarios.';
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
    return _parseUserRows(rows);
  }

  List<Map<String, String>> _parseXlsx(List<int> bytes) {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) throw const FormatException();
    final sheet = workbook.tables.values.first;
    final rows = sheet.rows
        .map((row) => row.map(_cellText).toList(growable: false))
        .where((row) => row.any((value) => value.isNotEmpty))
        .toList(growable: false);
    return _parseUserRows(rows);
  }

  String _cellText(Data? cell) {
    final value = cell?.value;
    return switch (value) {
      null => '',
      TextCellValue(:final value) => value.toString().trim(),
      IntCellValue(:final value) => value.toString(),
      DoubleCellValue(:final value) => value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString(),
      BoolCellValue(:final value) => value.toString(),
      DateCellValue() => value.toString(),
      TimeCellValue() => value.toString(),
      FormulaCellValue() => throw const FormatException(),
      _ => value.toString().trim(),
    };
  }

  List<Map<String, String>> _parseUserRows(List<List<String>> rows) {
    if (rows.length < 2) throw const FormatException();
    const required = ['id', 'nombre', 'correo', 'telefono', 'rol', 'estado'];
    final headers =
        rows.first.map((value) => value.trim().toLowerCase()).toList();
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
          (role.contains('estudiante') &&
              (semester == null || semester < 1 || semester > 6)) ||
          (record['semestre']!.trim().isNotEmpty &&
              (semester == null || semester < 1 || semester > 6)) ||
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
    final notifier = ref.read(adminControllerProvider.notifier);
    final users = state.filteredUsers;
    final pageCount = (users.length / _pageSize).ceil();
    final page = pageCount == 0 ? 0 : state.usersPage.clamp(0, pageCount - 1);
    final first = page * _pageSize;
    final pageUsers = users.skip(first).take(_pageSize).toList();
    const filters = [
      'Todos',
      'Activo',
      'Revocado',
      'Estudiante',
      'Docente',
      'Coordinador',
      'Líder de programas',
    ];

    Widget list() {
      if (state.isLoadingUsers) {
        return const Center(
            child: CircularProgressIndicator(color: Color(0xFFEA580C)));
      }
      if (state.usersError != null) {
        return ListView(padding: const EdgeInsets.all(18), children: [
          PaInfo(state.usersError!, tone: PaTone.error),
          NeuButton('Reintentar',
              kind: NeuButtonKind.alt,
              icon: Icons.refresh_rounded,
              onPressed: notifier.loadUsers),
        ]);
      }
      return ListView(
        padding: EdgeInsets.fromLTRB(
            18, 4, 18, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          PaRowList([
            for (final user in pageUsers)
              PaRow(
                icon: Icons.person_outline_rounded,
                title: user.nombre,
                subtitle: user.rol,
                trailing: PaTag(
                  user.isRevocado
                      ? 'Revocado'
                      : user.isActivo
                          ? 'Activo'
                          : user.estado,
                  tone: user.isRevocado
                      ? PaTone.error
                      : user.isActivo
                          ? PaTone.ok
                          : PaTone.warn,
                ),
                onTap: () => notifier.selectUser(user),
              ),
          ], empty: 'No hay usuarios que coincidan con la búsqueda.'),
          if (users.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Row(children: [
                Expanded(
                  child: Text('${first + 1}–${first + pageUsers.length} de ${users.length}',
                      style: neuBody(size: 13, color: Neu.muted)),
                ),
                NeuCircleButton(
                  icon: Icons.chevron_left_rounded,
                  size: 38,
                  tooltip: 'Página anterior',
                  onTap: page > 0 ? () => notifier.setUsersPage(page - 1) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('${page + 1} de $pageCount',
                      style: neuBody(size: 13, weight: FontWeight.w700)),
                ),
                NeuCircleButton(
                  icon: Icons.chevron_right_rounded,
                  size: 38,
                  tooltip: 'Página siguiente',
                  onTap: page + 1 < pageCount
                      ? () => notifier.setUsersPage(page + 1)
                      : null,
                ),
              ]),
            ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
          child: Row(children: [
            Expanded(
              child: NeuField(
                controller: _searchController,
                hint: 'Buscar por nombre',
                onChanged: notifier.setSearchQuery,
              ),
            ),
            const SizedBox(width: 12),
            NeuCircleButton(
              icon: Icons.filter_alt_outlined,
              size: 48,
              tooltip: 'Filtros',
              onTap: () => setState(() => _showFilters = !_showFilters),
            ),
          ]),
        ),
        if (_showFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NeuChipWrap([
                for (final option in filters)
                  NeuChip(option,
                      selected: state.filter == option,
                      onTap: () => notifier.setFilter(option)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                NeuButton('Actualizar',
                    kind: NeuButtonKind.alt,
                    small: true,
                    expand: false,
                    icon: Icons.refresh_rounded,
                    onPressed: state.isLoadingUsers ? null : notifier.loadUsers),
                const SizedBox(width: 10),
                NeuButton('Importar CSV / XLSX',
                    kind: NeuButtonKind.alt,
                    small: true,
                    expand: false,
                    icon: Icons.upload_file_outlined,
                    onPressed: _importingUsers ? null : _importUsers),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
        Expanded(child: list()),
      ],
    );
  }
}
