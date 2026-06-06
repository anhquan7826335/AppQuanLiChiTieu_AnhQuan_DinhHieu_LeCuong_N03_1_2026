import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../utils/currency_format.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(expenseServiceProvider);

    final now = DateTime.now();
    final from = _range?.start ?? DateTime(now.year, now.month, 1);
    final to   = _range?.end   ?? DateTime(now.year, now.month + 1, 0);
    final list = svc.search(from: from, to: to);

    final total = list.fold<double>(0, (s, e) => s + e.amount);
    final byCat = <String, double>{};
    for (final e in list) {
      byCat.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Phân tích')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 5),
                      initialDateRange: _range,
                    );
                    if (picked != null) setState(() => _range = picked);
                  },
                  child: Text(
                    '${from.toString().substring(0, 10)} → ${to.toString().substring(0, 10)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('Tổng chi: ${CurF.money(total)}')),
                if (svc.monthlyBudget > 0)
                  Chip(label: Text('Ngân sách: ${CurF.money(svc.monthlyBudget)}')),
                if (svc.monthlyBudget > 0)
                  Chip(
                    avatar: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                    label: Text('Còn lại: ${CurF.money(svc.monthlyBudget - total)}'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Theo danh mục', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...byCat.entries.map(
                          (e) => ListTile(
                        dense: true,
                        title: Text(e.key),
                        trailing: Text(CurF.money(e.value)),
                      ),
                    ),
                    if (byCat.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Không có dữ liệu trong khoảng đã chọn'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
