// lib/screens/settings/settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../utils/constants.dart';
import '../account/account_screen.dart';
import 'export_filter_screen.dart';
import '../admin/admin_home_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _budgetCtrl = TextEditingController();
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();

  // Dùng để bust cache ảnh sau khi upload xong
  int _avatarTick = 0;

  // Busy guards để chặn bấm nhanh liên tiếp
  bool _busyAvatar = false;
  bool _busyBudget = false;
  bool _busyPwd = false;
  bool _busySync = false;

  final _moneyInput = FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]'));

  @override
  void initState() {
    super.initState();
    final exp = ref.read(expenseServiceProvider);
    _budgetCtrl.text = _fmtMoney(exp.monthlyBudget);

    // ensureLoaded sau frame đầu tiên để không block build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileServiceProvider);
      try {
        (profile as dynamic).ensureLoaded?.call();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  // ================= Helpers =================
  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _fmtMoney(num v) {
    final s = v.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final r = s.length - i;
      b.write(s[i]);
      if (r > 1 && r % 3 == 1) b.write('.');
    }
    return '${b.toString()} đ';
  }

  double? _parseMoney(String input) {
    final raw = input.replaceAll('.', '').replaceAll(',', '').trim();
    return double.tryParse(raw);
  }

  String _absUrl(String raw) {
    if (raw.startsWith('http') || raw.startsWith('file:')) return raw;
    final base = AppConfig.baseUrl;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = raw.startsWith('/') ? raw.substring(1) : raw;
    return '$b/$p';
  }

  ImageProvider? _avatarProvider(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final src = raw.trim();

    if (src.startsWith('file://')) {
      final path = src.substring(7);
      if (path.isEmpty) return null;
      final f = File(path);
      return f.existsSync() ? FileImage(f) : null;
    }
    if (!src.contains('://') && (src.startsWith('/') || src.contains(Platform.pathSeparator))) {
      final f = File(src);
      if (f.existsSync()) return FileImage(f);
    }
    final abs = _absUrl(src);
    final bust = abs.contains('?') ? '$abs&cb=$_avatarTick' : '$abs?cb=$_avatarTick';
    return NetworkImage(bust);
  }

  // ================= Actions =================
  Future<void> _saveBudget() async {
    if (_busyBudget) return;
    setState(() => _busyBudget = true);
    try {
      final exp = ref.read(expenseServiceProvider);
      final v = _parseMoney(_budgetCtrl.text);
      if (v == null || v < 0) {
        _snack('Số tiền không hợp lệ');
        return;
      }
      await exp.setMonthlyBudget(v);
      _snack('Đã lưu ngân sách');
    } catch (e) {
      _snack('Lưu ngân sách thất bại: $e');
    } finally {
      if (mounted) setState(() => _busyBudget = false);
    }
  }

  Future<void> _changePassword() async {
    if (_busyPwd) return;
    setState(() => _busyPwd = true);
    try {
      final dynamic auth = ref.read(authServiceProvider);
      final oldPwd = _oldPwdCtrl.text.trim();
      final newPwd = _newPwdCtrl.text.trim();
      final confirm = _confirmPwdCtrl.text.trim();

      if (newPwd.length < 6) {
        _snack('Mật khẩu mới phải ≥ 6 ký tự');
        return;
      }
      if (newPwd != confirm) {
        _snack('Xác nhận mật khẩu không khớp');
        return;
      }

      await auth.changePassword?.call(oldPwd: oldPwd, newPwd: newPwd);
      _oldPwdCtrl.clear();
      _newPwdCtrl.clear();
      _confirmPwdCtrl.clear();
      _snack('Đổi mật khẩu thành công');
    } catch (e) {
      _snack('Chưa cấu hình đổi mật khẩu trong AuthService hoặc lỗi: $e');
    } finally {
      if (mounted) setState(() => _busyPwd = false);
    }
  }

  Future<void> _syncNow() async {
    if (_busySync) return;
    setState(() => _busySync = true);
    _snack('Đang đồng bộ…');
    try {
      await ref.read(syncServiceProvider).syncNow();
      _snack('Đồng bộ thành công');
    } catch (e) {
      _snack('Đồng bộ thất bại: $e');
    } finally {
      if (mounted) setState(() => _busySync = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (_busyAvatar) return;
    setState(() => _busyAvatar = true);
    try {
      final profile = ref.read(profileServiceProvider);
      await (profile as dynamic).pickAndUploadAvatar?.call();
      if (!mounted) return;
      setState(() => _avatarTick++); // bust cache ảnh sau upload
      _snack('Đã cập nhật ảnh đại diện');
    } catch (e) {
      _snack('Chưa cấu hình cập nhật avatar trong ProfileService hoặc lỗi: $e');
    } finally {
      if (mounted) setState(() => _busyAvatar = false);
    }
  }

  Future<void> _logout() async {
    final auth = ref.read(authServiceProvider);
    try {
      await (auth as dynamic).logout?.call() ?? auth.logout();
      if (!mounted) return;
      _snack('Đã đăng xuất');
      // Optionally pop back to root if cần:
      // Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      _snack('Đăng xuất thất bại: $e');
    }
  }

  Future<bool> _confirmLogout() async {
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _openAccount() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
  }

  void _openExportFilter() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportFilterScreen()));
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final exp = ref.watch(expenseServiceProvider);
    final profile = ref.watch(profileServiceProvider);
    final auth = ref.watch(authServiceProvider);

    final bool isAdmin = (auth.currentUser?.role?.toLowerCase() == 'admin');
    final String name = (profile.name ?? '').trim().isEmpty ? '—' : profile.name!.trim();
    final imgProvider = _avatarProvider(profile.avatarUrl);
    final double monthlyMoney = exp.monthlyBudget;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== Header =====
          Card(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: SizedBox(
              height: 210,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.black.withOpacity(.08),
                        backgroundImage: imgProvider,
                        child: (imgProvider == null)
                            ? Icon(Icons.person, size: 44, color: Colors.green.shade900)
                            : null,
                      ),
                      Material(
                        color: _busyAvatar ? Colors.grey : Colors.green.shade700,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _busyAvatar ? null : _pickAvatar,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _busyAvatar
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Tiền hàng tháng', style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    _fmtMoney(monthlyMoney),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ===== Danh sách chức năng =====
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const _IconTile(color: Color(0xFF4DA3FF), icon: Icons.person),
                  title: const Text('Tài khoản'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openAccount,
                ),
                const Divider(height: 1),

                ListTile(
                  leading: const _IconTile(color: Color(0xFFFFA14D), icon: Icons.lock),
                  title: const Text('Đổi mật khẩu'),
                  trailing: _busyPwd
                      ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    if (_busyPwd) return;
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (ctx) => Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(ctx).viewInsets.bottom,
                          left: 16,
                          right: 16,
                          top: 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _oldPwdCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Mật khẩu hiện tại',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _newPwdCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Mật khẩu mới',
                                prefixIcon: Icon(Icons.lock_reset),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmPwdCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Xác nhận mật khẩu mới',
                                prefixIcon: Icon(Icons.verified_user_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(children: [
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _changePassword();
                                },
                                icon: const Icon(Icons.check),
                                label: const Text('Lưu'),
                              ),
                            ]),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),

                ListTile(
                  leading: const _IconTile(color: Color(0xFF7AD17A), icon: Icons.credit_card),
                  title: const Text('Nhập ngân sách'),
                  subtitle: const Text('Quản lý ngân sách'),
                  trailing: _busyBudget
                      ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_fmtMoney(exp.monthlyBudget)),
                  onTap: () {
                    if (_busyBudget) return;
                    _budgetCtrl.text =
                        _fmtMoney(exp.monthlyBudget).replaceAll(' đ', '');
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (ctx) => Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(ctx).viewInsets.bottom,
                          left: 16,
                          right: 16,
                          top: 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _budgetCtrl,
                              keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [_moneyInput],
                              decoration: const InputDecoration(
                                labelText: 'Số tiền (VND)',
                                prefixIcon:
                                Icon(Icons.account_balance_wallet_outlined),
                                hintText: 'VD: 5.000.000',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(children: [
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _saveBudget();
                                },
                                icon: const Icon(Icons.save),
                                label: const Text('Lưu ngân sách'),
                              ),
                            ]),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),

                ListTile(
                  leading: const _IconTile(color: Color(0xFF8ED0FF), icon: Icons.download),
                  title: const Text('Xuất CSV'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openExportFilter,
                ),
                const Divider(height: 1),

                ListTile(
                  leading: const _IconTile(color: Color(0xFF00A8A8), icon: Icons.sync),
                  title: const Text('Đồng bộ dữ liệu'),
                  trailing: _busySync
                      ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  onTap: _syncNow,
                ),
                const Divider(height: 1),

                if (isAdmin) ...[
                  ListTile(
                    leading: const _IconTile(
                      color: Color(0xFF7C4DFF),
                      icon: Icons.admin_panel_settings_rounded,
                    ),
                    title: const Text('Bảng điều khiển Admin'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                ],

                ListTile(
                  leading: const _IconTile(color: Color(0xFFFF6B6B), icon: Icons.logout),
                  title: const Text('Đăng xuất', style: TextStyle(color: Color(0xFFDB3A34))),
                  onTap: () async {
                    if (await _confirmLogout()) {
                      await _logout();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _IconTile({required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withOpacity(.18),
      child: Icon(icon, color: color),
    );
  }
}
