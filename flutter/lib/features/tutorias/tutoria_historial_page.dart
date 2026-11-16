import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/role_theme.dart';
import '../pa/pa_widgets.dart';

class TutoriaHistorialPage extends ConsumerStatefulWidget {
  const TutoriaHistorialPage({
    required this.sessionId,
    required this.subject,
    this.isTeacher = false,
    super.key,
  });

  final String sessionId;
  final String subject;
  final bool isTeacher;

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

  String get _sessionPath =>
      '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}';

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
      final sessionResponse = await dio.get<Map<String, dynamic>>(_sessionPath);
      final session = sessionResponse.data;
      if (session == null) {
        throw const FormatException('El servidor devolvió una tutoría vacía.');
      }

      final results = await Future.wait([
        dio.get<List<dynamic>>('$_sessionPath/estudiantes'),
        dio.get<List<dynamic>>('$_sessionPath/chat'),
      ]);
      final students = (results[0].data ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final messages = (results[1].data ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
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

  bool get _isStudent => !widget.isTeacher;

  Color get _accentColor =>
      widget.isTeacher ? const Color(0xFF16834A) : const Color(0xFF1769AA);

  @override
  Widget build(BuildContext context) {
    final primary = _accentColor;

    return Theme(
      data: withRoleAccent(
        Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: primary,
            brightness: Theme.of(context).brightness,
          ).copyWith(primary: primary),
          scaffoldBackgroundColor: Neu.bg,
        ),
        primary,
      ),
      child: PaScaffold(
        title: 'Historial de tutoría grupal',
        subtitle: widget.subject,
        showLogo: false,
        actions: [
          NeuCircleButton(
            size: 40,
            icon: Icons.refresh_rounded,
            tooltip: 'Actualizar historial',
            onTap: _loading ? null : _loadHistory,
          ),
        ],
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            PaCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const NeuIconBox(Icons.error_outline_rounded,
                      color: Neu.error),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: neuBody(size: 13, color: Neu.muted),
                  ),
                  const SizedBox(height: 16),
                  NeuButton(
                    'Reintentar',
                    kind: NeuButtonKind.alt,
                    small: true,
                    icon: Icons.refresh_rounded,
                    expand: false,
                    onPressed: _loadHistory,
                  ),
                ],
              ),
            )
          else ...[
            _sessionHeaderCard(primary),
            const SizedBox(height: 14),
            _attendanceCard(primary),
            if (!widget.isTeacher) ...[
              const SizedBox(height: 14),
              _ratingDisplayCard(primary),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Registro del chat',
                style: neuPoppins(
                  size: 17,
                  weight: FontWeight.w700,
                  color: Neu.heading,
                ),
              ),
            ),
            if (_messages.isEmpty)
              PaCard(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No hay mensajes registrados.',
                    style: neuBody(size: 13, color: Neu.muted),
                  ),
                ),
              )
            else
              for (final message in _messages) ...[
                _messageCard(message, primary),
                const SizedBox(height: 10),
              ],
          ],
        ],
      ),
    );
  }

  Widget _sessionHeaderCard(Color primary) {
    final state = _session?['estadoClase']?.toString().toUpperCase();
    final (statusLabel, statusTone) = switch (state) {
      'FINALIZADA' => ('Finalizada', PaTone.ok),
      'EN_CURSO' => ('En curso', PaTone.warn),
      'PROGRAMADA' => ('Programada', PaTone.neutral),
      final val when val != null && val.isNotEmpty => (val, PaTone.neutral),
      _ => ('Estado no disponible', PaTone.quiet),
    };

    return PaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeuIconBox(
                Icons.menu_book_rounded,
                color: primary,
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subject,
                      style: neuPoppins(
                        size: 16,
                        weight: FontWeight.w700,
                        color: Neu.heading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tutoría colectiva',
                      style: neuBody(size: 12.5, color: Neu.muted),
                    ),
                  ],
                ),
              ),
              PaTag(statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Neu.line),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 16, color: Neu.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Inicio: ${_dateLabel(_session?['fechaInicio'])}',
                  style: neuBody(size: 12.5, color: Neu.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 16, color: Neu.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Finalización: ${_dateLabel(_session?['fechaFin'])}',
                  style: neuBody(size: 12.5, color: Neu.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attendanceCard(Color primary) {
    final attendance = (_session?['asistencias'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];

    if (_isStudent) {
      final attendanceRecord = attendance.firstWhere(
        (item) => item['asistio'] != null,
        orElse: () => const <String, dynamic>{},
      );
      final studentAttended = _session?['asistio'] as bool? ??
          attendanceRecord['asistio'] as bool?;
      final enteredLate = attendanceRecord['estado'] == 'ENTRO_TARDE' ||
          _session?['estadoAsistencia'] == 'ENTRO_TARDE';
      final lateMinutes = (attendanceRecord['minutosTarde'] ??
              _session?['minutosTarde']) as num?;

      return PaCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NeuIconBox(
                  Icons.fact_check_outlined,
                  color: primary,
                  size: 40,
                  iconSize: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tu asistencia',
                    style: neuPoppins(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Neu.heading,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  studentAttended == true
                      ? Icons.check_circle_rounded
                      : studentAttended == false
                          ? Icons.cancel_rounded
                          : Icons.help_outline_rounded,
                  color: studentAttended == true
                      ? Neu.okFg
                      : studentAttended == false
                          ? Neu.errFg
                          : Neu.muted,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Registro de participación',
                    style: neuPoppins(
                      size: 14,
                      weight: FontWeight.w600,
                      color: Neu.heading,
                    ),
                  ),
                ),
                PaTag(
                  enteredLate
                      ? 'Entró tarde · ${lateMinutes?.toInt() ?? 0} min'
                      : studentAttended == true
                          ? 'Asistió'
                          : studentAttended == false
                              ? 'No asistió'
                              : 'Sin marcar',
                  tone: enteredLate
                      ? PaTone.neutral
                      : studentAttended == true
                          ? PaTone.ok
                          : studentAttended == false
                              ? PaTone.error
                              : PaTone.neutral,
                ),
              ],
            ),
          ],
        ),
      );
    }

    final names = {
      for (final student in _students)
        if (student['id'] is String)
          student['id'] as String:
              student['nombre']?.toString() ?? student['id'] as String,
    };
    final attendanceByStudent = {
      for (final item in attendance)
        if (item['estudianteId'] is String)
          item['estudianteId'] as String: item,
    };
    final studentIds = _session?['estudianteIds'] is List
        ? (_session!['estudianteIds'] as List).whereType<String>().toList()
        : names.keys.toList();

    return PaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconBox(
                Icons.fact_check_outlined,
                color: primary,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Asistencia registrada',
                  style: neuPoppins(
                    size: 15,
                    weight: FontWeight.w700,
                    color: Neu.heading,
                  ),
                ),
              ),
              PaTag(
                '${studentIds.length} ${studentIds.length == 1 ? 'estudiante' : 'estudiantes'}',
                tone: PaTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (studentIds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No hay estudiantes registrados en esta tutoría.',
                style: neuBody(size: 13, color: Neu.muted),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: studentIds.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 14, color: Neu.line),
              itemBuilder: (context, index) {
                final id = studentIds[index];
                final record = attendanceByStudent[id] ?? const <String, dynamic>{};
                final isAttended = record['asistio'] as bool?;
                final enteredLate = record['estado'] == 'ENTRO_TARDE';
                final lateMinutes = record['minutosTarde'] as num?;
                return Row(
                  children: [
                    Icon(
                      isAttended == true
                          ? Icons.check_circle_rounded
                          : isAttended == false
                              ? Icons.cancel_rounded
                              : Icons.help_outline_rounded,
                      color: isAttended == true
                          ? Neu.okFg
                          : isAttended == false
                              ? Neu.errFg
                              : Neu.muted,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        names[id] ?? id,
                        style: neuBody(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: Neu.heading,
                        ),
                      ),
                    ),
                    PaTag(
                      enteredLate
                          ? 'Entró tarde · ${lateMinutes?.toInt() ?? 0} min'
                          : isAttended == true
                              ? 'Asistió'
                              : isAttended == false
                                  ? 'No asistió'
                                  : 'Sin marcar',
                      tone: enteredLate
                          ? PaTone.neutral
                          : isAttended == true
                              ? PaTone.ok
                              : isAttended == false
                                  ? PaTone.error
                                  : PaTone.neutral,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _ratingDisplayCard(Color primary) {
    final ratings = (_session?['valoraciones'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];

    final int stars;
    final String comment;
    final bool hasRating;

    if (ratings.isNotEmpty) {
      final first = ratings.first;
      stars = (first['estrellas'] as num?)?.toInt() ?? 0;
      comment = first['comentario']?.toString() ?? '';
      hasRating = stars > 0;
    } else {
      stars = 0;
      comment = '';
      hasRating = false;
    }

    return PaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconBox(
                Icons.star_rounded,
                color: Colors.amber.shade700,
                size: 40,
                iconSize: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isStudent
                      ? 'Tu valoración de la tutoría'
                      : 'Valoración recibida',
                  style: neuPoppins(
                    size: 15,
                    weight: FontWeight.w700,
                    color: Neu.heading,
                  ),
                ),
              ),
              if (hasRating)
                PaTag(
                  '$stars / 5',
                  tone: stars >= 4 ? PaTone.ok : PaTone.warn,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasRating)
            Text(
              'Aún no se ha registrado valoración para esta tutoría.',
              style: neuBody(size: 13, color: Neu.muted),
            )
          else ...[
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= stars ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber.shade600,
                    size: 24,
                  ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Neu.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Neu.line, width: 0.8),
                ),
                child: Text(
                  comment,
                  style: neuBody(size: 13, color: Neu.text, height: 1.35),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _messageCard(Map<String, dynamic> message, Color primary) {
    final senderName = message['nombre']?.toString() ??
        message['emisorId']?.toString() ??
        'Participante';
    final text = message['texto']?.toString() ?? '';
    final timeStr = _dateLabel(message['enviadoEn']);

    return PaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeuIconBox(
                Icons.person_rounded,
                color: primary,
                size: 28,
                iconSize: 15,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  senderName,
                  style: neuPoppins(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: Neu.heading,
                  ),
                ),
              ),
              Text(
                timeStr,
                style: neuBody(size: 11, color: Neu.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              text,
              style: neuBody(size: 13, color: Neu.text, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
