import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/auth_repository.dart';
import '../../auth/profile_change_dialog.dart';
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
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('El teléfono es obligatorio.')),
                );
                return;
              }
              final saved = await ref
                  .read(adminControllerProvider.notifier)
                  .updateAdminPhone(newPhone);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
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

  void _showChangePasswordDialog(BuildContext context) {
    final passCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cambiar contraseña',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Nueva contraseña',
            helperText: 'Mínimo 8 caracteres.',
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
            onPressed: () {
              if (passCtrl.text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Debe tener al menos 8 caracteres.')),
                );
                return;
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contraseña actualizada con éxito.'),
                  backgroundColor: Color(0xFF16A34A),
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
    String showValue(String? value) {
      if (value == null) return 'Cargando…';
      return value.isEmpty ? 'No registrado' : value;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        if (state.profileError != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.profileError!),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(adminControllerProvider.notifier).loadProfile(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        // Datos que puedes editar
        const Text(
          'Datos que puedes editar',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: state.isLoadingProfile || profile == null
              ? null
              : () => showProfileChangeDialog(context, ref,
                    field: ProfileChangeField.phone,
                    onUpdated: () => ref.read(adminControllerProvider.notifier).loadProfile()),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.phone_outlined,
                    color: Color(0xFFEA580C),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showValue(profile?.telefono),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Teléfono',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),

        // Seguridad
        const Text(
          'Seguridad',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => showProfileChangeDialog(context, ref,
              field: ProfileChangeField.password,
              onUpdated: () => ref.read(adminControllerProvider.notifier).loadProfile()),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFFEA580C),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cambiar contraseña',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Mínimo 8 caracteres.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),

        // Datos institucionales
        const Text(
          'Correo actual y datos institucionales',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildInstitutionalRow(
                title: 'Correo',
                value: showValue(profile?.correo),
                onTap: () => showProfileChangeDialog(context, ref,
                    field: ProfileChangeField.email,
                    onUpdated: () => ref.read(adminControllerProvider.notifier).loadProfile()),
              ),
              const Divider(height: 18, color: Color(0xFFF1F5F9)),
              _buildInstitutionalRow(
                title: 'Documento',
                value: showValue(profile?.documento),
              ),
              const Divider(height: 18, color: Color(0xFFF1F5F9)),
              _buildInstitutionalRow(
                title: 'Programa',
                value: showValue(profile?.programa),
              ),
              const Divider(height: 18, color: Color(0xFFF1F5F9)),
              _buildInstitutionalRow(
                title: 'Rol',
                value: showValue(profile?.rol),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'El correo actual recibe los códigos de seguridad. Puedes solicitar su cambio con verificación.',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 26),

        // Botón Cerrar sesión
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEE2E2),
              foregroundColor: const Color(0xFF991B1B),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstitutionalRow({
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFFEA580C),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.edit_outlined, color: Color(0xFFEA580C), size: 19),
        ],
      ),
      ),
    );
  }
}
