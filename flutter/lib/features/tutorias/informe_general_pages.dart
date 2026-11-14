import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../pa/pa_widgets.dart';

/// Informes generales que los docentes líderes envían a coordinación.
final informesGeneralesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ref
      .read(dioProvider)
      .get<List<dynamic>>('/api/coordinacion/informes-generales');
  return (response.data ?? const []).whereType<Map<String, dynamic>>().toList();
});

/// Grupos de proyecto de aula (para mostrar carrera, semestre y reportes de apoyo).
final coordinacionGruposProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ref
      .read(dioProvider)
      .get<List<dynamic>>('/api/coordinacion/tutorias-colectivas');
  return (response.data ?? const []).whereType<Map<String, dynamic>>().toList();
});

final _informeCoordinacionProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, tutoriaId) async {
  try {
    final response = await ref.read(dioProvider).get<Map<String, dynamic>>(
          '/api/coordinacion/tutorias-colectivas/'
          '${Uri.encodeComponent(tutoriaId)}/informe-general',
        );
    return response.data;
  } on DioException catch (error) {
    if (error.response?.statusCode == 404) return null;
    rethrow;
  }
});

String _apiMessage(Object error, String fallback) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
  }
  return fallback;
}

String _fecha(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'fecha no disponible';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

Map<String, dynamic>? _grupoPorId(List<Map<String, dynamic>> grupos, String id) {
  for (final grupo in grupos) {
    if (grupo['id']?.toString() == id) return grupo;
  }
  return null;
}

String _tituloGrupo(Map<String, dynamic>? grupo) {
  if (grupo == null) return 'Grupo de proyecto de aula';
  return '${grupo['tecnologia'] ?? 'Carrera'} · Semestre ${grupo['semestre'] ?? '—'}';
}

// ---------------------------------------------------------------------------
// Docente líder: redactar / consultar el informe general
// ---------------------------------------------------------------------------

class InformeGeneralLiderPage extends ConsumerStatefulWidget {
  const InformeGeneralLiderPage({
    required this.assignment,
    required this.onSent,
    super.key,
  });

  final Map<String, dynamic> assignment;
  final VoidCallback onSent;

  @override
  ConsumerState<InformeGeneralLiderPage> createState() =>
      _InformeGeneralLiderPageState();
}

class _InformeGeneralLiderPageState
    extends ConsumerState<InformeGeneralLiderPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _sending = false;
  String? _error;
  Map<String, dynamic>? _informe;

  String get _tutoriaId => widget.assignment['id']?.toString() ?? '';
  String get _path => '/api/docente/lider/tutorias-colectivas/'
      '${Uri.encodeComponent(_tutoriaId)}/informe-general';
  bool get _yaEnviado =>
      widget.assignment['informeGeneralEnviado'] == true || _informe != null;

  @override
  void initState() {
    super.initState();
    if (widget.assignment['informeGeneralEnviado'] == true) _cargar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await ref.read(dioProvider).get<Map<String, dynamic>>(_path);
      if (!mounted) return;
      setState(() {
        _informe = response.data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _apiMessage(error, 'No se pudo cargar el informe.');
        _loading = false;
      });
    }
  }

  Future<void> _enviar() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) {
      paToast(context, 'Escribe el informe antes de enviarlo.');
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enviar informe general'),
        content: const Text(
            'Se enviará a coordinación y no podrás editarlo después. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _sending = true);
    try {
      final response = await ref
          .read(dioProvider)
          .post<Map<String, dynamic>>(_path, data: {'contenido': texto});
      widget.onSent();
      if (!mounted) return;
      setState(() {
        _informe = response.data ??
            {
              'contenido': texto,
              'fechaInforme': DateTime.now().toIso8601String(),
            };
        _sending = false;
      });
      paToast(context, 'Informe enviado a coordinación.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      paToast(context, _apiMessage(error, 'No se pudo enviar el informe.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (_yaEnviado) {
      if (_loading) {
        children.add(const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ));
      } else if (_informe != null) {
        children.add(PaInfo(
          'Enviado a coordinación el ${_fecha(_informe!['fechaInforme'])}.',
          tone: PaTone.ok,
        ));
        children.add(PaCard(
          child: SelectableText(_informe!['contenido']?.toString() ?? ''),
        ));
      } else if (_error != null) {
        children.add(PaInfo(_error!, tone: PaTone.error));
      }
    } else {
      children.add(const PaInfo(
        'Cuenta cómo se vieron y se completaron las tutorías, y cómo fue el '
        'trabajo con los docentes de apoyo y los estudiantes. No podrás '
        'editarlo después de enviarlo.',
      ));
      children.add(TextField(
        controller: _controller,
        enabled: !_sending,
        minLines: 10,
        maxLines: 20,
        maxLength: 12000,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Escribe aquí el informe general del grupo…',
          border: OutlineInputBorder(),
        ),
      ));
      children.add(const SizedBox(height: 12));
      children.add(FilledButton.icon(
        onPressed: _sending ? null : _enviar,
        icon: _sending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send_outlined),
        label: const Text('Enviar a coordinación'),
      ));
    }
    return PaScaffold(
      title: 'Informe general',
      subtitle: _tituloGrupo(widget.assignment),
      children: children,
    );
  }
}

