import 'package:university_timetable/domain/import_export_logic.dart';
import 'package:university_timetable/models/course.dart';

/// `saveCourseConfig` keys that upstream scripts send but this app cannot store.
///
/// * `firstDayOfWeek` — 周起始日在 `week_calculator`、`statistics_service`、
///   考试排期三处硬编码为周一，没有任何可配置项。
/// * `defaultClassDuration` / `defaultBreakDuration` — 只在
///   `buildQuickSectionTimes` 生成时间模板时作为入参使用，模型不持久化，
///   存下来就是死状态。
const List<String> warehouseUnsupportedCourseConfigKeys = [
  'firstDayOfWeek',
  'defaultClassDuration',
  'defaultBreakDuration',
];

/// Parses an adapter-supplied semester start date into **local midnight**.
///
/// Why normalize: the field is persisted as `millisecondsSinceEpoch` and every
/// week-index computation re-reads it. A UTC instant (e.g. `2026-09-07T00:00Z`
/// → 08:00 in UTC+8) or a bare time component would shift the weekday and make
/// week 1 start on the wrong day, so keep only the calendar date and drop the
/// clock part.
///
/// Out-of-range calendar dates are **rejected, not rolled over**. `DateTime`
/// happily normalises `2026-13-45` into 2027-02-14, and this value is the sole
/// input to every "which week is it" computation in the app — silently
/// accepting a rollover corrupts a whole semester of week numbers. Returning
/// null makes the caller keep the user's existing value, which is the same
/// contract as an unparseable string.
DateTime? warehouseSemesterStartDate(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  // One validation path for both the ISO branch and the `2026-9-7 08:00`
  // fallback: take the leading calendar components, then require that they
  // name a real day. `DateTime.tryParse` alone is not enough — it normalises
  // overflow (`2026-13-45` → 2027-02-14, `2026-02-30` → 2026-03-02).
  final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(text);
  if (match == null) {
    return null;
  }
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) {
    return null;
  }
  // Round-trip is sufficient on its own: `DateTime` normalises every overflow
  // case we care about (month 0/13, day 0/32, Feb 30) into a *different*
  // year/month/day, so a mismatch catches all of them. A separate range check
  // was tried first and proved redundant by mutation testing.
  final built = DateTime(year, month, day);
  if (built.year != year || built.month != month || built.day != day) {
    return null;
  }
  return built;
}

/// What `saveCourseConfig` should write into `TimetableSettings`.
///
/// `null` means "script did not supply a usable value" and the caller must keep
/// whatever the user already has.
class WarehouseCourseConfigResolution {
  final int? semesterWeekCount;
  final DateTime? semesterStartDate;

  const WarehouseCourseConfigResolution({
    this.semesterWeekCount,
    this.semesterStartDate,
  });

  bool get hasAnything => semesterWeekCount != null || semesterStartDate != null;
}

/// Resolves an adapter's `saveCourseConfig` payload into settings to apply.
///
/// Extracted so the "invalid value must not overwrite the user's setting"
/// contract is directly testable. It used to live inline in the import screen,
/// and the test that covered it re-implemented the same condition — so flipping
/// the production behaviour left the test green.
class WarehouseCourseConfigLogic {
  const WarehouseCourseConfigLogic._();

  static WarehouseCourseConfigResolution resolve(Map<Object?, Object?> decoded) {
    // coerceInt, not a bare `as num?`: an adapter sending
    // `semesterTotalWeeks: "20"` would throw and take the whole import with it,
    // same class of bug as the course-array parser.
    final weekCount = WarehouseCourseImportLogic.coerceInt(
      decoded['semesterTotalWeeks'],
    );
    final startDate = warehouseSemesterStartDate(decoded['semesterStartDate']);
    return WarehouseCourseConfigResolution(
      // 0 / negative means "not supplied" rather than a literal 0-week term.
      semesterWeekCount: (weekCount != null && weekCount > 0) ? weekCount : null,
      semesterStartDate: startDate,
    );
  }
}

