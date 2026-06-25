import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const BottomNavBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface.withAlpha(230),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: theme.dividerTheme.color?.withAlpha(76) ?? Colors.grey.withAlpha(76)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Tab 1: Home (Devices)
            _NavItem(
              icon: currentIndex == 0 ? Icons.home_filled : Icons.home_outlined,
              label: 'Home',
              isActive: currentIndex == 0,
              onTap: () => onTap?.call(0),
              activeColor: colorScheme.primary,
            ),
            // Tab 2: Activity
            _NavItem(
              icon: Icons.history,
              label: 'Activity',
              isActive: currentIndex == 1,
              onTap: () => onTap?.call(1),
              activeColor: colorScheme.primary,
            ),
            // Tab 3: Members
            _NavItem(
              icon: currentIndex == 2 ? Icons.group : Icons.group_outlined,
              label: 'Members',
              isActive: currentIndex == 2,
              onTap: () => onTap?.call(2),
              activeColor: colorScheme.primary,
            ),
            // Tab 4: Settings
            _NavItem(
              icon: currentIndex == 3 ? Icons.settings : Icons.settings_outlined,
              label: 'Settings',
              isActive: currentIndex == 3,
              onTap: () => onTap?.call(3),
              activeColor: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final color = isActive ? activeColor : (textTheme.labelSmall?.color ?? Colors.grey);
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
