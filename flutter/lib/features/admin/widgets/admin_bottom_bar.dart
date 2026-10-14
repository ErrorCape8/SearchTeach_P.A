import 'package:flutter/material.dart';

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
        color: Colors.white,
        alignment: Alignment.topCenter,
        child: NavigationRail(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          labelType: NavigationRailLabelType.all,
          groupAlignment: -0.8,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFFFF1E6),
          selectedIconTheme: const IconThemeData(color: Color(0xFFEA580C)),
          unselectedIconTheme: const IconThemeData(color: Color(0xFF8C95A6)),
          selectedLabelTextStyle: const TextStyle(
            color: Color(0xFFEA580C),
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelTextStyle: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: Text('Inicio'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.people_alt_outlined),
              selectedIcon: Icon(Icons.people_alt_rounded),
              label: Text('Usuarios'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: Text('Perfil'),
            ),
          ],
        ),
      );
}
