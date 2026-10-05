part of '../timetable_provider.dart';

/// 日期规则「到点批量套用」的唯一实现（原 `timetable_provider.dart:1751-1896`）。
///
/// 从上帝类移出的同时补上本仓已确立的写入纪律。本函数会改**每一个** profile 的
/// `settings.activeTimeSchemeId` 与节次表，并按新节次表重写所有未锁课程的钟点，
/// 然后才 `await saveProfiles`。中间没有 try/catch 时，落盘失败（磁盘满、`commit()`
/// 返回 false）就是「内存已是新作息、盘上还是旧的」：抛错又跳过了后面的
/// `_notifyStateChanged()`，UI 显示旧、getter 是新，而下一次任意成功写入会把这份
/// 从未落库的改动经 `_mergeActiveProfileIntoProfilesList` 当成既有状态落盘 ——
/// 用户视角是「明明弹了失败，过一会儿全表的上课时间真的都变了」。
///
/// 回滚形状同 `_timetableApplyTimeScheme`（作息族，同样四份内存状态）、
/// `_commitLocationGroupChange`（地点分组族）与 `_applySavedThemes`（主题族）。
Future<ScheduleDateRuleApplyResult> _timetableApplyDueScheduleDateRulesDetailed(
  TimetableProvider host, {
  DateTime? now,
}) async {
  await host.initialize();
  final reference = now ?? DateTime.now();
  final matched = ScheduleDateRuleLogic.match(
    reference,
    host._scheduleDateRules,
  );
  if (!ScheduleDateRuleLogic.shouldBulkApply(
    matchedRule: matched,
    lastAppliedSignature: host._scheduleDateRuleLastAppliedSignature,
  )) {
    return const ScheduleDateRuleApplyResult(
      outcome: ScheduleDateRuleApplyOutcome.notDue,
    );
  }

  final rule = matched!;
  final scheme = host._getTimeSchemeById(rule.timeSchemeId);
  if (scheme == null) {
    appDebugLog(
      'ScheduleDateRule',
      '跳过批量套用: 模板不存在 rule=${rule.name} schemeId=${rule.timeSchemeId}',
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
  for (final profile in host._profiles) {
    for (final course in profile.courses) {
      if (course.endSection > requiredMaxSection) {
        requiredMaxSection = course.endSection;
      }
    }
  }
  for (final course in host._courses) {
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

  // 从这里开始动内存：先抓四份旧值，写盘失败就整体退回。
  final snapshotProfiles = List<TimetableProfile>.from(host._profiles);
  final snapshotSettings = host._settings;
  final snapshotCourses = List<Course>.from(host._courses);

  for (var index = 0; index < host._profiles.length; index++) {
    final profile = host._profiles[index];
    final nextSettings = profile.settings.copyWith(
      activeTimeSchemeId: scheme.id,
      sections: List<SectionTime>.from(scheme.sections),
    );
    final syncedCourses = host._syncCoursesWithEffectiveTimeSchemes(
      List<Course>.from(profile.courses),
      settings: nextSettings,
    );
    host._profiles[index] = profile.copyWith(
      settings: nextSettings,
      courses: syncedCourses,
    );
  }

  final activeIndex = host._profiles.indexWhere(
    (profile) => profile.id == host._activeProfileId,
  );
  if (activeIndex != -1) {
    host._courses = List<Course>.from(host._profiles[activeIndex].courses);
    host._settings = host._settingsFromProfile(host._profiles[activeIndex]);
  } else {
    host._settings = host._settings.copyWith(
      activeTimeSchemeId: scheme.id,
      sections: List<SectionTime>.from(scheme.sections),
    );
    host._courses = host._syncCoursesWithEffectiveTimeSchemes(
      List<Course>.from(host._courses),
      settings: host._settings,
    );
  }

  try {
    await host._profileRepository.saveProfiles(host._profiles);
  } catch (_) {
    host._profiles = snapshotProfiles;
    host._settings = snapshotSettings;
    host._courses = snapshotCourses;
    rethrow;
  }

  // 课表已经落成功，内存就是它该有的样子 —— 先通知，别让后面标记写失败把
  // UI 留在套用前的旧值上。
  notifyUserDataChangedForSync();
  host._currentLiveCourseId = null;
  host._notifyStateChanged();

  // 「已套用标记」必须在它自己落盘成功之后才写进内存：内存记了而盘上没有，
  // 本次会话就不会再套，重启后又照盘上的「没套用」再套一次，两边都不是真相。
  await host._profileRepository.saveScheduleDateRuleLastAppliedSignature(
    signature,
  );
  host._scheduleDateRuleLastAppliedSignature = signature;

  await host._updateLiveActivity();

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
