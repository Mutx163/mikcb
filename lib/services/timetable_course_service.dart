import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../domain/course_domain.dart';
import '../models/course.dart';
import '../models/course_task.dart';
import '../models/exam.dart';
import '../models/timetable_profile.dart';

/// 课程与作业写入口需要的最小宿主面。
///
/// 服务不 import `TimetableProvider`：这些成员在宿主侧都是现成的 getter/setter 或
/// 一行适配，所以整族写入口可以用假端口钉死在单测里
/// （`test/services/timetable_course_service_test.dart`），不必拉起 Provider。
abstract interface class TimetableCoursePort {
  List<Course> get courses;
  set courses(List<Course> value);

  List<CourseTask> get tasks;
  set tasks(List<CourseTask> value);

  List<Exam> get exams;
  set exams(List<Exam> value);

  List<TimetableProfile> get profiles;
  set profiles(List<TimetableProfile> value);

  /// 当前学期周数：课程周次归一要拿它夹上下界。
  int get semesterWeekCount;

  Course? getCourseById(String id);

  /// 课程在第 [week] 周那次上课的日历日期（课程作业的到期日就取它）。
  DateTime? dateForCourseOccurrence(Course course, int week);

  /// 课程**显式绑定**时间方案时的节次校验：绑定方案缺节次是「写不进」的硬错误
  /// （课卡无处取钟点）。
  String? validateCourseTimeSchemeOverride({
    String? timeSchemeId,
    required int startSection,
    required int endSection,
  });

  /// 把课程钟点按「生效方案」补齐（未绑定时课程自带钟点是唯一真源）。
  Course syncCourseWithEffectiveTimeScheme(Course course);

  /// 实时活动测试夹具：这类记录不走方案补齐，写入路径要原样放行。
  bool isLiveTestingFixture(Course course);

  /// 教师/地点历史各是一条**自己的落盘**，所以必须纳进写入口的保护区
  /// （见 [TimetableCourseService.update] 的注释）；两者都是幂等的。
  Future<void> recordTeacher(String teacher);
  Future<void> recordLocation(String location);

  /// 把当前设置与活动课表落盘；失败时抛错，由本服务回滚。
  Future<void> persistActiveProfileState();

  Future<void> initialize();

  void clearCurrentLiveCourseId();

  void notifyStateChanged();

  void logEvent(String name, Map<String, Object> parameters);

  /// 课程增删会改变考试提醒的派生列表，写完后要重新同步原生提醒。
  Future<void> syncExamReminders();

  Future<void> updateLiveActivity();
}

/// 课程、课程组与课程作业（任务）族的读写实现 —— **只有这一份定义**。
///
/// 2026-10-20 把三处合到一起（F3 两处 + F4 一处）：
///
/// - 分片 `providers/timetable/course_repository.dart`（248 行）里的四个写入口；
/// - 分片 `providers/timetable/course_group_repository.dart`（178 行）里的整组
///   增删改 —— 它写的是同一批状态（课程/考试/作业/档案）、用同一批钩子，
///   合并成一个服务才不用重复注入同一个端口；
/// - 父文件里的同族方法与规则：`addCourse` 的整段实现、`addTask` / `updateTask` /
///   `toggleTaskCompleted`、作业归一与校验、`_syncHomeworkTasksWithCourses`
///   的作业重算、`_normalizeCourse` 的课程归一、以及"清空当前课表"的实现。
///
/// 宿主只留一行委托与写盘门（`_runMutation` 仍在 provider）：服务的每个入口假定
/// **已经站在写盘门内**，不要在服务里再包一层门。
///
/// 落盘失败回滚的判据与写作纪律相同：**内存里被改掉的，是不是用户刚刚亲口确认的
/// 那一条**。
///
/// - [update]：改一条会把共享字段广播给同组其它课次、还会重算作业，落盘失败时那些
///   都要退回；[delete] 除了摘掉这门课，还连带摘掉记在它名下的考试与作业 ——
///   用户确认的是"删这门课"。
/// - [deleteGroup] / [updateGroup]：删整组会连带摘掉挂在这组课上的考试与作业
///   （用户点的是"删课程"，不是"删我的期中考试"）；整组替换是"改一批 + 剪孤儿
///   作业"，失败就要一起退回，否则留下的是"旧课次没了、新课次没落成功"的半套。
/// - [clearActiveProfileCourses]：一次清掉整份课表与所有挂在课程上的作业，是本族
///   影响面最大的写入口（考试刻意不清：清空后用户往往马上重新导入，考试留着才接得上）。
/// - [deleteTask]：用户点的是"删这条作业"，它却会顺手把**另一条记录**（那门课
///   `sessionNotes` 里对应周的 `hasHomework`）改成 false，所以也必须回滚。
/// - [add] / [addGroup] / [addTask] / [updateTask] / [toggleTaskCompleted] 改的就是
///   用户刚填的那些，**不回滚**：表单已经报了「保存失败」，再把整张表单清空是更糟的
///   体验。这条口径写在这里，是为了让后面读到 [deleteGroup] 的人明白为什么两兄弟
///   处理不同 —— 不是漏了一处。
///
/// 回归钉：`test/services/timetable_course_service_test.dart`（假端口）与存量的
/// `test/providers/course_write_rollback_test.dart` 等本族用例。
class TimetableCourseService {
  const TimetableCourseService._();

