import 'package:flutter/material.dart';

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          //Heaader
          Padding(
              padding: const EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: 8,
              ),
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.width * 0.1,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 0.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/group_avatar.png',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const FlutterLogo(size: 10),
                ),
              ),
            ),
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
          Container(
            width: double.infinity,
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: const [
                Text('Phenikaa University', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Nhóm: Anh Quân, Đình Hiếu, Lê Cường'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: 1,
        onTap: (index) {
          Navigator.pushReplacementNamed(context, ['/home','/content','/contact'][index]);
        },
      ),
    );
  }
}
