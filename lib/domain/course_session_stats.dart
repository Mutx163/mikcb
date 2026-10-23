import '../models/course.dart';
import '../models/course_task.dart';
import '../models/exam.dart';
import '../models/timetable_settings.dart';
import 'week_calculator.dart';

/// 单次课的阶段判定。
///
/// 只有「真实日期」才谈得上已上/未上，所以没设开学日期时一律 [undated]，
/// 不按周次估算 —— 估算会把「第 3 周周三」当成已上，而用户看到的课表
/// 并没有这条时间轴。
enum CourseSessionPhase {
  /// 已过（结束于今天之前）
  done,

  /// 就是今天
  today,

  /// 还没到
  upcoming,

  /// 该周停课（`suspendedWeeks`），不算缺勤也不算已上
  suspended,

  /// 当天是假期，课表本就不显示
  holiday,

  /// 没设开学日期，无法锚定到具体某天
  undated,
}

/// 一次具体的课（某门课 × 某一周的那一次）。
///
/// 这是**推导值**，不是实体：系统里没有「课次表」，本类只在计算过程中存在，
/// 不落盘、不参与云同步。要改成可写的实体（考勤、实际到课）需要另立模型。
class CourseSession {
  const CourseSession({
    required this.courseId,
    required this.week,
    required this.date,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.phase,
    required this.noteText,
    required this.hasHomework,
    required this.taskCount,
    required this.examCount,
    required this.hasReminder,
  });

  final String courseId;
  final int week;

  /// 真实日期；未设开学日期时为 null
  final DateTime? date;
  final int dayOfWeek;
  final int startSection;
  final int endSection;

  /// 生效作息下的真实钟点（可能为空：作息模板缺该节）
  final String? startTime;
  final String? endTime;
  final String location;
  final CourseSessionPhase phase;

  /// 这次课的备注原文（按周保存的 sessionNotes）
  final String? noteText;
  final bool hasHomework;
  final int taskCount;
  final int examCount;

  /// 这次课（按真实日期）是否设过单节课提醒
  final bool hasReminder;

  int get sectionCount => endSection - startSection + 1;

  bool get hasNote => noteText != null && noteText!.trim().isNotEmpty;

  /// 是否算「上过了」：只有确定日期且已过去的正常课
  bool get isPast => phase == CourseSessionPhase.done;

  /// 是否计入「计划/覆盖」口径：停课与假期不算（用户没上课，
  /// 那次课有没有备注都不该摊进「记录覆盖率」）。
  bool get isPlanned =>
      phase != CourseSessionPhase.suspended &&
      phase != CourseSessionPhase.holiday;
}

/// 「单节课」维度的汇总（全部由现有数据推导，不需要用户额外录入）。
class CourseSessionStats {
  const CourseSessionStats({
    required this.courseName,
    required this.teacher,
    required this.sessions,
    required this.plannedSessions,
    required this.hasCalendar,
  });

  final String courseName;
  final String teacher;

  /// 全部课次（含停课、假期），按日期/周次排好序
  final List<CourseSession> sessions;

  /// 计入统计的排课次数（不含停课与假期）
  final int plannedSessions;

  /// 是否有真实日期轴（= 设了开学日期）
  final bool hasCalendar;

  bool get isEmpty => sessions.isEmpty;

  int countOf(CourseSessionPhase phase) =>
      sessions.where((s) => s.phase == phase).length;

  int get doneSessions => countOf(CourseSessionPhase.done);
  int get todaySessions => countOf(CourseSessionPhase.today);
  int get upcomingSessions => countOf(CourseSessionPhase.upcoming);
  int get suspendedSessions => countOf(CourseSessionPhase.suspended);
  int get holidaySessions => countOf(CourseSessionPhase.holiday);
  int get undatedSessions => countOf(CourseSessionPhase.undated);

  /// 已经有备注的课次数（分母与 [sessions.length] 同口径）
  ///
  /// 覆盖类统计的分子分母都必须是「全部列出的课次」：停课周不清备注
  /// （`toggleCourseSuspensionImpl` 只改 `suspendedWeeks`），「停课周有备注」
  /// 真实存在且列表行照样显示。若分母用 [plannedSessions] 而分子数全部，
  /// 能构造出「3 / 1」这种超 100% 的自相矛盾；若两边都排除停课，
  /// 覆盖分母又会与汇总卡的「课次」对不上。全部课次口径下天然对齐，
  /// 也与覆盖卡的文档语义（「有多少次课留下了记录」）一致。
  int get notedSessions => sessions.where((s) => s.hasNote).length;

