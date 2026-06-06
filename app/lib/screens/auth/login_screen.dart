import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'register_screen.dart';

const double _kAuthMaxWidth = 480; // giới hạn bề rộng form trên desktop/tablet

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  static const route = '/login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPass = false;
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      await auth.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/'); // về AuthGate
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Đăng nhập thất bại: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
                // Header
                Text(
                  'Chào mừng trở lại!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chào mừng trở lại bạn đã bị bỏ lỡ!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 18),

                // Email
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 12),

                // Password
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

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                          Text('Chức năng Quên mật khẩu đang cập nhật'),
                        ),
                      );
                    },
                    child: const Text('Quên Mật Khẩu?'),
                  ),
                ),

                // Button
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade200,
                    ),
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Đăng Nhập'),
                  ),
                ),

                const SizedBox(height: 16),

                // Divider “Hoặc tiếp tục với”
                Row(
                  children: [
                    Expanded(child: Divider(color: cs.outlineVariant)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Hoặc tiếp tục với'),
                    ),
                    Expanded(child: Divider(color: cs.outlineVariant)),
                  ],
                ),
                const SizedBox(height: 12),

                // Social buttons (UI)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đăng nhập Google (UI demo)'),
                            ),
                          );
                        },
                        icon: Image.asset(
                          'assets/icons/google.png',
                          height: 18,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.g_mobiledata_rounded),
                        ),
                        label: const Text('Google'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đăng nhập Facebook (UI demo)'),
                            ),
                          );
                        },
                        icon: Image.asset(
                          'assets/icons/facebook.png',
                          height: 18,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.facebook_rounded),
                        ),
                        label: const Text('Facebook'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff1877f2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Không có tài khoản?'),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: const Text('Đăng ký ngay'),
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
