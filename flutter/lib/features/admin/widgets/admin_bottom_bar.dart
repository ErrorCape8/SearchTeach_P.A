import 'package:flutter/material.dart';

import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/sliding_pill_navigation_bar.dart';

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
      child: SafeArea(
        top: false,
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context)
                .colorScheme
                .copyWith(primary: const Color(0xFFEA580C)),
          ),
          child: SlidingPillNavigationBar(
            selectedColor: const Color(0xFFEA580C),
            indicatorColor: const Color(0xFFFFF1E6),
            selectedIndex: currentIndex,
            onDestinationSelected: onTap,
            destinations: const [
              SlidingPillDestination(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Inicio'),
              SlidingPillDestination(
                  icon: Icons.people_alt_outlined,
                  selectedIcon: Icons.people_alt_rounded,
                  label: 'Usuarios'),
              SlidingPillDestination(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Perfil'),
              SlidingPillDestination(
                  icon: Icons.verified_outlined,
                  selectedIcon: Icons.verified,
                  label: 'Certificaciones'),
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
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Transform.scale(
                    scale: 1.06,
                    child: const BrandLogo(
                      width: 142,
                      height: 72,
                      color: Colors.black,
                    ),
                  ),
                ),
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
                    selectedColor: Colors.white,
                    selectedTileColor: const Color(0xFFC2410C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    leading: Icon(
                      icons[index],
                      color: Colors.white,
                      size: 17,
                    ),
                    title: Text(
                      labels[index],
                      style: TextStyle(
                        color: Colors.white,
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
                child: Container(
                  decoration: BoxDecoration(
                    color: currentIndex == 2
                        ? const Color(0xFFC2410C)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
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