  /// 标了「有作业」（含挂了该课该周的作业条目）的课次数
  int get homeworkSessions => sessions.where((s) => s.hasHomework).length;

  /// 设过单节课提醒的课次数
  int get reminderSessions => sessions.where((s) => s.hasReminder).length;

  /// 已上课时（节）
  int get doneSections => sessions
      .where((s) => s.isPast)
      .fold<int>(0, (sum, s) => sum + s.sectionCount);

  /// 计划总课时（节，不含停课与假期）
  ///
  /// 必须与 [doneSections] 同一算法——逐课次累加。不能写成
  /// 「每周节数 × [plannedSessions]」：plannedSessions 按「条目 × 周」计数，
  /// 一门课一周两次排课（2+3 节）× 16 周时该式得 5×32=160，实际 5×16=80。
  int get plannedSections => sessions
      .where((s) => s.isPlanned)
      .fold<int>(0, (sum, s) => sum + s.sectionCount);
}

/// 单节课统计的计算入口（纯 Dart，无 Flutter / IO 依赖）。
///
/// 口径说明（必须与课表显示一致，否则同一份数据两处对不上）：
/// - 课次 = 课程的每一个有效周（`isInWeek` 口径：含单双周/自定义周次）；
///   停课周仍然列出来，但标 [CourseSessionPhase.suspended]，不计入计划。
/// - 日期只有一条来源：周次 + 星期几 → `WeekCalculator`，与提醒/导出同源。
///   没设开学日期就返回 null，由 UI 明说「按周次列出」。
/// - 节假日判定由调用方注入（[isHoliday]），因为假期数据在 provider 侧，
///   领域层不持有；不注入时视为没有假期数据。
class CourseSessionStatsCalculator {
  CourseSessionStatsCalculator._();

  static CourseSessionStats build({
    required String courseName,
    required List<Course> courses,
    required TimetableSettings settings,
    required List<CourseTask> tasks,
    required List<Exam> exams,
    required DateTime now,
    bool Function(DateTime date)? isHoliday,
    String? Function(Course course)? startTimeResolver,
    String? Function(Course course)? endTimeResolver,

    /// 已设置的单节课提醒键集合，格式 `courseId|yyyy-MM-dd`。
    ///
    /// 由调用方一次构建（provider 的 `classReminderFor` 是线性扫，
    /// 每 session 查一次是 O(课次 × 提醒数)；集合在这里只需要 O(1) 命中）。
    Set<String> reminderKeys = const {},
  }) {
    final semesterStart = settings.semesterStartDate;
    final today = DateTime(now.year, now.month, now.day);

    // 预分组：任务按「课程|周次」、考试按「课程|日期」各数一遍，
    // 避免在每个 session 上全表扫（20 周 × 10 门课 × 几十条任务时最差
    // 是 O(课次 × 任务数)，预分组后一次 O(任务数)）。
    final taskCounts = <String, int>{};
    for (final task in tasks) {
      final week = task.sourceWeek;
      final course = task.courseId;
      if (course == null || week == null) continue;
      final key = '$course|$week';
      taskCounts[key] = (taskCounts[key] ?? 0) + 1;
    }
    final examCounts = <String, int>{};
    for (final exam in exams) {
      final dateTime = exam.dateTime;
      final key =
          '${exam.courseId}|'
          '${dateTime.year.toString().padLeft(4, '0')}-'
          '${dateTime.month.toString().padLeft(2, '0')}-'
          '${dateTime.day.toString().padLeft(2, '0')}';
      examCounts[key] = (examCounts[key] ?? 0) + 1;
    }

    final sessions = <CourseSession>[];

    for (final course in courses) {
      // 每门课只解析一次的量：备注表（sessionNoteForWeek 每次调用都会
      // 经 normalizedSessionNotesMap 重建整个 Map）与生效钟点。
      final notes = course.normalizedSessionNotesMap;
      final startTime = startTimeResolver?.call(course) ?? course.startTime;
      final endTime = endTimeResolver?.call(course) ?? course.endTime;
      for (final week in _candidateWeeks(course)) {
        final date = courseOccurrenceDate(semesterStart, course, week);
        final suspended = course.isSuspendedInWeek(week);
        final dateKey = date == null ? null : _formatDate(date);
        final note = notes?[week];
        final taskCount = taskCounts['${course.id}|$week'] ?? 0;
        final examCount = dateKey == null
            ? 0
            : examCounts['${course.id}|$dateKey'] ?? 0;

        sessions.add(
          CourseSession(
            courseId: course.id,
            week: week,
            date: date,
            dayOfWeek: course.dayOfWeek,
            startSection: course.startSection,
            endSection: course.endSection,
            startTime: startTime,
            endTime: endTime,
            location: course.location,
            phase: _resolvePhase(
              suspended: suspended,
              date: date,
              today: today,
              holiday: date != null && (isHoliday?.call(date) ?? false),
            ),
            noteText: note?.trimmedText,
            hasHomework: (note?.hasHomework ?? false) || taskCount > 0,
            taskCount: taskCount,
            examCount: examCount,
            hasReminder:
                dateKey != null &&
                reminderKeys.contains('${course.id}|$dateKey'),
          ),
        );
      }
    }

    sessions.sort(_compareSessions);

    final planned = sessions.where((session) => session.isPlanned).length;

    return CourseSessionStats(
      courseName: courseName,
      teacher: courses.isEmpty ? '' : courses.first.teacher,
      sessions: sessions,
      plannedSessions: planned,
      hasCalendar: semesterStart != null,
    );
  }

