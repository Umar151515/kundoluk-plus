import '../../core/extensions/map_x.dart';
import 'lesson_teacher.dart';
import 'mark.dart';
import 'room.dart';
import 'student_info.dart';
import 'subject.dart';
import 'task.dart';
import 'topic.dart';

class Lesson {
  final String? uid;
  final String? scheduleItemId;
  final LessonTeacher? teacher;
  final Subject? subject;
  final Room? room;
  final String? startTime;
  final String? endTime;
  final String? lessonTime;
  final DateTime? lessonDay;
  final int? year;
  final int? month;
  final int? day;
  final int? lessonNumber;
  final StudentInfo? student;
  final List<Mark> marks;
  final Topic? topic;
  final Task? task;
  final Task? lastTask;
  final String? okpo;
  final String? gradeId;
  final int? grade;
  final String? letter;
  final bool? isKrujok;
  final int? group;
  final String? groupId;
  final String? subjectGroupName;
  final int? shift;
  final int? dayOfWeek;
  final String? schoolId;
  final String? schoolNameKg;
  final String? schoolNameRu;
  final bool? isContentSubject;
  final bool? isTwelve;
  final int? orderIndex;

  Lesson({
    this.uid,
    this.scheduleItemId,
    this.teacher,
    this.subject,
    this.room,
    this.startTime,
    this.endTime,
    this.lessonTime,
    this.lessonDay,
    this.year,
    this.month,
    this.day,
    this.lessonNumber,
    this.student,
    this.marks = const [],
    this.topic,
    this.task,
    this.lastTask,
    this.okpo,
    this.gradeId,
    this.grade,
    this.letter,
    this.isKrujok,
    this.group,
    this.groupId,
    this.subjectGroupName,
    this.shift,
    this.dayOfWeek,
    this.schoolId,
    this.schoolNameKg,
    this.schoolNameRu,
    this.isContentSubject,
    this.isTwelve,
    this.orderIndex,
  });

  Lesson copyWith({List<Mark>? marks}) {
    return Lesson(
      uid: uid,
      scheduleItemId: scheduleItemId,
      teacher: teacher,
      subject: subject,
      room: room,
      startTime: startTime,
      endTime: endTime,
      lessonTime: lessonTime,
      lessonDay: lessonDay,
      year: year,
      month: month,
      day: day,
      lessonNumber: lessonNumber,
      student: student,
      marks: marks ?? this.marks,
      topic: topic,
      task: task,
      lastTask: lastTask,
      okpo: okpo,
      gradeId: gradeId,
      grade: grade,
      letter: letter,
      isKrujok: isKrujok,
      group: group,
      groupId: groupId,
      subjectGroupName: subjectGroupName,
      shift: shift,
      dayOfWeek: dayOfWeek,
      schoolId: schoolId,
      schoolNameKg: schoolNameKg,
      schoolNameRu: schoolNameRu,
      isContentSubject: isContentSubject,
      isTwelve: isTwelve,
      orderIndex: orderIndex,
    );
  }

  static Lesson? fromJson(Map<String, dynamic> json) {
    final teacherJson = json['teacher'];
    final subjectJson = json['subject'];
    final roomJson = json['roomData'];
    final studentJson = json['student'];
    final marksJson = json['marks'];
    final topicJson = json['topic'];
    final taskJson = json['task'];
    final lastTaskJson = json['lastTask'];

    final marks = (marksJson is List)
        ? marksJson
            .map((e) => Mark.fromJson(e is Map ? e.cast<String, dynamic>() : {}))
            .whereType<Mark>()
            .toList()
        : <Mark>[];

    return Lesson(
      uid: json['uid']?.toString(),
      scheduleItemId: json['scheduleItemId']?.toString(),
      teacher: teacherJson is Map ? LessonTeacher.fromJson(teacherJson.cast<String, dynamic>()) : null,
      subject: subjectJson is Map ? Subject.fromJson(subjectJson.cast<String, dynamic>()) : null,
      room: roomJson is Map ? Room.fromJson(roomJson.cast<String, dynamic>()) : null,
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      lessonTime: json['lessonTime']?.toString(),
      lessonDay: json.parseDateTime('lessonDay'),
      year: json.parseInt('year'),
      month: json.parseInt('month'),
      day: json.parseInt('day'),
      lessonNumber: json.parseInt('lesson'),
      student: studentJson is Map ? StudentInfo.fromJson(studentJson.cast<String, dynamic>()) : null,
      marks: marks,
      topic: topicJson is Map ? Topic.fromJson(topicJson.cast<String, dynamic>()) : null,
      task: taskJson is Map ? Task.fromJson(taskJson.cast<String, dynamic>()) : null,
      lastTask: lastTaskJson is Map ? Task.fromJson(lastTaskJson.cast<String, dynamic>()) : null,
      okpo: json['okpo']?.toString(),
      gradeId: json['gradeId']?.toString(),
      grade: json.parseInt('grade'),
      letter: json['letter']?.toString(),
      isKrujok: json.parseBool('isKrujok'),
      group: json.parseInt('group'),
      groupId: json['groupId']?.toString(),
      subjectGroupName: json['subjectGroupName']?.toString(),
      shift: json.parseInt('shift'),
      dayOfWeek: json.parseInt('dayOfWeek'),
      schoolId: json['school']?.toString(),
      schoolNameKg: json['schoolNameKg']?.toString(),
      schoolNameRu: json['schoolNameRu']?.toString(),
      isContentSubject: json.parseBool('isContentSubject'),
      isTwelve: json.parseBool('isTwelve'),
      orderIndex: json.parseInt('orderIndex'),
    );
  }
}
