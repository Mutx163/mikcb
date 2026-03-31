import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';

class AiCourseImportParseResult {
  final List<Course> courses;
  final List<String> warnings;

  const AiCourseImportParseResult({
    required this.courses,
    required this.warnings,
  });

  int get requiredSectionCount => courses.isEmpty
      ? 0
      : courses
          .map((course) => course.endSection)
          .reduce((left, right) => left > right ? left : right);
}

class AiCourseImportService {
  static const String schema = 'mikcb_ai_import_v1';
  static const Set<String> _rootKeys = {'schema', 'courses', 'warnings'};
  static const Set<String> _courseKeys = {
    'name',
    'teacher',
    'location',
    'dayOfWeek',
    'startSection',
    'endSection',
    'customWeeks',
    'courseNature',
    'note',
  };

  static const String prompt = '''
你是轻屿课表的专属视觉解析引擎。你的任务是精准识别课程表截图，并将其转化为严格的 JSON 数据供本地解析。

【核心阅读策略：按列与单元格读取】
图片是一个二维表格。表头是星期（周一至周日），左侧是节次。
你必须严格按照列（星期）逐个单元格进行读取。一个单元格内的一堆换行文字，代表一门课程的完整信息。绝不能跨列合并文字！

【数据结构与输出红线】
你只能输出一个纯粹的 JSON 对象，绝不能包含任何 markdown 标记（如 ```json ）、前言、后语或注释。

{
  "schema": "mikcb_ai_import_v1",
  "courses": [
    {
      "name": "课程名",
      "teacher": "教师",
      "location": "地点",
      "dayOfWeek": 1, 
      "startSection": 1,
      "endSection": 4,
      "customWeeks": [14, 15],
      "courseNature": "required",
      "note": "班级信息"
    }
  ],
  "warnings": []
}

【单元格内容特征与极度严格的提取规则】
强智教务系统的标准单元格包含 5-6 行信息，请按此特征拆解：

1. 课程名称与性质：
   - 提取课程名，丢弃类似 [32]、[48] 的学时数字。
   - 根据 [必修] 或 [选修] 映射到 courseNature ("required" 或 "elective")。

2. 教师姓名：
   - 映射到 teacher。

3. 班级信息（极易混淆区，必须注意）：
   - 类似24软件工程[1-3]班(100)的信息，必须完整放入 note 字段。
   - 绝对禁止把[1-3]班、[3-4]班等带有班字的数字识别为上课节次！如果没有班级信息可填 ""。

4. 周次与节次（核心排雷区）：
   - 通常格式如：14-15(全部)[01-02-03-04节]。前半部分是周次，方括号内带节字的是节次。
   - 周次提取：提取并展开为纯数字升序去重数组 customWeeks。处理规则：(全部)为连续数组，(单)只取奇数，(双)只取偶数。
   - 节次提取（极其严格）：节次必须且只能从明确带有节字的方括号中提取（如 [01-02-03-04节] 提取首尾数字 1 和 4，映射为 startSection 和 endSection）。
   - 再次强调：绝对禁止从学时（如[32]）、班级（如[3-4]班）中提取节次数据！

5. 上课地点：
   - 类似 B201、教学楼101。映射到 location。

【严格约束条件】
1. dayOfWeek：必须通过表头或所在列判断，1-7对应周一至周日。
2. 空值处理：teacher, location, note 无内容时必须填 ""，绝不允许输出 null。
3. 字段限制：courses 内的对象只能包含上述 9 个字段，禁止增减其他字段。
4. 冲突与重叠：多图输入时，同名、同星期、同节次、同地点的课程自动去重。不同星期或节次的同名课程必须拆分为多个对象。如果同一门课出现 1-4 节和 3-4 节，说明你识别错了班级信息，请合并为 1-4 节。
5. 异常处理：如果某门课缺失 dayOfWeek、节次或周次等关键定位信息，不要猜测，不要将其加入 courses，而是将原因写入 warnings 数组中。

准备就绪，请直接输出纯 JSON 数据：
''';

  final Uuid _uuid;

