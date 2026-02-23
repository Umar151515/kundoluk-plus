import 'package:flutter/material.dart';

import '../../../domain/models/lesson.dart';
import '../../../domain/models/mark.dart';
import '../../ui_logic/mark_ui.dart';

class CompactLessonCard extends StatelessWidget {
  final Lesson lesson;
  final bool isCurrent;

  const CompactLessonCard({
    super.key,
    required this.lesson,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final subject = lesson.subject?.nameRu ?? lesson.subject?.name ?? 'Предмет';
    final teacher = lesson.teacher?.fio ?? 'Учитель';
    final room = lesson.room?.roomName;
    final time = (lesson.startTime != null && lesson.endTime != null)
        ? '${lesson.startTime}–${lesson.endTime}'
        : 'Время не указано';

    final topic = lesson.topic?.name?.trim();
    final topicLine = (topic != null && topic.isNotEmpty) ? topic : null;

    final Color cardColor = isCurrent ? cs.primaryContainer.withValues(alpha: 0.7) : cs.surfaceContainerHighest;
    final Color leftBorderColor = isCurrent ? cs.primary : Colors.transparent;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      elevation: isCurrent ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
      color: cardColor,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border(left: BorderSide(color: leftBorderColor, width: 6)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _LessonNumberPill(num: lesson.lessonNumber),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(30)),
                    child: Text(
                      'Сейчас',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _InfoPill(icon: Icons.person_rounded, text: teacher),
                if (room != null && room.trim().isNotEmpty) _InfoPill(icon: Icons.room_rounded, text: room),
              ],
            ),
            if (lesson.marks.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(height: 1, thickness: 1, color: cs.outlineVariant),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: lesson.marks.map((m) => _MarkChipCompact(mark: m)).toList(),
              ),
            ],
            if (topicLine != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.menu_book_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      topicLine,
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (lesson.task != null && (lesson.task!.name ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.home_rounded, size: 18, color: cs.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lesson.task!.name!,
                      style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (lesson.lastTask != null && (lesson.lastTask!.name ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.history_rounded, size: 18, color: cs.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lesson.lastTask!.name!,
                      style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LessonNumberPill extends StatelessWidget {
  final int? num;
  const _LessonNumberPill({required this.num});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Text(
        '${num ?? '?'}',
        style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoPill({required this.icon, required this.text});

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis, maxLines: 1)),
        ],
      ),
    );
  }
}

class _MarkChipCompact extends StatelessWidget {
  final Mark mark;
  const _MarkChipCompact({required this.mark});

  @override
  Widget build(BuildContext context) {
    final label = MarkUi.label(mark);
    final colors = MarkUi.colors(context, mark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(
          color: colors.fg,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
    );
  }
}