  /// 未绑方案时仍然要拦的硬上限：节次编号超过它就是脏数据。
  static const int maxUnboundEndSection = 30;

  /// 课程归一：trim 文本、把历史遗留的单条备注提升成共享描述、周次夹到学期内。
  static Course normalize(Course course, {required int semesterWeekCount}) {
    final trimmedDescription = course.description?.trim();
    final trimmedNote = course.note?.trim();
    final resolvedDescription =
        (trimmedDescription != null && trimmedDescription.isNotEmpty)
        ? trimmedDescription
        // Promote legacy per-entry note into the shared course description.
        : ((trimmedNote != null && trimmedNote.isNotEmpty)
              ? trimmedNote
              : null);
    final normalizedWeeks = Course.normalizeWeeks(
      startWeek: course.startWeek,
      endWeek: course.endWeek,
      maxWeek: semesterWeekCount,
    );
    return course.copyWith(
      name: course.name.trim(),
      shortName: course.shortName?.trim().isEmpty == true
          ? null
          : course.shortName?.trim(),
      teacher: course.teacher.trim(),
      location: course.location.trim(),
      description: resolvedDescription,
      note: (trimmedNote != null && trimmedNote.isNotEmpty)
          ? trimmedNote
          : null,
      startWeek: normalizedWeeks.startWeek,
      endWeek: normalizedWeeks.endWeek,
    );
  }

  /// 未绑定时间方案时的最小健全性：只拦写不进的脏数据，不拦超作息。
  ///
  /// 超作息由 `applyLocationTimeRulesToActiveProfile` 计数报告，不在写入时拒绝 ——
  /// 否则钟点齐全、只是不匹配当前方案的课会被莫名拒掉。
  static String? validateUnboundSections({
    required int startSection,
    required int endSection,
  }) {
    if (startSection < 1 || endSection < startSection) {
      return 'course_sections_invalid';
    }
    if (endSection > maxUnboundEndSection) {
      return 'course_sections_invalid';
    }
    return null;
  }

  /// 加一门课（原 `TimetableProvider.addCourse`）：改的就是用户刚填的那条，
  /// **刻意不回滚**，与 [update] 的判据相反。
  static Future<void> add(TimetableCoursePort port, Course course) async {
    _validateSections(port, course);
    final normalized = normalize(
      course,
      semesterWeekCount: port.semesterWeekCount,
    );
    final normalizedCourse = port.isLiveTestingFixture(normalized)
        ? normalized
        : port.syncCourseWithEffectiveTimeScheme(normalized);
    final existingSharedCourse = port.courses.cast<Course?>().firstWhere(
      (item) =>
          item != null &&
          CourseDomain.sharedKey(item) == CourseDomain.sharedKey(normalizedCourse),
      orElse: () => null,
    );
    final preparedCourse = existingSharedCourse == null
        ? normalizedCourse
        : CourseDomain.applySharedFields(normalizedCourse, existingSharedCourse);

    port.courses = <Course>[...port.courses, preparedCourse];
    await syncHomeworkTasksWithCourses(port);
    await port.persistActiveProfileState();
    await port.recordTeacher(preparedCourse.teacher);
    await port.recordLocation(preparedCourse.location);
    port.clearCurrentLiveCourseId();
    port.notifyStateChanged();
    port.logEvent('course_created', {
      'day_of_week': preparedCourse.dayOfWeek,
      'section_count': preparedCourse.sectionCount,
      'has_short_name': preparedCourse.shortName?.isNotEmpty == true ? 1 : 0,
    });
    unawaited(port.updateLiveActivity());
  }

