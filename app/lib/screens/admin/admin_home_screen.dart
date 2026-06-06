import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'admin_users_screen.dart';
import 'admin_expenses_screen.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});
  static const route = '/admin';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final role = (auth.currentUser?.role ?? 'user').toLowerCase(); // tránh null

    // Chặn truy cập nếu không phải admin
    if (role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản trị')),
        body: const Center(
          child: Text('Bạn không có quyền truy cập khu vực quản trị.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bảng điều khiển Admin')),
      body: LayoutBuilder(
        builder: (ctx, c) {
          final maxW = c.maxWidth;
          final contentW = maxW < 900 ? maxW : 820.0;
          final pad = maxW < 600 ? 12.0 : 20.0;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentW),
              child: ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  _AdminCard(
                    icon: Icons.people_alt_rounded,
                    title: 'Quản lý người dùng',
                    subtitle: 'Danh sách, tìm kiếm, khoá/mở, đổi quyền, reset mật khẩu',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AdminCard(
                    icon: Icons.insights_rounded,
                    title: 'Xem chi tiêu toàn hệ thống',
                    subtitle: 'Lọc theo user/thời gian/nhóm • Tổng hợp • Xuất CSV',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminExpensesScreen()),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: cs.primary.withOpacity(.12),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
