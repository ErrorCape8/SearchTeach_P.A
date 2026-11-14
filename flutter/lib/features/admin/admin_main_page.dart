import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/neu/neu.dart';
import '../../core/role_theme.dart';
import '../../core/tutoring_updates.dart';
import '../auth/auth_repository.dart';
import 'admin_controller.dart';
import 'views/admin_certificaciones_view.dart';
import 'views/admin_detalle_usuario_view.dart';
import 'views/admin_editar_usuario_view.dart';
import 'views/admin_inicio_view.dart';
import 'views/admin_perfil_view.dart';
import 'views/admin_usuarios_view.dart';

const _orange = Color(0xFFEA580C);

/// Pestañas del controlador en el orden del menú: Inicio, Usuarios,
/// Certificados y Perfil.
const _navTabs = [0, 1, 3, 2];

class AdminMainPage extends ConsumerWidget {
  const AdminMainPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(tutoringUpdatesProvider, (_, next) {
      if (next.hasValue) {
        ref.read(adminControllerProvider.notifier).refreshDashboard();
      }
    });
    final state = ref.watch(adminControllerProvider);
    final notifier = ref.read(adminControllerProvider.notifier);
    final pending =
        ref.watch(adminPendingCertificationsProvider).valueOrNull ?? 0;

    final hasSelectedUser = state.selectedUser != null;
    final isEditing = hasSelectedUser && state.isEditingSelectedUser;
    final name = state.adminProfile?.nombre ?? 'Admin TI';

    String title;
    String subtitle;
    if (isEditing) {
      title = 'Editar usuario';
      subtitle = state.selectedUser!.nombre;
    } else if (hasSelectedUser) {
      title = state.selectedUser!.nombre;
      subtitle = state.selectedUser!.rol;
    } else {
      (title, subtitle) = switch (state.activeTab) {
        1 => ('Usuarios', 'Cuentas y roles'),
        2 => (
            state.adminProfile?.nombre ?? 'Perfil de TI',
            state.adminProfile?.rol ??
                (state.isLoadingProfile
                    ? 'Cargando perfil…'
                    : 'Perfil no disponible')
          ),
        3 => ('Certificados', 'Solicitudes de certificado de los docentes'),
        _ => ('Panel de TI', 'Administrador del sistema'),
      };
    }

    final Widget body;
    if (isEditing) {
      body = AdminEditarUsuarioView(
        user: state.selectedUser!,
        onDone: () => notifier.clearSelectedUser(),
      );
    } else if (hasSelectedUser) {
      body = AdminDetalleUsuarioView(
        user: state.selectedUser!,
        onEdit: notifier.editSelectedUser,
      );
    } else {
      body = switch (state.activeTab) {
        1 => const AdminUsuariosView(),
        2 => const AdminPerfilView(),
        3 => const AdminCertificacionesView(),
        _ => AdminInicioView(onOpenCertifications: () => notifier.setTab(3)),
      };
    }

    Future<void> logout() async {
      await ref.read(authRepositoryProvider).logout();
      if (context.mounted) context.go('/login');
    }

    final theme = withRoleAccent(
      Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _orange,
          brightness: Theme.of(context).brightness,
        ).copyWith(primary: _orange),
      ),
      _orange,
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: Neu.bg,
        body: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final currentTab = hasSelectedUser ? 1 : state.activeTab;

          final header = NeuHeader(
            title: title,
            subtitle: subtitle,
            leading: hasSelectedUser
                ? NeuCircleButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Volver',
                    onTap: notifier.clearSelectedUser,
                  )
                : _Avatar(
                    initials: NeuSidebar.initials(name),
                    onTap: () => notifier.setTab(2),
                  ),
            actions: [
              if (wide)
                NeuButton('Actualizar',
                    onPressed: notifier.refreshDashboard,
                    kind: NeuButtonKind.alt,
                    small: true,
                    icon: Icons.refresh_rounded,
                    expand: false)
              else
                NeuCircleButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Actualizar',
                    onTap: notifier.refreshDashboard),
              NeuCircleButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notificaciones',
                badge: pending > 0 ? pending : null,
                onTap: () => context.push('/notificaciones', extra: _orange),
              ),
            ],
          );

          final content = Column(children: [
            header,
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(hasSelectedUser
                          ? '${isEditing ? 'edit' : 'detail'}_${state.selectedUser?.id}'
                          : 'tab_${state.activeTab}'),
                      child: body,
                    ),
                  ),
                ),
              ),
            ),
          ]);

          if (!wide) return content;
          return Row(children: [
            NeuSidebar(
              items: const [
                (Icons.home_outlined, 'Inicio', 0),
                (Icons.groups_outlined, 'Usuarios', 1),
                (Icons.description_outlined, 'Certificados', 3),
                (Icons.person_outline_rounded, 'Perfil', 2),
              ],
              selected: currentTab,
              onSelect: notifier.setTab,
              name: name,
              userRole: 'Administrador',
              roleLabel: 'Administrador',
              onLogout: logout,
              onUserTap: () => notifier.setTab(2),
            ),
            Expanded(child: content),
          ]);
        }),
        bottomNavigationBar: LayoutBuilder(builder: (context, _) {
          if (MediaQuery.sizeOf(context).width >= 760) {
            return const SizedBox.shrink();
          }
          final currentTab = hasSelectedUser ? 1 : state.activeTab;
          return NeuBottomBar(
            items: [
              const NeuNavItem(Icons.home_outlined, 'Inicio'),
              const NeuNavItem(Icons.groups_outlined, 'Usuarios'),
              NeuNavItem(Icons.description_outlined, 'Certificados',
                  dot: pending > 0),
              const NeuNavItem(Icons.person_outline_rounded, 'Perfil'),
            ],
            index: _navTabs.indexOf(currentTab),
            onSelect: (i) => notifier.setTab(_navTabs[i]),
          );
        }),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.onTap});
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Abrir perfil',
        child: SizedBox(
          width: 46,
          height: 46,
          child: NeuSurface(
            radius: 46,
            shadows: Neu.raiseS,
            onTap: onTap,
            child: Center(
              child: Text(initials,
                  style: neuPoppins(
                      size: 15,
                      weight: FontWeight.w700,
                      color: NeuPalette.of(context).c)),
            ),
          ),
        ),
      );
}
