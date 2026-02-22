import 'package:flutter/material.dart';

import '../../core/helpers/copy.dart';
import '../../core/network/api_error_kind.dart';
import '../../core/network/api_failure.dart';

class ApiErrorView extends StatelessWidget {
  final ApiFailure failure;
  final VoidCallback onRetry;
  final bool vacationHint;

  const ApiErrorView({
    super.key,
    required this.failure,
    required this.onRetry,
    this.vacationHint = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String hint = '';
    if (failure.kind == ApiErrorKind.badUrl) {
      hint = 'Открой настройки и проверь Base URL.';
    } else if (failure.kind == ApiErrorKind.network) {
      hint = 'Проверь интернет или попробуй позже.';
    } else if (failure.kind == ApiErrorKind.unauthorized) {
      hint = 'Сессия недействительна. Перелогинься (в профиле/аккаунтах).';
    } else if (vacationHint) {
      hint = 'Также возможно, что это каникулы (дата вне четвертей).';
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 0,
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    failure.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: cs.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    failure.message,
                    style: TextStyle(color: cs.onErrorContainer),
                  ),
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      hint,
                      style: TextStyle(color: cs.onErrorContainer.withValues(alpha: 0.9)),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton(onPressed: onRetry, child: const Text('Повторить')),
                      OutlinedButton(
                        onPressed: () => Copy.text(context, failure.toString(), label: 'Ошибка'),
                        child: const Text('Копировать'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
