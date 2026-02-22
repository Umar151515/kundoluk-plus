import 'package:flutter/material.dart';

class InfoRow {
  final String label;
  final String? value;
  InfoRow(this.label, this.value);
}

class InfoTable extends StatelessWidget {
  final List<InfoRow> items;
  const InfoTable({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = items
        .where((e) => e.value != null && e.value!.trim().isNotEmpty && e.value != 'null')
        .toList();

    if (filtered.isEmpty) {
      return Text('Нет данных', style: TextStyle(color: cs.onSurfaceVariant));
    }

    return Column(
      children: filtered.map((e) {
        final value = e.value!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 150,
                child: Text(
                  e.label,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: SelectableText(value)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
