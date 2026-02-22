import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateChip extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final bool isVacation;
  final VoidCallback onTap;

  const DateChip({
    super.key,
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.isVacation,
    required this.onTap,
  });

  String _getMonthAbbr() => DateFormat.MMM('ru').format(date).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final wd = DateFormat('EE', 'ru').format(date);
    final day = date.day.toString();
    final month = _getMonthAbbr();

    final Color bg = isSelected
        ? cs.primaryContainer
        : isVacation
            ? cs.errorContainer.withValues(alpha: 0.55)
            : cs.surfaceContainerHighest;

    final Color fg = isSelected
        ? cs.onPrimaryContainer
        : isVacation
            ? cs.onErrorContainer
            : cs.onSurface;

    final border = BorderSide(
      color: isToday ? cs.primary : cs.outlineVariant,
      width: isToday ? 2 : 1,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 80,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.fromBorderSide(border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              wd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  month,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  day,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
