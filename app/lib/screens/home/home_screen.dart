import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../expenses/expense_list_screen.dart';
import '../calendar/calendar_screen.dart';
import '../analysis/analysis_screen.dart';
import '../settings/settings_screen.dart';
import '../expenses/expense_form_screen.dart';

// Badge
import '../../services/notification_service.dart';

const double _kMaxContentWidth = 900;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  late final List<Widget> _pages = const [
    ExpenseListScreen(),
    CalendarScreen(),
    AnalysisScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final noti = ref.watch(notiProvider);

    // Tính bề rộng nội dung an toàn, KHÔNG dùng LayoutBuilder
    final size = MediaQuery.of(context).size;
    final contentW = size.width < _kMaxContentWidth ? size.width : _kMaxContentWidth;

    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: contentW,
          height: double.infinity,
          child: IndexedStack(index: _index, children: _pages),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseFormScreen()));
        },
        tooltip: 'Thêm chi tiêu',
        backgroundColor: cs.secondary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 6,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Trang chủ',
                    selected: _index == 0,
                    onTap: () => setState(() => _index = 0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'Lịch',
                    selected: _index == 1,
                    badgeCount: noti.calendar,
                    onTap: () {
                      setState(() => _index = 1);
                      ref.read(notiProvider.notifier).clear(NotiChannel.calendar);
                    },
                  ),
                ),
                const SizedBox(width: 56),
                Expanded(
                  child: _NavItem(
                    icon: Icons.query_stats_rounded,
                    label: 'Phân tích',
                    selected: _index == 2,
                    badgeCount: noti.analysis,
                    onTap: () {
                      setState(() => _index = 2);
                      ref.read(notiProvider.notifier).clear(NotiChannel.analysis);
                    },
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.settings_rounded,
                    label: 'Cài đặt',
                    selected: _index == 3,
                    onTap: () => setState(() => _index = 3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _badgeIcon(base: Icon(icon, size: 20, color: color), count: badgeCount),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeIcon({required Widget base, required int count}) {
    if (count <= 0) return base;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        base,
        Positioned(
          right: -8,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, height: 1.0),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
