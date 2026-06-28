import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/lan_edit_host.dart';
import 'package:university_timetable/services/lan_edit_server_service.dart';
import 'package:university_timetable/services/lan_edit_session.dart';
import 'package:university_timetable/services/spreadsheet_import_service.dart';

class _FakeLanEditHost implements LanEditHost {
  @override
  final List<Course> courses = [];
  TimetableSettings settings = TimetableSettings.defaults();
  @override
  int currentWeek = 3;
  bool throwOnUpdate = false;

  @override
  String? get activeProfileName => '测试课表';

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<Course> createCourse(Course draft) async {
    courses.add(draft);
    return draft;
  }

  @override
  Future<void> deleteCourse(String courseId) async {
    courses.removeWhere((course) => course.id == courseId);
  }

  @override
  Future<List<Course>> replaceCourseGroup({
    required String? originalName,
    required List<Course> slots,
  }) async {
    if (slots.isEmpty) {
      throw ArgumentError('至少需要保留一个上课时间段');
    }
    final trimmedOriginal = originalName?.trim();
    if (trimmedOriginal != null && trimmedOriginal.isNotEmpty) {
      courses.removeWhere((course) => course.name == trimmedOriginal);
    }
    courses.addAll(slots);
    return slots;
  }

  @override
  Course? findCourse(String id) {
    for (final course in courses) {
      if (course.id == id) {
        return course;
      }
    }
    return null;
  }

  @override
  Future<void> updateCourse(Course course) async {
    if (throwOnUpdate) {
      throw ArgumentError('所选时间模板节次数不足，无法覆盖第 1-2 节');
    }
    final index = courses.indexWhere((item) => item.id == course.id);
    if (index != -1) {
      courses[index] = course;
    }
  }

  @override
  String buildProfileBackupJson() => jsonEncode({
        'app': 'mikcb',
        'schemaVersion': 1,
        'courses': courses.map((course) => course.toJson()).toList(),
        'settings': settings.toJson(),
        'currentWeek': currentWeek,
      });

  @override
  Future<void> importProfileBackupJson(String content) async {}

  @override
  Future<int> importMergeBackupJson(String content) async {
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    final raw = decoded['courses'] as List<dynamic>? ?? [];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        courses.add(Course.fromJson(item));
      } else if (item is Map) {
        courses.add(Course.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return raw.length;
  }

  @override
  Future<int> deleteCoursesBatch(List<String> courseIds) async {
    var removed = 0;
    for (final id in courseIds) {
      final before = courses.length;
      courses.removeWhere((course) => course.id == id);
      if (courses.length < before) {
        removed += 1;
      }
    }
    return removed;
  }

  @override
  Map<String, dynamic> buildMetaJson() => {
        'profileName': activeProfileName,
        'currentWeek': currentWeek,
        'semesterWeekCount': settings.semesterWeekCount,
        'sectionCount': settings.sectionCount,
        'sections': settings.sections.map((section) => section.toJson()).toList(),
        'presetColors': const ['#2196F3'],
      };

  @override
  int get semesterWeekCount => settings.semesterWeekCount;

  @override
  TimetableSettings get timetableSettings => settings;

  @override
  Future<int> importSpreadsheetCourses(
    SpreadsheetImportResult result, {
    required bool replaceExisting,
  }) async {
    if (replaceExisting) {
      courses
        ..clear()
        ..addAll(result.courses);
    } else {
      courses.addAll(result.courses);
    }
    return result.courses.length;
  }

  @override
  Future<void> setCurrentWeek(int week) async {
    currentWeek = week;
  }
}

Future<_HttpClientResponse> _request({
  required int port,
  required String method,
  required String path,
  String? token,
  String? body,
}) async {
  final client = HttpClient();
  final request = await client.openUrl(
    method,
    Uri.parse('http://127.0.0.1:$port$path'),
  );
  if (token != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(body);
  }
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  client.close(force: true);
  return _HttpClientResponse(response.statusCode, responseBody);
}

class _HttpClientResponse {
  final int statusCode;
  final String body;

  _HttpClientResponse(this.statusCode, this.body);
}

class _SequenceRandom implements Random {
  final List<int> values;
  int index = 0;

