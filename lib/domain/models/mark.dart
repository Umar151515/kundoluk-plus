import '../../core/extensions/map_x.dart';

class Mark {
  final String? markId;
  final String? lsUid;
  final String? uid;
  final String? studentId;
  final int? studentPin;
  final String? studentPinAsString;
  final String? firstName;
  final String? lastName;
  final String? midName;
  final int? value;
  final String? markType;
  final int? oldMark;
  final String? customMark;
  final bool? absent;
  final String? absentType;
  final String? absentReason;
  final int? lateMinutes;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? success;

  Mark({
    this.markId,
    this.lsUid,
    this.uid,
    this.studentId,
    this.studentPin,
    this.studentPinAsString,
    this.firstName,
    this.lastName,
    this.midName,
    this.value,
    this.markType,
    this.oldMark,
    this.customMark,
    this.absent,
    this.absentType,
    this.absentReason,
    this.lateMinutes,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.success,
  });

  static Mark? fromJson(Map<String, dynamic> json) {
    return Mark(
      markId: json['mark_id']?.toString(),
      lsUid: json['ls_uid']?.toString(),
      uid: json['uid']?.toString(),
      studentId: json['idStudent']?.toString(),
      studentPin: json.parseInt('student_pin'),
      studentPinAsString: json['student_pin_as_string']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      midName: json['mid_name']?.toString(),
      value: json.parseInt('mark'),
      markType: json['mark_type']?.toString(),
      oldMark: json.parseInt('old_mark'),
      customMark: json['custom_mark']?.toString(),
      absent: json.parseBool('absent'),
      absentType: json['absent_type']?.toString(),
      absentReason: json['absent_reason']?.toString(),
      lateMinutes: json.parseInt('late_minutes'),
      note: json['note']?.toString(),
      createdAt: json.parseDateTime('created_at'),
      updatedAt: json.parseDateTime('updated_at'),
      success: json.parseBool('success'),
    );
  }

  bool get isNumericMark => value != null && value! > 0;
}
