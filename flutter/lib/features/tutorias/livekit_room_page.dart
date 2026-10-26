import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../core/api_client.dart';

class LiveKitRoomPage extends ConsumerStatefulWidget {
  const LiveKitRoomPage({required this.sessionId, required this.subject, this.modality = 'VIRTUAL', this.teacherMode = false, this.students = const [], this.ended = false, this.endAt, this.projectTutoringId, this.projectId, this.projectReportSessionId, super.key});

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

  bool get isProjectMeeting => projectTutoringId != null && projectId != null && projectReportSessionId != null;

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
  bool _ended = false;
  Timer? _endTimer;
  Timer? _chatTimer;
  String? _error;
  String? _mediaWarning;

  @override
  void initState() {
    super.initState();
    _ended = widget.ended;
    _loadChatHistory();
    _chatTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadChatHistory());
    if (!widget.isProjectMeeting) {
      _loadAttendance();
      _loadStudentNames();
    }
    final endAt = widget.endAt;
    if (endAt != null && !widget.ended) {
      final delay = endAt.difference(DateTime.now());
      _endTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
        if (widget.teacherMode) {
          _finish('FINALIZACION_AUTOMATICA');
        } else if (mounted) {
          setState(() => _ended = true);
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
    try {
      final response = await ref.read(dioProvider).get<List<dynamic>>('/api/tutorias/grupales/${widget.sessionId}/estudiantes');
      if (!mounted) return;
      setState(() {
        for (final item in (response.data ?? const []).whereType<Map<String, dynamic>>()) {
          final id = item['id'];
          final name = item['nombre'];
          if (id is String && name is String) _studentNames[id] = name;
        }
      });
    } on DioException { }
  }

  Future<void> _loadAttendance() async {
    try {
      final response = await ref.read(dioProvider).get<Map<String, dynamic>>('/api/tutorias/grupales/${widget.sessionId}');
      final list = response.data?['asistencias'];
      if (!mounted || list is! List) return;
      setState(() {
        for (final item in list.whereType<Map<String, dynamic>>()) {
          final id = item['estudianteId'];
          if (id is String) _attendance[id] = item['asistio'] as bool?;
        }
      });
    } on DioException { }
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
          ..addAll((response.data ?? const []).whereType<Map<String, dynamic>>().map((message) => _RoomMessage(
            sender: message['nombre']?.toString() ?? message['emisorId']?.toString() ?? 'Participante',
            text: message['texto']?.toString() ?? '',
          )));
      });
    } on DioException { }
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
      if (credentials == null || credentials['serverUrl'] is! String || credentials['token'] is! String) {
        throw const FormatException('El servidor no devolvió credenciales de LiveKit válidas.');
      }
      _listener = _room.createListener();
      _listener.on<DataReceivedEvent>((event) {
        try {
          final decoded = jsonDecode(utf8.decode(event.data));
          if (decoded is Map && decoded['text'] is String && mounted) {
            setState(() => _messages.add(_RoomMessage(
              sender: event.participant?.identity ?? 'Participante',
              text: (decoded['text'] as String).trim(),
            )));
          }
        } on FormatException {
          // Ignore packets that are not SearchTeach chat messages.
        }
      });
      _listener.on<ParticipantConnectedEvent>((_) { if (mounted) setState(() {}); });
      _listener.on<ParticipantDisconnectedEvent>((_) { if (mounted) setState(() {}); });
      _listener.on<TrackSubscribedEvent>((_) { if (mounted) setState(() {}); });
      _listener.on<TrackUnsubscribedEvent>((_) { if (mounted) setState(() {}); });
      await _room.connect(credentials['serverUrl'] as String, credentials['token'] as String);
      if (mounted) setState(() { _connected = true; _connecting = false; });
      final warnings = <String>[];
      try {
        await _room.localParticipant?.setMicrophoneEnabled(true);
      } catch (_) {
        _microphoneEnabled = false;
        warnings.add('No se pudo activar el micrófono. Revisa el permiso de audio.');
      }
      try {
        await _room.localParticipant?.setCameraEnabled(true);
      } catch (_) {
        _cameraEnabled = false;
        warnings.add('No se pudo activar la cámara. Revisa los permisos del navegador o dispositivo.');
      }
      if (mounted) setState(() => _mediaWarning = warnings.isEmpty ? null : warnings.join(' '));
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'No se pudo conectar con la sala.';
      if (mounted) setState(() { _error = message; _connecting = false; });
    } catch (error) {
      if (mounted) setState(() { _error = 'No se pudo iniciar la videollamada: $error'; _connecting = false; });
    }
  }

  Future<void> _toggleMicrophone() async {
    final next = !_microphoneEnabled;
    try {
      await _room.localParticipant?.setMicrophoneEnabled(next);
      if (mounted) setState(() => _microphoneEnabled = next);
    } catch (_) {
      _showMediaError('No se pudo cambiar el micrófono. Verifica los permisos y que no esté en uso por otra aplicación.');
    }
  }

  Future<void> _toggleCamera() async {
    final next = !_cameraEnabled;
    try {
      await _room.localParticipant?.setCameraEnabled(next);
      if (mounted) setState(() { _cameraEnabled = next; _mediaWarning = null; });
    } catch (_) {
      _showMediaError('No se pudo activar la cámara. Revisa los permisos del navegador o dispositivo.');
    }
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
        await ref.read(dioProvider).post('/api/tutorias/grupales/${widget.sessionId}/chat', data: {'texto': text});
      }
      if (_room.localParticipant != null) {
        final payload = utf8.encode(jsonEncode({'text': text, 'sentAt': DateTime.now().toUtc().toIso8601String()}));
        await _room.localParticipant!.publishData(payload, reliable: true, topic: 'searchteach.chat');
      }
    } on DioException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'No se pudo guardar el mensaje.')));
      return;
    }
    if (mounted) {
      setState(() => _messages.add(_RoomMessage(sender: 'Tú', text: text)));
      _message.clear();
    }
  }

  String get _projectChatPath => '/api/tutorias-colectivas/${Uri.encodeComponent(widget.projectTutoringId!)}'
      '/proyectos/${Uri.encodeComponent(widget.projectId!)}'
      '/sesiones/${Uri.encodeComponent(widget.projectReportSessionId!)}/mensajes';

  Future<void> _setAttendance(String studentId, bool attended) async {
    try {
      await ref.read(dioProvider).patch('/api/tutorias/grupales/${widget.sessionId}/asistencia', data: {'estudianteId': studentId, 'asistio': attended});
      if (mounted) setState(() => _attendance[studentId] = attended);
    } on DioException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'No se pudo guardar la asistencia.')));
    }
  }

  Future<void> _finish(String reason) async {
    try {
      await ref.read(dioProvider).patch('/api/tutorias/grupales/${widget.sessionId}/finalizar', data: {'motivo': reason});
      if (mounted) setState(() => _ended = true);
      await _room.disconnect();
    } on DioException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'No se pudo finalizar la tutoría.')));
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
          yield _VideoTile(label: participant.identity, track: track);
        }
      }
      if (!participantHasVideo) yield _VideoTile(label: participant.identity, track: null);
    }
    if (_room.remoteParticipants.isEmpty) yield const _WaitingParticipantTile();
  }

  @override
  void dispose() {
    _endTimer?.cancel();
    _chatTimer?.cancel();
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
    if (_ended) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.subject)),
        body: Column(children: [
            ListTile(title: Text(widget.isProjectMeeting ? 'Reunión de proyecto finalizada' : 'Historial de tutoría'), subtitle: Text(widget.isProjectMeeting ? 'Chat del proyecto guardado' : 'Asistencia y chat guardados'), leading: const Icon(Icons.check_circle_outline)),
          Expanded(child: ListView(children: [
            for (final student in widget.students) ListTile(
              leading: Icon(_attendance[student] == true ? Icons.check_circle : _attendance[student] == false ? Icons.cancel_outlined : Icons.help_outline),
              title: Text(_studentNames[student] ?? student),
              subtitle: Text(_attendance[student] == true ? 'Presente' : _attendance[student] == false ? 'Ausente' : 'Sin marcar'),
            ),
            const Divider(),
            for (final message in _messages) ListTile(title: Text(message.sender), subtitle: Text(message.text)),
          ])),
        ]),
      );
    }
    if (_connecting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.subject)),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1F26),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.subject, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text('${_room.remoteParticipants.length + (_connected ? 1 : 0)} participantes', style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            tooltip: _showChat ? 'Ocultar chat' : 'Mostrar chat',
            onPressed: () => setState(() => _showChat = !_showChat),
            icon: Icon(_showChat ? Icons.chat : Icons.chat_outlined),
          ),
        ],
      ),
      body: Column(children: [
        if (_mediaWarning != null)
          MaterialBanner(
            backgroundColor: const Color(0xFF3A2B18),
            content: Text(_mediaWarning!, style: const TextStyle(color: Colors.white)),
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
            actions: [TextButton(onPressed: () => setState(() => _mediaWarning = null), child: const Text('Entendido'))],
          ),
        Expanded(
          child: wide
              ? Row(children: [
                  Expanded(flex: 4, child: _videoGallery()),
                  if (_showChat) SizedBox(width: 340, child: _chatPanel()),
                ])
              : Column(children: [
                  Expanded(flex: _showChat ? 3 : 1, child: _videoGallery()),
                  if (_showChat) SizedBox(height: 220, child: _chatPanel()),
                ]),
        ),
        if (widget.teacherMode && !widget.isProjectMeeting) _teacherSessionPanel(),
        _callControls(),
      ]),
    );
  }

  Widget _videoGallery() => LayoutBuilder(builder: (context, constraints) {
        final tiles = widget.modality.toUpperCase() == 'PRESENCIAL'
            ? const <Widget>[_WaitingParticipantTile(message: 'Tutoría presencial')]
            : _videoTiles().toList();
        final columns = constraints.maxWidth > 1000 ? 3 : constraints.maxWidth > 560 ? 2 : 1;
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
        color: const Color(0xFF1C1F26),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.isProjectMeeting ? 'Chat del proyecto' : 'Chat de la tutoría', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, index) => ListTile(
              dense: true,
              title: Text(_messages[index].sender, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: Text(_messages[index].text, style: const TextStyle(color: Colors.white70)),
            ),
          )),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _message,
                maxLength: 500,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Escribe al grupo',
                  counterText: '',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF292D35),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              )),
              IconButton(onPressed: _sendMessage, color: Colors.lightBlueAccent, icon: const Icon(Icons.send)),
            ]),
          ),
        ]),
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
                _CallControl(icon: _microphoneEnabled ? Icons.mic : Icons.mic_off, label: _microphoneEnabled ? 'Silenciar' : 'Activar audio', onPressed: _toggleMicrophone, active: _microphoneEnabled),
              if (widget.modality.toUpperCase() != 'PRESENCIAL')
                _CallControl(icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off, label: _cameraEnabled ? 'Apagar cámara' : 'Activar cámara', onPressed: _toggleCamera, active: _cameraEnabled),
              _CallControl(icon: Icons.chat_outlined, label: _showChat ? 'Cerrar chat' : 'Chat', onPressed: () => setState(() => _showChat = !_showChat), active: _showChat),
              if (widget.teacherMode && !widget.isProjectMeeting)
                _CallControl(icon: Icons.stop_circle_outlined, label: 'Finalizar clase', onPressed: () => _finish('FINALIZADA'), active: false),
              _CallControl(icon: Icons.call_end, label: 'Salir', onPressed: () => Navigator.of(context).maybePop(), active: false, danger: true),
            ],
          ),
        ),
      );

  Widget _teacherSessionPanel() => ExpansionTile(
        collapsedBackgroundColor: const Color(0xFF1C1F26),
        backgroundColor: const Color(0xFF1C1F26),
        textColor: Colors.white,
        collapsedTextColor: Colors.white,
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        title: const Text('Asistencia y opciones de cierre'),
        children: [
          for (final student in widget.students)
            ListTile(
              dense: true,
              title: Text(_studentNames[student] ?? student, style: const TextStyle(color: Colors.white)),
              subtitle: Text(_attendance[student] == true ? 'Presente' : _attendance[student] == false ? 'Ausente' : 'Sin marcar', style: const TextStyle(color: Colors.white70)),
              trailing: Wrap(children: [
                IconButton(tooltip: 'Marcar presente', onPressed: () => _setAttendance(student, true), icon: const Icon(Icons.check_circle_outline, color: Colors.green)),
                IconButton(tooltip: 'Marcar ausente', onPressed: () => _setAttendance(student, false), icon: const Icon(Icons.cancel_outlined, color: Colors.red)),
              ]),
            ),
          Wrap(spacing: 8, children: [
            TextButton(onPressed: () => _finish('FALTA_ESTUDIANTES'), child: const Text('Falta de estudiantes')),
            TextButton(onPressed: () => _finish('PROBLEMAS_EXTERNOS'), child: const Text('Problema externo')),
            TextButton(onPressed: () => _finish('PROBLEMAS_INTERNET'), child: const Text('Problema de internet')),
          ]),
        ],
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
            Center(child: CircleAvatar(
              radius: 38,
              backgroundColor: const Color(0xFF414751),
              child: Text(label.isEmpty ? '?' : label.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 28)),
            )),
          Positioned(left: 8, bottom: 8, child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.all(Radius.circular(8))),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(label, style: const TextStyle(color: Colors.white))),
          )),
        ]),
      );
}

class _WaitingParticipantTile extends StatelessWidget {
  const _WaitingParticipantTile({this.message = 'Esperando a que alguien se una…'});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF292D35),
        child: Center(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.people_outline, color: Colors.white70, size: 38),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ]),
        )),
      );
}

class _CallControl extends StatelessWidget {
  const _CallControl({required this.icon, required this.label, required this.onPressed, required this.active, this.danger = false});
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
              backgroundColor: danger ? const Color(0xFFB3261E) : active ? const Color(0xFF3C414B) : const Color(0xFF292D35),
              foregroundColor: Colors.white,
              minimumSize: const Size(52, 52),
            ),
            icon: Icon(icon),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );
}

class _RoomMessage {
  const _RoomMessage({required this.sender, required this.text});
  final String sender;
  final String text;
}
