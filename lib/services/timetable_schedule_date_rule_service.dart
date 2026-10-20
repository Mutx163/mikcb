import 'dart:async';

import '../domain/schedule_date_rule_logic.dart';
import '../logging/app_debug_log.dart';
import '../models/course.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import 'app_log_service.dart';
import 'timetable_time_scheme_service.dart';

/// 日期规则批量套用需要的宿主面。
///
/// 它做的事和「套用作息」是同一棵状态树：改每一个档案的生效作息与节次表、按新节次
/// 重写未锁课程的钟点、分两次落盘（档案先写、套用标记后写）。所以这里**直接复用
/// [TimetableTimeSchemePort]**，只在它上面多三个成员，不要另立一份重复的成员表。
abstract interface class TimetableScheduleDateRulePort
    implements TimetableTimeSchemePort {
  /// 上次成功套用的签名；策略是"同一档期只套一次"。
  String? get scheduleDateRuleLastAppliedSignature;
  set scheduleDateRuleLastAppliedSignature(String? value);

  /// 「已套用标记」必须**自己落盘成功之后**才写进内存（见 [applyDue]）。
  Future<void> saveScheduleDateRuleLastAppliedSignature(String signature);

  /// 课表落盘成功后通知云同步：这份数据变了。
  void notifySyncDataChanged();
}

/// 日期规则的批量套用实现 —— **只有这一份**。
///
/// 2026-10-20 从分片 `providers/timetable/schedule_date_rule_repository.dart`
/// （181 行）搬出（F6）。宿主只留一行委托与写盘门。
///
/// 落盘失败必须整体回滚：本方法会改**每一个** profile 的 `activeTimeSchemeId` 与
/// 节次表，并按新节次表重写所有未锁课程的钟点，然后才 `saveProfiles`。中途没有
/// try/catch 时，落盘失败（磁盘满、`commit()` 返回 false）就是「内存已是新作息、
/// 盘上还是旧的」：抛错又跳过通知，UI 显示旧、getter 是新，而下一次任意成功写入会
/// 把这份从未落库的改动当成既有状态落盘 —— 用户视角是「明明弹了失败，过一会儿
/// 全表的上课时间真的都变了」。
///
/// 回滚形状与 [TimetableTimeSchemeService.apply]（作息族）、地点分组族、主题族一致。
class TimetableScheduleDateRuleService {
  const TimetableScheduleDateRuleService._();

