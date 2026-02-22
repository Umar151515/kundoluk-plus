import 'package:intl/intl.dart';

import '../../../domain/models/quarter_mark.dart';

class QuarterUi {
  static String tooltip(String subjectName, QuarterMark m) {
    final parts = <String>[];
    parts.add('Предмет: $subjectName');

    final q = m.quarter;
    final qLabel = (q == 5)
        ? 'Год'
        : (q != null && q >= 1 && q <= 4)
            ? '$q четверть'
            : '—';
    parts.add('Период: $qLabel');

    final value = m.customMark?.trim().isNotEmpty == true ? m.customMark! : (m.quarterMark?.toString() ?? '—');
    parts.add('Итог: $value');

    if (m.quarterAvg != null) parts.add('Средний: ${m.quarterAvg!.toStringAsFixed(2)}');
    if (m.isBonus == true) parts.add('Бонус: да');

    if (m.quarterDate != null) {
      parts.add('Дата выставления: ${DateFormat('d MMM yyyy, HH:mm').format(m.quarterDate!.toLocal())}');
    }

    return parts.join('\n');
  }
}
