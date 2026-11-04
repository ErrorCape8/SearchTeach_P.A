import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

class AdminCertificacionesView extends ConsumerStatefulWidget {
  const AdminCertificacionesView({super.key});
  @override
  ConsumerState<AdminCertificacionesView> createState() =>
      _AdminCertificacionesViewState();
}

class _AdminCertificacionesViewState
    extends ConsumerState<AdminCertificacionesView> {
  List<dynamic> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get<List<dynamic>>('/api/admin/certificaciones');
      if (mounted) {
        setState(() {
          _items = response.data ?? const [];
          _loading = false;
        });
      }
    } on DioException {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(String id, String status) async {
    await ref.read(dioProvider).patch('/api/admin/certificaciones/$id',
        queryParameters: {'estado': status});
    await _load();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Certificaciones docentes',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
              'Investiga cada soporte y acepta o rechaza su aplicación.'),
          if (_loading) const LinearProgressIndicator(),
          for (final item in _items)
            Card(
              child: ListTile(
                title: Text(
                    '${item['dondeLaDio'] ?? ''} · ${item['lugar'] ?? ''}'),
                subtitle: Text(
                    'Docente: ${item['docenteId'] ?? ''}\nDuración: ${item['duracion'] ?? ''}\nEstado: ${item['estado'] ?? ''}'),
                isThreeLine: true,
                trailing: item['estado'] == 'PENDIENTE'
                    ? Wrap(children: [
                        IconButton(
                          tooltip: 'Aceptar',
                          color: Colors.green,
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () =>
                              _review(item['id'] as String, 'APROBADA'),
                        ),
                        IconButton(
                          tooltip: 'Rechazar',
                          color: Colors.red,
                          icon: const Icon(Icons.cancel_outlined),
                          onPressed: () =>
                              _review(item['id'] as String, 'RECHAZADA'),
                        ),
                      ])
                    : null,
              ),
            ),
        ],
      );
}
