import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers.dart';
import '../../utils/currency_format.dart';
import '../../models/expense.dart';

// Badge state
import '../../services/notification_service.dart';

enum Period { week, month, year }
enum ChartType { pie, bar }

const double _kMaxContentWidth = 900;

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  Period _period = Period.week;
  int _offset = 0;
  ChartType _chart = ChartType.pie;

  final bool _clampWeekInsideMonth = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notiProvider.notifier).clear(NotiChannel.analysis);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final contentW = size.width < _kMaxContentWidth ? size.width : _kMaxContentWidth;

    final svc = ref.watch(expenseServiceProvider);
    final range = _dateRange(DateTime.now(), _period, _offset);

    final List<Expense> list = svc.search(from: range.start, to: range.end);

    final Map<String, double> byCat = {};
    for (final e in list) {
      byCat.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
    final entries = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phân Tích', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: contentW,
          height: double.infinity,
          child: Column(
            children: [
              // Tabs Tuần / Tháng / Năm
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: cs.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      _periodTab(context, 'Tuần', Period.week),
                      _periodTab(context, 'Tháng', Period.month),
                      _periodTab(context, 'Năm', Period.year),
                    ],
                  ),
                ),
              ),

              // Header khoảng ngày + label
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_rangeLabel(range), style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Text('Chi Tiêu', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.chevron_left_rounded),  onPressed: () => setState(() => _offset -= 1)),
                        IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => setState(() => _offset += 1)),
                      ],
                    ),
                  ),
                ),
              ),

              // Biểu đồ
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF12324C), Color(0xFF12324C)],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 56),
                      child: _chart == ChartType.pie ? _buildPie(entries, total) : _buildBar(entries),
                    ),
                  ),
                ),
              ),

              // Tóm tắt
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Chi tiêu: -${CurF.money(total)}', style: TextStyle(color: cs.error, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),

      // Nút chuyển Pie/Bar
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chartBtn(icon: Icons.pie_chart_rounded, selected: _chart == ChartType.pie, onTap: () => setState(() => _chart = ChartType.pie)),
            const SizedBox(width: 8),
            _chartBtn(icon: Icons.bar_chart_rounded, selected: _chart == ChartType.bar, onTap: () => setState(() => _chart = ChartType.bar)),
          ],
        ),
      ),
    );
  }

  // ======= Widgets phụ =======
  Widget _periodTab(BuildContext context, String label, Period p) {
    final cs = Theme.of(context).colorScheme;
    final selected = _period == p;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() { _period = p; _offset = 0; }),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primary.withOpacity(.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? cs.primary : cs.onSurfaceVariant)),
        ),
      ),
    );
  }

  Widget _chartBtn({required IconData icon, required bool selected, required VoidCallback onTap}) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      containedInkWell: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black.withOpacity(.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, size: 18, color: Colors.black87),
      ),
    );
  }

  // ======= Chart builders =======
  Widget _buildPie(List<MapEntry<String, double>> entries, double total) {
    if (total <= 0) {
      return const Center(child: Text('Chưa có dữ liệu', style: TextStyle(color: Colors.white70)));
    }
    return PieChart(
      PieChartData(
        centerSpaceRadius: 46,
        sectionsSpace: 2,
        sections: [
          for (final e in entries)
            PieChartSectionData(
              value: e.value,
              color: _colorOf(e.key),
              radius: 72,
              title: '${(e.value / total * 100).toStringAsFixed(1)}%',
              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
              badgeWidget: _badgeForCat(e.key),
              badgePositionPercentageOffset: 1.15,
              titlePositionPercentageOffset: .55,
            ),
        ],
      ),
      swapAnimationDuration: const Duration(milliseconds: 250),
      swapAnimationCurve: Curves.easeOut,
    );
  }

  Widget _buildBar(List<MapEntry<String, double>> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu', style: TextStyle(color: Colors.white70)));
    }
    final show = entries.length <= 6 ? entries : entries.take(6).toList();
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < show.length; i++) {
      final e = show[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: e.value,
              width: 18,
              color: _colorOf(e.key),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8, top: 6),
      child: BarChart(
        BarChartData(
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (v) => FlLine(color: Colors.white24, strokeWidth: 1),
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= show.length) return const SizedBox.shrink();
                  final name = show[idx].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 11), overflow: TextOverflow.ellipsis),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
        swapAnimationDuration: const Duration(milliseconds: 250),
        swapAnimationCurve: Curves.easeOut,
      ),
    );
  }

  // ======= Date helpers =======
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  DateTimeRange _intersect(DateTimeRange a, DateTimeRange b) {
    final start = a.start.isAfter(b.start) ? a.start : b.start;
    final end = a.end.isBefore(b.end) ? a.end : b.end;
    if (start.isAfter(end)) return DateTimeRange(start: start, end: start);
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _dateRange(DateTime base, Period p, int offset) {
    base = DateTime.now();
    switch (p) {
      case Period.week:
        final today = _startOfDay(base);
        final monday = today.subtract(Duration(days: (today.weekday - 1)));
        final weekStart = _startOfDay(monday.add(Duration(days: 7 * offset)));
        final weekEnd = _endOfDay(weekStart.add(const Duration(days: 6)));
        final weekRange = DateTimeRange(start: weekStart, end: weekEnd);
        if (_clampWeekInsideMonth) {
          final m = DateTime(base.year, base.month, 1);
          final monthStart = _startOfDay(DateTime(m.year, m.month, 1));
          final monthEnd = _endOfDay(DateTime(m.year, m.month + 1, 0));
          final monthRange = DateTimeRange(start: monthStart, end: monthEnd);
          return _intersect(weekRange, monthRange);
        }
        return weekRange;

      case Period.month:
        final m = DateTime(base.year, base.month + offset, 1);
        final start = _startOfDay(DateTime(m.year, m.month, 1));
        final end = _endOfDay(DateTime(m.year, m.month + 1, 0));
        return DateTimeRange(start: start, end: end);

      case Period.year:
        final y = base.year + offset;
        final start = _startOfDay(DateTime(y, 1, 1));
        final end = _endOfDay(DateTime(y, 12, 31));
        return DateTimeRange(start: start, end: end);
    }
  }

  String _rangeLabel(DateTimeRange r) {
    String d(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    return '${d(r.start)} - ${d(r.end)}';
  }

  // ======= Màu & Icon theo danh mục =======
  Color _colorOf(String cat) {
    switch (cat) {
      case 'Ăn uống': return const Color(0xFFEF4444);
      case 'Di chuyển': return const Color(0xFFF59E0B);
      case 'Điện': return const Color(0xFF22C55E);
      case 'Nước': return const Color(0xFF3B82F6);
      case 'Điện thoại': return const Color(0xFF6366F1);
      case 'Bảo dưỡng xe': return const Color(0xFF14B8A6);
      default: return const Color(0xFFA855F7);
    }
  }

  IconData _iconOf(String cat) {
    switch (cat) {
      case 'Ăn uống': return Icons.restaurant_rounded;
      case 'Di chuyển': return Icons.directions_car_rounded;
      case 'Điện': return Icons.bolt_rounded;
      case 'Nước': return Icons.water_drop_rounded;
      case 'Điện thoại': return Icons.smartphone_rounded;
      case 'Bảo dưỡng xe': return Icons.build_rounded;
      default: return Icons.category_rounded;
    }
  }

  Widget _badgeForCat(String cat) {
    final bg = Colors.white;
    final fg = _colorOf(cat);
    final icon = _iconOf(cat);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 6, offset: const Offset(0, 2))],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: CircleAvatar(radius: 10, backgroundColor: fg, child: Icon(icon, size: 14, color: Colors.white)),
    );
  }
}