  AiCourseImportService({
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  AiCourseImportParseResult parse(
    String content, {
    required TimetableSettings settings,
  }) {
    final normalized = _normalizeJsonPayload(content);
    final decoded = jsonDecode(normalized);
    if (decoded is! Map) {
      throw const FormatException('AI 结果不是合法对象，请重新复制完整 JSON');
    }

    final json = Map<String, dynamic>.from(decoded);
    _rejectUnknownKeys(
      actualKeys: json.keys,
      allowedKeys: _rootKeys,
      targetName: '根对象',
    );

    final currentSchema = _readRequiredString(json, 'schema');
    if (currentSchema != schema) {
      throw FormatException('schema 必须为 $schema');
    }

    final rawCourses = json['courses'];
    if (rawCourses is! List) {
      throw const FormatException('courses 必须是数组');
    }

    final rawWarnings = json['warnings'];
    if (rawWarnings != null && rawWarnings is! List) {
      throw const FormatException('warnings 必须是字符串数组');
    }

    final warnings = (rawWarnings as List<dynamic>? ?? const [])
        .map((item) {
          if (item is! String) {
            throw const FormatException('warnings 中的每一项都必须是字符串');
          }
          return item.trim();
        })
        .where((item) => item.isNotEmpty)
        .toList();

    final courses = <Course>[];
    for (var i = 0; i < rawCourses.length; i++) {
      final item = rawCourses[i];
      if (item is! Map) {
        throw FormatException('courses[$i] 不是合法对象');
      }
      courses.add(
        _parseCourse(
          Map<String, dynamic>.from(item),
          index: i,
          settings: settings,
        ),
      );
    }

    return AiCourseImportParseResult(
      courses: courses,
      warnings: warnings,
    );
  }

  Course _parseCourse(
    Map<String, dynamic> json, {
    required int index,
    required TimetableSettings settings,
  }) {
    _rejectUnknownKeys(
      actualKeys: json.keys,
      allowedKeys: _courseKeys,
      targetName: 'courses[$index]',
    );

    final rawName = _readRequiredString(json, 'name').trim();
    final name = _normalizeCourseName(rawName);
    if (name.isEmpty) {
      throw FormatException('courses[$index].name 不能为空');
    }

    final teacher = _readOptionalString(json, 'teacher');
    final location = _readOptionalString(json, 'location');
    final note = _readOptionalString(json, 'note');

    final dayOfWeek = _readRequiredInt(json, 'dayOfWeek');
    if (dayOfWeek < 1 || dayOfWeek > 7) {
      throw FormatException('courses[$index].dayOfWeek 必须是 1-7');
    }

    final startSection = _readRequiredInt(json, 'startSection');
    final endSection = _readRequiredInt(json, 'endSection');
    if (startSection < 1) {
      throw FormatException('courses[$index].startSection 必须大于等于 1');
    }
    if (endSection < startSection) {
      throw FormatException(
        'courses[$index].endSection 不能小于 startSection',
      );
    }

    final customWeeks = _readRequiredWeekList(
      json,
      'customWeeks',
      itemName: 'courses[$index].customWeeks',
    );
    if (customWeeks.isEmpty) {
      throw FormatException('courses[$index].customWeeks 不能为空');
    }

    final courseNatureValue =
        _readOptionalString(json, 'courseNature').trim().toLowerCase();
    final courseNature = _resolveCourseNature(
      courseNatureValue,
      rawName: rawName,
      index: index,
    );

    final startTime = startSection <= settings.sectionCount
        ? settings.sections[startSection - 1].startTime
        : '00:00';
    final endTime = endSection <= settings.sectionCount
        ? settings.sections[endSection - 1].endTime
        : '00:00';

    return Course(
      id: 'ai-${_uuid.v4()}',
      name: name,
      teacher: teacher,
      location: location,
      dayOfWeek: dayOfWeek,
      startSection: startSection,
      endSection: endSection,
      startTime: startTime,
      endTime: endTime,
      startWeek: customWeeks.first,
      endWeek: customWeeks.last,
      customWeeks: customWeeks,
      courseNature: courseNature,
      note: note.isEmpty ? null : note,
    );
  }

  String _normalizeJsonPayload(String content) {
    var normalized = content.trim();
    if (normalized.startsWith('\uFEFF')) {
      normalized = normalized.substring(1).trimLeft();
    }

    if (normalized.startsWith('```')) {
      final lines = normalized.split(RegExp(r'\r?\n'));
      if (lines.isNotEmpty && lines.first.trim().startsWith('```')) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.trim() == '```') {
        lines.removeLast();
      }
      normalized = lines.join('\n').trim();
    }

    final firstBrace = normalized.indexOf('{');
    final lastBrace = normalized.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      normalized = normalized.substring(firstBrace, lastBrace + 1).trim();
    }

    return normalized;
  }

