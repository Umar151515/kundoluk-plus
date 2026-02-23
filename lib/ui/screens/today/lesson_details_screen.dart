import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/helpers/copy.dart';
import '../../../core/helpers/layout.dart';
import '../../../domain/models/lesson.dart';
import '../../../domain/models/mark.dart';
import '../../ui_logic/mark_ui.dart';
import '../../widgets/app_scaffold_max_width.dart';
import '../../widgets/chips.dart';
import '../../widgets/info_table.dart';
import '../../widgets/rich_block.dart';
import 'teacher_details_screen.dart';

class LessonDetailsScreen extends StatelessWidget {
  final Lesson lesson;
  const LessonDetailsScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final subject = lesson.subject?.nameRu ?? lesson.subject?.name ?? 'Предмет';
    final time = (lesson.startTime != null && lesson.endTime != null) ? '${lesson.startTime}–${lesson.endTime}' : null;
    final date = lesson.lessonDay != null ? DateFormat('d MMMM yyyy, EEE').format(lesson.lessonDay!.toLocal()) : null;

    final page = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (time != null) AppChip(label: 'Время', value: time),
                    if (date != null) AppChip(label: 'Дата', value: date),
                    AppChip(label: 'Номер', value: 'Урок №${lesson.lessonNumber ?? '?'}'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (lesson.teacher != null)
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Учитель'),
              subtitle: Text(lesson.teacher!.fio),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TeacherDetailsScreen(teacher: lesson.teacher!)),
              ),
            ),
          ),
        if (lesson.room != null) ...[
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Место', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  InfoTable(
                    items: [
                      InfoRow('Кабинет', lesson.room?.roomName),
                      InfoRow('Этаж', lesson.room?.floor?.toString()),
                      InfoRow('Блок', lesson.room?.block),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        if ((lesson.topic?.name ?? '').trim().isNotEmpty ||
            (lesson.task?.name ?? '').trim().isNotEmpty ||
            (lesson.lastTask?.name ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Материалы', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if ((lesson.topic?.name ?? '').trim().isNotEmpty) RichBlock(title: 'Тема', text: lesson.topic!.name!),
                  if ((lesson.task?.name ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    RichBlock(title: 'Домашнее задание', text: lesson.task!.name!),
                  ],
                  if ((lesson.lastTask?.name ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    RichBlock(title: 'Предыдущее задание', text: lesson.lastTask!.name!),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Оценки и посещаемость', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (lesson.marks.isEmpty)
                  Text('Нет оценок/отметок', style: TextStyle(color: cs.onSurfaceVariant))
                else
                  Column(
                    children: lesson.marks
                        .map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DetailedMarkTile(mark: m),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Урок'),
        actions: [
          IconButton(
            tooltip: 'Копировать всё',
            onPressed: () => Copy.text(context, _lessonToCopyText(lesson), label: 'Урок'),
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: isWide(context) ? AppScaffoldMaxWidth(maxWidth: 980, child: page) : page,
    );
  }

  String _lessonToCopyText(Lesson l) {
    final subject = l.subject?.nameRu ?? l.subject?.name ?? '';
    final teacher = l.teacher?.fio ?? '';
    final room = l.room?.roomName ?? '';
    final time = (l.startTime != null && l.endTime != null) ? '${l.startTime}–${l.endTime}' : '';
    final date = l.lessonDay != null ? DateFormat('d MMMM yyyy').format(l.lessonDay!.toLocal()) : '';
    final marks = l.marks.isNotEmpty ? l.marks.map(MarkUi.label).join(', ') : '';

    return [
      'Предмет: $subject',
      if (date.isNotEmpty) 'Дата: $date',
      if (time.isNotEmpty) 'Время: $time',
      if (teacher.isNotEmpty) 'Учитель: $teacher',
      if (room.isNotEmpty) 'Кабинет: $room',
      if ((l.topic?.name ?? '').trim().isNotEmpty) 'Тема: ${l.topic!.name}',
      if ((l.task?.name ?? '').trim().isNotEmpty) 'ДЗ: ${l.task!.name}',
      if (marks.isNotEmpty) 'Оценки/отметки: $marks',
      if (l.uid != null) 'UID: ${l.uid}',
      if (l.scheduleItemId != null) 'ScheduleItemId: ${l.scheduleItemId}',
    ].join('\n');
  }
}

class _DetailedMarkTile extends StatelessWidget {
  final Mark mark;
  const _DetailedMarkTile({required this.mark});

  String _valueTitle(Mark m) {
    if (m.value != null && m.value != 0) return 'Оценка';
    if (m.customMark != null && m.customMark!.trim().isNotEmpty) return 'Отметка';
    if (m.absent == true) return 'Отсутствие';
    if ((m.lateMinutes ?? 0) > 0) return 'Опоздание';
    return 'Запись';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final label = MarkUi.label(mark);
    final colors = MarkUi.colors(context, mark);
    final bg = colors.bg.withValues(alpha: 0.18);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(8)),
                child: Text(label, style: TextStyle(color: colors.fg, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_valueTitle(mark)} • ${MarkUi.typeTitle(mark)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if ((mark.createdAt ?? mark.updatedAt) != null)
                      Text(
                        'Дата: ${DateFormat('d MMM yyyy, HH:mm').format((mark.createdAt ?? mark.updatedAt)!.toLocal())}',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (mark.absent == true) const _InlinePill(icon: Icons.report_rounded, text: 'Отсутствие'),
              if (mark.absentType != null && mark.absentType!.trim().isNotEmpty)
                AppChip(label: 'Тип отсутствия', value: mark.absentType!),
              if (mark.lateMinutes != null && mark.lateMinutes! > 0) AppChip(label: 'Опоздание', value: '${mark.lateMinutes} мин'),
              if (mark.absentReason != null && mark.absentReason!.trim().isNotEmpty) AppChip(label: 'Причина', value: mark.absentReason!),
              if (mark.note != null && mark.note!.trim().isNotEmpty) AppChip(label: 'Комментарий', value: mark.note!),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlinePill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InlinePill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(text),
      ]),
    );
  }
}
