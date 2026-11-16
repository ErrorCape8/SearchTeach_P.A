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
  final Map<String, Map<String, dynamic>> _attendance = {};
  final Map<String, String> _studentNames = {};
  final Map<String, bool> _raisedHands = {};
  dynamic _listener;
  bool _connecting = true;
  bool _connected = false;
  bool _waitingForTeacher = false;
  bool _microphoneEnabled = true;
  bool _cameraEnabled = true;
  bool _screenShareEnabled = false;
  bool _handRaised = false;
  bool _showChat = false;
  bool _showPeople = false;
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
    _showPeople = widget.teacherMode;
    _showChat = widget.ended || widget.studentMode || widget.teacherMode;
    _loadChatHistory();
    _chatTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _loadChatHistory());
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
            '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}',
          );
      final list = response.data?['asistencias'];
      if (!mounted) return;
      if (list is! List) {
        setState(() => _attendanceError =
            'El servidor no devolvió la lista de asistencia.');
        return;
      }
      setState(() {
        _attendance.clear();
        for (final item in list.whereType<Map<String, dynamic>>()) {
          final id = item['estudianteId'];
          if (id is String) _attendance[id] = item;
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
            '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}',
          );
      if (response.data?['estadoClase'] != 'FINALIZADA' || !mounted) return;
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
              .map((message) {
                final identity = message['emisorId']?.toString() ?? '';
                final localIdentity = _room.localParticipant?.identity;
                final isLocal = localIdentity != null &&
                    identity == localIdentity;
                return _RoomMessage(
                  sender: isLocal
                      ? 'Tú'
                      : message['nombre']?.toString() ??
                          (identity.isEmpty ? 'Participante' : identity),
                  text: message['texto']?.toString() ?? '',
                  fromTeacher: isLocal
                      ? widget.teacherMode
                      : _isTeacherParticipant(identity),
                );
              }));
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
          if (decoded is! Map || !mounted) return;
          final identity = event.participant?.identity ?? '';
          if (decoded['type'] == 'hand' && decoded['raised'] is bool) {
            setState(() => _raisedHands[identity] = decoded['raised'] as bool);
            return;
          }
          if (decoded['text'] is String) {
            setState(() => _messages.add(_RoomMessage(
                  sender: _participantLabel(identity, event.participant?.name),
                  text: (decoded['text'] as String).trim(),
                  fromTeacher: _isTeacherParticipant(identity),
                )));
          }
        } on FormatException {
          // Ignore packets that are not SearchTeach chat messages.
        }
      });
      _listener.on<ParticipantConnectedEvent>((_) {
        if (mounted) setState(() {});
      });
      _listener.on<ParticipantDisconnectedEvent>((event) {
        if (mounted) {
          setState(() => _raisedHands.remove(event.participant.identity));
        }
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
              '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}/asistencia',
              data: {'estudianteId': identity, 'asistio': true},
            );
            await _loadAttendance();
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
          !widget.isProjectMeeting) {
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

  Future<void> _toggleScreenShare() async {
    final participant = _room.localParticipant;
    if (participant == null) return;
    final next = !_screenShareEnabled;
    try {
      await participant.setScreenShareEnabled(next);
      if (mounted) setState(() => _screenShareEnabled = next);
    } catch (_) {
      _showMediaError(
          'No se pudo compartir la pantalla. Revisa los permisos del navegador o dispositivo.');
    }
  }

  Future<void> _toggleHand() async {
    final participant = _room.localParticipant;
    if (participant == null) return;
    final next = !_handRaised;
    try {
      final payload = utf8.encode(jsonEncode({
        'type': 'hand',
        'raised': next,
      }));
      await participant.publishData(
        payload,
        reliable: true,
        topic: 'searchteach.hand',
      );
      if (!mounted) return;
      setState(() {
        _handRaised = next;
        _raisedHands[participant.identity] = next;
      });
    } catch (_) {
      _showMediaError('No se pudo actualizar el estado de la mano.');
    }
  }

  bool _isTeacherParticipant(String identity) {
    if (identity.isEmpty) return !widget.teacherMode;
    if (widget.students.contains(identity)) return false;
    final localIdentity = _room.localParticipant?.identity;
    if (identity == localIdentity) return widget.teacherMode;
    return true;
  }

  String _attendanceLabel(String studentId) {
    final attendance = _attendance[studentId];
    if (attendance == null) return 'Asistencia pendiente';
    if (attendance['estado'] == 'ENTRO_TARDE') {
      final minutes = attendance['minutosTarde'];
      return 'Entró tarde · ${minutes is num ? minutes.toInt() : 0} min';
    }
    if (attendance['asistio'] == true) return 'Asistió';
    if (attendance['asistio'] == false) return 'No asistió';
    return 'Asistencia pendiente';
  }

  Color _attendanceColor(String studentId) {
    final attendance = _attendance[studentId];
    if (attendance?['estado'] == 'ENTRO_TARDE') return Colors.amber;
    if (attendance?['asistio'] == true) return Neu.okFg;
    if (attendance?['asistio'] == false) return Neu.errFg;
    return Colors.white54;
  }

  void _showMediaError(String message) {
    if (mounted) setState(() => _mediaWarning = message);
  }

  Future<void> _sendMessage() async {
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
      setState(() => _messages.add(_RoomMessage(
          sender: 'Tú', text: text, fromTeacher: widget.teacherMode)));
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
    final index = widget.students.indexOf(studentId) + 1;
    return 'Estudiante $index';
  }

  Future<void> _finish(String reason) async {
    try {
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
          final screenShare = publication.source == TrackSource.screenShareVideo;
          yield _VideoTile(
            label: screenShare ? 'Tu pantalla' : 'Tú',
            track: screenShare || _cameraEnabled ? track : null,
          );
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
          final screenShare = publication.source == TrackSource.screenShareVideo;
          yield _VideoTile(
            label: screenShare
                ? 'Pantalla · ${_participantLabel(participant.identity, participant.name)}'
                : _participantLabel(participant.identity, participant.name),
            track: track,
          );
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
                      boxShadow: Neu.raise,
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
                      boxShadow: Neu.raise,
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
      backgroundColor: _sharedRoomBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF161922),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFF262B37), width: 1),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subject,
              style: neuPoppins(
                size: 16,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _roomAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_room.remoteParticipants.length + (_connected ? 1 : 0)} participantes',
                  style: neuBody(size: 11.5, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: _showChat ? 'Ocultar chat' : 'Mostrar chat',
              style: IconButton.styleFrom(
                backgroundColor:
                    _showChat ? _roomAccent.withOpacity(0.2) : Colors.transparent,
                foregroundColor: _showChat ? _roomAccent : Colors.white70,
              ),
              onPressed: () => setState(() => _showChat = !_showChat),
              icon: Icon(
                  _showChat ? Icons.chat_rounded : Icons.chat_outlined),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_mediaWarning != null)
            MaterialBanner(
              backgroundColor: const Color(0xFF3A2B18),
              content: Text(
                _mediaWarning!,
                style: const TextStyle(color: Colors.white),
              ),
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _mediaWarning = null),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      Expanded(flex: 4, child: _videoGallery()),
                      if (_showChat)
                        SizedBox(width: 320, child: _chatPanel()),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        flex: _showChat ? 3 : 1,
                        child: _videoGallery(),
                      ),
                      if (_showChat)
                        SizedBox(height: 220, child: _chatPanel()),
                    ],
                  ),
          ),
          _callControls(),
        ],
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
        decoration: const BoxDecoration(
          color: Color(0xFF161922),
          border: Border(
            left: BorderSide(color: Color(0xFF262B37), width: 1),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E222D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _chatTab(
                      'Chat (${_messages.length})',
                      !_showPeople,
                      () => setState(() => _showPeople = false),
                    ),
                    _chatTab(
                      'Participantes (${widget.students.length + 1})',
                      _showPeople,
                      () => setState(() => _showPeople = true),
                    ),
                    if (_showPeople && !widget.isProjectMeeting)
                      IconButton(
                        tooltip: 'Actualizar participantes',
                        visualDensity: VisualDensity.compact,
                        onPressed: _attendanceLoading ? null : _loadAttendance,
                        icon: _attendanceLoading
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh,
                                size: 18, color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ),
            if (_showPeople && !widget.isProjectMeeting && _attendanceLoading) ...[
              LinearProgressIndicator(
                minHeight: 2,
                color: _roomAccent,
                backgroundColor: Colors.white10,
              ),
              if (_attendanceSlow)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Conectando con el servidor; la primera carga puede tardar hasta un minuto.',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (_showPeople &&
                !widget.isProjectMeeting &&
                _attendanceError != null)
              Material(
                color: const Color(0xFF382315),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFFFA726), size: 17),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _attendanceError!,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white),
                        ),
                      ),
                      TextButton(
                        onPressed: _attendanceLoading ? null : _loadAttendance,
                        child: const Text('Reintentar',
                            style: TextStyle(color: Color(0xFFFFA726))),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 1, color: Color(0xFF262B37)),
            Expanded(
              child: _showPeople
                  ? ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        if (widget.students.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Aún no hay estudiantes inscritos.',
                              textAlign: TextAlign.center,
                              style: neuBody(size: 12, color: Colors.white54),
                            ),
                          ),
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: widget.teacherMode ? 16 : 13,
                            backgroundColor: _roomAccent.withOpacity(0.2),
                            child: Icon(
                              Icons.school_rounded,
                              size: widget.teacherMode ? 16 : 13,
                              color: _roomAccent,
                            ),
                          ),
                          title: Text(
                            widget.teacherMode ? 'Tú · Docente' : 'Tutor',
                            style: neuPoppins(
                              size: widget.teacherMode ? 13 : 11,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          trailing: _handRaised
                              ? const Icon(Icons.pan_tool_alt_rounded,
                                  color: Colors.amber, size: 19)
                              : null,
                        ),
                        for (final student in widget.students)
                          ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: widget.teacherMode ? 16 : 13,
                              backgroundColor: const Color(0xFF252A36),
                              child: Icon(
                                Icons.person_outline_rounded,
                                size: widget.teacherMode ? 16 : 13,
                                color: Colors.white70,
                              ),
                            ),
                            title: Text(
                              _studentNames[student] ?? _studentLabel(student),
                              style: neuPoppins(
                                size: widget.teacherMode ? 13 : 11,
                                weight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: !widget.isProjectMeeting
                                ? Text(
                                    _attendanceLabel(student),
                                    style: neuBody(
                                      size: widget.teacherMode ? 11 : 9,
                                      color: _attendanceColor(student),
                                    ),
                                  )
                                : null,
                            trailing: _raisedHands[student] == true
                                ? const Icon(Icons.pan_tool_alt_rounded,
                                    color: Colors.amber, size: 19)
                                : null,
                          ),
                      ],
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Text(
                            'Aún no hay mensajes.',
                            style: neuBody(
                              color: Colors.white54,
                              size: 13,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final accent = message.fromTeacher
                                ? _teacherRoomAccent
                                : _studentRoomAccent;
                            return Align(
                              alignment: message.fromTeacher
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 280),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment: message.fromTeacher
                                        ? CrossAxisAlignment.start
                                        : CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        message.sender,
                                        textAlign: message.fromTeacher
                                            ? TextAlign.left
                                            : TextAlign.right,
                                        style: neuPoppins(
                                          color: accent,
                                          size: 11,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(top: 3),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: accent.withOpacity(0.16),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: accent.withOpacity(0.42),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: SelectableText(
                                          message.text,
                                          style: neuBody(
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            if (_ended)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chat guardado de la sesión. Solo lectura.',
                    style: neuBody(
                      color: Colors.white54,
                      size: widget.teacherMode ? 11 : 9,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _message,
                        maxLength: 500,
                        onSubmitted: (_) => _sendMessage(),
                        style: neuBody(
                          size: widget.teacherMode ? 13 : 10,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Envía un mensaje…',
                          hintStyle: neuBody(
                            size: widget.teacherMode ? 13 : 10,
                            color: Colors.white38,
                          ),
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFF232733),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: Color(0xFF333847),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: Color(0xFF333847),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: _roomAccent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: _roomAccent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _sendMessage,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.send_rounded,
                            size: widget.teacherMode ? 18 : 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _chatTab(String label, bool selected, VoidCallback onTap) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  selected ? _roomAccent.withOpacity(0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: neuPoppins(
                color: selected ? _roomAccent : Colors.white60,
                size: widget.teacherMode ? 12 : 9,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
  Widget _callControls() => SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF161922),
            border: Border(
              top: BorderSide(color: Color(0xFF262B37), width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 10,
            children: [
              if (widget.modality.toUpperCase() != 'PRESENCIAL')
                _CallControl(
                    icon: _microphoneEnabled ? Icons.mic : Icons.mic_off,
                    label: _microphoneEnabled ? 'Silenciar' : 'Activar audio',
                    onPressed: _toggleMicrophone,
                    active: _microphoneEnabled),
              if (widget.modality.toUpperCase() != 'PRESENCIAL')
                _CallControl(
                    icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                    label: _cameraEnabled ? 'Apagar cámara' : 'Activar cámara',
                    onPressed: _toggleCamera,
                    active: _cameraEnabled),
              if (widget.teacherMode &&
                  widget.modality.toUpperCase() != 'PRESENCIAL')
                _CallControl(
                  icon: _screenShareEnabled
                      ? Icons.stop_screen_share_outlined
                      : Icons.screen_share_outlined,
                  label: _screenShareEnabled
                      ? 'Dejar de compartir'
                      : 'Compartir pantalla',
                  onPressed: _toggleScreenShare,
                  active: _screenShareEnabled,
                ),
              _CallControl(
                  icon: Icons.chat_outlined,
                  label: _showChat ? 'Cerrar chat' : 'Chat',
                  onPressed: () => setState(() => _showChat = !_showChat),
                  active: _showChat),
              _CallControl(
                  icon: Icons.people_outline,
                  label: 'Participantes',
                  onPressed: () => setState(() {
                        _showChat = true;
                        _showPeople = true;
                      }),
                  active: _showPeople),
              if (!widget.teacherMode)
                _CallControl(
                  icon: _handRaised
                      ? Icons.pan_tool_alt_rounded
                      : Icons.pan_tool_outlined,
                  label: _handRaised ? 'Bajar la mano' : 'Levantar la mano',
                  onPressed: _toggleHand,
                  active: _handRaised,
                ),
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
                  color: Colors.black.withValues(alpha: 0.65),
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

class _CallControl extends StatelessWidget {
  const _CallControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.active,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final background = danger
        ? const Color(0xFFDC3545)
        : active
            ? accent
            : const Color(0xFF262B36);

    return Tooltip(
      message: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: background,
            shape: const CircleBorder(),
            elevation: active || danger ? 2 : 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: 50,
                height: 50,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(label, style: neuBody(size: 11, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _RoomMessage {
  const _RoomMessage({
    required this.sender,
    required this.text,
    required this.fromTeacher,
  });
  final String sender;
  final String text;
  final bool fromTeacher;
}
