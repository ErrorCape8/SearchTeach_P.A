import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/role_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
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

  Future<void> _review(_Certification certification, String status) async {
    final approved = status == 'APROBADA';
    final confirmed = await showDialog<bool>(
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
    final users = ref.watch(adminControllerProvider).users;
    final filtered = _items
        .where((item) => item.estado.toUpperCase() == _selectedStatus)
        .toList(growable: false);
    final statusLabels = const {
      'PENDIENTE': 'Pendientes',
      'APROBADA': 'Aceptadas',
      'RECHAZADA': 'Rechazadas',
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 14, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Certificaciones docentes',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar solicitudes',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                color: const Color(0xFFEA7408),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                for (final entry in statusLabels.entries)
                  ChoiceChip(
                    label: Text(
                      '${entry.value} (${_items.where((item) => item.estado.toUpperCase() == entry.key).length})',
                    ),
                    selected: _selectedStatus == entry.key,
                    selectedColor: const Color(0xFFFFE6D1),
                    labelStyle: TextStyle(
                      color: _selectedStatus == entry.key
                          ? const Color(0xFFB45309)
                          : const Color(0xFF475569),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) =>
                        setState(() => _selectedStatus = entry.key),
                  ),
              ],
            ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _loading
                              ? 'Cargando solicitudes…'
                              : 'No hay ${statusLabels[_selectedStatus]?.toLowerCase()} por mostrar.',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final teacherName = users
                                  .where((user) => user.id == item.docenteId)
                                  .map((user) => user.nombre)
                                  .firstOrNull ??
                              item.docenteId;
                          final isPending =
                              item.estado.toUpperCase() == 'PENDIENTE';
                          return _CertificationCard(
                            certification: item,
                            teacherName: teacherName,
                            isReviewing: _reviewingIds.contains(item.id),
                            isOpeningPdf: _openingPdfIds.contains(item.id),
                            onOpenPdf: () => _openPdf(item),
                            onApprove: isPending
                                ? () => _review(item, 'APROBADA')
                                : null,
                            onReject: isPending
                                ? () => _review(item, 'RECHAZADA')
                                : null,
                          );
                        },
                      ),
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
    required this.isReviewing,
    required this.isOpeningPdf,
    required this.onOpenPdf,
    required this.onApprove,
    required this.onReject,
  });

  final _Certification certification;
  final String teacherName;
  final bool isReviewing;
  final bool isOpeningPdf;
  final VoidCallback onOpenPdf;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final stateColor = switch (certification.estado.toUpperCase()) {
      'APROBADA' => const Color(0xFF15803D),
      'RECHAZADA' => const Color(0xFFB91C1C),
      _ => const Color(0xFFB45309),
    };
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE7EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    certification.dondeLaDio,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    certification.estado,
                    style: TextStyle(
                      color: stateColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Docente: $teacherName',
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${certification.lugar} · ${certification.duracion}'
              '${certification.creadaEn.isEmpty ? '' : ' · ${certification.creadaEn}'}',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: isOpeningPdf ? null : onOpenPdf,
                  icon: isOpeningPdf
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 15),
                  label: Text(isOpeningPdf ? 'Abriendo…' : 'Ver PDF'),
                ),
                if (onApprove != null)
                  FilledButton.tonalIcon(
                    onPressed: isReviewing ? null : onApprove,
                    icon: const Icon(Icons.check, size: 15),
                    label: const Text('Aceptar'),
                  ),
                if (onReject != null)
                  TextButton.icon(
                    onPressed: isReviewing ? null : onReject,
                    icon: const Icon(Icons.close, size: 15),
                    label: const Text('Rechazar'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C),
                    ),
                  ),
                if (isReviewing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
