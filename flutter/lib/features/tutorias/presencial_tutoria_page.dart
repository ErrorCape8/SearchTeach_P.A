import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class PresencialTutoriaPage extends ConsumerStatefulWidget {
  const PresencialTutoriaPage({
    required this.sessionId,
    required this.subject,
    super.key,
  });

  final String sessionId;
  final String subject;

  @override
  ConsumerState<PresencialTutoriaPage> createState() =>
      _PresencialTutoriaPageState();
}

class _PresencialTutoriaPageState extends ConsumerState<PresencialTutoriaPage> {
  static const _green = Color(0xFF0C8A53);

  final Map<String, bool?> _attendance = {};
  final Map<String, String> _studentNames = {};
  bool _starting = true;
  bool _loadingAttendance = true;
  bool _saving = false;
  bool _ended = false;
  String? _error;

  String get _sessionPath =>
      '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}';

  @override
  void initState() {
    super.initState();
    _enableClass();
  }

  Future<void> _enableClass() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).patch('$_sessionPath/iniciar-presencial');
      if (!mounted) return;
      setState(() => _starting = false);
      await _loadAttendance();
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = error.response?.data is Map<String, dynamic>
            ? (error.response!.data['message'] as String?) ??
                'No se pudo habilitar la clase presencial.'
            : 'No se pudo habilitar la clase presencial.';
      });
    }
  }

  Future<void> _loadAttendance() async {
    setState(() {
      _loadingAttendance = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final sessionResponse = await dio.get<Map<String, dynamic>>(_sessionPath);
      final studentsResponse = await dio.get<List<dynamic>>('$_sessionPath/estudiantes');
      final session = sessionResponse.data;
      final students = studentsResponse.data ?? const [];
      if (session == null) {
        throw const FormatException('No se encontró la clase presencial.');
      }

      final attendance = <String, bool?>{};
      final records = session['asistencias'];
      if (records is List) {
        for (final record in records.whereType<Map<String, dynamic>>()) {
          final id = record['estudianteId'];
          if (id is String && id.isNotEmpty) {
            attendance[id] = record['asistio'] as bool?;
          }
        }
      }

      final names = <String, String>{};
      for (final student in students.whereType<Map<String, dynamic>>()) {
        final id = student['id'];
        final name = student['nombre'];
        if (id is String && id.isNotEmpty) {
          names[id] = name is String && name.trim().isNotEmpty ? name : id;
          attendance.putIfAbsent(id, () => null);
        }
      }

      if (!mounted) return;
      setState(() {
        _attendance
          ..clear()
          ..addAll(attendance);
        _studentNames
          ..clear()
          ..addAll(names);
        _ended = session['estadoClase'] == 'FINALIZADA';
        _loadingAttendance = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingAttendance = false;
        _error = error.message ?? 'No se pudo cargar la lista de asistencia.';
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingAttendance = false;
        _error = error.message;
      });
    }
  }

  Future<void> _setAttendance(String studentId, bool attended) async {
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).patch(
        '$_sessionPath/asistencia',
        data: {'estudianteId': studentId, 'asistio': attended},
      );
      if (mounted) setState(() => _attendance[studentId] = attended);
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _error = error.response?.data is Map<String, dynamic>
            ? (error.response!.data['message'] as String?) ??
                'No se pudo guardar la asistencia.'
            : 'No se pudo guardar la asistencia.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finish(String reason) async {
    final noShow = reason == 'FALTA_ESTUDIANTES';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(noShow ? 'Terminar por inasistencia' : 'Finalizar clase'),
        content: Text(noShow
            ? 'Se registrará como ausentes a los estudiantes que no tengan asistencia marcada. ¿Deseas terminar la clase?'
            : '¿Confirmas que la tutoría presencial terminó?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).patch(
        '$_sessionPath/finalizar',
        data: {'motivo': reason},
      );
      if (mounted) {
        setState(() {
          _ended = true;
          for (final id in _attendance.keys.toList()) {
            _attendance[id] ??= false;
          }
        });
      }
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _error = error.response?.data is Map<String, dynamic>
            ? (error.response!.data['message'] as String?) ??
                'No se pudo finalizar la clase.'
            : 'No se pudo finalizar la clase.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF3F8F4),
        appBar: AppBar(
          title: const Text('Clase presencial'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0A6843),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _starting
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _attendance.isEmpty
                    ? _errorView()
                    : _classContent(),
          ),
        ),
      );

  Widget _errorView() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 38),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _enableClass,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar habilitación'),
            ),
          ],
        ),
      );

  Widget _classContent() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.subject,
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A6843))),
                  const SizedBox(height: 6),
                  Text(_ended
                      ? 'Clase finalizada'
                      : 'Clase presencial habilitada'),
                  const SizedBox(height: 18),
                  const Text('Lista de asistencia',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_loadingAttendance)
                    const LinearProgressIndicator()
                  else if (_attendance.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No hay estudiantes inscritos en esta clase.'),
                    )
                  else
                    for (final entry in _attendance.entries)
                      _studentRow(entry.key, entry.value),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 18),
                  if (!_ended)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: _saving || _loadingAttendance
                              ? null
                              : () => _finish('FINALIZADA'),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Finalizar clase'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _saving ||
                                  _loadingAttendance ||
                                  _attendance.values.any((value) => value == true)
                              ? null
                              : () => _finish('FALTA_ESTUDIANTES'),
                          icon: const Icon(Icons.person_off_outlined),
                          label: const Text(
                              'Terminar por inasistencia de estudiantes'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _studentRow(String id, bool? attended) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_studentNames[id] ?? id),
        subtitle: Text(attended == null
            ? 'Asistencia pendiente'
            : attended
                ? 'Presente'
                : 'Ausente'),
        trailing: _ended
            ? Icon(
                attended == true ? Icons.check_circle : Icons.cancel_outlined,
                color: attended == true ? _green : Colors.blueGrey,
              )
            : Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Marcar presente',
                    onPressed: _saving ? null : () => _setAttendance(id, true),
                    color: attended == true ? _green : null,
                    icon: const Icon(Icons.check_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Marcar ausente',
                    onPressed: _saving ? null : () => _setAttendance(id, false),
                    color: attended == false ? Colors.red : null,
                    icon: const Icon(Icons.cancel_outlined),
                  ),
                ],
              ),
      );
}