  _SequenceRandom(this.values);

  @override
  int nextInt(int max) {
    final value = values[index.clamp(0, values.length - 1)];
    index += 1;
    return value % max;
  }

  @override
  double nextDouble() => nextInt(1000) / 1000.0;

  @override
  bool nextBool() => nextInt(2) == 0;
}

void main() {
  test('LanEditSession verifies PIN and token', () {
    final session = LanEditSession.create(
      random: _SequenceRandom([123456, 1, 2, 3]),
    );
    expect(session.pin, '223456');
    expect(session.verifyPin('000000', '127.0.0.1'), isFalse);
    expect(session.verifyPin(session.pin, '127.0.0.1'), isTrue);
    expect(session.verifyToken(session.token), isTrue);
    expect(session.verifyToken('bad'), isFalse);
  });

  test('server exposes auth and course CRUD on loopback', () async {
    final host = _FakeLanEditHost();
    final session = LanEditSession.create(
      random: _SequenceRandom([234567, 1, 2, 3]),
    );
    final server = LanEditServerService();
    await server.start(host: host, session: session);

    try {
      final health = await _request(
        port: server.port!,
        method: 'GET',
        path: '/api/v1/health',
      );
      expect(health.statusCode, 200);

      final unauthorized = await _request(
        port: server.port!,
        method: 'GET',
        path: '/api/v1/courses',
      );
      expect(unauthorized.statusCode, 401);

      final verify = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/auth/verify',
        body: jsonEncode({'pin': session.pin}),
      );
      expect(verify.statusCode, 200);
      final token =
          (jsonDecode(verify.body) as Map<String, dynamic>)['token'] as String;

      final create = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/courses',
        token: token,
        body: jsonEncode({
          'name': '高等数学',
          'teacher': '张教授',
          'location': '教301',
          'dayOfWeek': 1,
          'startSection': 1,
          'endSection': 2,
          'startWeek': 1,
          'endWeek': 16,
        }),
      );
      expect(create.statusCode, 201);
      final courseId =
          (jsonDecode(create.body) as Map<String, dynamic>)['id'] as String;

      final list = await _request(
        port: server.port!,
        method: 'GET',
        path: '/api/v1/courses',
        token: token,
      );
      expect(list.statusCode, 200);
      final courses =
          (jsonDecode(list.body) as Map<String, dynamic>)['courses'] as List;
      expect(courses, hasLength(1));

      final patch = await _request(
        port: server.port!,
        method: 'PATCH',
        path: '/api/v1/courses/$courseId',
        token: token,
        body: jsonEncode({'location': '教302'}),
      );
      expect(patch.statusCode, 200);
      expect(host.courses.single.location, '教302');

      final delete = await _request(
        port: server.port!,
        method: 'DELETE',
        path: '/api/v1/courses/$courseId',
        token: token,
      );
      expect(delete.statusCode, 200);
      expect(host.courses, isEmpty);

      final listAfterDelete = await _request(
        port: server.port!,
        method: 'GET',
        path: '/api/v1/courses',
        token: token,
      );
      expect(listAfterDelete.statusCode, 200);
      final remaining =
          (jsonDecode(listAfterDelete.body) as Map<String, dynamic>)['courses']
              as List;
      expect(remaining, isEmpty);
    } finally {
      await server.stop();
    }
  });

  test('server replaces course group atomically', () async {
    final host = _FakeLanEditHost();
    host.courses.addAll([
      Course(
        id: 'slot-a',
        name: '高等数学',
        teacher: '张教授',
        location: '教301',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        color: '#2196F3',
        startWeek: 1,
        endWeek: 16,
      ),
      Course(
        id: 'slot-b',
        name: '高等数学',
        teacher: '张教授',
        location: '教301',
        dayOfWeek: 3,
        startSection: 3,
        endSection: 4,
        startTime: '10:00',
        endTime: '11:40',
        color: '#2196F3',
        startWeek: 1,
        endWeek: 16,
      ),
    ]);
    final session = LanEditSession.create(
      random: _SequenceRandom([345678, 1, 2, 3]),
    );
    final server = LanEditServerService();
    await server.start(host: host, session: session);

    try {
      final verify = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/auth/verify',
        body: jsonEncode({'pin': session.pin}),
      );
      final token =
          (jsonDecode(verify.body) as Map<String, dynamic>)['token'] as String;

      final replace = await _request(
        port: server.port!,
        method: 'PUT',
        path: '/api/v1/courses/group',
        token: token,
        body: jsonEncode({
          'originalName': '高等数学',
          'slots': [
            {
              'id': 'slot-a',
              'name': '高等数学',
              'teacher': '张教授',
              'location': '教302',
              'dayOfWeek': 1,
              'startSection': 1,
              'endSection': 2,
              'startWeek': 1,
              'endWeek': 16,
            },
            {
              'name': '高等数学',
              'teacher': '张教授',
              'location': '教302',
              'dayOfWeek': 5,
              'startSection': 1,
              'endSection': 2,
              'startWeek': 1,
              'endWeek': 16,
            },
          ],
        }),
      );
      expect(replace.statusCode, 200);
      expect(host.courses, hasLength(2));
      expect(host.courses.any((course) => course.id == 'slot-b'), isFalse);
      expect(host.courses.every((course) => course.location == '教302'), isTrue);
    } finally {
      await server.stop();
    }
  });

  test('encodeLanEditUrl appends pin query param', () {
    expect(
      encodeLanEditUrl(host: '192.168.1.5', port: 52841, pin: '482913'),
      'http://192.168.1.5:52841/?pin=482913',
    );
    expect(
      encodeLanEditUrl(
        host: '192.168.1.5',
        port: 52841,
        pin: '482913',
        token: 'abc/def',
      ),
      'http://192.168.1.5:52841/?token=abc%2Fdef&pin=482913',
    );
  });

  test('ICS-imported course ids support GET PATCH and DELETE', () async {
    final host = _FakeLanEditHost();
    const icsCourseId = 'ics-1772756400000-40';
    host.courses.add(
      Course(
        id: icsCourseId,
        name: 'ICS 导入课程',
        teacher: '李老师',
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        startWeek: 1,
        endWeek: 16,
        isOddWeek: true,
      ),
    );
    final session = LanEditSession.create(
      random: _SequenceRandom([456789, 1, 2, 3]),
    );
    final server = LanEditServerService();
    await server.start(host: host, session: session);

    try {
      final verify = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/auth/verify',
        body: jsonEncode({'pin': session.pin}),
      );
      final token =
          (jsonDecode(verify.body) as Map<String, dynamic>)['token'] as String;

      final getCourse = await _request(
        port: server.port!,
        method: 'GET',
        path: '/api/v1/courses/$icsCourseId',
        token: token,
      );
      expect(getCourse.statusCode, 200);
      expect(
        (jsonDecode(getCourse.body) as Map<String, dynamic>)['id'],
        icsCourseId,
      );

      final patch = await _request(
        port: server.port!,
        method: 'PATCH',
        path: '/api/v1/courses/$icsCourseId',
        token: token,
        body: jsonEncode({'location': 'B202'}),
      );
      expect(patch.statusCode, 200);
      expect(host.courses.single.location, 'B202');

      final delete = await _request(
        port: server.port!,
        method: 'DELETE',
        path: '/api/v1/courses/$icsCourseId',
        token: token,
      );
      expect(delete.statusCode, 200);
      expect(host.courses, isEmpty);
    } finally {
      await server.stop();
    }
  });

  test('PATCH returns 400 when provider rejects course update', () async {
    final host = _FakeLanEditHost()..throwOnUpdate = true;
    const icsCourseId = 'ics-123-1';
    host.courses.add(
      Course(
        id: icsCourseId,
        name: '冲突课程',
        teacher: '',
        location: '',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
      ),
    );
    final session = LanEditSession.create(
      random: _SequenceRandom([567890, 1, 2, 3]),
    );
    final server = LanEditServerService();
    await server.start(host: host, session: session);

    try {
      final verify = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/auth/verify',
        body: jsonEncode({'pin': session.pin}),
      );
      final token =
          (jsonDecode(verify.body) as Map<String, dynamic>)['token'] as String;

      final patch = await _request(
        port: server.port!,
        method: 'PATCH',
        path: '/api/v1/courses/$icsCourseId',
        token: token,
        body: jsonEncode({'location': 'B202'}),
      );
      expect(patch.statusCode, 400);
      final body = jsonDecode(patch.body) as Map<String, dynamic>;
      expect(body['error'], 'invalid_request');
      expect(body['message'], contains('节次数不足'));
      expect(server.isRunning, isTrue);
    } finally {
      await server.stop();
    }
  });

  test('favicon request returns 204 without 404 noise', () async {
    final host = _FakeLanEditHost();
    final session = LanEditSession.create(
      random: _SequenceRandom([678901, 1, 2, 3]),
    );
    final server = LanEditServerService();
    await server.start(host: host, session: session);

    try {
      final response = await _request(
        port: server.port!,
        method: 'GET',
        path: '/favicon.ico',
      );
      expect(response.statusCode, 204);
      expect(response.body, isEmpty);
    } finally {
      await server.stop();
    }
  });

  test('spreadsheet import accepts mikcb CSV', () async {
    final host = _FakeLanEditHost();
    final session = LanEditSession.create(
      random: _SequenceRandom([456789, 1, 2, 3]),
    );
    final server = LanEditServerService();
    await server.start(host: host, session: session);

    const csv = '''# mikcb-course-import-v1
课程名,星期,开始节,结束节,上课周
测试课,2,1,2,1-4
''';

    try {
      final verify = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/auth/verify',
        body: jsonEncode({'pin': session.pin}),
      );
      final token =
          (jsonDecode(verify.body) as Map<String, dynamic>)['token'] as String;

      final response = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/import/spreadsheet',
        token: token,
        body: jsonEncode({
          'fileName': 'courses.csv',
          'contentBase64': base64Encode(utf8.encode(csv)),
          'replaceExisting': true,
        }),
      );
      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['importedCount'], 1);
      expect(host.courses, hasLength(1));
      expect(host.courses.single.name, '测试课');
    } finally {
      await server.stop();
    }
  });

  test('week expression parse returns weeks', () async {
    final host = _FakeLanEditHost();
    final session = LanEditSession.create(
      random: _SequenceRandom([567890, 1, 2, 3]),
    );
    final server = LanEditServerService();
    await server.start(host: host, session: session);

    try {
      final verify = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/auth/verify',
        body: jsonEncode({'pin': session.pin}),
      );
      final token =
          (jsonDecode(verify.body) as Map<String, dynamic>)['token'] as String;

      final response = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/week-expression/parse',
        token: token,
        body: jsonEncode({
          'expression': '1-3、5',
          'itemName': '高等数学',
        }),
      );
      expect(response.statusCode, 200);
      final weeks =
          (jsonDecode(response.body) as Map<String, dynamic>)['weeks'] as List;
      expect(weeks, [1, 2, 3, 5]);
    } finally {
      await server.stop();
    }
  });

  test('PATCH session updates current week', () async {
    final host = _FakeLanEditHost();
    final session = LanEditSession.create(
      random: _SequenceRandom([678012, 1, 2, 3]),
    );
    final server = LanEditServerService();
    await server.start(host: host, session: session);

    try {
      final verify = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/auth/verify',
        body: jsonEncode({'pin': session.pin}),
      );
      final token =
          (jsonDecode(verify.body) as Map<String, dynamic>)['token'] as String;

      final response = await _request(
        port: server.port!,
        method: 'PATCH',
        path: '/api/v1/session',
        token: token,
        body: jsonEncode({'currentWeek': 7}),
      );
      expect(response.statusCode, 200);
      expect(host.currentWeek, 7);
    } finally {
      await server.stop();
    }
  });

  test('course group save applies weekExpression', () async {
    final host = _FakeLanEditHost();
    final session = LanEditSession.create(
      random: _SequenceRandom([789123, 1, 2, 3]),
    );
    final server = LanEditServerService();
    await server.start(host: host, session: session);

    try {
      final verify = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/auth/verify',
        body: jsonEncode({'pin': session.pin}),
      );
      final token =
          (jsonDecode(verify.body) as Map<String, dynamic>)['token'] as String;

      final response = await _request(
        port: server.port!,
        method: 'PUT',
        path: '/api/v1/courses/group',
        token: token,
        body: jsonEncode({
          'slots': [
            {
              'name': '表达式课',
              'dayOfWeek': 1,
              'startSection': 1,
              'endSection': 2,
              'weekExpression': '1-2、4',
            },
          ],
        }),
      );
      expect(response.statusCode, 200);
      expect(host.courses.single.customWeeks, [1, 2, 4]);
    } finally {
      await server.stop();
    }
  });

  test('merge import adds courses without clearing existing', () async {
    final host = _FakeLanEditHost();
    host.courses.add(
      Course(
        id: 'keep-me',
        name: '保留课',
        teacher: '',
        location: '',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 1,
        startTime: '08:00',
        endTime: '08:45',
        color: '#2196F3',
        startWeek: 1,
        endWeek: 16,
      ),
    );
    final session = LanEditSession.create(
      random: _SequenceRandom([890234, 1, 2, 3]),
    );
    final server = LanEditServerService();
    await server.start(host: host, session: session);

    try {
      final verify = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/auth/verify',
        body: jsonEncode({'pin': session.pin}),
      );
      final token =
          (jsonDecode(verify.body) as Map<String, dynamic>)['token'] as String;

      final mergePayload = jsonEncode({
        'app': 'mikcb',
        'schemaVersion': 1,
        'courses': [
          {
            'id': 'new-1',
            'name': '合并新课',
            'teacher': '',
            'location': '',
            'dayOfWeek': 2,
            'startSection': 1,
            'endSection': 2,
            'startTime': '08:00',
            'endTime': '09:30',
            'color': '#4CAF50',
            'startWeek': 1,
            'endWeek': 16,
          },
        ],
      });

      final response = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/import/merge',
        token: token,
        body: mergePayload,
      );
      expect(response.statusCode, 200);
      expect(host.courses, hasLength(2));
      expect(host.courses.any((c) => c.id == 'keep-me'), isTrue);
      expect(host.courses.any((c) => c.name == '合并新课'), isTrue);
    } finally {
      await server.stop();
    }
  });

  test('batch delete removes multiple courses', () async {
    final host = _FakeLanEditHost();
    host.courses.addAll([
      Course(
        id: 'a',
        name: 'A',
        teacher: '',
        location: '',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 1,
        startTime: '08:00',
        endTime: '08:45',
        color: '#2196F3',
        startWeek: 1,
        endWeek: 16,
      ),
      Course(
        id: 'b',
        name: 'B',
        teacher: '',
        location: '',
        dayOfWeek: 2,
        startSection: 1,
        endSection: 1,
        startTime: '08:00',
        endTime: '08:45',
        color: '#2196F3',
        startWeek: 1,
        endWeek: 16,
      ),
    ]);
    final session = LanEditSession.create(
      random: _SequenceRandom([901345, 1, 2, 3]),
    );
    final server = LanEditServerService();
    await server.start(host: host, session: session);

    try {
      final verify = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/auth/verify',
        body: jsonEncode({'pin': session.pin}),
      );
      final token =
          (jsonDecode(verify.body) as Map<String, dynamic>)['token'] as String;

      final response = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/courses/batch-delete',
        token: token,
        body: jsonEncode({'ids': ['a', 'b']}),
      );
      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['deletedCount'], 2);
      expect(host.courses, isEmpty);
    } finally {
      await server.stop();
    }
  });

  test('PIN verify returns 429 after repeated failures', () async {
    final host = _FakeLanEditHost();
    final session = LanEditSession.create(
      random: _SequenceRandom([345678, 1, 2, 3]),
    );
    final server = LanEditServerService();
    await server.start(host: host, session: session);

    try {
      for (var i = 0; i < LanEditSession.maxPinAttemptsPerIp; i++) {
        final response = await _request(
          port: server.port!,
          method: 'POST',
          path: '/api/v1/auth/verify',
          body: jsonEncode({'pin': '000000'}),
        );
        expect(response.statusCode, 401);
      }

      final blocked = await _request(
        port: server.port!,
        method: 'POST',
        path: '/api/v1/auth/verify',
        body: jsonEncode({'pin': session.pin}),
      );
      expect(blocked.statusCode, 429);
    } finally {
      await server.stop();
    }
  });
}
