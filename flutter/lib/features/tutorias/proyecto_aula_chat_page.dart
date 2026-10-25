import 'dart:typed_data';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'livekit_room_page.dart';

class ProyectoAulaChatPage extends ConsumerStatefulWidget {
  const ProyectoAulaChatPage({
    required this.tutoringId,
    required this.projectId,
    required this.sessionId,
    required this.title,
    required this.teacherMode,
    this.supportMode = true,
    super.key,
  });
  final String tutoringId;
  final String projectId;
  final String sessionId;
  final String title;
  final bool teacherMode;
  final bool supportMode;

  @override
  ConsumerState<ProyectoAulaChatPage> createState() => _ProyectoAulaChatPageState();
}

class _ProyectoAulaChatPageState extends ConsumerState<ProyectoAulaChatPage> {
  final _text = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  PlatformFile? _attachment;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Map<String, dynamic>? _projectState;
  Timer? _refreshTimer;

  String get _path => '/api/tutorias-colectivas/${Uri.encodeComponent(widget.tutoringId)}'
      '/proyectos/${Uri.encodeComponent(widget.projectId)}'
      '/sesiones/${Uri.encodeComponent(widget.sessionId)}/mensajes';
  String get _statusPath => '/api/tutorias-colectivas/${Uri.encodeComponent(widget.tutoringId)}'
      '/proyectos/${Uri.encodeComponent(widget.projectId)}'
      '/sesiones/${Uri.encodeComponent(widget.sessionId)}/estado';

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await ref.read(dioProvider).get<List<dynamic>>(_path);
      if (!mounted) return;
      setState(() {
        _messages = (response.data ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
        _loading = false;
        _error = null;
      });
      try {
        final project = await ref.read(dioProvider).get<Map<String, dynamic>>(_statusPath);
        if (mounted) setState(() => _projectState = project.data);
      } on DioException {
        // The report remains readable if project status cannot be refreshed.
      }
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _apiMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _scheduleMeeting() async {
    final now = DateTime.now();
    var date = now.add(const Duration(days: 1));
    var time = const TimeOfDay(hour: 10, minute: 0);
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Organizar reunión de PA'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: date, firstDate: now, lastDate: DateTime(now.year + 2));
              if (picked != null) setDialogState(() => date = DateTime(picked.year, picked.month, picked.day));
            },
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showTimePicker(context: context, initialTime: time);
              if (picked != null) setDialogState(() => time = picked);
            },
            icon: const Icon(Icons.schedule_outlined),
            label: Text(time.format(context)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, DateTime(date.year, date.month, date.day, time.hour, time.minute)), child: const Text('Programar')),
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
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Solicitar finalización de PA'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          RadioListTile<String>(value: 'LISTO', groupValue: reason, onChanged: (value) => setDialogState(() => reason = value!), title: const Text('El proyecto está listo')),
          RadioListTile<String>(value: 'SIN_ATENCION', groupValue: reason, onChanged: (value) => setDialogState(() => reason = value!), title: const Text('Los estudiantes dejaron de responder')),
          const Text('El docente líder revisará el reporte antes de confirmar el cierre.'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, reason), child: const Text('Enviar al líder')),
        ],
      )),
    );
    if (selected == null) return;
    try {
      await ref.read(dioProvider).post(
        '/api/docente/tutorias-colectivas/${Uri.encodeComponent(widget.tutoringId)}'
        '/proyectos/${Uri.encodeComponent(widget.projectId)}/solicitud-cierre',
        data: {'motivo': selected},
      );
      await _load();
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _apiMessage(error));
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final extension = file.extension?.toLowerCase();
    if (!const {'pdf', 'docx'}.contains(extension) || file.bytes == null) {
      setState(() => _error = 'Selecciona un archivo PDF o Word válido.');
      return;
    }
    setState(() {
      _attachment = file;
      _error = null;
    });
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_apiMessage(error))));
    } on FormatException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
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
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (widget.teacherMode && widget.supportMode && _projectState?['estadoCierre'] != 'FINALIZADO')
              PopupMenuButton<String>(
                tooltip: 'Acciones del proyecto',
                onSelected: (value) => value == 'reunion' ? _scheduleMeeting() : _requestProjectClosure(),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'reunion', child: Text('Programar reunión')),
                  if (_projectState?['estadoCierre'] == 'EN_CURSO')
                    const PopupMenuItem(value: 'cierre', child: Text('Solicitar finalizar PA')),
                ],
              ),
          ],
        ),
        body: Column(children: [
          if (_projectState != null) _projectWorkflowBanner(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _messages.isEmpty
                    ? Center(child: Text(_error!))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_messages.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('Inicia la conversación sobre este reporte.'),
                            ),
                          for (final message in _messages) _messageBubble(message),
                        ],
                      ),
          ),
          if (_error != null && _messages.isNotEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          if (_attachment != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.attach_file),
              title: Text(_attachment!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(onPressed: () => setState(() => _attachment = null), icon: const Icon(Icons.close)),
            ),
          if (_projectState?['estadoCierre'] != 'FINALIZADO') SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                IconButton(tooltip: 'Adjuntar PDF o Word', onPressed: _sending ? null : _pickFile, icon: const Icon(Icons.attach_file)),
                Expanded(child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  decoration: const InputDecoration(hintText: 'Escribe una respuesta…', border: OutlineInputBorder(), counterText: ''),
                )),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
              ]),
            ),
          ),
        ]),
      );

  Widget _projectWorkflowBanner() {
    final state = _projectState?['estadoCierre']?.toString() ?? 'EN_CURSO';
    final meeting = DateTime.tryParse(_projectState?['fechaReunion']?.toString() ?? '')?.toLocal();
    final reason = _projectState?['motivoCierre']?.toString();
    final status = state == 'FINALIZADO'
        ? 'Proyecto finalizado por el docente líder.'
        : state == 'PENDIENTE_CONFIRMACION'
            ? 'Cierre pendiente de revisión del docente líder${reason == 'SIN_ATENCION' ? ' · motivo: falta de atención' : ' · motivo: proyecto listo'}.'
            : 'Proyecto en curso.';
    return Container(
      width: double.infinity,
      color: const Color(0xFFE8F3FF),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text('$status${meeting == null ? '' : '\nReunión: ${meeting.day.toString().padLeft(2, '0')}/${meeting.month.toString().padLeft(2, '0')}/${meeting.year} ${TimeOfDay.fromDateTime(meeting).format(context)}'}'),
    );
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final own = message['propio'] == true;
    final fileName = message['archivoNombre']?.toString();
    final sentAt = DateTime.tryParse(message['enviadoEn']?.toString() ?? '')?.toLocal();
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          color: own ? const Color(0xFFE8F3FF) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(own ? 'Tú' : widget.supportMode ? widget.teacherMode ? 'Estudiante' : 'Tutor' : 'Participante', style: const TextStyle(fontWeight: FontWeight.bold)),
              if ((message['texto']?.toString() ?? '').isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(message['texto'].toString()),
              ),
              if (fileName != null && fileName.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _download(message),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              if (message['tipo'] == 'REUNION') Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.icon(
                  onPressed: _projectState?['estadoCierre'] == 'FINALIZADO'
                      ? null
                      : () => _enterMeeting(),
                  icon: const Icon(Icons.video_call_outlined),
                  label: const Text('Entrar a la reunión de PA'),
                ),
              ),
              if (sentAt != null) Align(
                alignment: Alignment.centerRight,
                child: Text('${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')}/${sentAt.year} ${TimeOfDay.fromDateTime(sentAt).format(context)}', style: Theme.of(context).textTheme.labelSmall),
              ),
            ]),
          ),
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
