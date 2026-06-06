import 'package:flutter/material.dart';

/// Dropdown chọn danh mục với Material 3, chữ rõ ràng trên mọi nền.
class CategoryDropdown extends StatelessWidget {
  /// Giá trị đang chọn; null = Tất cả
  final String? value;
  final ValueChanged<String?> onChanged;
  final double width;

  const CategoryDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final items = <_CatItem>[
      const _CatItem(null, 'Tất cả', Icons.all_inclusive_rounded),
      const _CatItem('Ăn uống', 'Ăn uống', Icons.restaurant_rounded),
      const _CatItem('Di chuyển', 'Di chuyển', Icons.directions_car_rounded),
      const _CatItem('Điện', 'Điện', Icons.bolt_rounded),
      const _CatItem('Nước', 'Nước', Icons.water_drop_rounded),
      const _CatItem('Điện thoại', 'Điện thoại', Icons.phone_iphone_rounded),
      const _CatItem('Bảo dưỡng xe', 'Bảo dưỡng xe', Icons.build_rounded),
      const _CatItem('Khác', 'Khác', Icons.category_rounded),
    ];

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String?>(
        value: value,
        onChanged: onChanged,
        isExpanded: true,
        isDense: true,
        menuMaxHeight: 320,
        borderRadius: BorderRadius.circular(14),
        dropdownColor: cs.surface, // nền menu dịu, dễ đọc
        icon: const Icon(Icons.keyboard_arrow_down_rounded),

        // ✅ ép màu chữ rõ ràng cho giá trị đang hiển thị
        style: TextStyle(
          fontSize: 14,
          color: cs.onSurface,
        ),

        decoration: InputDecoration(
          labelText: 'Danh mục',
          labelStyle: TextStyle(color: cs.onSurface),
          prefixIcon: const Icon(Icons.category_rounded),
          filled: true,
          fillColor: cs.surfaceVariant.withOpacity(.45),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.primary, width: 1.2),
          ),
        ),

        items: [
          for (final it in items)
            DropdownMenuItem<String?>(
              value: it.value,
              child: Row(
                children: [
                  Icon(it.icon, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  // ✅ chữ trong menu cũng dùng onSurface để không bị trắng
                  Flexible(
                    child: Text(
                      it.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurface, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CatItem {
  final String? value;
  final String label;
  final IconData icon;
  const _CatItem(this.value, this.label, this.icon);
}
