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
  // 只有课程**显式绑定**时间方案时才做节次校验：绑定方案缺节次是「写不进」的硬错误
  // （课卡无处取钟点）。未绑定时课程自带钟点是唯一真源，地点分组/日期规则/激活方案
  // 都只是 apply 时的**建议**——溢出由 applyLocationTimeRulesToActiveProfile 计数
  // 报告，不在写入时拒绝（否则钟点齐全、只是不匹配当前方案的课会被莫名拒掉）。
  if (course.timeSchemeIdOverride != null) {
    final validationMessage = host.validateCourseTimeSchemeOverride(
      timeSchemeId: course.timeSchemeIdOverride,
      startSection: course.startSection,
      endSection: course.endSection,
    );
    if (validationMessage != null) {
      throw ArgumentError(validationMessage);
    }
  } else {
    // main 侧合入的最小健全性：只拦写不进的脏数据，不拦超作息（见上注）。
    final minimalMessage = TimetableProvider._validateUnboundCourseSections(
      startSection: course.startSection,
      endSection: course.endSection,
    );
    if (minimalMessage != null) {
      throw ArgumentError(minimalMessage);
    }
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

/// 「清空当前课表」（原 `timetable_provider.dart:3821-3839`）—— 本族影响面最大的写入口。
///
/// `_courses = []` 清掉整份课表，再 `_tasks.removeWhere((task) => task.courseId != null)`
/// 顺手摘掉所有挂在课程上的作业，然后 `await _persistActiveProfileState()`。原先没有
/// try/catch，而调用方 `timetable_profiles_screen.dart:204-216` 也没有 try/catch：
/// 落盘失败时既没有「已清空」也没有失败提示（用户只看到"点了没反应"），内存却是空的、
/// 盘上还是满的，而 `_persistActiveProfileState()` 开头已经把空课程与空作业并进了
/// `_profiles` —— 下一次任意成功写入（切周、加课、30 秒一次的 `syncTemporalContext`
/// 心跳）会把「整份课表没了 + 全部课程作业没了」永久坐实。一次没落成功的"清空"
/// 会延迟成真，而用户从来没第二次确认过它。
///
/// 考试（`_exams`）这里刻意**不**跟着清：`deleteCourse` 会连带删考试，而"清空课表"后
/// 用户往往马上要重新导入课表，考试条目留着才可能接得上。这条差异是有意的，不动语义，
/// 只补回滚。
Future<bool> _timetableClearActiveProfileCourses(TimetableProvider host) async {
  await host.initialize();
  final clearedCourseCount = host._courses.length;
  if (clearedCourseCount == 0) {
    return false;
  }

  final snapshotCourses = List<Course>.from(host._courses);
  final snapshotTasks = List<CourseTask>.from(host._tasks);
  final snapshotProfiles = List<TimetableProfile>.from(host._profiles);
  host._courses = [];
  host._tasks.removeWhere((task) => task.courseId != null);
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
  host._analytics.logEventLater(
    name: 'courses_cleared',
    parameters: {'cleared_course_count': clearedCourseCount},
  );
  await host._updateLiveActivity();
  return true;
}

/// 删一条作业（原 `timetable_provider.dart:2600-2632`）—— 落盘失败要整体退回。
///
/// 这个写入口的越界处在下面那段「作业标记来源」的处理：用户点的是「删这条作业」，
/// 但它会顺手把**另一条记录**（那门课 `sessionNotes` 里对应周的 `hasHomework`）
/// 改成 false，然后才 `await _persistActiveProfileState()`。按
/// `course_group_repository.dart:15` 与 `schedule_item_repository.dart:52` 写明的
/// 边界 —— 只有「内存里被改掉的不是用户刚亲口确认的那一条」才需要回滚 ——
/// 这里必须回滚（`toggleTaskCompleted` / `updateTask` 改的都是用户点名那条，
/// 按同一条判据**不该**回滚，缺的只是把落盘失败报给用户）。
///
/// 不回滚的后果与 `_timetableDeleteCourse` 同族：作业停在「已删」而盘上还有，
/// 那门课的周标记停在「没作业」而盘上还是 true，而 `_persistActiveProfileState`
/// 第一步的 `_mergeActiveProfileIntoProfilesList` 已经把改过的课程并进 `_profiles`，
/// 下一次任意成功写入把「这门课从来没布置过作业」坐实。
Future<void> _timetableDeleteTask(TimetableProvider host, String taskId) async {
  final index = host._tasks.indexWhere((task) => task.id == taskId);
  if (index == -1) {
    return;
  }
  final snapshotTasks = List<CourseTask>.from(host._tasks);
  final snapshotCourses = List<Course>.from(host._courses);
  final snapshotProfiles = List<TimetableProfile>.from(host._profiles);
  final task = host._tasks[index];
  if (task.source == CourseTaskSource.homeworkMark &&
      task.courseId != null &&
      task.sourceWeek != null) {
    final courseIndex = host._courses.indexWhere(
      (course) => course.id == task.courseId,
    );
    if (courseIndex != -1) {
      final course = host._courses[courseIndex];
      final note = course.sessionNoteForWeek(task.sourceWeek!);
      if (note != null) {
        host._courses[courseIndex] = course.copyWith(
          sessionNotes: course.withSessionNote(
            task.sourceWeek!,
            note.copyWith(hasHomework: false),
          ),
        );
      }
    }
  }
  host._tasks.removeAt(index);
  try {
    await host._persistActiveProfileState();
  } catch (_) {
    host._tasks = snapshotTasks;
    host._courses = snapshotCourses;
    host._profiles = snapshotProfiles;
    rethrow;
  }
  host._notifyStateChanged();
  host._analytics.logEventLater(
    name: 'task_deleted',
    parameters: {'remaining_task_count': host._tasks.length},
  );
}
