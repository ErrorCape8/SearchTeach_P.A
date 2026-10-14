import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_controller.dart';
import '../models/admin_user.dart';

class AdminUsuariosView extends ConsumerStatefulWidget {
  const AdminUsuariosView({super.key});

  @override
  ConsumerState<AdminUsuariosView> createState() => _AdminUsuariosViewState();
}

class _AdminUsuariosViewState extends ConsumerState<AdminUsuariosView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterModal(BuildContext context, String currentFilter) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        final options = [
          'Todos',
          'Activo',
          'Revocado',
          'Estudiante',
          'Docente',
          'Coordinador'
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrar usuarios',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((opt) {
                    final isSelected = opt == currentFilter;
                    return ChoiceChip(
                      label: Text(opt),
                      selected: isSelected,
                      selectedColor: const Color(0xFFEA580C),
                      backgroundColor: const Color(0xFFF1F4F9),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFFEA580C)
                              : Colors.transparent,
                        ),
                      ),
                      onSelected: (_) {
                        ref.read(adminControllerProvider.notifier).setFilter(opt);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminControllerProvider);
    final users = state.filteredUsers;

    return Column(
      children: [
        // Barra de búsqueda y filtro
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => ref
                        .read(adminControllerProvider.notifier)
                        .setSearchQuery(val),
                    decoration: const InputDecoration(
                          hintText: 'Buscar por nombre, correo o ID',
                      hintStyle: TextStyle(
                        color: Color(0xFF8C95A6),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Color(0xFF8C95A6),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showFilterModal(context, state.filter),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: state.filter != 'Todos'
                          ? const Color(0xFFEA580C)
                          : const Color(0xFFE5E7EB),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.filter_alt_outlined,
                    color: const Color(0xFFEA580C),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Actualizar lista de usuarios',
                child: IconButton(
                  onPressed: state.isLoadingUsers
                      ? null
                      : () => ref
                          .read(adminControllerProvider.notifier)
                          .loadUsers(),
                  icon: state.isLoadingUsers
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFFEA580C),
                    backgroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Lista de usuarios
        Expanded(
          child: state.isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : state.usersError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.usersError!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => ref
                                  .read(adminControllerProvider.notifier)
                                  .loadUsers(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : users.isEmpty
              ? const Center(
                  child: Text(
                    'No hay usuarios que coincidan con la búsqueda.',
                    style: TextStyle(color: Color(0xFF8C95A6), fontSize: 14),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF1F5F9),
                  ),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _UserListTile(
                      user: user,
                      onTap: () {
                        // Al presionar un usuario lo deja editar
                        ref
                            .read(adminControllerProvider.notifier)
                            .selectUser(user);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _UserListTile extends StatelessWidget {
  const _UserListTile({
    required this.user,
    required this.onTap,
  });

  final AdminUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActivo = user.isActivo;
    final isRevocado = user.isRevocado;
    final stateLabel = isActivo
        ? 'Activo'
        : isRevocado
            ? 'Revocado'
            : 'Sin estado';
    final stateColor = isActivo
        ? const Color(0xFF16A34A)
        : isRevocado
            ? const Color(0xFFDC2626)
            : const Color(0xFF64748B);
    final stateBackground = isActivo
        ? const Color(0xFFDCFCE7)
        : isRevocado
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFE2E8F0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            // Avatar con icono de persona
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF1E6),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFFEA580C),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Nombre y Rol
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nombre.isEmpty ? 'Sin nombre registrado' : user.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.rol.isEmpty ? 'Sin rol registrado' : user.rol,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Badge de estado recibido de la base de datos.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: stateBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                stateLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: stateColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
