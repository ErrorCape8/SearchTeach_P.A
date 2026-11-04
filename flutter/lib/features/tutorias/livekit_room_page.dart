import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../core/api_client.dart';
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
  final Room _room = Room();
  final TextEditingController _message = TextEditingController();
  final List<_RoomMessage> _messages = [];
  final Map<String, bool?> _attendance = {};
  final Map<String, String> _studentNames = {};
  dynamic _listener;
  bool _connecting = true;
  bool _connected = false;
  bool _microphoneEnabled = true;
  bool _cameraEnabled = true;
  bool _showChat = false;
  bool _showPeople = false;
  bool _ended = false;
  Timer? _endTimer;
  Timer? _chatTimer;
  Timer? _roomStatusTimer;
  String? _error;
  String? _mediaWarning;

  @override
  void initState() {
    super.initState();
    _ended = widget.ended;
    _showPeople = widget.teacherMode;
    _showChat = widget.isIndividualTutoring
        ? widget.teacherMode
        : widget.ended || widget.studentMode || widget.teacherMode;
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
          setState(() {
            _ended = true;
            _showChat = true;
          });
          unawaited(Future.wait(
              [_loadChatHistory(), _loadAttendance(), _loadStudentNames()]));
          _room.disconnect();
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
    try {
      final response = await ref.read(dioProvider).get<Map<String, dynamic>>(
            widget.isIndividualTutoring
                ? '/api/tutorias/${Uri.encodeComponent(widget.sessionId)}'
                : '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}',
          );
      if (widget.isIndividualTutoring) {
        final studentId = response.data?['estudianteId'];
        final attended = response.data?['asistio'];
        if (!mounted || studentId is! String || attended is! bool) return;
        setState(() => _attendance[studentId] = attended);
        return;
      }
      final list = response.data?['asistencias'];
      if (!mounted || list is! List) return;
      setState(() {
        for (final item in list.whereType<Map<String, dynamic>>()) {
          final id = item['estudianteId'];
          if (id is String) _attendance[id] = item['asistio'] as bool?;
        }
      });
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _mediaWarning =
            error.message ?? 'No se pudo cargar la asistencia.');
      }
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
      setState(() {
        _ended = true;
        _showChat = true;
        _connected = false;
      });
      await _room.disconnect();
      await Future.wait(
          [_loadChatHistory(), _loadAttendance(), _loadStudentNames()]);
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
        setState(() {
          _connected = false;
          _connecting = false;
          _ended = true;
          _showChat = true;
        });
        if (!widget.isProjectMeeting) {
          unawaited(Future.wait(
              [_loadChatHistory(), _loadAttendance(), _loadStudentNames()]));
        }
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
      if (mounted)
        setState(() {
          _connected = true;
          _connecting = false;
        });
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
      if (mounted)
        setState(
            () => _mediaWarning = warnings.isEmpty ? null : warnings.join(' '));
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'No se pudo conectar con la sala.';
      if (mounted)
        setState(() {
          _error = message;
          _connecting = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = 'No se pudo iniciar la videollamada: $error';
          _connecting = false;
        });
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
      if (mounted)
        setState(() {
          _cameraEnabled = next;
          _mediaWarning = null;
        });
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.message ?? 'No se pudo guardar el mensaje.')));
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(error.message ?? 'No se pudo guardar la asistencia.')));
    }
  }

  Future<void> _finish(String reason) async {
    try {
      if (widget.isIndividualTutoring) {
        final studentId = widget.students.isEmpty ? '' : widget.students.first;
        await ref.read(dioProvider).patch(
          '/api/tutorias/${Uri.encodeComponent(widget.sessionId)}/finalizar',
          data: {'asistio': _attendance[studentId] ?? false},
        );
        if (mounted) {
          setState(() {
            _ended = true;
            _showChat = false;
          });
        }
        await _room.disconnect();
        return;
      }
      await ref.read(dioProvider).patch(
          '/api/tutorias/grupales/${widget.sessionId}/finalizar',
          data: {'motivo': reason});
      if (mounted) {
        setState(() {
          _ended = true;
          _showChat = true;
        });
        await Future.wait(
            [_loadChatHistory(), _loadAttendance(), _loadStudentNames()]);
      }
      await _room.disconnect();
    } on DioException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(error.message ?? 'No se pudo finalizar la tutoría.')));
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
      if (!participantHasVideo)
        yield _VideoTile(
            label: _participantLabel(participant.identity, participant.name),
            track: null);
    }
    if (_room.remoteParticipants.isEmpty) yield const _WaitingParticipantTile();
  }

  @override
  void dispose() {
    _endTimer?.cancel();
    _chatTimer?.cancel();
    _roomStatusTimer?.cancel();
    _message.dispose();
    unawaited(_closeRoom());
    super.dispose();
  }

  Future<void> _closeRoom() async {
    await _listener?.dispose();
    await _room.disconnect();
    await _room.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (_ended) {
      return _withRoleNavigation(
        Scaffold(
          backgroundColor: const Color(0xFF1E2024),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E2024),
            foregroundColor: Colors.white,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.subject),
                Text(
                  widget.isProjectMeeting
                      ? 'Reunión de proyecto finalizada'
                      : 'Historial de tutoría',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          Expanded(child: _endedGallery()),
                          if (!widget.isIndividualTutoring ||
                              widget.teacherMode)
                            SizedBox(width: 290, child: _chatPanel()),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: _endedGallery()),
                          if (!widget.isIndividualTutoring ||
                              widget.teacherMode)
                            SizedBox(height: 230, child: _chatPanel()),
                        ],
                      ),
              ),
              _historyControls(),
            ],
          ),
        ),
        wide: wide,
      );
    }
    if (_connecting) {
      return _withRoleNavigation(
        Scaffold(
          backgroundColor: const Color(0xFF111318),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1C1F26),
            foregroundColor: Colors.white,
            title: Text(widget.subject),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        wide: wide,
      );
    }
    if (_error != null) {
      return _withRoleNavigation(
        Scaffold(
          backgroundColor: const Color(0xFF111318),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1C1F26),
            foregroundColor: Colors.white,
            title: Text(widget.subject),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        wide: wide,
      );
    }
    return _withRoleNavigation(
      Scaffold(
        backgroundColor: const Color(0xFF111318),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1C1F26),
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.subject,
                style: TextStyle(
                  fontSize: widget.teacherMode ? 18 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${_room.remoteParticipants.length + (_connected ? 1 : 0)} participantes',
                style: TextStyle(
                  fontSize: widget.teacherMode ? 12 : 9,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          actions: [
            if (!widget.isIndividualTutoring)
              IconButton(
                tooltip: _showChat ? 'Ocultar chat' : 'Mostrar chat',
                onPressed: () => setState(() => _showChat = !_showChat),
                icon: Icon(_showChat ? Icons.chat : Icons.chat_outlined),
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
                          SizedBox(width: 290, child: _chatPanel()),
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
      ),
      wide: wide,
    );
  }

  Widget _withRoleNavigation(Widget page, {required bool wide}) {
    if (widget.teacherMode && wide) {
      return Scaffold(
        body: Row(
          children: [
            _TeacherRoomSidebar(
              historyMode: _ended,
              onNavigate: (tab) {
                final callback = widget.onNavigateToDashboard;
                if (callback != null) {
                  callback(switch (tab) {
                    0 => 0,
                    1 => 1,
                    _ => 3,
                  });
                } else {
                  Navigator.of(context).maybePop();
                }
              },
            ),
            Expanded(child: page),
          ],
        ),
      );
    }
    if (!widget.studentMode || !wide) return page;
    return Scaffold(
      body: Row(
        children: [
          _StudentRoomSidebar(
            studentName: widget.studentName,
            historyMode: _ended,
            onNavigate: () => Navigator.of(context).maybePop(),
          ),
          Expanded(child: page),
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

  Widget _endedGallery() => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 560 ? 2 : 1;
          return GridView.count(
            padding: const EdgeInsets.all(8),
            crossAxisCount: columns,
            childAspectRatio: columns == 1 ? 1.6 : 1.45,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              _VideoTile(label: 'Tutor', track: null),
              for (final student in widget.students)
                _VideoTile(
                  label: _studentNames[student] ?? _studentLabel(student),
                  track: null,
                ),
            ],
          );
        },
      );

  Widget _chatPanel() => Container(
        color: Colors.white,
        child: Column(
          children: [
            Row(
              children: [
                if (!widget.isIndividualTutoring)
                  _chatTab(
                    'Chat (${_messages.length})',
                    !_showPeople,
                    () => setState(() => _showPeople = false),
                  ),
                _chatTab(
                  widget.isIndividualTutoring
                      ? 'Asistencia'
                      : 'Personas (${widget.students.length + 1})',
                  _showPeople,
                  () => setState(() => _showPeople = true),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: _showPeople
                  ? ListView(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      children: [
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: widget.teacherMode ? 18 : 13,
                            child: Icon(
                              Icons.person,
                              size: widget.teacherMode ? 18 : 14,
                            ),
                          ),
                          title: Text(
                            widget.teacherMode ? 'Tú · Docente' : 'Tutor',
                            style: TextStyle(
                              fontSize: widget.teacherMode ? 13 : 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        for (final student in widget.students)
                          ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: widget.teacherMode ? 18 : 13,
                              backgroundColor: const Color(0xFFE6EEFF),
                              child: Icon(
                                Icons.person_outline,
                                size: widget.teacherMode ? 18 : 14,
                                color: const Color(0xFF0D4FC4),
                              ),
                            ),
                            title: Text(
                              _studentNames[student] ?? _studentLabel(student),
                              style: TextStyle(
                                fontSize: widget.teacherMode ? 13 : 10,
                              ),
                            ),
                            subtitle: widget.teacherMode || widget.ended
                                ? Text(
                                    _attendance[student] == true
                                        ? 'Asistió'
                                        : _attendance[student] == false
                                            ? 'No asistió'
                                            : widget.teacherMode && !_ended
                                                ? 'Asistencia pendiente'
                                                : 'Sin marcar',
                                    style: TextStyle(
                                      fontSize: widget.teacherMode ? 11 : 8,
                                      color: _attendance[student] == true
                                          ? const Color(0xFF16834A)
                                          : null,
                                    ),
                                  )
                                : null,
                            trailing: widget.teacherMode &&
                                    !_ended &&
                                    !widget.isProjectMeeting
                                ? Wrap(
                                    spacing: 0,
                                    children: [
                                      IconButton(
                                        tooltip: 'Marcar presente',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            _setAttendance(student, true),
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                          color: Color(0xFF16834A),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Marcar ausente',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            _setAttendance(student, false),
                                        icon: const Icon(
                                          Icons.cancel_outlined,
                                          color: Color(0xFFB3261E),
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                      ],
                    )
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Aún no hay mensajes.',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.sender,
                                    style: TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: widget.teacherMode ? 11 : 7,
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF1F5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      message.text,
                                      style: TextStyle(
                                        fontSize: widget.teacherMode ? 13 : 9,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            if (_ended)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chat guardado de la sesión. Solo lectura.',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: widget.teacherMode ? 11 : 8,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(7),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _message,
                        maxLength: 500,
                        onSubmitted: (_) => _sendMessage(),
                        style: TextStyle(
                          fontSize: widget.teacherMode ? 13 : 9,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Envía un mensaje',
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFFF0F2F6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filled(
                      onPressed: _sendMessage,
                      icon: Icon(
                        Icons.send,
                        size: widget.teacherMode ? 18 : 13,
                      ),
                      visualDensity: VisualDensity.compact,
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
          child: Container(
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color:
                      selected ? const Color(0xFF0D4FC4) : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? (widget.teacherMode
                        ? const Color(0xFF16834A)
                        : const Color(0xFF0D4FC4))
                    : Colors.blueGrey,
                fontSize: widget.teacherMode ? 12 : 8,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );

  Widget _historyControls() => SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          color: const Color(0xFF1C1F26),
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: [
              if (!widget.isIndividualTutoring)
                _CallControl(
                  icon: Icons.chat_outlined,
                  label: 'Chat',
                  onPressed: () {
                    setState(() {
                      _showChat = true;
                      _showPeople = false;
                    });
                  },
                  active: !_showPeople,
                ),
              _CallControl(
                icon: Icons.people_outline,
                label: widget.isIndividualTutoring ? 'Asistencia' : 'Personas',
                onPressed: () {
                  setState(() {
                    _showChat = true;
                    _showPeople = true;
                  });
                },
                active: _showPeople,
              ),
              _CallControl(
                icon: Icons.call_end,
                label: 'Salir',
                onPressed: () => Navigator.of(context).maybePop(),
                active: false,
                danger: true,
              ),
            ],
          ),
        ),
      );

  Widget _callControls() => SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          color: const Color(0xFF1C1F26),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
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
              if (!widget.isIndividualTutoring)
                _CallControl(
                    icon: Icons.chat_outlined,
                    label: _showChat ? 'Cerrar chat' : 'Chat',
                    onPressed: () => setState(() => _showChat = !_showChat),
                    active: _showChat),
              if (widget.teacherMode || !widget.isIndividualTutoring)
                _CallControl(
                    icon: Icons.people_outline,
                    label:
                        widget.isIndividualTutoring ? 'Asistencia' : 'Personas',
                    onPressed: () => setState(() {
                          _showChat = true;
                          _showPeople = true;
                        }),
                    active: _showPeople),
              if (widget.teacherMode && !widget.isProjectMeeting)
                _CallControl(
                    icon: Icons.call_end,
                    label: 'Finalizar tutoría',
                    onPressed: _confirmFinish,
                    active: false,
                    danger: true),
              _CallControl(
                  icon: Icons.call_end,
                  label: 'Salir',
                  onPressed: () => Navigator.of(context).maybePop(),
                  active: false,
                  danger: true),
            ],
          ),
        ),
      );

  Future<void> _confirmFinish() async {
    final reasons = <(String, String)>[
      ('FINALIZADA', 'Tutoría completada'),
      ('FALTA_ESTUDIANTES', 'Falta de estudiantes'),
      ('PROBLEMAS_EXTERNOS', 'Problema externo'),
      ('PROBLEMAS_INTERNET', 'Problema de internet'),
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar tutoría'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Selecciona el motivo de cierre:'),
            const SizedBox(height: 8),
            for (final option in reasons)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(option.$2),
                onTap: () => Navigator.pop(context, option.$1),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (reason != null && mounted) await _finish(reason);
  }
}

class _TeacherRoomSidebar extends StatelessWidget {
  const _TeacherRoomSidebar({
    required this.historyMode,
    required this.onNavigate,
  });

  final bool historyMode;
  final ValueChanged<int> onNavigate;

  static const _items = [
    (Icons.home_outlined, 'Inicio'),
    (Icons.calendar_month_outlined, 'Sesiones'),
    (Icons.school_outlined, 'Proyectos de aula'),
  ];

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF0E8A62),
        child: SizedBox(
          width: 196,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const BrandLogo(width: 34, height: 32),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'SearchTeach',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'DOCENTE',
                  style: TextStyle(
                    color: Color(0xFFD4EEE2),
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < _items.length; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  child: ListTile(
                    dense: true,
                    selected: index == 1,
                    selectedTileColor: Colors.white.withValues(alpha: .16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    leading: Icon(
                      _items[index].$1,
                      color: Colors.white,
                      size: 19,
                    ),
                    title: Text(
                      _items[index].$2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => onNavigate(index),
                  ),
                ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Divider(color: Color(0x55FFFFFF)),
              ),
              ListTile(
                leading: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person_outline,
                    color: Color(0xFF0E8A62),
                    size: 19,
                  ),
                ),
                title: const Text(
                  'Volver a sesiones',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => onNavigate(1),
              ),
              if (historyMode)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'Historial de tutoría',
                    style: TextStyle(color: Color(0xFFD4EEE2), fontSize: 10),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );
}

class _StudentRoomSidebar extends StatelessWidget {
  const _StudentRoomSidebar({
    required this.studentName,
    required this.historyMode,
    required this.onNavigate,
  });

  final String studentName;
  final bool historyMode;
  final VoidCallback onNavigate;

  static const _items = [
    (Icons.home_outlined, 'Inicio'),
    (Icons.desktop_windows_outlined, 'Tutores'),
    (Icons.check_box_outline_blank, 'Mis tutorías'),
    (Icons.history, 'Historial'),
    (Icons.groups_outlined, 'Proyectos de aula'),
  ];

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF0A3D91),
        child: SizedBox(
          width: 124,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  height: 74,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const BrandLogo(width: 104, height: 64),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'ESTUDIANTE',
                  style: TextStyle(
                    color: Color(0xFFB8C9E6),
                    fontSize: 7,
                    letterSpacing: .7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Divider(height: 1, color: Color(0x334A77C0)),
              ),
              const SizedBox(height: 5),
              for (var index = 0; index < _items.length; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: SizedBox(
                    height: 27,
                    child: Material(
                      color: (historyMode ? index == 3 : index == 2)
                          ? const Color(0xFF3B63AE)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      child: InkWell(
                        onTap: onNavigate,
                        borderRadius: BorderRadius.circular(7),
                        child: Row(
                          children: [
                            const SizedBox(width: 7),
                            Icon(
                              _items[index].$1,
                              size: 13,
                              color: Colors.white.withValues(alpha: .94),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                _items[index].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Divider(height: 1, color: Color(0x334A77C0)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: const Color(0xFF3B63AE),
                      child: Text(
                        studentName.isEmpty
                            ? 'E'
                            : studentName.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Volver',
                      onPressed: onNavigate,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 18,
                        height: 24,
                      ),
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.label, required this.track});
  final String label;
  final VideoTrack? track;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF292D35),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          if (track != null)
            VideoTrackRenderer(track!, fit: VideoViewFit.cover)
          else
            Center(
                child: CircleAvatar(
              radius: 38,
              backgroundColor: const Color(0xFF414751),
              child: Text(
                  label.isEmpty ? '?' : label.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 28)),
            )),
          Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.all(Radius.circular(8))),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(label,
                        style: const TextStyle(color: Colors.white))),
              )),
        ]),
      );
}

class _WaitingParticipantTile extends StatelessWidget {
  const _WaitingParticipantTile(
      {this.message = 'Esperando a que alguien se una…'});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF292D35),
        child: Center(
            child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.people_outline, color: Colors.white70, size: 38),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
          ]),
        )),
      );
}

class _CallControl extends StatelessWidget {
  const _CallControl(
      {required this.icon,
      required this.label,
      required this.onPressed,
      required this.active,
      this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconButton.filled(
            onPressed: onPressed,
            style: IconButton.styleFrom(
              backgroundColor: danger
                  ? const Color(0xFFB3261E)
                  : active
                      ? const Color(0xFF3C414B)
                      : const Color(0xFF292D35),
              foregroundColor: Colors.white,
              minimumSize: const Size(52, 52),
            ),
            icon: Icon(icon),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );
}

class _RoomMessage {
  const _RoomMessage({required this.sender, required this.text});
  final String sender;
  final String text;
}
