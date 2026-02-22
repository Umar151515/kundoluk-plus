import 'package:flutter/material.dart';

import '../../../domain/models/quarter_mark.dart';
import 'quarter_ui.dart';

class QuarterChip extends StatelessWidget {
  final QuarterMark mark;
  final String subjectName;
  const QuarterChip({super.key, required this.mark, required this.subjectName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = mark.quarter ?? 0;

    final qLabel = (q == 5)
        ? 'Год'
        : (q >= 1 && q <= 4)
            ? '$q четв.'
            : '—';

    final value = mark.quarterMark?.toString() ?? '—';
    final tip = QuarterUi.tooltip(subjectName, mark);

    return Tooltip(
      message: tip,
      triggerMode: TooltipTriggerMode.longPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              qLabel,
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                if (mark.isBonus == true) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.star_rounded, size: 18, color: cs.tertiary),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
