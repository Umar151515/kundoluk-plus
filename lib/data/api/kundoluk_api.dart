import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/cache_keys.dart';
import '../../core/extensions/datetime_x.dart';
import '../../core/extensions/map_x.dart';
import '../../core/network/api_error_kind.dart';
import '../../core/network/api_failure.dart';
import '../../core/network/api_response.dart';
import '../../data/stores/app_settings_store.dart';
import '../../data/stores/auth_store.dart';
import '../../domain/models/account.dart';
import '../../domain/models/daily_schedule.dart';
import '../../domain/models/daily_schedules.dart';
import '../../domain/models/lesson.dart';
import '../../domain/models/mark.dart';
import '../../domain/models/quarter_mark.dart';
import '../../domain/school_year/school_year.dart';
import 'kundoluk_api_mapping.dart';

class KundolukApi {
  final Dio dio;
  final SharedPreferences prefs;
  final AppSettingsStore settings;
  final AuthStore auth;

  final KundolukApiMapping _mapping = KundolukApiMapping();

  KundolukApi({
    required this.dio,
    required this.prefs,
    required this.settings,
    required this.auth,
  }) {
    dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 40),
      sendTimeout: const Duration(seconds: 25),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['content-type'] = 'application/json';
          options.headers['accept-encoding'] = 'gzip';
          options.headers['host'] = 'kundoluk.edu.gov.kg';
          options.headers['user-agent'] = settings.userAgent;