  /// 改一门课（原分片 `course_repository.dart` 的 `_timetableUpdateCourse`）。
  static Future<void> update(
    TimetableCoursePort port,
    Course course, {
    String? previousSharedName,
  }) async {
    final currentCourses = List<Course>.from(port.courses);
    final index = currentCourses.indexWhere((item) => item.id == course.id);
    if (index == -1) {
      return;
    }
    _validateSections(port, course);
    final normalized = normalize(
      course,
      semesterWeekCount: port.semesterWeekCount,
    );
    final normalizedCourse = port.isLiveTestingFixture(normalized)
        ? normalized
        : port.syncCourseWithEffectiveTimeScheme(normalized);
    final originalCourse = currentCourses[index];
    final previousKey = buildSharedCourseNameKey(
      previousSharedName ?? originalCourse.name,
    );
    final newKey = CourseDomain.sharedKey(normalizedCourse);

    // 从这里开始动内存：本方法会改同组其它课次，也会重算作业，失败时都要退回。
    final snapshotCourses = List<Course>.from(currentCourses);
    final snapshotTasks = List<CourseTask>.from(port.tasks);
    final snapshotProfiles = List<TimetableProfile>.from(port.profiles);

    // ⚠️ 保护区要从这里开始（2026-10-07 补）。`recordTeacher` / `recordLocation`
    // 各自会落一份盘，也就是说**它们自己也要落盘**。原先把 try 放在它们之后，
    // 于是这两条 await 抛错时：课程已替换、共享字段已广播给同组其它课次、
    // 教师/地点记录已追加进内存，而三份快照一份都不退、也不通知 ——
    // 用户看到的是「更新课程报错了，但课已经变了，而且没有任何提示」。
    //
    // 这两个调用是幂等的（`if (_teacherRecords.contains(teacher)) return;`），
    // 把它们纳入保护区不需要额外补偿：退回去之后再调一次是同参 no-op。
    try {
      final nextCourses = List<Course>.from(currentCourses);
      nextCourses[index] = normalizedCourse;
      for (var i = 0; i < nextCourses.length; i++) {
        if (i == index) {
          continue;
        }
        final current = nextCourses[i];
        final currentKey = CourseDomain.sharedKey(current);
        if (currentKey == previousKey || currentKey == newKey) {
          nextCourses[i] = CourseDomain.applySharedFields(
            current,
            normalizedCourse,
          );
        }
      }
      // 一次性赋值，落在第一条 await 之前：内存要么全是新的、要么全是旧的。
      port.courses = nextCourses;
      await port.recordTeacher(normalizedCourse.teacher);
      await port.recordLocation(normalizedCourse.location);
      await syncHomeworkTasksWithCourses(port);
      await port.persistActiveProfileState();
    } catch (_) {
      port.courses = snapshotCourses;
      port.tasks = snapshotTasks;
      port.profiles = snapshotProfiles;
      rethrow;
    }
    port.clearCurrentLiveCourseId();
    port.notifyStateChanged();
    unawaited(port.syncExamReminders());
    port.logEvent('course_updated', {
      'day_of_week': normalizedCourse.dayOfWeek,
      'section_count': normalizedCourse.sectionCount,
      'has_short_name': normalizedCourse.shortName?.isNotEmpty == true ? 1 : 0,
    });
    unawaited(port.updateLiveActivity());
  }

