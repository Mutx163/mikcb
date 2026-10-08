import 'dart:convert';

import '../l10n/app_localizations.dart';
import '../l10n/course_week_localizations.dart';

enum CourseNature { required, elective }

extension CourseNatureX on CourseNature {
  String get value => switch (this) {
    CourseNature.required => 'required',
    CourseNature.elective => 'elective',
  };

  static CourseNature fromValue(String? value) {
    return CourseNature.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CourseNature.required,
    );
  }
}

/// Per-occurrence (single week) note for a course schedule entry.
class CourseSessionNote {
  static const Object _unset = Object();

  final String text;
  final bool hasHomework;

  const CourseSessionNote({this.text = '', this.hasHomework = false});

  bool get isEmpty => text.trim().isEmpty && !hasHomework;

  bool get isNotEmpty => !isEmpty;

  String get trimmedText => text.trim();

  CourseSessionNote? get normalizedOrNull {
    final trimmed = trimmedText;
    if (trimmed.isEmpty && !hasHomework) {
      return null;
    }
    return CourseSessionNote(text: trimmed, hasHomework: hasHomework);
  }

  Map<String, dynamic> toJson() {
    return {'text': text, 'hasHomework': hasHomework};
  }

  factory CourseSessionNote.fromJson(Map<String, dynamic> json) {
    return CourseSessionNote(
      text: (json['text'] as String?) ?? '',
      hasHomework: json['hasHomework'] as bool? ?? false,
    );
  }

  CourseSessionNote copyWith({Object? text = _unset, bool? hasHomework}) {
    return CourseSessionNote(
      text: identical(text, _unset) ? this.text : text as String,
      hasHomework: hasHomework ?? this.hasHomework,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CourseSessionNote &&
        other.text == text &&
        other.hasHomework == hasHomework;
  }

  @override
  int get hashCode => Object.hash(text, hasHomework);
}

class Course {
  static const Object _unset = Object();

  final String id;
  final String name;
  final String? shortName;
  final String teacher;
  final String location;
  final int dayOfWeek; // 1-7, Monday-Sunday
  final int startSection; // 开始节次
  final int endSection; // 结束节次
  final String startTime; // 格式: HH:mm
  final String endTime; // 格式: HH:mm
  final String color; // 课程颜色
  final String? textColor; // 课程卡片文字颜色（hex），为空表示跟随全局设置
  final int startWeek; // 开始周次
  final int endWeek; // 结束周次
  final bool isOddWeek; // 是否单周
  final bool isEvenWeek; // 是否双周
  final List<int>? customWeeks; // 自定义周次
  final List<int>? suspendedWeeks; // 停课周次
  final CourseNature courseNature; // 课程性质
  final String? description; // 课程简介（同名课程共享）
  /// Legacy per-entry free text. Prefer [description] for shared course intro;
  /// kept for import/back-compat. UI should not write new values here.
  final String? note;

  /// Per-week session notes keyed by teaching week (1-based).
  final Map<int, CourseSessionNote>? sessionNotes;
  final String? timeSchemeIdOverride; // 课程级时间模板覆盖

  /// True when [startTime]/[endTime] carry an adapter-supplied clock range that
  /// must win over the time scheme.
  ///
  /// 教务适配脚本可对不对应编号节次的时段（早读、实验连堂等）下发真实钟点，此时
  /// 时间不能由时间模板按节次反推。
  ///
  /// 不能用「startTime 非空」来判断：历史存档里 startTime/endTime 可能残留早已
  /// 与模板不同步的旧钟点（见 provider 注释「绝不能退回 Course.startTime 存量值」），
  /// 以非空为准会把旧数据误当成自定义时间。
  final bool hasCustomTime;

  Course({
    required this.id,
    required this.name,
    this.shortName,
    required this.teacher,
    required this.location,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
    required this.startTime,
    required this.endTime,
    this.color = '#2196F3',
    this.textColor,
    this.startWeek = 1,
    this.endWeek = 16,
    this.isOddWeek = false,
    this.isEvenWeek = false,
    this.customWeeks,
    this.suspendedWeeks,
    this.courseNature = CourseNature.required,
    this.description,
    this.note,
    this.sessionNotes,
    this.timeSchemeIdOverride,
    this.hasCustomTime = false,
  });

