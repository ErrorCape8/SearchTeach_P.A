import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_controller.dart';
import 'views/admin_editar_usuario_view.dart';
import 'views/admin_inicio_view.dart';
import 'views/admin_perfil_view.dart';
import 'views/admin_usuarios_view.dart';
import 'widgets/admin_bottom_bar.dart';
import 'widgets/admin_header.dart';

class AdminMainPage extends ConsumerWidget {
  const AdminMainPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminControllerProvider);
    final notifier = ref.read(adminControllerProvider.notifier);

    final isEditing = state.selectedUser != null;

    final String headerTitle;
    final String headerSubtitle;

    if (isEditing) {
      headerTitle = 'Editar usuario';
      headerSubtitle = state.selectedUser!.nombre;
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
        default:
          headerTitle = state.adminProfile?.nombre ?? 'Perfil de TI';
          headerSubtitle = state.adminProfile?.rol ??
              (state.isLoadingProfile
                  ? 'Cargando perfil…'
                  : 'Perfil no disponible');
          break;
      }
    }

    final Widget bodyContent;
    if (isEditing) {
      bodyContent = AdminEditarUsuarioView(
        user: state.selectedUser!,
        onDone: () => notifier.clearSelectedUser(),
      );
    } else {
      bodyContent = switch (state.activeTab) {
        0 => const AdminInicioView(),
        1 => const AdminUsuariosView(),
        2 => const AdminPerfilView(),
        _ => const AdminInicioView(),
      };
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F9),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          final contentSurface = Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(isWide ? 24 : 28),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 1120 : double.infinity,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(
                      isEditing
                          ? 'edit_${state.selectedUser?.id}'
                          : 'tab_${state.activeTab}',
                    ),
                    child: bodyContent,
                  ),
                ),
              ),
            ),
          );

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 1440 : 480,
              ),
              child: Column(
                children: [
                  AdminHeader(
                    title: headerTitle,
                    subtitle: headerSubtitle,
                    isEditing: isEditing,
                    onBack: () => notifier.clearSelectedUser(),
                  ),
                  Expanded(
                    child: isWide
                        ? Row(
                            children: [
                              AdminSideNav(
                                currentIndex: isEditing ? 1 : state.activeTab,
                                onTap: notifier.setTab,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: contentSurface,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : contentSurface,
                  ),
                  if (!isWide)
                    AdminBottomBar(
                      currentIndex: isEditing ? 1 : state.activeTab,
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
