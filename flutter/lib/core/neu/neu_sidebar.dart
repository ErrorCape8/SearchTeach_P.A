import 'package:flutter/material.dart';

import 'neu_theme.dart';
import 'neu_widgets.dart';

class NeuSidebar extends StatelessWidget {
  const NeuSidebar({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.name,
    required this.userRole,
    required this.roleLabel,
    required this.onLogout,
    this.onUserTap,
    super.key,
  });

  final List<(IconData, String, int)> items;
  final int? selected;
  final ValueChanged<int> onSelect;
  final String name;
  final String userRole;
  final String roleLabel;
  final VoidCallback onLogout;
  final VoidCallback? onUserTap;

  static String initials(String value) {
    final words =
        value.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '··';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final p = NeuPalette.of(context);
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Neu.bg,
        boxShadow: [
          BoxShadow(color: Neu.shadowDark, offset: Offset(4, 0), blurRadius: 12),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    p.logoAsset,
                    width: 48,
                    fit: BoxFit.contain,
                    semanticLabel: 'Logo de SearchTeach',
                    errorBuilder: (_, __, ___) => const SizedBox(width: 48),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Search',
                                style: neuPoppins(
                                  size: 21,
                                  weight: FontWeight.w700,
                                  color: Neu.text,
                                ),
                              ),
                              TextSpan(
                                text: 'Teach',
                                style: neuPoppins(
                                  size: 21,
                                  weight: FontWeight.w700,
                                  color: p.c,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          roleLabel.toUpperCase(),
                          style: neuBody(
                            size: 9.5,
                            weight: FontWeight.w700,
                            color: p.c,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: NeuSurface(
                  radius: 16,
                  shadows: const [],
                  sunken: selected == item.$3,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  onTap: () => onSelect(item.$3),
                  child: Row(children: [
                    Icon(item.$1,
                        size: 22,
                        color: selected == item.$3 ? p.c : Neu.navIdle),
                    const SizedBox(width: 12),
                    Text(item.$2,
                        style: neuBody(
                            size: 15,
                            weight: FontWeight.w700,
                            color: selected == item.$3 ? p.c : Neu.muted)),
                  ]),
                ),
              ),
            const Spacer(),
            NeuSurface(
              radius: 16,
              shadows: const [],
              padding: const EdgeInsets.all(10),
              onTap: onUserTap,
              child: Row(children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: NeuSurface(
                    radius: 40,
                    shadows: Neu.raiseS,
                    child: Center(
                      child: Text(initials(name),
                          style: neuBody(
                              size: 13,
                              weight: FontWeight.w700,
                              color: Neu.muted)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: neuBody(size: 14, weight: FontWeight.w700)),
                        Text(userRole,
                            style: neuBody(size: 12, color: Neu.muted)),
                      ]),
                ),
                IconButton(
                  tooltip: 'Cerrar sesión',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded, color: Neu.muted),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
