import 'package:flutter/material.dart';

class RoleDashboardHeader extends StatelessWidget {
  const RoleDashboardHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.darkColor,
    required this.initials,
    this.onRefresh,
    this.onNotifications,
    this.onProfile,
    this.onLogout,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final Color darkColor;
  final String initials;
  final VoidCallback? onRefresh;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, topPadding + 14, 14, 38),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor, darkColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -82,
            right: -56,
            child: Container(
              width: 184,
              height: 184,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .07),
                  width: 24,
                ),
              ),
            ),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: Colors.white.withValues(alpha: .2),
                foregroundColor: Colors.white,
                child: Text(
                  initials,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: onRefresh,
                  color: Colors.white,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              if (onNotifications != null)
                IconButton(
                  tooltip: 'Avisos',
                  onPressed: onNotifications,
                  color: Colors.white,
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              if (onProfile != null)
                IconButton(
                  tooltip: 'Mi perfil',
                  onPressed: onProfile,
                  color: Colors.white,
                  icon: const Icon(Icons.account_circle_outlined),
                ),
              if (onLogout != null)
                PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  color: Colors.white,
                  iconColor: Colors.white,
                  onSelected: (value) {
                    if (value == 'logout') onLogout!();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Text('Cerrar sesión'),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
