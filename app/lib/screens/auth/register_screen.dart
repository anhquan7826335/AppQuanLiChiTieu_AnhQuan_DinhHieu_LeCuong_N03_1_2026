import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'login_screen.dart';

const double _kAuthMaxWidth = 480; // giới hạn bề rộng form trên desktop/tablet

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  DateTime? _dob;
  String _gender = 'Male'; // 'Male' | 'Female'
  bool _showPass = false;
  bool _showConfirm = false;
  bool _loading = false;

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu không khớp')),
      );
      return;
    }
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập email và mật khẩu')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);

      // Đăng ký tài khoản (có gender & birthday)
      await auth.register(
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
        gender: _gender,   // 'Male' | 'Female'
        birthday: _dob,    // DateTime?
      );

      // >>> GHI LOCAL để AccountScreen hiển thị ngay sau đăng nhập
      // (yêu cầu ProfileService đã có setProfile(name, birthday, gender))
      ref.read(profileServiceProvider).setProfile(
        name: _name.text.trim(),
        birthday: _dob,
        gender: _gender,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thành công! Vui lòng đăng nhập.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng ký thất bại: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kAuthMaxWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 16 + bottomInset),
              children: [
                // ===== Header =====
                Text(
                  'Chào người dùng mới!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chào mừng bạn đến với ứng dụng',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 18),

                // ===== Form =====
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Họ Tên',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 16),

                // Giới tính (Nam / Nữ)
                Row(
                  children: [
                    Expanded(
                      child: _GenderCard(
                        label: 'Nam',
                        selected: _gender == 'Male',
                        onTap: () => setState(() => _gender = 'Male'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GenderCard(
                        label: 'Nữ',
                        selected: _gender == 'Female',
                        onTap: () => setState(() => _gender = 'Female'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Ngày sinh
                GestureDetector(
                  onTap: _pickDob,
                  child: AbsorbPointer(
                    child: TextField(
                      controller: TextEditingController(
                        text: _dob == null
                            ? ''
                            : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Ngày sinh',
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                        suffixIcon: Icon(Icons.event_rounded),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Mật khẩu
                TextField(
                  controller: _password,
                  obscureText: !_showPass,
                  decoration: InputDecoration(
                    labelText: 'Mật Khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showPass = !_showPass),
                      icon: Icon(
                        _showPass
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Xác nhận mật khẩu
                TextField(
                  controller: _confirm,
                  obscureText: !_showConfirm,
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showConfirm = !_showConfirm),
                      icon: Icon(
                        _showConfirm
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Nút đăng ký
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade200,
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Đăng ký'),
                  ),
                ),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Đã có tài khoản?'),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      ),
                      child: const Text('Đăng nhập ngay'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ chọn giới tính: dùng icon Material mặc định (nam/nữ)
class _GenderCard extends StatelessWidget {
  final String label; // 'Nam' | 'Nữ'
  final bool selected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bool isMale = label == 'Nam';
    final IconData icon = isMale ? Icons.male_rounded : Icons.female_rounded;
    final Color color = isMale ? Colors.blue : Colors.pink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(.06) : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(.15),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? cs.primary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
