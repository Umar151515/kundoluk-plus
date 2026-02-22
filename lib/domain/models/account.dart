import '../../core/extensions/map_x.dart';
import 'school.dart';

class Account {
  final String? userId;
  final String? studentId;
  final String? okpo;
  final int? pin;
  final String? pinAsString;
  final int? grade;
  final String? letter;
  final String? lastName;
  final String? firstName;
  final String? midName;
  final String? email;
  final String? phone;
  final bool? isAgreementSigned;
  final String? locale;
  final bool? changePassword;
  final String? role;
  final DateTime? birthdate;
  final School? school;

  Account({
    this.userId,
    this.studentId,
    this.okpo,
    this.pin,
    this.pinAsString,
    this.grade,
    this.letter,
    this.lastName,
    this.firstName,
    this.midName,
    this.email,
    this.phone,
    this.isAgreementSigned,
    this.locale,
    this.changePassword,
    this.role,
    this.birthdate,
    this.school,
  });

  String get fio => [
        lastName,
        firstName,
        midName,
      ].where((e) => e != null && e.trim().isNotEmpty).map((e) => e!.trim()).join(' ').trim();

  String get classLabel => '${grade ?? '?'}${letter ?? ''}';

  static Account fromJson(Map<String, dynamic> json) {
    String? pickStr(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null) return v.toString();
      }
      return null;
    }

    final schoolJson = json['school'];
    return Account(
      userId: pickStr(['userId', 'user_id']),
      studentId: pickStr(['studentId', 'student_id']),
      okpo: pickStr(['okpo']),
      pin: json.parseInt('pin'),
      pinAsString: pickStr(['pinAsString', 'pin_as_string']),
      grade: json.parseInt('grade'),
      letter: pickStr(['letter']),
      lastName: pickStr(['last_name', 'lastName', 'lastNameRu']),
      firstName: pickStr(['first_name', 'firstName']),
      midName: pickStr(['mid_name', 'midName']),
      email: pickStr(['email']),
      phone: pickStr(['phone']),
      isAgreementSigned: json.parseBool('isAgreementSigned'),
      locale: pickStr(['locale']),
      changePassword: json.parseBool('changePassword'),
      role: pickStr(['type', 'role']),
      birthdate: json.parseDateTime('birthdate'),
      school: schoolJson is Map ? School.fromJson(schoolJson.cast<String, dynamic>()) : null,
    );
  }
}
