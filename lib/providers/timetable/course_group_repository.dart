part of '../timetable_provider.dart';

/// 课程组（同名多课次）的整组写操作。
///
/// 从上帝类移出（原 `timetable_provider.dart:2593-2613`、`:2840-2878`、`:2888-2935`），
/// 并把 delete / update 两处补上本仓的写入纪律「快照 → await 落库 → catch 回滚 +
/// rethrow」。判据是**内存里被改掉的是不是用户刚刚亲口确认的那一条**：
///
/// - `deleteCourseGroup` / `updateCourseGroup` 会连带改别的记录 —— 删除整组时一并
///   `_exams.removeWhere` / `_tasks.removeWhere` 摘掉挂在这组课上的考试与作业，
///   而用户点的是"删课程"，不是"删我的期中考试"。这两处原先都没有 try/catch，
///   且 `_persistActiveProfileState()` 开头的 `_mergeActiveProfileIntoProfilesList()`
///   已经把删过的课程/考试/作业并进 `_profiles`，所以抛错之后内存里连课表镜像都是
///   删过的状态，下一次任意成功写入就把「整组没了 + 考试没了 + 作业没了」坐实到盘上。
/// - 单条 `addCourse` / `addCourseGroup` 失败时**不回滚**是有意为之：内存里那些
///   正是用户刚填的内容，表单已经报了「保存失败」，把整张表单清空是更糟的体验。
///   这条口径写在这里，是为了让后面读到 `deleteCourseGroup` 的人明白为什么两兄弟
///   处理不同 —— 不是漏了一处。
Future<void> _timetableDeleteCourseGroup(TimetableProvider host, String name) async {
  final key = buildSharedCourseNameKey(name);
  final deletedCourseIds = host._courses
      .where((c) => buildSharedCourseNameKey(c.name) == key)
      .map((c) => c.id)
      .toSet();
  // 三份列表 + 课表镜像（`_persistActiveProfileState` 会把它们并进去）都要能退回。
  final snapshotCourses = List<Course>.from(host._courses);
  final snapshotExams = List<Exam>.from(host._exams);
  final snapshotTasks = List<CourseTask>.from(host._tasks);
  final snapshotProfiles = List<TimetableProfile>.from(host._profiles);
  host._courses.removeWhere((c) => deletedCourseIds.contains(c.id));
  host._exams.removeWhere((e) => deletedCourseIds.contains(e.courseId));
  host._tasks.removeWhere((task) => deletedCourseIds.contains(task.courseId));
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
    name: 'course_group_deleted',
    parameters: {'remaining_course_count': host._courses.length},
  );
  host._updateLiveActivity();
}

Future<void> _timetableUpdateCourseGroup(
  TimetableProvider host,
  String originalName,
  List<Course> updatedCourses,
) async {
  final key = buildSharedCourseNameKey(originalName);
  if (updatedCourses.isEmpty) {
    // 必须挡在 removeWhere 之前：空集合会让下面的 `updatedCourses.first` 抛
    // StateError，而那时整组课程已经被摘掉——既没落库也没 notify，界面仍显示
    // 旧组、内存里整组消失，下一次任意成功写入就把「整组没了」落盘。
    // 与 addCourseGroup 的 isEmpty 守卫同一口径（调用方目前都自带非空保证，
    // 这里是 provider 侧的兜底，防未来新调用方直接踩）。
    return;
  }
  final snapshotCourses = List<Course>.from(host._courses);
  final snapshotTasks = List<CourseTask>.from(host._tasks);
  final snapshotProfiles = List<TimetableProfile>.from(host._profiles);
  // Remove old entries for this group.
  host._courses.removeWhere((c) => buildSharedCourseNameKey(c.name) == key);
  // Add the updated entries, applying shared fields.
  final shared = updatedCourses.first;
  for (final course in updatedCourses) {
    final normalized = host._normalizeCourse(
      CourseDomain.applySharedFields(course, shared),
    );
    host._courses.add(normalized);
    await host._recordTeacherImpl(normalized.teacher);
    await host._recordLocationImpl(normalized.location);
  }
  host._tasks.removeWhere(
    (task) =>
        task.courseId != null &&
        !host._courses.any((course) => course.id == task.courseId),
  );
  await host._syncHomeworkTasksWithCourses();
  try {
    await host._persistActiveProfileState();
  } catch (_) {
    // 整组替换是「改一批 + 剪孤儿作业」，失败就要一起退回：留下的只会是
    // "旧课次没了、新课次没落成功"的半套状态。
    host._courses = snapshotCourses;
    host._tasks = snapshotTasks;
    host._profiles = snapshotProfiles;
    rethrow;
  }
  host._currentLiveCourseId = null;
  host._notifyStateChanged();
  unawaited(host._syncExamReminders());
  host._analytics.logEventLater(
    name: 'course_group_updated',
    parameters: {
      'schedule_count': updatedCourses.length,
      'remaining_course_count': host._courses.length,
    },
  );
  host._updateLiveActivity();
}

Future<void> _timetableAddCourseGroup(
  TimetableProvider host,
  List<Course> courses,
) async {
  if (courses.isEmpty) {
    return;
  }
  final shared = courses.first;
  // 先收集到临时列表，验证全部通过后再批量添加，避免中途失败导致状态不一致
  final normalizedCourses = <Course>[];
  final teachers = <String>{};
  final locations = <String>{};
  for (final course in courses) {
    // 与 addCourse/updateCourse 同一契约：只校验**显式绑定**的方案，未绑定时
    // 课程自带钟点是唯一真源，不在写入环节拒溢出。
    if (course.timeSchemeIdOverride != null) {
      final validationMessage = host.validateCourseTimeSchemeOverride(
        timeSchemeId: course.timeSchemeIdOverride,
        startSection: course.startSection,
        endSection: course.endSection,
      );
      if (validationMessage != null) {
        throw ArgumentError(validationMessage);
      }
    }
    final normalized = host._syncCourseWithEffectiveTimeScheme(
      host._normalizeCourse(CourseDomain.applySharedFields(course, shared)),
    );
    normalizedCourses.add(normalized);
    if (normalized.teacher.isNotEmpty) teachers.add(normalized.teacher);
    if (normalized.location.isNotEmpty) locations.add(normalized.location);
  }
  // 所有验证通过，批量添加
  host._courses.addAll(normalizedCourses);
  await host._syncHomeworkTasksWithCourses();
  for (final teacher in teachers) {
    await host._recordTeacherImpl(teacher);
  }
  for (final location in locations) {
    await host._recordLocationImpl(location);
  }
  await host._persistActiveProfileState();
  host._currentLiveCourseId = null;
  host._notifyStateChanged();
  host._analytics.logEventLater(
    name: 'course_group_created',
    parameters: {
      'schedule_count': courses.length,
      'remaining_course_count': host._courses.length,
    },
  );
  host._updateLiveActivity();
}