  /// Clamps [dayOfWeek] to Monday–Sunday (1–7).
  static int normalizeDayOfWeek(int dayOfWeek) {
    if (dayOfWeek < 1) {
      return 1;
    }
    if (dayOfWeek > 7) {
      return 7;
    }
    return dayOfWeek;
  }

  /// Clamps section indexes so both stay in range and end >= start.
  static ({int startSection, int endSection}) normalizeSections({
    required int startSection,
    required int endSection,
    int maxSection = 24,
  }) {
    final safeMaxSection = maxSection < 1 ? 1 : maxSection;
    final normalizedStart = startSection.clamp(1, safeMaxSection);
    final normalizedEnd = endSection.clamp(normalizedStart, safeMaxSection);
    return (startSection: normalizedStart, endSection: normalizedEnd);
  }

  /// Clamps week range so both stay in range and end >= start.
  static ({int startWeek, int endWeek}) normalizeWeeks({
    required int startWeek,
    required int endWeek,
    int maxWeek = 30,
  }) {
    final safeMaxWeek = maxWeek < 1 ? 1 : maxWeek;
    final normalizedStart = startWeek.clamp(1, safeMaxWeek);
    final normalizedEnd = endWeek.clamp(normalizedStart, safeMaxWeek);
    return (startWeek: normalizedStart, endWeek: normalizedEnd);
  }

  /// 周次数量级上限：钳制后最多 `maxWeek` 项，任何远超该量级的列表都只会是
  /// 畸形/被灌入的外部数据，不做无界遍历。
  static const int maxWeekListEntries = 512;

  /// 周次列表归一：丢弃越界项、去重、升序。与 [normalizeWeeks] 同口径。
  ///
  /// 必须在解析与消费两侧都钳：`activeWeeks` 会原样吐出 customWeeks，而导入去重键
  /// （import_export_logic 的 `weeks.join(',')`）与按周展开都遍历它。此前
  /// startWeek/endWeek 走 normalizeWeeks 被夹到 1..30，customWeeks/suspendedWeeks
  /// 却是裸列表，一份备份就能塞进任意多个/任意大的周次值。
  static List<int>? normalizeWeekList(List<int>? weeks, {int maxWeek = 30}) {
    if (weeks == null || weeks.isEmpty || weeks.length > maxWeekListEntries) {
      return null;
    }
    final safeMaxWeek = maxWeek < 1 ? 1 : maxWeek;
    final normalized = <int>{};
    for (final week in weeks) {
      if (week < 1 || week > safeMaxWeek) {
        continue;
      }
      normalized.add(week);
    }
    if (normalized.isEmpty) {
      return null;
    }
    return normalized.toList()..sort();
  }

