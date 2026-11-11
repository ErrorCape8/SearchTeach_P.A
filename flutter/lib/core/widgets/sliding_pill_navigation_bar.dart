import 'package:flutter/material.dart';

class SlidingPillDestination {
  const SlidingPillDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

class SlidingPillNavigationBar extends StatelessWidget {
  const SlidingPillNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.selectedColor,
    required this.indicatorColor,
    this.backgroundColor = Colors.white,
  });

  final List<SlidingPillDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Color selectedColor;
  final Color indicatorColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return const SizedBox.shrink();
    final safeIndex = selectedIndex.clamp(0, destinations.length - 1);
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .14),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / destinations.length;
            return SizedBox(
              height: 66,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    left: itemWidth * safeIndex,
                    top: 0,
                    bottom: 0,
                    width: itemWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: indicatorColor,
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var index = 0; index < destinations.length; index++)
                        Expanded(
                          child: _NavigationDestinationButton(
                            destination: destinations[index],
                            selected: index == safeIndex,
                            selectedColor: selectedColor,
                            unselectedColor: mutedColor,
                            onTap: () => onDestinationSelected(index),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavigationDestinationButton extends StatelessWidget {
  const _NavigationDestinationButton({
    required this.destination,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final SlidingPillDestination destination;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? destination.selectedIcon ?? destination.icon
                    : destination.icon,
                color: color,
                size: 23,
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
