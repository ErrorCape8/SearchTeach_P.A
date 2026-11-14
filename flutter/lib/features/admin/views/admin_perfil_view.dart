import 'package:flutter/material.dart';
import '../../../core/widgets/role_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/auth_repository.dart';
import '../../../core/neu/neu.dart';
import '../../pa/pa_widgets.dart';
import '../admin_controller.dart';

class AdminPerfilView extends ConsumerWidget {
  const AdminPerfilView({super.key});

  void _showEditPhoneDialog(
    BuildContext context,
    WidgetRef ref,
    String currentPhone,
  ) {
    final controller = TextEditingController(text: currentPhone);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Editar teléfono',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Número de teléfono',
            filled: true,
            fillColor: const Color(0xFFF1F4F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final newPhone = controller.text.trim();
              if (newPhone.isEmpty) {
                RoleToast.showSnackBar(
                  ctx,
                  const SnackBar(content: Text('El teléfono es obligatorio.')),
                );
                return;
              }
              final saved = await ref
                  .read(adminControllerProvider.notifier)
                  .updateAdminPhone(newPhone);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              RoleToast.showSnackBar(
                context,
                SnackBar(
                  content: Text(saved
                      ? 'Teléfono actualizado.'
                      : ref.read(adminControllerProvider).profileError ??
                          'No se pudo actualizar el teléfono.'),
                  backgroundColor:
                      saved ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminControllerProvider);
    final profile = state.adminProfile;
    String show(String? value) {
      if (value == null) return 'Cargando…';
      return value.isEmpty ? '—' : value;
    }

    PaRow locked(String title, String? value) => PaRow(
        icon: Icons.lock_outline_rounded, title: title, subtitle: show(value));

    return ListView(
      padding: EdgeInsets.fromLTRB(
          18, 4, 18, 32 + MediaQuery.paddingOf(context).bottom),
      children: [
        if (state.profileError != null) ...[
          PaInfo(state.profileError!, tone: PaTone.error),
          NeuButton('Reintentar',
              kind: NeuButtonKind.alt,
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.read(adminControllerProvider.notifier).loadProfile()),
        ],
        const PaSection('Datos que puedes editar'),
        PaRowList([
          PaRow(
            icon: Icons.phone_outlined,
            title: show(profile?.telefono),
            subtitle: 'Teléfono',
            onTap: state.isLoadingProfile || profile == null
                ? null
                : () => _showEditPhoneDialog(context, ref, profile.telefono),
          ),
        ]),
        const PaSection('Seguridad'),
        PaRowList([
          PaRow(
            icon: Icons.lock_outline_rounded,
            title: 'Cambiar contraseña',
            subtitle: 'Mínimo 8 caracteres.',
            onTap: () => context.push('/forgot-password'),
          ),
        ]),
        const PaSection('Datos institucionales'),
        PaRowList([
          locked('Correo', profile?.correo),
          locked('Documento', profile?.documento),
          locked('Programa', profile?.programa),
          locked('Rol', profile?.rol),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
          child: Text('Estos datos los gestiona TI.',
              style: neuBody(size: 12.5, color: Neu.muted)),
        ),
        NeuButton(
          'Cerrar sesión',
          kind: NeuButtonKind.danger,
          icon: Icons.logout_rounded,
          onPressed: () async {
            await ref.read(authRepositoryProvider).logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }
}
