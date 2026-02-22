import 'api_error_kind.dart';

class ApiFailure implements Exception {
  final ApiErrorKind kind;
  final String title;
  final String message;
  final int? httpStatus;
  final dynamic details;

  ApiFailure({
    required this.kind,
    required this.title,
    required this.message,
    this.httpStatus,
    this.details,
  });

  @override
  String toString() => '$title: $message';
}
