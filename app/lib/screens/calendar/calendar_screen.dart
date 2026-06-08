import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../models/expense.dart';
import '../../utils/currency_format.dart';
import '../expenses/expense_detail_screen.dart';
import '../../widget/empty_placeholder.dart';
import '../../widget/expense_tile.dart';

// Badge state
import '../../services/notification_service.dart';

const double _kMaxContentWidth = 900;

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  int _monthOffset = 0;
  DateTime? _selectedDay;

  DateTime get _now => DateTime.now();
  DateTime get _viewMonth {
    final m = DateTime(_now.year, _now.month + _monthOffset, 1);
    return DateTime(m.year, m.month, 1);
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _startOfDay(_now);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notiProvider.notifier).clear(NotiChannel.calendar);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final contentW = size.width < _kMaxContentWidth ? size.width : _kMaxContentWidth;

    final svc = ref.watch(expenseServiceProvider);
    final viewMonth = _viewMonth;

    final monthStart = DateTime(viewMonth.year, viewMonth.month, 1);
    final monthEnd = DateTime(viewMonth.year, viewMonth.month + 1, 0, 23, 59, 59, 999);

    final monthExpenses = svc.search(from: monthStart, to: monthEnd);

    final byDay = <String, List<Expense>>{};
    for (final e in monthExpenses) {
      final k = _keyOf(e.date);
      (byDay[k] ??= []).add(e);
    }

    final sel = _selectedDay;
    final isSelInMonth = sel != null && sel.year == viewMonth.year && sel.month == viewMonth.month;
    final effectiveSelected = isSelInMonth ? sel! : monthStart;

    final selKey = _keyOf(effectiveSelected);
    final listOfDay = byDay[selKey] ?? const <Expense>[];
    final totalOfDay = listOfDay.fold<double>(0, (s, e) => s + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: contentW,
          height: double.infinity,
          child: Column(
            children: [
              // Điều hướng tháng
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () => setState(() {
                          _monthOffset -= 1;
                          final m = _viewMonth;
                          _selectedDay = DateTime(m.year, m.month, 1);
                        }),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'tháng ${viewMonth.month.toString().padLeft(2, '0')} năm ${viewMonth.year}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () => setState(() {
                          _monthOffset += 1;
                          final m = _viewMonth;
                          _selectedDay = DateTime(m.year, m.month, 1);
                        }),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Header thứ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: const [
                    _WeekdayHeader('Th 2'),
                    _WeekdayHeader('Th 3'),
                    _WeekdayHeader('Th 4'),
                    _WeekdayHeader('Th 5'),
                    _WeekdayHeader('Th 6'),
                    _WeekdayHeader('Sat', color: Colors.redAccent),
                    _WeekdayHeader('Sun', color: Colors.redAccent),
                  ],
                ),
              ),

              // Lưới lịch
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildMonthGrid(
                  viewMonth: viewMonth,
                  expensesByDay: byDay,
                  selected: effectiveSelected,
                  onSelect: (d) => setState(() => _selectedDay = d),
                ),
              ),

              // Tổng hợp ngày
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Row(
                  children: [
                    Expanded(child: _SummaryChip(label: 'Chi Tiêu', value: '-${CurF.money(totalOfDay)}', color: Colors.red)),
                    const SizedBox(width: 8),
                    Expanded(child: _SummaryChip(label: 'Tổng', value: CurF.money(totalOfDay), color: Colors.green)),
                  ],
                ),
              ),

              // Danh sách chi tiêu của ngày
              Expanded(
                child: listOfDay.isEmpty
                    ? const EmptyPlaceholder(title: 'Không có chi tiêu', subtitle: 'Chọn ngày khác hoặc nhấn + để thêm chi tiêu')
                    : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  itemCount: listOfDay.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) {
                    final e = listOfDay[i];
                    return Dismissible(
                      key: ValueKey(e.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.red),
                      ),
                      confirmDismiss: (_) => _confirmDelete(context, e),
                      onDismissed: (_) async {
                        await ref.read(expenseServiceProvider).remove(e.id);
                        if (mounted) setState(() {});
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa chi tiêu')));
                      },
                      child: ExpenseTile(
                        e: e,
                        onTap: () async {
                          final changed = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ExpenseDetailScreen(e: e)),
                          );
                          if (changed == true && mounted) setState(() {});
                        },
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Helpers =====
  Future<bool> _confirmDelete(BuildContext context, Expense e) async {
    final cs = Theme.of(context).colorScheme;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa chi tiêu?'),
        content: Text('Bạn có chắc muốn xóa “${e.title}” (${CurF.money(e.amount)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    ) ??
        false;
  }

  Widget _buildMonthGrid({
    required DateTime viewMonth,
    required Map<String, List<Expense>> expensesByDay,
    required DateTime selected,
    required ValueChanged<DateTime> onSelect,
  }) {
    final firstOfMonth = DateTime(viewMonth.year, viewMonth.month, 1);
    final lastOfMonth = DateTime(viewMonth.year, viewMonth.month + 1, 0);

    final leadingEmpty = firstOfMonth.weekday - 1;
    final daysInMonth = lastOfMonth.day;
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final dayNum = cellIndex - leadingEmpty + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const _DayCell.empty();
            }

            final d = DateTime(viewMonth.year, viewMonth.month, dayNum);
            final key = _keyOf(d);
            final count = expensesByDay[key]?.length ?? 0;
            final isToday = _isSameDate(d, DateTime.now());
            final isSelected = _isSameDate(d, selected);

            return _DayCell(
              day: dayNum,
              isToday: isToday,
              isSelected: isSelected,
              count: count,
              onTap: () => onSelect(_startOfDay(d)),
            );
          }),
        );
      }),
    );
  }

  String _keyOf(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

// ===== Widgets con =====
class _WeekdayHeader extends StatelessWidget {
  final String text;
  final Color? color;
  const _WeekdayHeader(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Center(
          child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color ?? Colors.black54)),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int? day; // null nếu là ô trống
  final bool isToday;
  final bool isSelected;
  final int count;
  final VoidCallback? onTap;

  const _DayCell({
    Key? key,
    this.day,
    this.isToday = false,
    this.isSelected = false,
    this.count = 0,
    this.onTap,
  }) : super(key: key);

  const _DayCell.empty({Key? key})
      : day = null,
        isToday = false,
        isSelected = false,
        count = 0,
        onTap = null,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (day == null) {
      return Expanded(
        child: SizedBox(
          height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: cs.outline.withOpacity(.2))),
          ),
        ),
      );
    }

    final bg = isSelected ? cs.primary.withOpacity(.12) : Colors.transparent;
    final borderColor = isToday ? cs.primary : cs.outline.withOpacity(.25);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(color: bg, border: Border.all(color: borderColor)),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, top: 4),
                  child: Text('$day', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                ),
              ),
              if (count > 0)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    margin: const EdgeInsets.only(right: 4, bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(10)),
                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chi Tiêu', style: const TextStyle(fontSize: 12, height: 1.1, color: Colors.black54, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(height: 1.1, color: color, fontWeight: FontWeight.w800, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
