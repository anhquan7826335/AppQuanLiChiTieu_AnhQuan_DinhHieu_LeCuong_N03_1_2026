// lib/screens/settings/export_filter_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../models/expense.dart';
import '../../utils/constants.dart';

enum _TimeMode { month, year, custom }

class ExportFilterScreen extends ConsumerStatefulWidget {
  const ExportFilterScreen({super.key});
  @override
  ConsumerState<ExportFilterScreen> createState() => _ExportFilterScreenState();
}

class _ExportFilterScreenState extends ConsumerState<ExportFilterScreen> {
  // Money
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _moneyInput = FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]'));

  // Filters
  String? _category; // null = Tất cả
  _TimeMode _mode = _TimeMode.month;
  int _selMonth = DateTime.now().month;
  int _selYear = DateTime.now().year;
  int _yearOnly = DateTime.now().year;
  DateTimeRange? _customRange;

  // State
  bool _loading = false;
  OverlayEntry? _spinner;

  // ===== Utils =====
  double? _toNum(String s) {
    final raw = s.replaceAll('.', '').replaceAll(',', '').trim();
    return double.tryParse(raw);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  ({DateTime? from, DateTime? to}) _calcRange() {
    switch (_mode) {
      case _TimeMode.month:
        final from = DateTime(_selYear, _selMonth, 1);
        final to = DateTime(_selYear, _selMonth + 1, 0, 23, 59, 59);
        return (from: from, to: to);
      case _TimeMode.year:
        final from = DateTime(_yearOnly, 1, 1);
        final to = DateTime(_yearOnly, 12, 31, 23, 59, 59);
        return (from: from, to: to);
      case _TimeMode.custom:
        return (from: _customRange?.start, to: _customRange?.end);
    }
  }

  void _showSpinner() {
    if (_spinner != null || !mounted) return;
    _spinner = OverlayEntry(
      builder: (_) => const Stack(
        children: [
          Positioned.fill(child: AbsorbPointer()),
          Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context)?.insert(_spinner!);
  }

  void _hideSpinner() {
    _spinner?.remove();
    _spinner = null;
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 0),
          ),
    );
    if (picked != null && mounted) setState(() => _customRange = picked);
  }

  Future<void> _export() async {
    if (_loading || !mounted) return;
    setState(() => _loading = true);
    _showSpinner();

    try {
      final expenses = ref.read(expenseServiceProvider);
      final export = ref.read(exportServiceProvider);

      final minV = _toNum(_minCtrl.text);
      final maxV = _toNum(_maxCtrl.text);
      final range = _calcRange();

      // Lọc
      List<Expense> items = expenses.filter(
        from: range.from,
        to: range.to,
        category: _category,
      );
      if (minV != null) items = items.where((e) => e.amount >= minV).toList();
      if (maxV != null) items = items.where((e) => e.amount <= maxV).toList();

      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không có dữ liệu phù hợp để xuất')),
          );
        }
        return;
      }

      final savedPath = await export.exportCsv(items); // nhớ dùng compute trong ExportService
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã lưu CSV: $savedPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xuất CSV thất bại: $e')),
        );
      }
    } finally {
      _hideSpinner();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _hideSpinner();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cats = ExpenseCategory.labels
        .where((e) => e != ExpenseCategory.labelAll)
        .toList();

    // ✅ Chặn gesture back khi đang export (tránh overlay mồ côi / pop giữa chừng)
    return PopScope(
      canPop: !_loading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Bộ Lọc')),
        body: LayoutBuilder(
          builder: (ctx, c) {
            final maxW = c.maxWidth;
            final contentW = maxW < 900 ? maxW : 820.0;
            final pad = maxW < 600 ? 14.0 : 20.0;
            final fieldPadV = maxW < 600 ? 10.0 : 12.0;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(pad),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentW),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ChipTitle('Tiền'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _BoxField(
                              paddingV: fieldPadV,
                              prefix: const Icon(Icons.south_rounded),
                              child: TextField(
                                controller: _minCtrl,
                                inputFormatters: [_moneyInput],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Tối thiểu',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _BoxField(
                              paddingV: fieldPadV,
                              prefix: const Icon(Icons.north_rounded),
                              child: TextField(
                                controller: _maxCtrl,
                                inputFormatters: [_moneyInput],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Tối đa',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _ChipTitle('Thời Gian'),
                      const SizedBox(height: 8),
                      _TimeModeCard(
                        mode: _mode,
                        onModeChanged: (m) => setState(() => _mode = m),
                        selMonth: _selMonth,
                        selYear: _selYear,
                        onMonthChanged: (m) => setState(() => _selMonth = m),
                        onYearChanged: (y) => setState(() => _selYear = y),
                        yearOnly: _yearOnly,
                        onYearOnlyChanged: (y) => setState(() => _yearOnly = y),
                        range: _customRange,
                        onPickRange: _pickCustomRange,
                        dateFormatter: _fmtDate,
                      ),
                      const SizedBox(height: 16),

                      _ChipTitle('Nhóm'),
                      const SizedBox(height: 8),
                      _BoxField(
                        paddingV: fieldPadV,
                        suffix: const Icon(Icons.keyboard_arrow_down_rounded),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _category,
                            isExpanded: true,
                            items: <DropdownMenuItem<String?>>[
                              const DropdownMenuItem<String?>(value: null, child: Text('Tất cả')),
                              ...cats.map(
                                    (c) => DropdownMenuItem<String?>(
                                  value: c,
                                  child: Text(c),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _category = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        height: 46,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _export,
                          icon: _loading
                              ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.download_rounded),
                          label: Text(_loading ? 'Đang xuất…' : 'Xuất CSV'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E6B3A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// === Sub-widgets ===

class _ChipTitle extends StatelessWidget {
  final String text;
  const _ChipTitle(this.text);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _BoxField extends StatelessWidget {
  final Widget child;
  final Widget? prefix;
  final Widget? suffix;
  final double paddingV;
  const _BoxField({
    required this.child,
    this.prefix,
    this.suffix,
    this.paddingV = 12,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: paddingV),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          if (prefix != null) ...[prefix!, const SizedBox(width: 8)],
          Expanded(child: child),
          if (suffix != null) ...[const SizedBox(width: 8), suffix!],
        ],
      ),
    );
  }
}

class _TimeModeCard extends StatelessWidget {
  final _TimeMode mode;
  final ValueChanged<_TimeMode> onModeChanged;

  final int selMonth;
  final int selYear;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;

  final int yearOnly;
  final ValueChanged<int> onYearOnlyChanged;

  final DateTimeRange? range;
  final VoidCallback onPickRange;

  final String Function(DateTime) dateFormatter;

  const _TimeModeCard({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.selMonth,
    required this.selYear,
    required this.onMonthChanged,
    required this.onYearChanged,
    required this.yearOnly,
    required this.onYearOnlyChanged,
    required this.range,
    required this.onPickRange,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, _TimeMode m) {
      final selected = mode == m;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onModeChanged(m),
        labelStyle: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
      );
    }

    Widget monthYear() {
      final months = List.generate(12, (i) => i + 1);
      final years = List.generate(20, (i) => DateTime.now().year - 10 + i);
      return Row(
        children: [
          Expanded(
            child: _BoxField(
              prefix: const Icon(Icons.calendar_month_rounded),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selMonth,
                  isExpanded: true,
                  items: months
                      .map((m) => DropdownMenuItem(value: m, child: Text('Tháng $m')))
                      .toList(),
                  onChanged: (v) => onMonthChanged(v ?? selMonth),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BoxField(
              prefix: const Icon(Icons.event_rounded),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selYear,
                  isExpanded: true,
                  items: years
                      .map((y) => DropdownMenuItem(value: y, child: Text('Năm $y')))
                      .toList(),
                  onChanged: (v) => onYearChanged(v ?? selYear),
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget yearOnlyPicker() {
      final years = List.generate(20, (i) => DateTime.now().year - 10 + i);
      return _BoxField(
        prefix: const Icon(Icons.date_range_rounded),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: yearOnly,
            isExpanded: true,
            items: years
                .map((y) => DropdownMenuItem(value: y, child: Text('Năm $y')))
                .toList(),
            onChanged: (v) => onYearOnlyChanged(v ?? yearOnly),
          ),
        ),
      );
    }

    Widget customPicker() {
      return _BoxField(
        prefix: const Icon(Icons.calendar_today_rounded),
        suffix: const Icon(Icons.event_rounded),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            range == null
                ? 'Chọn khoảng thời gian'
                : '${dateFormatter(range!.start)}  →  ${dateFormatter(range!.end)}',
          ),
          onTap: onPickRange,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            chip('Tháng', _TimeMode.month),
            chip('Năm', _TimeMode.year),
            chip('Tuỳ chỉnh', _TimeMode.custom),
          ]),
          const SizedBox(height: 12),
          if (mode == _TimeMode.month) monthYear(),
          if (mode == _TimeMode.year) yearOnlyPicker(),
          if (mode == _TimeMode.custom) customPicker(),
        ],
      ),
    );
  }
}
