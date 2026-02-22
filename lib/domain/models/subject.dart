import '../../core/extensions/map_x.dart';

class Subject {
  final String? code;
  final String? name;
  final String? nameKg;
  final String? nameRu;
  final String? short;
  final String? shortKg;
  final String? shortRu;
  final int? grade;

  Subject({
    this.code,
    this.name,
    this.nameKg,
    this.nameRu,
    this.short,
    this.shortKg,
    this.shortRu,
    this.grade,
  });

  static Subject fromJson(Map<String, dynamic> json) {
    return Subject(
      code: json['code']?.toString(),
      name: json['name']?.toString(),
      nameKg: json['nameKg']?.toString(),
      nameRu: json['nameRu']?.toString(),
      short: json['short']?.toString(),
      shortKg: json['shortKg']?.toString(),
      shortRu: json['shortRu']?.toString(),
      grade: json.parseInt('grade'),
    );
  }
}