          final active = auth.activeAccount;
          if (active != null) {
            final token = await auth.getToken(active.id);
            if (token != null && token.isNotEmpty) {
              options.headers['authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          if (e.response?.statusCode == 401) {
            await auth.invalidateActiveToken();
          }
          handler.next(e);
        },
      ),
    );
  }

  String get baseUrl => settings.baseUrl;

  Future<ApiResponse<Account>> loginStudent({
    required String username,
    required String password,
    bool makeActive = true,
  }) async {
    try {
      final url = '${baseUrl}auth/loginStudent';
      final resp = await dio.post(url, data: {
        'username': username,
        'password': password,
        'device': defaultTargetPlatform.name,
      });

      if (resp.statusCode != 200) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.server,
            title: 'Ошибка сервера',
            message: 'Сервер вернул HTTP ${resp.statusCode}.',
            httpStatus: resp.statusCode,
            details: resp.data,
          ),
          data: Account(),
        );
      }

      final map = _mapping.asMap(resp.data);
      final token = (map['token'] ?? '').toString();

      if (token.isEmpty) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.parse,
            title: 'Ошибка ответа сервера',
            message: 'Не удалось получить токен авторизации.',
            details: map,
          ),
          data: Account(),
        );
      }

      final account = Account.fromJson(map);

      await auth.setOrReplaceSession(
        username: username,
        token: token,
        password: password,
        accountJson: map,
        makeActive: makeActive,
      );

      return ApiResponse.ok(account);
    } on DioException catch (e) {
      return ApiResponse.fail(_mapping.mapDioToFailure(e), data: Account());
    } catch (e) {
      return ApiResponse.fail(
        ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: e.toString()),
        data: Account(),
      );
    }
  }

  Future<ApiResponse<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final active = auth.activeAccount;
      if (active == null) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.unauthorized,
            title: 'Нет аккаунта',
            message: 'Сначала войди в аккаунт.',
          ),
          data: null,
        );
      }

      final curr = currentPassword.trim();
      if (curr.isEmpty) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.validation,
            title: 'Нужен текущий пароль',
            message: 'Введи текущий пароль.',
          ),
          data: null,
        );
      }
      if (newPassword.trim().isEmpty) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.validation,
            title: 'Новый пароль пустой',
            message: 'Укажи новый пароль.',
          ),
          data: null,
        );
      }

      final url = '${baseUrl}account/changePasswordStudent';
      final resp = await dio.post(url, data: {
        'CurrentPassword': curr,
        'NewPassword': newPassword,
        'NewPasswordConfirmation': newPassword,
      });

      final map = _mapping.asMap(resp.data);
      final code = map.parseInt('resultCode') ?? 0;
      final msg = (map['resultMessage'] ?? map['message'] ?? '').toString();

      if (resp.statusCode != 200) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.server,
            title: 'Ошибка сервера',
            message: 'Сервер вернул HTTP ${resp.statusCode}.',
            httpStatus: resp.statusCode,
            details: resp.data,
          ),
          data: null,
        );
      }

      if (code != 0) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.validation,
            title: 'Не удалось сменить пароль',
            message: msg.isEmpty ? 'Сервер не принял новый пароль.' : msg,
            details: map,
          ),
          resultCode: code,
          data: null,
        );
      }

      await auth.updateActivePassword(newPassword);
      return ApiResponse.ok(null, message: msg.isEmpty ? 'Пароль изменён' : msg);
    } on DioException catch (e) {
      return ApiResponse.fail(_mapping.mapDioToFailure(e), data: null);
    } catch (e) {
      return ApiResponse.fail(
        ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: e.toString()),
        data: null,
      );
    }
  }

  Future<ApiResponse<void>> ensureAuthorized() async {
    final active = auth.activeAccount;
    if (active == null) {
      return ApiResponse.fail(
        ApiFailure(
          kind: ApiErrorKind.unauthorized,
          title: 'Нет аккаунта',
          message: 'Сначала войди в аккаунт.',
        ),
        data: null,
      );
    }

    final token = await auth.getToken(active.id);
    if (token == null || token.isEmpty) {
      final password = await auth.getPassword(active.id);
      if (password == null || password.isEmpty) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.unauthorized,
            title: 'Нужно войти заново',
            message: 'Токен недействителен. Пароль не сохранён — войди заново.',
          ),
          data: null,
        );
      }
      final relogin = await loginStudent(
        username: active.username,
        password: password,
        makeActive: true,
      );
      if (!relogin.isSuccess) {
        return ApiResponse.fail(relogin.failure!, data: null);
      }
    }
    return ApiResponse.ok(null);
  }

  Future<ApiResponse<DailySchedule?>> getDailySchedule(DateTime day) async {
    final authOk = await ensureAuthorized();
    if (!authOk.isSuccess) return ApiResponse.fail(authOk.failure!, data: null);

    try {
      final start = day.toApiDate();
      final end = day.toApiDate();

      final resp = await dio.get(
        '${baseUrl}student/gradebook/list',
        queryParameters: {'start_date': start, 'end_date': end},
      );

      final json = _mapping.asMap(resp.data);
      final code = json.parseInt('resultCode') ?? 0;
      final msg = (json['resultMessage'] ?? json['message'] ?? '').toString();
      final action = json.containsKey('actionResult') ? json['actionResult'] : json;

      if (code != 0) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.server,
            title: 'Ошибка сервера',
            message: msg.isEmpty ? 'Сервер вернул ошибку (код=$code).' : msg,
            details: json,
          ),
          resultCode: code,
          data: null,
        );
      }

      final list = _mapping.asList(action);
      final lessons = list
          .map((e) => Lesson.fromJson(_mapping.asMap(e)))
          .whereType<Lesson>()
          .toList()
        ..sort((a, b) => (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999));

      final schedule = DailySchedule(date: day.dateOnly, lessons: lessons);

      await auth.saveToCache(CacheKeys.schedule(day), json);

      return ApiResponse.ok(schedule, message: msg);
    } on DioException catch (e) {
      return ApiResponse.fail(_mapping.mapDioToFailure(e), data: null);
    } catch (e) {
      return ApiResponse.fail(
        ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: e.toString()),
        data: null,
      );
    }
  }

  Future<ApiResponse<DailySchedules>> getScheduleRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final authOk = await ensureAuthorized();
    if (!authOk.isSuccess) {
      return ApiResponse.fail(
        authOk.failure!,
        data: const DailySchedules(days: []),
      );
    }

    try {
      final resp = await dio.get(
        '${baseUrl}student/gradebook/list',
        queryParameters: {
          'start_date': start.toApiDate(),
          'end_date': end.toApiDate(),
        },
      );

      final json = _mapping.asMap(resp.data);
      final code = json.parseInt('resultCode') ?? 0;
      final msg = (json['resultMessage'] ?? json['message'] ?? '').toString();
      final action = json.containsKey('actionResult') ? json['actionResult'] : json;

      if (resp.statusCode != 200) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.server,
            title: 'Ошибка сервера',
            message: 'Сервер вернул HTTP ${resp.statusCode}.',
            httpStatus: resp.statusCode,
            details: resp.data,
          ),
          data: const DailySchedules(days: []),
        );
      }

      if (code != 0) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.server,
            title: 'Ошибка сервера',
            message: msg.isEmpty ? 'Сервер вернул ошибку (код=$code).' : msg,
            details: json,
          ),
          resultCode: code,
          data: const DailySchedules(days: []),
        );
      }

      final list = _mapping.asList(action);
      final lessons = list.map((e) => Lesson.fromJson(_mapping.asMap(e))).whereType<Lesson>().toList();

      final daysMap = <DateTime, List<Lesson>>{};
      for (final l in lessons) {
        final d = l.lessonDay?.toLocal();
        if (d == null) continue;
        final day = DateTime(d.year, d.month, d.day);
        daysMap.putIfAbsent(day, () => []).add(l);
      }

      final days = daysMap.entries
          .map((e) {
            final ls = [...e.value]..sort((a, b) => (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999));
            return DailySchedule(date: e.key, lessons: ls);
          })
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      return ApiResponse.ok(DailySchedules(days: days), message: msg);
    } on DioException catch (e) {
      return ApiResponse.fail(
        _mapping.mapDioToFailure(e),
        data: const DailySchedules(days: []),
      );
    } catch (e) {
      return ApiResponse.fail(
        ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: e.toString()),
        data: const DailySchedules(days: []),
      );
    }
  }

  Future<ApiResponse<DailySchedules>> getFullScheduleTerm(int term) async {
    if (term < 1 || term > 4) {
      return ApiResponse.fail(
        ApiFailure(
          kind: ApiErrorKind.validation,
          title: 'Неверная четверть',
          message: 'Четверть должна быть от 1 до 4.',
        ),
        data: const DailySchedules(days: []),
      );
    }

    final authOk = await ensureAuthorized();
    if (!authOk.isSuccess) {
      return ApiResponse.fail(
        authOk.failure!,
        data: const DailySchedules(days: []),
      );
    }

    try {
      final now = DateTime.now();
      final yearStart = now.month >= 9 ? now.year : now.year - 1;

      final q = SchoolYear.quarters[term]!;
      final startArr = q['start']!;
      final endArr = q['end']!;
      final y = term <= 2 ? yearStart : yearStart + 1;
      final start = DateTime(y, startArr[0], startArr[1]);
      final end = DateTime(y, endArr[0], endArr[1]);

      final baseResp = await getScheduleRange(start: start, end: end);
      if (!baseResp.isSuccess) {
        return ApiResponse.fail(
          baseResp.failure!,
          data: const DailySchedules(days: []),
        );
      }

      final base = baseResp.data;

      final results = await Future.wait([
        getScheduleWithMarks(term, absent: false),
        getScheduleWithMarks(term, absent: true),
      ]);

      final marksResp = results[0];
      final absentResp = results[1];

      if (!marksResp.isSuccess && !absentResp.isSuccess) {
        return ApiResponse.fail(
          marksResp.failure ?? absentResp.failure!,
          data: const DailySchedules(days: []),
        );
      }

      final merged = _mergeQuarterData(
        base: base,
        extras: [
          if (marksResp.isSuccess) marksResp.data,
          if (absentResp.isSuccess) absentResp.data,
        ],
      );

      final cacheJson = _serializeDailySchedulesToCacheJson(merged);
      await auth.saveToCache(CacheKeys.fullTerm(term), cacheJson);

      return ApiResponse.ok(merged, message: 'Расписание за четверть обновлено');
    } on DioException catch (e) {
      return ApiResponse.fail(
        _mapping.mapDioToFailure(e),
        data: const DailySchedules(days: []),
      );
    } catch (e) {
      return ApiResponse.fail(
        ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: e.toString()),
        data: const DailySchedules(days: []),
      );
    }
  }

  Future<DailySchedules?> loadFullScheduleTermFromCache(int term) async {
    final json = await auth.loadFromCache(CacheKeys.fullTerm(term));
    if (json == null) return null;

    try {
      final action = json['actionResult'];
      if (action is! List) return null;

      final lessons = action.map((e) => Lesson.fromJson(_mapping.asMap(e))).whereType<Lesson>().toList();

      final daysMap = <DateTime, List<Lesson>>{};
      for (final l in lessons) {
        final d = l.lessonDay?.toLocal();
        if (d == null) continue;
        final day = DateTime(d.year, d.month, d.day);
        daysMap.putIfAbsent(day, () => []).add(l);
      }

      final days = daysMap.entries
          .map((e) {
            final ls = [...e.value]..sort((a, b) => (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999));
            return DailySchedule(date: e.key, lessons: ls);
          })
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      return DailySchedules(days: days);
    } catch (_) {
      return null;
    }
  }

  DailySchedules _mergeQuarterData({
    required DailySchedules base,
    required List<DailySchedules> extras,
  }) {
    String makeKey(Lesson l, DateTime day) {
      final uid = l.uid;
      if (uid != null && uid.trim().isNotEmpty) return 'uid:$uid';

      final num = l.lessonNumber ?? -1;
      final subj = (l.subject?.nameRu ?? l.subject?.name ?? '').trim();
      return 'fb:${day.toIso8601String()}:$num:$subj';
    }

    final marksByKey = <String, List<Mark>>{};

    for (final ex in extras) {
      for (final day in ex.days) {
        for (final lesson in day.lessons) {
          if (lesson.marks.isEmpty) continue;
          final k = makeKey(lesson, day.date);
          marksByKey.putIfAbsent(k, () => []).addAll(lesson.marks);
        }
      }
    }

    final mergedDays = base.days.map((day) {
      final mergedLessons = day.lessons.map((lesson) {
        final k = makeKey(lesson, day.date);
        final extraMarks = marksByKey[k];
        if (extraMarks == null || extraMarks.isEmpty) return lesson;
        final mergedMarks = _uniqueMarks([...lesson.marks, ...extraMarks]);
        return lesson.copyWith(marks: mergedMarks);
      }).toList();

      mergedLessons.sort((a, b) => (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999));
      return DailySchedule(date: day.date, lessons: mergedLessons);
    }).toList();

    mergedDays.sort((a, b) => a.date.compareTo(b.date));
    return DailySchedules(days: mergedDays);
  }

  Future<ApiResponse<DailySchedule?>> getFullScheduleDay(DateTime day) async {
    final authOk = await ensureAuthorized();
    if (!authOk.isSuccess) {
      return ApiResponse.fail(authOk.failure!, data: null);
    }

    final scheduleResp = await getDailySchedule(day);
    if (!scheduleResp.isSuccess) return scheduleResp;

    final dailySchedule = scheduleResp.data;
    if (dailySchedule == null) return ApiResponse.ok(null);

    final term = SchoolYear.getQuarter(day, nearest: true) ?? 1;

    final results = await Future.wait([
      getScheduleWithMarks(term, absent: false),
      getScheduleWithMarks(term, absent: true),
    ]);

    final marksResp = results[0];
    final absentResp = results[1];

    if (!marksResp.isSuccess && !absentResp.isSuccess) {
      return ApiResponse.fail(
        marksResp.failure ?? absentResp.failure!,
        data: null,
      );
    }

    final extraLessons = <Lesson>[];
    if (marksResp.isSuccess) {
      final mDay = marksResp.data.getByDate(day);
      if (mDay != null) extraLessons.addAll(mDay.lessons);
    }
    if (absentResp.isSuccess) {
      final aDay = absentResp.data.getByDate(day);
      if (aDay != null) extraLessons.addAll(aDay.lessons);
    }

    final marksByLessonUid = <String, List<Mark>>{};
    for (final lesson in extraLessons) {
      final uid = lesson.uid;
      if (uid == null || uid.isEmpty) continue;
      if (lesson.marks.isEmpty) continue;
      marksByLessonUid.putIfAbsent(uid, () => []).addAll(lesson.marks);
    }

    final mergedLessons = dailySchedule.lessons.map((lesson) {
      final uid = lesson.uid;
      if (uid != null && marksByLessonUid.containsKey(uid)) {
        final uniqueMarks = _uniqueMarks([...lesson.marks, ...marksByLessonUid[uid]!]);
        return lesson.copyWith(marks: uniqueMarks);
      }
      return lesson;
    }).toList();

    mergedLessons.sort((a, b) => (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999));

    final fullDay = DailySchedule(date: dailySchedule.date, lessons: mergedLessons);

    final cacheJson = _serializeDailyScheduleToCacheJson(fullDay);
    await auth.saveToCache(CacheKeys.schedule(day), cacheJson);

    return ApiResponse.ok(fullDay, message: 'Расписание обновлено');
  }

  List<Mark> _uniqueMarks(List<Mark> marks) {
    final map = <String, Mark>{};
    for (final m in marks) {
      final key = m.uid ??
          '${m.createdAt?.toIso8601String() ?? ''}:'
              '${m.value ?? ''}:'
              '${m.customMark ?? ''}:'
              '${m.absent ?? ''}:'
              '${m.lateMinutes ?? ''}:'
              '${m.absentType ?? ''}';
      map[key] = m;
    }
    final result = map.values.toList();
    result.sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
    return result;
  }

  Map<String, dynamic> _serializeDailyScheduleToCacheJson(DailySchedule day) {
    final lessons = day.lessons.map(_lessonToJsonForCache).toList();
    return {
      'resultCode': 0,
      'resultMessage': 'OK (cache)',
      'actionResult': lessons,
    };
  }

  Map<String, dynamic> _serializeDailySchedulesToCacheJson(DailySchedules schedules) {
    final lessons = <Map<String, dynamic>>[];
    for (final d in schedules.days) {
      for (final l in d.lessons) {
        lessons.add(_lessonToJsonForCache(l));
      }
    }
    return {
      'resultCode': 0,
      'resultMessage': 'OK (cache)',
      'actionResult': lessons,
    };
  }

  Map<String, dynamic> _lessonToJsonForCache(Lesson l) {
    return <String, dynamic>{
      'uid': l.uid,
      'scheduleItemId': l.scheduleItemId,
      'teacher': l.teacher == null
          ? null
          : {
              'pin': l.teacher!.pin,
              'pinAsString': l.teacher!.pinAsString,
              'firstName': l.teacher!.firstName,
              'lastName': l.teacher!.lastName,
              'midName': l.teacher!.midName,
            },
      'subject': l.subject == null
          ? null
          : {
              'code': l.subject!.code,
              'name': l.subject!.name,
              'nameKg': l.subject!.nameKg,
              'nameRu': l.subject!.nameRu,
              'short': l.subject!.short,
              'shortKg': l.subject!.shortKg,
              'shortRu': l.subject!.shortRu,
              'grade': l.subject!.grade,
            },
      'roomData': l.room == null
          ? null
          : {
              'id': l.room!.idRoom,
              'roomName': l.room!.roomName,
              'floor': l.room!.floor,
              'block': l.room!.block,
            },
      'startTime': l.startTime,
      'endTime': l.endTime,
      'lessonTime': l.lessonTime,
      'lessonDay': l.lessonDay?.toIso8601String(),
      'year': l.year,
      'month': l.month,
      'day': l.day,
      'lesson': l.lessonNumber,
      'student': l.student == null
          ? null
          : {
              'scheduleItemId': l.student!.scheduleItemId,
              'lessonDay': l.student!.lessonDay?.toIso8601String(),
              'lessonDayAsDateOnly': l.student!.lessonDayAsDateOnly?.toIso8601String(),
              'objectId': l.student!.objectId,
              'schoolId': l.student!.schoolId,
              'gradeId': l.student!.gradeId,
              'okpo': l.student!.okpo,
              'pin': l.student!.pin,
              'pinAsString': l.student!.pinAsString,
              'grade': l.student!.grade,
              'letter': l.student!.letter,
              'name': l.student!.name,
              'lastName': l.student!.lastName,
              'firstName': l.student!.firstName,
              'midName': l.student!.midName,
              'email': l.student!.email,
              'phone': l.student!.phone,
              'groupId': l.student!.groupId,
              'subjectGroupName': l.student!.subjectGroupName,
              'districtName': l.student!.districtName,
              'cityName': l.student!.cityName,
            },
      'marks': l.marks
          .map((m) => {
                'mark_id': m.markId,
                'ls_uid': m.lsUid,
                'uid': m.uid,
                'idStudent': m.studentId,
                'student_pin': m.studentPin,
                'student_pin_as_string': m.studentPinAsString,
                'first_name': m.firstName,
                'last_name': m.lastName,
                'mid_name': m.midName,
                'mark': m.value,
                'mark_type': m.markType,
                'old_mark': m.oldMark,
                'custom_mark': m.customMark,
                'absent': m.absent,
                'absent_type': m.absentType,
                'absent_reason': m.absentReason,
                'late_minutes': m.lateMinutes,
                'note': m.note,
                'created_at': m.createdAt?.toIso8601String(),
                'updated_at': m.updatedAt?.toIso8601String(),
                'success': m.success,
              })
          .toList(),
      'topic': l.topic == null
          ? null
          : {
              'code': l.topic!.code,
              'name': l.topic!.name,
              'short': l.topic!.short,
              'lessonDay': l.topic!.lessonDay?.toIso8601String(),
            },
      'task': l.task == null
          ? null
          : {
              'code': l.task!.code,
              'name': l.task!.name,
              'note': l.task!.note,
              'lessonDay': l.task!.lessonDay?.toIso8601String(),
            },
      'lastTask': l.lastTask == null
          ? null
          : {
              'code': l.lastTask!.code,
              'name': l.lastTask!.name,
              'note': l.lastTask!.note,
              'lessonDay': l.lastTask!.lessonDay?.toIso8601String(),
            },
      'okpo': l.okpo,
      'gradeId': l.gradeId,
      'grade': l.grade,
      'letter': l.letter,
      'isKrujok': l.isKrujok,
      'group': l.group,
      'groupId': l.groupId,
      'subjectGroupName': l.subjectGroupName,
      'shift': l.shift,
      'dayOfWeek': l.dayOfWeek,
      'school': l.schoolId,
      'schoolNameKg': l.schoolNameKg,
      'schoolNameRu': l.schoolNameRu,
      'isContentSubject': l.isContentSubject,
      'isTwelve': l.isTwelve,
      'orderIndex': l.orderIndex,
    };
  }

  Future<ApiResponse<DailySchedules>> getScheduleWithMarks(
    int term, {
    required bool absent,
  }) async {
    final authOk = await ensureAuthorized();
    if (!authOk.isSuccess) {
      return ApiResponse.fail(
        authOk.failure!,
        data: const DailySchedules(days: []),
      );
    }

    try {
      final resp = await dio.get(
        '${baseUrl}student/gradebook/term/$term',
        queryParameters: {'absent': absent ? 1 : 0},
      );

      final json = _mapping.asMap(resp.data);
      final code = json.parseInt('resultCode') ?? 0;
      final msg = (json['resultMessage'] ?? json['message'] ?? '').toString();
      final action = json.containsKey('actionResult') ? json['actionResult'] : json;

      if (code != 0) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.server,
            title: 'Ошибка сервера',
            message: msg.isEmpty ? 'Сервер вернул ошибку (код=$code).' : msg,
            details: json,
          ),
          resultCode: code,
          data: const DailySchedules(days: []),
        );
      }

      final list = _mapping.asList(action);
      final lessons = list.map((e) => Lesson.fromJson(_mapping.asMap(e))).whereType<Lesson>().toList();

      final daysMap = <DateTime, List<Lesson>>{};
      for (final l in lessons) {
        final d = l.lessonDay?.toLocal();
        if (d == null) continue;
        final day = DateTime(d.year, d.month, d.day);
        daysMap.putIfAbsent(day, () => []).add(l);
      }

      final days = daysMap.entries
          .map((e) {
            final ls = [...e.value]..sort((a, b) => (a.lessonNumber ?? 999).compareTo(b.lessonNumber ?? 999));
            return DailySchedule(date: e.key, lessons: ls);
          })
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final schedules = DailySchedules(days: days);

      await auth.saveToCache(CacheKeys.marks(term, absent), json);
      return ApiResponse.ok(schedules, message: msg);
    } on DioException catch (e) {
      return ApiResponse.fail(
        _mapping.mapDioToFailure(e),
        data: const DailySchedules(days: []),
      );
    } catch (e) {
      return ApiResponse.fail(
        ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: e.toString()),
        data: const DailySchedules(days: []),
      );
    }
  }

  Future<ApiResponse<List<QuarterMark>>> getAllQuarterMarks() async {
    final authOk = await ensureAuthorized();
    if (!authOk.isSuccess) return ApiResponse.fail(authOk.failure!, data: const []);

    try {
      final resp = await dio.get('${baseUrl}student/qmarks/all');

      final json = _mapping.asMap(resp.data);
      final code = json.parseInt('resultCode') ?? 0;
      final msg = (json['resultMessage'] ?? json['message'] ?? '').toString();
      final action = json.containsKey('actionResult') ? json['actionResult'] : json;

      if (code != 0) {
        return ApiResponse.fail(
          ApiFailure(
            kind: ApiErrorKind.server,
            title: 'Ошибка сервера',
            message: msg.isEmpty ? 'Сервер вернул ошибку (код=$code).' : msg,
            details: json,
          ),
          resultCode: code,
          data: const [],
        );
      }

      final results = _mapping.asList(action);
      final all = <QuarterMark>[];
      for (final r in results) {
        final rm = _mapping.asMap(r);
        final qms = _mapping.asList(rm['quarterMarks']);
        for (final q in qms) {
          final qm = QuarterMark.fromJson(_mapping.asMap(q));
          if (qm != null) all.add(qm);
        }
      }

      final uniq = <String, QuarterMark>{};
      for (final m in all) {
        final id = m.objectId ?? '${m.subjectNameRu}:${m.quarter}:${m.quarterMark}:${m.customMark}';
        uniq[id] = m;
      }

      final out = uniq.values.toList()
        ..sort((a, b) {
          final sA = a.subjectNameRu ?? a.subjectNameKg ?? '';
          final sB = b.subjectNameRu ?? b.subjectNameKg ?? '';
          final c = sA.compareTo(sB);
          if (c != 0) return c;
          return (a.quarter ?? 0).compareTo(b.quarter ?? 0);
        });

      await auth.saveToCache(CacheKeys.quarterMarks(), json);
      return ApiResponse.ok(out, message: msg);
    } on DioException catch (e) {
      return ApiResponse.fail(_mapping.mapDioToFailure(e), data: const []);
    } catch (e) {
      return ApiResponse.fail(
        ApiFailure(kind: ApiErrorKind.unknown, title: 'Ошибка', message: e.toString()),
        data: const [],
      );
    }
  }
}