  /// 该课程的所有「排课周」：含停课周，排除单双周不匹配的那些。
  static List<int> _candidateWeeks(Course course) {
    final custom = course.normalizedCustomWeeks;
    if (custom != null) {
      return List<int>.from(custom);
    }
    final weeks = <int>[];
    for (var week = course.startWeek; week <= course.endWeek; week++) {
      if (course.isInWeek(week)) {
        weeks.add(week);
      }
    }
    return weeks;
  }

  static CourseSessionPhase _resolvePhase({
    required bool suspended,
    required DateTime? date,
    required DateTime today,
    required bool holiday,
  }) {
    if (suspended) return CourseSessionPhase.suspended;
    if (date == null) return CourseSessionPhase.undated;
    if (holiday) return CourseSessionPhase.holiday;
    if (date.isBefore(today)) return CourseSessionPhase.done;
    if (date.isAtSameMomentAs(today)) return CourseSessionPhase.today;
    return CourseSessionPhase.upcoming;
  }

  /// 有日期的按日期排；没日期的排在后面按周次排。
  static int _compareSessions(CourseSession left, CourseSession right) {
    final leftDate = left.date;
    final rightDate = right.date;
    if (leftDate != null && rightDate != null) {
      final byDate = leftDate.compareTo(rightDate);
      if (byDate != 0) return byDate;
    } else if (leftDate != null) {
      return -1;
    } else if (rightDate != null) {
      return 1;
    }
    final byWeek = left.week.compareTo(right.week);
    if (byWeek != 0) return byWeek;
    final byDay = left.dayOfWeek.compareTo(right.dayOfWeek);
    if (byDay != 0) return byDay;
    return left.startSection.compareTo(right.startSection);
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// 课次 → 真实日期的**唯一规则**：学期首周的周一 + (周-1)×7 + (星期-1)。
///
/// 与 `TimetableCourseService.courseOccurrenceDate` 同一算法（那边是给 provider
/// 用的门面），此处独立成一份是为了让领域层可测且不反向依赖 services。
/// 两处若分叉，单节课统计的日期会与提醒、课表对不上 —— 已有测试
/// `course_session_stats_test` 钉住这条等价关系。
DateTime? courseOccurrenceDate(
  DateTime? semesterStart,
  Course course,
  int week,
) {
  if (semesterStart == null || week < 1) {
    return null;
  }
  final startOfSemesterWeek = WeekCalculator.startOfWeek(semesterStart);
  return WeekCalculator.addDays(
    startOfSemesterWeek,
    (week - 1) * 7 + course.dayOfWeek - 1,
  );
}
