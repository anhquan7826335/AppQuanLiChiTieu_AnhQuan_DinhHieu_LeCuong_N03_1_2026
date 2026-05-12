import 'package:flutter/material.dart';

typedef BottomNavTapCallback = void Function(int index);

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final BottomNavTapCallback? onTap;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;

  const AppBottomNavigation({
    Key? key,
    required this.currentIndex,
    this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
  }) : super(key: key);

  void _defaultNavigate(BuildContext context, int index) {
    // Default route mapping
    final routes = ['/home', '/content', '/contact'];
    if (index < 0 || index >= routes.length) return;
    final route = routes[index];

    // Use pushReplacementNamed to keep a single top-level route
    Navigator.pushReplacementNamed(context, route);
  }

  void _handleTap(BuildContext context, int index) {
    if (onTap != null) {
      onTap!(index);
    } else {
      _defaultNavigate(context, index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.white;
    final selected = selectedItemColor ?? const Color(0xFF1A1A1A);
    final unselected = unselectedItemColor ?? Colors.grey.shade600;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _handleTap(context, index),
      backgroundColor: bg,
      selectedItemColor: selected,
      unselectedItemColor: unselected,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.info), label: 'Content'),
        BottomNavigationBarItem(icon: Icon(Icons.contacts), label: 'About'),
      ],
    );
  }
}
