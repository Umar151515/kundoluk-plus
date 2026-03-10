import 'package:flutter/material.dart';

class LateInfoBadge extends StatelessWidget {
  final int minutes;
  final String? type;
  final String? reason;

  const LateInfoBadge({
    super.key,
    required this.minutes,
    this.type,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typeText = type?.trim();
    final reasonText = reason?.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alarm_rounded, size: 16, color: cs.onTertiaryContainer),
              const SizedBox(width: 6),
              Text(
                'Опоздание: $minutes мин',
                style: TextStyle(
                  color: cs.onTertiaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (typeText != null && typeText.isNotEmpty)
            Text(
              'Тип: $typeText',
              style: TextStyle(color: cs.onTertiaryContainer, fontSize: 12),
            ),
          if (reasonText != null && reasonText.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'Причина: $reasonText',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onTertiaryContainer, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
