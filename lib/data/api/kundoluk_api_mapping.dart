import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/network/api_error_kind.dart';
import '../../core/network/api_failure.dart';

class KundolukApiMapping {
  ApiFailure mapDioToFailure(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ApiFailure(
        kind: ApiErrorKind.timeout,
        title: 'Превышено время ожидания',
        message: 'Сервер долго отвечает. Проверь интернет и попробуй ещё раз.',
        httpStatus: status,
        details: e.message,
      );
    }

    if (e.type == DioExceptionType.unknown) {
      final msg = (e.message ?? '').toLowerCase();
      if (msg.contains('socket') || msg.contains('network') || msg.contains('failed host lookup')) {
        return ApiFailure(
          kind: ApiErrorKind.network,
          title: 'Нет соединения',
          message: 'Похоже, нет интернета или сервер недоступен.',
          details: e.message,
        );
      }
      if (msg.contains('handshake') || msg.contains('certificate')) {
        return ApiFailure(
          kind: ApiErrorKind.network,
          title: 'Проблема SSL',
          message: 'Не удалось установить защищённое соединение.',
          details: e.message,
        );
      }
      if (msg.contains('invalid')) {
        return ApiFailure(
          kind: ApiErrorKind.badUrl,
          title: 'Неверный адрес API',
          message: 'Проверь Base URL в настройках.',
          details: e.message,
        );
      }
    }

    if (status == 401) {
      return ApiFailure(
        kind: ApiErrorKind.unauthorized,
        title: 'Сессия недействительна',
        message: 'Токен истёк или пароль был изменён. Нужно войти заново.',
        httpStatus: status,
        details: data,
      );
    }
    if (status == 403) {
      return ApiFailure(
        kind: ApiErrorKind.forbidden,
        title: 'Доступ запрещён',
        message: 'Нет прав доступа к этому действию.',
        httpStatus: status,
        details: data,
      );
    }
    if (status == 400) {
      final text = extractServerErrorMessage(data) ?? 'Неверные данные запроса.';
      return ApiFailure(
        kind: ApiErrorKind.validation,
        title: 'Ошибка данных',
        message: text,
        httpStatus: status,
        details: data,
      );
    }
    if (status != null && status >= 500) {
      return ApiFailure(
        kind: ApiErrorKind.server,
        title: 'Ошибка сервера',
        message: 'Сервер вернул ошибку ($status). Попробуй позже.',
        httpStatus: status,
        details: data,
      );
    }

    return ApiFailure(
      kind: ApiErrorKind.unknown,
      title: 'Ошибка',
      message: 'Не удалось выполнить запрос.',
      httpStatus: status,
      details: data ?? e.message,
    );
  }

  String? extractServerErrorMessage(dynamic data) {
    try {
      if (data is String) {
        final decoded = jsonDecode(data);
        return extractServerErrorMessage(decoded);
      }
      if (data is List) {
        final msgs = data
            .map((e) => (e is Map ? (e['errorMessage'] ?? e['message'] ?? '').toString() : e.toString()))
            .where((s) => s.trim().isNotEmpty)
            .toList();
        if (msgs.isNotEmpty) return msgs.join('; ');
      }
      if (data is Map) {
        final m = data.cast<dynamic, dynamic>();
        final msg = (m['message'] ?? m['resultMessage'] ?? m['errorMessage'])?.toString();
        if (msg != null && msg.trim().isNotEmpty) return msg;
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry(k.toString(), v));
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        return asMap(decoded);
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  List<dynamic> asList(dynamic v) => v is List ? v : const [];
}
