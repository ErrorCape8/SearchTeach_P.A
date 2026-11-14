import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/role_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/neu/neu.dart';
import '../../pa/pa_widgets.dart';
import '../admin_controller.dart';

class AdminCertificacionesView extends ConsumerStatefulWidget {
  const AdminCertificacionesView({super.key});

  @override
  ConsumerState<AdminCertificacionesView> createState() =>
      _AdminCertificacionesViewState();
}

class _AdminCertificacionesViewState
    extends ConsumerState<AdminCertificacionesView> {
  List<_Certification> _items = const [];
  final Set<String> _reviewingIds = {};
  final Set<String> _openingPdfIds = {};
  bool _loading = true;
  String? _error;
  String _selectedStatus = 'PENDIENTE';

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
          .get<List<dynamic>>('/api/admin/certificaciones');
      final data = response.data;
      if (data == null) {
        throw const FormatException(
          'El servidor no devolvió solicitudes de certificación.',
        );
      }
      final items = data.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException(
            'El servidor devolvió una solicitud de certificación inválida.',
          );
        }
        return _Certification.fromJson(item);
      }).toList(growable: false);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } on DioException catch (error) {
      if (mounted) {
        setState(() {
          _error = _apiError(error);
          _loading = false;
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _review(_Certification certification, String status,
      {bool confirm = true}) async {
    final approved = status == 'APROBADA';
    final confirmed = !confirm ? true : await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            Text(approved ? 'Aceptar certificación' : 'Rechazar certificación'),
        content: Text(
          approved
              ? '¿Confirmas que deseas aceptar esta certificación?'
              : '¿Confirmas que deseas rechazar esta certificación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  approved ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
            ),
            child: Text(approved ? 'Aceptar' : 'Rechazar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _reviewingIds.add(certification.id));
    try {
      await ref.read(dioProvider).patch<void>(
        '/api/admin/certificaciones/${Uri.encodeComponent(certification.id)}',
        queryParameters: {'estado': status},
      );
      await _load();
      if (mounted && _error == null) {
        _showMessage('Estado de certificación actualizado.');
      }
    } on DioException catch (error) {
      if (mounted) _showMessage(_apiError(error), isError: true);
    } finally {
      if (mounted) setState(() => _reviewingIds.remove(certification.id));
    }
  }

  Future<void> _openPdf(_Certification certification) async {
    setState(() => _openingPdfIds.add(certification.id));
    try {
      final response = await ref.read(dioProvider).get<List<int>>(
            '/api/admin/certificaciones/${Uri.encodeComponent(certification.id)}/pdf',
            options: Options(responseType: ResponseType.bytes),
          );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException(
          'El servidor devolvió un PDF vacío o inválido.',
        );
      }
      final uri = Uri.dataFromBytes(bytes, mimeType: 'application/pdf');
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw const FormatException(
          'No se encontró una aplicación para abrir el PDF.',
        );
      }
    } on DioException catch (error) {
      if (mounted) _showMessage(_apiError(error), isError: true);
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } on PlatformException catch (error) {
      if (mounted) {
        _showMessage(
          error.message ?? 'No se pudo abrir el documento PDF.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _openingPdfIds.remove(certification.id));
    }
  }

  /// «Ver PDF y revisar»: abre el soporte y luego pide la decisión.
  Future<void> _openAndReview(_Certification certification) async {
    await _openPdf(certification);
    if (!mounted || certification.estado.toUpperCase() != 'PENDIENTE') return;
    final status = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revisar certificación'),
        content: const Text('¿Qué decides sobre esta certificación?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar')),
          OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, 'RECHAZADA'),
              child: const Text('Rechazar')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'APROBADA'),
              child: const Text('Aceptar')),
        ],
      ),
    );
    if (status != null && mounted) {
      await _review(certification, status, confirm: false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    RoleToast.showSnackBar(
      context,
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
      ),
    );
  }

  String _apiError(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'No se pudo completar la operación. Revisa tu conexión e inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    // Al actualizar desde la cabecera se recarga también esta lista.
    ref.listen(adminPendingCertificationsProvider, (_, __) {
      if (mounted) _load();
    });
    final users = ref.watch(adminControllerProvider).users;
    const keys = ['PENDIENTE', 'APROBADA', 'RECHAZADA'];
    const names = ['Pendientes', 'Aceptados', 'Rechazados'];
    int count(String k) =>
        _items.where((i) => i.estado.toUpperCase() == k).length;
    final selected = keys.indexOf(_selectedStatus);
    final filtered = _items
        .where((item) => item.estado.toUpperCase() == _selectedStatus)
        .toList(growable: false);

    return ListView(
      padding: EdgeInsets.fromLTRB(
          18, 4, 18, 32 + MediaQuery.paddingOf(context).bottom),
      children: [
        PaSegmented(
          labels: [for (var i = 0; i < 3; i++) '${names[i]} (${count(keys[i])})'],
          selected: selected,
          onSelect: (i) => setState(() => _selectedStatus = keys[i]),
        ),
        if (_error != null) ...[
          PaInfo(_error!, tone: PaTone.error),
          NeuButton('Reintentar',
              kind: NeuButtonKind.alt,
              icon: Icons.refresh_rounded,
              onPressed: _load),
        ] else if (_loading && _items.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(36),
              child: CircularProgressIndicator(color: Color(0xFFEA580C)),
            ),
          )
        else if (filtered.isEmpty)
          PaEmpty(_loading
              ? 'Cargando solicitudes…'
              : 'No hay ${names[selected].toLowerCase()} por mostrar.')
        else
          for (final item in filtered)
            _CertificationCard(
              certification: item,
              teacherName: users
                      .where((user) => user.id == item.docenteId)
                      .map((user) => user.nombre)
                      .firstOrNull ??
                  item.docenteId,
              isBusy: _reviewingIds.contains(item.id) ||
                  _openingPdfIds.contains(item.id),
              onOpen: () => _openAndReview(item),
            ),
      ],
    );
  }
}

