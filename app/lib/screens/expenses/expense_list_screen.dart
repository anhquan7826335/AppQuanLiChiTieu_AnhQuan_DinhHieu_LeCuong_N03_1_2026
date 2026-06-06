// lib/screens/expenses/expense_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../utils/currency_format.dart';
import '../../widgets/empty_placeholder.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/category_dropdown.dart';
import 'expense_detail_screen.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  final _q = TextEditingController();
  DateTimeRange? _range;
  String? _category;

  /// -1 = tháng trước, 0 = tháng này, 1 = tháng sau
  int _monthIndex = 0;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expSvc = ref.watch(expenseServiceProvider);

    // Khoảng tháng theo _monthIndex (nếu user chưa chọn range custom)
    final monthRange = _monthDateRange(_monthIndex);
    final effectiveRange = _range ?? monthRange;
    final from = effectiveRange.start;
    final to = effectiveRange.end;

    // Dùng search đã chuẩn hoá (bỏ dấu + lowercase)
    final filtered = expSvc.search(
      q: _q.text,
      from: from,
      to: to,
      category: _category,
    );

    final total = filtered.fold<double>(0, (s, e) => s + e.amount);
    final budget = expSvc.monthlyBudget;
    final remain = (budget > 0) ? (budget - total) : 0.0;
    final title = _formatMonthLabel(_monthIndex);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            title: const Text('Trang chủ'),
            centerTitle: false,
          ),

          // ===== Chọn tháng: “Tháng MM/YYYY” (-1 | 0 | 1) =====
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _MonthSwitcher(
                index: _monthIndex,
                leftLabel: _formatMonthLabel(-1),
                centerLabel: _formatMonthLabel(0),
                rightLabel: _formatMonthLabel(1),
                onChanged: (i) {
                  setState(() {
                    _monthIndex = i;
                    _range = null; // về đúng tháng khi đổi tab
                  });
                },
              ),
            ),
          ),

          // ===== Card tổng hợp: Ngân sách / Tổng / Còn lại =====
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                children: [
                  _SummaryCard(
                    title: title,
                    budget: budget,
                    total: total,
                    remain: remain,
                  ),
                  const SizedBox(height: 12),

                  // ===== Bộ lọc: tìm kiếm + date range + danh mục =====
                  _FiltersBar(
                    qController: _q,
                    range: effectiveRange,
                    rangeLabel:
                    '${effectiveRange.start.toString().substring(0, 10)} → ${effectiveRange.end.toString().substring(0, 10)}',
                    onRangePicked: (r) => setState(() => _range = r),
                    category: _category,
                    onCatChanged: (v) => setState(() => _category = v),
                    // ✅ NEW: khi gõ tìm kiếm → parent setState() → tính lại filtered
                    onQueryChanged: (v) => setState(() {}),
                  ),
                  const SizedBox(height: 8),

                  // ===== Chips thông tin nhanh =====
                  Row(
                    children: [
                      Chip(label: Text('Số bản ghi: ${filtered.length}')),
                      const SizedBox(width: 8),
                      Chip(label: Text('Tổng: ${CurF.money(total)}')),
                      const SizedBox(width: 8),
                      if (budget > 0)
                        Chip(label: Text('Ngân sách: ${CurF.money(budget)}')),
                      const SizedBox(width: 8),
                      if (budget > 0)
                        Chip(
                          avatar: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 16,
                          ),
                          label: Text('Còn lại: ${CurF.money(remain)}'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ===== Danh sách chi tiêu =====
          filtered.isEmpty
              ? const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 48),
              child: EmptyPlaceholder(
                title: 'Chưa có chi tiêu',
                subtitle: 'Nhấn nút + để thêm chi tiêu mới',
              ),
            ),
          )
              : SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 0),
            itemBuilder: (_, i) {
              final e = filtered[i];

              // Nền hiện khi vuốt sang trái/phải
              Widget swipeBg(Alignment align) => Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: align,
                padding: EdgeInsets.only(
                  left: align == Alignment.centerLeft ? 20 : 0,
                  right: align == Alignment.centerRight ? 20 : 0,
                ),
                child: const Icon(Icons.delete, color: Colors.red),
              );

              return Dismissible(
                key: ValueKey(e.id),
                background: swipeBg(Alignment.centerLeft),
                secondaryBackground: swipeBg(Alignment.centerRight),

                // Hộp thoại xác nhận xóa để tránh vuốt nhầm
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Xóa chi tiêu?'),
                      content: Text(
                        'Bạn có chắc muốn xóa “${e.title}” (${CurF.money(e.amount)})?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(ctx, false),
                          child: const Text('Hủy'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.pop(ctx, true),
                          child: const Text('Xóa'),
                        ),
                      ],
                    ),
                  ) ??
                      false;
                },
                onDismissed: (_) async {
                  await ref.read(expenseServiceProvider).remove(e.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa chi tiêu')),
                  );
                  setState(() {}); // refresh list
                },
                child: ExpenseTile(
                  e: e,
                  onTap: () async {
                    final changed = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExpenseDetailScreen(e: e),
                      ),
                    );
                    if (changed == true && mounted) {
                      setState(() {}); // refresh sau khi xoá/sửa ở màn chi tiết
                    }
                  },
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  // Khoảng đầu->cuối tháng theo offset (-1/0/1)
  DateTimeRange _monthDateRange(int index) {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month + index, 1);
    final start = DateTime(base.year, base.month, 1);
    final end = DateTime(base.year, base.month + 1, 0, 23, 59, 59, 999);
    return DateTimeRange(start: start, end: end);
  }

  // “Tháng MM/YYYY”
  String _formatMonthLabel(int index) {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month + index, 1);
    final mm = base.month.toString().padLeft(2, '0');
    final yyyy = base.year.toString();
    return 'Tháng $mm/$yyyy';
  }
}

