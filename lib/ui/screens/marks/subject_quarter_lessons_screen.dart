import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/api/kundoluk_api.dart';
import '../../widgets/app_scaffold_max_width.dart';
import 'subject_lessons_sheet.dart';
import 'subject_quarter_lessons_bloc.dart';

class SubjectQuarterLessonsScreen extends StatelessWidget {
  final KundolukApi api;
  final int term;
  final String subjectName;

  const SubjectQuarterLessonsScreen({
    super.key,
    required this.api,
    required this.term,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          SubjectQuarterLessonsBloc(api: api, term: term)
            ..add(SubjectQuarterLessonsStarted()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Уроки за четверть')),
        body: AppScaffoldMaxWidth(
          padding: EdgeInsets.symmetric(vertical: 10),
          maxWidth: 980,
          child: SubjectQuarterLessonsContent(
            subjectName: subjectName,
            term: term,
            fullScreen: true,
          ),
        ),
      ),
    );
  }
}
