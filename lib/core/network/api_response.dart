import 'api_failure.dart';

class ApiResponse<T> {
  final int resultCode;
  final String message;
  final T data;
  final ApiFailure? failure;

  const ApiResponse({
    required this.resultCode,
    required this.message,
    required this.data,
    this.failure,
  });

  bool get isSuccess => failure == null && resultCode == 0;

  static ApiResponse<T> ok<T>(T data, {String message = 'ОК'}) =>
      ApiResponse(resultCode: 0, message: message, data: data);

  static ApiResponse<T> fail<T>(
    ApiFailure f, {
    int resultCode = -1,
    required T data,
  }) =>
      ApiResponse(
        resultCode: resultCode,
        message: f.message,
        data: data,
        failure: f,
      );
}
