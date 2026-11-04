import 'package:flutter/material.dart';

import '../../../core/widgets/brand_logo.dart';

class AdminBottomBar extends StatelessWidget {
  const AdminBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const activeOrange = Color(0xFFEA580C);
    const inactiveColor = Color(0xFF8C95A6);
    const activePillBg = Color(0xFFFFF1E6);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F4F9), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _buildItem(
              index: 0,
              label: 'Inicio',
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              isActive: currentIndex == 0,
              activeOrange: activeOrange,
              inactiveColor: inactiveColor,
              activePillBg: activePillBg,
            ),
            _buildItem(
              index: 1,
              label: 'Usuarios',
              icon: Icons.people_alt_outlined,
              activeIcon: Icons.people_alt_rounded,
              isActive: currentIndex == 1,
              activeOrange: activeOrange,
              inactiveColor: inactiveColor,
              activePillBg: activePillBg,
            ),
            _buildItem(
              index: 2,
              label: 'Perfil',
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              isActive: currentIndex == 2,
              activeOrange: activeOrange,
              inactiveColor: inactiveColor,
              activePillBg: activePillBg,
            ),
            _buildItem(
              index: 3,
              label: 'Certificaciones',
              icon: Icons.verified_outlined,
              activeIcon: Icons.verified,
              isActive: currentIndex == 3,
              activeOrange: activeOrange,
              inactiveColor: inactiveColor,
              activePillBg: activePillBg,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required Color activeOrange,
    required Color inactiveColor,
    required Color activePillBg,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? activePillBg : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? activeOrange : inactiveColor,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? activeOrange : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminSideNav extends StatelessWidget {
  const AdminSideNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.adminName = 'Admin TI',
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final String adminName;

  @override
  Widget build(BuildContext context) => Container(
        width: 168,
        color: const Color(0xFFEA580C),
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: const BrandLogo(width: 142, height: 72),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ADMINISTRADOR TI',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(
                color: Colors.white24,
                thickness: 1,
                indent: 8,
                endIndent: 8,
              ),
              const SizedBox(height: 4),
              ...List.generate(3, (index) {
                final tabs = [0, 1, 3];
                final labels = ['Inicio', 'Usuarios', 'Certificados'];
                final icons = [
                  Icons.home_outlined,
                  Icons.people_alt_outlined,
                  Icons.verified_outlined,
                ];
                final active = currentIndex == tabs[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    selected: active,
                    selectedColor: const Color(0xFFEA580C),
                    selectedTileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    leading: Icon(
                      icons[index],
                      color: active ? const Color(0xFFEA580C) : Colors.white,
                      size: 17,
                    ),
                    title: Text(
                      labels[index],
                      style: TextStyle(
                        color: active ? const Color(0xFFEA580C) : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    onTap: () => onTap(tabs[index]),
                  ),
                );
              }),
              const Spacer(),
              InkWell(
                onTap: () => onTap(2),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 8, 14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                        child: Text(
                          _adminInitials(adminName),
                          style: TextStyle(
                            color: Color(0xFFEA580C),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              adminName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                            const Text(
                              'Administrador TI',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  static String _adminInitials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    if (parts.isEmpty) return 'AT';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}