  Map<String, dynamic> toJson() {
    final normalizedSessionNotes = normalizedSessionNotesMap;
    return {
      'id': id,
      'name': name,
      'shortName': shortName,
      'teacher': teacher,
      'location': location,
      'dayOfWeek': dayOfWeek,
      'startSection': startSection,
      'endSection': endSection,
      'startTime': startTime,
      'endTime': endTime,
      'hasCustomTime': hasCustomTime,
      'color': color,
      'textColor': textColor,
      'startWeek': startWeek,
      'endWeek': endWeek,
      'isOddWeek': isOddWeek,
      'isEvenWeek': isEvenWeek,
      'customWeeks': customWeeks,
      'suspendedWeeks': suspendedWeeks,
      'courseNature': courseNature.value,
      'description': description,
      'note': note,
      if (normalizedSessionNotes != null)
        'sessionNotes': {
          for (final entry in normalizedSessionNotes.entries)
            entry.key.toString(): entry.value.toJson(),
        },
      'timeSchemeIdOverride': timeSchemeIdOverride,
    };
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    int readInt(String key, {int? fallback}) {
      final raw = json[key];
      if (raw is num) {
        return raw.toInt();
      }
      if (raw is String) {
        return int.tryParse(raw) ?? fallback ?? 0;
      }
      if (fallback != null) {
        return fallback;
      }
      throw FormatException('Course.$key must be a number');
    }

    List<int>? readIntList(String key) {
      final raw = json[key];
      if (raw is! List) {
        return null;
      }
      if (raw.length > maxWeekListEntries) {
        // 畸形/被灌入的备份：钳制后最多 maxWeek 项，量级远超即判无效，
        // 不去遍历一个百万元素的数组。
        return null;
      }
      final values = <int>[];
      for (final item in raw) {
        if (item is num) {
          values.add(item.toInt());
        } else if (item is String) {
          final parsed = int.tryParse(item);
          if (parsed != null) {
            values.add(parsed);
          }
        }
        // 其他类型忽略。旧实现把它们记作 0，会让脏数据伪装成「第 0 周」。
      }
      return values;
    }

    // 2026-10-08 补：下面六个字段原先是 `json[k] as String` 的**裸强制转换**。
    // Course.fromJson 是**所有**导入面的唯一入口（教务 CSV / ICS / .mikcb 备份 /
    // WebDAV 恢复），而这些 JSON 全是外部来的：一个字段类型不对就抛 TypeError，
    // 单条课程坏掉会让整份备份恢复失败
    // （`data_transfer_service.dart` 的 `_parseListWithTotalLossGuard` 把空结果
    // 当「全损」抛 `unrecognized_mikcb_data_file`）。
    // 局域网那条路早就改成了 `(json[k] as String?)?.trim() ?? ''`
    // （`lan_edit_provider_host.dart:522-525`），两个解析器此前并不一致。
    //
    // ⚠️ 但**不能一律放宽**：本仓有一条「坏条目留档、不写回」的机制
    // （`storage_service.dart` 的 `timetable_profiles_unparsed_items` +
    // `storage_service_profiles_integrity_test.dart:104` 钉着）——
    // 它靠「`Course.fromJson` 对结构性缺失抛错」把可疑记录留档，等解析器修好后
    // 还能救回来。若 `teacher` 缺失也收下，这条课就会带着空教师名混进课表、
    // 且**不留任何档**，用户永远不知道自己丢过东西。
    //
    // 所以分两类：
    // - **必填**（id / name / teacher / location / startTime / endTime）：
    //   缺失 → 抛 `FormatException`（让留档机制接住）；类型不对但有值
    //   （`name: 123` 这类导入器手滑）→ 收下并 toString，不抛。
    // - **可选**（shortName / color / textColor / note / description /
    //   courseNature / timeSchemeIdOverride）：缺失或类型不对都收下、退回默认。
    String readRequired(String key) {
      final raw = json[key];
      if (raw == null) {
        throw FormatException('Course.$key is missing');
      }
      return raw is String ? raw : raw.toString();
    }

    String? readStringOrNull(String key) {
      final raw = json[key];
      if (raw == null) {
        return null;
      }
      return raw is String ? raw : raw.toString();
    }

    final sections = normalizeSections(
      startSection: readInt('startSection', fallback: 1),
      endSection: readInt('endSection', fallback: 1),
    );
    final weeks = normalizeWeeks(
      startWeek: readInt('startWeek', fallback: 1),
      endWeek: readInt('endWeek', fallback: 16),
    );

    return Course(
      id: readRequired('id'),
      name: readRequired('name'),
      shortName: readStringOrNull('shortName'),
      teacher: readRequired('teacher'),
      location: readRequired('location'),
      dayOfWeek: normalizeDayOfWeek(readInt('dayOfWeek', fallback: 1)),
      startSection: sections.startSection,
      endSection: sections.endSection,
      startTime: readRequired('startTime'),
      endTime: readRequired('endTime'),
      hasCustomTime: json['hasCustomTime'] as bool? ?? false,
      color: readStringOrNull('color') ?? '#2196F3',
      textColor: readStringOrNull('textColor'),
      startWeek: weeks.startWeek,
      endWeek: weeks.endWeek,
      isOddWeek: json['isOddWeek'] as bool? ?? false,
      isEvenWeek: json['isEvenWeek'] as bool? ?? false,
      customWeeks: normalizeWeekList(readIntList('customWeeks')),
      suspendedWeeks: normalizeWeekList(readIntList('suspendedWeeks')),
      courseNature: CourseNatureX.fromValue(readStringOrNull('courseNature')),
      // `description` 先试自己、再回落旧键 `note`；两处都用 [readStringOrNull]，
      // 原来的 `json['note'] as String?` 同样是裸转换（数字型 note 会抛）。
      description: readStringOrNull('description') ?? readStringOrNull('note'),
      note: readStringOrNull('note'),
      sessionNotes: parseSessionNotes(json['sessionNotes']),
      timeSchemeIdOverride: readStringOrNull('timeSchemeIdOverride'),
    );
  }