  void _rejectUnknownKeys({
    required Iterable<String> actualKeys,
    required Set<String> allowedKeys,
    required String targetName,
  }) {
    final unknownKeys = actualKeys.where((key) => !allowedKeys.contains(key));
    if (unknownKeys.isNotEmpty) {
      throw FormatException(
        '$targetName 包含不支持的字段：${unknownKeys.join('、')}',
      );
    }
  }

  String _readRequiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw FormatException('$key 必须是字符串');
    }
    return value;
  }

  String _readOptionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return '';
    }
    if (value is! String) {
      throw FormatException('$key 必须是字符串');
    }
    return value;
  }

  int _readRequiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    final parsed = _readInt(value);
    if (parsed == null) {
      throw FormatException('$key 必须是整数');
    }
    return parsed;
  }

  List<int> _readRequiredWeekList(
    Map<String, dynamic> json,
    String key, {
    required String itemName,
  }) {
    final value = json[key];
    final weeks = <int>{};

    if (value is List) {
      for (final item in value) {
        if (item is String) {
          weeks.addAll(_parseWeekExpression(item, itemName: itemName));
          continue;
        }
        final parsed = _readInt(item);
        if (parsed == null || parsed < 1) {
          throw FormatException('$itemName 只能包含大于等于 1 的整数');
        }
        weeks.add(parsed);
      }
    } else if (value is String) {
      weeks.addAll(_parseWeekExpression(value, itemName: itemName));
    } else {
      throw FormatException('$key 必须是整数数组或周次字符串');
    }

    final sorted = weeks.toList()..sort();
    return sorted;
  }

  List<int> _parseWeekExpression(
    String raw, {
    required String itemName,
  }) {
    var normalized = raw.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    normalized = normalized
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'\[[^\]]*节\]'), '')
        .replaceAll(RegExp(r'【[^】]*节】'), '');

    final modeMatch =
        RegExp(r'[（(](全部|单|双)[）)]').firstMatch(normalized)?.group(1);
    normalized = normalized.replaceAll(RegExp(r'[（(][^）)]*[）)]'), '');

    final result = <int>{};
    final parts = normalized.split(RegExp(r'[，,、]'));
    for (final part in parts) {
      final token = part.trim();
      if (token.isEmpty) {
        continue;
      }
      final rangeMatch = RegExp(r'^(\d+)-(\d+)$').firstMatch(token);
      if (rangeMatch != null) {
        final start = int.parse(rangeMatch.group(1)!);
        final end = int.parse(rangeMatch.group(2)!);
        if (start > end) {
          throw FormatException('$itemName 周次范围不合法');
        }
        for (var week = start; week <= end; week++) {
          result.add(week);
        }
        continue;
      }

      final parsed = int.tryParse(token);
      if (parsed == null || parsed < 1) {
        throw FormatException('$itemName 含有无法识别的周次：$token');
      }
      result.add(parsed);
    }

    final weeks = result.toList()..sort();
    if (modeMatch == '单') {
      return weeks.where((week) => week.isOdd).toList();
    }
    if (modeMatch == '双') {
      return weeks.where((week) => week.isEven).toList();
    }
    return weeks;
  }

  String _normalizeCourseName(String rawName) {
    return rawName.replaceAll(RegExp(r'(\[(?:\d+|必修|选修)\])+$'), '').trim();
  }

  CourseNature _resolveCourseNature(
    String courseNatureValue, {
    required String rawName,
    required int index,
  }) {
    switch (courseNatureValue) {
      case '':
        return _inferCourseNatureFromName(rawName);
      case 'required':
      case '必修':
        return CourseNature.required;
      case 'elective':
      case '选修':
        return CourseNature.elective;
      default:
        throw FormatException(
          'courses[$index].courseNature 只能是 required 或 elective',
        );
    }
  }

  CourseNature _inferCourseNatureFromName(String rawName) {
    if (rawName.contains('[选修]')) {
      return CourseNature.elective;
    }
    return CourseNature.required;
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value == value.toInt() ? value.toInt() : null;
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}
