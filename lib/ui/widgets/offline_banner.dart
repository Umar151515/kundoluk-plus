import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  const OfflineBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.errorContainer),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: cs.onErrorContainer.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.onErrorContainer,
              side: BorderSide(color: cs.onErrorContainer.withValues(alpha: 0.6)),
            ),
            child: const Text('Обновить'),
          ),
        ],
      ),
    );
  }
}
