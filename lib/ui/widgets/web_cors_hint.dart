import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/stores/app_settings_store.dart';

class WebCorsHint extends StatelessWidget {
  final AppSettingsStore settings;
  final bool compact;

  const WebCorsHint({
    super.key,
    required this.settings,
    this.compact = false,
  });

  static const String corsDemoUrl = 'https://cors-anywhere.herokuapp.com/corsdemo';

  Future<void> _openCorsDemo(BuildContext context) async {
    final uri = Uri.parse(corsDemoUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть сайт. Открой его вручную в новой вкладке.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    if (!settings.shouldShowWebCorsHint) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    final title = 'Для работы на сайте нужно один раз разрешить CORS';
    final subtitle =
        'Открой страницу CORS Anywhere и нажми кнопку “Request temporary access”. '
        'После этого вернись сюда и обнови данные.';

    return Container(
      margin: EdgeInsets.fromLTRB(12, compact ? 8 : 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.tertiaryContainer),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.public_rounded, color: cs.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: cs.onTertiaryContainer.withValues(alpha: 0.9))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonal(
                      onPressed: () => _openCorsDemo(context),
                      child: const Text('Открыть сайт CORS Anywhere'),
                    ),
                    SelectableText(
                      corsDemoUrl,
                      style: TextStyle(
                        color: cs.onTertiaryContainer.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
