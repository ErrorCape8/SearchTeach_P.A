import 'package:flutter/material.dart';
import '../../../core/widgets/profile_security_dialogs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pa/pa_widgets.dart';
import '../admin_controller.dart';

class AdminPerfilView extends ConsumerWidget {
  const AdminPerfilView({super.key});

  Future<void> _showEditPhoneDialog(
    BuildContext context,
    WidgetRef ref,
    String currentPhone,
  ) async {
    final updated = await showChangePhoneDialog(
      context,
      ref,
      currentPhone: currentPhone,
    );
    if (updated) {
      ref.read(adminControllerProvider.notifier).loadProfile();
    }
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
            onTap: () => showChangePasswordDialog(context, ref),
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
      ],
    );
  }
}
