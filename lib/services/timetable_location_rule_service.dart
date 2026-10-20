import 'dart:async';

import 'package:uuid/uuid.dart';

import '../domain/location_time_match_logic.dart';
import '../domain/time_scheme_logic.dart';
import '../logging/app_debug_log.dart';
import '../models/course.dart';
import '../models/location_time_group.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import 'app_log_service.dart';

/// Stats returned after applying location-time rules to the active profile.
class LocationTimeApplyStats {
  final int unlockedCount;
  final int matchedCount;
  final int updatedCount;

  /// Matched, but start/end clocks already equaled the target scheme.
  final int alreadySameClockCount;

  /// Location hit a group, but course section range cannot map into that
  /// scheme — synchronization is rejected (no mode or clock rewrite).
  final int sectionOverflowCount;

  /// First few course names rejected for section overflow (for toast).
  final List<String> sectionOverflowCourseNames;

  const LocationTimeApplyStats({
    required this.unlockedCount,
    required this.matchedCount,
    required this.updatedCount,
    this.alreadySameClockCount = 0,
    this.sectionOverflowCount = 0,
    this.sectionOverflowCourseNames = const [],
  });
}

/// 地点规则族（地点分组 CRUD + 全表重算 + 批量套用）需要的最小宿主面。
///
/// `TimetableProvider` 的成员都是现成的（getter 已有、私有方法各包一层），
/// 服务不 import provider，可用假端口单测。
abstract interface class TimetableLocationRulePort {
  List<Course> get courses;
  set courses(List<Course> value);

  List<TimetableProfile> get profiles;
  set profiles(List<TimetableProfile> value);

  List<LocationTimeGroup> get locationTimeGroups;
  set locationTimeGroups(List<LocationTimeGroup> value);

  TimetableSettings get settings;
  set settings(TimetableSettings value);

  List<TimeScheme> get timeSchemes;

  TimetableProfile? get activeProfile;
  String? get activeProfileId;
  TimeScheme? get activeTimeScheme;

  Future<void> initialize();

  /// 把当前设置与活动课表落盘；失败时抛错，由本服务回滚。
  Future<void> persistActiveProfileState();

  /// 只落盘地点分组列表（仓储 + 同步通知）。
  Future<void> persistLocationTimeGroups();

  /// 只落盘整份课表列表（仓储 + 同步通知）。
  Future<void> saveProfiles(List<TimetableProfile> profiles);

  void notifySyncDataChanged();
  void notifyStateChanged();

  /// 课程钟点被整表重写后，实时活动要丢掉旧选择并重推。
  void clearCurrentLiveCourseId();
  Future<void> updateLiveActivity();

  List<Course> syncCoursesWithEffectiveTimeSchemes(
    List<Course> source, {
    TimetableSettings? settings,
  });

  Course syncCourseWithEffectiveTimeScheme(
    Course course, {
    TimetableSettings? settings,
    bool debugTrace = false,
  });

  TimetableSettings settingsFromProfile(TimetableProfile profile);
}

/// 地点规则族 —— **只有这一份实现**。
///
/// 2026-10-20 从两个分片合并而来（F2）：`location_group_repository.dart`
/// 的 `_commitLocationGroupChange`（40 行）与 `schedule_rule_apply.dart` 的
/// 批量套用实现（363 行），外加主文件里的分组 CRUD、`_persistLocationTimeGroups`、
/// `_resyncAllProfilesWithLocationRules`（合计约 140 行）。宿主只留委托与写盘门
/// （`_runMutation` 仍在 provider），服务的每个入口假定已站在门内。
///
/// 收口规则（逐字保持）：
///
/// - 分组写入任一步 await 失败就把**四份**内存状态（分组、课表、设置、课程）整体
///   退回，并尽力把旧分组列表重新落盘（补偿），最后 rethrow。形状同主题族与作息族。
///   分组写成功但重算失败时也必须退：否则盘上是新分组、课表钟点还是旧口径，
///   下一次任意成功写入会把这份不一致永久坐实。
/// - 批量套用是一次整表重写（钟点改写 + 释放全部 `timeSchemeIdOverride`，不可逆）。
///   落盘抛错时内存必须退回，否则下一次任意成功写入会把这份规则坐实 ——
///   用户视角是「重新匹配报了失败，但课程时间自己变了」。
class TimetableLocationRuleService {
  const TimetableLocationRuleService._();

