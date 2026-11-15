import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/role_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../core/api_client.dart';
import '../../core/neu/neu.dart';
import '../../core/widgets/brand_logo.dart';

class LiveKitRoomPage extends ConsumerStatefulWidget {
  const LiveKitRoomPage({
    required this.sessionId,
    required this.subject,
    this.modality = 'VIRTUAL',
    this.teacherMode = false,
    this.students = const [],
    this.ended = false,
    this.endAt,
    this.projectTutoringId,
    this.projectId,
    this.projectReportSessionId,
    this.studentMode = false,
    this.studentName = 'Estudiante',
    this.isIndividualTutoring = false,
    this.onNavigateToDashboard,
    super.key,
  });

  final String sessionId;
  final String subject;
  final String modality;
  final bool teacherMode;
  final List<String> students;
  final bool ended;
  final DateTime? endAt;
  final String? projectTutoringId;
  final String? projectId;
  final String? projectReportSessionId;
  final bool studentMode;
  final String studentName;
  final bool isIndividualTutoring;
  final ValueChanged<int>? onNavigateToDashboard;

  bool get isProjectMeeting =>
      projectTutoringId != null &&
      projectId != null &&
      projectReportSessionId != null;

  @override
  ConsumerState<LiveKitRoomPage> createState() => _LiveKitRoomPageState();
}

class _LiveKitRoomPageState extends ConsumerState<LiveKitRoomPage> {
  static const _sharedRoomBackground = Color(0xFF111318);
  static const _teacherRoomAccent = Color(0xFF16834A);
  static const _studentRoomAccent = Color(0xFF1769AA);

  final Room _room = Room();
  final TextEditingController _message = TextEditingController();
  final List<_RoomMessage> _messages = [];
  final Map<String, bool?> _attendance = {};
  final Map<String, String> _studentNames = {};
  dynamic _listener;
  bool _connecting = true;
  bool _connected = false;
  bool _waitingForTeacher = false;
  bool _microphoneEnabled = true;
  bool _cameraEnabled = true;
  bool _showChat = false;
  bool _showAttendance = false;
  bool _ended = false;
  bool _attendanceLoading = true;
  bool _attendanceSlow = false;
  String? _attendanceError;
  Timer? _attendanceSlowTimer;
  Timer? _endTimer;
  Timer? _chatTimer;
  Timer? _roomStatusTimer;
  Timer? _waitingRoomTimer;
  String? _error;
  String? _mediaWarning;

  Color get _roomAccent =>
      widget.teacherMode ? _teacherRoomAccent : _studentRoomAccent;

