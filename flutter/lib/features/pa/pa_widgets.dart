import 'package:flutter/material.dart';

import '../../core/role_theme.dart';
import '../../core/widgets/role_toast.dart';

const paInk = Color(0xFF17324F);
const paMuted = Color(0xFF758093);
const paCanvas = Color(0xFFF3F5FA);
const paLine = Color(0xFFE4EAF1);

/// Abre una vista conservando (o cambiando) el color de acento del rol.
Future<T?> paPush<T>(BuildContext context, Widget page, {Color? accent}) {
  final theme = Theme.of(context);
  final color = accent ?? theme.colorScheme.primary;
  return Navigator.of(context).push<T>(MaterialPageRoute(
    builder: (_) => Theme(
      data: withRoleAccent(
        theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(primary: color),
        ),
        color,
      ),
      child: page,
    ),
  ));
}

void paToast(BuildContext context, String message) =>
    RoleToast.showSnackBar(context, SnackBar(content: Text(message)));

enum PaTone { neutral, ok, warn, error }

class PaTag extends StatelessWidget {
  const PaTag(this.text, {this.tone = PaTone.neutral, super.key});
  final String text;
  final PaTone tone;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final (bg, fg) = switch (tone) {
      PaTone.ok => (const Color(0xFFE3F5EA), const Color(0xFF1B7A3E)),
      PaTone.warn => (const Color(0xFFFFF1DB), const Color(0xFFB5640B)),
      PaTone.error => (const Color(0xFFFDE4E4), const Color(0xFFC0342F)),
      PaTone.neutral => (primary.withValues(alpha: .12), primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style:
              TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

/// Pantalla base: cabecera con degradado + hoja redondeada con contenido.
class PaScaffold extends StatelessWidget {
  const PaScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    this.actions = const [],
    super.key,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final dark = Color.lerp(primary, Colors.black, .35)!;
    return Scaffold(
      backgroundColor: primary,
      body: Column(children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, dark]),
          ),
          padding: EdgeInsets.fromLTRB(
              8, MediaQuery.paddingOf(context).top + 6, 8, 22),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconButton(
              tooltip: 'Volver',
              color: Colors.white,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .8),
                              fontSize: 13)),
                    ]),
              ),
            ),
            ...actions,
          ]),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: paCanvas,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class PaCard extends StatelessWidget {
  const PaCard(
      {required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap,
      super.key});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
            BoxShadow(
                color: Colors.white, blurRadius: 6, offset: Offset(-2, -2)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(padding: padding, child: child)),
        ),
      );
}

class PaKpi extends StatelessWidget {
  const PaKpi(this.value, this.label, {super.key});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: paMuted, fontSize: 11.5)),
        ]),
      );
}

class PaKpiRow extends StatelessWidget {
  const PaKpiRow(this.items, {super.key});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: PaKpi(items[i].$1, items[i].$2)),
          ],
        ]),
      );
}

class PaSection extends StatelessWidget {
  const PaSection(this.title, {this.action, this.onAction, super.key});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
        child: Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: paInk, fontSize: 16, fontWeight: FontWeight.w800))),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ]),
      );
}

class PaRow extends StatelessWidget {
  const PaRow(
      {required this.icon,
      required this.title,
      this.subtitle,
      this.trailing,
      this.onTap,
      super.key});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: primary, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(color: paInk, fontWeight: FontWeight.w700)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: const TextStyle(color: paMuted, fontSize: 12.5)),
      trailing: trailing ??
          (onTap == null
              ? null
              : const Icon(Icons.chevron_right_rounded, color: paMuted)),
    );
  }
}

/// Lista dentro de una tarjeta con separadores.
class PaRowList extends StatelessWidget {
  const PaRowList(this.rows, {super.key});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => PaCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: paLine),
            rows[i],
          ],
        ]),
      );
}

class PaEmpty extends StatelessWidget {
  const PaEmpty(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: paMuted)),
      );
}

class PaInfo extends StatelessWidget {
  const PaInfo(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, color: primary, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: const TextStyle(color: paInk, fontSize: 13))),
      ]),
    );
  }
}

class PaSegmented extends StatelessWidget {
  const PaSegmented(
      {required this.labels,
      required this.selected,
      required this.onSelect,
      super.key});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < labels.length; i++)
            ChoiceChip(
              label: Text(labels[i]),
              selected: selected == i,
              onSelected: (_) => onSelect(i),
            ),
        ]),
      );
}

class PaFieldLabel extends StatelessWidget {
  const PaFieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: paMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .6)),
      );
}

InputDecoration paInput([String? hint]) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF3F5FA),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );

class PaEstrellas extends StatelessWidget {
  const PaEstrellas(
      {required this.value, required this.onChanged, super.key});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '$i',
            onPressed: () => onChanged(i),
            icon: Icon(
                i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                color: const Color(0xFFF5A623)),
          ),
      ]);
}
