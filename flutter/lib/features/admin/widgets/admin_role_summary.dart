import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_controller.dart';

class AdminRoleSummary extends ConsumerWidget {
  const AdminRoleSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminControllerProvider);
    final roles = <(String, IconData, int)>[
      (
        'Estudiantes',
        Icons.person_outline,
        state.users.where((user) => user.rol.toLowerCase().contains('estudiante')).length,
      ),
      (
        'Docentes',
        Icons.menu_book_outlined,
        state.users.where((user) => user.rol.toLowerCase().contains('docente')).length,
      ),
      (
        'Coordinadores',
        Icons.groups_outlined,
        state.users.where((user) => user.rol.toLowerCase().contains('coordinador')).length,
      ),
      (
        'Líder de programas',
        Icons.bar_chart_outlined,
        state.users.where((user) {
          final role = user.rol.toLowerCase();
          return role.contains('líder') || role.contains('lider');
        }).length,
      ),
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE7EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cuentas por rol',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (state.isLoadingUsers && state.users.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (state.usersError != null && state.users.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      state.usersError!,
                      style: const TextStyle(
                        color: Color(0xFF9B2C2C),
                        fontSize: 10,
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(adminControllerProvider.notifier)
                          .loadUsers(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else
              for (var index = 0; index < roles.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                _RoleCountRow(
                  label: roles[index].$1,
                  icon: roles[index].$2,
                  count: roles[index].$3,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _RoleCountRow extends StatelessWidget {
  const _RoleCountRow({
    required this.label,
    required this.icon,
    required this.count,
  });

  final String label;
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1E5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: const Color(0xFFEA7408)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'Cuentas registradas',
                    style: TextStyle(
                      color: Color(0xFF8A93A2),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1E5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFFEA7408),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}
