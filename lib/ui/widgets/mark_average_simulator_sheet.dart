import 'package:flutter/material.dart';

Future<void> showMarkAverageSimulatorSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<int> initialMarks = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.78,
      child: MarkAverageSimulatorSheet(
        title: title,
        subtitle: subtitle,
        initialMarks: initialMarks,
      ),
    ),
  );
}

class MarkAverageSimulatorSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<int> initialMarks;

  const MarkAverageSimulatorSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.initialMarks = const [],
  });

  @override
  State<MarkAverageSimulatorSheet> createState() =>
      _MarkAverageSimulatorSheetState();
}

class _MarkAverageSimulatorSheetState extends State<MarkAverageSimulatorSheet> {
  late final List<int> _initialMarks = [...widget.initialMarks];
  late final List<int> _marks = [...widget.initialMarks];

  double? get _avg {
    if (_marks.isEmpty) return null;
    final sum = _marks.fold<int>(0, (total, value) => total + value);
    return sum / _marks.length;
  }

  void _addMark(int value) {
    setState(() => _marks.add(value));
  }

  void _removeAt(int index) {
    setState(() => _marks.removeAt(index));
  }

  void _restoreInitialMarks() {
    setState(() {
      _marks
        ..clear()
        ..addAll(_initialMarks);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Средняя',
                  value: _avg?.toStringAsFixed(2) ?? '—',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Оценок',
                  value: '${_marks.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Добавить оценку',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: _restoreInitialMarks,
                label: const Text('Вернуть исходные'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              5,
              (index) => _AddMarkButton(
                value: index + 1,
                onTap: () => _addMark(index + 1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Текущие оценки',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: _marks.isEmpty
                  ? Center(
                      child: Text(
                        'Добавь оценки, и симулятор сразу покажет среднюю.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(
                          _marks.length,
                          (index) => InputChip(
                            label: Text(
                              '${_marks[index]}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            onDeleted: () => _removeAt(index),
                            deleteIcon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMarkButton extends StatelessWidget {
  final int value;
  final VoidCallback onTap;

  const _AddMarkButton({
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
