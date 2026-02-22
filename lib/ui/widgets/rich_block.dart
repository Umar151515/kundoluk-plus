import 'package:flutter/material.dart';

class RichBlock extends StatelessWidget {
  final String title;
  final String text;
  const RichBlock({super.key, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(text),
        ],
      ),
    );
  }
}
