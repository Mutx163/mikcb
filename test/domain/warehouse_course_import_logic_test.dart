import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/warehouse_course_import_logic.dart';
import 'package:university_timetable/models/course.dart';

List<Course> _parse(List<dynamic> items) =>
    WarehouseCourseImportLogic.parse(
      items,
      idFactory: _nextId,
      unknownTeacher: '未知教师',
      unknownLocation: '未知地点',
    );

int _seq = 0;
String _nextId() => 'id-${_seq++}';

void main() {
  setUp(() => _seq = 0);

  group('warehouseSemesterStartDate', () {
    test('归一到本地零点，丢掉时刻部分', () {
      final d = warehouseSemesterStartDate('2026-09-07T08:30:00Z');
      expect(d, DateTime(2026, 9, 7));
      expect(d!.hour, 0);
    });

    test('UTC 带 Z 时只取日历日，不被时区推走一天', () {
      // 2026-09-07T00:00Z 在 UTC+8 是 08:00 同日；若按 UTC 瞬间处理再转本地，
      // 某些时区会退到前一天，周次起始日随之错一天。
      final d = warehouseSemesterStartDate('2026-09-07T00:00:00Z');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 9);
      expect(d.day, 7);
    });

    test('接受 H:mm 补零与 ISO 日期', () {
      expect(warehouseSemesterStartDate('2026-9-7'), DateTime(2026, 9, 7));
      expect(warehouseSemesterStartDate('2026-09-07'), DateTime(2026, 9, 7));
    });

    test('兼容空格分隔的非 ISO 写法', () {
      expect(
        warehouseSemesterStartDate('2026-09-07 08:00'),
        DateTime(2026, 9, 7),
      );
    });

    test('空值与垃圾输入返回 null（保持原值，不清空）', () {
      expect(warehouseSemesterStartDate(null), isNull);
      expect(warehouseSemesterStartDate(''), isNull);
      expect(warehouseSemesterStartDate('   '), isNull);
      expect(warehouseSemesterStartDate('not-a-date'), isNull);
    });

    group('越界日期必须拒绝，不能让 DateTime 静默进位', () {
      // DateTime 会把 2026-13-45 归一化成 2027-02-14。开学日期是全 App 算
      // 「第几周」的唯一输入，进位等于把整个学期的周次算错。
      test('月份越界返回 null', () {
        expect(warehouseSemesterStartDate('2026-13-01'), isNull);
        expect(warehouseSemesterStartDate('2026-00-01'), isNull);
        expect(warehouseSemesterStartDate('2026-13-45'), isNull);
      });

      test('日期越界返回 null（含不存在的 2 月 30 日）', () {
        expect(warehouseSemesterStartDate('2026-02-30'), isNull);
        expect(warehouseSemesterStartDate('2026-04-31'), isNull);
        expect(warehouseSemesterStartDate('2026-09-31'), isNull);
      });

      test('非 ISO 写法的越界值同样被拒', () {
        expect(warehouseSemesterStartDate('2026-13-45 08:00'), isNull);
        expect(warehouseSemesterStartDate('2026-02-30 08:00'), isNull);
      });

      test('单位月日的非 ISO 写法（DateTime 解析不了的那条分支）也要拦', () {
        // `2026-13-7` / `2026-9-7 08:00` 走的是回退分支，不经 tryParse，
        // 越界值若不在这条分支上拦，就是个只对一半输入生效的检查。
        expect(warehouseSemesterStartDate('2026-13-7'), isNull);
        expect(warehouseSemesterStartDate('2026-9-7 08:00'), DateTime(2026, 9, 7));
        expect(warehouseSemesterStartDate('2026-2-30'), isNull);
        expect(warehouseSemesterStartDate('2026-4-31 08:00'), isNull);
        expect(warehouseSemesterStartDate('2026-0-7'), isNull);
        expect(warehouseSemesterStartDate('2026-9-0'), isNull);
      });

      test('合法边界日期照常通过（不能误伤）', () {
        expect(warehouseSemesterStartDate('2026-02-28'), DateTime(2026, 2, 28));
        expect(warehouseSemesterStartDate('2024-02-29'), DateTime(2024, 2, 29));
        expect(warehouseSemesterStartDate('2026-01-31'), DateTime(2026, 1, 31));
        expect(warehouseSemesterStartDate('2026-12-31'), DateTime(2026, 12, 31));
        expect(warehouseSemesterStartDate('2026-09-07 08:00'),
            DateTime(2026, 9, 7));
      });
    });
  });

  group('warehouseUnsupportedCourseConfigKeys', () {
    test('列出的三项正是本 App 无处安放的上游字段', () {
      expect(
        warehouseUnsupportedCourseConfigKeys,
        containsAll(<String>[
          'firstDayOfWeek',
          'defaultClassDuration',
          'defaultBreakDuration',
        ]),
      );
    });
  });

  group('normalizeClock', () {
    test('accepts HH:mm and H:mm', () {
      expect(WarehouseCourseImportLogic.normalizeClock('08:20'), '08:20');
      expect(WarehouseCourseImportLogic.normalizeClock('8:05'), '08:05');
    });

    test('tolerates whitespace and a trailing seconds part', () {
      expect(WarehouseCourseImportLogic.normalizeClock(' 09:15 '), '09:15');
      expect(WarehouseCourseImportLogic.normalizeClock('10:30:00'), '10:30');
    });

    test('rejects garbage and out-of-range values', () {
      expect(WarehouseCourseImportLogic.normalizeClock(null), isNull);
      expect(WarehouseCourseImportLogic.normalizeClock(''), isNull);
      expect(WarehouseCourseImportLogic.normalizeClock('abc'), isNull);
      expect(WarehouseCourseImportLogic.normalizeClock('25:00'), isNull);
      expect(WarehouseCourseImportLogic.normalizeClock('08:99'), isNull);
      expect(WarehouseCourseImportLogic.normalizeClock('0800'), isNull);
    });

    test('分钟一位两位都收（8:05 与 8:5 不该一个成一个否）', () {
      // 此前只接受两位分钟：'8:05' 通过而 '8:5' 被拒，这种不对称对调用方
      // 毫无意义，而适配脚本确实会发短写法。
      expect(WarehouseCourseImportLogic.normalizeClock('8:5'), '08:05');
      expect(WarehouseCourseImportLogic.normalizeClock('07:5'), '07:05');
      expect(WarehouseCourseImportLogic.normalizeClock('8:05'), '08:05');
      expect(WarehouseCourseImportLogic.normalizeClock('08:05'), '08:05');
      expect(WarehouseCourseImportLogic.normalizeClock('8:0'), '08:00');
    });

    test('整串锚定：多出来的数字不再被悄悄截断', () {
      // 分钟放宽到 1–2 位之后，未锚定的 `^(\d{1,2}):(\d{1,2})` 会把
      // '8:555' 读成 08:55。被误读的钟点比被拒的钟点更糟：拒了会退回模板
      // 时间，误读了会被存下来。
      expect(WarehouseCourseImportLogic.normalizeClock('8:555'), isNull);
      expect(WarehouseCourseImportLogic.normalizeClock('08:05:0'), isNull);
      expect(WarehouseCourseImportLogic.normalizeClock('08:05am'), isNull);
      expect(WarehouseCourseImportLogic.normalizeClock('08:05:000'), isNull);
      // 秒段照旧只取前两位丢掉——App 只存 HH:mm，这与 '10:30:00' → '10:30'
      // 是同一条规则，只是现在要求秒段真的是两位。
      expect(WarehouseCourseImportLogic.normalizeClock('08:05:00'), '08:05');
      expect(WarehouseCourseImportLogic.normalizeClock('8:5:30'), '08:05');
    });
  });

  group('parse', () {
    test('keeps a normal course unchanged (no custom time)', () {
      final courses = _parse([
        {
          'name': '机械控制工程',
          'teacher': '芦玉琴',
          'position': 'A主215',
          'day': 4,
          'startSection': 1,
          'endSection': 4,
          'weeks': [7, 11],
        },
      ]);
      expect(courses, hasLength(1));
      final c = courses.single;
      expect(c.name, '机械控制工程');
      expect(c.startSection, 1);
      expect(c.endSection, 4);
      expect(c.startTime, '');
      expect(c.endTime, '');
      expect(c.hasCustomTime, isFalse);
      expect(c.customWeeks, [7, 11]);
    });

    test('早读：没有节次但有真实钟点 —— 过去会被整条丢弃，现在保留', () {
      final courses = _parse([
        {
          'name': '早读',
          'teacher': '张三',
          'position': 'A主101',
          'day': 1,
          'weeks': [1, 2, 3],
          'isCustomTime': true,
          'customStartTime': '07:30',
          'customEndTime': '08:00',
        },
      ]);
      // 关键回归：以前 startSection/endSection 缺失 → 直接 continue，课凭空消失。
      expect(courses, hasLength(1));
      final c = courses.single;
      expect(c.hasCustomTime, isTrue);
      expect(c.startTime, '07:30');
      expect(c.endTime, '08:00');
      // 无节次可落位，固定占第 1 节，显示位置是第 1 节但钟点用真实值。
      expect(c.startSection, 1);
      expect(c.endSection, 1);
    });

    test('带节次 + 自定义钟点（永川「其他教学楼」第 1-4 节）', () {
      final courses = _parse([
        {
          'name': '工装夹具设计及应用课程设计',
          'teacher': '付世强',
          'position': 'A综204',
          'day': 5,
          'startSection': 1,
          'endSection': 4,
          'weeks': [11, 12],
          'isCustomTime': true,
          'customStartTime': '08:20',
          'customEndTime': '12:00',
        },
      ]);
      expect(courses, hasLength(1));
      final c = courses.single;
      expect(c.hasCustomTime, isTrue);
      expect(c.startTime, '08:20');
      expect(c.endTime, '12:00');
      expect(c.startSection, 1);
      expect(c.endSection, 4);
    });

    test('没有 isCustomTime 但给了钟点，也能推断出来', () {
      final courses = _parse([
        {
          'name': '连堂实验',
          'day': 2,
          'weeks': [5],
          'customStartTime': '13:00',
          'customEndTime': '16:40',
        },
      ]);
      expect(courses.single.hasCustomTime, isTrue);
      expect(courses.single.endTime, '16:40');
    });

    test('isCustomTime=true 但钟点非法 → 当作无自定义时间处理', () {
      final courses = _parse([
        {
          'name': '坏数据',
          'day': 2,
          'startSection': 1,
          'endSection': 2,
          'weeks': [1],
          'isCustomTime': true,
          'customStartTime': 'oops',
          'customEndTime': '',
        },
      ]);
      expect(courses.single.hasCustomTime, isFalse);
      expect(courses.single.startTime, '');
    });

    test('isCustomTime=false 即使给了钟点也不采纳', () {
      final courses = _parse([
        {
          'name': '显式关闭',
          'day': 2,
          'startSection': 1,
          'endSection': 2,
          'weeks': [1],
          'isCustomTime': false,
          'customStartTime': '08:20',
          'customEndTime': '10:00',
        },
      ]);
      expect(courses.single.hasCustomTime, isFalse);
    });

    test('既无节次又无钟点 → 仍然丢弃（无据可依）', () {
      final courses = _parse([
        {
          'name': '无信息',
          'day': 2,
          'weeks': [1],
        },
      ]);
      expect(courses, isEmpty);
    });

    test('缺 name / day / weeks 仍然丢弃', () {
      final courses = _parse([
        {'day': 1, 'startSection': 1, 'endSection': 1, 'weeks': [1]},
        {
          'name': 'x',
          'startSection': 1,
          'endSection': 1,
          'weeks': [1],
        },
        {
          'name': 'y',
          'day': 1,
          'startSection': 1,
          'endSection': 1,
        },
      ]);
      expect(courses, isEmpty);
    });

    test('position 缺失时回退 location，再回退占位文案', () {
      final courses = _parse([
        {
          'name': 'a',
          'day': 1,
          'startSection': 1,
          'endSection': 1,
          'weeks': [1],
          'location': 'B303',
        },
        {
          'name': 'b',
          'day': 1,
          'startSection': 1,
          'endSection': 1,
          'weeks': [1],
        },
      ]);
      expect(courses[0].location, 'B303');
      expect(courses[1].location, '未知地点');
    });

    test('周次去重排序并丢弃越界值', () {
      final courses = _parse([
        {
          'name': 'w',
          'day': 1,
          'startSection': 1,
          'endSection': 1,
          'weeks': [5, 1, 5, 999, 0, -2],
        },
      ]);
      expect(courses.single.customWeeks, [1, 5]);
    });

    test('非 Map 记录被跳过而不影响其余', () {
      final courses = _parse([
        'garbage',
        42,
        null,
        {
          'name': 'ok',
          'day': 1,
          'startSection': 1,
          'endSection': 1,
          'weeks': [1],
        },
      ]);
      expect(courses, hasLength(1));
      expect(courses.single.name, 'ok');
    });

    test('空数组返回空列表', () {
      expect(_parse([]), isEmpty);
    });

    group('脏数据不得毁掉整次导入', () {
      // 适配脚本是 JavaScript：周次常被序列化成字符串，布尔常写成 1/0。
      // 以前这两处是裸强转（`item as num`、`x as bool?`），一个脏元素就抛错，
      // 而 parse 是整批的唯一入口 —— 抛错意味着同一批其他课程一门都导不进来。
      test('weeks 传字符串照样解析', () {
        final courses = _parse([
          {
            'name': '大学英语',
            'day': 1,
            'startSection': 1,
            'endSection': 2,
            'weeks': ['1', '2', 3],
          },
        ]);
        expect(courses.single.customWeeks, [1, 2, 3]);
      });

      test('isCustomTime 传 1/0 照样解析', () {
        final courses = _parse([
          {
            'name': '早读',
            'day': 1,
            'weeks': [1, 2],
            'isCustomTime': 1,
            'customStartTime': '07:30',
            'customEndTime': '08:00',
          },
          {
            'name': '正课',
            'day': 2,
            'startSection': 1,
            'endSection': 2,
            'weeks': [1],
            'isCustomTime': 0,
          },
        ]);
        expect(courses, hasLength(2));
        expect(courses[0].hasCustomTime, isTrue);
        expect(courses[1].hasCustomTime, isFalse);
      });

      test('day / 节次传字符串也解析', () {
        final courses = _parse([
          {
            'name': '体育',
            'day': '3',
            'startSection': '5',
            'endSection': '6',
            'weeks': ['1'],
          },
        ]);
        expect(courses.single.dayOfWeek, 3);
        expect(courses.single.startSection, 5);
        expect(courses.single.endSection, 6);
      });

      test('一条脏数据只丢脏的那部分，同批其他课程全部保留', () {
        final courses = _parse([
          {
            'name': '正常课',
            'day': 1,
            'startSection': 1,
            'endSection': 2,
            'weeks': [1, 2],
          },
          {
            'name': '周次里有非数字',
            'day': 2,
            'startSection': 1,
            'endSection': 2,
            'weeks': [1, 'x', {'bad': 1}],
          },
          {
            'name': '另一门正常课',
            'day': 3,
            'startSection': 3,
            'endSection': 4,
            'weeks': [3],
          },
        ]);
        // 三门都在：中间那门只是把无法解析的周次丢掉，仍留下可用的第 1 周 ——
        // 宽容丢掉脏元素，好过整条丢弃。
        expect(courses.map((c) => c.name),
            ['正常课', '周次里有非数字', '另一门正常课']);
        expect(courses[1].customWeeks, [1]);
      });

      test('weeks 不是数组时按缺资料丢弃该条，不影响其余', () {
        final courses = _parse([
          {'name': '坏的', 'day': 1, 'startSection': 1, 'endSection': 1},
          {
            'name': '好的',
            'day': 2,
            'startSection': 1,
            'endSection': 1,
            'weeks': [1],
          },
        ]);
        expect(courses.map((c) => c.name), ['好的']);
      });

      test('weeks 传标量或字典也不抛错', () {
        expect(
          () => _parse([
            {'name': 'a', 'day': 1, 'startSection': 1, 'endSection': 1, 'weeks': 3},
            {
              'name': 'b',
              'day': 1,
              'startSection': 1,
              'endSection': 1,
              'weeks': {'1': true},
            },
          ]),
          returnsNormally,
        );
      });

      test('position 传数字也不抛错', () {
        final courses = _parse([
          {
            'name': '地点是数字',
            'day': 1,
            'startSection': 1,
            'endSection': 1,
            'weeks': [1],
            'position': 215,
          },
        ]);
        expect(courses.single.location, '215');
      });
    });

    group('时间倒挂必须被拒（审核第 11 条）', () {
      test('结束早于开始 → 不采纳自定义时间，回落模板', () {
        final courses = _parse([
          {
            'name': '晚到早退的课',
            'day': 2,
            'startSection': 1,
            'endSection': 2,
            'weeks': [1],
            'isCustomTime': true,
            'customStartTime': '18:00',
            'customEndTime': '07:00',
          },
        ]);
        // 倒挂时间会让「正在上课」判断永不命中、闹钟不响，且在课表上看不出来。
        // 拒掉自定义时间后这门课退回模板时间：看起来普通，但至少是自洽的。
        expect(courses.single.hasCustomTime, isFalse);
        expect(courses.single.startTime, '');
        expect(courses.single.endTime, '');
      });

      test('结束等于开始同样不可用', () {
        final courses = _parse([
          {
            'name': '零长度',
            'day': 2,
            'startSection': 1,
            'endSection': 1,
            'weeks': [1],
            'isCustomTime': true,
            'customStartTime': '08:20',
            'customEndTime': '08:20',
          },
        ]);
        expect(courses.single.hasCustomTime, isFalse);
      });

      test('正常区间不受影响', () {
        final courses = _parse([
          {
            'name': '正常连堂',
            'day': 2,
            'startSection': 1,
            'endSection': 4,
            'weeks': [1],
            'isCustomTime': true,
            'customStartTime': '08:20',
            'customEndTime': '12:10',
          },
        ]);
        expect(courses.single.hasCustomTime, isTrue);
        expect(courses.single.startTime, '08:20');
        expect(courses.single.endTime, '12:10');
      });

      test('只给了一端钟点 → 不算自定义时间', () {
        final courses = _parse([
          {
            'name': '只有起点',
            'day': 2,
            'startSection': 1,
            'endSection': 2,
            'weeks': [1],
            'customStartTime': '08:20',
          },
        ]);
        expect(courses.single.hasCustomTime, isFalse);
      });
    });

    group('courseNature（必修/选修）', () {
      Course parseOne(Object? nature) => _parse([
            {
              'name': '大学英语',
              'day': 1,
              'startSection': 1,
              'endSection': 2,
              'weeks': [1, 2],
              'courseNature': ?nature,
            },
          ]).single;

      test('选修被如实保留（上游 CQUET 从课程名 [选修] 提取后下发）', () {
        expect(parseOne('elective').courseNature, CourseNature.elective);
      });

      test('必修被如实保留', () {
        expect(parseOne('required').courseNature, CourseNature.required);
      });

      test('字段缺省时按必修处理（与旧行为一致）', () {
        expect(parseOne(null).courseNature, CourseNature.required);
      });

      test('未知取值不得把课变成选修 —— 静默误标会污染学分统计', () {
        // statistics_service 按 CourseNature.required 累计必修学分。
        // 若把解析失败默认成 elective（或 elective），用户的必修学分会凭空少掉。
        expect(parseOne('必选').courseNature, CourseNature.required);
        expect(parseOne('').courseNature, CourseNature.required);
        expect(parseOne('ELECTIVE').courseNature, CourseNature.required);
      });

      test('不与自定义钟点互相干扰', () {
        final courses = _parse([
          {
            'name': '早读英语[选修]',
            'day': 1,
            'weeks': [1, 2, 3],
            'isCustomTime': true,
            'customStartTime': '07:30',
            'customEndTime': '08:00',
            'courseNature': 'elective',
          },
        ]);
        final c = courses.single;
        expect(c.courseNature, CourseNature.elective);
        expect(c.hasCustomTime, isTrue);
        expect(c.startTime, '07:30');
      });
    });

    group('onSkip：少了课必须说得出来', () {
      // Why this group exists: `parse` swallowing a bad record is right (one
      // dirty course must not cost the user the whole batch) but it must not be
      // *silent* — the original complaint about this funnel was a course that
      // simply was not on the timetable with nothing saying why.
      ({List<Course> courses, List<(WarehouseCourseSkipReason, String?)> skips})
          parseWithSkips(List<dynamic> items) {
        final skips = <(WarehouseCourseSkipReason, String?)>[];
        final courses = WarehouseCourseImportLogic.parse(
          items,
          idFactory: _nextId,
          unknownTeacher: '未知教师',
          unknownLocation: '未知地点',
          onSkip: (reason, name) => skips.add((reason, name)),
        );
        return (courses: courses, skips: skips);
      }

      Map<WarehouseCourseSkipReason, int> tally(
        List<(WarehouseCourseSkipReason, String?)> skips,
      ) {
        final counts = <WarehouseCourseSkipReason, int>{};
        for (final (reason, _) in skips) {
          counts.update(reason, (n) => n + 1, ifAbsent: () => 1);
        }
        return counts;
      }

      test('正常批次一条都不报', () {
        final result = parseWithSkips([
          {
            'name': '高数',
            'day': 1,
            'startSection': 1,
            'endSection': 2,
            'weeks': [1, 2],
          },
        ]);
        expect(result.courses, hasLength(1));
        expect(result.skips, isEmpty);
      });

      test('既无节次又无钟点 → unusable，并带上课程名', () {
        final result = parseWithSkips([
          {'name': '没有落点', 'day': 1, 'weeks': [1]},
        ]);
        expect(result.courses, isEmpty);
        expect(result.skips, [
          (WarehouseCourseSkipReason.unusable, '没有落点'),
        ]);
      });

      test('非 Map 记录 → malformed，名字取不到就是 null', () {
        final result = parseWithSkips(['不是对象', 42]);
        expect(result.courses, isEmpty);
        expect(tally(result.skips), {WarehouseCourseSkipReason.malformed: 2});
        expect(result.skips.every((s) => s.$2 == null), isTrue);
      });

      test('周次里有非数字 → 课还在，但报 partialWeeks', () {
        final result = parseWithSkips([
          {
            'name': '周次不干净',
            'day': 1,
            'startSection': 1,
            'endSection': 2,
            'weeks': [1, 'abc', 5],
          },
        ]);
        expect(result.courses, hasLength(1));
        expect(result.courses.single.customWeeks, [1, 5]);
        expect(result.skips, [
          (WarehouseCourseSkipReason.partialWeeks, '周次不干净'),
        ]);
      });

      test('周次里越界的值被削掉也要报（否则学生会以为那几周没课）', () {
        final result = parseWithSkips([
          {
            'name': '越界周次',
            'day': 1,
            'startSection': 1,
            'endSection': 2,
            'weeks': [1, 9999],
          },
        ]);
        expect(tally(result.skips),
            {WarehouseCourseSkipReason.partialWeeks: 1});
      });

      test('重复周次不算被削 —— 重复不丢任何东西', () {
        final result = parseWithSkips([
          {
            'name': '重复周次',
            'day': 1,
            'startSection': 1,
            'endSection': 2,
            'weeks': [1, 1, 2],
          },
        ]);
        expect(result.courses.single.customWeeks, [1, 2]);
        expect(result.skips, isEmpty);
      });

      test('整条丢掉与周次被削分开计，前端要分开说', () {
        final result = parseWithSkips([
          {'name': '整条没了', 'day': 1, 'weeks': [1]},
          {
            'name': '削了周次',
            'day': 1,
            'startSection': 1,
            'endSection': 2,
            'weeks': [1, 'x'],
          },
        ]);
        expect(tally(result.skips), {
          WarehouseCourseSkipReason.unusable: 1,
          WarehouseCourseSkipReason.partialWeeks: 1,
        });
      });

      test('一条脏记录不影响同批其他课，且脏的那条会被点名', () {
        final result = parseWithSkips([
          {
            'name': '好的',
            'day': 1,
            'startSection': 1,
            'endSection': 2,
            'weeks': [1, 2],
          },
          {'name': '坏的', 'day': 1, 'weeks': []},
        ]);
        expect(result.courses.map((c) => c.name), ['好的']);
        expect(result.skips, [
          (WarehouseCourseSkipReason.unusable, '坏的'),
        ]);
      });
    });
  });
}
