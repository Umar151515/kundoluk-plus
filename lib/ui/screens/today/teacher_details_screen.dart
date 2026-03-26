import 'package:flutter/material.dart';

import '../../../core/extensions/datetime_x.dart';
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
    final birthInfo = _birthInfoFromPin();

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
                const Text(
                  'Детали',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                InfoTable(
                  items: [
                    InfoRow('Фамилия', teacher.lastName),
                    InfoRow('Имя', teacher.firstName),
                    InfoRow('Отчество', teacher.midName),
                    InfoRow('ПИН', teacher.pinAsString ?? teacher.pin?.toString()),
                    InfoRow('Дата рождения', birthInfo?.birthdateLabel),
                    InfoRow('Возраст', birthInfo?.ageLabel),
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
                if (birthInfo != null) 'Дата рождения: ${birthInfo.birthdateLabel}',
                if (birthInfo != null) 'Возраст: ${birthInfo.ageLabel}',
              ].join('\n');
              Copy.text(context, text, label: 'Учитель');
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: isWide(context)
          ? AppScaffoldMaxWidth(maxWidth: 980, child: page)
          : page,
    );
  }

  _TeacherBirthInfo? _birthInfoFromPin() {
    final raw = (teacher.pinAsString ?? teacher.pin?.toString() ?? '').trim();
    if (!RegExp(r'^\d{9,}$').hasMatch(raw)) return null;

    final genderDigit = int.tryParse(raw.substring(0, 1));
    final day = int.tryParse(raw.substring(1, 3));
    final month = int.tryParse(raw.substring(3, 5));
    final year = int.tryParse(raw.substring(5, 9));
    if (genderDigit == null || day == null || month == null || year == null) {
      return null;
    }

    if (genderDigit != 1 && genderDigit != 2) return null;
    if (year < 1900 || year > DateTime.now().year) return null;

    final birthDate = DateTime(year, month, day);
    if (birthDate.year != year ||
        birthDate.month != month ||
        birthDate.day != day) {
      return null;
    }

    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hadBirthdayThisYear = now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthdayThisYear) age--;

    return _TeacherBirthInfo(birthDate: birthDate, age: age);
  }
}

class _TeacherBirthInfo {
  final DateTime birthDate;
  final int age;

  const _TeacherBirthInfo({
    required this.birthDate,
    required this.age,
  });

  String get birthdateLabel => '${birthDate.russianTextDate} года';

  String get ageLabel => '$age лет';
}
