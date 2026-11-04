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
          mainAxisAlignment: MainAxisAlignment.spaceAround,
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: isActive
            ? const EdgeInsets.symmetric(horizontal: 22, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeOrange : inactiveColor,
              ),
            ),
          ],
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
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
        width: 240,
        color: const Color(0xFFEA580C),
        child: Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: BrandLogo(width: 52, height: 46),
              ),
              const SizedBox(height: 4),
              const Text(
                'SearchTeach',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Text(
                'CONNECT · LEARN · GROW',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 18),
              const Divider(
                color: Colors.white24,
                thickness: 1,
                indent: 12,
                endIndent: 12,
              ),
              const SizedBox(height: 18),
              ...List.generate(4, (index) {
                final labels = ['Inicio', 'Usuarios', 'Perfil', 'Certificaciones'];
                final icons = [
                  Icons.home_outlined,
                  Icons.people_alt_outlined,
                  Icons.person_outline_rounded,
                  Icons.verified_outlined,
                ];
                final active = currentIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    selected: active,
                    selectedColor: const Color(0xFFEA580C),
                    selectedTileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(
                      icons[index],
                      color: active ? const Color(0xFFEA580C) : Colors.white,
                    ),
                    title: Text(
                      labels[index],
                      style: TextStyle(
                        color: active ? const Color(0xFFEA580C) : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => onTap(index),
                  ),
                );
              }),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white,
                      child: Text(
                        'AT',
                        style: TextStyle(
                          color: Color(0xFFEA580C),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Admin TI',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
