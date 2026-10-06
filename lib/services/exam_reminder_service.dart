import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/schedule_item_expander.dart';
import '../logging/app_debug_log.dart';
import '../models/course.dart';
import '../models/exam.dart';
import '../models/schedule_item.dart';
import '../utils/timed_method_channel.dart';

/// One scheduled fire point for an exam reminder (local wall clock).
class ExamReminderFire {
  const ExamReminderFire({
    required this.examId,
    required this.offsetMinutes,
    required this.fireAtMillis,
    required this.examStartMillis,
    required this.title,
    required this.body,
    required this.requestCode,
  });

  final String examId;
  final int offsetMinutes;
  final int fireAtMillis;
  final int examStartMillis;
  final String title;
  final String body;
  final int requestCode;

  /// 只换 PendingIntent 身份，其余字段原样保留。
  ///
  /// 用于 [ExamReminderService.assignDistinctRequestCodes] 的碰撞消解：原生侧的
  /// 取消/去重一律走快照里存着的这个值（ExamReminderScheduler.kt:247-255、:285），
  /// 从不按 examId 重新计算，所以改码不会让旧闹钟取消不掉。
  ExamReminderFire withRequestCode(int code) => ExamReminderFire(
    examId: examId,
    offsetMinutes: offsetMinutes,
    fireAtMillis: fireAtMillis,
    examStartMillis: examStartMillis,
    title: title,
    body: body,
    requestCode: code,
  );

  Map<String, dynamic> toNativeMap() {
    return {
      'examId': examId,
      'offsetMinutes': offsetMinutes,
      'fireAtMillis': fireAtMillis,
      'examStartMillis': examStartMillis,
      'title': title,
      'body': body,
      'requestCode': requestCode,
    };
  }
}

/// Builds fire points and syncs them to the native AlarmManager scheduler.
class ExamReminderService {
  static const MethodChannel _channel = TimedMethodChannel(
    'com.mutx163.qingyu/exam_reminder',
  );

  /// Namespace for PendingIntent request codes (must match native cancel).
  static const int requestCodeNamespace = 0x46000000;

  static final ExamReminderService _instance = ExamReminderService._internal();
  factory ExamReminderService() => _instance;
  ExamReminderService._internal();

