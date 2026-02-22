import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/mark.dart';
import '../../domain/models/mark_entry.dart';

class MarkUiColors {
  final Color bg;
  final Color fg;
  MarkUiColors(this.bg, this.fg);
}

class MarkUi {
  static String label(Mark m) {
    if (m.value != null && m.value != 0) return m.value.toString();
    if (m.customMark != null && m.customMark!.trim().isNotEmpty) return m.customMark!;
    if (m.absent == true) return 'Н';
    if ((m.lateMinutes ?? 0) > 0) return 'ОП';
    return '—';
  }

  static String typeTitle(Mark m) {
    final t = (m.markType ?? '').trim();
    if (t.isEmpty) {
      if (m.absent == true) return 'Отсутствие';
      if ((m.lateMinutes ?? 0) > 0) return 'Опоздание';
      return 'Запись';
    }
    return switch (t) {
      'general' => 'Оценка',
      'control' => 'Контрольная',
      'homework' => 'Домашняя работа',
      'test' => 'Тест',
      'laboratory' => 'Лабораторная',
      'write' => 'Письменная',
      'practice' => 'Практическая',
      _ => 'Тип: $t',
    };
  }

  static MarkUiColors colors(BuildContext context, Mark m) {
    final cs = Theme.of(context).colorScheme;
    final l = label(m).toLowerCase();

    final isBad = (l == '2' || l == '1');
    final isAbsent = (l == 'н' || m.absent == true);
    final isLate = (l == 'оп' || (m.lateMinutes ?? 0) > 0);

    if (isAbsent) return MarkUiColors(cs.errorContainer, cs.onErrorContainer);
    if (isLate) return MarkUiColors(cs.tertiaryContainer, cs.onTertiaryContainer);
    if (isBad) return MarkUiColors(cs.errorContainer, cs.onErrorContainer);
    if (m.isNumericMark) return MarkUiColors(cs.secondaryContainer, cs.onSecondaryContainer);

    return MarkUiColors(cs.surfaceContainerHighest, cs.onSurface);
  }

  static String tooltip(MarkEntry e) {
    final parts = <String>[];
    parts.add('Предмет: ${e.subjectName}');
    if (e.teacherName != null && e.teacherName!.trim().isNotEmpty) {
      parts.add('Учитель: ${e.teacherName}');
    }
    parts.add('Тип: ${typeTitle(e.mark)}');
    parts.add('Значение: ${label(e.mark)}');
    parts.add('Дата урока: ${DateFormat('d MMM yyyy').format(e.lessonDate)}');
    if (e.lessonTime != null) parts.add('Время урока: ${e.lessonTime}');
    final t = e.markCreated?.toLocal();
    if (t != null) parts.add('Выставлено: ${DateFormat('d MMM yyyy, HH:mm').format(t)}');
    if (e.mark.absent == true) {
      parts.add('Отсутствие: да');
      if (e.mark.absentType != null && e.mark.absentType!.trim().isNotEmpty) {
        parts.add('AbsentType: ${e.mark.absentType}');
      }
      if ((e.mark.lateMinutes ?? 0) > 0) parts.add('Опоздание: ${e.mark.lateMinutes} мин');
      if (e.mark.absentReason != null && e.mark.absentReason!.trim().isNotEmpty) {
        parts.add('Причина: ${e.mark.absentReason}');
      }
    }
    if (e.mark.note != null && e.mark.note!.trim().isNotEmpty) {
      parts.add('Комментарий: ${e.mark.note}');
    }
    return parts.join('\n');
  }
}