  /// 删一门课（原分片 `course_repository.dart` 的 `_timetableDeleteCourse`）。
  ///
  /// `deleteCourse` 除了摘掉这门课，还连带摘掉记在它名下的考试与作业 ——
  /// 用户确认的是"删这门课"，那些不是他删的东西；三份列表 + 课表镜像都要能退回。
  static Future<void> delete(TimetableCoursePort port, String courseId) async {
    final snapshotCourses = List<Course>.from(port.courses);
    final snapshotExams = List<Exam>.from(port.exams);
    final snapshotTasks = List<CourseTask>.from(port.tasks);
    final snapshotProfiles = List<TimetableProfile>.from(port.profiles);
    port.courses = port.courses.where((course) => course.id != courseId).toList();
    port.exams = port.exams.where((exam) => exam.courseId != courseId).toList();
    port.tasks = port.tasks
        .where((task) => task.courseId != courseId)
        .toList();
    try {
      await port.persistActiveProfileState();
    } catch (_) {
      port.courses = snapshotCourses;
      port.exams = snapshotExams;
      port.tasks = snapshotTasks;
      port.profiles = snapshotProfiles;
      rethrow;
    }
    port.clearCurrentLiveCourseId();
    port.notifyStateChanged();
    unawaited(port.syncExamReminders());
    port.logEvent('course_deleted', {
      'remaining_course_count': port.courses.length,
    });
    unawaited(port.updateLiveActivity());
  }

  /// 删掉一个课程组（同名多课次）—— 连同挂在这组课上的考试与作业一起摘掉。
  ///
  /// 判据同 [delete]：用户点的是"删课程"，不是"删我的期中考试"，
  /// 落盘失败时课程/考试/作业/档案四份都要退回。
  static Future<void> deleteGroup(TimetableCoursePort port, String name) async {
    final key = buildSharedCourseNameKey(name);
    final deletedCourseIds = port.courses
        .where((course) => buildSharedCourseNameKey(course.name) == key)
        .map((course) => course.id)
        .toSet();
    final snapshotCourses = List<Course>.from(port.courses);
    final snapshotExams = List<Exam>.from(port.exams);
    final snapshotTasks = List<CourseTask>.from(port.tasks);
    final snapshotProfiles = List<TimetableProfile>.from(port.profiles);
    port.courses = port.courses
        .where((course) => !deletedCourseIds.contains(course.id))
        .toList();
    port.exams = port.exams
        .where((exam) => !deletedCourseIds.contains(exam.courseId))
        .toList();
    port.tasks = port.tasks
        .where((task) => !deletedCourseIds.contains(task.courseId))
        .toList();
    try {
      await port.persistActiveProfileState();
    } catch (_) {
      port.courses = snapshotCourses;
      port.exams = snapshotExams;
      port.tasks = snapshotTasks;
      port.profiles = snapshotProfiles;
      rethrow;
    }
    port.clearCurrentLiveCourseId();
    port.notifyStateChanged();
    unawaited(port.syncExamReminders());
    port.logEvent('course_group_deleted', {
      'remaining_course_count': port.courses.length,
    });
    unawaited(port.updateLiveActivity());
  }

