import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/expense.dart';
import '../../providers.dart';

// Cộng badge khi thêm chi tiêu
import '../../services/notification_service.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final Expense? expense;
  const ExpenseFormScreen({super.key, this.expense});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _location = TextEditingController();
  final _friends = TextEditingController();

  String _category = 'Ăn uống';
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _more = true;

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      final e = widget.expense!;
      _category = e.category;
      _date = e.date;
      _time = TimeOfDay.fromDateTime(e.date);
      _note.text = e.note;
      _amount.text = e.amount > 0 ? e.amount.toStringAsFixed(0) : '';
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _location.dispose();
    _friends.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickCategory() async {
    final cs = Theme.of(context).colorScheme;
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _catItem(Icons.restaurant_rounded, 'Ăn uống', Colors.orange),
            _catItem(Icons.directions_car_rounded, 'Di chuyển', Colors.blue),
            _catItem(Icons.electric_bolt_rounded, 'Điện', Colors.amber.shade800),
            _catItem(Icons.water_drop_rounded, 'Nước', Colors.cyan),
            _catItem(Icons.phone_iphone_rounded, 'Điện thoại', Colors.indigo),
            _catItem(Icons.build_rounded, 'Bảo dưỡng xe', Colors.teal),
            _catItem(Icons.category_rounded, 'Khác', cs.primary),
          ],
        ),
      ),
    );
    if (v != null) setState(() => _category = v);
  }

  ListTile _catItem(IconData icon, String label, Color color) =>
      ListTile(leading: _circleIcon(icon, color), title: Text(label), onTap: () => Navigator.pop(context, label));

  Widget _circleIcon(IconData icon, Color color) =>
      CircleAvatar(radius: 16, backgroundColor: color.withOpacity(.15), child: Icon(icon, color: color, size: 18));

  Future<void> _addImage(ImageSource source) async {
    try {
      final x = await _picker.pickImage(source: source, imageQuality: 85);
      if (x != null) setState(() => _images.add(x));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lấy được ảnh: $e')));
    }
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  Future<void> _save() async {
    final svc = ref.read(expenseServiceProvider);
    final amt = double.tryParse(_amount.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;

    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập số tiền > 0')));
      return;
    }

    final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

    if (widget.expense == null) {
      // Thêm mới
      final saved = await svc.add(
        Expense(
          id: 'tmp',
          title: _category,
          category: _category,
          amount: amt,
          date: dt,
          note: _mergeNote(),
        ),
      );

      // Upload ảnh (nếu có)
      if (_images.isNotEmpty && saved.id.isNotEmpty) {
        await svc.uploadAttachments(expenseId: saved.id, files: List<XFile>.from(_images));
      }

      // +1 badge cho cả "Phân tích" và "Lịch"
      ref.read(notiProvider.notifier).incrementAll();

    } else {
      // Cập nhật
      await svc.update(
        widget.expense!.copyWith(
          title: _category,
          category: _category,
          amount: amt,
          date: dt,
          note: _mergeNote(),
        ),
      );

      // Upload ảnh mới (nếu có)
      if (_images.isNotEmpty && widget.expense!.id.isNotEmpty) {
        await svc.uploadAttachments(expenseId: widget.expense!.id, files: List<XFile>.from(_images));
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  String _mergeNote() {
    final parts = <String>[];
    if (_note.text.trim().isNotEmpty) parts.add(_note.text.trim());
    if (_location.text.trim().isNotEmpty) parts.add('Vị trí: ${_location.text.trim()}');
    if (_friends.text.trim().isNotEmpty) parts.add('Bạn bè: ${_friends.text.trim()}');
    if (_images.isNotEmpty) parts.add('Ảnh đính kèm: ${_images.length} hình (demo)');
    return parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm Chi Tiêu'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Lưu', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              // Số tiền
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amount,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '0', border: InputBorder.none),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('VND', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Loại
              _cardTile(
                leading: _circleIcon(Icons.help_outline_rounded, Colors.blueGrey),
                title: const Text('Loại'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_category, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: _pickCategory,
              ),

              // Ngày
              _cardTile(
                leading: _circleIcon(Icons.event_rounded, Colors.orange),
                title: Text(_fmtDate(_date)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _pickDate,
              ),

              // Giờ
              _cardTile(
                leading: _circleIcon(Icons.access_time_rounded, Colors.amber.shade700),
                title: Text(_fmtTime(_time)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _pickTime,
              ),

              // Ghi chú
              _cardTile(
                leading: _circleIcon(Icons.edit_note_rounded, Colors.brown),
                title: TextField(
                  controller: _note,
                  decoration: const InputDecoration(border: InputBorder.none, hintText: 'Ghi Chú'),
                ),
              ),

              if (_more) ...[
                const SizedBox(height: 8),
                // Vị trí
                _cardTile(
                  leading: _circleIcon(Icons.place_rounded, Colors.green),
                  title: TextField(
                    controller: _location,
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Vị Trí'),
                  ),
                ),

                const SizedBox(height: 8),
                // Bạn bè
                _cardTile(
                  leading: _circleIcon(Icons.group_rounded, Colors.pink),
                  title: TextField(
                    controller: _friends,
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Bạn bè'),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),

                const SizedBox(height: 8),
                // Ảnh + Camera
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _addImage(ImageSource.gallery),
                          icon: const Icon(Icons.image_rounded),
                          label: const Text(''),
                        ),
                      ),
                      Container(width: 1, height: 36, color: cs.outlineVariant),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _addImage(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_rounded),
                          label: const Text(''),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 86,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final f = File(_images[i].path);
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(f, width: 110, height: 86, fit: BoxFit.cover),
                            ),
                            Positioned(
                              right: -8,
                              top: -8,
                              child: IconButton.filled(
                                style: ButtonStyle(
                                  backgroundColor: WidgetStatePropertyAll(Colors.black.withOpacity(.55)),
                                ),
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                onPressed: () => _removeImage(i),
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _more = !_more),
                  child: Text(_more ? 'Ẩn bớt  ↑' : 'Hiện thêm  ↓'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helpers
  Widget _cardTile({required Widget leading, required Widget title, Widget? trailing, VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: leading,
        title: title,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
