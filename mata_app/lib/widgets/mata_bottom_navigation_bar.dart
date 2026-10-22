import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  static const Color barColor = Color(0xFF5C3F38);
  static const Color selectedColor = Color(0xFF705D59);
  static const Color iconColor = Color(0xFFDCCDB5);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: selected
                ? MataBottomNavigationBar.selectedColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: MataBottomNavigationBar.iconColor,
                size: 29,
              ),
              if (selected) ...[
                const SizedBox(width: 7),
                Text(
                  label,
                  style: GoogleFonts.reemKufi(
                    color: MataBottomNavigationBar.iconColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}