  /// 整组替换（同一门课的多条课次一起改）。
  ///
  /// 保护区必须覆盖 `recordTeacher` / `recordLocation`（2026-10-07 补，与 [update]
  /// 同因）：它们各自会落一份盘。原先把 try 放在循环之后，于是第二条课次的教师名
  /// 写盘失败时：旧课次已经整组摘掉、新课次只加了一半、作业还没剪，而三份快照
  /// 一份都不退、也不通知。
  static Future<void> updateGroup(
    TimetableCoursePort port,
    String originalName,
    List<Course> updatedCourses,
  ) async {
    final key = buildSharedCourseNameKey(originalName);
    if (updatedCourses.isEmpty) {
      // 必须挡在摘除旧课次之前：空集合会让下面的 `updatedCourses.first` 抛
      // StateError，而那时整组课程已经被摘掉——既没落库也没通知，界面仍显示
      // 旧组、内存里整组消失，下一次任意成功写入就把「整组没了」落盘。
      // 与 [addGroup] 的 isEmpty 守卫同一口径（调用方目前都自带非空保证，
      // 这里是服务侧的兜底，防未来新调用方直接踩）。
      return;
    }
    final snapshotCourses = List<Course>.from(port.courses);
    final snapshotTasks = List<CourseTask>.from(port.tasks);
    final snapshotProfiles = List<TimetableProfile>.from(port.profiles);
    try {
      final nextCourses = port.courses
          .where((course) => buildSharedCourseNameKey(course.name) != key)
          .toList();
      final shared = updatedCourses.first;
      for (final course in updatedCourses) {
        final normalized = normalize(
          CourseDomain.applySharedFields(course, shared),
          semesterWeekCount: port.semesterWeekCount,
        );
        nextCourses.add(normalized);
        await port.recordTeacher(normalized.teacher);
        await port.recordLocation(normalized.location);
      }
      port.courses = nextCourses;
      // 剪孤儿作业：挂到已不存在课程上的作业留不住。
      final courseIds = nextCourses.map((course) => course.id).toSet();
      port.tasks = port.tasks
          .where(
            (task) => task.courseId == null || courseIds.contains(task.courseId),
          )
          .toList();
      await syncHomeworkTasksWithCourses(port);
      await port.persistActiveProfileState();
    } catch (_) {
      // 整组替换是「改一批 + 剪孤儿作业」，失败就要一起退回：留下的只会是
      // "旧课次没了、新课次没落成功"的半套状态。
      port.courses = snapshotCourses;
      port.tasks = snapshotTasks;
      port.profiles = snapshotProfiles;
      rethrow;
    }
    port.clearCurrentLiveCourseId();
    port.notifyStateChanged();
    unawaited(port.syncExamReminders());
    port.logEvent('course_group_updated', {
      'schedule_count': updatedCourses.length,
      'remaining_course_count': port.courses.length,
    });
    unawaited(port.updateLiveActivity());
  }

  /// 加一组课次（新建一门课的多条课次，只落一次盘）。
  ///
  /// 与 [add] 同口径**不回滚**：内存里那些正是用户刚填的内容。
  /// 先把整组算好、验证全部通过再批量落，避免中途失败留下半套。
  static Future<void> addGroup(
    TimetableCoursePort port,
    List<Course> courses,
  ) async {
    if (courses.isEmpty) {
      return;
    }
    final shared = courses.first;
    final normalizedCourses = <Course>[];
    final teachers = <String>{};
    final locations = <String>{};
    for (final course in courses) {
      // 与 [add] / [update] 同一契约：只校验**显式绑定**的方案，未绑定时课程自带
      // 钟点是唯一真源，不在写入环节拒溢出。
      _validateSections(port, course);
      final normalized = port.syncCourseWithEffectiveTimeScheme(
        normalize(
          CourseDomain.applySharedFields(course, shared),
          semesterWeekCount: port.semesterWeekCount,
        ),
      );
      normalizedCourses.add(normalized);
      if (normalized.teacher.isNotEmpty) {
        teachers.add(normalized.teacher);
      }
      if (normalized.location.isNotEmpty) {
        locations.add(normalized.location);
      }
    }
    port.courses = <Course>[...port.courses, ...normalizedCourses];
    await syncHomeworkTasksWithCourses(port);
    for (final teacher in teachers) {
      await port.recordTeacher(teacher);
    }
    for (final location in locations) {
      await port.recordLocation(location);
    }
    await port.persistActiveProfileState();
    port.clearCurrentLiveCourseId();
    port.notifyStateChanged();
    port.logEvent('course_group_created', {
      'schedule_count': courses.length,
      'remaining_course_count': port.courses.length,
    });
    unawaited(port.updateLiveActivity());
  }

  /// 「清空当前课表」—— 本族影响面最大的写入口。
  ///
  /// 原先没有 try/catch，调用方也没有：落盘失败时既没有「已清空」也没有失败提示
  /// （用户只看到"点了没反应"），内存却是空的、盘上还是满的，而下一次任意成功写入
  /// （切周、加课、30 秒一次的 `syncTemporalContext` 心跳）会把「整份课表没了 +
  /// 全部课程作业没了」永久坐实 —— 一次没落成功的"清空"会延迟成真，而用户从来
  /// 没第二次确认过它。
  ///
  /// 考试（`exams`）这里刻意**不**跟着清：清空课表后用户往往马上要重新导入课表，
  /// 考试条目留着才可能接得上。这条差异是有意的，不动语义，只补回滚。
  static Future<bool> clearActiveProfileCourses(TimetableCoursePort port) async {
    await port.initialize();
    final clearedCourseCount = port.courses.length;
    if (clearedCourseCount == 0) {
      return false;
    }

    final snapshotCourses = List<Course>.from(port.courses);
    final snapshotTasks = List<CourseTask>.from(port.tasks);
    final snapshotProfiles = List<TimetableProfile>.from(port.profiles);
    port.courses = <Course>[];
    port.tasks = port.tasks.where((task) => task.courseId == null).toList();
    try {
      await port.persistActiveProfileState();
    } catch (_) {
      port.courses = snapshotCourses;
      port.tasks = snapshotTasks;
      port.profiles = snapshotProfiles;
      rethrow;
    }
    port.clearCurrentLiveCourseId();
    port.notifyStateChanged();
    port.logEvent('courses_cleared', {
      'cleared_course_count': clearedCourseCount,
    });
    await port.updateLiveActivity();
    return true;
  }