  /// 到点就按匹配到的规则批量套用作息；不满足条件时如实返回 [outcome]。
  static Future<ScheduleDateRuleApplyResult> applyDue(
    TimetableScheduleDateRulePort port, {
    DateTime? now,
  }) async {
    await port.initialize();
    final reference = now ?? DateTime.now();
    final matched = ScheduleDateRuleLogic.match(
      reference,
      port.scheduleDateRules,
    );
    if (!ScheduleDateRuleLogic.shouldBulkApply(
      matchedRule: matched,
      lastAppliedSignature: port.scheduleDateRuleLastAppliedSignature,
    )) {
      return const ScheduleDateRuleApplyResult(
        outcome: ScheduleDateRuleApplyOutcome.notDue,
      );
    }

    final rule = matched!;
    final scheme = port.timeSchemeById(rule.timeSchemeId);
    if (scheme == null) {
      appDebugLog(
        'ScheduleDateRule',
        '跳过批量套用: 模板不存在 rule=${rule.name} '
            'schemeId=${rule.timeSchemeId}',
      );
      await AppLogService.instance.warn(
        'schedule_date_rule',
        '日期规则批量套用失败：时间模板不存在',
        extras: {
          'ruleId': rule.id,
          'ruleName': rule.name,
          'schemeId': rule.timeSchemeId,
        },
      );
      return const ScheduleDateRuleApplyResult(
        outcome: ScheduleDateRuleApplyOutcome.schemeMissing,
      );
    }

    // Validate every profile before rewriting clocks; active-only checks can
    // leave inactive profiles pointing at a scheme that cannot represent them.
    var requiredMaxSection = 0;
    for (final profile in port.profiles) {
      for (final course in profile.courses) {
        if (course.endSection > requiredMaxSection) {
          requiredMaxSection = course.endSection;
        }
      }
    }
    for (final course in port.courses) {
      if (course.endSection > requiredMaxSection) {
        requiredMaxSection = course.endSection;
      }
    }
    if (requiredMaxSection > scheme.sections.length) {
      appDebugLog(
        'ScheduleDateRule',
        '跳过批量套用: 节次超出模板 rule=${rule.name} need=$requiredMaxSection '
            'has=${scheme.sections.length}',
      );
      await AppLogService.instance.warn(
        'schedule_date_rule',
        '日期规则批量套用失败：节次超出模板',
        extras: {
          'ruleId': rule.id,
          'ruleName': rule.name,
          'schemeId': scheme.id,
          'requiredMaxSection': requiredMaxSection,
          'schemeSections': scheme.sections.length,
        },
      );
      return ScheduleDateRuleApplyResult(
        outcome: ScheduleDateRuleApplyOutcome.sectionOverflow,
        requiredMaxSection: requiredMaxSection,
        schemeSectionCount: scheme.sections.length,
      );
    }

    final signature = ScheduleDateRuleLogic.appliedSignature(rule);
    appDebugLog(
      'ScheduleDateRule',
      '批量套用作息: rule=${rule.name} scheme=${scheme.name} '
          'range=${rule.startDate}~${rule.endDate} signature=$signature',
    );

    // 从这里开始动内存：先抓三份旧值，写盘失败就整体退回。
    final snapshotProfiles = List<TimetableProfile>.from(port.profiles);
    final snapshotSettings = port.settings;
    final snapshotCourses = List<Course>.from(port.courses);

    final nextProfiles = List<TimetableProfile>.from(port.profiles);
    for (var index = 0; index < nextProfiles.length; index++) {
      final profile = nextProfiles[index];
      final nextSettings = profile.settings.copyWith(
        activeTimeSchemeId: scheme.id,
        sections: List<SectionTime>.from(scheme.sections),
      );
      final syncedCourses = port.syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(profile.courses),
        settings: nextSettings,
      );
      nextProfiles[index] = profile.copyWith(
        settings: nextSettings,
        courses: syncedCourses,
      );
    }
    port.profiles = nextProfiles;

    final activeIndex = nextProfiles.indexWhere(
      (profile) => profile.id == port.activeProfileId,
    );
    if (activeIndex != -1) {
      port.courses = List<Course>.from(nextProfiles[activeIndex].courses);
      port.settings = port.settingsFromProfile(nextProfiles[activeIndex]);
    } else {
      port.settings = port.settings.copyWith(
        activeTimeSchemeId: scheme.id,
        sections: List<SectionTime>.from(scheme.sections),
      );
      port.courses = port.syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(port.courses),
        settings: port.settings,
      );
    }

    try {
      await port.saveProfiles(port.profiles);
    } catch (_) {
      port.profiles = snapshotProfiles;
      port.settings = snapshotSettings;
      port.courses = snapshotCourses;
      rethrow;
    }

    // 课表已经落成功，内存就是它该有的样子 —— 先通知，别让后面标记写失败把
    // UI 留在套用前的旧值上。
    port.notifySyncDataChanged();
    port.clearCurrentLiveCourseId();
    port.notifyStateChanged();

    // 「已套用标记」必须在它自己落盘成功之后才写进内存：内存记了而盘上没有，
    // 本次会话就不会再套，重启后又照盘上的「没套用」再套一次，两边都不是真相。
    await port.saveScheduleDateRuleLastAppliedSignature(signature);
    port.scheduleDateRuleLastAppliedSignature = signature;

    await port.updateLiveActivity();

    unawaited(
      AppLogService.instance.info(
        'schedule_date_rule',
        '已按日期规则批量套用作息',
        extras: {
          'ruleId': rule.id,
          'ruleName': rule.name,
          'schemeId': scheme.id,
          'schemeName': scheme.name,
          'startDate': rule.startDate,
          'endDate': rule.endDate,
          'signature': signature,
        },
      ),
    );
    return const ScheduleDateRuleApplyResult(
      outcome: ScheduleDateRuleApplyOutcome.applied,
    );
  }
}
