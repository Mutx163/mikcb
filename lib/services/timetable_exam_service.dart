import '../models/course.dart';
import '../models/exam.dart';
import '../models/timetable_profile.dart';

/// 考试写入口需要的最小依赖面。
///
/// 由 `TimetableProvider` 侧的适配器实现：读/替换考试列表与档案快照（失败
/// 回滚用）、统一 mutation 门、初始化、课程关联校验、落盘、提醒/小组件重推
/// 与埋点。服务本身不碰 provider 私有字段，可用假端口单测。
abstract interface class TimetableExamPort {
  List<Exam> get exams;
  set exams(List<Exam> value);
  List<TimetableProfile> get profiles;
  set profiles(List<TimetableProfile> value);
  Future<void> initialize();
  Future<T> runMutation<T>(Future<T> Function() operation);
  Course? courseForExam(Exam exam);
  Future<void> persistActiveProfileState();
  void notifyStateChanged();
  void syncExamReminders();
  void invalidateHomeWidgetSnapshot();
  void syncHomeWidgetSnapshot();
  void logExamEvent(String name, Map<String, Object> parameters);
}

/// 考试域用例：查询 + 新增/修改/删除。
///
/// 2026-10-19 从 `TimetableProvider` 的考试族方法搬出；写入纪律与提示时序
/// 保持原样：add 失败不回滚（保留用户刚填的内容）；update/delete 失败连
/// 考试列表与档案列表一起回滚并上抛。
class TimetableExamService {
  TimetableExamService(this._port);

  final TimetableExamPort _port;

  List<Exam> getExamsForCourse(String courseId) {
    return _port.exams.where((exam) => exam.courseId == courseId).toList()
      ..sort(Exam.compareByStart);
  }

  List<Exam> getUpcomingExams({int? limit}) {
    final upcoming = _port.exams.where((exam) => !exam.isExpired).toList()
      ..sort(Exam.compareByStart);
    if (limit != null && upcoming.length > limit) {
      return upcoming.sublist(0, limit);
    }
    return upcoming;
  }

  Exam? getNextExam() {
    final upcoming = getUpcomingExams(limit: 1);
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// 当天是否有**未过期**的考试。
  ///
  /// 2026-10-20 补 `!isExpired`：原先只比日期，于是「今天下午看早上那场考完的
  /// 考试」会让星期栏红点亮着，而日视图议程（`_buildDayAgendaItems` 带
  /// `!e.isExpired`）和周网格考试卡（`WeekGridAgendaPlacement.resolve` 同一
  /// 判据）都把它滤掉了 —— 用户看到「有红点、点进去什么都没有」。
  /// 三处现在同一条口径：**考完即消失**（用户 2026-10-20 拍板）。
  bool hasExamOnDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return _port.exams.any((exam) {
      if (exam.isExpired) {
        return false;
      }
      final examDate = DateTime(
        exam.dateTime.year,
        exam.dateTime.month,
        exam.dateTime.day,
      );
      return examDate == target;
    });
  }

  /// 失败**不**回滚是刻意的（与 `addCourse` 同口径）：内存里这条正是用户刚填完的
  /// 内容，表单已弹「保存失败」，回滚等于把他填的一屏清空，比留下它更糟。
  Future<void> addExam(Exam exam) {
    return _port.runMutation(() async {
      await _port.initialize();
      if (_port.courseForExam(exam) == null) {
        throw ArgumentError('linked_course_not_found');
      }
      _port.exams = [..._port.exams, exam];
      await _port.persistActiveProfileState();
      _port.notifyStateChanged();
      _port.syncExamReminders();
      // Native widgets re-read profiles; force a snapshot push so exam line
      // appears without waiting for the next course-boundary refresh.
      _port.invalidateHomeWidgetSnapshot();
      _port.syncHomeWidgetSnapshot();
      _port.logExamEvent('exam_created', {
        'has_location': exam.location?.isNotEmpty == true ? 1 : 0,
        'has_seat': exam.seatNumber?.isNotEmpty == true ? 1 : 0,
      });
    });
  }

  /// 与 [deleteExam] 同一条契约：改内存 → await 落盘 → 失败整体退回并上抛。
  Future<void> updateExam(Exam exam) {
    return _port.runMutation(() async {
      await _port.initialize();
      final index = _port.exams.indexWhere((e) => e.id == exam.id);
      if (index == -1) return;
      final snapshotExams = List<Exam>.from(_port.exams);
      final snapshotProfiles = List<TimetableProfile>.from(_port.profiles);
      final updated = List<Exam>.from(_port.exams);
      updated[index] = exam;
      _port.exams = updated;
      try {
        await _port.persistActiveProfileState();
      } catch (_) {
        _port.exams = snapshotExams;
        _port.profiles = snapshotProfiles;
        rethrow;
      }
      _port.notifyStateChanged();
      _port.syncExamReminders();
      _port.invalidateHomeWidgetSnapshot();
      _port.syncHomeWidgetSnapshot();
      _port.logExamEvent('exam_updated', {'exam_id': exam.id});
    });
  }

  /// 删除考试。
  ///
  /// 落盘失败必须整体退回并上抛（2026-10-07 补）。`_runMutation` 只是互斥锁，
  /// 不含回滚；原先这里是裸的 `removeWhere` → await 落盘 → `notifyListeners()`：
  /// 落盘抛错时条目已从考试列表摘掉、通知被跳过，于是界面仍显示着这一条、
  /// 用户收到「保存失败」，而删除其实已经进了内存。
  ///
  /// 档案列表也要一起退：`persistActiveProfileState` 的第一步就是
  /// `_mergeActiveProfileIntoProfilesList`（早于任何磁盘写入），落盘失败时
  /// 档案里已经是那份没存下的状态，只退考试列表会留下幻影。
  Future<void> deleteExam(String examId) {
    return _port.runMutation(() async {
      await _port.initialize();
      final snapshotExams = List<Exam>.from(_port.exams);
      final snapshotProfiles = List<TimetableProfile>.from(_port.profiles);
      _port.exams = _port.exams.where((e) => e.id != examId).toList();
      try {
        await _port.persistActiveProfileState();
      } catch (_) {
        _port.exams = snapshotExams;
        _port.profiles = snapshotProfiles;
        rethrow;
      }
      _port.notifyStateChanged();
      _port.syncExamReminders();
      _port.invalidateHomeWidgetSnapshot();
      _port.syncHomeWidgetSnapshot();
      _port.logExamEvent('exam_deleted', {
        'remaining_exam_count': _port.exams.length,
      });
    });
  }
}
