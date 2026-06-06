import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expense.dart';
import '../../providers.dart';
import '../../utils/currency_format.dart';
import 'expense_form_screen.dart';

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  final Expense e;
  const ExpenseDetailScreen({super.key, required this.e});

  @override
  ConsumerState<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  late Future<List<String>> _imgsFuture; // URLs ảnh

  @override
  void initState() {
    super.initState();
    // gọi ngay khi mở màn
    _imgsFuture = ref.read(expenseServiceProvider).fetchAttachments(widget.e.id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = widget.e;

    Future<void> deleteExpense() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Xoá chi tiêu?'),
          content: const Text('Thao tác này không thể hoàn tác.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Xoá'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await ref.read(expenseServiceProvider).remove(e.id);
      if (mounted) Navigator.pop(context, true);
    }

    final dateStr =
        '${_dd(e.date.day)}/${_dd(e.date.month)}/${e.date.year} - ${_dd(e.date.hour)}:${_dd(e.date.minute)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết chi tiêu'),
        actions: [
          IconButton(
            tooltip: 'Sửa',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ExpenseFormScreen(expense: e)),
              );
              if (mounted) {
                // quay lại list yêu cầu refresh
                Navigator.pop(context, true);
              }
            },
          ),
          IconButton(
            tooltip: 'Xoá',
            icon: const Icon(Icons.delete_rounded),
            onPressed: deleteExpense,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _circleIcon(_iconByCat(e.category), _colorByCat(e.category)),
                        const SizedBox(width: 10),
                        Text(e.category, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: Text(
                            '${CurF.money(e.amount)} VND',
                            style: TextStyle(
                              color: Colors.red.shade400,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ]),
                      const Divider(height: 18),
                      _infoRow(icon: Icons.event_rounded, color: Colors.orange, text: dateStr),
                      if (e.note.trim().isNotEmpty)
                        _infoRow(
                          icon: Icons.sticky_note_2_rounded,
                          color: Colors.brown,
                          text: e.note,
                          multiline: true,
                        ),
                      const SizedBox(height: 8),
                      _friendsAndLocationFromNote(e.note, cs),

                      // ====== ẢNH ĐÍNH KÈM ======
                      const SizedBox(height: 12),
                      FutureBuilder<List<String>>(
                        future: _imgsFuture,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(),
                            ));
                          }
                          final imgs = snap.data ?? const [];
                          if (imgs.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text('Ảnh đính kèm', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 1,
                                ),
                                itemCount: imgs.length,
                                itemBuilder: (_, i) {
                                  final url = imgs[i];
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      onTap: () => _openImageViewer(context, imgs, i),
                                      child: Image.network(url, fit: BoxFit.cover),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openImageViewer(BuildContext ctx, List<String> urls, int index) {
    Navigator.push(ctx, MaterialPageRoute(builder: (_) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: PageView.builder(
          controller: PageController(initialPage: index),
          itemCount: urls.length,
          itemBuilder: (_, i) => InteractiveViewer(
            child: Center(child: Image.network(urls[i])),
          ),
        ),
      );
    }));
  }

  // ===== helpers =====
  static Widget _infoRow({
    required IconData icon,
    required Color color,
    required String text,
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withOpacity(.15),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.3))),
        ],
      ),
    );
  }

  static Widget _friendsAndLocationFromNote(String note, ColorScheme cs) {
    final lines = note.split('\n');
    String? location;
    List<String> friends = [];

    for (final line in lines) {
      final l = line.trim();
      if (l.toLowerCase().startsWith('vị trí:')) {
        location = l.substring(6).trim();
      } else if (l.toLowerCase().startsWith('bạn bè:')) {
        final names = l.substring(7).split(RegExp(r'[;,]')).map((s) => s.trim()).where((s) => s.isNotEmpty);
        friends = names.toList();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (location != null && location.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.green.withOpacity(.15),
                  child: const Icon(Icons.place_rounded, size: 16, color: Colors.green),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(location)),
              ],
            ),
          ),
        if (friends.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.pink.withOpacity(.15),
                child: const Icon(Icons.group_rounded, size: 16, color: Colors.pink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: friends
                      .map(
                        (f) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(f),
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor: cs.primary.withOpacity(.15),
                        child: Text(
                          f.characters.first.toUpperCase(),
                          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),
                  )
                      .toList(),
                ),
              ),
            ],
          ),
      ],
    );
  }

  static IconData _iconByCat(String cat) {
    switch (cat) {
      case 'Ăn uống': return Icons.restaurant_rounded;
      case 'Di chuyển': return Icons.directions_car_rounded;
      case 'Điện': return Icons.electric_bolt_rounded;
      case 'Nước': return Icons.water_drop_rounded;
      case 'Điện thoại': return Icons.phone_iphone_rounded;
      case 'Bảo dưỡng xe': return Icons.build_rounded;
      default: return Icons.category_rounded;
    }
  }

  static Color _colorByCat(String cat) {
    switch (cat) {
      case 'Ăn uống': return Colors.orange;
      case 'Di chuyển': return Colors.blue;
      case 'Điện': return Colors.amber;
      case 'Nước': return Colors.cyan;
      case 'Điện thoại': return Colors.indigo;
      case 'Bảo dưỡng xe': return Colors.teal;
      default: return Colors.brown;
    }
  }

  static Widget _circleIcon(IconData icon, Color color) => CircleAvatar(
    radius: 18,
    backgroundColor: color.withOpacity(.15),
    child: Icon(icon, size: 20, color: color),
  );

  static String _dd(int n) => n.toString().padLeft(2, '0');
}
