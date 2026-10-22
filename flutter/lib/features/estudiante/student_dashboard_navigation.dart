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
        height: 68,
        padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE4EAF1))),
        ),
        child: Row(children: [
          const BrandLogo(width: 42, height: 36),
          const SizedBox(width: 10),
          const Text('SearchTeach',
              style: TextStyle(
                  color: _navy, fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (wide)
            Text('Panel de estudiante',
                style: TextStyle(color: Colors.blueGrey.shade600)),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFE7F1FC),
            child: Text(
              profile.name.trim().isEmpty
                  ? 'E'
                  : profile.name.trim()[0].toUpperCase(),
              style: const TextStyle(
                  color: _blue, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          if (wide) ...[
            const SizedBox(width: 10),
            Text(profile.name,
                style:
                    const TextStyle(color: _navy, fontWeight: FontWeight.w600)),
          ],
          if (!wide)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: onLogout,
              icon: const Icon(Icons.logout, color: _navy),
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
        color: Colors.white,
        child: SizedBox(
          width: 230,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
                child: Text(
                  'Hola, ${profile.name.split(' ').first}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _navy, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 10),
              for (var i = 0; i < _items.length; i++)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  child: ListTile(
                    selected: tab == i,
                    selectedColor: _blue,
                    selectedTileColor: const Color(0xFFEAF3FC),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    leading: i == 3
                        ? const NotificationUnreadIcon(
                            icon: Icons.notifications_none_outlined,
                          )
                        : Icon(_items[i].$1),
                    title: Text(_items[i].$2,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () => onSelect(i),
                  ),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Cerrar sesión'),
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
