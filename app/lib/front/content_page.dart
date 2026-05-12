import 'package:flutter/material.dart';
import 'package:app/widget/bottom_navigation.dart';

class ContentPage extends StatelessWidget {
  const ContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          //Header
          _NavBar(),
          // Body
          Expanded(
            child: Center(
              child: Text(
                'Chi tiết các khoản thu chi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Footer
          _Footer(),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: 1,
        onTap: (index) {
          Navigator.pushReplacementNamed(context, ['/home','/content','/contact'][index]);
        },
      ),//AppBottomNavigation
    );
  }
}

// ── Nav Bar ───────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // Logo
              Image.asset(  
                'assets/group_avatar.png',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const FlutterLogo(size: 60),
              ),  

              // Nav links
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _NavLink(label: 'Trang chủ', active: true),
                      _NavLink(label: 'Tính năng', active: false),
                      _NavLink(label: 'Giải pháp', active: false),
                      _NavLink(label: 'Nhóm', active: false),
                      _NavLink(label: 'Liên hệ', active: false),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Buttons
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A1A1A),
                  side: const BorderSide(color: Color(0xFFDDDDDD)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Sign in',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Register',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final bool active;
  const _NavLink({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          backgroundColor:
              active ? const Color(0xFFEEEEEE) : Colors.transparent,
          foregroundColor: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Chart Painter ─────────────────────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      final y = size.height - (i * (size.height / 4));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final incomePaint = Paint()
      ..color = Colors.green.shade500
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final expensePaint = Paint()
      ..color = Colors.red.shade500
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final incomePath = Path();
    final expensePath = Path();

    final incomePoints = [0.2, 0.5, 0.4, 0.7, 0.6, 0.9];
    final expensePoints = [0.1, 0.3, 0.6, 0.4, 0.3, 0.5];

    final dx = size.width / (incomePoints.length - 1);

    for (int i = 0; i < incomePoints.length; i++) {
      final x = i * dx;
      final yIncome = size.height - (incomePoints[i] * size.height);
      final yExpense = size.height - (expensePoints[i] * size.height);

      if (i == 0) {
        incomePath.moveTo(x, yIncome);
        expensePath.moveTo(x, yExpense);
      } else {
        incomePath.lineTo(x, yIncome);
        expensePath.lineTo(x, yExpense);
      }
      
      canvas.drawCircle(Offset(x, yIncome), 4, Paint()..color = Colors.green.shade500);
      canvas.drawCircle(Offset(x, yExpense), 4, Paint()..color = Colors.red.shade500);
    }

    canvas.drawPath(incomePath, incomePaint);
    canvas.drawPath(expensePath, expensePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: logo + socials
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(  
                    'assets/group_avatar.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const FlutterLogo(size: 40),
                  ),
                  Row(
                    children: [
                      _SocialBtn(Icons.close),
                      _SocialBtn(Icons.camera_alt_outlined),
                      _SocialBtn(Icons.play_circle_outline),
                      _SocialBtn(Icons.work_outline),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // Footer columns
              _FooterColumn(
                title: 'Use cases',
                items: ['UI design', 'UX design', 'Wireframing'],
              ),
              const SizedBox(width: 28),
              _FooterColumn(
                title: 'Explore',
                items: ['Design', 'Prototyping', 'Development features'],
              ),
              const SizedBox(width: 28),
              _FooterColumn(
                title: 'Resources',
                items: ['Blog', 'Best practices', 'Colors'],
              ),
            ],
          ),

          const SizedBox(height: 28),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 16),

          Row(
            children: [
              Text(
                '© 2026 Finance Tracker',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '23010580 · 23010827 · 23010224',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> items;
  const _FooterColumn({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1A1A1A))),
        const SizedBox(height: 14),
        ...items.map(
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(i,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
        ),
      ],
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final IconData icon;
  const _SocialBtn(this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Icon(icon, size: 22, color: const Color(0xFF1A1A1A)),
    );
  }
}
