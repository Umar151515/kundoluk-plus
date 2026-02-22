import 'package:flutter/material.dart';

import '../../../domain/models/mark_entry.dart';
import '../../ui_logic/mark_ui.dart';

class MarkChip extends StatelessWidget {
  final MarkEntry entry;
  const MarkChip({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final label = entry.label;
    final colors = MarkUi.colors(context, entry.mark);

    return Tooltip(
      message: MarkUi.tooltip(entry),
      triggerMode: TooltipTriggerMode.longPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(color: colors.fg, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