  /// Stable request code shared with native cancel/schedule.
  static int stableRequestCode(String examId, int offsetMinutes) {
    final key = '$examId#$offsetMinutes';
    var hash = 0x811c9dc5;
    for (final codeUnit in key.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return requestCodeNamespace | (hash & 0x00ffffff);
  }

  /// 给一整批触发点分配**互不重复**的 requestCode。
  ///
  /// 上面的散列只留了 24 位（`& 0x00ffffff`），唯一个数 16,777,216。碰撞的后果不是
  /// 理论问题：原生用 `PendingIntent.getBroadcast(ctx, fire.requestCode, …,
  /// FLAG_UPDATE_CURRENT)`（ExamReminderScheduler.kt:406-411），两条 fire 的 PI
  /// 身份相同就会被后写入的那条整体顶掉触发时刻 → 更早的那条提醒静默丢失。
  ///
  /// 触发规模**实测过**（不是生日悖论估算）：本仓 `schedule:<uuid>#<date>` 这种键
  /// 形状在 4000 条并发 fire 时零碰撞，10000 条出现 2 次，30000 条 37 次 —— 这个
  /// FNV 变体对结构化键的分布明显好于随机，要几十条「每天重复 + 多个提前量」的
  /// 日程铺满一整年才会开始碰到。所以本方法属**加固**：代价十几行，收益是把
  /// 「某节课的提醒从来没响过」这种查不出来的故障彻底堵死。
  ///
  /// 分配前先按 (examId, offsetMinutes, fireAtMillis) 排序：碰撞消解的结果只取决于
  /// 这一**集合**，与调用方的拼装顺序无关，因此同一批提醒每次重建都拿到同一套
  /// 编码（原生 reconcile 是「先全量取消旧的、再排新的」，编码抖动本身也安全）。
  static List<ExamReminderFire> assignDistinctRequestCodes(
    Iterable<ExamReminderFire> fires,
  ) {
    final ordered = fires.toList()
      ..sort((left, right) {
        final byId = left.examId.compareTo(right.examId);
        if (byId != 0) return byId;
        final byOffset = left.offsetMinutes.compareTo(right.offsetMinutes);
        if (byOffset != 0) return byOffset;
        return left.fireAtMillis.compareTo(right.fireAtMillis);
      });
    final taken = <int>{};
    final result = <ExamReminderFire>[];
    for (final fire in ordered) {
      // 候选码取 **fire 自己携带的那一个**，不能按 (examId, offsetMinutes)
      // 重算：三个生产源里日程（:241）与考试（:365）恰好等于重算值，单节课
      // 提醒不是 —— 它的真实码含 `minuteOfDay`（class_reminder_service.dart:110），
      // `offsetMinutes` 则被刻意填成 0（同文件 :100-107 解释了为什么必须这样填），
      // 而它经 `reconcile` 的 `additionalFires`（:405-413）合进同一个批次。
      // 重算的后果是登记表记了一个**根本不会发出去**的码：`probe == 0` 时原样
      // 返回 `fire`，实际发出去的码从未进 `taken`，别的 fire 撞上它时不被判为
      // 冲突 → 两条同一 PendingIntent 身份 → 原生 `getBroadcast
      // (FLAG_UPDATE_CURRENT)` 让后写入的整条顶掉前一条，正是上面声称要堵死的故障。
      var code = fire.requestCode;
      var probe = 0;
      final registered = taken.add(code);
      if (!registered) {
        do {
          probe++;
          code = stableRequestCode(
            '${fire.examId}#collision$probe',
            fire.offsetMinutes,
          );
        } while (!taken.add(code));
      }
      result.add(probe == 0 ? fire : fire.withRequestCode(code));
    }
    result.sort(
      (left, right) => left.fireAtMillis.compareTo(right.fireAtMillis),
    );
    return result;
  }

  /// Identifies one logical reminder fire, including its lead time.
  ///
  /// Keeping the offset in the key matters when a user changes a reminder
  /// from (for example) 30 minutes to 60 minutes: the old overdue fire must
  /// not be retried as if it were still part of the active schedule.
  static String fireKey(ExamReminderFire fire) =>
      '${fire.examId}#${fire.offsetMinutes}';

  static Set<String> buildActiveFireKeys(Iterable<ExamReminderFire> fires) {
    return fires.map(fireKey).toSet();
  }

  /// 交给原生的"这条逻辑提醒仍在用户的计划里"键集。
  ///
  /// 与投递列表不同：**必须包含已经到点、但可能没弹出去的那些提前量**。
  /// 原生 `ExamReminderScheduler.kt:112-131` 靠 `fireKey(fire) in activeFireKeys`
  /// 判定一条逾期未投递的 fire 要不要重试一次；而投递列表刻意只收严格未来的响点
  /// （`buildFires` / `buildScheduleFires` 里那两处注释都写着"原生另有
  /// failedOverdueFires 通道专门重试"）—— 两边各指认对方兜底，结果是这个通道
  /// 从来拿不到货： overdue fire 的键永远不在键集里 → 判"不再活跃" → :134
  /// `persistFires` 整份覆盖把它删掉。用户在通知权限被拒/勿扰期间没弹出去的
  /// 那条考试提醒，就这么在下一次冷启动 reconcile 时永久消失。
  ///
  /// 键集仍然保留"改了提前量就别重试旧的"这层原意：`exam#30` 在用户把提前量
  /// 从 30 改成 60 之后不再出现在计划里，旧的那条依旧不会被重试。
  ///
  /// 单节课提醒（`additionalFires`）刻意**不**放宽：它的 id 只含课程与日期、
  /// 不含钟点（`class_reminder.dart:28`），`offsetMinutes` 又被固定成 0
  /// （同文件 :100-107），放宽会让"改了上课时间"的旧条目也被判成仍在计划里，
  /// 与新的那条一起重投 —— 与第 22 轮 requestCode 那一族同形。
  static Set<String> buildPlannedFireKeys({
    required List<Exam> exams,
    required Course? Function(Exam exam) resolveCourse,
    List<ScheduleItem> scheduleItems = const [],
    List<ExamReminderFire> additionalFires = const [],
    DateTime? now,
  }) {
    return buildActiveFireKeys(<ExamReminderFire>[
      ...buildFires(
        exams: exams,
        resolveCourse: resolveCourse,
        now: now,
        includePastOffsets: true,
      ),
      ...buildScheduleFires(
        scheduleItems: scheduleItems,
        now: now,
        includePastOffsets: true,
      ),
      ...additionalFires,
    ]);
  }

  static const Duration _scheduleReminderHorizon = Duration(days: 366);
  static const Duration _scheduleReminderRetryWindow = Duration(days: 1);

  /// Expands schedule instances and resolves moved overrides by their actual
  /// displayed date. The persisted occurrence id remains the identity used by
  /// native cancellation, while this key prevents a moved override from being
  /// shown/scheduled alongside the natural occurrence at its destination.
  static Map<String, ScheduleItemInstance> _buildScheduleInstances({
    required List<ScheduleItem> scheduleItems,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final rootEnabledById = <String, bool>{
      for (final item in scheduleItems)
        if (item.seriesId == null) item.id: item.enabled,
    };
    final instancesByDisplayDate = <String, ScheduleItemInstance>{};

    for (final item in scheduleItems) {
      // Disabling a recurring root disables the whole series, including any
      // persisted overrides. Disabled overrides remain eligible below as
      // tombstones when their root is enabled.
      if (item.seriesId == null && !item.enabled) {
        continue;
      }
      if (item.seriesId != null && rootEnabledById[item.seriesId] == false) {
        continue;
      }

      for (final instance in item.expandInstances(
        fromDate: fromDate,
        toDate: toDate,
      )) {
        // 与首页展开器共用同一条去重口径（以前这里是一份独立副本）：
        // 同一系列的两条不同例外被移到同一显示日时，两条都是真实存在、可分别
        // 撤销的条目。副本用的是覆盖式 key，后一条被直接丢弃 —— 界面上两张卡
        // 都在，提醒表里只有一条，被吞的那条不进 buildScheduleActiveIds，
        // 原生对账看到"这个 id 不活跃"就把用户已经设好的闹钟取消了。
        ScheduleItemExpander.putByDisplayDate(instancesByDisplayDate, instance);
      }
    }
    return instancesByDisplayDate;
  }

  /// Builds one-shot fires for enabled schedule occurrences.
  ///
  /// The native scheduler already reconciles and persists one-shot fires, so
  /// recurring rules are expanded here into a bounded future window. The
  /// occurrence id is namespaced to keep it disjoint from exam ids while
  /// retaining deterministic cancellation across edits and restarts.
  static List<ExamReminderFire> buildScheduleFires({
    required List<ScheduleItem> scheduleItems,
    DateTime? now,
    bool includePastOffsets = false,
  }) {
    final referenceNow = now ?? DateTime.now();
    final fromDate = ScheduleItem.dateOnly(
      referenceNow.subtract(_scheduleReminderRetryWindow),
    );
    final toDate = ScheduleItem.dateOnly(
      referenceNow.add(_scheduleReminderHorizon),
    );
    final instancesByDisplayDate = _buildScheduleInstances(
      scheduleItems: scheduleItems,
      fromDate: fromDate,
      toDate: toDate,
    );

    final fires = <ExamReminderFire>[];
    for (final instance in instancesByDisplayDate.values) {
      final item = instance.effectiveItem;
      if (!item.enabled) {
        continue;
      }
      final offsetMinutes = item.reminderMinutesBefore;
      if (offsetMinutes == null || offsetMinutes <= 0) {
        continue;
      }
      final start = _buildScheduleDateTime(instance.date, item.startTime);
      if (start == null) {
        continue;
      }
      final fireAt = start.subtract(Duration(minutes: offsetMinutes));
      // 只发**严格未来**的响点：已投递过的那条会被原生从快照里删掉，但用户改一
      // 节课就会重建整张提醒表，留 30 秒窗口的话那条刚响过的还在窗口内 → 原生按
      // 过去时刻 setExact → AlarmManager 立刻再投一次，同一条提醒弹两遍。原生另
      // 有 failedOverdueFires 通道专门重试「投了但没弹出去」的，不需要这里兜。
      // 计划键那一支要的就是这些已过点的条目，见 buildPlannedFireKeys。
      if (!includePastOffsets && !fireAt.isAfter(referenceNow)) {
        continue;
      }
      final scheduleId = _scheduleFireId(instance.occurrenceId);
      fires.add(
        ExamReminderFire(
          examId: scheduleId,
          offsetMinutes: offsetMinutes,
          fireAtMillis: fireAt.millisecondsSinceEpoch,
          examStartMillis: start.millisecondsSinceEpoch,
          title: item.title.trim(),
          body: _buildScheduleBody(item),
          requestCode: stableRequestCode(scheduleId, offsetMinutes),
        ),
      );
    }

    fires.sort(
      (left, right) => left.fireAtMillis.compareTo(right.fireAtMillis),
    );
    return fires;
  }

  static Set<String> buildScheduleActiveIds({
    required List<ScheduleItem> scheduleItems,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final fromDate = ScheduleItem.dateOnly(
      referenceNow.subtract(_scheduleReminderRetryWindow),
    );
    final toDate = ScheduleItem.dateOnly(
      referenceNow.add(_scheduleReminderHorizon),
    );
    final instancesByDisplayDate = _buildScheduleInstances(
      scheduleItems: scheduleItems,
      fromDate: fromDate,
      toDate: toDate,
    );
    return instancesByDisplayDate.values
        .where((instance) {
          final item = instance.effectiveItem;
          return item.enabled &&
              item.reminderMinutesBefore != null &&
              item.reminderMinutesBefore! > 0;
        })
        .map((instance) => _scheduleFireId(instance.occurrenceId))
        .toSet();
  }

  static String _scheduleFireId(String occurrenceId) =>
      'schedule:$occurrenceId';

  static DateTime? _buildScheduleDateTime(DateTime date, String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23) {
      return null;
    }
    if (minute < 0 || minute > 59) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static String _buildScheduleBody(ScheduleItem item) {
    final parts = <String>['${item.startTime.trim()}-${item.endTime.trim()}'];
    final location = item.location?.trim();
    if (location != null && location.isNotEmpty) {
      parts.add(location);
    }
    return parts.join(' · ');
  }

  /// Expands [exams] into future fire points. Pure function for unit tests.
  ///
  /// [includePastOffsets] 只给 `buildPlannedFireKeys` 用：计划键要覆盖**当前配置的
  /// 全部提前量**，哪怕响点已经过去 —— 否则原生那条"投递了但没弹出去就重试一次"
  /// 的通道（`ExamReminderScheduler.kt:112-131`）永远判不出"仍在计划里"。
  /// 排程本身（投递列表）不受它影响，仍然只有严格未来的响点。
  static List<ExamReminderFire> buildFires({
    required List<Exam> exams,
    required Course? Function(Exam exam) resolveCourse,
    DateTime? now,
    bool includePastOffsets = false,
  }) {
    final referenceNow = now ?? DateTime.now();
    final fires = <ExamReminderFire>[];

    for (final exam in exams) {
      final endParts = Exam.parseTimeOfDayParts(
        exam.endTime,
        fallbackHour: 23,
        fallbackMinute: 59,
      );
      final examEnd = DateTime(
        exam.dateTime.year,
        exam.dateTime.month,
        exam.dateTime.day,
        endParts.$1,
        endParts.$2,
      );
      if (!examEnd.isAfter(referenceNow)) {
        continue;
      }

      final offsets = exam.effectiveReminderMinutes.toSet().toList()..sort();
      if (offsets.isEmpty) {
        continue;
      }

      final examStart = exam.examStartDateTime;
      final examStartMillis = examStart.millisecondsSinceEpoch;
      final course = resolveCourse(exam);
      final body = _buildBody(exam, course);

      for (final offsetMinutes in offsets) {
        if (offsetMinutes <= 0) {
          continue;
        }
        final fireAt = examStart.subtract(Duration(minutes: offsetMinutes));
        // 只发**严格未来**的响点。原生另有 failedOverdueFires 通道专门重试
        // 「投递了但没弹出去」的条目，这里留窗口等于把刚响过的那条再投一遍：
        // 通知已投递会把它从快照删掉，但用户改一节课就会重建整张提醒表，30 秒内
        // 重建时它仍在窗口内 → setExact 一个过去时刻 → AlarmManager 立刻再弹一次。
        // 例外：计划键那一支（includePastOffsets）要的就是"已经到点但可能没弹出去"
        // 的那些，见 buildPlannedFireKeys。
        if (!includePastOffsets && !fireAt.isAfter(referenceNow)) {
          continue;
        }
        // Empty title → native falls back to localized
        // notification_exam_reminder_default_title (do not hardcode zh-CN).
        fires.add(
          ExamReminderFire(
            examId: exam.id,
            offsetMinutes: offsetMinutes,
            fireAtMillis: fireAt.millisecondsSinceEpoch,
            examStartMillis: examStartMillis,
            title: exam.name.trim(),
            body: body,
            requestCode: stableRequestCode(exam.id, offsetMinutes),
          ),
        );
      }
    }

    fires.sort(
      (left, right) => left.fireAtMillis.compareTo(right.fireAtMillis),
    );
    return fires;
  }

  static String _buildBody(Exam exam, Course? course) {
    final parts = <String>['${exam.startTime}-${exam.endTime}'];
    final location = exam.location?.trim().isNotEmpty == true
        ? exam.location!.trim()
        : course?.location.trim();
    if (location != null && location.isNotEmpty) {
      parts.add(location);
    }
    final seatNumber = exam.seatNumber?.trim();
    if (seatNumber != null && seatNumber.isNotEmpty) {
      parts.add(seatNumber);
    }
    return parts.join(' · ');
  }

  /// Full reconcile: replaces all native exam-reminder alarms with [exams].
  Future<bool> reconcile({
    required List<Exam> exams,
    required Course? Function(Exam exam) resolveCourse,
    List<ScheduleItem> scheduleItems = const [],

    /// 额外触发点（如单节课提醒），与考试/日程走同一原生调度管线。
    List<ExamReminderFire> additionalFires = const [],
    DateTime? now,
  }) async {
    final referenceNow = now ?? DateTime.now();
    // 三个来源合流后统一消解 requestCode 碰撞（24 位散列空间 + 366 天展开，
    // 几千条并发 fire 时几乎必然撞），见 assignDistinctRequestCodes 的注释。
    final fires = assignDistinctRequestCodes(<ExamReminderFire>[
      ...buildFires(
        exams: exams,
        resolveCourse: resolveCourse,
        now: referenceNow,
      ),
      ...buildScheduleFires(scheduleItems: scheduleItems, now: referenceNow),
      ...additionalFires,
    ]);
    final activeExamIds = exams
        .where((exam) => !exam.isExpired)
        .map((exam) => exam.id)
        .toSet();
    activeExamIds.addAll(
      buildScheduleActiveIds(scheduleItems: scheduleItems, now: referenceNow),
    );
    return syncFires(
      fires,
      activeExamIds: activeExamIds,
      // 计划键单独算，含已过点的提前量：见 buildPlannedFireKeys 的注释，
      // 这是原生逾期未投递重试通道唯一的入口。
      activeFireKeys: buildPlannedFireKeys(
        exams: exams,
        resolveCourse: resolveCourse,
        scheduleItems: scheduleItems,
        additionalFires: additionalFires,
        now: referenceNow,
      ),
    );
  }

  Future<bool> syncFires(
    List<ExamReminderFire> fires, {
    Set<String> activeExamIds = const {},
    Set<String>? activeFireKeys,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final payload = <String, dynamic>{
        'fires': fires.map((fire) => fire.toNativeMap()).toList(),
        'activeExamIds': activeExamIds.toList(growable: false),
      };
      if (activeFireKeys != null) {
        payload['activeFireKeys'] = activeFireKeys.toList(growable: false);
      }
      await _channel.invokeMethod<void>('reconcile', payload);
      return true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
    } catch (error) {
      appDebugLog('ExamReminder', 'reconcile failed: $error');
    }
    return false;
  }

  Future<bool> clearAll() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      await _channel.invokeMethod<void>('clear');
      return true;
    } on MissingPluginException {
      if (kDebugMode) {
        return true;
      }
    } catch (error) {
      appDebugLog('ExamReminder', 'clear failed: $error');
    }
    return false;
  }
}
