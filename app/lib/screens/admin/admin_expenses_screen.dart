// lib/screens/admin/admin_expenses_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../providers.dart';
import '../../utils/constants.dart';
import '../../utils/currency_format.dart';
// ✅ THÊM import để dùng adminServiceProvider
import '../../services/admin_service.dart';

enum _TMode { month, year, custom }

class AdminExpensesScreen extends ConsumerStatefulWidget {
  const AdminExpensesScreen({super.key});

  @override
  ConsumerState<AdminExpensesScreen> createState() => _AdminExpensesScreenState();
}

class _AdminExpensesScreenState extends ConsumerState<AdminExpensesScreen> {
  final _userQ = TextEditingController();
  _TMode _mode = _TMode.month;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  int _onlyYear = DateTime.now().year;
  DateTimeRange? _custom;
  bool _loading = false;

  List<Map<String, dynamic>> _items = [];
  double _sum = 0;

  ({DateTime? from, DateTime? to}) _calcRange() {
    switch (_mode) {
      case _TMode.month:
        final f = DateTime(_year, _month, 1);
        final t = DateTime(_year, _month + 1, 0, 23, 59, 59);
        return (from: f, to: t);
      case _TMode.year:
        final f = DateTime(_onlyYear, 1, 1);
        final t = DateTime(_onlyYear, 12, 31, 23, 59, 59);
        return (from: f, to: t);
      case _TMode.custom:
        return (from: _custom?.start, to: _custom?.end);
    }
  }

  String _fmtD(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _custom ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 0),
          ),
    );
    if (picked != null) setState(() => _custom = picked);
  }

  Future<void> _search() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _items = [];
      _sum = 0;
    });

    final r = _calcRange();
    try {
      // ✅ Dùng AdminService để tự chèn admin_id + tham số đúng tên
      final admin = ref.read(adminServiceProvider);
      final resp = await admin.listExpenses(
        userQ: _userQ.text.trim(),
        from: r.from,
        to: r.to,
      );

      if (resp['ok'] == true) {
        final List list = (resp['data']?['items'] ?? []) as List;
        final casted = list
            .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
            .toList();

        setState(() {
          _items = casted.cast<Map<String, dynamic>>();
          _sum = _items.fold<double>(0, (s, e) {
            final v = e['amount'];
            if (v is num) return s + v.toDouble();
            if (v is String) return s + (double.tryParse(v) ?? 0);
            return s;
          });
        });
      } else {
        _toast('Không tải được dữ liệu: ${resp['error'] ?? 'unk'}');
      }
    } catch (e) {
      _toast('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _exportCsv() async {
    if (_items.isEmpty) {
      _toast('Không có dữ liệu để xuất');
      return;
    }
    try {
      final csv = StringBuffer()..writeln('user_email,user_name,category,amount,date,note');
      for (final e in _items) {
        String esc(String? s) => '"${(s ?? '').replaceAll('"', '""')}"';
        csv.writeln([
          esc('${e['user_email']}'),
          esc('${e['user_name']}'),
          esc('${e['category']}'),
          '${e['amount']}',
          esc('${e['date']}'),
          esc('${e['note']}'),
        ].join(','));
      }

      // ✅ Chỉ dùng API đã có: saveRawCsv
      final export = ref.read(exportServiceProvider);
      final path = await export.saveRawCsv(csv.toString(), filenameHint: 'admin_expenses');
      _toast(path == null ? 'Đã xuất CSV' : 'Đã lưu CSV: $path');
    } catch (e) {
      _toast('Xuất CSV lỗi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiêu toàn hệ thống')),
      body: LayoutBuilder(
        builder: (ctx, c) {
          final maxW = c.maxWidth;
          final contentW = maxW < 900 ? maxW : 880.0;
          final pad = maxW < 600 ? 12.0 : 20.0;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentW),
              child: ListView(
                padding: EdgeInsets.all(pad),
                children: [
                  // --- Bộ lọc ---
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _userQ,
                          decoration: const InputDecoration(
                            labelText: 'Lọc theo email hoặc tên người dùng',
                            prefixIcon: Icon(Icons.person_search_rounded),
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Tháng'),
                              selected: _mode == _TMode.month,
                              onSelected: (_) => setState(() => _mode = _TMode.month),
                            ),
                            ChoiceChip(
                              label: const Text('Năm'),
                              selected: _mode == _TMode.year,
                              onSelected: (_) => setState(() => _mode = _TMode.year),
                            ),
                            ChoiceChip(
                              label: const Text('Tuỳ chỉnh'),
                              selected: _mode == _TMode.custom,
                              onSelected: (_) => setState(() => _mode = _TMode.custom),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_mode == _TMode.month)
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _month,
                                  decoration: const InputDecoration(
                                    labelText: 'Tháng',
                                    prefixIcon: Icon(Icons.calendar_month_rounded),
                                  ),
                                  items: List.generate(
                                    12,
                                        (i) => DropdownMenuItem(value: i + 1, child: Text('Tháng ${i + 1}')),
                                  ),
                                  onChanged: (v) => setState(() => _month = v ?? _month),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _year,
                                  decoration: const InputDecoration(
                                      labelText: 'Năm', prefixIcon: Icon(Icons.event_rounded)),
                                  items: List.generate(
                                    20,
                                        (i) {
                                      final y = DateTime.now().year - 10 + i;
                                      return DropdownMenuItem(value: y, child: Text('Năm $y'));
                                    },
                                  ),
                                  onChanged: (v) => setState(() => _year = v ?? _year),
                                ),
                              ),
                            ],
                          ),
                        if (_mode == _TMode.year)
                          DropdownButtonFormField<int>(
                            value: _onlyYear,
                            decoration:
                            const InputDecoration(labelText: 'Năm', prefixIcon: Icon(Icons.date_range_rounded)),
                            items: List.generate(
                              20,
                                  (i) {
                                final y = DateTime.now().year - 10 + i;
                                return DropdownMenuItem(value: y, child: Text('Năm $y'));
                              },
                            ),
                            onChanged: (v) => setState(() => _onlyYear = v ?? _onlyYear),
                          ),
                        if (_mode == _TMode.custom)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_today_rounded),
                            title: Text(
                              _custom == null
                                  ? 'Chọn khoảng thời gian'
                                  : '${_fmtD(_custom!.start)} → ${_fmtD(_custom!.end)}',
                            ),
                            trailing: const Icon(Icons.event_rounded),
                            onTap: _pickRange,
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _search,
                            icon: _loading
                                ? const SizedBox(
                                height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.search_rounded),
                            label: const Text('Tìm'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tổng hợp
                  if (_items.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Tổng chi: ${CurF.money(_sum)} VND',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: Colors.red.shade400, fontWeight: FontWeight.w800),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _exportCsv,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Xuất CSV'),
                          )
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Danh sách
                  ..._items.map((e) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long_rounded),
                        title: Text(
                          '${e['category']}  •  ${CurF.money(double.tryParse('${e['amount']}') ?? 0)} VND',
                        ),
                        subtitle: Text(
                          '${e['date']}  •  ${(e['user_name'] ?? e['user_email'])}\n${(e['note'] ?? '')}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
