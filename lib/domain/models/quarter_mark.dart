import '../../core/extensions/map_x.dart';

class QuarterMark {
  final String? objectId;
  final String? gradeId;
  final String? studentId;
  final String? subjectId;
  final int? quarter;
  final double? quarterAvg;
  final int? quarterMark;
  final String? customMark;
  final bool? isBonus;
  final DateTime? quarterDate;
  final String? subjectNameKg;
  final String? subjectNameRu;
  final String? staffId;

  QuarterMark({
    this.objectId,
    this.gradeId,
    this.studentId,
    this.subjectId,
    this.quarter,
    this.quarterAvg,
    this.quarterMark,
    this.customMark,
    this.isBonus,
    this.quarterDate,
    this.subjectNameKg,
    this.subjectNameRu,
    this.staffId,
  });

  static QuarterMark? fromJson(Map<String, dynamic> json) {
    return QuarterMark(
      objectId: json['objectId']?.toString(),
      gradeId: json['gradeId']?.toString(),
      studentId: json['studentId']?.toString(),
      subjectId: json['subjectId']?.toString(),
      quarter: json.parseInt('quarter'),
      quarterAvg: json.parseDouble('quarterAvg'),
      quarterMark: json.parseInt('quarterMark'),
      customMark: json['customMark']?.toString(),
      isBonus: json.parseBool('isBonus'),
      quarterDate: json.parseDateTime('quarterDate'),
      subjectNameKg: json['subjectNameKg']?.toString(),
      subjectNameRu: json['subjectNameRu']?.toString(),
      staffId: json['staffId']?.toString(),
    );
  }
}
