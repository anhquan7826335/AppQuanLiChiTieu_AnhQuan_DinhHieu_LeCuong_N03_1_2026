import 'dart:async';
import 'package:flutter/foundation.dart';

/// Gộp nhiều notifyListeners() trong 1 frame (microtask),
/// tránh bắn notify liên tục gây đứng màn / spam.
mixin CoalesceNotifyMixin on ChangeNotifier {
  bool _scheduled = false;

  @override
  void notifyListeners() {
    if (_scheduled) return; // đã lên lịch -> bỏ qua lần gọi thêm
    _scheduled = true;
    Future.microtask(() {
      _scheduled = false;
      super.notifyListeners();
    });
  }

  /// Nếu cần phát ngay lập tức (hiếm gặp), gọi flushNow()
  @protected
  @visibleForTesting
  void flushNow() {
    if (_scheduled) {
      _scheduled = false;
      super.notifyListeners();
    }
  }
}
