import 'package:flutter/material.dart';

class AcademicRoleSwitcher extends StatelessWidget {
  const AcademicRoleSwitcher({
    required this.role,
    required this.activeRole,
    required this.onProfile,
    required this.child,
    this.onSwitchToTeacher,
    this.onSwitchToStudent,
    super.key,
  });

  final String role;
  final String activeRole;
  final VoidCallback onProfile;
  final VoidCallback? onSwitchToTeacher;
  final VoidCallback? onSwitchToStudent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final normalizedRole = role.toLowerCase();
    final canSwitch = normalizedRole.contains('docente') &&
        normalizedRole.contains('estudiante') &&
        onSwitchToTeacher != null &&
        onSwitchToStudent != null;

    if (!canSwitch) {
      return GestureDetector(
        onTap: onProfile,
        child: child,
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Cambiar de sesión',
      onSelected: (selection) {
        switch (selection) {
          case 'docente':
            onSwitchToTeacher!();
            break;
          case 'estudiante':
            onSwitchToStudent!();
            break;
          case 'perfil':
            onProfile();
            break;
        }
      },
      itemBuilder: (context) => [
        _roleItem(
          value: 'docente',
          label: 'Docente',
          icon: Icons.co_present_outlined,
        ),
        _roleItem(
          value: 'estudiante',
          label: 'Estudiante',
          icon: Icons.school_outlined,
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'perfil',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_outline_rounded),
            title: Text('Mi perfil'),
          ),
        ),
      ],
      child: Semantics(
        button: true,
        label: 'Cambiar de sesión',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            const Positioned(
              right: -2,
              bottom: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.swap_vert_rounded,
                  size: 17,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _roleItem({
    required String value,
    required String label,
    required IconData icon,
  }) =>
      PopupMenuItem(
        enabled: activeRole != value,
        value: value,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(label),
          trailing: activeRole == value
              ? const Icon(Icons.check_rounded, size: 18)
              : null,
        ),
      );
}
