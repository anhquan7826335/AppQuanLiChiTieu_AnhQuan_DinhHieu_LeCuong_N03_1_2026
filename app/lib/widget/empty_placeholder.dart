import 'package:flutter/material.dart';


class EmptyPlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;
  const EmptyPlaceholder({super.key, required this.title, this.subtitle = ''});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ]
        ],
      ),
    );
  }
}