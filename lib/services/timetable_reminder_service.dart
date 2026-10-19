import '../models/class_reminder.dart';
import '../models/timetable_settings.dart';

/// 上课提醒写入口需要的最小依赖面。
///
/// 由 `TimetableProvider` 侧的适配器实现：读当前设置、走统一设置写入口
/// （含落盘失败回滚）、走统一 mutation 串行队列、写后重排考试提醒。
/// 服务本身不碰 provider 私有字段，可用假端口单测。
abstract interface class TimetableReminderPort {
  TimetableSettings get settings;
  Future<void> updateSettings(TimetableSettings settings);
  Future<T> runMutation<T>(Future<T> Function() operation);
  void syncExamReminders();
}

/// 上课提醒域用例：设置/覆盖一次提醒、取消一次提醒。
///
/// 2026-10-19 从 `TimetableProvider` 的上课提醒族方法搬出（连同读-改-写收口
/// `_mutateSettings`）。写入纪律保持原样：条目不直接改列表，而是以门内最新设置
/// 为基准整份写回，落盘失败由设置写入口回滚并上抛。
class TimetableReminderService {
  TimetableReminderService(this._port);

  final TimetableReminderPort _port;

  /// 以「当前真源」为基准做一次读-改-写，整段在同一次持锁里完成。
  ///
  /// 原先的写法是在门外先 `final current = settings;`，算好新值再
  /// `await updateSettings(current.copyWith(...))`；而 `updateSettings` 在门内
  /// 把设置**整份替换**，于是从取快照到真正拿到锁之间落地的任何写入（另一节课
  /// 的提醒、日期规则自动套用、外观 250ms 防抖保存）都会被这份旧快照覆盖，
  /// 而两个调用方都收到「成功」返回。门内再读一次才是唯一安全的基准。
  Future<void> _mutateSettings(
    TimetableSettings Function(TimetableSettings current) update,
  ) {
    return _port.runMutation(
      () => _port.updateSettings(update(_port.settings)),
    );
  }

  /// 设置（或覆盖）某节课某天的提醒；同课同日只保留一条。
  Future<void> setClassReminder(ClassReminderEntry entry) async {
    await _mutateSettings((current) {
      final rest =
          current.classReminders
              .where(
                (existing) =>
                    !(existing.courseId == entry.courseId &&
                        existing.date == entry.date),
              )
              .toList()
            ..add(entry)
            ..sort((a, b) {
              final byDate = a.date.compareTo(b.date);
              if (byDate != 0) {
                return byDate;
              }
              return a.minuteOfDay.compareTo(b.minuteOfDay);
            });
      return current.copyWith(classReminders: rest);
    });
    _port.syncExamReminders();
  }

  /// 取消某节课某天的提醒；不存在时静默幂等。
  Future<void> removeClassReminder(String courseId, String date) async {
    var changed = false;
    await _mutateSettings((current) {
      final rest = current.classReminders
          .where(
            (existing) =>
                !(existing.courseId == courseId && existing.date == date),
          )
          .toList();
      changed = rest.length != current.classReminders.length;
      if (!changed) {
        return current;
      }
      return current.copyWith(classReminders: rest);
    });
    if (!changed) {
      return;
    }
    _port.syncExamReminders();
  }
}
