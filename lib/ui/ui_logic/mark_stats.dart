import '../../domain/models/mark_entry.dart';

class MarkStats {
  final int total;
  final int numericCount;
  final int notesCount;
  final double? avg;

  MarkStats({
    required this.total,
    required this.numericCount,
    required this.notesCount,
    required this.avg,
  });

  static MarkStats ofEntries(List<MarkEntry> entries) {
    final total = entries.length;
    int numeric = 0;
    int notes = 0;
    int sum = 0;

    for (final e in entries) {
      final m = e.mark;
      if (m.isNumericMark) {
        numeric++;
        sum += m.value!;
      } else {
        notes++;
      }
    }

    final avg = numeric == 0 ? null : (sum / numeric);
    return MarkStats(total: total, numericCount: numeric, notesCount: notes, avg: avg);
  }
}
