import 'package:flutter/material.dart';

import '../../core/network/api_failure.dart';

class ErrorCard extends StatelessWidget {
  final ApiFailure failure;
  final VoidCallback onCopy;

  const ErrorCard({super.key, required this.failure, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            failure.title,
            style: TextStyle(
              color: cs.onErrorContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            failure.message,
            style: TextStyle(color: cs.onErrorContainer),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(onPressed: onCopy, child: const Text('Копировать')),
            ],
          ),
        ],
      ),
    );
  }
}
