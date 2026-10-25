import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class TutoriaChatPage extends ConsumerStatefulWidget {
  const TutoriaChatPage({
    required this.sessionId,
    required this.subject,
    this.readOnly = false,
    super.key,
  });

  final String sessionId;
  final String subject;
  final bool readOnly;

  @override
  ConsumerState<TutoriaChatPage> createState() => _TutoriaChatPageState();
}

class _TutoriaChatPageState extends ConsumerState<TutoriaChatPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  String get _path =>
      '/api/tutorias/grupales/${Uri.encodeComponent(widget.sessionId)}/chat';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages());
  }

  Future<void> _loadMessages() async {
    try {
      final response = await ref.read(dioProvider).get<List<dynamic>>(_path);
      if (!mounted) return;
      setState(() {
        _messages = (response.data ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _apiMessage(error);
      });
    }
  }

  Future<void> _send() async {
    final message = _text.text.trim();
    if (message.isEmpty || _sending || widget.readOnly) return;
    setState(() => _sending = true);
    try {
      await ref.read(dioProvider).post(_path, data: {'texto': message});
      _text.clear();
      await _loadMessages();
    } on DioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_apiMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _apiMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'No se pudo cargar el chat de la tutoría.';
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Chat · ${widget.subject}')),
        body: Column(children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _loadMessages,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final name = message['nombre']?.toString() ?? 'Participante';
                          final text = message['texto']?.toString() ?? '';
                          final sent = message['enviadoEn']?.toString();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(name,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(text),
                              trailing: sent == null
                                  ? null
                                  : Text(sent.replaceFirst('T', ' '),
                                      style: Theme.of(context).textTheme.bodySmall),
                            ),
                          );
                        },
                      ),
          ),
          if (widget.readOnly)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Esta tutoría finalizó. El chat está disponible para consulta.'),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Escribe un mensaje',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    tooltip: 'Enviar mensaje',
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ]),
              ),
            ),
        ]),
      );
}