  @override
  void initState() {
    super.initState();
    _ended = widget.ended;
    _showAttendance = false;
    _showChat = false;
    if (!widget.isIndividualTutoring) {
      _loadChatHistory();
      _chatTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => _loadChatHistory());
    }
    if (!widget.isProjectMeeting) {
      _loadAttendance();
      _loadStudentNames();
      if (!widget.teacherMode && !widget.ended) {
        _roomStatusTimer = Timer.periodic(
          const Duration(seconds: 3),
          (_) => _checkIfSessionEnded(),
        );
      }
    }
    final endAt = widget.endAt;
    if (endAt != null && !widget.ended) {
      final delay = endAt.difference(DateTime.now());
      _endTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
        if (widget.teacherMode) {
          _finish('FINALIZACION_AUTOMATICA');
        } else if (mounted) {
          _room.disconnect();
          Navigator.of(context).pop('ended');
        }
      });
    }
    if (widget.ended || widget.modality.toUpperCase() == 'PRESENCIAL') {
      _connecting = false;
    } else {
      _connect();
    }
  }

  Future<void> _loadStudentNames() async {
    if (widget.isIndividualTutoring) return;
    try {
      final response = await ref.read(dioProvider).get<List<dynamic>>(
          '/api/tutorias/grupales/${widget.sessionId}/estudiantes');
      if (!mounted) return;
      setState(() {
        for (final item
            in (response.data ?? const []).whereType<Map<String, dynamic>>()) {
          final id = item['id'];
          final name = item['nombre'];
          if (id is String && name is String) _studentNames[id] = name;
        }
      });
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _mediaWarning =
            error.message ?? 'No se pudieron cargar los nombres.');
      }
    }
  }

  Future<void> _loadAttendance() async {
    _attendanceSlowTimer?.cancel();
    if (mounted) {
      setState(() {
        _attendanceLoading = true;
        _attendanceSlow = false;
        _attendanceError = null;
      });
      _attendanceSlowTimer = Timer(const Duration(seconds: 8), () {
        if (mounted && _attendanceLoading) {
          setState(() => _attendanceSlow = true);
        }
      });
    }
    try {
      final response = await ref.read(dioProvider).get<Map<String, dynamic>>(
            widget.isIndividualTutoring
                ? '/api/tutorias/${Uri.encodeComponent(widget.sessionId)}'
                : '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}',
          );
      if (widget.isIndividualTutoring) {
        final studentId = response.data?['estudianteId'];
        final attended = response.data?['asistio'];
        if (!mounted) return;
        if (studentId is! String || studentId.isEmpty) {
          setState(() => _attendanceError =
              'No se encontró el estudiante de esta tutoría.');
          return;
        }
        setState(() {
          if (attended is bool) _attendance[studentId] = attended;
        });
        return;
      }
      final list = response.data?['asistencias'];
      if (!mounted) return;
      if (list is! List) {
        setState(() => _attendanceError =
            'El servidor no devolvió la lista de asistencia.');
        return;
      }
      setState(() {
        for (final item in list.whereType<Map<String, dynamic>>()) {
          final id = item['estudianteId'];
          final attended = item['asistio'];
          if (id is String && attended is bool) {
            _attendance[id] = attended;
          }
        }
      });
    } on DioException catch (error) {
      if (mounted) {
        setState(() {
          _attendanceError = error.response?.data is Map<String, dynamic>
              ? ((error.response!.data as Map<String, dynamic>)['message']
                      ?.toString() ??
                  'No se pudo cargar la asistencia.')
              : error.message ?? 'No se pudo cargar la asistencia.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _attendanceError =
            'No se pudo interpretar la información de asistencia.');
      }
    } finally {
      _attendanceSlowTimer?.cancel();
      if (mounted) setState(() => _attendanceLoading = false);
    }
  }

  Future<void> _checkIfSessionEnded() async {
    if (_ended || widget.isProjectMeeting) return;
    try {
      final response = await ref.read(dioProvider).get<Map<String, dynamic>>(
            widget.isIndividualTutoring
                ? '/api/tutorias/${Uri.encodeComponent(widget.sessionId)}'
                : '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}',
          );
      final Object? sessionState;
      if (widget.isIndividualTutoring) {
        sessionState = response.data?['estado'];
      } else {
        sessionState = response.data?['estadoClase'];
      }
      final isFinished = widget.isIndividualTutoring
          ? sessionState == 'REALIZADA'
          : sessionState == 'FINALIZADA';
      if (!isFinished || !mounted) return;
      _roomStatusTimer?.cancel();
      await _room.disconnect();
      if (!widget.teacherMode && mounted) {
        Navigator.of(context).pop('ended');
      }
    } on DioException {
      // The server-side timer or LiveKit room deletion can still end the call.
    }
  }

  Future<void> _loadChatHistory() async {
    if (widget.isIndividualTutoring) return;
    try {
      final path = widget.isProjectMeeting
          ? _projectChatPath
          : '/api/tutorias/grupales/${widget.sessionId}/chat';
      final response = await ref.read(dioProvider).get<List<dynamic>>(path);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll((response.data ?? const [])
              .whereType<Map<String, dynamic>>()
              .map((message) => _RoomMessage(
                    sender: message['nombre']?.toString() ??
                        message['emisorId']?.toString() ??
                        'Participante',
                    text: message['texto']?.toString() ?? '',
                  )));
      });
    } on DioException catch (error) {
      if (mounted) {
        setState(() =>
            _mediaWarning = error.message ?? 'No se pudo cargar el chat.');
      }
    }
  }

  Future<void> _connect() async {
    try {
      final response = await ref.read(dioProvider).post<Map<String, dynamic>>(
            widget.isProjectMeeting
                ? '/api/tutorias-colectivas/${Uri.encodeComponent(widget.projectTutoringId!)}'
                    '/proyectos/${Uri.encodeComponent(widget.projectId!)}'
                    '/sesiones/${Uri.encodeComponent(widget.projectReportSessionId!)}/livekit-token'
                : widget.isIndividualTutoring
                    ? '/api/tutorias/${Uri.encodeComponent(widget.sessionId)}/livekit-token'
                    : '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}/livekit-token',
          );
      final credentials = response.data;
      if (credentials == null ||
          credentials['serverUrl'] is! String ||
          credentials['token'] is! String) {
        throw const FormatException(
            'El servidor no devolvió credenciales de LiveKit válidas.');
      }
      _listener = _room.createListener();
      _listener.on<DataReceivedEvent>((event) {
        try {
          final decoded = jsonDecode(utf8.decode(event.data));
          if (decoded is Map && decoded['text'] is String && mounted) {
            setState(() => _messages.add(_RoomMessage(
                  sender: _participantLabel(
                    event.participant?.identity ?? '',
                    event.participant?.name,
                  ),
                  text: (decoded['text'] as String).trim(),
                )));
          }
        } on FormatException {
          // Ignore packets that are not SearchTeach chat messages.
        }
      });
      _listener.on<ParticipantConnectedEvent>((_) {
        if (mounted) setState(() {});
      });
      _listener.on<ParticipantDisconnectedEvent>((_) {
        if (mounted) setState(() {});
      });
      _listener.on<RoomDisconnectedEvent>((_) {
        if (!mounted) return;
        if (!widget.teacherMode) {
          _roomStatusTimer?.cancel();
          Navigator.of(context).pop('ended');
          return;
        }
        setState(() {
          _connected = false;
          _connecting = false;
        });
      });
      _listener.on<TrackSubscribedEvent>((_) {
        if (mounted) setState(() {});
      });
      _listener.on<TrackUnsubscribedEvent>((_) {
        if (mounted) setState(() {});
      });
      await _room
          .connect(credentials['serverUrl'] as String,
              credentials['token'] as String)
          .timeout(const Duration(seconds: 30));
      if (mounted) {
        setState(() {
          _connected = true;
          _connecting = false;
        });
      }
      final warnings = <String>[];
      if (!widget.teacherMode && !widget.isProjectMeeting) {
        final identity = _room.localParticipant?.identity;
        if (identity != null && identity.isNotEmpty) {
          try {
            await ref.read(dioProvider).patch(
                  widget.isIndividualTutoring
                      ? '/api/tutorias/${Uri.encodeComponent(widget.sessionId)}/asistencia'
                      : '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}/asistencia',
                  data: widget.isIndividualTutoring
                      ? {'asistio': true}
                      : {'estudianteId': identity, 'asistio': true},
                );
            if (mounted) setState(() => _attendance[identity] = true);
          } on DioException {
            warnings.add(
                'La llamada está activa, pero no se pudo guardar tu asistencia.');
          }
        }
      }
      try {
        await _room.localParticipant?.setMicrophoneEnabled(true);
      } catch (_) {
        _microphoneEnabled = false;
        warnings.add(
            'No se pudo activar el micrófono. Revisa el permiso de audio.');
      }
      try {
        await _room.localParticipant?.setCameraEnabled(true);
      } catch (_) {
        _cameraEnabled = false;
        warnings.add(
            'No se pudo activar la cámara. Revisa los permisos del navegador o dispositivo.');
      }
      if (mounted) {
        setState(
            () => _mediaWarning = warnings.isEmpty ? null : warnings.join(' '));
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 409 &&
          widget.studentMode &&
          !widget.isProjectMeeting &&
          !widget.isIndividualTutoring) {
        await _enterWaitingRoom();
        return;
      }
      final data = error.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'No se pudo conectar con la sala.';
      if (mounted) {
        setState(() {
          _error = message;
          _connecting = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo iniciar la videollamada: $error';
          _connecting = false;
        });
      }
    }
  }

  Future<void> _enterWaitingRoom() async {
    try {
      await ref.read(dioProvider).post<void>(
            '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}/sala-espera',
          );
    } on DioException {
      // Mantiene la espera activa aunque falle el aviso puntual.
    }
    if (!mounted) return;
    setState(() {
      _waitingForTeacher = true;
      _connecting = false;
      _error = null;
    });
    _waitingRoomTimer?.cancel();
    _waitingRoomTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollTeacherStart(),
    );
  }

  Future<void> _pollTeacherStart() async {
    if (!_waitingForTeacher || !mounted) return;
    try {
      final response = await ref.read(dioProvider).get<Map<String, dynamic>>(
            '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}',
          );
      final state = response.data?['estadoClase']?.toString();
      if (!mounted) return;
      if (state == 'EN_CURSO') {
        _waitingRoomTimer?.cancel();
        setState(() {
          _waitingForTeacher = false;
          _connecting = true;
        });
        await _connect();
      } else if (state == 'FINALIZADA') {
        _waitingRoomTimer?.cancel();
        if (mounted) {
          Navigator.of(context).pop('ended');
        }
      }
    } on DioException {
      // Reintenta en el siguiente ciclo.
    }
  }

  Future<void> _toggleMicrophone() async {
    final next = !_microphoneEnabled;
    try {
      await _room.localParticipant?.setMicrophoneEnabled(next);
      if (mounted) setState(() => _microphoneEnabled = next);
    } catch (_) {
      _showMediaError(
          'No se pudo cambiar el micrófono. Verifica los permisos y que no esté en uso por otra aplicación.');
    }
  }

  Future<void> _toggleCamera() async {
    final next = !_cameraEnabled;
    try {
      await _room.localParticipant?.setCameraEnabled(next);
      if (mounted) {
        setState(() {
          _cameraEnabled = next;
          _mediaWarning = null;
        });
      }
    } catch (_) {
      _showMediaError(
          'No se pudo activar la cámara. Revisa los permisos del navegador o dispositivo.');
    }
  }

  void _showMediaError(String message) {
    if (mounted) setState(() => _mediaWarning = message);
  }

  Future<void> _sendMessage() async {
    if (widget.isIndividualTutoring) return;
    final text = _message.text.trim();
    if (text.isEmpty || _ended) return;
    try {
      if (widget.isProjectMeeting) {
        await ref.read(dioProvider).post(
              _projectChatPath,
              data: FormData.fromMap({'texto': text}),
            );
      } else {
        await ref.read(dioProvider).post(
            '/api/tutorias/grupales/${widget.sessionId}/chat',
            data: {'texto': text});
      }
      if (_room.localParticipant != null) {
        final payload = utf8.encode(jsonEncode({
          'text': text,
          'sentAt': DateTime.now().toUtc().toIso8601String()
        }));
        await _room.localParticipant!
            .publishData(payload, reliable: true, topic: 'searchteach.chat');
      }
    } on DioException catch (error) {
      if (mounted) {
        RoleToast.showSnackBar(
            context,
            SnackBar(
                content:
                    Text(error.message ?? 'No se pudo guardar el mensaje.')));
      }
      return;
    }
    if (mounted) {
      setState(() => _messages.add(_RoomMessage(sender: 'Tú', text: text)));
      _message.clear();
    }
  }

  String get _projectChatPath =>
      '/api/tutorias-colectivas/${Uri.encodeComponent(widget.projectTutoringId!)}'
      '/proyectos/${Uri.encodeComponent(widget.projectId!)}'
      '/sesiones/${Uri.encodeComponent(widget.projectReportSessionId!)}/mensajes';

  String _participantLabel(String identity, [String? liveKitName]) {
    final name = liveKitName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final knownName = _studentNames[identity]?.trim();
    if (knownName != null && knownName.isNotEmpty) return knownName;
    return identity.isEmpty ? 'Participante' : identity;
  }

  String _studentLabel(String studentId) {
    if (widget.isIndividualTutoring) {
      if (widget.studentMode) return widget.studentName;
      for (final participant in _room.remoteParticipants.values) {
        if (participant.identity == studentId) {
          return _participantLabel(studentId, participant.name);
        }
      }
      return 'Estudiante';
    }
    final index = widget.students.indexOf(studentId) + 1;
    return 'Estudiante $index';
  }

  Future<void> _setAttendance(String studentId, bool attended) async {
    try {
      await ref.read(dioProvider).patch(
            widget.isIndividualTutoring
                ? '/api/tutorias/${Uri.encodeComponent(widget.sessionId)}/asistencia'
                : '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}/asistencia',
            data: widget.isIndividualTutoring
                ? {'asistio': attended}
                : {'estudianteId': studentId, 'asistio': attended},
          );
      if (mounted) setState(() => _attendance[studentId] = attended);
    } on DioException catch (error) {
      if (mounted) {
        RoleToast.showSnackBar(
            context,
            SnackBar(
                content: Text(
                    error.message ?? 'No se pudo guardar la asistencia.')));
      }
    }
  }

  Future<void> _finish(String reason) async {
    try {
      if (widget.isIndividualTutoring) {
        final studentId = widget.students.isEmpty ? '' : widget.students.first;
        await ref.read(dioProvider).patch(
          '/api/tutorias/${Uri.encodeComponent(widget.sessionId)}/finalizar',
          data: {
            'asistio': _attendance[studentId] ?? false,
            'motivo': reason,
          },
        );
        await _room.disconnect();
        if (mounted) {
          RoleToast.show(context,
              message: 'Tutoría finalizada.', roleColor: _teacherRoomAccent);
          Navigator.of(context).pop();
        }
        return;
      }
      await ref.read(dioProvider).patch(
          '/api/tutorias/grupales/${widget.sessionId}/finalizar',
          data: {'motivo': reason});
      await _room.disconnect();
      if (mounted) {
        RoleToast.show(context,
            message: 'Tutoría finalizada.', roleColor: _teacherRoomAccent);
        Navigator.of(context).pop();
      }
    } on DioException catch (error) {
      if (mounted) {
        RoleToast.showSnackBar(
            context,
            SnackBar(
                content:
                    Text(error.message ?? 'No se pudo finalizar la tutoría.')));
      }
    }
  }

  Iterable<Widget> _videoTiles() sync* {
    final local = _room.localParticipant;
    var localHasVideo = false;
    if (local != null) {
      for (final publication in local.videoTrackPublications) {
        final track = publication.track;
        if (track != null) {
          localHasVideo = true;
          yield _VideoTile(label: 'Tú', track: _cameraEnabled ? track : null);
        }
      }
    }
    if (!localHasVideo) yield const _VideoTile(label: 'Tú', track: null);
    for (final participant in _room.remoteParticipants.values) {
      var participantHasVideo = false;
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (track != null) {
          participantHasVideo = true;
          yield _VideoTile(
              label: _participantLabel(participant.identity, participant.name),
              track: track);
        }
      }
      if (!participantHasVideo) {
        yield _VideoTile(
            label: _participantLabel(participant.identity, participant.name),
            track: null);
      }
    }
    if (_room.remoteParticipants.isEmpty) yield const _WaitingParticipantTile();
  }

  @override
  void dispose() {
    _attendanceSlowTimer?.cancel();
    _endTimer?.cancel();
    _chatTimer?.cancel();
    _roomStatusTimer?.cancel();
    _waitingRoomTimer?.cancel();
    _message.dispose();
    unawaited(_closeRoom());
    super.dispose();
  }

  Future<void> _closeRoom() async {
    await _listener?.dispose();
    await _room.disconnect();
    await _room.dispose();
  }

  Widget _buildRoomHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Neu.bg,
          boxShadow: [
            BoxShadow(
              color: Neu.shadowDark,
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(
              widget.teacherMode
                  ? 'assets/images/logo_docente.png'
                  : 'assets/images/logo_estudiante.png',
              width: 36,
              height: 36,
              errorBuilder: (_, __, ___) => BrandLogo(
                width: 36,
                height: 36,
                accentColor: _roomAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: neuPoppins(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Neu.heading,
                    ),
                  ),
                  Text(
                    '${_room.remoteParticipants.length + (_connected ? 1 : 0)} participantes · ${widget.modality}',
                    style: neuBody(size: 11, color: Neu.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (_ended) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop('ended');
      });
      return const Scaffold(
        backgroundColor: Neu.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_waitingForTeacher) {
      return Scaffold(
        backgroundColor: Neu.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildRoomHeader(),
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    constraints: const BoxConstraints(maxWidth: 440),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: Neu.raiseM,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          widget.teacherMode
                              ? 'assets/images/logo_docente.png'
                              : 'assets/images/logo_estudiante.png',
                          width: 48,
                          height: 48,
                          errorBuilder: (_, __, ___) => BrandLogo(
                            width: 48,
                            height: 48,
                            accentColor: _roomAccent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        CircularProgressIndicator(color: _roomAccent),
                        const SizedBox(height: 20),
                        Text(
                          'Estás en la sala de espera',
                          textAlign: TextAlign.center,
                          style: neuPoppins(
                            color: Neu.heading,
                            size: 18,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ya notificamos al docente. Entrarás automáticamente a la videollamada en cuanto inicie la tutoría.',
                          textAlign: TextAlign.center,
                          style: neuBody(color: Neu.muted, size: 13),
                        ),
                        const SizedBox(height: 24),
                        NeuButton(
                          'Salir de la espera',
                          icon: Icons.arrow_back_rounded,
                          accentColor: _roomAccent,
                          expand: false,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_connecting) {
      return Scaffold(
        backgroundColor: Neu.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildRoomHeader(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _roomAccent),
                      const SizedBox(height: 16),
                      Text(
                        'Conectando a la sala…',
                        style: neuBody(size: 14, color: Neu.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Neu.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildRoomHeader(),
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    constraints: const BoxConstraints(maxWidth: 440),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: Neu.raiseM,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Neu.errFg, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No se pudo conectar',
                          style: neuPoppins(
                            size: 17,
                            weight: FontWeight.w700,
                            color: Neu.heading,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: neuBody(color: Neu.muted, size: 13),
                        ),
                        const SizedBox(height: 24),
                        NeuButton(
                          'Volver',
                          icon: Icons.arrow_back_rounded,
                          accentColor: _roomAccent,
                          expand: false,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Neu.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildRoomHeader(),
            if (_mediaWarning != null)
              Container(
                color: const Color(0xFFFFF3CD),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _mediaWarning!,
                        style: const TextStyle(
                            color: Color(0xFF856404), fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _mediaWarning = null),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: _videoGallery()),
                        if (_showChat) _chatPanel(),
                        if (_showAttendance) _attendancePanel(),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: _videoGallery()),
                        if (_showChat)
                          SizedBox(height: 240, child: _chatPanel()),
                        if (_showAttendance)
                          SizedBox(height: 240, child: _attendancePanel()),
                      ],
                    ),
            ),
            _callControls(),
          ],
        ),
      ),
    );
  }

  Widget _videoGallery() => LayoutBuilder(builder: (context, constraints) {
        final tiles = widget.modality.toUpperCase() == 'PRESENCIAL'
            ? const <Widget>[
                _WaitingParticipantTile(message: 'Tutoría presencial')
              ]
            : _videoTiles().toList();
        final columns = constraints.maxWidth > 1000
            ? 3
            : constraints.maxWidth > 560
                ? 2
                : 1;
        return GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: columns,
          childAspectRatio: columns == 1 ? 1.5 : 1.25,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: tiles,
        );
      });

  Widget _chatPanel() => Container(
        width: 320,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: Neu.raiseM,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
              child: Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 18, color: _roomAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Chat (${_messages.length})',
                    style: neuPoppins(
                        size: 14, weight: FontWeight.w700, color: Neu.heading),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: Neu.muted),
                    tooltip: 'Cerrar chat',
                    onPressed: () => setState(() => _showChat = false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Neu.line),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Aún no hay mensajes.',
                        style: neuBody(color: Neu.muted, size: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.sender == 'Tú';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.sender,
                                  style: neuPoppins(
                                    color: _roomAccent,
                                    size: 11,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? _roomAccent.withOpacity(0.12)
                                        : const Color(0xFFF1F4F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isMe
                                          ? _roomAccent.withOpacity(0.3)
                                          : const Color(0xFFE2E8F0),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    message.text,
                                    style: neuBody(
                                        size: 12.5, color: Neu.heading),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      maxLength: 500,
                      onSubmitted: (_) => _sendMessage(),
                      style: neuBody(size: 12.5, color: Neu.heading),
                      decoration: InputDecoration(
                        hintText: 'Envía un mensaje…',
                        hintStyle: neuBody(size: 12.5, color: Neu.muted),
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFF1F4F9),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  NeuCircleButton(
                    size: 38,
                    icon: Icons.send_rounded,
                    tooltip: 'Enviar mensaje',
                    onTap: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _attendancePanel() => Container(
        width: 320,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: Neu.raiseM,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
              child: Row(
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 18, color: _roomAccent),
                  const SizedBox(width: 8),
                  Text(
                    widget.teacherMode
                        ? 'Asistencia (${widget.students.length})'
                        : 'Participantes (${widget.students.length + 1})',
                    style: neuPoppins(
                        size: 14, weight: FontWeight.w700, color: Neu.heading),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Actualizar asistencia',
                    visualDensity: VisualDensity.compact,
                    onPressed: _attendanceLoading ? null : _loadAttendance,
                    icon: _attendanceLoading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded,
                            size: 18, color: Neu.muted),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: Neu.muted),
                    tooltip: 'Cerrar asistencia',
                    onPressed: () => setState(() => _showAttendance = false),
                  ),
                ],
              ),
            ),
            if (widget.teacherMode)
              Container(
                width: double.infinity,
                color: _roomAccent.withOpacity(0.08),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  'Presentes: ${_attendance.values.where((v) => v == true).length} | Ausentes: ${_attendance.values.where((v) => v == false).length}',
                  style: neuPoppins(
                    color: _roomAccent,
                    size: 11,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            const Divider(height: 1, color: Neu.line),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: _roomAccent.withOpacity(0.15),
                      child: Icon(Icons.school_rounded,
                          size: 15, color: _roomAccent),
                    ),
                    title: Text(
                      widget.teacherMode ? 'Tú · Docente' : 'Tutor',
                      style: neuPoppins(
                          size: 12.5,
                          weight: FontWeight.w600,
                          color: Neu.heading),
                    ),
                  ),
                  for (final student in widget.students)
                    ListTile(
                      dense: true,
                      leading: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFE2E8F0),
                        child: Icon(Icons.person_outline_rounded,
                            size: 15, color: Neu.muted),
                      ),
                      title: Text(
                        _studentNames[student] ?? _studentLabel(student),
                        style: neuPoppins(
                            size: 12.5,
                            weight: FontWeight.w500,
                            color: Neu.heading),
                      ),
                      subtitle: widget.teacherMode
                          ? Text(
                              _attendance[student] == true
                                  ? 'Asistió'
                                  : _attendance[student] == false
                                      ? 'No asistió'
                                      : 'Sin registrar',
                              style: neuBody(
                                size: 11,
                                color: _attendance[student] == true
                                    ? Neu.okFg
                                    : _attendance[student] == false
                                        ? Neu.errFg
                                        : Neu.muted,
                              ),
                            )
                          : null,
                      trailing: widget.teacherMode && !widget.isProjectMeeting
                          ? Wrap(
                              spacing: 2,
                              children: [
                                IconButton(
                                  tooltip: 'Marcar presente',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _setAttendance(student, true),
                                  icon: Icon(
                                    Icons.check_circle_rounded,
                                    color: _attendance[student] == true
                                        ? Neu.okFg
                                        : Colors.grey[400],
                                    size: 22,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Marcar ausente',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _setAttendance(student, false),
                                  icon: Icon(
                                    Icons.cancel_rounded,
                                    color: _attendance[student] == false
                                        ? Neu.errFg
                                        : Colors.grey[400],
                                    size: 22,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _callControls() => Container(
        decoration: const BoxDecoration(
          color: Neu.bg,
          boxShadow: [
            BoxShadow(
              color: Neu.shadowDark,
              offset: Offset(0, -2),
              blurRadius: 8,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Tooltip(
                message: 'Salir de la clase',
                child: NeuSurface(
                  radius: 44,
                  shadows: Neu.raiseS,
                  padding: const EdgeInsets.all(12),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: Neu.muted,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.modality.toUpperCase() != 'PRESENCIAL') ...[
                    Tooltip(
                      message: _microphoneEnabled
                          ? 'Silenciar micrófono'
                          : 'Activar micrófono',
                      child: NeuSurface(
                        radius: 44,
                        sunken: !_microphoneEnabled,
                        shadows: _microphoneEnabled ? Neu.raiseS : const [],
                        padding: const EdgeInsets.all(12),
                        onTap: _toggleMicrophone,
                        child: Icon(
                          _microphoneEnabled
                              ? Icons.mic_rounded
                              : Icons.mic_off_rounded,
                          size: 20,
                          color: _microphoneEnabled ? Neu.heading : Neu.errFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Tooltip(
                      message: _cameraEnabled
                          ? 'Apagar cámara'
                          : 'Activar cámara',
                      child: NeuSurface(
                        radius: 44,
                        sunken: !_cameraEnabled,
                        shadows: _cameraEnabled ? Neu.raiseS : const [],
                        padding: const EdgeInsets.all(12),
                        onTap: _toggleCamera,
                        child: Icon(
                          _cameraEnabled
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                          size: 20,
                          color: _cameraEnabled ? Neu.heading : Neu.errFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (!widget.isIndividualTutoring) ...[
                    Tooltip(
                      message: _showChat ? 'Cerrar chat' : 'Abrir chat',
                      child: NeuSurface(
                        radius: 44,
                        sunken: _showChat,
                        shadows: _showChat ? const [] : Neu.raiseS,
                        padding: const EdgeInsets.all(12),
                        onTap: () => setState(() => _showChat = !_showChat),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 20,
                          color: _showChat ? _roomAccent : Neu.heading,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (widget.teacherMode || !widget.isIndividualTutoring)
                    Tooltip(
                      message: widget.teacherMode
                          ? (_showAttendance
                              ? 'Cerrar asistencia'
                              : 'Tomar asistencia')
                          : (_showAttendance
                              ? 'Cerrar participantes'
                              : 'Ver participantes'),
                      child: NeuSurface(
                        radius: 44,
                        sunken: _showAttendance,
                        shadows: _showAttendance ? const [] : Neu.raiseS,
                        padding: const EdgeInsets.all(12),
                        onTap: () => setState(
                            () => _showAttendance = !_showAttendance),
                        child: Icon(
                          Icons.people_outline_rounded,
                          size: 20,
                          color: _showAttendance ? _roomAccent : Neu.heading,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (widget.teacherMode && !widget.isProjectMeeting)
                Tooltip(
                  message: 'Finalizar clase',
                  child: Material(
                    color: const Color(0xFFFFECEC),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _confirmFinish,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.power_settings_new_rounded,
                          size: 20,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 44),
            ],
          ),
        ),
      );

  Future<void> _confirmFinish() async {
    final reasons = <(String, String)>[
      ('FINALIZADA', 'Tutoría completada'),
      ('FALTA_ESTUDIANTES', 'Falta de estudiantes'),
      ('PROBLEMAS_EXTERNOS', 'Problema técnico u otro'),
      ('PROBLEMAS_INTERNET', 'Error de conexión a internet'),
    ];
    String? selectedReason;
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refreshDialog) => AlertDialog(
          icon: Icon(Icons.call_end_rounded, color: _roomAccent),
          title: const Text('Finalizar tutoría'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Selecciona por qué finalizas la tutoría:'),
              ),
              const SizedBox(height: 8),
              for (final option in reasons)
                RadioListTile<String>(
                  value: option.$1,
                  groupValue: selectedReason,
                  activeColor: _roomAccent,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(option.$2),
                  onChanged: (value) =>
                      refreshDialog(() => selectedReason = value),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: selectedReason == null
                  ? null
                  : () => Navigator.pop(dialogContext, selectedReason),
              icon: const Icon(Icons.check),
              label: const Text('Confirmar y finalizar'),
            ),
          ],
        ),
      ),
    );
    if (reason != null && mounted) await _finish(reason);
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.label, required this.track});
  final String label;
  final VideoTrack? track;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B1E26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2C313E), width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (track != null)
              VideoTrackRenderer(track!, fit: VideoViewFit.cover)
            else
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2D3342), Color(0xFF1E232E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF3F4657),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label.isEmpty ? '?' : label.substring(0, 1).toUpperCase(),
                    style: neuPoppins(
                      color: Colors.white,
                      size: 26,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_circle_outlined,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: neuBody(
                        size: 12,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _WaitingParticipantTile extends StatelessWidget {
  const _WaitingParticipantTile(
      {this.message = 'Esperando a que alguien se una…'});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B1E26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2C313E), width: 1.2),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF252A36),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.people_outline_rounded,
                    color: Colors.white70,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: neuBody(size: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      );
}

class _RoomMessage {
  const _RoomMessage({required this.sender, required this.text});
  final String sender;
  final String text;
}
