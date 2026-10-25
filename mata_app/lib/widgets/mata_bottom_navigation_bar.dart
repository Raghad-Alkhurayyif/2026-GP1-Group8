import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/mata_theme.dart';

class MataBottomNavigationBar extends StatelessWidget {
  const MataBottomNavigationBar({
    required this.currentIndex,
    required this.onHomeTap,
    required this.onAccountTap,
    this.onHistoryTap,
    super.key,
  });

  final int currentIndex;
  final VoidCallback onHomeTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback onAccountTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(22);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: MataColors.cocoa.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: -14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: MataColors.softWhite.withValues(alpha: 0.7),
              borderRadius: shape,
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                _NavigationItem(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  selected: currentIndex == 0,
                  onTap: onHomeTap,
                ),
                _NavigationItem(
                  icon: Icons.access_time_rounded,
                  label: 'History',
                  selected: currentIndex == 1,
                  onTap: onHistoryTap,
                ),
                _NavigationItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Account',
                  selected: currentIndex == 2,
                  onTap: onAccountTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MataColors.brown : MataColors.faint;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: MataText.body(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
