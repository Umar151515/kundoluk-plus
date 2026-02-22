import 'package:flutter/material.dart';

class EmptyView extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  const EmptyView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_rounded, size: 44, color: cs.onSurfaceVariant),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  SelectableText(
                    subtitle,
                    style: TextStyle(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(onPressed: onRetry, child: const Text('Обновить')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
