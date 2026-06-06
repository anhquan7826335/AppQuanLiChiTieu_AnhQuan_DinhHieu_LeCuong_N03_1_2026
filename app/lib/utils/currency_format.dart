import 'package:intl/intl.dart';


class CurF {
  static final _fmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  static String money(double v) => _fmt.format(v);
}