part of 'student_dashboard_page.dart';

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.profile,
    required this.wide,
    required this.onLogout,
  });
  final StudentProfile profile;
  final bool wide;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Container(
        height: 96,
        padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16),
        decoration: const BoxDecoration(
          color: Color(0xFF0B4EA2),
          boxShadow: [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          const BrandLogo(width: 44, height: 42),
          const SizedBox(width: 10),
          Text('SearchTeach',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: wide ? 24 : 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const Spacer(),
          if (wide) ...[
            Text(
              profile.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: Colors.white,
                child: Text(
                  profile.name.trim().isEmpty
                      ? 'E'
                      : profile.name.trim()[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF0B4EA2),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEA3A4C),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          if (!wide)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: onLogout,
              icon: const Icon(Icons.logout, color: Colors.white),
            ),
        ]),
      );
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.tab,
    required this.profile,
    required this.onSelect,
    required this.onLogout,
  });
  final int tab;
  final StudentProfile profile;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  static const _items = [
    (Icons.home_outlined, 'Inicio'),
    (Icons.menu_book_outlined, 'Tutorías'),
    (Icons.person_outline, 'Perfil'),
    (Icons.notifications_none_outlined, 'Avisos'),
  ];

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF0A3D86),
        child: SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        profile.name.trim().isEmpty
                            ? 'E'
                            : profile.name.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF0A3D86),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Estudiante',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < _items.length; i++)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    selected: tab == i,
                    selectedColor: const Color(0xFF0A3D86),
                    selectedTileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    leading: i == 3
                        ? const NotificationUnreadIcon(
                            icon: Icons.notifications_none_outlined,
                          )
                        : Icon(
                            _items[i].$1,
                            color: tab == i ? const Color(0xFF0A3D86) : Colors.white,
                          ),
                    title: Text(
                      _items[i].$2,
                      style: TextStyle(
                        color: tab == i ? const Color(0xFF0A3D86) : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => onSelect(i),
                  ),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white),
                  title: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  onTap: onLogout,
                ),
              ),
            ],
          ),
        ),
      );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42, color: _blue),
                const SizedBox(height: 14),
                const Text('No pudimos cargar tu panel',
                    style: TextStyle(
                        color: _navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                Text('$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.blueGrey)),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
}