// ---------------------------------------------------------------------------
// Coordinación: lista y detalle de informes
// ---------------------------------------------------------------------------

/// Pestaña «Reportes» del panel de coordinación.
class InformesGeneralesPage extends StatelessWidget {
  const InformesGeneralesPage({this.leading, super.key});
  final Widget? leading;

  @override
  Widget build(BuildContext context) => PaScaffold(
        title: 'Reportes',
        subtitle: 'Informes generales de docentes líderes',
        leading: leading,
        children: const [InformesGeneralesLista()],
      );
}

class InformesGeneralesLista extends ConsumerWidget {
  const InformesGeneralesLista({this.limit, super.key});
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grupos = ref.watch(coordinacionGruposProvider).valueOrNull ??
        const <Map<String, dynamic>>[];
    return ref.watch(informesGeneralesProvider).when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => PaEmpty(
              _apiMessage(error, 'No se pudieron cargar los informes.')),
          data: (lista) {
            final ordenados = [...lista]..sort((a, b) =>
                '${b['fechaInforme']}'.compareTo('${a['fechaInforme']}'));
            final visibles =
                limit == null ? ordenados : ordenados.take(limit!).toList();
            final filas = <Widget>[];
            for (final informe in visibles) {
              final id = informe['tutoriaColectivaId']?.toString() ?? '';
              final grupo = _grupoPorId(grupos, id);
              filas.add(PaRow(
                icon: Icons.inbox_outlined,
                title: _tituloGrupo(grupo),
                subtitle: 'Enviado el ${_fecha(informe['fechaInforme'])}',
                onTap: () => paPush(
                  context,
                  InformeGeneralCoordinacionPage(tutoriaId: id, grupo: grupo),
                ),
              ));
            }
            return PaRowList(filas,
                empty: 'Aún no hay informes generales de líderes.');
          },
        );
  }
}

class InformeGeneralCoordinacionPage extends ConsumerWidget {
  const InformeGeneralCoordinacionPage({
    required this.tutoriaId,
    this.grupo,
    super.key,
  });

  final String tutoriaId;
  final Map<String, dynamic>? grupo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final informe = ref.watch(_informeCoordinacionProvider(tutoriaId));
    final proyectos = (grupo?['proyectos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final conReporte = proyectos
        .where((p) => (p['reporteCierre']?.toString() ?? '').trim().isNotEmpty)
        .toList();

    return PaScaffold(
      title: _tituloGrupo(grupo),
      subtitle: 'Informe general del docente líder',
      children: [
        informe.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => PaInfo(
            _apiMessage(error, 'No se pudo cargar el informe.'),
            tone: PaTone.error,
          ),
          data: (data) => data == null
              ? const PaEmpty('El docente líder aún no ha enviado el informe general.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PaHint('Enviado el ${_fecha(data['fechaInforme'])}'),
                    PaCard(
                      child: SelectableText(
                          data['contenido']?.toString() ?? ''),
                    ),
                  ],
                ),
        ),
        if (conReporte.isNotEmpty) ...[
          const PaSection('Reportes de los docentes de apoyo'),
          for (final proyecto in conReporte)
            PaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proyecto['nombre']?.toString() ?? 'Proyecto de aula',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(proyecto['reporteCierre'].toString()),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
