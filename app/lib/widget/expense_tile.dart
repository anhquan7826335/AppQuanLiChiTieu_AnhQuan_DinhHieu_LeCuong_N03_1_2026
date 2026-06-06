import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../utils/currency_format.dart';

class ExpenseTile extends StatelessWidget {
  final Expense e;
  final VoidCallback? onTap;
  const ExpenseTile({super.key, required this.e, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.6,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: _chipColor(context, e.category),
          child: Icon(_iconForCategory(e.category),
              color: Colors.white, size: 20),
        ),
        title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${e.category} · ${e.ymd}${e.note.isNotEmpty ? ' · ${e.note}' : ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(CurF.money(e.amount),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _iconForCategory(String cat) {
    switch (cat) {
      case 'Ăn uống':
        return Icons.restaurant_rounded;
      case 'Di chuyển':
        return Icons.directions_car_rounded;
      case 'Điện':
        return Icons.bolt_rounded;
      case 'Nước':
        return Icons.water_drop_rounded;
      case 'Điện thoại':
        return Icons.phone_iphone_rounded;
      case 'Bảo dưỡng xe':
        return Icons.build_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _chipColor(BuildContext ctx, String cat) {
    final cs = Theme.of(ctx).colorScheme;
    switch (cat) {
      case 'Ăn uống':
        return cs.primary;
      case 'Di chuyển':
        return cs.tertiary;
      case 'Điện':
        return cs.error;
      case 'Nước':
        return cs.secondary;
      case 'Điện thoại':
        return cs.primaryContainer;
      case 'Bảo dưỡng xe':
        return cs.errorContainer;
      default:
        return cs.outline;
    }
  }
}
