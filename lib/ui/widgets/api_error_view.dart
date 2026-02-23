import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/helpers/copy.dart';
import '../../core/network/api_error_kind.dart';
import '../../core/network/api_failure.dart';
import '../../data/stores/app_settings_store.dart';

class ApiErrorView extends StatelessWidget {
  final ApiFailure failure;
  final VoidCallback onRetry;
  final bool vacationHint;

  final AppSettingsStore? settings;

  const ApiErrorView({
    super.key,
    required this.failure,
    required this.onRetry,
    this.vacationHint = false,
    this.settings,
  });

  static const String _corsDemoUrl = 'https://cors-anywhere.herokuapp.com/corsdemo';

  Future<void> _openCorsDemo(BuildContext context) async {
    final uri = Uri.parse(_corsDemoUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть сайт. Открой его вручную в новой вкладке.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String hint = '';
    if (failure.kind == ApiErrorKind.badUrl) {
      hint = 'Открой настройки и проверь адрес API.';
    } else if (failure.kind == ApiErrorKind.network) {
      hint = 'Проверь интернет или попробуй позже.';
    } else if (failure.kind == ApiErrorKind.unauthorized) {
      hint = 'Сессия недействительна. Перелогинься (в профиле/аккаунтах).';
    } else if (vacationHint) {
      hint = 'Также возможно, что это каникулы (дата вне четвертей).';
    }

    final showCorsHint = kIsWeb && (settings?.shouldShowWebCorsHint ?? false);

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
                  Text(failure.message, style: TextStyle(color: cs.onErrorContainer)),
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(hint, style: TextStyle(color: cs.onErrorContainer.withValues(alpha: 0.9))),
                  ],

                  if (showCorsHint) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Если ты открываешь приложение через браузер: попробуй зайти на сайт CORS Anywhere и дать доступ.',
                      style: TextStyle(color: cs.onErrorContainer.withValues(alpha: 0.95), fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.tonal(
                          onPressed: () => _openCorsDemo(context),
                          child: const Text('Открыть сайт'),
                        ),
                        SelectableText(
                          _corsDemoUrl,
                          style: TextStyle(color: cs.onErrorContainer.withValues(alpha: 0.9)),
                        ),
                      ],
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
