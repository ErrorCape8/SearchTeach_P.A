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
  static const _sharedRoomBackground = Neu.bg;
  static const _teacherRoomAccent = Color(0xFF16834A);
  static const _studentRoomAccent = Color(0xFF1769AA);

  final Room _room = Room();
  final TextEditingController _message = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<_RoomMessage> _messages = [];
  final Map<String, Map<String, dynamic>> _attendance = {};
  final Map<String, String> _studentNames = {};
  final Map<String, bool> _raisedHands = {};
  final Set<String> _attendanceSaving = {};
  dynamic _listener;
  bool _connecting = true;
  bool _connected = false;
  bool _waitingForTeacher = false;
  bool _microphoneEnabled = true;
  bool _cameraEnabled = true;
  bool _screenShareEnabled = false;
  bool _screenShareBusy = false;
  bool _handRaised = false;
  bool _showChat = false;
  bool _showAttendance = false;
  bool _sendingMessage = false;
  bool _finishing = false;
  bool _ended = false;
  bool _attendanceLoading = true;
  bool _attendanceSlow = false;
  String? _attendanceError;
  Timer? _attendanceSlowTimer;
  Timer? _endWarningTimer;
  Timer? _endTimer;
  Timer? _chatTimer;
  Timer? _roomStatusTimer;
  Timer? _waitingRoomTimer;
  String? _error;
  String? _mediaWarning;
  bool _studentExitInProgress = false;
  bool _studentSessionEndedConfirmed = false;

  Color get _roomAccent =>
      widget.teacherMode ? _teacherRoomAccent : _studentRoomAccent;

  @override
  void initState() {
    super.initState();
    _ended = widget.ended;
    _showAttendance = widget.teacherMode && !widget.ended;
    _showChat = widget.ended || widget.studentMode;
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
      final now = DateTime.now();
      if (endAt.isAfter(now)) {
        final warningDelay =
            endAt.subtract(const Duration(minutes: 2)).difference(now);
        _endWarningTimer = Timer(
          warningDelay.isNegative ? Duration.zero : warningDelay,
          () => _showEndWarning(late: warningDelay.isNegative),
        );
      }
      if (widget.teacherMode) {
        final delay = endAt.difference(now);
        _endTimer = Timer(
          delay.isNegative ? Duration.zero : delay,
          () => _finish('FINALIZACION_AUTOMATICA'),
        );
      }
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
      await _leaveStudentRoom(sessionEnded: true);
    } on DioException {
      // The server-side timer or LiveKit room deletion can still end the call.
    }
  }

  void _showEndWarning({required bool late}) {
    if (!mounted || _ended) return;
    final endAt = widget.endAt;
    if (endAt == null || !endAt.isAfter(DateTime.now())) return;
    RoleToast.show(
      context,
      message: late
          ? 'La clase está por finalizar.'
          : 'Faltan 2 minutos para finalizar la clase.',
      roleColor: _roomAccent,
    );
  }

  Future<void> _leaveStudentRoom({bool? sessionEnded}) async {
    if (!mounted) return;
    if (sessionEnded == true) _studentSessionEndedConfirmed = true;
    if (_studentExitInProgress) return;
    _studentExitInProgress = true;
    _roomStatusTimer?.cancel();

    var ended = _studentSessionEndedConfirmed;
    String? errorMessage;
    if (sessionEnded == null && !widget.isProjectMeeting) {
      try {
        final response = await ref.read(dioProvider).get<Map<String, dynamic>>(
              '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}',
            );
        _studentSessionEndedConfirmed = _studentSessionEndedConfirmed ||
            response.data?['estadoClase'] == 'FINALIZADA';
        ended = _studentSessionEndedConfirmed;
      } on DioException catch (error) {
        if (!_studentSessionEndedConfirmed) {
          final data = error.response?.data;
          errorMessage = data is Map && data['message'] is String
              ? data['message'] as String
              : 'No se pudo confirmar si la tutoría finalizó.';
        }
        ended = _studentSessionEndedConfirmed;
      }
    }

    if (!mounted) return;
    if (errorMessage != null) {
      RoleToast.showSnackBar(
        context,
        SnackBar(content: Text(errorMessage)),
      );
    }
    Navigator.of(context).pop(ended ? 'ended' : 'disconnected');
  }

  Future<void> _loadChatHistory() async {
    try {
      final path = widget.isProjectMeeting
          ? _projectChatPath
          : '/api/tutorias/grupales/${widget.sessionId}/chat';
      final response = await ref.read(dioProvider).get<List<dynamic>>(path);
      if (!mounted) return;
      var addedMessage = false;
      for (final message
          in (response.data ?? const []).whereType<Map<String, dynamic>>()) {
        final identity = message['usuarioId']?.toString() ??
            message['emisorId']?.toString() ??
            message['autorId']?.toString() ??
            '';
        final localIdentity = _room.localParticipant?.identity;
        final isLocal = localIdentity != null && identity == localIdentity;
        final text = message['texto']?.toString().trim() ?? '';
        if (text.isEmpty) continue;
        final sentAt = DateTime.tryParse(
              message['enviadoEn']?.toString() ??
                  message['sentAt']?.toString() ??
                  '',
            ) ??
            DateTime.now();
        final roomMessage = _RoomMessage(
          sender: isLocal
              ? 'Tú'
              : message['nombre']?.toString() ??
                  (identity.isEmpty ? 'Participante' : identity),
          senderId: identity,
          text: text,
          sentAt: sentAt,
          fromTeacher:
              isLocal ? widget.teacherMode : _isTeacherParticipant(identity),
        );
        if (!_hasDuplicateMessage(roomMessage)) {
          _messages.add(roomMessage);
          addedMessage = true;
        }
      }
      if (addedMessage) {
        _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
        setState(() {});
        _scrollChatToLatest();
      }
    } on DioException catch (error) {
      if (mounted) {
        setState(() =>
            _mediaWarning = error.message ?? 'No se pudo cargar el chat.');
      }
    }
  }

  bool _hasDuplicateMessage(_RoomMessage message) => _messages.any((existing) {
        final sameSender = message.senderId.isNotEmpty
            ? existing.senderId == message.senderId
            : existing.sender == message.sender;
        return sameSender &&
            existing.text == message.text &&
            existing.sentAt.difference(message.sentAt).inSeconds.abs() <= 2;
      });

  void _appendMessage(_RoomMessage message) {
    if (_hasDuplicateMessage(message)) return;
    setState(() {
      _messages.add(message);
      _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    });
    _scrollChatToLatest();
  }

  void _scrollChatToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
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
        if (event.topic != 'searchteach.chat' &&
            event.topic != 'searchteach.hand') {
          return;
        }
        try {
          final decoded = jsonDecode(utf8.decode(event.data));
          if (decoded is! Map || !mounted) return;
          final identity = event.participant?.identity ?? '';
          if (event.topic == 'searchteach.hand' &&
              decoded['type'] == 'hand' &&
              decoded['raised'] is bool) {
            setState(() => _raisedHands[identity] = decoded['raised'] as bool);
            return;
          }
          if (event.topic == 'searchteach.chat' && decoded['text'] is String) {
            final text = (decoded['text'] as String).trim();
            if (text.isNotEmpty) {
              _appendMessage(_RoomMessage(
                sender: _participantLabel(identity, event.participant?.name),
                senderId: identity,
                text: text,
                sentAt: DateTime.tryParse(
                      decoded['sentAt']?.toString() ?? '',
                    ) ??
                    DateTime.now(),
                fromTeacher: _isTeacherParticipant(identity),
              ));
            }
          }
        } on FormatException {
          // Ignore packets that are not SearchTeach chat messages.
        }
      });
      _listener.on<LocalTrackPublishedEvent>((event) {
        if (event.publication.source == TrackSource.screenShareVideo &&
            mounted) {
          setState(() => _screenShareEnabled = true);
        }
      });
      _listener.on<LocalTrackUnpublishedEvent>((event) {
        if (event.publication.source == TrackSource.screenShareVideo &&
            mounted) {
          setState(() => _screenShareEnabled = false);
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
          unawaited(_leaveStudentRoom());
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
        await _leaveStudentRoom(sessionEnded: true);
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
    if (_screenShareBusy) return;
    if (participant == null) {
      _showMediaError('Conéctate a la sala antes de compartir pantalla.');
      return;
    }
    final next = !_screenShareEnabled;
    setState(() => _screenShareBusy = true);
    try {
      await participant.setScreenShareEnabled(
        next,
        screenShareCaptureOptions: const ScreenShareCaptureOptions(
          captureScreenAudio: false,
          maxFrameRate: 15,
          params: VideoParametersPresets.screenShareH1080FPS15,
        ),
      );
      if (mounted) {
        setState(() {
          _screenShareEnabled = next;
          _mediaWarning = null;
        });
      }
    } catch (error) {
      final details = error.toString().contains('not supported on mobile')
          ? 'La aplicación requiere un navegador o dispositivo de escritorio para compartir pantalla.'
          : 'Revisa los permisos del navegador y vuelve a intentarlo. ($error)';
      _showMediaError('No se pudo compartir la pantalla. $details');
    } finally {
      if (mounted) setState(() => _screenShareBusy = false);
    }
  }

  void _toggleRoomPanel({required bool attendance}) {
    final wide = MediaQuery.sizeOf(context).width >= 1180;
    setState(() {
      if (attendance) {
        _showAttendance = !_showAttendance;
        if (!wide && _showAttendance) _showChat = false;
      } else {
        _showChat = !_showChat;
        if (!wide && _showChat) _showAttendance = false;
      }
    });
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
    return Neu.muted;
  }

  void _showMediaError(String message) {
    if (mounted) setState(() => _mediaWarning = message);
  }

  Future<void> _sendMessage() async {
    final text = _message.text.trim();
    if (text.isEmpty || _ended || _sendingMessage) return;
    setState(() => _sendingMessage = true);
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
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _sendingMessage = false);
        RoleToast.showSnackBar(
          context,
          SnackBar(
            content: Text(error.message ?? 'No se pudo guardar el mensaje.'),
          ),
        );
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() => _sendingMessage = false);
        RoleToast.showSnackBar(
          context,
          SnackBar(content: Text('No se pudo enviar el mensaje: $error')),
        );
      }
      return;
    }

    if (!mounted) return;
    final sentAt = DateTime.now().toUtc();
    final identity = _room.localParticipant?.identity ?? '';
    _appendMessage(_RoomMessage(
      sender: 'Tú',
      senderId: identity,
      text: text,
      sentAt: sentAt,
      fromTeacher: widget.teacherMode,
    ));
    _message.clear();
    setState(() => _sendingMessage = false);

    if (_room.localParticipant != null) {
      try {
        final payload = utf8.encode(jsonEncode({
          'text': text,
          'sentAt': sentAt.toIso8601String(),
        }));
        await _room.localParticipant!
            .publishData(payload, reliable: true, topic: 'searchteach.chat');
      } catch (error) {
        _showMediaError(
            'El mensaje se guardó, pero no se pudo enviar en tiempo real. ($error)');
      }
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

  Future<void> _setAttendance(String studentId, bool attended) async {
    if (_attendanceSaving.contains(studentId) || widget.isProjectMeeting) {
      return;
    }
    setState(() => _attendanceSaving.add(studentId));
    try {
      final response = await ref.read(dioProvider).patch<List<dynamic>>(
        '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}/asistencia',
        data: {'estudianteId': studentId, 'asistio': attended},
      );
      if (!mounted) return;
      Map<String, dynamic>? updated;
      for (final item
          in (response.data ?? const []).whereType<Map<String, dynamic>>()) {
        if (item['estudianteId'] == studentId) {
          updated = item;
          break;
        }
      }
      setState(() {
        _attendance[studentId] = updated ??
            <String, dynamic>{
              ...?_attendance[studentId],
              'estudianteId': studentId,
              'asistio': attended,
            };
      });
    } on DioException catch (error) {
      if (mounted) {
        RoleToast.showSnackBar(
          context,
          SnackBar(
            content: Text(error.message ?? 'No se pudo guardar la asistencia.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        RoleToast.showSnackBar(
          context,
          SnackBar(
            content: Text('No se pudo guardar la asistencia: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _attendanceSaving.remove(studentId));
    }
  }

  Future<void> _finish(String reason) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await ref.read(dioProvider).patch(
          '/api/tutorias/grupales/${widget.sessionId}/finalizar',
          data: {'motivo': reason});
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _finishing = false);
        RoleToast.showSnackBar(
          context,
          SnackBar(
            content: Text(error.message ?? 'No se pudo finalizar la tutoría.'),
          ),
        );
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() => _finishing = false);
        RoleToast.showSnackBar(
          context,
          SnackBar(content: Text('No se pudo finalizar la tutoría: $error')),
        );
      }
      return;
    }

    String? disconnectError;
    try {
      await _room.disconnect();
    } catch (error) {
      disconnectError = error.toString();
    }
    if (mounted) {
      RoleToast.show(
        context,
        message: disconnectError == null
            ? 'Tutoría finalizada.'
            : 'Tutoría finalizada, pero hubo un error al cerrar la sala: $disconnectError',
        roleColor: _teacherRoomAccent,
      );
      Navigator.of(context).pop();
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
          final screenShare =
              publication.source == TrackSource.screenShareVideo;
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
          final screenShare =
              publication.source == TrackSource.screenShareVideo;
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
    _endWarningTimer?.cancel();
    _endTimer?.cancel();
    _chatTimer?.cancel();
    _roomStatusTimer?.cancel();
    _waitingRoomTimer?.cancel();
    _message.dispose();
    _chatScrollController.dispose();
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
    final wide = MediaQuery.sizeOf(context).width >= 1180;
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
        backgroundColor: Neu.bg,
        foregroundColor: Neu.heading,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
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
                  style: neuBody(size: 11.5, color: Neu.muted),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_mediaWarning != null)
            MaterialBanner(
              backgroundColor: const Color(0xFFFFF4E5),
              content: Text(
                _mediaWarning!,
                style: neuBody(color: Neu.heading, size: 12),
              ),
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFB45309),
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
                      if (_showChat) SizedBox(width: 320, child: _chatPanel()),
                      if (_showAttendance)
                        SizedBox(width: 320, child: _attendancePanel()),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: _videoGallery()),
                      if (_showAttendance)
                        SizedBox(height: 220, child: _attendancePanel())
                      else if (_showChat)
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
        width: 320,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: Neu.raise,
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
                    tooltip: 'Cerrar chat',
                    onPressed: () => setState(() => _showChat = false),
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: Neu.muted),
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
                      controller: _chatScrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final accent = message.fromTeacher
                            ? _teacherRoomAccent
                            : _studentRoomAccent;
                        final isLocal = message.sender == 'Tú';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Align(
                            alignment: isLocal
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: Column(
                                crossAxisAlignment: isLocal
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.sender,
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
                                      color: isLocal
                                          ? accent.withValues(alpha: 0.12)
                                          : const Color(0xFFF1F4F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isLocal
                                            ? accent.withValues(alpha: 0.3)
                                            : const Color(0xFFE2E8F0),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: SelectableText(
                                      message.text,
                                      style: neuBody(
                                          size: 12.5, color: Neu.heading),
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
                    style: neuBody(color: Neu.muted, size: 11),
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
                        enabled: !_sendingMessage,
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
                      icon: _sendingMessage
                          ? Icons.hourglass_top_rounded
                          : Icons.send_rounded,
                      tooltip: 'Enviar mensaje',
                      onTap: _sendingMessage ? null : _sendMessage,
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
          boxShadow: Neu.raise,
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
                  Expanded(
                    child: Text(
                      widget.teacherMode
                          ? 'Asistencia (${widget.students.length})'
                          : 'Participantes (${widget.students.length + 1})',
                      style: neuPoppins(
                          size: 14,
                          weight: FontWeight.w700,
                          color: Neu.heading),
                    ),
                  ),
                  if (!widget.isProjectMeeting)
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
                    tooltip: 'Cerrar',
                    onPressed: () => setState(() => _showAttendance = false),
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: Neu.muted),
                  ),
                ],
              ),
            ),
            if (widget.teacherMode && !widget.isProjectMeeting)
              Container(
                width: double.infinity,
                color: _roomAccent.withValues(alpha: 0.08),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  'Presentes: ${_attendance.values.where((v) => v['asistio'] == true).length} · Ausentes: ${_attendance.values.where((v) => v['asistio'] == false).length}',
                  style: neuPoppins(
                    color: _roomAccent,
                    size: 11,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            if (!widget.isProjectMeeting && _attendanceLoading)
              const LinearProgressIndicator(minHeight: 2),
            if (!widget.isProjectMeeting && _attendanceSlow)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Text(
                  'Conectando con el servidor; la primera carga puede tardar hasta un minuto.',
                  style: neuBody(size: 11, color: Neu.muted),
                ),
              ),
            if (!widget.isProjectMeeting && _attendanceError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Neu.errFg, size: 17),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _attendanceError!,
                        style: neuBody(size: 11, color: Neu.errFg),
                      ),
                    ),
                    TextButton(
                      onPressed: _attendanceLoading ? null : _loadAttendance,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1, color: Neu.line),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (widget.students.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Aún no hay estudiantes inscritos.',
                        textAlign: TextAlign.center,
                        style: neuBody(size: 12, color: Neu.muted),
                      ),
                    ),
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: _roomAccent.withValues(alpha: 0.15),
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
                    trailing: _handRaised
                        ? const Icon(Icons.pan_tool_alt_rounded,
                            color: Colors.amber, size: 19)
                        : null,
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
                      subtitle: !widget.isProjectMeeting
                          ? Text(
                              _attendanceLabel(student),
                              style: neuBody(
                                size: 11,
                                color: _attendanceColor(student),
                              ),
                            )
                          : null,
                      trailing: widget.teacherMode && !widget.isProjectMeeting
                          ? _attendanceSaving.contains(student)
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Wrap(
                                  spacing: 2,
                                  children: [
                                    IconButton(
                                      tooltip: 'Marcar presente',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _attendanceLoading
                                          ? null
                                          : () => _setAttendance(student, true),
                                      icon: Icon(
                                        Icons.check_circle_rounded,
                                        color: _attendance[student]
                                                    ?['asistio'] ==
                                                true
                                            ? Neu.okFg
                                            : Colors.grey[400],
                                        size: 22,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Marcar ausente',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _attendanceLoading
                                          ? null
                                          : () =>
                                              _setAttendance(student, false),
                                      icon: Icon(
                                        Icons.cancel_rounded,
                                        color: _attendance[student]
                                                    ?['asistio'] ==
                                                false
                                            ? Neu.errFg
                                            : Colors.grey[400],
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                )
                          : _raisedHands[student] == true
                              ? const Icon(Icons.pan_tool_alt_rounded,
                                  color: Colors.amber, size: 19)
                              : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
  Widget _callControls() => SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
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
                  active: _microphoneEnabled,
                  accent: _roomAccent,
                ),
              if (widget.modality.toUpperCase() != 'PRESENCIAL')
                _CallControl(
                  icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                  label: _cameraEnabled ? 'Apagar cámara' : 'Activar cámara',
                  onPressed: _toggleCamera,
                  active: _cameraEnabled,
                  accent: _roomAccent,
                ),
              if (widget.teacherMode &&
                  widget.modality.toUpperCase() != 'PRESENCIAL')
                _CallControl(
                  icon: _screenShareEnabled
                      ? Icons.stop_screen_share_outlined
                      : Icons.screen_share_outlined,
                  label: _screenShareBusy
                      ? 'Procesando…'
                      : _screenShareEnabled
                          ? 'Dejar de compartir'
                          : 'Compartir pantalla',
                  onPressed: _screenShareBusy ? null : _toggleScreenShare,
                  active: _screenShareEnabled,
                  accent: _roomAccent,
                ),
              _CallControl(
                  icon: Icons.chat_outlined,
                  label: _showChat ? 'Cerrar chat' : 'Chat',
                  onPressed: () => _toggleRoomPanel(attendance: false),
                  active: _showChat,
                  accent: _roomAccent),
              _CallControl(
                icon: Icons.people_outline,
                label: _showAttendance
                    ? (widget.teacherMode && !widget.isProjectMeeting
                        ? 'Cerrar asistencia'
                        : 'Cerrar participantes')
                    : (widget.teacherMode && !widget.isProjectMeeting
                        ? 'Asistencia'
                        : 'Participantes'),
                onPressed: () => _toggleRoomPanel(attendance: true),
                active: _showAttendance,
                accent: _roomAccent,
              ),
              if (!widget.teacherMode)
                _CallControl(
                  icon: _handRaised
                      ? Icons.pan_tool_alt_rounded
                      : Icons.pan_tool_outlined,
                  label: _handRaised ? 'Bajar la mano' : 'Levantar la mano',
                  onPressed: _toggleHand,
                  active: _handRaised,
                  accent: _roomAccent,
                ),
              if (widget.teacherMode && !widget.isProjectMeeting)
                _CallControl(
                  icon: _finishing
                      ? Icons.hourglass_top_rounded
                      : Icons.call_end_rounded,
                  label: _finishing ? 'Finalizando…' : 'Finalizar clase',
                  onPressed: _finishing ? null : _confirmFinish,
                  active: false,
                  danger: true,
                )
            ],
          ),
        ),
      );

  Future<void> _confirmFinish() async {
    if (_finishing) return;
    final reasons = <(String, String)>[
      ('FINALIZADA', 'Temas concluidos'),
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
          title: const Text('Finalizar clase'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Selecciona por qué finalizas la clase:'),
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
          color: Neu.bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Neu.raise,
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
                    color: Neu.bg,
                    shape: BoxShape.circle,
                    boxShadow: Neu.raiseS,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label.isEmpty ? '?' : label.substring(0, 1).toUpperCase(),
                    style: neuPoppins(
                      color: Neu.muted,
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
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: Neu.raiseS,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_circle_outlined,
                      size: 14,
                      color: Neu.muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: neuBody(
                        size: 12,
                        weight: FontWeight.w600,
                        color: Neu.heading,
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
          color: Neu.bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Neu.raise,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Neu.bg,
                    shape: BoxShape.circle,
                    boxShadow: Neu.raiseS,
                  ),
                  child: Icon(
                    Icons.people_outline_rounded,
                    color: Neu.muted,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: neuBody(size: 13, color: Neu.muted),
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
    this.accent = Neu.heading,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;
  final Color accent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final iconColor = danger
        ? Neu.errFg
        : active
            ? accent
            : Neu.heading;

    return Tooltip(
      message: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NeuSurface(
            radius: 44,
            sunken: active,
            shadows: active ? const [] : Neu.raiseS,
            onTap: onPressed,
            child: SizedBox(
              width: 50,
              height: 50,
              child: Center(
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: neuBody(size: 11, color: danger ? Neu.errFg : Neu.muted),
          ),
        ],
      ),
    );
  }
}

class _RoomMessage {
  const _RoomMessage({
    required this.sender,
    this.senderId = '',
    required this.text,
    required this.sentAt,
    required this.fromTeacher,
  });
  final String sender;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool fromTeacher;
}
