import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/widgets/role_toast.dart';
import '../pa/pa_widgets.dart';
import 'director_widgets.dart';

/// Perfil de la cuenta. Si el backend no devuelve datos para este rol la
/// pantalla sigue funcionando y muestra "No disponible" en cada campo.
final directorProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  try {
    final response = await ref.read(dioProvider).get<Map<String, dynamic>>(
          '/api/usuarios/perfil',
          options: Options(extra: const {'skipGlobalError': true}),
        );
    return response.data;
  } on DioException {
    return null;
  }
});

String profileText(Map<String, dynamic>? data, String key) {
  final value = data?[key];
  return value is String && value.trim().isNotEmpty ? value : 'No disponible';
}

String initialsOf(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'DP';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
      .toUpperCase();
}

class DirPerfilView extends ConsumerWidget {
  const DirPerfilView({required this.onLogout, super.key});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(directorProfileProvider);
    if (async.isLoading && !async.hasValue) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final data = async.asData?.value;
    final phone = profileText(data, 'telefono');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PaSection('Datos que puedes editar'),
      PaCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DirRow(
          icon: Icons.phone_outlined,
          title: phone,
          subtitle: 'Teléfono',
          onTap: () => _editPhone(context, ref, phone),
        ),
      ),
      const PaSection('Seguridad'),
      PaCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DirRow(
          icon: Icons.lock_outline_rounded,
          title: 'Cambiar contraseña',
          subtitle: 'Mínimo 8 caracteres.',
          onTap: () => _changePassword(context, ref),
        ),
      ),
      const PaSection('Datos institucionales'),
      PaRowList([
        _locked('Correo', profileText(data, 'correo')),
        _locked('Documento', profileText(data, 'id')),
        _locked('Programa', profileText(data, 'carrera')),
        _locked('Rol', profileText(data, 'rol')),
      ]),
      const SizedBox(height: 6),
      Text('Estos datos los gestiona la institución y no se pueden editar.',
          style: neuBody(size: 12.5, color: Neu.muted)),
      const SizedBox(height: 18),
      NeuButton('Cerrar sesión',
          kind: NeuButtonKind.alt,
          icon: Icons.logout_rounded,
          onPressed: onLogout),
    ]);
  }

  Widget _locked(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          const NeuIconBox(Icons.lock_outline_rounded,
              size: 44, radius: 14, iconSize: 21),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: neuPoppins(size: 15.5)),
              const SizedBox(height: 2),
              Text(value, style: neuBody(size: 13, color: Neu.muted)),
            ]),
          ),
        ]),
      );

  // ── Diálogos ──────────────────────────────────────────────────────────────

  String _message(DioException error) {
    final data = error.response?.data;
    return data is Map && data['message'] is String
        ? data['message'] as String
        : 'No se pudo actualizar la información.';
  }

  void _toast(BuildContext context, String message) =>
      RoleToast.showSnackBar(context, SnackBar(content: Text(message)));

  Future<void> _editPhone(
      BuildContext context, WidgetRef ref, String current) async {
    final controller =
        TextEditingController(text: current == 'No disponible' ? '' : current);
    final value = await _neuDialog<String>(
      context,
      title: 'Editar teléfono',
      fields: [
        NeuField(
            controller: controller,
            hint: 'Teléfono',
            keyboardType: TextInputType.phone),
      ],
      confirmLabel: 'Guardar',
      onConfirm: (ctx) => controller.text.trim(),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await ref
          .read(dioProvider)
          .patch('/api/usuarios/perfil/telefono', data: {'telefono': value});
      ref.invalidate(directorProfileProvider);
      if (context.mounted) _toast(context, 'Teléfono actualizado.');
    } on DioException catch (error) {
      if (context.mounted) _toast(context, _message(error));
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final done = await _neuDialog<bool>(
      context,
      title: 'Cambiar contraseña',
      fields: [
        NeuField(
            controller: current, hint: 'Contraseña actual', obscure: true),
        const SizedBox(height: 10),
        NeuField(controller: next, hint: 'Nueva contraseña', obscure: true),
      ],
      confirmLabel: 'Guardar',
      onConfirm: (ctx) {
        if (current.text.isEmpty || next.text.length < 8) {
          _toast(ctx, 'La nueva contraseña debe tener mínimo 8 caracteres.');
          return null;
        }
        return true;
      },
    );
    final currentText = current.text;
    final nextText = next.text;
    current.dispose();
    next.dispose();
    if (done != true) return;
    try {
      await ref.read(dioProvider).patch('/api/usuarios/perfil/contrasena',
          data: {
            'contrasenaActual': currentText,
            'nuevaContrasena': nextText,
          });
      if (context.mounted) _toast(context, 'Contraseña actualizada.');
    } on DioException catch (error) {
      if (context.mounted) _toast(context, _message(error));
    }
  }
}

/// Diálogo con la estética neumórfica. [onConfirm] devuelve el valor a cerrar
/// o `null` para mantenerlo abierto.
Future<T?> _neuDialog<T>(
  BuildContext context, {
  required String title,
  required List<Widget> fields,
  required String confirmLabel,
  required T? Function(BuildContext) onConfirm,
}) =>
    showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Neu.bg,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: neuPoppins(size: 17, color: Neu.heading)),
                const SizedBox(height: 16),
                ...fields,
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: NeuButton('Cancelar',
                        kind: NeuButtonKind.alt,
                        small: true,
                        onPressed: () => Navigator.pop(ctx)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeuButton(confirmLabel,
                        small: true,
                        onPressed: () {
                          final result = onConfirm(ctx);
                          if (result != null) Navigator.pop(ctx, result);
                        }),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
