import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../providers.dart';
import '../../utils/constants.dart';
import '../../services/admin_service.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _q = TextEditingController();
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  List<Map<String, dynamic>> _items = [];

  /// userIds đang xử lý -> khoá nút để tránh spam
  final Set<String> _pending = {};

  String? get _adminId => ref.read(authServiceProvider).currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;

    final adminId = _adminId;
    if (adminId == null || adminId.isEmpty) {
      _toast('Thiếu admin_id (chưa đăng nhập?)');
      return;
    }

    setState(() => _loading = true);

    try {
      final p = reset ? 1 : _page + 1;
      final uri = Uri.parse('${AppConfig.baseUrl}/admin_users_list.php').replace(
        queryParameters: {
          'admin_id': adminId,
          'page': '$p',
          if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(),
          'limit': '20',
        },
      );
      final res = await http.get(uri);
      final data = _decode(res);
      if (res.statusCode == 200 && data['ok'] == true) {
        final List list = (data['data']?['items'] ?? []) as List;
        setState(() {
          if (reset) _items = [];
          _items.addAll(list.cast<Map<String, dynamic>>());
          _page = p;
          _hasMore = (data['data']?['has_more'] == true);
        });
      } else {
        _toast('Không tải được danh sách: ${data['error'] ?? res.statusCode}');
      }
    } catch (e) {
      _toast('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return {'ok': false, 'error': 'bad-json'};
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isActiveOf(Map<String, dynamic> u) {
    return (u['is_active'] is num)
        ? (u['is_active'] as num) != 0
        : (u['is_active'] == true || u['is_active'].toString() == '1');
  }

  Future<void> _toggleActive(Map<String, dynamic> u, bool next) async {
    final id = '${u['id']}';
    if (_pending.contains(id)) return;

    setState(() {
      _pending.add(id);
      u['is_active'] = next ? 1 : 0; // optimistic update
    });

    final ok =
    await ref.read(adminServiceProvider).updateUser(userId: id, isActive: next);

    if (!ok) {
      setState(() => u['is_active'] = next ? 0 : 1); // revert
      _toast('Cập nhật thất bại');
    }

    if (mounted) setState(() => _pending.remove(id));
  }

  Future<void> _changeRole(Map<String, dynamic> u) async {
    final cur = (u['role'] ?? 'user').toString();
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: const Text('user'),
            trailing: cur == 'user' ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, 'user'),
          ),
          ListTile(
            title: const Text('admin'),
            trailing: cur == 'admin' ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, 'admin'),
          ),
          const SizedBox(height: 6),
        ]),
      ),
    );
    if (v == null) return;

    final id = '${u['id']}';
    if (_pending.contains(id)) return;

    setState(() => _pending.add(id));

    final ok = await ref.read(adminServiceProvider).updateUser(userId: id, role: v);

    if (ok) {
      setState(() => u['role'] = v);
      _toast('Đã gán quyền $v');
    } else {
      _toast('Gán quyền thất bại');
    }

    if (mounted) setState(() => _pending.remove(id));
  }

  Future<void> _resetPassword(Map<String, dynamic> u) async {
    final tmp = await showDialog<String>(
      context: context,
      builder: (_) {
        final c = TextEditingController(text: 'Temp@1234');
        return AlertDialog(
          title: const Text('Đặt mật khẩu tạm'),
          content: TextField(
            controller: c,
            decoration:
            const InputDecoration(labelText: 'Mật khẩu tạm (ít nhất 6 ký tự)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
            FilledButton(
                onPressed: () => Navigator.pop(context, c.text.trim()),
                child: const Text('Đặt')),
          ],
        );
      },
    );
    if (tmp == null || tmp.length < 6) return;

    final id = '${u['id']}';
    if (_pending.contains(id)) return;

    setState(() => _pending.add(id));

    final ok =
    await ref.read(adminServiceProvider).resetPassword(userId: id, newPassword: tmp);

    if (ok) {
      _toast('Đã đặt mật khẩu tạm');
    } else {
      _toast('Không đặt được mật khẩu');
    }

    if (mounted) setState(() => _pending.remove(id));
  }

  // --------- Chỉnh sửa thông tin cá nhân ---------
  Future<void> _editUser(Map<String, dynamic> u) async {
    final id = '${u['id']}';
    if (_pending.contains(id)) return;

    // Helpers (đặt tên thường để tránh cảnh báo)
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final p = DateTime.tryParse(v.toString());
      return p == null ? null : DateTime(p.year, p.month, p.day);
    }

    String fmtDate(DateTime? d) {
      if (d == null) return '';
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      return '$dd/$mm/${d.year}';
    }

    final nameC  = TextEditingController(text: (u['name'] ?? '').toString());
    final emailC = TextEditingController(text: (u['email'] ?? '').toString());
    String role  = (u['role'] ?? 'user').toString();
    bool isActive = _isActiveOf(u);

    DateTime? birthday = parseDate(u['birthday']);
    String gender = (u['gender'] ?? '').toString().toLowerCase();
    if (!['male', 'female', 'other'].contains(gender)) gender = 'other';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Chỉnh sửa tài khoản'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Tên hiển thị'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailC,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),

                // Ngày sinh
                Row(
                  children: [
                    const Icon(Icons.cake_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final init =
                              birthday ?? DateTime(now.year - 18, now.month, now.day);
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(1900, 1, 1),
                            lastDate: now,
                            initialDate: init,
                          );
                          if (picked != null) setS(() => birthday = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Ngày sinh',
                            border: UnderlineInputBorder(),
                          ),
                          child: Text(birthday == null ? 'Chọn ngày' : fmtDate(birthday)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Giới tính
                Row(
                  children: [
                    const Icon(Icons.wc_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: gender,
                        items: const [
                          DropdownMenuItem(value: 'male',   child: Text('Nam')),
                          DropdownMenuItem(value: 'female', child: Text('Nữ')),
                          DropdownMenuItem(value: 'other',  child: Text('Khác')),
                        ],
                        onChanged: (v) => setS(() => gender = v ?? gender),
                        decoration: const InputDecoration(labelText: 'Giới tính'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Quyền & kích hoạt
                Row(
                  children: [
                    const Text('Quyền:'),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: role,
                      items: const [
                        DropdownMenuItem(value: 'user',  child: Text('user')),
                        DropdownMenuItem(value: 'admin', child: Text('admin')),
                      ],
                      onChanged: (v) => setS(() => role = v ?? role),
                    ),
                    const Spacer(),
                    const Text('Kích hoạt'),
                    Switch.adaptive(
                      value: isActive,
                      onChanged: (v) => setS(() => isActive = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu')),
          ],
        ),
      ),
    );

    if (ok != true) return;

    setState(() => _pending.add(id));
    final saved = await ref.read(adminServiceProvider).updateUserProfile(
      userId: id,
      name: nameC.text.trim(),
      email: emailC.text.trim(),
      role: role,
      isActive: isActive,
      birthday: birthday,
      gender: gender,
    );

    if (saved) {
      setState(() {
        u['name'] = nameC.text.trim();
        u['email'] = emailC.text.trim();
        u['role'] = role;
        u['is_active'] = isActive ? 1 : 0;

        final b = birthday;
        u['birthday'] = (b == null)
            ? null
            : '${b.year.toString().padLeft(4, '0')}-'
            '${b.month.toString().padLeft(2, '0')}-'
            '${b.day.toString().padLeft(2, '0')}';

        u['gender'] = gender;
      });
      _toast('Đã cập nhật tài khoản');
    } else {
      _toast('Cập nhật thất bại');
    }
    if (mounted) setState(() => _pending.remove(id));
  }

  // --------- Xoá cứng ----------
  Future<void> _confirmDelete(Map<String, dynamic> u) async {
    final id = '${u['id']}';
    if (_pending.contains(id)) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá tài khoản'),
        content: Text('Bạn chắc chắn muốn xoá tài khoản này?\n${u['email']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _pending.add(id));
    final done = await ref.read(adminServiceProvider).deleteUser(userId: id);
    if (done) {
      setState(() => _items.removeWhere((e) => '${e['id']}' == id));
      _toast('Đã xoá vĩnh viễn');
    } else {
      _toast('Xoá thất bại');
    }
    if (mounted) setState(() => _pending.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý người dùng')),
      body: LayoutBuilder(
        builder: (ctx, c) {
          final maxW = c.maxWidth;
          final pad = maxW < 600 ? 12.0 : 16.0;
          final contentW = maxW < 900 ? maxW : 820.0;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentW),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(pad, pad, pad, 6),
                    child: TextField(
                      controller: _q,
                      decoration: InputDecoration(
                        hintText: 'Tìm theo email hoặc tên…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _q.clear();
                            _load(reset: true);
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _load(reset: true),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(pad, 6, pad, pad),
                        itemCount: _items.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          if (i >= _items.length) {
                            return OutlinedButton(
                              onPressed: _loading ? null : () => _load(),
                              child: _loading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                                  : const Text('Tải thêm'),
                            );
                          }

                          final u = _items[i];
                          final isActive = _isActiveOf(u);
                          final role = (u['role'] ?? 'user').toString();
                          final id = '${u['id']}';
                          final busy = _pending.contains(id);

                          return Container(
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cs.primary.withValues(alpha: 0.12),
                                child: Text(
                                  (u['name'] ?? u['email'] ?? '?')
                                      .toString()
                                      .characters
                                      .first
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              title: Text(
                                (u['name'] ?? '').toString().trim().isEmpty
                                    ? (u['email'] ?? '').toString()
                                    : (u['name'] ?? '').toString(),
                              ),
                              subtitle: Text((u['email'] ?? '').toString()),
                              trailing: Wrap(
                                spacing: 6,
                                children: [
                                  FilterChip(
                                    label: Text(role),
                                    selected: role == 'admin',
                                    onSelected: (_) => _changeRole(u),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (busy)
                                        const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      const SizedBox(width: 8),
                                      IgnorePointer(
                                        ignoring: busy,
                                        child: Switch.adaptive(
                                          value: isActive,
                                          onChanged: (val) => _toggleActive(u, val),
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    tooltip: 'Đặt mật khẩu tạm',
                                    onPressed: busy ? null : () => _resetPassword(u),
                                    icon: const Icon(Icons.key_rounded),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Tác vụ',
                                    onSelected: (v) {
                                      if (v == 'edit') _editUser(u);
                                      if (v == 'delete') _confirmDelete(u);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: ListTile(
                                          leading: Icon(Icons.edit_rounded),
                                          title: Text('Chỉnh sửa'),
                                        ),
                                      ),
                                      PopupMenuDivider(),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                          leading: Icon(Icons.delete_forever_rounded, color: Colors.red),
                                          title: Text('Xoá vĩnh viễn', style: TextStyle(color: Colors.red)),
                                        ),
                                      ),
                                    ],
                                    child: const Icon(Icons.more_vert_rounded),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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
