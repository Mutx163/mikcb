import '../domain/week_calculator.dart';
import '../models/course.dart';

class IcsImportResult {
  final List<Course> courses;
  final DateTime semesterStart;

  const IcsImportResult({required this.courses, required this.semesterStart});
}

class IcsImportService {
  /// Size budget for a picked `.ics` file.
  ///
  /// Same 20 MB as the spreadsheet and unified-transfer import paths, so every
  /// import entry enforces an identical ceiling. An `.ics` is plain text, so
  /// this is far more than any real calendar export needs.
  static const int maxFileBytes = 20 * 1024 * 1024;

  /// RFC 5545 里值为 TEXT 类型的属性 —— 只有这些需要反转义。
  static const Set<String> _icsTextProperties = {
    'SUMMARY',
    'DESCRIPTION',
    'LOCATION',
    'CATEGORIES',
    'COMMENT',
  };

  IcsImportResult parseWakeUpSchedule(String content) {
    final events = _parseEvents(content);
    if (events.isEmpty) {
      return IcsImportResult(courses: const [], semesterStart: DateTime.now());
    }

    final startDates =
        events
            .map((event) => _parseLocalDateTime(event['DTSTART']))
            .whereType<DateTime>()
            .toList()
          ..sort();

    if (startDates.isEmpty) {
      return IcsImportResult(courses: const [], semesterStart: DateTime.now());
    }

    final semesterStart = WeekCalculator.startOfWeek(startDates.first);
    final rawCourses = <Course>[];

    for (final event in events) {
      final course = _buildCourseFromEvent(
        event,
        semesterStart,
        rawCourses.length,
      );
      if (course != null) {
        rawCourses.add(course);
      }
    }

    final courses = _mergeAlternatingWeekCourses(rawCourses);

    return IcsImportResult(courses: courses, semesterStart: semesterStart);
  }

  List<Map<String, String>> _parseEvents(String content) {
    final unfoldedLines = _unfoldLines(content);
    final events = <Map<String, String>>[];
    Map<String, String>? currentEvent;
    var inAlarm = false;

    for (final rawLine in unfoldedLines) {
      final line = rawLine.trim();
      if (line == 'BEGIN:VEVENT') {
        currentEvent = <String, String>{};
        inAlarm = false;
        continue;
      }
      if (line == 'END:VEVENT') {
        if (currentEvent != null) {
          events.add(currentEvent);
        }
        currentEvent = null;
        inAlarm = false;
        continue;
      }
      if (currentEvent == null) {
        continue;
      }
      if (line == 'BEGIN:VALARM') {
        inAlarm = true;
        continue;
      }
      if (line == 'END:VALARM') {
        inAlarm = false;
        continue;
      }
      if (inAlarm || !line.contains(':')) {
        continue;
      }

      final separatorIndex = line.indexOf(':');
      final rawKey = line.substring(0, separatorIndex);
      final key = rawKey.split(';').first;
      final value = line.substring(separatorIndex + 1);

      // RFC 5545 §3.3.11：TEXT 值里的 `\,` `\;` `\:` `\\` `\n` 是转义序列，读进来
      // 必须还原。原先只手工处理了 DESCRIPTION 的 `\n`，其余一律原样入库 ——
      // `SUMMARY:高等数学\, 实验` 的课程名变成 `高等数学\, 实验`（反斜杠留在名字里，
      // 也污染按课程名去重的合并键）。
      //
      // 只对文本类属性反转义：DTSTART/RRULE 的值本身带冒号和分号（`TZID=...:`、
      // `FREQ=WEEKLY;UNTIL=...`），全局反转义会把它们改坏。
      currentEvent.putIfAbsent(
        key,
        () => _icsTextProperties.contains(key) ? unescapeIcsText(value) : value,
      );
    }

    return events;
  }