// ============= WIDGETS PHỤ =============

class _MonthSwitcher extends StatelessWidget {
  final int index; // -1, 0, 1
  final String leftLabel;
  final String centerLabel;
  final String rightLabel;
  final ValueChanged<int> onChanged;

  const _MonthSwitcher({
    required this.index,
    required this.leftLabel,
    required this.centerLabel,
    required this.rightLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget tab(String label, int value) {
      final selected = index == value;
      return InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                height: 2,
                width: selected ? 56 : 0,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            tab(leftLabel, -1),
            tab(centerLabel, 0),
            tab(rightLabel, 1),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double budget;
  final double total;
  final double remain;

  const _SummaryCard({
    required this.title,
    required this.budget,
    required this.total,
    required this.remain,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DefaultTextStyle(
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.primary,
                fontSize: 16,
              ),
              child: Row(
                children: [
                  Text(title),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Divider(height: 24, color: cs.outlineVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _kv(
                    'Ngân sách',
                    budget > 0 ? CurF.money(budget) : '—',
                  ),
                ),
                Expanded(child: _kv('Tổng chi', CurF.money(total))),
                Expanded(
                  child: _kv(
                    'Còn lại',
                    budget > 0 ? CurF.money(remain) : '—',
                    bold: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 2),
        Text(
          v,
          style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
        ),
      ],
    );
  }
}

class _FiltersBar extends StatelessWidget {
  final TextEditingController qController;
  final DateTimeRange range;
  final String rangeLabel;
  final void Function(DateTimeRange?) onRangePicked;
  final String? category;
  final void Function(String?) onCatChanged;

  // ✅ NEW: callback báo parent thay đổi query để parent setState()
  final ValueChanged<String> onQueryChanged;

  const _FiltersBar({
    required this.qController,
    required this.range,
    required this.rangeLabel,
    required this.onRangePicked,
    required this.category,
    required this.onCatChanged,
    required this.onQueryChanged, // NEW
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: qController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Tìm kiếm chi tiêu...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            // ✅ Gõ đến đâu → báo parent → parent setState() → filtered tính lại ngay
            onChanged: onQueryChanged,
          ),
        ),
        FilledButton.tonal(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 5),
              initialDateRange: range,
            );
            onRangePicked(picked);
          },
          child: Text(rangeLabel),
        ),

        // === Dropdown danh mục ===
        CategoryDropdown(
          value: category,
          onChanged: onCatChanged,
        ),
      ],
    );
  }
}
