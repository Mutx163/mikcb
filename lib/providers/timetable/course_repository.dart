part of '../timetable_provider.dart';

/// 单条课程的整表写入口（原 `timetable_provider.dart:2517-2574`、`:2576-2591`）。
///
/// 移出时补上本仓的写入纪律「快照 → await 落库 → catch 回滚 + rethrow」，判据与
/// `course_group_repository.dart` 相同：**内存里被改掉的是不是用户刚刚亲口确认的那一条**。
///
/// - `deleteCourse` 除了摘掉这门课，还连带 `_exams.removeWhere` / `_tasks.removeWhere`
///   摘掉记在它名下的考试与作业 —— 用户确认的是"删这门课"，那些不是他删的东西；
/// - `updateCourse` 会把改动的共享字段**广播给同组其它课次**（下面的 applySharedFields
///   循环），还会 `_syncHomeworkTasksWithCourses` 重算作业；
/// - 两处原先都没有 try/catch。而 `_persistActiveProfileState()` 开头会先
///   `_mergeActiveProfileIntoProfilesList()` 把课程/考试/作业/日程并进 `_profiles`，
///   所以落盘失败之后内存里连课表镜像都是改过的状态：抛错跳过了 `_notifyStateChanged()`，
///   界面显示旧的、getter 是新的，而下一次任意成功写入（切周、加课、30 秒一次的
///   `syncTemporalContext` 心跳）会把这份从未落库的改动当成既有状态永久落盘。
Future<void> _timetableUpdateCourse(
  TimetableProvider host,
  Course course, {
  String? previousSharedName,
}) async {
  final index = host._courses.indexWhere((c) => c.id == course.id);
  if (index == -1) {
    return;
  }
  final validationMessage = host.validateCourseTimeSchemeOverride(
    timeSchemeId: course.timeSchemeIdOverride,
    startSection: course.startSection,
    endSection: course.endSection,
  );
  if (validationMessage != null) {
    throw ArgumentError(validationMessage);
  }
  final normalized = host._normalizeCourse(course);
  final normalizedCourse = _isLiveTestingFixture(normalized)
      ? normalized
      : host._syncCourseWithEffectiveTimeScheme(normalized);
  final originalCourse = host._courses[index];
  final previousKey = buildSharedCourseNameKey(
    previousSharedName ?? originalCourse.name,
  );
  final newKey = CourseDomain.sharedKey(normalizedCourse);

  // 从这里开始动内存：本函数会改同组其它课次，也会重算作业，失败时都要退回。
  final snapshotCourses = List<Course>.from(host._courses);
  final snapshotTasks = List<CourseTask>.from(host._tasks);
  final snapshotProfiles = List<TimetableProfile>.from(host._profiles);

  host._courses[index] = normalizedCourse;
  await host._recordTeacherImpl(normalizedCourse.teacher);
  await host._recordLocationImpl(normalizedCourse.location);
  for (var i = 0; i < host._courses.length; i++) {
    if (i == index) {
      continue;
    }
    final current = host._courses[i];
    final currentKey = CourseDomain.sharedKey(current);
    if (currentKey == previousKey || currentKey == newKey) {
      host._courses[i] = CourseDomain.applySharedFields(
        current,
        normalizedCourse,
      );
    }
  }

  await host._syncHomeworkTasksWithCourses();
  try {
    await host._persistActiveProfileState();
  } catch (_) {
    host._courses = snapshotCourses;
    host._tasks = snapshotTasks;
    host._profiles = snapshotProfiles;
    rethrow;
  }
  host._currentLiveCourseId = null;
  host._notifyStateChanged();
  unawaited(host._syncExamReminders());
  host._analytics.logEventLater(
    name: 'course_updated',
    parameters: {
      'day_of_week': normalizedCourse.dayOfWeek,
      'section_count': normalizedCourse.sectionCount,
      'has_short_name': normalizedCourse.shortName?.isNotEmpty == true
          ? 1
          : 0,
    },
  );
  host._updateLiveActivity();
}

Future<void> _timetableDeleteCourse(TimetableProvider host, String courseId) async {
  // 三份列表 + 课表镜像都要能退回：删课程失败时，被连带摘掉的考试与作业必须一起回来。
  final snapshotCourses = List<Course>.from(host._courses);
  final snapshotExams = List<Exam>.from(host._exams);
  final snapshotTasks = List<CourseTask>.from(host._tasks);
  final snapshotProfiles = List<TimetableProfile>.from(host._profiles);
  host._courses.removeWhere((c) => c.id == courseId);
  host._exams.removeWhere((e) => e.courseId == courseId);
  host._tasks.removeWhere((task) => task.courseId == courseId);
  try {
    await host._persistActiveProfileState();
  } catch (_) {
    host._courses = snapshotCourses;
    host._exams = snapshotExams;
    host._tasks = snapshotTasks;
    host._profiles = snapshotProfiles;
    rethrow;
  }
  host._currentLiveCourseId = null;
  host._notifyStateChanged();
  unawaited(host._syncExamReminders());
  host._analytics.logEventLater(
    name: 'course_deleted',
    parameters: {'remaining_course_count': host._courses.length},
  );
  host._updateLiveActivity();
}
