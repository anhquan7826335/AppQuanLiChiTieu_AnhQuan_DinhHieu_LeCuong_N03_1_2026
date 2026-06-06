import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hai kênh thông báo chúng ta dùng để gắn badge
enum NotiChannel { analysis, calendar }

/// Trạng thái thông báo (immutable)
class NotiState {
  final int analysis; // badge cho màn Phân tích
  final int calendar; // badge cho màn Lịch

  const NotiState({this.analysis = 0, this.calendar = 0});

  int get total => analysis + calendar;

  NotiState copyWith({int? analysis, int? calendar}) => NotiState(
    analysis: analysis ?? this.analysis,
    calendar: calendar ?? this.calendar,
  );

  @override
  String toString() => 'NotiState(analysis: $analysis, calendar: $calendar)';
}

/// StateNotifier quản lý badge
class NotiNotifier extends StateNotifier<NotiState> {
  NotiNotifier() : super(const NotiState());

  /// Tăng cả hai kênh (gọi khi THÊM chi tiêu mới)
  void incrementAll({int by = 1}) {
    if (by <= 0) return;
    state = state.copyWith(
      analysis: state.analysis + by,
      calendar: state.calendar + by,
    );
  }

  /// Tăng 1 kênh
  void increment(NotiChannel c, {int by = 1}) {
    if (by <= 0) return;
    switch (c) {
      case NotiChannel.analysis:
        state = state.copyWith(analysis: state.analysis + by);
        break;
      case NotiChannel.calendar:
        state = state.copyWith(calendar: state.calendar + by);
        break;
    }
  }

  /// Giảm 1 kênh (không cho âm)
  void decrement(NotiChannel c, {int by = 1}) {
    if (by <= 0) return;
    switch (c) {
      case NotiChannel.analysis:
        state = state.copyWith(
          analysis: (state.analysis - by).clamp(0, 1 << 31),
        );
        break;
      case NotiChannel.calendar:
        state = state.copyWith(
          calendar: (state.calendar - by).clamp(0, 1 << 31),
        );
        break;
    }
  }

  /// Xoá badge 1 kênh (gọi khi user nhấn vào icon/badge kênh đó)
  void clear(NotiChannel c) {
    switch (c) {
      case NotiChannel.analysis:
        state = state.copyWith(analysis: 0);
        break;
      case NotiChannel.calendar:
        state = state.copyWith(calendar: 0);
        break;
    }
  }

  /// Xoá mọi badge
  void clearAll() => state = const NotiState();
}

/// Provider toàn cục
final notiProvider =
StateNotifierProvider<NotiNotifier, NotiState>((ref) => NotiNotifier());
