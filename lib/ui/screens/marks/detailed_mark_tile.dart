import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/mark.dart';
import '../../ui_logic/mark_ui.dart';
import '../../widgets/chips.dart';

class DetailedMarkTile extends StatelessWidget {
  final Mark mark;
  const DetailedMarkTile({super.key, required this.mark});

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
                    Text('Тип: ${MarkUi.typeTitle(mark)}', style: const TextStyle(fontWeight: FontWeight.w700)),
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
              if (mark.markType != null) AppChip(label: 'MarkType', value: mark.markType!),
              if (mark.absent == true) const _InlinePill(icon: Icons.report_rounded, text: 'Отсутствие'),
              if (mark.absentType != null && mark.absentType!.trim().isNotEmpty)
                AppChip(label: 'AbsentType', value: mark.absentType!),
              if (mark.lateMinutes != null && mark.lateMinutes! > 0) AppChip(label: 'Опоздание', value: '${mark.lateMinutes} мин'),
              if (mark.absentReason != null && mark.absentReason!.trim().isNotEmpty)
                AppChip(label: 'Причина', value: mark.absentReason!),
            ],
          ),
          if (mark.note != null && mark.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Комментарий: ${mark.note}', style: TextStyle(color: cs.onSurfaceVariant)),
          ],
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }
}
