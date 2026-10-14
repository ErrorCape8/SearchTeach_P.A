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
          headerSubtitle = 'Administrador del sistema';
          break;
        case 1:
          headerTitle = 'Usuarios';
          headerSubtitle = 'Cuentas y roles';
          break;
        case 2:
        default:
          headerTitle = 'Admin TI';
          headerSubtitle = 'Administrador';
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
      backgroundColor: const Color(0xFFEA580C),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // Cabecera naranja dinámica
              AdminHeader(
                title: headerTitle,
                subtitle: headerSubtitle,
                isEditing: isEditing,
                onBack: () => notifier.clearSelectedUser(),
              ),

              // Cuerpo con esquinas superiores redondeadas (hoja blanca)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(isEditing ? 'edit_${state.selectedUser?.id}' : 'tab_${state.activeTab}'),
                      child: bodyContent,
                    ),
                  ),
                ),
              ),

              // Barra de navegación inferior
              AdminBottomBar(
                currentIndex: isEditing ? 1 : state.activeTab,
                onTap: (index) {
                  notifier.setTab(index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