/// Why one record from an adapter's course array did not make it in.
///
/// Reported through `WarehouseCourseImportLogic.parse`'s `onSkip` rather than
/// dropped silently. A course that vanishes with no explanation is the exact
/// failure users complained about when 早读-style records were being dropped;
/// trading "the whole batch fails" for "one record disappears quietly" only
/// moved the same problem somewhere harder to see.
enum WarehouseCourseSkipReason {
  /// Neither a usable section pair nor a usable clock pair — nothing to seat
  /// the course on.
  unusable,

  /// The record threw while being read: unexpected field types, or a map with
  /// non-string keys. Other records in the same batch are unaffected.
  malformed,

  /// The course was imported, but non-numeric or out-of-range week numbers
  /// were stripped from its week list, so it shows fewer weeks than it meets.
  partialWeeks,
}

/// Pure parser for 教务适配脚本下发的课程数组（`saveImportedCourses` 的入参）。
///
/// Why this exists: the warehouse protocol lets an adapter attach a real clock
/// range to a course via `isCustomTime` / `customStartTime` / `customEndTime`.
/// Such records frequently carry **no** `startSection` / `endSection` at all —
/// 早读、实验连堂等不对应编号节次的时段就是这种形状。The previous inline parser
/// required both section fields and silently dropped anything missing them, so
/// those courses simply never appeared on the timetable.
///
/// Extracted as a pure function so this behaviour is directly testable; the
/// widget used to own it inline.
class WarehouseCourseImportLogic {
  const WarehouseCourseImportLogic._();