  /// Parses persisted session-note maps (week key as string or int).
  static Map<int, CourseSessionNote>? parseSessionNotes(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final parsed = <int, CourseSessionNote>{};
    raw.forEach((key, value) {
      final week = switch (key) {
        final int number => number,
        final String text => int.tryParse(text),
        _ => null,
      };
      if (week == null || week < 1) {
        return;
      }
      if (value is! Map) {
        return;
      }
      final note = CourseSessionNote.fromJson(
        Map<String, dynamic>.from(value),
      ).normalizedOrNull;
      if (note != null) {
        parsed[week] = note;
      }
    });
    if (parsed.isEmpty) {
      return null;
    }
    return Map<int, CourseSessionNote>.unmodifiable(parsed);
  }

  static Map<int, CourseSessionNote>? normalizeSessionNotes(
    Map<int, CourseSessionNote>? source,
  ) {
    if (source == null || source.isEmpty) {
      return null;
    }
    final normalized = <int, CourseSessionNote>{};
    for (final entry in source.entries) {
      if (entry.key < 1) {
        continue;
      }
      final note = entry.value.normalizedOrNull;
      if (note != null) {
        normalized[entry.key] = note;
      }
    }
    if (normalized.isEmpty) {
      return null;
    }
    return Map<int, CourseSessionNote>.unmodifiable(normalized);
  }

  String toJsonString() => jsonEncode(toJson());