class _Certification {
  const _Certification({
    required this.id,
    required this.docenteId,
    required this.dondeLaDio,
    required this.lugar,
    required this.duracion,
    required this.nombreArchivo,
    required this.estado,
    required this.creadaEn,
  });

  final String id;
  final String docenteId;
  final String dondeLaDio;
  final String lugar;
  final String duracion;
  final String nombreArchivo;
  final String estado;
  final String creadaEn;

  factory _Certification.fromJson(Map<String, dynamic> json) {
    String readString(String key) {
      final value = json[key];
      if (value is! String) {
        throw FormatException(
            'El campo "$key" de la certificación es inválido.');
      }
      return value;
    }

    return _Certification(
      id: readString('id'),
      docenteId: readString('docenteId'),
      dondeLaDio: readString('dondeLaDio'),
      lugar: readString('lugar'),
      duracion: readString('duracion'),
      nombreArchivo: readString('nombreArchivo'),
      estado: readString('estado'),
      creadaEn: readString('creadaEn'),
    );
  }
}

class _CertificationCard extends StatelessWidget {
  const _CertificationCard({
    required this.certification,
    required this.teacherName,
    required this.isBusy,
    required this.onOpen,
  });

  final _Certification certification;
  final String teacherName;
  final bool isBusy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final estado = certification.estado.toUpperCase();
    final pending = estado == 'PENDIENTE';
    final (label, tone) = switch (estado) {
      'APROBADA' => ('Aceptada', PaTone.ok),
      'RECHAZADA' => ('Rechazada', PaTone.error),
      _ => ('Pendiente', PaTone.warn),
    };
    final detalle = [
      'Certificado de tutorías dictadas',
      if (certification.dondeLaDio.isNotEmpty) certification.dondeLaDio,
      if (certification.lugar.isNotEmpty) certification.lugar,
    ].join(' · ');
    Widget field(String title, String value) => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Neu.line))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(),
                style: neuBody(size: 11, color: Neu.muted, letterSpacing: .4)),
            const SizedBox(height: 2),
            Text(value, style: neuBody(size: 15, weight: FontWeight.w700)),
          ]),
        );
    return PaCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(teacherName,
                  style: neuPoppins(size: 16, weight: FontWeight.w700))),
          PaTag(label, tone: tone),
        ]),
        const SizedBox(height: 4),
        Text(detalle, style: neuBody(size: 14, color: Neu.muted, height: 1.35)),
        const SizedBox(height: 8),
        field('Horas de tutoría dictadas', certification.duracion),
        field('Archivo subido por el docente', certification.nombreArchivo),
        const SizedBox(height: 10),
        NeuButton(
          pending ? 'Ver PDF y revisar' : 'Ver PDF',
          icon: Icons.description_outlined,
          onPressed: isBusy ? null : onOpen,
        ),
      ]),
    );
  }
}
