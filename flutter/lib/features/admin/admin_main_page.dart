import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/tutoring_updates.dart';
import 'admin_controller.dart';
import 'views/admin_editar_usuario_view.dart';
import 'views/admin_detalle_usuario_view.dart';
import 'views/admin_inicio_view.dart';
import 'views/admin_perfil_view.dart';
import 'views/admin_usuarios_view.dart';
import 'views/admin_certificaciones_view.dart';
import 'widgets/admin_bottom_bar.dart';
import 'widgets/admin_header.dart';
import 'widgets/admin_role_summary.dart';

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

    final hasSelectedUser = state.selectedUser != null;
    final isEditing = hasSelectedUser && state.isEditingSelectedUser;

    final String headerTitle;
    final String headerSubtitle;

    if (isEditing) {
      headerTitle = 'Editar usuario';
      headerSubtitle = state.selectedUser!.nombre;
    } else if (hasSelectedUser) {
      headerTitle = state.selectedUser!.nombre;
      headerSubtitle = state.selectedUser!.rol;
    } else {
      switch (state.activeTab) {
        case 0:
          headerTitle = 'Panel de TI';
          headerSubtitle = state.adminProfile?.nombre ??
              (state.isLoadingProfile
                  ? 'Cargando perfil…'
                  : 'Perfil no disponible');
          break;
        case 1:
          headerTitle = 'Usuarios';
          headerSubtitle = 'Cuentas y roles';
          break;
        case 2:
          headerTitle = state.adminProfile?.nombre ?? 'Perfil de TI';
          headerSubtitle = state.adminProfile?.rol ??
              (state.isLoadingProfile
                  ? 'Cargando perfil…'
                  : 'Perfil no disponible');
          break;
        case 3:
          headerTitle = 'Certificaciones';
          headerSubtitle = 'Revisión de soportes docentes';
          break;
        default:
          headerTitle = 'Panel de TI';
          headerSubtitle = 'Administración';
          break;
      }
    }

    final Widget bodyContent;
    if (isEditing) {
      bodyContent = AdminEditarUsuarioView(
        user: state.selectedUser!,
        onDone: () => notifier.clearSelectedUser(),
      );
    } else if (hasSelectedUser) {
      bodyContent = AdminDetalleUsuarioView(
        user: state.selectedUser!,
        onEdit: notifier.editSelectedUser,
      );
    } else {
      bodyContent = switch (state.activeTab) {
        0 => AdminInicioView(
            onOpenCertifications: () => notifier.setTab(3),
          ),
        1 => const AdminUsuariosView(),
        2 => const AdminPerfilView(),
        3 => const AdminCertificacionesView(),
        _ => const AdminInicioView(),
      };
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;
          final showRoleSummary = constraints.maxWidth >= 1360;
          final contentSurface = Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FB),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(isWide ? 18 : 24),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey(
                  hasSelectedUser
                      ? '${isEditing ? 'edit' : 'detail'}_${state.selectedUser?.id}'
                      : 'tab_${state.activeTab}',
                ),
                child: bodyContent,
              ),
            ),
          );

          final header = AdminHeader(
            title: headerTitle,
            subtitle: headerSubtitle,
            isEditing: hasSelectedUser,
            onBack: notifier.clearSelectedUser,
            onProfileTap: () => notifier.setTab(2),
          );

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 1440 : double.infinity,
              ),
              child: Column(
                children: [
                  header,
                  Expanded(
                    child: isWide
                        ? Row(
                            children: [
                              AdminSideNav(
                                currentIndex: hasSelectedUser ? 1 : state.activeTab,
                                adminName: state.adminProfile?.nombre ?? 'Admin TI',
                                onTap: notifier.setTab,
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: showRoleSummary ? 3 : 1,
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          showRoleSummary ? 14 : 20,
                                          14,
                                          showRoleSummary ? 8 : 20,
                                          14,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: contentSurface,
                                        ),
                                      ),
                                    ),
                                    if (showRoleSummary)
                                      SizedBox(
                                        width: 238,
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            5,
                                            14,
                                            14,
                                            14,
                                          ),
                                          child: Align(
                                            alignment: Alignment.topCenter,
                                            child: AdminRoleSummary(
                                              key: ValueKey(
                                                'roles_${state.users.length}_${state.isLoadingUsers}',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : contentSurface,
                  ),
                  if (!isWide)
                    AdminBottomBar(
                      currentIndex: hasSelectedUser ? 1 : state.activeTab,
                      onTap: notifier.setTab,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