  /// 还原 RFC 5545 文本转义。
  ///
  /// 逐字符扫描而不是 `replaceAll` 链：`\\,` 表示「一个字面反斜杠 + 一个普通逗号」，
  /// 先替换 `\,` 再替换 `\\` 会把它错解析成「转义反斜杠 + 什么都不剩」，反之则会把
  /// `\,` 二次解释。一趟扫描天然处理正确的优先级。
  String unescapeIcsText(String value) {
    if (!value.contains(r'\')) {
      return value;
    }
    final buffer = StringBuffer();
    var index = 0;
    while (index < value.length) {
      final char = value[index];
      if (char == r'\' && index + 1 < value.length) {
        final next = value[index + 1];
        switch (next) {
          case 'n':
          case 'N':
            buffer.write('\n');
            index += 2;
            continue;
          case ',':
          case ';':
          case ':':
          case r'\':
            buffer.write(next);
            index += 2;
            continue;
        }
      }
      buffer.write(char);
      index += 1;
    }
    return buffer.toString();
  }

  List<String> _unfoldLines(String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    final unfolded = <String>[];

    for (final line in lines) {
      if ((line.startsWith(' ') || line.startsWith('\t')) &&
          unfolded.isNotEmpty) {
        unfolded[unfolded.length - 1] += line.substring(1);
      } else {
        unfolded.add(line);
      }
    }

    return unfolded;
  }

  Course? _buildCourseFromEvent(
    Map<String, String> event,
    DateTime semesterStart,
    int index,
  ) {
    final summary = event['SUMMARY'];
    final description = event['DESCRIPTION'];
    final startDateTime = _parseLocalDateTime(event['DTSTART']);
    final endDateTime = _parseLocalDateTime(event['DTEND']);
    if (summary == null ||
        description == null ||
        startDateTime == null ||
        endDateTime == null) {
      return null;
    }

    // `\n` 已经在 _parseEvents 里由 unescapeIcsText 还原成真换行（连同 `\,` `\;`
    // `\:` `\\`），这里不能再 replaceAll 一次：那会把源文件里 `\\n`（字面反斜杠
    // 后跟字母 n）这份合法内容错误地二次展开成换行。
    final descriptionLines = description
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (descriptionLines.isEmpty) {
      return null;
    }

    // ── 节次：中文「第X-Y节」优先，其次**导出侧自己写的**「Sections: X-Y」──
    //
    // 2026-10-27 修：原先这里只用一条中文正则、且只看 `descriptionLines.first`。
    // 后果是**本 App 导出的 .ics 导不回来** —— `ics_export_service.dart:318` 写的
    // 是 `Sections: ${startSection}-${endSection}`，而且它排在第 2 行
    //（第 1 行是 `Teacher: ...`），两条都不满足，于是整门课被静默丢弃
    // （审计 §3.1 记的就是这条：任何第三方日历 Google / Apple / Outlook 基本都导不进）。
    //
    // 现在：**搜所有行**，并且接受几种常见的写法。仍然要求「有明确节次」才收，
    // 不猜 —— 猜出来的节次会让课表显示在错误的时间格上，比不导入更糟。
    final sectionMatch = _findSectionRange(descriptionLines);
    if (sectionMatch == null) {
      return null;
    }
    final startSection = sectionMatch.startSection;
    final endSection = sectionMatch.endSection;

    // 节次那一行已经用掉了，剩下的行才是教师/地点的候选。
    final contentLines = descriptionLines
        .where((line) => line != sectionMatch.sourceLine)
        .toList();

    // 显式前缀（导出侧就是这种）：`Teacher: 张三` / `教师：张三`。
    final explicitTeacher = _prefixedValue(contentLines, const [
      'teacher',
      'instructor',
      '教师',
      '老师',
    ]);
    final explicitLocation = _prefixedValue(contentLines, const [
      'location',
      'room',
      '地点',
      '教室',
    ]);
    // 本 App 自己的导出会给自由文本也带前缀（`Description:` / `Note:`），
    // 只为把它们从「位置式配对」里排除，并顺手还原到课程字段。
    final explicitDescription = _prefixedValue(contentLines, const [
      'description',
      '简介',
      '描述',
    ]);
    final explicitNote = _prefixedValue(contentLines, const ['note', '备注']);
    // 被前缀行用掉的那些行不再参与位置式配对。
    final pairingLines = contentLines
        .where((line) => !_hasKnownPrefix(line))
        .toList();

    // ⚠️ 这里的下标/阈值是相对**已剔除节次行**的列表算的，与改动前
    //（`descriptionLines` 还含节次行）差一位：
    //   旧：`descriptionLines.length >= 2` 表示「节次 + 至少 1 行」，
    //       `descriptionLines[1]` 是第一行附加信息；
    //   新：`pairingLines.isNotEmpty` 表示同一件事，
    //       `pairingLines[0]` 就是那一行。
    // 2026-10-27 第一版就是漏了这个位移，把中文三行格式的「地点」读成了教师 ——
    // 往返测试当场抓到（`Expected: 'A101' / Actual: '张老师'`）。
    final hasStructuredLocation = pairingLines.isNotEmpty;

    // ICS DESCRIPTION has two known formats after the section line:
    //   Format A: line[0]=location, line[1]=teacher
    //   Format B: line[0]=teacher,   line[1]=location
    // We use the independent LOCATION field from the ICS event as a
    // tie-breaker: whichever description line matches LOCATION is the
    // location line, and the other is the teacher line.
    String rawLocation;
    String teacher;
    if (explicitTeacher != null || explicitLocation != null) {
      // 带前缀的写法不需要猜：缺哪一半就从 LOCATION 字段补。
      final icsLocation = (event['LOCATION'] ?? '').trim();
      // ⚠️ 显式 `Location:` 前缀说明 LOCATION 是**纯地点**（本 App 导出侧就是
      // 这么写的）。这时"没有教师"就是真的没有，不能再从地点串里拆最后一个
      // 词当教师 —— 否则 `Location: 教三-201` 会把教师写成 `教三-201`。
      // 没有 Location 前缀时才保留 WakeUp 的旧口径（LOCATION = 地点 + 教师）。
      teacher =
          explicitTeacher ??
          (explicitLocation != null
              ? ''
              : _extractTeacherFromCombinedLocation(icsLocation));
      rawLocation = explicitLocation ?? icsLocation;
    } else if (!hasStructuredLocation) {
      rawLocation = event['LOCATION'] ?? '';
      teacher = _extractTeacherFromCombinedLocation(rawLocation);
    } else if (pairingLines.length < 2) {
      // Only one extra line — fall back to LOCATION field.
      rawLocation = pairingLines[0];
      teacher = _extractTeacherFromCombinedLocation(event['LOCATION'] ?? '');
    } else {
      final icsLocation = (event['LOCATION'] ?? '').trim();
      final line1 = pairingLines[0].trim();
      final line2 = pairingLines[1].trim();

      final line1MatchesLocation =
          icsLocation.isNotEmpty &&
          (line1.contains(icsLocation) || icsLocation.contains(line1));
      final line2MatchesLocation =
          icsLocation.isNotEmpty &&
          (line2.contains(icsLocation) || icsLocation.contains(line2));

      if (line2MatchesLocation && !line1MatchesLocation) {
        // Format B: line[1]=teacher, line[2]=location
        teacher = line1;
        rawLocation = line2;
      } else {
        // Format A (default): line[1]=location, line[2]=teacher
        rawLocation = line1;
        teacher = line2;
      }
    }
    final rawStartWeek = _weekIndex(startDateTime, semesterStart);
    final rawEndWeek =
        _parseEndWeek(event['RRULE'], semesterStart, startDateTime) ??
        rawStartWeek;
    // Clamp to the same 1..30 range the storage read path already applies
    // (Course.fromJson -> normalizeWeeks), so writing matches reading.
    // Without it a hostile `RRULE:UNTIL=99991231` resolves to ~416k weeks:
    // activeWeeks is an uncomputed getter that materialises every one of
    // them, and the import dedup key joins them into a ~2.4MB string per
    // course, so one file can exhaust memory mid-import.
    final weeks = Course.normalizeWeeks(
      startWeek: rawStartWeek,
      endWeek: rawEndWeek,
    );
    final startWeek = weeks.startWeek;
    final endWeek = weeks.endWeek;
    final weeklyInterval = _parseWeeklyInterval(event['RRULE'] ?? '');
    // INTERVAL=2 means every other week; mark odd/even from the first week.
    final isBiweekly = weeklyInterval == 2;
    final isOddWeek = isBiweekly && startWeek.isOdd;
    final isEvenWeek = isBiweekly && startWeek.isEven;

    return Course(
      id: 'ics-${startDateTime.millisecondsSinceEpoch}-$index',
      name: _cleanSummary(summary),
      teacher: teacher,
      // 显式 `Location:` 是纯地点，不再走「从合并字段里剥掉教师」的旧口径
      //（旧口径按空格切，`教学楼 A101` 会被截成 `教学楼`）。
      location: (hasStructuredLocation || explicitLocation != null)
          ? rawLocation.trim()
          : _extractLocationFromCombinedField(rawLocation),
      description: explicitDescription,
      note: explicitNote,
      dayOfWeek: startDateTime.weekday,
      startSection: startSection,
      endSection: endSection,
      startTime: _formatTime(startDateTime),
      endTime: _formatTime(endDateTime),
      startWeek: startWeek,
      endWeek: endWeek,
      isOddWeek: isOddWeek,
      isEvenWeek: isEvenWeek,
    );
  }

  String _cleanSummary(String summary) {
    return summary.replaceFirst(RegExp(r'\[\d+\]\[[^\]]+\]$'), '').trim();
  }

  /// 从描述行里找出「第几节到第几节」。
  ///
  /// 搜**所有行**（导出侧把节次排在第 2 行），接受这几种写法：
  ///
  /// | 写法 | 谁写的 |
  /// |---|---|
  /// | `第1-2节` / `第 1 - 2 节` | 原 WakeUp 格式 |
  /// | `Sections: 1-2` | **本 App 自己的导出**（`ics_export_service.dart:318`） |
  /// | `Section 1-2` / `Period 1-2` / `Periods: 1-2` | 常见第三方日历手填 |
  ///
  /// 只认「两端都是数字的区间」。找不到就返回 null —— 不猜节次，
  /// 猜错会让课显示在错误的时间格上，比不导入更糟。
  _SectionRange? _findSectionRange(List<String> lines) {
    final patterns = <RegExp>[
      // 中文：`第X-Y节`（允许中间有空格）
      RegExp(r'第\s*(\d+)\s*-\s*(\d+)\s*节'),
      // 导出侧：`Sections: X-Y`（行首、可带 Section/Period 单复数与中英文冒号）
      RegExp(
        r'^\s*(?:sections?|periods?)\s*[:：]\s*(\d+)\s*-\s*(\d+)\s*$',
        caseSensitive: false,
      ),
      // 裸区间 + 节：`1-2节` / `1-2 节`
      RegExp(r'^\s*(\d+)\s*-\s*(\d+)\s*节\s*$'),
      // 英文裸区间：`Period 1-2` / `Section 1-2`
      RegExp(
        r'^\s*(?:section|period)\s+(\d+)\s*-\s*(\d+)\s*$',
        caseSensitive: false,
      ),
    ];
    for (final line in lines) {
      for (final pattern in patterns) {
        final match = pattern.firstMatch(line);
        if (match == null) {
          continue;
        }
        final start = int.tryParse(match.group(1)!);
        final end = int.tryParse(match.group(2)!);
        if (start == null || end == null) {
          continue;
        }
        return _SectionRange(
          startSection: start,
          endSection: end,
          sourceLine: line,
        );
      }
    }
    return null;
  }

  /// `Teacher: 张三` / `教师：张三` 这类带前缀的值；没有就返回 null。
  String? _prefixedValue(List<String> lines, List<String> prefixes) {
    for (final line in lines) {
      final lower = line.toLowerCase();
      for (final prefix in prefixes) {
        final key = prefix.toLowerCase();
        if (!lower.startsWith(key)) {
          continue;
        }
        final rest = line.substring(prefix.length).trimLeft();
        if (!rest.startsWith(':') && !rest.startsWith('：')) {
          continue;
        }
        final value = rest.substring(1).trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  /// 这一行是不是带已知前缀（教师/地点/节次），不该再参与位置式配对。
  bool _hasKnownPrefix(String line) {
    final lower = line.toLowerCase();
    for (final prefix in const [
      'teacher',
      'instructor',
      'location',
      'room',
      'section',
      'period',
      'description',
      'note',
      'session note',
      'homework',
      '教师',
      '老师',
      '地点',
      '教室',
      '简介',
      '描述',
      '备注',
    ]) {
      if (lower.startsWith(prefix.toLowerCase())) {
        final rest = line.substring(prefix.length).trimLeft();
        if (rest.startsWith(':') || rest.startsWith('：')) {
          return true;
        }
      }
    }
    return false;
  }

  List<Course> _mergeAlternatingWeekCourses(List<Course> courses) {
    final grouped = <String, List<Course>>{};
    for (final course in courses) {
      grouped.putIfAbsent(_courseMergeKey(course), () => []).add(course);
    }

    final mergedCourses = <Course>[];
    for (final entry in grouped.entries) {
      final mergedFlags = <String>{};
      final group = List<Course>.from(entry.value)
        ..sort((left, right) {
          final weekCompare = left.startWeek.compareTo(right.startWeek);
          if (weekCompare != 0) {
            return weekCompare;
          }
          return left.id.compareTo(right.id);
        });

      for (var i = 0; i < group.length; i++) {
        final current = group[i];
        if (mergedFlags.contains(current.id)) {
          continue;
        }

        final run = <Course>[current];
        for (var j = i + 1; j < group.length; j++) {
          final candidate = group[j];
          if (mergedFlags.contains(candidate.id)) {
            continue;
          }
          final previous = run.last;
          if (!_isSingleWeekCourse(previous) ||
              !_isSingleWeekCourse(candidate)) {
            break;
          }
          if (candidate.startWeek - previous.startWeek != 2) {
            break;
          }
          if ((candidate.startWeek % 2) != (current.startWeek % 2)) {
            break;
          }
          run.add(candidate);
        }

        if (run.length >= 2 && run.every(_isSingleWeekCourse)) {
          mergedFlags.addAll(run.map((course) => course.id));
          mergedCourses.add(
            current.copyWith(
              startWeek: run.first.startWeek,
              endWeek: run.last.endWeek,
              isOddWeek: run.first.startWeek.isOdd,
              isEvenWeek: run.first.startWeek.isEven,
            ),
          );
          continue;
        }

        mergedFlags.add(current.id);
        mergedCourses.add(current);
      }
    }

    mergedCourses.sort((left, right) {
      final dayCompare = left.dayOfWeek.compareTo(right.dayOfWeek);
      if (dayCompare != 0) {
        return dayCompare;
      }
      final sectionCompare = left.startSection.compareTo(right.startSection);
      if (sectionCompare != 0) {
        return sectionCompare;
      }
      return left.startWeek.compareTo(right.startWeek);
    });
    return mergedCourses;
  }

  String _courseMergeKey(Course course) {
    return [
      course.name,
      course.teacher,
      course.location,
      course.dayOfWeek,
      course.startSection,
      course.endSection,
      course.startTime,
      course.endTime,
      course.shortName ?? '',
      course.note ?? '',
    ].join('|');
  }

  bool _isSingleWeekCourse(Course course) =>
      course.startWeek == course.endWeek &&
      !course.isOddWeek &&
      !course.isEvenWeek;

  String _extractLocationFromCombinedField(String location) {
    final parts = location.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) {
      return location.trim();
    }
    return parts.sublist(0, parts.length - 1).join(' ');
  }

  String _extractTeacherFromCombinedLocation(String location) {
    final parts = location.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return '';
    }
    return parts.last;
  }

  DateTime? _parseLocalDateTime(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{8})T(\d{4,6})(Z)?$').firstMatch(value.trim());
    if (match == null) return null;

    final date = match.group(1)!;
    final time = match.group(2)!;
    final year = int.tryParse(date.substring(0, 4));
    final month = int.tryParse(date.substring(4, 6));
    final day = int.tryParse(date.substring(6, 8));
    final hour = int.tryParse(time.substring(0, 2));
    final minute = int.tryParse(time.substring(2, 4));
    final second = time.length >= 6 ? int.tryParse(time.substring(4, 6)) : 0;
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }

    final isUtc = match.group(3) != null;
    return isUtc
        ? DateTime.utc(year, month, day, hour, minute, second).toLocal()
        : DateTime(year, month, day, hour, minute, second);
  }

