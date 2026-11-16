import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import '../../core/widgets/role_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/neu/neu.dart';
import 'livekit_room_page.dart';

const _teacherAccent = Color(0xFF16834A);
const _studentAccent = Color(0xFF1769AA);
const _voiceSampleRate = 16000;
const _maxVoiceDuration = Duration(minutes: 3);

class ProyectoAulaChatPage extends ConsumerStatefulWidget {
  const ProyectoAulaChatPage({
    required this.tutoringId,
    required this.projectId,
    required this.sessionId,
    required this.title,
    required this.teacherMode,
    this.supportMode = true,
    this.readOnly = false,
    super.key,
  });
  final String tutoringId;
  final String projectId;
  final String sessionId;
  final String title;
  final bool teacherMode;
  final bool supportMode;
  final bool readOnly;

  @override
  ConsumerState<ProyectoAulaChatPage> createState() =>
      _ProyectoAulaChatPageState();
}

class _ProyectoAulaChatPageState extends ConsumerState<ProyectoAulaChatPage> {
  final _text = TextEditingController();
  final _audioRecorder = AudioRecorder();
  List<Map<String, dynamic>> _messages = [];
  PlatformFile? _attachment;
  bool _loading = true;
  bool _sending = false;
  bool _recording = false;
  bool _finalizingRecording = false;
  String _closureReport = '';
  String? _error;
  Map<String, dynamic>? _projectState;
  Map<String, dynamic>? _meeting;
  bool _panelOpen = false;
  _ChatSection _section = _ChatSection.videoconferencias;
  BytesBuilder? _recordingBuffer;
  StreamSubscription<Uint8List>? _recordingSubscription;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  Timer? _refreshTimer;
  CancelToken? _streamCancel;
  StreamSubscription<String>? _streamSubscription;

  String get _path =>
      '/api/tutorias-colectivas/${Uri.encodeComponent(widget.tutoringId)}'
      '/proyectos/${Uri.encodeComponent(widget.projectId)}'
      '/sesiones/${Uri.encodeComponent(widget.sessionId)}/mensajes';
  String get _statusPath =>
      '/api/tutorias-colectivas/${Uri.encodeComponent(widget.tutoringId)}'
      '/proyectos/${Uri.encodeComponent(widget.projectId)}'
      '/sesiones/${Uri.encodeComponent(widget.sessionId)}/estado';
  String get _meetingPath =>
      '/api/tutorias-colectivas/${Uri.encodeComponent(widget.tutoringId)}'
      '/proyectos/${Uri.encodeComponent(widget.projectId)}'
      '/sesiones/${Uri.encodeComponent(widget.sessionId)}/reunion';

  bool get _canManageProject =>
      !widget.readOnly &&
      widget.teacherMode &&
      widget.supportMode &&
      _projectState?['estadoCierre'] != 'FINALIZADO';

  Color get _roleAccent => widget.teacherMode ? _teacherAccent : _studentAccent;

  bool get _chatClosed => _projectState?['estadoCierre'] == 'FINALIZADO';

