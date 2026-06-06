// lib/widgets/async_guard.dart
import 'package:flutter/material.dart';

/// Điều phối 1 hành động async tại 1 thời điểm, ngăn double-tap & spam.
class BusyController extends ChangeNotifier {
  bool _busy = false;
  bool get isBusy => _busy;

  Future<T?> run<T>(Future<T> Function() task) async {
    if (_busy) return null;        // chặn chồng thao tác
    _busy = true;
    notifyListeners();
    try {
      return await task();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

/// Nút có spinner tự động khi bận
class BusyButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;
  final Widget child;

  const BusyButton({
    super.key,
    required this.busy,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
        width: 18, height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : child,
    );
  }
}
