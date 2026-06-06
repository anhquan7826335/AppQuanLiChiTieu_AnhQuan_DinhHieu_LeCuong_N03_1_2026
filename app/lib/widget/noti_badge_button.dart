import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';

class NotiBadgeButton extends ConsumerWidget {
  final NotiChannel channel;
  final VoidCallback? onPressed; // nếu muốn mở danh sách thông báo thật
  const NotiBadgeButton({super.key, required this.channel, this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(notiProvider);
    final count = (channel == NotiChannel.analysis) ? s.analysis : s.calendar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Thông báo',
          icon: const Icon(Icons.chat_bubble_rounded),
          onPressed: () {
            // giảm từng cái 1 cho đúng yêu cầu
            if (count > 0) {
              ref.read(notiProvider.notifier).decrement(channel);
            }
            // nếu bạn muốn mở danh sách thông báo, gọi onPressed()
            onPressed?.call();
          },
        ),
        if (count > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}