  @override
  void initState() {
    super.initState();
    _load();
    _connectStream();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _refreshTimer?.cancel();
    _recordingTimer?.cancel();
    _streamCancel?.cancel('Chat cerrado');
    _streamSubscription?.cancel();
    _recordingSubscription?.cancel();
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  Future<void> _connectStream() async {
    final cancel = CancelToken();
    _streamCancel = cancel;
    try {
      final response = await ref.read(dioProvider).get<ResponseBody>(
            '$_path/stream',
            cancelToken: cancel,
            options: Options(
                responseType: ResponseType.stream,
                receiveTimeout: Duration.zero),
          );
      final body = response.data;
      if (body == null || cancel.isCancelled) return;
      _streamSubscription = body.stream
          .map((chunk) => utf8.decode(chunk))
          .transform(const LineSplitter())
          .where((line) => line.startsWith('data:'))
          .map((line) => line.substring(5).trim())
          .where((line) => line.isNotEmpty && line != 'connected')
          .listen(_receiveStreamMessage, onError: (_) {});
    } on DioException {
      // La consulta periódica mantiene el chat actualizado si SSE no está disponible.
    }
  }

  void _receiveStreamMessage(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic> || !mounted) return;
      final id = decoded['id']?.toString();
      setState(() {
        if (id == null ||
            !_messages.any((message) => message['id']?.toString() == id)) {
          _messages = [..._messages, decoded];
        }
      });
    } on FormatException {
      // Ignora eventos incompletos o no válidos.
    }
  }

  Future<void> _load() async {
    try {
      final response = await ref.read(dioProvider).get<List<dynamic>>(_path);
      if (!mounted) return;
      final loaded = (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: true);
      final loadedIds =
          loaded.map((message) => message['id']?.toString()).toSet();
      loaded.addAll(_messages.where((message) =>
          message['id'] == null ||
          !loadedIds.contains(message['id']?.toString())));
      setState(() {
        _messages = loaded;
        _loading = false;
        _error = null;
      });
      try {
        final project =
            await ref.read(dioProvider).get<Map<String, dynamic>>(_statusPath);
        if (mounted) setState(() => _projectState = project.data);
      } on DioException {
        // The report remains readable if project status cannot be refreshed.
      }
      try {
        final meeting = await ref.read(dioProvider).get<Map<String, dynamic>>(
              _meetingPath,
            );
        if (mounted) setState(() => _meeting = meeting.data);
      } on DioException {
        if (mounted) setState(() => _meeting = null);
      }
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _apiMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _respondMeeting(bool accepts) async {
    try {
      await ref.read(dioProvider).post(
        '$_meetingPath/respuesta',
        queryParameters: {'acepta': accepts},
      );
      await _load();
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _apiMessage(error));
    }
  }

  Future<void> _scheduleMeeting() async {
    final now = DateTime.now();
    var date = now.add(const Duration(days: 1));
    var time = const TimeOfDay(hour: 10, minute: 0);
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: const Text('Organizar reunión de PA'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: now,
                          lastDate: DateTime(now.year + 2));
                      if (picked != null) {
                        setDialogState(() => date =
                            DateTime(picked.year, picked.month, picked.day));
                      }
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                          context: context, initialTime: time);
                      if (picked != null) setDialogState(() => time = picked);
                    },
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(time.format(context)),
                  ),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancelar')),
                  FilledButton.icon(
                      onPressed: () => Navigator.pop(
                          dialogContext,
                          DateTime(date.year, date.month, date.day, time.hour,
                              time.minute)),
                      icon: const Icon(Icons.video_call_outlined),
                      label: const Text('Crear videoconferencia')),
                ],
              )),
    );
    if (selected == null) return;
    if (!selected.isAfter(DateTime.now())) {
      setState(() => _error = 'Selecciona una fecha y hora futura.');
      return;
    }
    try {
      await ref.read(dioProvider).post(
        '/api/docente/tutorias-colectivas/${Uri.encodeComponent(widget.tutoringId)}'
        '/proyectos/${Uri.encodeComponent(widget.projectId)}'
        '/sesiones/${Uri.encodeComponent(widget.sessionId)}/reunion',
        data: {'fechaReunion': selected.toIso8601String()},
      );
      await _load();
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _apiMessage(error));
    }
  }

  Future<void> _requestProjectClosure() async {
    var reason = 'LISTO';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: const Text('Solicitar finalización de PA'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  RadioListTile<String>(
                      value: 'LISTO',
                      groupValue: reason,
                      onChanged: (value) =>
                          setDialogState(() => reason = value!),
                      title: const Text('Dar por completado el asesoramiento')),
                  RadioListTile<String>(
                      value: 'SIN_ATENCION',
                      groupValue: reason,
                      onChanged: (value) =>
                          setDialogState(() => reason = value!),
                      title:
                          const Text('Finalizar por falta de participación')),
                  TextField(
                    maxLines: 4,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Reporte obligatorio de lo realizado',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        setDialogState(() => _closureReport = value),
                  ),
                  const Text(
                      'El docente líder revisará el reporte antes de confirmar el cierre.'),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancelar')),
                  FilledButton(
                    onPressed: _closureReport.trim().isEmpty
                        ? null
                        : () => Navigator.pop(dialogContext, reason),
                    child: const Text('Enviar al líder'),
                  ),
                ],
              )),
    );
    if (selected == null) return;
    try {
      await ref.read(dioProvider).post(
        '/api/docente/tutorias-colectivas/${Uri.encodeComponent(widget.tutoringId)}'
        '/proyectos/${Uri.encodeComponent(widget.projectId)}/solicitud-cierre',
        data: {'motivo': selected, 'reporte': _closureReport.trim()},
      );
      await _load();
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _apiMessage(error));
    }
  }

  Future<void> _pickFile({required bool audio}) async {
    final allowed = audio ? const ['webm', 'wav'] : const ['pdf', 'docx'];
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowed,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final extension = file.extension?.toLowerCase();
    if (!allowed.contains(extension) || file.bytes == null) {
      setState(() => _error = audio
          ? 'Selecciona una nota de voz en formato WebM o WAV.'
          : 'Selecciona un documento PDF o Word (.docx) válido.');
      return;
    }
    setState(() {
      _attachment = file;
      _error = null;
    });
  }

  Future<void> _startVoiceRecording() async {
    if (_recording || _finalizingRecording || _sending) return;
    if (_attachment != null) {
      setState(() => _error = 'Quita el adjunto actual antes de grabar una nota de voz.');
      return;
    }
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          setState(() => _error = 'Permite el acceso al micrófono para grabar.');
        }
        return;
      }
      _recordingBuffer = BytesBuilder(copy: false);
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _voiceSampleRate,
          numChannels: 1,
        ),
      );
      _recordingSubscription = stream.listen(
        (chunk) => _recordingBuffer?.add(chunk),
        onError: (Object error, StackTrace stackTrace) {
          if (mounted) {
            setState(() => _error = 'La grabación de audio se interrumpió.');
          }
        },
      );
      if (!mounted) {
        await _audioRecorder.stop();
        return;
      }
      setState(() {
        _recording = true;
        _recordingDuration = Duration.zero;
        _error = null;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_recording) return;
        final next = _recordingDuration + const Duration(seconds: 1);
        setState(() => _recordingDuration = next);
        if (next >= _maxVoiceDuration) {
          unawaited(_finishVoiceRecording());
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo iniciar la grabación: $error');
      }
    }
  }

  Future<void> _finishVoiceRecording() async {
    if (!_recording || _finalizingRecording) return;
    setState(() => _finalizingRecording = true);
    _recordingTimer?.cancel();
    var readyToSend = false;
    try {
      await _audioRecorder.stop();
      await _recordingSubscription?.cancel();
      _recordingSubscription = null;
      final pcm = _recordingBuffer?.takeBytes() ?? Uint8List(0);
      _recordingBuffer = null;
      if (pcm.isEmpty) {
        throw const FormatException('No se capturó audio. Inténtalo de nuevo.');
      }
      final wav = _encodePcmAsWav(pcm);
      if (wav.length > 8 * 1024 * 1024) {
        throw const FormatException(
            'La nota de voz supera el límite de 8 MB.');
      }
      if (!mounted) return;
      setState(() {
        _attachment = PlatformFile(
          name: 'nota-de-voz-${DateTime.now().millisecondsSinceEpoch}.wav',
          size: wav.length,
          bytes: wav,
        );
        _error = null;
      });
      readyToSend = true;
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _recording = false;
          _finalizingRecording = false;
          _recordingDuration = Duration.zero;
        });
      }
    }
    if (readyToSend && mounted) await _send();
  }

  Uint8List _encodePcmAsWav(Uint8List pcm) {
    final sampleBytes = pcm.length - pcm.length % 2;
    final data = ByteData(44);
    void writeText(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        data.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    writeText(0, 'RIFF');
    data.setUint32(4, sampleBytes + 36, Endian.little);
    writeText(8, 'WAVE');
    writeText(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _voiceSampleRate, Endian.little);
    data.setUint32(28, _voiceSampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeText(36, 'data');
    data.setUint32(40, sampleBytes, Endian.little);
    final wav = Uint8List(44 + sampleBytes);
    wav.setRange(0, 44, data.buffer.asUint8List());
    wav.setRange(44, wav.length, pcm);
    return wav;
  }

  Future<void> _toggleVoiceRecording() async {
    if (_recording) {
      await _finishVoiceRecording();
    } else {
      await _startVoiceRecording();
    }
  }

  String _recordingTime() {
    final minutes = _recordingDuration.inMinutes.toString().padLeft(2, '0');
    final seconds =
        (_recordingDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty && _attachment == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final form = FormData.fromMap({
        if (text.isNotEmpty) 'texto': text,
        if (_attachment?.bytes != null)
          'archivo': MultipartFile.fromBytes(
            _attachment!.bytes!,
            filename: _attachment!.name,
          ),
      });
      await ref.read(dioProvider).post(_path, data: form);
      _text.clear();
      setState(() => _attachment = null);
      await _load();
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _apiMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _download(Map<String, dynamic> message) async {
    final id = message['id']?.toString() ?? '';
    final name = message['archivoNombre']?.toString() ?? 'adjunto';
    if (id.isEmpty) return;
    try {
      final response = await ref.read(dioProvider).get<List<int>>(
            '$_path/${Uri.encodeComponent(id)}/archivo',
            options: Options(responseType: ResponseType.bytes),
          );
      final bytes = response.data;
      if (bytes == null) throw const FormatException('El archivo está vacío.');
      await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar archivo',
        fileName: name,
        bytes: Uint8List.fromList(bytes),
      );
    } on DioException catch (error) {
      if (mounted) {
        RoleToast.showSnackBar(
            context, SnackBar(content: Text(_apiMessage(error))));
      }
    } on FormatException catch (error) {
      if (mounted) {
        RoleToast.showSnackBar(context, SnackBar(content: Text(error.message)));
      }
    }
  }

  String _apiMessage(DioException error) {
    final data = error.response?.data;
    return data is Map && data['message'] is String
        ? data['message'] as String
        : 'No se pudo completar la operación.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Neu.bg,
        appBar: AppBar(
          backgroundColor: Neu.bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.title,
            style: neuPoppins(size: 17, weight: FontWeight.w700, color: Neu.heading),
          ),
          actions: [
            if (_canManageProject && _projectState?['estadoCierre'] == 'EN_CURSO')
              PopupMenuButton<String>(
                tooltip: 'Acciones del proyecto',
                onSelected: (_) => _requestProjectClosure(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'cierre', child: Text('Solicitar finalizar PA')),
                ],
              ),
            IconButton(
              tooltip: _panelOpen
                  ? 'Cerrar menú'
                  : 'Videoconferencias y documentos',
              onPressed: () => setState(() => _panelOpen = !_panelOpen),
              icon: Icon(
                _panelOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: _roleAccent,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final hasMeetingCard = _meeting != null && !widget.teacherMode;
            final panelWidth =
                constraints.maxWidth >= 424 ? 400.0 : constraints.maxWidth - 24;
            return Stack(
              children: [
                Column(
                  children: [
                    if (_projectState != null) _projectWorkflowBanner(),
                    if (hasMeetingCard) _meetingCard(),
                    Expanded(
                      child: _loading
                          ? Center(
                              child: CircularProgressIndicator(
                                  color: _roleAccent))
                          : _error != null && _messages.isEmpty
                              ? Center(child: _chatNotice(_error!))
                              : ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: [
                                    if (_messages.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          'Inicia la conversación sobre este reporte.',
                                          textAlign: TextAlign.center,
                                          style: neuBody(
                                              size: 14, color: Neu.muted),
                                        ),
                                      ),
                                    for (final message in _messages)
                                      _messageBubble(message),
                                  ],
                                ),
                    ),
                    if (_error != null && _messages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: _chatNotice(_error!),
                      ),
                    if (!widget.readOnly && !_chatClosed) _composer(),
                  ],
                ),
                if (_panelOpen)
                  Positioned(
                    top: (_projectState != null ? 68.0 : 12.0) +
                        (hasMeetingCard ? 84.0 : 0.0),
                    right: 12,
                    child: SizedBox(
                      width: panelWidth,
                      child: _resourcesPanel(),
                    ),
                  ),
              ],
            );
          },
        ),
      );

  Widget _chatNotice(String message) => NeuSunken(
        radius: 14,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _roleAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: neuBody(size: 13))),
          ],
        ),
      );

  Widget _composer() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: NeuSurface(
            radius: 20,
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_attachment != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Icon(Icons.attach_file, color: _roleAccent, size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _attachment!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: neuBody(size: 12, color: Neu.muted),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar adjunto',
                        visualDensity: VisualDensity.compact,
                        onPressed: _sending
                            ? null
                            : () => setState(() => _attachment = null),
                        icon: const Icon(Icons.close_rounded, size: 19),
                      ),
                    ]),
                  ),
                if (_recording || _finalizingRecording)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Icon(Icons.fiber_manual_record,
                          size: 12, color: _teacherAccent),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _finalizingRecording
                              ? 'Preparando nota de voz…'
                              : 'Grabando ${_recordingTime()} · suelta o haz clic para enviar',
                          style: neuBody(
                              size: 12,
                              weight: FontWeight.w600,
                              color: _roleAccent),
                        ),
                      ),
                    ]),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Adjuntar documento (PDF o Word)',
                      onPressed:
                          _sending ? null : () => _pickFile(audio: false),
                      color: _roleAccent,
                      icon: const Icon(Icons.attach_file_rounded),
                    ),
                    GestureDetector(
                      onTap: _sending || _finalizingRecording
                          ? null
                          : _toggleVoiceRecording,
                      onLongPressStart: _sending || _finalizingRecording
                          ? null
                          : (_) => unawaited(_startVoiceRecording()),
                      onLongPressEnd: _sending || _finalizingRecording
                          ? null
                          : (_) => unawaited(_finishVoiceRecording()),
                      child: NeuSurface(
                        radius: 14,
                        padding: const EdgeInsets.all(11),
                        gradient: _recording
                            ? const LinearGradient(
                                colors: [Color(0xFFFF7777), Color(0xFFE53935)])
                            : null,
                        child: Icon(
                          _recording
                              ? Icons.stop_rounded
                              : Icons.mic_none_rounded,
                          size: 21,
                          color: _recording ? Colors.white : _roleAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Focus(
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.enter &&
                              !HardwareKeyboard.instance.isShiftPressed) {
                            unawaited(_send());
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: NeuSunken(
                          radius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: _text,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 4000,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: 'Escribe una respuesta…',
                              border: InputBorder.none,
                              counterText: '',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: _roleAccent,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'Enviar (Enter)',
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _meetingCard() {
    final state = _meeting?['estado']?.toString() ?? 'PENDIENTE';
    final date = DateTime.tryParse(_meeting?['fechaReunion']?.toString() ?? '');
    final responses = (_meeting?['respuestas'] as Map?)?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: NeuSurface(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Icon(
            state == 'CANCELADA'
                ? Icons.event_busy
                : Icons.video_call_outlined,
            color: _roleAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state == 'CANCELADA'
                      ? 'Videoconferencia cancelada'
                      : 'Videoconferencia propuesta',
                  style: neuPoppins(size: 12.5, color: Neu.heading),
                ),
                Text(
                  '${date == null ? 'Fecha pendiente' : _stamp(date.toIso8601String())} · '
                  '$responses respuesta(s)',
                  style: neuBody(size: 11, color: Neu.muted),
                ),
              ],
            ),
          ),
          if (state != 'CANCELADA') ...[
            TextButton(
              onPressed: () => _respondMeeting(false),
              child: const Text('No puedo'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _roleAccent),
              onPressed: () => _respondMeeting(true),
              child: const Text('Aceptar'),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _projectWorkflowBanner() {
    final state = _projectState?['estadoCierre']?.toString() ?? 'EN_CURSO';
    final meeting =
        DateTime.tryParse(_projectState?['fechaReunion']?.toString() ?? '')
            ?.toLocal();
    final reason = _projectState?['motivoCierre']?.toString();
    final status = state == 'FINALIZADO'
        ? 'Proyecto finalizado por el docente líder.'
        : state == 'PENDIENTE_CONFIRMACION'
            ? 'Cierre pendiente de revisión del docente líder${reason == 'SIN_ATENCION' ? ' · motivo: falta de atención' : ' · motivo: proyecto listo'}.'
            : 'Proyecto en curso.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: NeuSunken(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.track_changes_rounded, color: _roleAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$status${meeting == null ? '' : '\nReunión: ${meeting.day.toString().padLeft(2, '0')}/${meeting.month.toString().padLeft(2, '0')}/${meeting.year} ${TimeOfDay.fromDateTime(meeting).format(context)}'}',
                style: neuBody(size: 12, color: Neu.text, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final own = message['propio'] == true;
    final senderIsTeacher = own ? widget.teacherMode : !widget.teacherMode;
    final senderAccent = senderIsTeacher ? _teacherAccent : _studentAccent;
    final senderRole = senderIsTeacher
        ? (widget.supportMode ? 'Docente de apoyo' : 'Docente líder')
        : 'Estudiante';
    final fileName = message['archivoNombre']?.toString();
    final sentAt =
        DateTime.tryParse(message['enviadoEn']?.toString() ?? '')?.toLocal();
    return Align(
      alignment:
          senderIsTeacher ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: own
                  ? senderAccent.withValues(alpha: 0.09)
                  : Neu.bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(own ? 18 : 5),
                bottomRight: Radius.circular(own ? 5 : 18),
              ),
              border: Border.all(color: senderAccent.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Neu.shadowDark.withValues(alpha: 0.32),
                  offset: const Offset(3, 3),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: Neu.shadowLight.withValues(alpha: 0.75),
                  offset: const Offset(-3, -3),
                  blurRadius: 8,
                ),
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.account_circle_outlined,
                    color: senderAccent, size: 17),
                const SizedBox(width: 6),
                Text(
                  own ? 'Tú · $senderRole' : senderRole,
                  style: neuPoppins(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: senderAccent),
                ),
              ]),
              if ((message['texto']?.toString() ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SelectableText(
                    message['texto'].toString(),
                    style: neuBody(size: 13, color: Neu.text, height: 1.35),
                  ),
                ),
              if (fileName != null && fileName.isNotEmpty)
                _attachmentTile(message, fileName, senderAccent),
              if (message['tipo'] == 'REUNION')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: senderAccent),
                    onPressed: _chatClosed ? null : _enterMeeting,
                    icon: const Icon(Icons.video_call_outlined),
                    label: const Text('Entrar a la reunión de PA'),
                  ),
                ),
              if (sentAt != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                      '${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')}/${sentAt.year} ${TimeOfDay.fromDateTime(sentAt).format(context)}',
                      style: neuBody(size: 10, color: Neu.muted)),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  bool _isAudio(Map<String, dynamic> message) {
    final mime = message['archivoMime']?.toString().toLowerCase() ?? '';
    final name = message['archivoNombre']?.toString().toLowerCase() ?? '';
    return mime.startsWith('audio/') ||
        name.endsWith('.webm') ||
        name.endsWith('.wav');
  }

  String _size(dynamic bytes) {
    final value = bytes is num ? bytes.toDouble() : 0.0;
    if (value <= 0) return '';
    if (value < 1024 * 1024) return '${(value / 1024).ceil()} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _stamp(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${TimeOfDay.fromDateTime(date).format(context)}';
  }

  /// Nota de voz (estilo WhatsApp) o documento dentro de la burbuja.
  Widget _attachmentTile(
      Map<String, dynamic> message, String fileName, Color senderAccent) {
    final audio = _isAudio(message);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _download(message),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: senderAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: senderAccent.withValues(alpha: 0.18)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(audio ? Icons.mic_rounded : _docIcon(fileName),
                color: senderAccent),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(audio ? 'Nota de voz' : fileName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                      [
                        if (audio)
                          fileName.toLowerCase().endsWith('.wav') ? 'WAV' : 'WebM',
                        _size(message['archivoTamano']),
                      ].where((e) => e.isNotEmpty).join(' · '),
                      style: neuBody(size: 10.5, color: Neu.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.download_outlined, size: 20),
          ]),
        ),
      ),
    );
  }

  IconData _docIcon(String name) => name.toLowerCase().endsWith('.pdf')
      ? Icons.picture_as_pdf_outlined
      : Icons.description_outlined;

  /// Menú desplegable del chat: Videoconferencias | Documentos.
  Widget _resourcesPanel() {
    final meetings = _messages.where((m) => m['tipo'] == 'REUNION').toList();
    final documents = _messages
        .where((m) =>
            (m['archivoNombre']?.toString() ?? '').isNotEmpty &&
            !_isAudio(m))
        .toList();
    final finished = _projectState?['estadoCierre'] == 'FINALIZADO';
    final theme = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(primary: _roleAccent),
    );
    return Theme(
      data: theme,
      child: NeuSurface(
        radius: 18,
        padding: EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.48),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: SegmentedButton<_ChatSection>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                      value: _ChatSection.videoconferencias,
                      icon: const Icon(Icons.videocam_outlined),
                      label: Text('Videollamadas (${meetings.length})')),
                  ButtonSegment(
                      value: _ChatSection.documentos,
                      icon: const Icon(Icons.folder_open_outlined),
                      label: Text('Documentos (${documents.length})')),
                ],
                selected: {_section},
                onSelectionChanged: (value) =>
                    setState(() => _section = value.first),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                children: _section == _ChatSection.videoconferencias
                    ? [
                        if (_canManageProject)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: _roleAccent),
                              onPressed: _scheduleMeeting,
                              icon: const Icon(Icons.video_call_outlined),
                              label: const Text('Programar videoconferencia'),
                            ),
                          ),
                        if (meetings.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              'Aún no hay videoconferencias.',
                              style: neuBody(size: 12, color: Neu.muted),
                            ),
                          ),
                        for (final m in meetings.reversed)
                          ListTile(
                            dense: true,
                            leading: Icon(Icons.videocam_outlined,
                                color: _roleAccent),
                            title: Text(
                                (m['texto']?.toString() ?? '').isEmpty
                                    ? 'Reunión de PA'
                                    : m['texto'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(_stamp(m['enviadoEn'])),
                            trailing: TextButton(
                              onPressed: finished ? null : _enterMeeting,
                              child: const Text('Entrar'),
                            ),
                          ),
                      ]
                    : [
                        if (!widget.readOnly && !finished)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _sending
                                  ? null
                                  : () => _pickFile(audio: false),
                              icon: const Icon(Icons.upload_file_outlined),
                              label: const Text('Subir PDF o Word'),
                            ),
                          ),
                        if (documents.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              'Aún no se han compartido documentos.',
                              style: neuBody(size: 12, color: Neu.muted),
                            ),
                          ),
                        for (final m in documents.reversed)
                          ListTile(
                            dense: true,
                            leading: Icon(
                                _docIcon(m['archivoNombre'].toString()),
                                color: _roleAccent),
                            title: Text(m['archivoNombre'].toString(),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                [_size(m['archivoTamano']), _stamp(m['enviadoEn'])]
                                    .where((e) => e.isNotEmpty)
                                    .join(' · ')),
                            trailing: Icon(Icons.download_outlined,
                                color: _roleAccent),
                            onTap: () => _download(m),
                          ),
                      ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _enterMeeting() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LiveKitRoomPage(
        sessionId: widget.projectId,
        subject: 'Reunión PA · ${widget.title}',
        teacherMode: widget.teacherMode && widget.supportMode,
        projectTutoringId: widget.tutoringId,
        projectId: widget.projectId,
        projectReportSessionId: widget.sessionId,
      ),
    ));
  }
}

enum _ChatSection { videoconferencias, documentos }
