import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/tutoring_updates.dart';

class DocenteSolicitudesPage extends ConsumerStatefulWidget {
  const DocenteSolicitudesPage({super.key});

  @override
  ConsumerState<DocenteSolicitudesPage> createState() =>
      _DocenteSolicitudesPageState();
}

class _DocenteSolicitudesPageState extends ConsumerState<DocenteSolicitudesPage>
    with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  String? _busyId;
  List<_TutoringRequest> _requests = const [];

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
      final response = await ref.read(dioProvider).get<List<dynamic>>(
            '/api/tutorias/docente',
          );
      final requests = (response.data ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_TutoringRequest.fromJson)
          .where((request) => request.id.isNotEmpty)
          .toList()
        ..sort((left, right) {
          final pendingOrder = (left.state == 'SOLICITADA' ? 0 : 1)
              .compareTo(right.state == 'SOLICITADA' ? 0 : 1);
          if (pendingOrder != 0) return pendingOrder;
          return right.start.compareTo(left.start);
        });
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'El servidor devolvi\u{00F3} solicitudes con un formato inv\u{00E1}lido.';
        _loading = false;
      });
    }
  }

  Future<void> _accept(_TutoringRequest request) async {
    await _perform(
        request,
        () => ref
            .read(dioProvider)
            .patch('/api/tutorias/${Uri.encodeComponent(request.id)}/aceptar'));
  }

  Future<void> _proposeTime(_TutoringRequest request) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final requestedDate = DateTime(
      request.start.year,
      request.start.month,
      request.start.day,
    );
    final initialDate =
        requestedDate.isBefore(firstDate) ? firstDate : requestedDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365)),
      helpText: 'Elige una fecha alternativa',
    );
    if (date == null || !mounted) return;
    final startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(request.start),
      helpText: 'Hora de inicio',
    );
    if (startTime == null || !mounted) return;
    final defaultEnd = request.end.isAfter(request.start)
        ? request.end
        : request.start.add(const Duration(hours: 1));
    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(defaultEnd),
      helpText: 'Hora de finalizaci\u{00F3}n',
    );
    if (endTime == null || !mounted) return;

    final start = DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
    final end = DateTime(
      date.year,
      date.month,
      date.day,
      endTime.hour,
      endTime.minute,
    );
    if (!end.isAfter(start)) {
      _showMessage('La hora final debe ser posterior a la hora de inicio.');
      return;
    }

    await _perform(
      request,
      () => ref.read(dioProvider).patch(
        '/api/tutorias/${Uri.encodeComponent(request.id)}/proponer-horario',
        data: {
          'fechaInicio': start.toIso8601String(),
          'fechaFin': end.toIso8601String(),
        },
      ),
    );
  }

  Future<void> _perform(
    _TutoringRequest request,
    Future<dynamic> Function() action,
  ) async {
    setState(() => _busyId = request.id);
    try {
      await action();
      if (!mounted) return;
      _showMessage('La solicitud de ${request.subject} fue actualizada.');
      await _load();
    } on DioException catch (error) {
      if (!mounted) return;
      _showMessage(_message(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _message(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'No se pudo actualizar la solicitud. Int\u{00E9}ntalo de nuevo.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _timeLabel(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    ref.listen(tutoringUpdatesProvider, (_, next) {
      if (next.hasValue && mounted) _load();
    });
    final pending = _requests.where((request) => request.state == 'SOLICITADA');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const Text(
            'Solicitudes de tutor\u{00ED}as',
            style: TextStyle(
              color: Color(0xFF18352A),
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${pending.length} solicitudes esperan tu respuesta.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_loading && _requests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _requests.isEmpty)
            _LoadError(message: _error!, onRetry: _load)
          else if (_requests.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No tienes solicitudes de tutor\u{00ED}a.'),
              ),
            )
          else
            for (final request in _requests)
              _RequestCard(
                request: request,
                busy: _busyId == request.id,
                dateLabel: _dateLabel(request.start),
                timeLabel:
                    '${_timeLabel(request.start)} - ${_timeLabel(request.end)}',
                onAccept: () => _accept(request),
                onPropose: () => _proposeTime(request),
              ),
        ],
      ),
    );
  }
}

class _TutoringRequest {
  const _TutoringRequest({
    required this.id,
    required this.studentId,
    required this.subject,
    required this.modality,
    required this.start,
    required this.end,
    required this.state,
  });

  factory _TutoringRequest.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['fechaInicio']?.toString() ?? '');
    final end = DateTime.tryParse(json['fechaFin']?.toString() ?? '');
    if (start == null || end == null) {
      throw const FormatException(
          'La solicitud tiene fechas inv\u{00E1}lidas.');
    }
    return _TutoringRequest(
      id: json['id']?.toString() ?? '',
      studentId: json['estudianteId']?.toString() ?? 'Estudiante',
      subject: json['materia']?.toString() ?? 'Tutor\u{00ED}a',
      modality: json['modalidad']?.toString() ?? 'Sin modalidad',
      start: start,
      end: end,
      state: json['estado']?.toString() ?? 'SOLICITADA',
    );
  }

  final String id;
  final String studentId;
  final String subject;
  final String modality;
  final DateTime start;
  final DateTime end;
  final String state;
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.busy,
    required this.dateLabel,
    required this.timeLabel,
    required this.onAccept,
    required this.onPropose,
  });

  final _TutoringRequest request;
  final bool busy;
  final String dateLabel;
  final String timeLabel;
  final VoidCallback onAccept;
  final VoidCallback onPropose;

  @override
  Widget build(BuildContext context) {
    final isPending = request.state == 'SOLICITADA';
    final stateLabel = switch (request.state) {
      'SOLICITADA' => 'Pendiente',
      'ALTERNATIVA_PROPUESTA' => 'Esperando confirmaci\u{00F3}n',
      'PROGRAMADA' => 'Programada',
      'EN_CURSO' => 'En curso',
      'REALIZADA' => 'Realizada',
      'CANCELADA' => 'Cancelada',
      _ => request.state,
    };
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5ECE7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_outline_rounded,
                      color: Color(0xFF16834A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    request.subject,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPending
                        ? const Color(0xFFFFF3D9)
                        : const Color(0xFFEAF5EE),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    stateLabel,
                    style: TextStyle(
                      color: isPending
                          ? const Color(0xFF946200)
                          : const Color(0xFF16834A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 9,
              children: [
                _RequestDetail(
                  icon: Icons.badge_outlined,
                  label: 'Estudiante: ${request.studentId}',
                ),
                _RequestDetail(
                  icon: Icons.calendar_month_outlined,
                  label: dateLabel,
                ),
                _RequestDetail(
                  icon: Icons.schedule_outlined,
                  label: timeLabel,
                ),
                _RequestDetail(
                  icon: Icons.meeting_room_outlined,
                  label: request.modality,
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFEAF0EB)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : onAccept,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Aceptar solicitud'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onPropose,
                    icon: const Icon(Icons.schedule_outlined),
                    label: const Text('Proponer otro horario'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestDetail extends StatelessWidget {
  const _RequestDetail({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF7C8B81)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF687A70),
              fontSize: 12,
            ),
          ),
        ],
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
}
