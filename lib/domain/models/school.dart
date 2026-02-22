import '../../core/extensions/map_x.dart';

class School {
  final String? schoolId;
  final String? institutionId;
  final String? okpo;
  final String? nameRu;
  final String? shortName;
  final bool? isStaffActive;

  School({
    this.schoolId,
    this.institutionId,
    this.okpo,
    this.nameRu,
    this.shortName,
    this.isStaffActive,
  });

  static School fromJson(Map<String, dynamic> json) => School(
        schoolId: (json['schoolId'] ?? json['school_id'])?.toString(),
        institutionId: (json['institutionId'] ?? json['institution_id'])?.toString(),
        okpo: json['okpo']?.toString(),
        nameRu: (json['nameRu'] ?? json['name_ru'])?.toString(),
        shortName: (json['short'] ?? json['shortName'])?.toString(),
        isStaffActive: json.parseBool('isStaffActive'),
      );
}