  int? _parseEndWeek(
    String? rrule,
    DateTime semesterStart,
    DateTime startDateTime,
  ) {
    if (rrule == null) return null;
    final untilDateTime = _parseUntilDateTime(rrule);
    if (untilDateTime == null) return null;

    final intervalWeeks = _parseWeeklyInterval(rrule);
    final repeatDuration = Duration(
      days: 7 * (intervalWeeks <= 0 ? 1 : intervalWeeks),
    );
    final difference = untilDateTime.difference(startDateTime);
    if (difference.isNegative) {
      return _weekIndex(startDateTime, semesterStart);
    }

    // 这里保持**绝对时长**语义而不是日历日：ICS 的 UNTIL 是一个具体时刻，
    // 「最后一次实例」必须以 `时刻 ≤ UNTIL` 为准。改成日历日跨度会把「UNTIL 当天
    // 早于上课时刻」的那次也算进来（实测多算一周：期望第 5 周得到第 6 周），
    // test/services/ics_import_service_test.dart 的三条钉子正是钉这个边界。
    final occurrenceOffset =
        difference.inMicroseconds ~/ repeatDuration.inMicroseconds;
    final lastOccurrence = startDateTime.add(
      Duration(days: repeatDuration.inDays * occurrenceOffset),
    );
    return _weekIndex(lastOccurrence, semesterStart);
  }