  /// 只落盘分组列表（仓储 + 同步通知收在宿主侧）。
  static Future<void> persistGroups(TimetableLocationRulePort port) async {
    await port.persistLocationTimeGroups();
  }

  /// 按当前地点分组重算**每个课表**的钟点，并把活动档的课程/设置同步回内存。
  static Future<void> resyncAllProfiles(
    TimetableLocationRulePort port, {
    bool notify = true,
  }) async {
    final profiles = List<TimetableProfile>.from(port.profiles);
    for (var index = 0; index < profiles.length; index++) {
      final profile = profiles[index];
      final syncedCourses = port.syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(profile.courses),
        settings: profile.settings,
      );
      profiles[index] = profile.copyWith(courses: syncedCourses);
    }
    port.profiles = profiles;

    final activeIndex = profiles.indexWhere(
      (profile) => profile.id == port.activeProfileId,
    );
    if (activeIndex != -1) {
      port.courses = List<Course>.from(profiles[activeIndex].courses);
      port.settings = port.settingsFromProfile(profiles[activeIndex]);
    }

    await port.saveProfiles(profiles);
    port.notifySyncDataChanged();
    port.clearCurrentLiveCourseId();
    if (notify) {
      port.notifyStateChanged();
    }
    await port.updateLiveActivity();
  }

  /// 地点分组写入的收口：任一步 await 失败就把四份内存状态整体退回，
  /// 并尽力把旧分组列表重新落盘（补偿），最后 rethrow。
  static Future<void> commitGroupChange(
    TimetableLocationRulePort port,
    List<LocationTimeGroup> previousGroups,
    Future<void> Function() write,
  ) async {
    final snapshotProfiles = List<TimetableProfile>.from(port.profiles);
    final snapshotSettings = port.settings;
    final snapshotCourses = List<Course>.from(port.courses);
    try {
      await write();
    } catch (_) {
      port.locationTimeGroups = previousGroups;
      port.profiles = snapshotProfiles;
      port.settings = snapshotSettings;
      port.courses = snapshotCourses;
      try {
        await port.persistLocationTimeGroups();
      } catch (_) {
        // 补偿失败不遮住原始错误：与 updateTimetableSettings 的旧路径同处理。
      }
      rethrow;
    }
  }

  static Future<LocationTimeGroup> createGroup(
    TimetableLocationRulePort port, {
    required String name,
    required String timeSchemeId,
    List<LocationKeyword> keywords = const [],
    bool enabled = true,
    int priority = 0,
  }) async {
    await port.initialize();
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('location_time_group_name_required');
    }
    if (TimeSchemeLogic.getSchemeById(port.timeSchemes, timeSchemeId) == null) {
      throw ArgumentError('time_scheme_not_found');
    }

    final group = LocationTimeGroup(
      id: const Uuid().v4(),
      name: trimmedName,
      timeSchemeId: timeSchemeId,
      enabled: enabled,
      priority: priority,
      keywords: List<LocationKeyword>.from(keywords),
    );
    final previousGroups = List<LocationTimeGroup>.from(port.locationTimeGroups);
    port.locationTimeGroups = [...port.locationTimeGroups, group];
    await commitGroupChange(port, previousGroups, () async {
      await port.persistLocationTimeGroups();
      await resyncAllProfiles(port);
    });
    return group;
  }

  static Future<LocationTimeGroup?> updateGroup(
    TimetableLocationRulePort port,
    LocationTimeGroup group,
  ) async {
    await port.initialize();
    final index = port.locationTimeGroups.indexWhere(
      (item) => item.id == group.id,
    );
    if (index == -1) {
      return null;
    }
    final trimmedName = group.name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('location_time_group_name_required');
    }
    if (TimeSchemeLogic.getSchemeById(port.timeSchemes, group.timeSchemeId) ==
        null) {
      throw ArgumentError('time_scheme_not_found');
    }

    final updated = group.copyWith(
      name: trimmedName,
      keywords: List<LocationKeyword>.from(group.keywords),
    );
    final previousGroups = List<LocationTimeGroup>.from(port.locationTimeGroups);
    final next = List<LocationTimeGroup>.from(port.locationTimeGroups);
    next[index] = updated;
    port.locationTimeGroups = next;
    await commitGroupChange(port, previousGroups, () async {
      await port.persistLocationTimeGroups();
      await resyncAllProfiles(port);
    });
    return updated;
  }

  static Future<bool> deleteGroup(
    TimetableLocationRulePort port,
    String groupId,
  ) async {
    await port.initialize();
    final previousGroups = List<LocationTimeGroup>.from(port.locationTimeGroups);
    final next = port.locationTimeGroups
        .where((group) => group.id != groupId)
        .toList();
    port.locationTimeGroups = next;
    if (next.length == previousGroups.length) {
      return false;
    }
    await commitGroupChange(port, previousGroups, () async {
      await port.persistLocationTimeGroups();
      await resyncAllProfiles(port);
    });
    return true;
  }

  /// 整份替换分组列表（传输层应用、教务导入、云快照恢复都走这里）。
  static Future<void> replaceGroups(
    TimetableLocationRulePort port,
    List<LocationTimeGroup> groups, {
    bool resync = true,
  }) async {
    await port.initialize();
    final previousGroups = List<LocationTimeGroup>.from(port.locationTimeGroups);
    port.locationTimeGroups = List<LocationTimeGroup>.from(groups);
    await commitGroupChange(port, previousGroups, () async {
      await port.persistLocationTimeGroups();
      if (resync) {
        await resyncAllProfiles(port);
        return;
      }
      port.notifyStateChanged();
    });
  }

  /// 地点分组的批量套用：按分组规则重算活动档全部课程的钟点。
  ///
  /// 不改的地点组/课程都会在日志里报告原因（未命中、模板缺失、节次越界）；
  /// 只有**完整坐进模板节次范围**的课程才会被改写（HARD RULE）。
  static Future<LocationTimeApplyStats> applyToActiveProfile(
    TimetableLocationRulePort port,
  ) async {
    await port.initialize();
    const debugTag = 'LocationTimeApply';
    var unlockedCount = 0;
    var matchedCount = 0;
    var updatedCount = 0;
    var alreadySameClockCount = 0;
    var sectionOverflowCount = 0;
    final sectionOverflowCourseNames = <String>[];
    var noMatchCount = 0;
    var matchMissingSchemeCount = 0;
    var autoReleasedCount = 0;
    var clockRewriteCount = 0;
    final changeSamples = <String>[];

    void audit(String message, {Map<String, Object?> extras = const {}}) {
      appDebugLog(debugTag, message);
      unawaited(
        AppLogService.instance.info('location_time_apply', message, extras: extras),
      );
    }

    final activeScheme = port.activeTimeScheme;
    audit(
      '===== 开始应用到当前课表 ===== '
      'profile=${port.activeProfile?.name ?? "null"}(${port.activeProfileId ?? "-"}) '
      'courses=${port.courses.length} '
      'locationGroups=${port.locationTimeGroups.length} '
      'activeScheme=${activeScheme?.name ?? "null"}(${activeScheme?.id ?? "-"}) '
      'activeSections=${activeScheme?.sections.length ?? port.settings.sections.length} '
      'manualOverridesBefore=${port.courses.where((c) => c.timeSchemeIdOverride != null).length}',
      extras: {
        'profileId': port.activeProfileId,
        'courseCount': port.courses.length,
        'groupCount': port.locationTimeGroups.length,
        'activeSchemeId': activeScheme?.id,
        'manualOverridesBefore': port.courses
            .where((course) => course.timeSchemeIdOverride != null)
            .length,
      },
    );
    for (final group in port.locationTimeGroups) {
      final scheme = TimeSchemeLogic.getSchemeById(
        port.timeSchemes,
        group.timeSchemeId,
      );
      final keywords = group.keywords
          .map((keyword) => '${keyword.pattern}(${keyword.mode.name})')
          .join('|');
      audit(
        '地点组: id=${group.id} name=${group.name} enabled=${group.enabled} '
        'priority=${group.priority} scheme=${scheme?.name ?? "MISSING"}(${group.timeSchemeId}) '
        'schemeSections=${scheme?.sections.length ?? 0} keywords=[$keywords]',
        extras: {
          'groupId': group.id,
          'groupName': group.name,
          'enabled': group.enabled,
          'schemeId': group.timeSchemeId,
          'schemeName': scheme?.name,
          'schemeSections': scheme?.sections.length ?? 0,
          'keywords': keywords,
        },
      );
      if (scheme != null && scheme.sections.isNotEmpty) {
        final first = scheme.sections.first;
        final last = scheme.sections.last;
        audit(
          '  模板首末节: ${first.startTime}-${first.endTime} ... '
          '${last.startTime}-${last.endTime}',
        );
      }
    }
    if (activeScheme != null && activeScheme.sections.isNotEmpty) {
      final first = activeScheme.sections.first;
      final last = activeScheme.sections.last;
      audit(
        '主课表模板首末节: ${first.startTime}-${first.endTime} ... '
        '${last.startTime}-${last.endTime}',
      );
    }

    final synced = <Course>[];
    for (final course in port.courses) {
      unlockedCount += 1;
      final beforeOverride = course.timeSchemeIdOverride;
      final beforeClock = '${course.startTime}-${course.endTime}';
      final match = LocationTimeMatchLogic.match(
        course.location,
        port.locationTimeGroups,
      );
      final matchedScheme = match == null
          ? null
          : TimeSchemeLogic.getSchemeById(port.timeSchemes, match.timeSchemeId);

      Course courseToSync = course;

      // 适配脚本下发的真实钟点是权威值，地点分组不得覆盖，否则用户改一次分组
      // 就会把早读/连堂这类自定义时间冲掉。
      if (course.hasCustomTime) {
        synced.add(course);
        continue;
      }

      if (match == null) {
        noMatchCount += 1;
        if (changeSamples.length < 40) {
          audit(
            '未命中地点: course=${course.name} id=${course.id} loc=${course.location} '
            'sections=${course.startSection}-${course.endSection} '
            'override=${beforeOverride ?? "null"} clock=$beforeClock',
            extras: {
              'action': 'no_match',
              'courseId': course.id,
              'courseName': course.name,
              'location': course.location,
              'beforeOverride': beforeOverride,
              'beforeClock': beforeClock,
            },
          );
        }
        synced.add(course);
        continue;
      }

      if (matchedScheme == null) {
        matchMissingSchemeCount += 1;
        audit(
          '命中但模板不存在: course=${course.name} id=${course.id} loc=${course.location} '
          'group=${match.groupName} schemeId=${match.timeSchemeId} '
          'keyword=${match.matchedKeyword.pattern}/${match.matchedKeyword.mode.name}',
          extras: {
            'action': 'match_missing_scheme',
            'courseId': course.id,
            'courseName': course.name,
            'location': course.location,
            'groupName': match.groupName,
            'schemeId': match.timeSchemeId,
            'beforeOverride': beforeOverride,
          },
        );
        synced.add(course);
        continue;
      }

      final startIndex = course.startSection - 1;
      final endIndex = course.endSection - 1;
      final sectionCount = matchedScheme.sections.length;
      // HARD RULE: only fully seat-mapable courses may be synchronized.
      // Applying a short scheme to a later section would produce nonsense
      // clocks, so leave the course untouched and report it.
      if (startIndex < 0 || endIndex < startIndex || endIndex >= sectionCount) {
        sectionOverflowCount += 1;
        if (sectionOverflowCourseNames.length < 5) {
          sectionOverflowCourseNames.add(course.name);
        }
        audit(
          '拒绝套用(节次无法对号入座): course=${course.name} id=${course.id} '
          'loc=${course.location} need=${course.startSection}-${course.endSection} '
          'scheme=${matchedScheme.name} has=$sectionCount '
          'beforeOverride=${beforeOverride ?? "null"} clock=$beforeClock '
          '→ 不写 override、不改钟点',
          extras: {
            'action': 'overflow_reject_no_sync',
            'courseId': course.id,
            'courseName': course.name,
            'location': course.location,
            'startSection': course.startSection,
            'endSection': course.endSection,
            'schemeId': matchedScheme.id,
            'schemeName': matchedScheme.name,
            'schemeSections': sectionCount,
            'beforeOverride': beforeOverride,
            'beforeClock': beforeClock,
          },
        );
        // Leave course completely unchanged.
        synced.add(course);
        if (changeSamples.length < 30) {
          changeSamples.add(
            '${course.name}|${course.id}|REJECT overflow '
            'need=${course.startSection}-${course.endSection} schemeHas=$sectionCount',
          );
        }
        continue;
      }

      // Only fully seat-mapped courses count as matched/synchronized.
      matchedCount += 1;
      // Return the course to automatic mode, then resolve it through the
      // current location rule. This keeps future rule edits automatic instead
      // of turning a rematch into another permanent manual override.
      courseToSync = course.copyWith(timeSchemeIdOverride: null);
      if (beforeOverride != null) {
        autoReleasedCount += 1;
      }

      final expectedStart = matchedScheme.sections[startIndex].startTime;
      final expectedEnd = matchedScheme.sections[endIndex].endTime;
      final sameClock =
          course.startTime == expectedStart && course.endTime == expectedEnd;
      if (sameClock) {
        alreadySameClockCount += 1;
      }

      final next = port.syncCourseWithEffectiveTimeScheme(
        courseToSync,
        settings: port.settings,
        debugTrace: true,
      );
      synced.add(next);

      final clockChanged =
          next.startTime != course.startTime || next.endTime != course.endTime;
      final overrideChanged =
          next.timeSchemeIdOverride != course.timeSchemeIdOverride;
      if (clockChanged || overrideChanged) {
        updatedCount += 1;
        if (clockChanged) {
          clockRewriteCount += 1;
        }
        if (changeSamples.length < 30) {
          changeSamples.add(
            '${course.name}|${course.id}|'
            'override ${beforeOverride ?? "null"}->${next.timeSchemeIdOverride ?? "null"}|'
            'clock $beforeClock->${next.startTime}-${next.endTime}',
          );
        }
      }
      audit(
        '${sameClock ? "SAME" : "DIFF"} course=${course.name} id=${course.id} '
        'loc=${course.location} group=${match.groupName} '
        'scheme=${matchedScheme.name} '
        'beforeOverride=${beforeOverride ?? "null"} '
        'afterOverride=${next.timeSchemeIdOverride ?? "null"} '
        'beforeClock=$beforeClock afterClock=${next.startTime}-${next.endTime} '
        'clockChanged=$clockChanged overrideChanged=$overrideChanged',
        extras: {
          'action': sameClock
              ? 'auto_match_same_clock'
              : 'auto_match_and_rewrite_clock',
          'courseId': course.id,
          'courseName': course.name,
          'location': course.location,
          'groupName': match.groupName,
          'schemeId': matchedScheme.id,
          'schemeName': matchedScheme.name,
          'beforeOverride': beforeOverride,
          'afterOverride': next.timeSchemeIdOverride,
          'beforeClock': beforeClock,
          'afterClock': '${next.startTime}-${next.endTime}',
          'expectedClock': '$expectedStart-$expectedEnd',
          'sameClock': sameClock,
          'clockChanged': clockChanged,
          'overrideChanged': overrideChanged,
        },
      );
    }

    if (updatedCount > 0) {
      // 形状：整份课程表按地点规则重写（钟点改写 + 释放全部
      // `timeSchemeIdOverride`，不可逆）后落盘。落盘抛错时内存停在
      // 没落库的新表上，而 `_persistActiveProfileState` 的第一步
      // `_mergeActiveProfileIntoProfilesList` 已把它并进 `_profiles` ——
      // 下一次任意成功写入（加课、切课表、30 秒一次的心跳）就把这份规则
      // 坐实，用户视角是「重新匹配报了失败，但课程时间自己变了」。
      final snapshotCourses = List<Course>.from(port.courses);
      final snapshotProfiles = List<TimetableProfile>.from(port.profiles);
      port.courses = synced;
      try {
        await port.persistActiveProfileState();
      } catch (error, stackTrace) {
        port.courses = snapshotCourses;
        port.profiles = snapshotProfiles;
        Error.throwWithStackTrace(error, stackTrace);
      }
      port.clearCurrentLiveCourseId();
      port.notifyStateChanged();
      await port.updateLiveActivity();
    }

    final overridesAfter = port.courses
        .where((course) => course.timeSchemeIdOverride != null)
        .length;
    final profileOverrides =
        port.activeProfile?.courses
            .where((course) => course.timeSchemeIdOverride != null)
            .length ??
        -1;
    audit(
      '===== 应用结束 ===== unlocked=$unlockedCount matched=$matchedCount '
      'updated=$updatedCount sameClock=$alreadySameClockCount '
      'overflow=$sectionOverflowCount noMatch=$noMatchCount '
      'missingScheme=$matchMissingSchemeCount '
      'autoReleased=$autoReleasedCount clockRewrite=$clockRewriteCount '
      'overridesInMemoryAfter=$overridesAfter overridesInActiveProfile=$profileOverrides '
      'didPersist=${updatedCount > 0} '
      'overflowNames=${sectionOverflowCourseNames.join(",")} '
      // 键名用 `changeSamples`（受脱敏表覆盖）而不是 `samples`：
      // 值里是 `课程名|id|…`，而 `samples` 是性能探针的计数键名，
      // 不能为了这一个字段把计数也抹掉（见 `app_debug_log.dart` 的口径说明）。
      'changeSamples=${changeSamples.take(12).join(" || ")}',
      extras: {
        'unlocked': unlockedCount,
        'matched': matchedCount,
        'updated': updatedCount,
        'sameClock': alreadySameClockCount,
        'overflow': sectionOverflowCount,
        'noMatch': noMatchCount,
        'missingScheme': matchMissingSchemeCount,
        'autoReleased': autoReleasedCount,
        'clockRewrite': clockRewriteCount,
        'overridesInMemoryAfter': overridesAfter,
        'overridesInActiveProfile': profileOverrides,
        'didPersist': updatedCount > 0,
        'changeSamples': changeSamples,
        'overflowNames': sectionOverflowCourseNames,
      },
    );
    if (matchedCount > 0 && updatedCount == 0) {
      audit(
        '结论: 地点规则已命中，但课程未改写（钟点已相同且未绑定 override，或全部节次越界）。'
        'sameClock=$alreadySameClockCount overflow=$sectionOverflowCount。'
        '请对比地点组绑定模板 vs 主课表模板各节起止时间是否完全一致。',
      );
    }
    if (overridesAfter != profileOverrides && profileOverrides >= 0) {
      audit(
        '严重异常: 内存课表与 activeProfile 的模板覆盖数量不一致。持久化/合并失败。',
        extras: {
          'fatal': true,
          'overridesInMemoryAfter': overridesAfter,
          'overridesInActiveProfile': profileOverrides,
        },
      );
    }

    return LocationTimeApplyStats(
      unlockedCount: unlockedCount,
      matchedCount: matchedCount,
      updatedCount: updatedCount,
      alreadySameClockCount: alreadySameClockCount,
      sectionOverflowCount: sectionOverflowCount,
      sectionOverflowCourseNames: sectionOverflowCourseNames,
    );
  }
}