  /// Coerces an adapter-supplied integer, tolerating the shapes JavaScript
  /// adapters actually produce (`1`, `"1"`, `1.0`).
  ///
  /// A bare `as num` cast throws on `"1"`, and because [parse] maps over the
  /// whole batch, one dirty record used to abort every other course in the
  /// import. Adapters serializing week numbers as strings is common enough
  /// that failing the entire import over it is the wrong trade.
  static int? coerceInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  /// Coerces an adapter-supplied boolean, tolerating `1`/`0` and `"true"`.
  ///
  /// Same rationale as [coerceInt]: `isCustomTime: 1` is a natural thing for
  /// a JS adapter to emit, and it must not throw.
  static bool? coerceBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final text = raw.trim().toLowerCase();
      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
    }
    return null;
  }

  /// Reads a string-ish field without throwing on a non-string value.
  static String coerceText(Object? raw) => raw?.toString().trim() ?? '';

  /// Normalizes an adapter-supplied `HH:mm` clock value, or null when unusable.
  ///
  /// Tolerates `H:mm`/`H:m` and surrounding whitespace, plus a trailing `:ss`
  /// from adapters that serialize a `DateTime`; rejects out-of-range values so
  /// a malformed clock can never be persisted. Minutes accept 1–2 digits on
  /// purpose: accepting `8:05` while rejecting `8:5` is an asymmetry no caller
  /// could act on, and adapters do emit the short form.
  ///
  /// The whole value is anchored. An unanchored `^(\d{1,2}):(\d{1,2})` silently
  /// accepted `8:555` as `08:55` and `8:5:30` as `08:05` once minutes went to
  /// two widths — a wrong clock is worse than a rejected one, because a rejected
  /// clock falls back to the template while a mangled one is persisted. The
  /// seconds group stays exactly two digits: every producer that emits seconds
  /// (ISO, `toISOString`, `Date#toTimeString`) zero-pads them.
  static String? normalizeClock(Object? raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final match = RegExp(
      r'^(\d{1,2}):(\d{1,2})(?::(\d{2}))?$',
    ).firstMatch(text);
    if (match == null) {
      return null;
    }
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  /// Minutes since midnight for a normalized `HH:mm`, or null when unusable.
  static int? clockMinutes(String? normalized) {
    final text = normalized?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
    if (match == null) {
      return null;
    }
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  /// Parses [rawCourses] into [Course]s, skipping unusable records.
  ///
  /// [idFactory] keeps this pure w.r.t. identity so callers control ids.
  /// [unknownTeacher] / [unknownLocation] supply the placeholders the widget
  /// would otherwise pull from localisation.
  ///
  /// [onSkip] reports every record that did not make it in, together with a
  /// best-effort [name] and, for [WarehouseCourseSkipReason.malformed], the
  /// error that was swallowed. It exists because the alternative is worse on
  /// both ends: throwing used to cost the user *every* course in the batch, and
  /// skipping quietly costs them one course with no explanation — which is
  /// exactly the complaint that started this funnel ("a course just isn't on
  /// my timetable and nothing says why"). Callers should both log the count and
  /// show it; a skip that nobody is told about is the bug, not the fix.
  ///
  /// The `error` is there because this funnel catches *everything* on purpose:
  /// one `TypeError` from a future field shape must not void the batch. Without
  /// it, a genuine programming bug in this file is indistinguishable from dirty
  /// adapter data and the stack trace is gone for good. Pass it to the log.
  static List<Course> parse(
    List<dynamic> rawCourses, {
    required String Function() idFactory,
    required String unknownTeacher,
    required String unknownLocation,
    int maxWeek = ImportExportLogic.maxAllowedSemesterWeekCount,
    void Function(
      WarehouseCourseSkipReason reason,
      String? name, {
      Object? error,
    })?
    onSkip,
  }) {
    final courses = <Course>[];
    for (final item in rawCourses) {
      if (item is! Map) {
        onSkip?.call(WarehouseCourseSkipReason.malformed, null);
        continue;
      }
      Course? parsed;
      var weeksTrimmed = false;
      try {
        parsed = _parseOne(
          item,
          idFactory: idFactory,
          unknownTeacher: unknownTeacher,
          unknownLocation: unknownLocation,
          maxWeek: maxWeek,
          onWeeksTrimmed: () => weeksTrimmed = true,
        );
      } catch (error) {
        // One malformed record must never cost the user the whole batch.
        // `parse` is the single funnel for every adapter's output, so a throw
        // here used to surface as "import failed" with nothing saved. The error
        // is handed back rather than dropped: this catch is deliberately
        // total, so without it a real programming bug here would be
        // indistinguishable from dirty adapter data.
        onSkip?.call(
          WarehouseCourseSkipReason.malformed,
          _bestEffortName(item),
          error: error,
        );
        continue;
      }
      if (parsed != null) {
        courses.add(parsed);
        // 只有课真的进来了，「周次被削」才成立。一门「周次全越界 + 被整条丢弃」
        // 的课会同时命中两个标志，若在这里无条件上报，用户会同时看到「丢掉了
        // 1 门」和「1 门课导入成功但少了周次」——后一句是假的。而它恰好是这个
        // 功能专门要防的那类隐蔽故障，跟「整条没进来」混在一起就把提示词废掉了。
        if (weeksTrimmed) {
          onSkip?.call(WarehouseCourseSkipReason.partialWeeks, parsed.name);
        }
      } else {
        onSkip?.call(
          WarehouseCourseSkipReason.unusable,
          _bestEffortName(item),
        );
      }
    }
    return courses;
  }

  /// Reads a record's `name` without the `cast<String, dynamic>()` that
  /// `_parseOne` does — that cast is precisely what can throw on a map with
  /// non-string keys, so it is no use inside the `catch` that reports it.
  static String? _bestEffortName(Object? item) {
    if (item is Map) {
      for (final entry in item.entries) {
        if (entry.key == 'name') {
          final name = coerceText(entry.value);
          return name.isEmpty ? null : name;
        }
      }
    }
    return null;
  }

  static Course? _parseOne(
    Map<dynamic, dynamic> item, {
    required String Function() idFactory,
    required String unknownTeacher,
    required String unknownLocation,
    required int maxWeek,
    void Function()? onWeeksTrimmed,
  }) {
    final map = Map<String, dynamic>.from(item.cast<String, dynamic>());
    final name = coerceText(map['name']);
    final teacher = coerceText(map['teacher']);
    final locationRaw = map['position'] ?? map['location'];
    final location = coerceText(locationRaw);
    final day = coerceInt(map['day']);
    final startSection = coerceInt(map['startSection']);
    final endSection = coerceInt(map['endSection']);
    final rawWeeks = map['weeks'];
    final rawWeekList = rawWeeks is List ? rawWeeks : null;
    final inRangeWeeks = rawWeekList
        ?.map(coerceInt)
        .whereType<int>()
        .where((week) => week > 0 && week <= maxWeek)
        .toList();
    final weeks = inRangeWeeks?.toSet().toList();
    weeks?.sort();
    // Losing a week number is not a silent no-op: the course still shows up,
    // just with fewer weeks than it actually meets, and the student has no way
    // to notice. Compared *before* de-duplication on purpose — adapters may
    // legitimately repeat a week, and a repeat loses nothing.
    if (inRangeWeeks != null && inRangeWeeks.length < rawWeekList!.length) {
      onWeeksTrimmed?.call();
    }

    final customStart = normalizeClock(map['customStartTime']);
    final customEnd = normalizeClock(map['customEndTime']);
    // A range whose end is not after its start is unusable, not merely odd:
    // an inverted clock makes the "in progress" check never match and leaves
    // alarms silent, and it is invisible on the timetable. Rejecting it here
    // means such a course falls back to template times — a wrong-looking but
    // *consistent* entry — instead of a permanently broken one.
    //
    // Courses that genuinely cross midnight cannot be represented anyway:
    // `Course` stores `HH:mm` with no day component.
    //
    // `clockMinutes` cannot return null for either end here: `normalizeClock`
    // already produced `HH:mm` or null, and a non-null `HH:mm` always parses.
    // So the `?? 0` is a bug-guard, not a data rule — it keeps this expression
    // to the single reachable comparison instead of carrying two `== null`
    // branches that no input can ever take. (A previous revision had those
    // branches; they read as a second, stricter policy that did not exist.)
    final startMinutes = clockMinutes(customStart) ?? 0;
    final endMinutes = clockMinutes(customEnd) ?? 0;
    final clockRangeUsable = endMinutes > startMinutes;
    // `isCustomTime` absent → infer from the presence of a usable clock pair,
    // so adapters that only send the times still work.
    final hasCustomTime =
        (coerceBool(map['isCustomTime']) ??
            (customStart != null && customEnd != null)) &&
        customStart != null &&
        customEnd != null &&
        clockRangeUsable;

    // No section but a real clock range (早读 etc.): seat it in section 1 so
    // the record survives; the pinned clock drives display and alarms.
    final effectiveStartSection = startSection ?? (hasCustomTime ? 1 : null);
    final effectiveEndSection = endSection ?? effectiveStartSection;

    if (name.isEmpty ||
        day == null ||
        effectiveStartSection == null ||
        effectiveEndSection == null ||
        weeks == null ||
        weeks.isEmpty) {
      return null;
    }
    final sections = Course.normalizeSections(
      startSection: effectiveStartSection,
      endSection: effectiveEndSection,
    );
    return Course(
      id: idFactory(),
      name: name,
      teacher: teacher.isEmpty ? unknownTeacher : teacher,
      location: location.isEmpty ? unknownLocation : location,
      dayOfWeek: Course.normalizeDayOfWeek(day),
      startSection: sections.startSection,
      endSection: sections.endSection,
      startWeek: weeks.first,
      endWeek: weeks.last,
      startTime: hasCustomTime ? customStart : '',
      endTime: hasCustomTime ? customEnd : '',
      hasCustomTime: hasCustomTime,
      customWeeks: weeks,
      // Adapters that know 必修/选修 send `courseNature: 'required' |
      // 'elective'`（上游 CQUET 会先把课程名里的 `[必修]`/`[选修]` 抠出来）。
      // Previously dropped, so every 选修 course imported as 必修 — which
      // mislabels the course card / overview and, worse, feeds
      // `statistics_service` a required course, skewing credit totals.
      // Unknown/absent values fall back to 必修 via CourseNatureX.
      courseNature: CourseNatureX.fromValue(coerceText(map['courseNature'])),
    );
  }
}