  DateTime? _parseUntilDateTime(String rrule) {
    final dateTimeMatch = RegExp(
      r'UNTIL=(\d{8})T(\d{6})(Z)?',
    ).firstMatch(rrule);
    if (dateTimeMatch != null) {
      final date = dateTimeMatch.group(1)!;
      final time = dateTimeMatch.group(2)!;
      final isUtc = dateTimeMatch.group(3) == 'Z';
      final year = int.parse(date.substring(0, 4));
      final month = int.parse(date.substring(4, 6));
      final day = int.parse(date.substring(6, 8));
      final hour = int.parse(time.substring(0, 2));
      final minute = int.parse(time.substring(2, 4));
      final second = int.parse(time.substring(4, 6));

      return isUtc
          ? DateTime.utc(year, month, day, hour, minute, second).toLocal()
          : DateTime(year, month, day, hour, minute, second);
    }

    final dateMatch = RegExp(r'UNTIL=(\d{8})').firstMatch(rrule);
    if (dateMatch == null) return null;

    final date = dateMatch.group(1)!;
    return DateTime(
      int.parse(date.substring(0, 4)),
      int.parse(date.substring(4, 6)),
      int.parse(date.substring(6, 8)),
    );
  }

  int _parseWeeklyInterval(String rrule) {
    final match = RegExp(r'INTERVAL=(\d+)').firstMatch(rrule);
    return match == null ? 1 : int.tryParse(match.group(1)!) ?? 1;
  }

  int _weekIndex(DateTime date, DateTime semesterStart) {
    final days = WeekCalculator.daysBetween(
      WeekCalculator.startOfWeek(semesterStart),
      WeekCalculator.startOfWeek(date),
    );
    return days ~/ 7 + 1;
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// 从描述里解析出来的节次区间，附带「是哪一行给的」。
///
/// 带上 [sourceLine] 是为了把它从后续的教师/地点候选里剔除：导出侧的
/// `Sections: 1-2` 若留在候选里，会被当成教师或地点写进课程。
class _SectionRange {
  const _SectionRange({
    required this.startSection,
    required this.endSection,
    required this.sourceLine,
  });

  final int startSection;
  final int endSection;
  final String sourceLine;
}