  factory Course.fromJsonString(String jsonString) {
    return Course.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  Course copyWith({
    String? id,
    String? name,
    Object? shortName = _unset,
    String? teacher,
    String? location,
    int? dayOfWeek,
    int? startSection,
    int? endSection,
    String? startTime,
    String? endTime,
    String? color,
    Object? textColor = _unset,
    int? startWeek,
    int? endWeek,
    bool? isOddWeek,
    bool? isEvenWeek,
    Object? customWeeks = _unset,
    Object? suspendedWeeks = _unset,
    CourseNature? courseNature,
    Object? description = _unset,
    Object? note = _unset,
    Object? sessionNotes = _unset,
    Object? timeSchemeIdOverride = _unset,
    bool? hasCustomTime,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: identical(shortName, _unset)
          ? this.shortName
          : shortName as String?,
      teacher: teacher ?? this.teacher,
      location: location ?? this.location,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      color: color ?? this.color,
      textColor: identical(textColor, _unset)
          ? this.textColor
          : textColor as String?,
      startWeek: startWeek ?? this.startWeek,
      endWeek: endWeek ?? this.endWeek,
      isOddWeek: isOddWeek ?? this.isOddWeek,
      isEvenWeek: isEvenWeek ?? this.isEvenWeek,
      customWeeks: identical(customWeeks, _unset)
          ? this.customWeeks
          : (customWeeks as List<int>?),
      suspendedWeeks: identical(suspendedWeeks, _unset)
          ? this.suspendedWeeks
          : (suspendedWeeks as List<int>?),
      courseNature: courseNature ?? this.courseNature,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      sessionNotes: identical(sessionNotes, _unset)
          ? this.sessionNotes
          : normalizeSessionNotes(sessionNotes as Map<int, CourseSessionNote>?),
      timeSchemeIdOverride: identical(timeSchemeIdOverride, _unset)
          ? this.timeSchemeIdOverride
          : timeSchemeIdOverride as String?,
      hasCustomTime: hasCustomTime ?? this.hasCustomTime,
    );
  }

  int get sectionCount => endSection - startSection + 1;

  Map<int, CourseSessionNote>? get normalizedSessionNotesMap =>
      normalizeSessionNotes(sessionNotes);

  CourseSessionNote? sessionNoteForWeek(int week) =>
      normalizedSessionNotesMap?[week];

  bool hasHomeworkInWeek(int week) =>
      sessionNoteForWeek(week)?.hasHomework == true;

  bool hasSessionNoteInWeek(int week) => sessionNoteForWeek(week) != null;

  bool get hasAnyHomework =>
      normalizedSessionNotesMap?.values.any((note) => note.hasHomework) ??
      false;

  /// Returns a new session-note map with [week] upserted or removed.
  Map<int, CourseSessionNote>? withSessionNote(
    int week,
    CourseSessionNote? note,
  ) {
    final next = <int, CourseSessionNote>{...?normalizedSessionNotesMap};
    final normalized = note?.normalizedOrNull;
    if (normalized == null) {
      next.remove(week);
    } else {
      next[week] = normalized;
    }
    return normalizeSessionNotes(next);
  }

  /// Removes the session note for [week] (e.g. delete this occurrence).
  Map<int, CourseSessionNote>? withoutSessionNote(int week) =>
      withSessionNote(week, null);

  /// Moves a session note from [fromWeek] to [toWeek] (reschedule).
  Map<int, CourseSessionNote>? relocatingSessionNote({
    required int fromWeek,
    required int toWeek,
  }) {
    if (fromWeek == toWeek) {
      return normalizedSessionNotesMap;
    }
    final source = sessionNoteForWeek(fromWeek);
    final next = <int, CourseSessionNote>{...?normalizedSessionNotesMap};
    next.remove(fromWeek);
    if (source != null) {
      next[toWeek] = source;
    }
    return normalizeSessionNotes(next);
  }

  /// Session notes kept on the leftover multi-week course after moving one week.
  Map<int, CourseSessionNote>? sessionNotesExcludingWeek(int week) =>
      withoutSessionNote(week);

  /// Session notes for a single-week course created by reschedule/split.
  Map<int, CourseSessionNote>? sessionNotesForSingleWeek({
    required int sourceWeek,
    required int targetWeek,
  }) {
    final source = sessionNoteForWeek(sourceWeek);
    if (source == null) {
      return null;
    }
    return normalizeSessionNotes({targetWeek: source});
  }

  List<int>? get normalizedCustomWeeks => normalizeWeekList(customWeeks);

  bool get hasCustomWeeks => normalizedCustomWeeks != null;

  List<int>? get normalizedSuspendedWeeks => normalizeWeekList(suspendedWeeks);

  bool isSuspendedInWeek(int week) => suspendedWeeks?.contains(week) ?? false;

  List<int> get activeWeeks {
    final custom = normalizedCustomWeeks;
    final weeks = <int>[];
    if (custom != null) {
      weeks.addAll(custom);
    } else {
      for (var week = startWeek; week <= endWeek; week++) {
        if (isOddWeek && week.isEven) {
          continue;
        }
        if (isEvenWeek && week.isOdd) {
          continue;
        }
        weeks.add(week);
      }
    }
    final suspended = normalizedSuspendedWeeks;
    if (suspended == null || suspended.isEmpty) {
      return weeks;
    }
    return weeks.where((week) => !suspended.contains(week)).toList();
  }

  String weekDescription(AppLocalizations l10n) =>
      courseWeekDescription(l10n, this);

  String? suspensionDescription(AppLocalizations l10n) =>
      courseSuspensionDescription(l10n, this);

  bool isInWeek(int week) {
    final custom = normalizedCustomWeeks;
    if (custom != null) {
      return custom.contains(week);
    }
    if (week < startWeek || week > endWeek) return false;
    if (isOddWeek && week % 2 == 0) return false;
    if (isEvenWeek && week % 2 != 0) return false;
    return true;
  }

  /// 是否在指定周次有效（排除停课）
  bool isActiveInWeek(int week) {
    if (suspendedWeeks?.contains(week) == true) return false;
    return isInWeek(week);
  }

  /// 是否在指定周及以后仍有上课周（排除停课周）。
  /// 返回 false 表示课程在该周之前已全部结束，可作为「已结课」判定。
  bool hasActiveWeekOnOrAfter(int week) {
    return activeWeeks.any((w) => w >= week);
  }
}
