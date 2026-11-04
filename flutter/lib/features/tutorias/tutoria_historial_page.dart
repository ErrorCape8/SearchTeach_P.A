import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class TutoriaHistorialPage extends ConsumerStatefulWidget {
  const TutoriaHistorialPage({
    required this.sessionId,
    required this.subject,
    required this.isIndividual,
    super.key,
  });

  final String sessionId;
  final String subject;
  final bool isIndividual;

  @override
  ConsumerState<TutoriaHistorialPage> createState() =>
      _TutoriaHistorialPageState();
}

class _TutoriaHistorialPageState extends ConsumerState<TutoriaHistorialPage> {
  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;

  String get _sessionPath => widget.isIndividual
      ? '/api/tutorias/${Uri.encodeComponent(widget.sessionId)}'
      : '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final sessionResponse =
          await dio.get<Map<String, dynamic>>(_sessionPath);
      final session = sessionResponse.data;
      if (session == null) {
        throw const FormatException('El servidor devolvió una tutoría vacía.');
      }

      List<Map<String, dynamic>> students = [];
      List<Map<String, dynamic>> messages = [];
      if (!widget.isIndividual) {
        final results = await Future.wait([
          dio.get<List<dynamic>>(
              '$_sessionPath/estudiantes'),
          dio.get<List<dynamic>>('$_sessionPath/chat'),
        ]);
        students = (results[0].data ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        messages = (results[1].data ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _session = session;
        _students = students;
        _messages = messages;
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      setState(() {
        _loading = false;
        _error = data is Map && data['message'] is String
            ? data['message'] as String
            : error.message ?? 'No se pudo cargar el historial de la tutoría.';
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  String _dateLabel(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Fecha no disponible';
    final datePart =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timePart =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$datePart · $timePart';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F7F5),
        appBar: AppBar(
          title: const Text('Historial de tutoría'),
          actions: [
            IconButton(
              tooltip: 'Actualizar historial',
              onPressed: _loading ? null : _loadHistory,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _loadHistory,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.menu_book_outlined),
                          ),
                          title: Text(
                            widget.subject,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${_dateLabel(_session?['fechaInicio'])}\n'
                            'Finalización: ${_dateLabel(_session?['fechaFin'])}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _attendanceCard(),
                      if (!widget.isIndividual) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Registro del chat',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_messages.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(18),
                              child: Text('No hay mensajes registrados.'),
                            ),
                          )
                        else
                          for (final message in _messages)
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  message['nombre']?.toString() ??
                                      message['emisorId']?.toString() ??
                                      'Participante',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                subtitle:
                                    Text(message['texto']?.toString() ?? ''),
                                trailing: Text(
                                  _dateLabel(message['enviadoEn']),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
      );

  Widget _attendanceCard() {
    if (widget.isIndividual) {
      final attended = _session?['asistio'];
      return Card(
        child: ListTile(
          leading: Icon(
            attended == true ? Icons.check_circle : Icons.event_busy_outlined,
            color: attended == true ? const Color(0xFF16834A) : Colors.blueGrey,
          ),
          title: Text(_session?['estudianteId']?.toString() ?? 'Estudiante'),
          subtitle: Text(attended == true
              ? 'Asistencia marcada: asistió'
              : attended == false
                  ? 'Asistencia marcada: no asistió'
                  : 'Asistencia sin marcar'),
        ),
      );
    }

    final attendance = (_session?['asistencias'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];
    final names = {
      for (final student in _students)
        if (student['id'] is String)
          student['id'] as String: student['nombre']?.toString() ??
              student['id'] as String,
    };
    final marked = {
      for (final item in attendance)
        if (item['estudianteId'] is String)
          item['estudianteId'] as String: item['asistio'] as bool?,
    };
    final studentIds = _session?['estudianteIds'] is List
        ? (_session!['estudianteIds'] as List).whereType<String>().toList()
        : names.keys.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Asistencia registrada',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (studentIds.isEmpty)
              const Text('No hay estudiantes registrados en esta tutoría.')
            else
              for (final id in studentIds)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    marked[id] == true
                        ? Icons.check_circle
                        : marked[id] == false
                            ? Icons.cancel
                            : Icons.help_outline,
                    color: marked[id] == true
                        ? const Color(0xFF16834A)
                        : marked[id] == false
                            ? const Color(0xFFB3261E)
                            : Colors.blueGrey,
                  ),
                  title: Text(names[id] ?? id),
                  subtitle: Text(
                    marked[id] == true
                        ? 'Asistió'
                        : marked[id] == false
                            ? 'No asistió'
                            : 'Sin marcar',
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