  /// 加一条作业：改的就是用户刚填的那条，**不回滚**。
  static Future<void> addTask(TimetableCoursePort port, CourseTask task) async {
    final normalized = _normalizeTask(task);
    _validateTask(port, normalized);
    port.tasks = _sortTasks(<CourseTask>[...port.tasks, normalized]);
    await port.persistActiveProfileState();
    port.notifyStateChanged();
    port.logEvent('task_created', {
      'has_course': normalized.courseId == null ? 0 : 1,
      'has_due_date': normalized.dueDate == null ? 0 : 1,
    });
  }

  /// 改一条作业：改的是用户点名那条，**不回滚**（缺的只是落盘失败上报）。
  static Future<void> updateTask(
    TimetableCoursePort port,
    CourseTask task,
  ) async {
    final items = List<CourseTask>.from(port.tasks);
    final index = items.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      return;
    }
    final normalized = _normalizeTask(
      task,
    ).copyWith(createdAt: items[index].createdAt, updatedAt: DateTime.now());
    _validateTask(port, normalized);
    items[index] = normalized;
    port.tasks = _sortTasks(items);
    await port.persistActiveProfileState();
    port.notifyStateChanged();
  }

  /// 勾选/取消勾选一条作业：同上，只改用户点名那条。
  static Future<void> toggleTaskCompleted(
    TimetableCoursePort port,
    String taskId,
  ) async {
    final items = List<CourseTask>.from(port.tasks);
    final index = items.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    final current = items[index];
    items[index] = current.copyWith(
      isCompleted: !current.isCompleted,
      updatedAt: DateTime.now(),
    );
    port.tasks = _sortTasks(items);
    await port.persistActiveProfileState();
    port.notifyStateChanged();
  }

  /// 删一条作业：会顺手把**另一条记录**（那门课对应周的 `hasHomework`）改成 false，
  /// 所以落盘失败必须整体退回；不回滚的后果与 [delete] 同族 ——
  /// 作业停在「已删」而盘上还有，那门课的周标记停在「没作业」而盘上还是 true，
  /// 下一次任意成功写入把「这门课从来没布置过作业」坐实。
  static Future<void> deleteTask(
    TimetableCoursePort port,
    String taskId,
  ) async {
    final items = List<CourseTask>.from(port.tasks);
    final index = items.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    final snapshotTasks = List<CourseTask>.from(items);
    final snapshotCourses = List<Course>.from(port.courses);
    final snapshotProfiles = List<TimetableProfile>.from(port.profiles);
    final task = items[index];
    if (task.source == CourseTaskSource.homeworkMark &&
        task.courseId != null &&
        task.sourceWeek != null) {
      final courses = List<Course>.from(port.courses);
      final courseIndex = courses.indexWhere(
        (course) => course.id == task.courseId,
      );
      if (courseIndex != -1) {
        final course = courses[courseIndex];
        final note = course.sessionNoteForWeek(task.sourceWeek!);
        if (note != null) {
          courses[courseIndex] = course.copyWith(
            sessionNotes: course.withSessionNote(
              task.sourceWeek!,
              note.copyWith(hasHomework: false),
            ),
          );
          port.courses = courses;
        }
      }
    }
    items.removeAt(index);
    port.tasks = items;
    try {
      await port.persistActiveProfileState();
    } catch (_) {
      port.tasks = snapshotTasks;
      port.courses = snapshotCourses;
      port.profiles = snapshotProfiles;
      rethrow;
    }
    port.notifyStateChanged();
    port.logEvent('task_deleted', {'remaining_task_count': port.tasks.length});
  }

  /// 按「课程周次备注里的作业标记」重算作业列表（原 `_syncHomeworkTasksWithCourses`）。
  ///
  /// 这是课程与作业之间的唯一同步点：课程备注勾了「有作业」就长出一条作业、
  /// 到期日取该周那次课的日历日期；取消勾选就摘掉。返回作业列表是否变化。
  static Future<bool> syncHomeworkTasksWithCourses(
    TimetableCoursePort port, {
    bool persist = false,
  }) async {
    final before = jsonEncode(port.tasks.map((task) => task.toJson()).toList());
    final existingHomework = port.tasks
        .where((task) => task.source == CourseTaskSource.homeworkMark)
        .toList();
    final next = port.tasks
        .where((task) => task.source != CourseTaskSource.homeworkMark)
        .toList();
    final now = DateTime.now();

    for (final course in port.courses) {
      final notes = course.normalizedSessionNotesMap;
      if (notes == null) {
        continue;
      }
      for (final entry in notes.entries) {
        final note = entry.value;
        if (!note.hasHomework) {
          continue;
        }
        CourseTask? existing;
        for (final candidate in existingHomework) {
          if (candidate.courseId == course.id &&
              candidate.sourceWeek == entry.key) {
            existing = candidate;
            break;
          }
        }
        final noteTitle = note.trimmedText;
        if (noteTitle.isEmpty && existing == null) {
          continue;
        }
        final title = noteTitle.isEmpty ? existing!.title : noteTitle;
        next.add(
          (existing ??
                  CourseTask(
                    id: const Uuid().v4(),
                    title: title,
                    courseId: course.id,
                    sourceWeek: entry.key,
                    source: CourseTaskSource.homeworkMark,
                    createdAt: now,
                    updatedAt: now,
                  ))
              .copyWith(
                title: title,
                courseId: course.id,
                sourceWeek: entry.key,
                dueDate: port.dateForCourseOccurrence(course, entry.key),
                source: CourseTaskSource.homeworkMark,
                updatedAt: now,
              ),
        );
      }
    }

    port.tasks = _sortTasks(next);
    final after = jsonEncode(port.tasks.map((task) => task.toJson()).toList());
    final changed = before != after;
    if (changed && persist) {
      await port.persistActiveProfileState();
    }
    return changed;
  }

  static void _validateSections(TimetableCoursePort port, Course course) {
    if (course.timeSchemeIdOverride != null) {
      final validationMessage = port.validateCourseTimeSchemeOverride(
        timeSchemeId: course.timeSchemeIdOverride,
        startSection: course.startSection,
        endSection: course.endSection,
      );
      if (validationMessage != null) {
        throw ArgumentError(validationMessage);
      }
      return;
    }
    final minimalMessage = validateUnboundSections(
      startSection: course.startSection,
      endSection: course.endSection,
    );
    if (minimalMessage != null) {
      throw ArgumentError(minimalMessage);
    }
  }

  static CourseTask _normalizeTask(CourseTask task) {
    final title = task.title.trim();
    final note = task.note?.trim();
    final courseId = task.courseId?.trim();
    final sourceWeek = task.sourceWeek != null && task.sourceWeek! > 0
        ? task.sourceWeek
        : null;
    return task.copyWith(
      title: title,
      courseId: courseId == null || courseId.isEmpty ? null : courseId,
      sourceWeek: sourceWeek,
      dueDate: task.dueDate == null ? null : CourseTask.dateOnly(task.dueDate!),
      note: note == null || note.isEmpty ? null : note,
      updatedAt: DateTime.now(),
    );
  }

  static void _validateTask(TimetableCoursePort port, CourseTask task) {
    if (task.title.isEmpty) {
      throw ArgumentError('task_title_required');
    }
    if (task.courseId != null && port.getCourseById(task.courseId!) == null) {
      throw ArgumentError('task_course_not_found');
    }
  }

  static List<CourseTask> _sortTasks(List<CourseTask> source) {
    source.sort(CourseTask.compareByDueDate);
    return source;
  }
}
