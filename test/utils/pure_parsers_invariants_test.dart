import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/import_export_logic.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/warehouse_macro_models.dart';
import 'package:university_timetable/services/warehouse_import_session_log.dart';
import 'package:university_timetable/services/week_expression_parser.dart';
import 'package:university_timetable/utils/clock_time.dart';

/// 属性/随机测试（2026-10-02 审查第 8 轮）：把几个"解析 + 归一 + 脱敏"的纯函数
/// 用随机与恶意输入过一遍，只断言它们**自己文档里写下的不变量**，不引入新口径。
///
/// 为什么走这条路而不是再加一条单点用例：这几处是全仓唯一直接吃"用户/远端给的
/// 任意字符串"的入口（教务页面 URL、WebView 日志里的 URL、周次表达式、钟点串），
/// 单点用例想不全；而它们的返回又会被写进 SharedPreferences、导入去重键与
/// 用户导出发给维护者的日志文本里。
void main() {
  Course course(
    String id, {
    String name = '高等数学',
    String teacher = '张老师',
    String location = 'A101',
    int dayOfWeek = 1,
    int startSection = 1,
    int endSection = 2,
    int startWeek = 1,
    int endWeek = 16,
    List<int>? customWeeks,
  }) => Course(
    id: id,
    name: name,
    teacher: teacher,
    location: location,
    dayOfWeek: dayOfWeek,
    startSection: startSection,
    endSection: endSection,
    startTime: '08:00',
    endTime: '09:40',
    startWeek: startWeek,
    endWeek: endWeek,
    customWeeks: customWeeks,
  );

  group('ClockTime 解析不变量', () {
    test('随机串不抛异常，解析出来就能原样往返', () {
      final random = Random(20261002);
      const alphabet = '0123456789: ;amAMP.x/\\-–\t\n';
      for (var i = 0; i < 4000; i++) {
        final length = random.nextInt(9);
        final buffer = StringBuffer();
        for (var c = 0; c < length; c++) {
          buffer.write(alphabet[random.nextInt(alphabet.length)]);
        }
        final raw = buffer.toString();
        final parsed = ClockTime.tryParse(raw);
        if (parsed == null) {
          continue;
        }
        expect(parsed.totalMinutes, inInclusiveRange(0, 23 * 60 + 59));
        expect(ClockTime.tryParse(parsed.formatted)?.totalMinutes, parsed.totalMinutes,
            reason: '$raw → ${parsed.formatted} 不能往返');
      }
    });

    test('allowEndOfDay 只多放行 24:00 这一个值', () {
      final random = Random(7);
      for (var i = 0; i < 2000; i++) {
        final hour = random.nextInt(30);
        final minute = random.nextInt(70);
        final raw = '${hour.toString().padLeft(2, '0')}:'
            '${minute.toString().padLeft(2, '0')}';
        final strict = ClockTime.tryParse(raw);
        final lenient = ClockTime.tryParse(raw, allowEndOfDay: true);
        if (raw == '24:00') {
          expect(strict, isNull);
          expect(lenient?.totalMinutes, 24 * 60);
        } else {
          expect(lenient?.totalMinutes, strict?.totalMinutes, reason: raw);
        }
      }
    });
  });

  group('Course.normalizeWeekList 不变量', () {
    test('随机周表：只留 1..maxWeek、去重升序、超长整条作废', () {
      final random = Random(11);
      for (var i = 0; i < 3000; i++) {
        final length = random.nextInt(40);
        final weeks = List<int>.generate(
          length,
          (_) => random.nextInt(80) - 20,
        );
        final maxWeek = 1 + random.nextInt(30);
        final normalized = Course.normalizeWeekList(weeks, maxWeek: maxWeek);
        if (weeks.every((week) => week < 1 || week > maxWeek)) {
          expect(normalized, isNull, reason: '全越界应归 null：$weeks');
          continue;
        }
        expect(normalized, isNotNull);
        expect(normalized!.length, lessThanOrEqualTo(weeks.toSet().length));
        expect(normalized, orderedEquals(normalized.toList()..sort()));
        expect(normalized.toSet().length, normalized.length);
        for (final week in normalized) {
          expect(week, inInclusiveRange(1, maxWeek));
        }
      }
    });

    test('超过 maxWeekListEntries 的输入一律拒绝，避免任意大的列表进键与展开', () {
      expect(
        Course.normalizeWeekList(
          List<int>.generate(Course.maxWeekListEntries + 1, (i) => (i % 30) + 1),
        ),
        isNull,
      );
      expect(
        Course.normalizeWeekList(
          List<int>.generate(Course.maxWeekListEntries, (i) => (i % 30) + 1),
        ),
        isNotNull,
      );
    });
  });

  group('周次表达式解析不变量', () {
    test('随机脏输入不抛异常，返回值都落在学期内且去重升序', () {
      final random = Random(23);
      const pieces = [
        '1-5', '2', '3,7', '单', '双', '(单)', '(双)', '1-40', '0', '-3',
        '1..4', 'abc', '第(3)节', '1-2-3', ' ', ',', '-', '（单）', '9999',
        '1-5;6', '1周-3周', '(1-2)',
      ];
      for (var i = 0; i < 4000; i++) {
        final raw = List<String>.generate(
          1 + random.nextInt(4),
          (_) => pieces[random.nextInt(pieces.length)],
        ).join(random.nextBool() ? ',' : ' ');
        final semesterWeekCount = 1 + random.nextInt(25);
        final warnings = <String>[];
        late List<int> weeks;
        try {
          weeks = WeekExpressionParser.parse(
            raw,
            itemName: 'fuzz',
            semesterWeekCount: semesterWeekCount,
            warnings: warnings,
          );
        } on FormatException {
          // 明确的"畸形输入"异常是本函数的契约（导入侧要拿它报错），不算违反不变量。
          continue;
        }
        for (final week in weeks) {
          expect(week, inInclusiveRange(1, semesterWeekCount), reason: raw);
        }
        expect(weeks.toSet().length, weeks.length, reason: raw);
        expect(weeks, orderedEquals(weeks.toList()..sort()), reason: raw);
      }
    });
  });

  group('导入去重键', () {
    test('同课同键，改任一身份字段就换键', () {
      final base = course('c1');
      expect(buildImportedCourseDedupKey(base), buildImportedCourseDedupKey(base));
      // 只有 id 参与"是不是同一门课"的判断之外，改名/改教师/改地点/改星期/
      // 改节次/改周次都必须换键，否则两条不同安排会被去重吞掉一条。
      final variants = <Course>[
        course('c1', name: '大学英语'),
        course('c1', teacher: '李老师'),
        course('c1', location: 'B202'),
        course('c1', dayOfWeek: 3),
        course('c1', startSection: 5, endSection: 6),
        course('c1', endSection: 3),
        course('c1', startWeek: 2),
        course('c1', endWeek: 12),
        course('c1', customWeeks: const [1, 3, 5]),
      ];
      final baseKey = buildImportedCourseDedupKey(base);
      for (final variant in variants) {
        expect(
          buildImportedCourseDedupKey(variant),
          isNot(baseKey),
          reason: '${variant.id} 的字段变化没有换键，会被去重吞掉',
        );
      }
    });

    test('随机课表：去重后不再有重复键', () {
      final random = Random(31);
      for (var round = 0; round < 300; round++) {
        final courses = <Course>[];
        for (var i = 0; i < 6; i++) {
          courses.add(
            course(
              'c$i',
              name: ['高等数学', '大学英语', '体育'][random.nextInt(3)],
              teacher: '老师${random.nextInt(2)}',
              location: random.nextBool() ? 'A101' : 'B202',
              dayOfWeek: 1 + random.nextInt(7),
              startSection: 1 + random.nextInt(3),
              endSection: 1 + random.nextInt(3) + 1,
              startWeek: 1 + random.nextInt(3),
            ),
          );
        }
        final deduped = dedupeImportedCourses(courses);
        final keys = deduped.map(buildImportedCourseDedupKey).toList();
        expect(keys.toSet().length, keys.length);
      }
    });
  });

  group('URL 脱敏不变量', () {
    test('会话类参数无论大小写/前缀都必须被剥掉，正常业务参数保留', () {
      const sessionish = <String>[
        'JSESSIONID',
        'jsessionid',
        'sid',
        'sessionid',
        'sessionId',
        'PHPSESSID',
        'ASP.NET_SessionId',
        'access_token',
        'refresh_token',
        'SSO_TOKEN',
        'wt_ticket',
        'ticket',
        'state',
        'nonce',
      ];
      const secret = 'SESS3cr3tValue';
      for (final name in sessionish) {
        final raw = 'https://jwrs.example.edu.cn/kb/x.html?$name=$secret&keep=1';
        final script = sanitizeWarehouseScriptPageUrl(raw);
        final logged = sanitizeWarehouseLogUrl(raw);
        expect(script, isNotNull, reason: name);
        expect(script, isNot(contains(secret)), reason: '$name 的值泄漏进保存的 URL');
        expect(script, contains('keep=1'), reason: '$name 时业务参数被误删');
        expect(
          logged,
          isNot(contains(secret)),
          reason: '$name 的值泄漏进导出的日志文本',
        );
      }
    });

    test('路径里的 ;jsessionid= 与 userinfo 凭据都不留下', () {
      const raw = 'https://user:pass@jw.example.edu.cn;jsessionid=ABC123DEF/servlet/'
          'Show?xh=2023123456';
      final script = sanitizeWarehouseScriptPageUrl(raw)!;
      expect(script, isNot(contains('jsessionid')));
      expect(script, isNot(contains('ABC123DEF')));
      expect(script, isNot(contains('user:pass')));
      expect(sanitizeWarehouseLogUrl(raw), isNot(contains('user:pass')));
    });

    test('随机脏串只可能返回空或合法 http(s) 绝对地址，且绝不带上 query 里的凭据', () {
      final random = Random(97);
      const alphabet = "htps:/?&=;#@% .-_abc0123456789\\\"'";
      for (var i = 0; i < 3000; i++) {
        final length = random.nextInt(40);
        final buffer = StringBuffer();
        for (var c = 0; c < length; c++) {
          buffer.write(alphabet[random.nextInt(alphabet.length)]);
        }
        final raw = buffer.toString();
        final logged = sanitizeWarehouseLogUrl(raw);
        final script = sanitizeWarehouseScriptPageUrl(raw);
        expect(() => Uri.parse(logged), returnsNormally, reason: raw);
        if (script != null) {
          expect(() => Uri.parse(script), returnsNormally, reason: raw);
          final parsed = Uri.parse(script);
          expect(parsed.scheme, anyOf('http', 'https'), reason: '$raw → $script');
          expect(parsed.userInfo, isEmpty, reason: '$raw → $script');
        }
      }
    });
  });
}
