import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';
import 'neu_theme.dart';
import 'neu_widgets.dart';

/// Barra lateral neumórfica (`#app.neu .side`) para pantallas anchas:
/// logo + rol, opciones de menú y, al pie, el bloque de usuario con el botón
/// de cerrar sesión. En celular se usa [NeuBottomBar] en su lugar.
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

  /// (icono, etiqueta, id de pestaña).
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
            SizedBox(
              height: 72,
              width: 170,
              child: BrandLogo(width: 170, height: 72, accentColor: p.c),
            ),
            Text(roleLabel.toUpperCase(),
                style: neuBody(
                    size: 11,
                    weight: FontWeight.w700,
                    color: p.c,
                    letterSpacing: .6)),
            const SizedBox(height: 20),
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
