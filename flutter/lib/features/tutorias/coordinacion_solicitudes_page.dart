import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

const _wine = Color(0xFFA9154F);
const _muted = Color(0xFF758093);

class CoordinacionSolicitudesPage extends ConsumerStatefulWidget {
  const CoordinacionSolicitudesPage({super.key});

  @override
  ConsumerState<CoordinacionSolicitudesPage> createState() =>
      _CoordinacionSolicitudesPageState();
}

class _CoordinacionSolicitudesPageState
    extends ConsumerState<CoordinacionSolicitudesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(dioProvider)
          .get<List<dynamic>>('/api/coordinacion/solicitudes-cambio-fecha');
      if (!mounted) return;
      setState(() {
        _requests = (response.data ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      setState(() {
        _error = data is Map && data['message'] is String
            ? data['message'] as String
            : 'No se pudieron cargar las solicitudes.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _wine));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
          ),
        ]),
      );
    }
    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 150),
          Icon(Icons.inbox_outlined, size: 52, color: _muted),
          SizedBox(height: 12),
          Center(child: Text('No hay solicitudes pendientes.')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) => _requestCard(_requests[index]),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> item) {
    final oldStart = _parse(item['fechaInicioOriginal']);
    final oldEnd = _parse(item['fechaFinOriginal']);
    final desiredStart = _parse(item['fechaInicioSolicitada']);
    final desiredEnd = _parse(item['fechaFinSolicitada']);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDDE4EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFFCE7EF),
              child: Icon(Icons.person_outline, color: _wine),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_value(item['docenteNombre'], 'Docente'),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(_value(item['materia'], 'Tutoría'),
                        style: const TextStyle(color: _muted)),
                  ]),
            ),
            const Chip(label: Text('Pendiente')),
          ]),
          const SizedBox(height: 14),
          Text('Horario actual: ${_format(oldStart)} – ${_format(oldEnd)}'),
          const SizedBox(height: 4),
          Text('Solicita: ${_format(desiredStart)} – ${_format(desiredEnd)}'),
          const SizedBox(height: 12),
          Text('Motivo: ${_value(item['motivo'], 'Sin motivo')}',
              style: const TextStyle(color: _muted, height: 1.35)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _wine),
              onPressed: () => _accept(item, desiredStart),
              icon: const Icon(Icons.check),
              label: const Text('Aceptar'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: _wine),
              onPressed: () => _deny(item),
              icon: const Icon(Icons.close),
              label: const Text('Denegar'),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _accept(Map<String, dynamic> item, DateTime requested) async {
    var assignLater = false;
    var start = requested;
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Aceptar solicitud'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('Fecha y hora'),
                    icon: Icon(Icons.schedule)),
                ButtonSegment(
                    value: true,
                    label: Text('Más tarde'),
                    icon: Icon(Icons.event_busy_outlined)),
              ],
              selected: {assignLater},
              onSelectionChanged: (selection) =>
                  setDialogState(() => assignLater = selection.first),
            ),
            if (assignLater)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                    'Se eliminará esta tutoría para asignar otra después.'),
              ),
            if (!assignLater) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: start.isAfter(DateTime.now())
                        ? start
                        : DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (date != null) {
                    setDialogState(() => start = DateTime(date.year, date.month,
                        date.day, start.hour, start.minute));
                  }
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_date(start)),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(start));
                  if (time != null) {
                    setDialogState(() => start = DateTime(start.year,
                        start.month, start.day, time.hour, time.minute));
                  }
                },
                icon: const Icon(Icons.schedule),
                label: Text(TimeOfDay.fromDateTime(start).format(context)),
              ),
            ],
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Volver')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, assignLater),
                child: const Text('Confirmar')),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final action = choice ? 'ASIGNAR_MAS_TARDE' : 'REPROGRAMAR';
    await _resolve(item, {
      'accion': action,
      if (!choice) 'fechaInicio': start.toIso8601String(),
    });
  }

  Future<void> _deny(Map<String, dynamic> item) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Denegar solicitud'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration:
                const InputDecoration(labelText: 'Motivo de la denegación'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Escribe el motivo.'
                : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Volver')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Denegar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    await _resolve(item, {'accion': 'DENEGAR', 'motivoDenegacion': reason});
  }

  Future<void> _resolve(
      Map<String, dynamic> item, Map<String, dynamic> body) async {
    try {
      await ref.read(dioProvider).patch(
            '/api/coordinacion/solicitudes-cambio-fecha/${item['id']}',
            data: body,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Solicitud atendida.')));
      await _load();
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'No se pudo resolver la solicitud.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  static DateTime _parse(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  static String _value(dynamic value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value : fallback;
  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  static String _format(DateTime value) =>
      '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
