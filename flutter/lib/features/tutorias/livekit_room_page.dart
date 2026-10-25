import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../core/api_client.dart';

class LiveKitRoomPage extends ConsumerStatefulWidget {
  const LiveKitRoomPage({required this.sessionId, required this.subject, this.teacherMode = false, this.students = const [], this.ended = false, this.endAt, super.key});

  final String sessionId;
  final String subject;
  final bool teacherMode;
  final List<String> students;
  final bool ended;
  final DateTime? endAt;

  @override
  ConsumerState<LiveKitRoomPage> createState() => _LiveKitRoomPageState();
}

class _LiveKitRoomPageState extends ConsumerState<LiveKitRoomPage> {
  final Room _room = Room();
  final TextEditingController _message = TextEditingController();
  final List<_RoomMessage> _messages = [];
  final Map<String, bool?> _attendance = {};
  dynamic _listener;
  bool _connecting = true;
  bool _connected = false;
  bool _microphoneEnabled = true;
  bool _cameraEnabled = true;
  bool _ended = false;
  Timer? _endTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ended = widget.ended;
    _loadChatHistory();
    _loadAttendance();
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
    _connect();
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
      final response = await ref.read(dioProvider).get<List<dynamic>>('/api/tutorias/grupales/${widget.sessionId}/chat');
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll((response.data ?? const []).whereType<Map<String, dynamic>>().map((message) => _RoomMessage(
            sender: message['nombre']?.toString() ?? 'Participante',
            text: message['texto']?.toString() ?? '',
          )));
      });
    } on DioException { }
  }

  Future<void> _connect() async {
    try {
      final response = await ref.read(dioProvider).post<Map<String, dynamic>>(
        '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}/livekit-token',
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
      await _room.localParticipant?.setMicrophoneEnabled(true);
      await _room.localParticipant?.setCameraEnabled(true);
      if (mounted) setState(() { _connected = true; _connecting = false; });
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
    await _room.localParticipant?.setMicrophoneEnabled(next);
    if (mounted) setState(() => _microphoneEnabled = next);
  }

  Future<void> _toggleCamera() async {
    final next = !_cameraEnabled;
    await _room.localParticipant?.setCameraEnabled(next);
    if (mounted) setState(() => _cameraEnabled = next);
  }

  Future<void> _sendMessage() async {
    final text = _message.text.trim();
    if (text.isEmpty || _room.localParticipant == null) return;
    final payload = utf8.encode(jsonEncode({'text': text, 'sentAt': DateTime.now().toUtc().toIso8601String()}));
    await _room.localParticipant!.publishData(payload, reliable: true, topic: 'searchteach.chat');
    try {
      await ref.read(dioProvider).post('/api/tutorias/grupales/${widget.sessionId}/chat', data: {'texto': text});
    } on DioException { }
    if (mounted) {
      setState(() => _messages.add(_RoomMessage(sender: 'Tú', text: text)));
      _message.clear();
    }
  }

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
    if (local != null) {
      for (final publication in local.videoTrackPublications) {
        final track = publication.track;
        if (track is VideoTrack) {
          yield _VideoTile(label: 'Tú', track: track);
        }
      }
    }
    for (final participant in _room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (track is VideoTrack) {
          yield _VideoTile(label: participant.identity, track: track);
        }
      }
    }
  }

  @override
  void dispose() {
    _endTimer?.cancel();
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
          const ListTile(title: Text('Clase finalizada'), subtitle: Text('Asistencia guardada'), leading: Icon(Icons.check_circle_outline)),
          Expanded(child: ListView(children: [
            for (final student in widget.students) ListTile(
              leading: Icon(_attendance[student] == true ? Icons.check_circle : _attendance[student] == false ? Icons.cancel_outlined : Icons.help_outline),
              title: Text(student),
              subtitle: Text(_attendance[student] == true ? 'Presente' : _attendance[student] == false ? 'Ausente' : 'Sin marcar'),
            ),
            const Divider(),
            for (final message in _messages) ListTile(title: Text(message.sender), subtitle: Text(message.text)),
          ])),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.subject), actions: [
        if (_connected) Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(child: Text('${_room.remoteParticipants.length + 1}/6')),
        ),
      ]),
      body: _connecting
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : Column(children: [
                  Expanded(
                    flex: 3,
                    child: GridView.count(
                      padding: const EdgeInsets.all(12),
                      crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
                      children: [
                        ..._videoTiles(),
                        if (_videoTiles().isEmpty)
                          const Center(child: Text('Cámara apagada')),
                      ],
                    ),
                  ),
                  Wrap(spacing: 12, children: [
                    IconButton.filledTonal(
                      tooltip: _microphoneEnabled ? 'Silenciar' : 'Activar micrófono',
                      onPressed: _toggleMicrophone,
                      icon: Icon(_microphoneEnabled ? Icons.mic : Icons.mic_off),
                    ),
                    IconButton.filledTonal(
                      tooltip: _cameraEnabled ? 'Apagar cámara' : 'Activar cámara',
                      onPressed: _toggleCamera,
                      icon: Icon(_cameraEnabled ? Icons.videocam : Icons.videocam_off),
                    ),
                    IconButton.filled(
                      tooltip: 'Salir de la sala',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.call_end),
                    ),
                  ]),
                  if (widget.teacherMode) ...[
                    const Padding(padding: EdgeInsets.all(8), child: Text('Asistencia', style: TextStyle(fontWeight: FontWeight.bold))),
                    Wrap(spacing: 8, children: [for (final student in widget.students) Chip(label: Text(student), avatar: const Icon(Icons.person), onDeleted: () => _setAttendance(student, false), deleteIcon: const Icon(Icons.close), tooltip: 'Marcar ausencia'),]),
                    Wrap(spacing: 8, children: [for (final student in widget.students) OutlinedButton.icon(onPressed: () => _setAttendance(student, true), icon: const Icon(Icons.check), label: Text('Presente $student'))]),
                    Wrap(spacing: 8, children: [
                      OutlinedButton(onPressed: () => _finish('FALTA_ESTUDIANTES'), child: const Text('Finalizar por falta de estudiantes')),
                      OutlinedButton(onPressed: () => _finish('PROBLEMAS_EXTERNOS'), child: const Text('Problemas externos')),
                      OutlinedButton(onPressed: () => _finish('PROBLEMAS_INTERNET'), child: const Text('Problemas de internet')),
                      FilledButton(onPressed: () => _finish('FINALIZADA'), child: const Text('Finalizar clase')),
                    ]),
                  ],
                  const Divider(),
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => ListTile(
                        dense: true,
                        title: Text(_messages[index].sender, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(_messages[index].text),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Expanded(child: TextField(
                          controller: _message,
                          maxLength: 500,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: const InputDecoration(hintText: 'Escribe al grupo', border: OutlineInputBorder()),
                        )),
                        IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send)),
                      ]),
                    ),
                  ),
                ]),
    );
  }
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.label, required this.track});
  final String label;
  final VideoTrack track;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          VideoTrackRenderer(track, fit: VideoViewFit.cover),
          Positioned(left: 8, bottom: 8, child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.all(Radius.circular(8))),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(label, style: const TextStyle(color: Colors.white))),
          )),
        ]),
      );
}

class _RoomMessage {
  const _RoomMessage({required this.sender, required this.text});
  final String sender;
  final String text;
}
