import 'package:flutter/material.dart';

import '../../../core/helpers/copy.dart';
import '../../../core/helpers/layout.dart';
import '../../../domain/models/lesson_teacher.dart';
import '../../widgets/app_scaffold_max_width.dart';
import '../../widgets/info_table.dart';

class TeacherDetailsScreen extends StatelessWidget {
  final LessonTeacher teacher;
  const TeacherDetailsScreen({super.key, required this.teacher});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final page = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          child: ListTile(
            leading: const Icon(Icons.person_rounded),
            title: Text(teacher.fio.isNotEmpty ? teacher.fio : 'Учитель'),
            subtitle: Text([
              if (teacher.pinAsString != null) 'ПИН: ${teacher.pinAsString}',
              if (teacher.pin != null) '(${teacher.pin})',
            ].join(' ')),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: cs.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Детали', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                InfoTable(
                  items: [
                    InfoRow('Фамилия', teacher.lastName),
                    InfoRow('Имя', teacher.firstName),
                    InfoRow('Отчество', teacher.midName),
                    InfoRow('ПИН', teacher.pin?.toString()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Учитель'),
        actions: [
          IconButton(
            tooltip: 'Копировать всё',
            onPressed: () {
              final text = [
                'ФИО: ${teacher.fio}',
                if (teacher.pinAsString != null) 'ПИН: ${teacher.pinAsString}',
                if (teacher.pin != null) 'PIN (число): ${teacher.pin}',
              ].join('\n');
              Copy.text(context, text, label: 'Учитель');
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: isWide(context) ? AppScaffoldMaxWidth(maxWidth: 980, child: page) : page,
    );
  }
}
