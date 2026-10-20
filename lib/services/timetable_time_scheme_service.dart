import 'package:uuid/uuid.dart';

import '../domain/time_scheme_logic.dart';
import '../l10n/service_message_localizer.dart';
import '../models/course.dart';
import '../models/location_time_group.dart';
import '../models/schedule_date_rule.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';

/// 作息（时间模板）族写入口需要的最小宿主面。
///
/// 这个族要动四份内存状态（作息表 / 全部档案 / 全局设置 / 当前课表），落盘还要分
/// 两次（作息表先写、档案后写），所以端口里既有 `set` 也有两条独立的落盘钩子——
/// 复合事务的补偿语义必须显式，不能靠"宿主自己在某处顺手存一下"。
abstract interface class TimetableTimeSchemePort {
  List<TimeScheme> get timeSchemes;
  set timeSchemes(List<TimeScheme> value);

  List<Course> get courses;
  set courses(List<Course> value);

  List<TimetableProfile> get profiles;
  set profiles(List<TimetableProfile> value);

  TimetableSettings get settings;
  set settings(TimetableSettings value);

  List<LocationTimeGroup> get locationTimeGroups;

  List<ScheduleDateRule> get scheduleDateRules;

  String? get activeProfileId;

  TimeScheme? get activeTimeScheme;

  /// 按 id 找作息（宿主内部同一个查找口径）。
  TimeScheme? timeSchemeById(String? schemeId);

  /// 把课程钟点按生效方案补齐（改作息后整表重算）。
  List<Course> syncCoursesWithEffectiveTimeSchemes(
    List<Course> source, {
    TimetableSettings? settings,
  });

  /// 档案里那份设置只是镜像；从档案恢复内存状态时要用它重新叠加全局真源。
  TimetableSettings settingsFromProfile(TimetableProfile profile);

  /// 把当前内存状态写回活动档案条目（落盘前的镜像合并）。
  void mergeActiveProfileIntoProfilesList();

  Future<void> initialize();

  /// 只写作息表这一份（不是整份课表）。
  Future<void> persistTimeSchemes();

  Future<void> persistActiveProfileState();

  Future<void> saveProfiles(List<TimetableProfile> profiles);

  void notifyStateChanged();

  void clearCurrentLiveCourseId();

  Future<void> updateLiveActivity();
}

/// 作息（时间模板）族的读写实现 —— **只有这一份定义**。
///
/// 2026-10-20 从分片 `providers/timetable/time_scheme_repository.dart`（304 行）
/// 搬出（F5）。宿主只留一行委托与写盘门，服务的每个入口假定**已经站在写盘门内**：
/// 这个族的每个入口都要 `_mutationGate`，否则门内写者（加课/导入/云恢复）中途
/// 让出时，本入口改内存并落盘会被那次失败回滚当成"恢复前的旧数据"抹掉。
///
/// 回滚判据与写作纪律相同：**内存里被改掉的，是不是用户刚刚亲口确认的那一条**。
///
/// - [create] / [duplicate]：只往作息表里加一条，失败就把刚加的那条摘掉
///   （否则幻影作息会被下一次任意成功写入经 `mergeActiveProfileIntoProfilesList`
///   当成既有状态永久落盘）。
/// - [apply]：一次改"活动作息 + 按新作息重排出来的课程钟点"两份状态，失败整体退回。
/// - [update]：同时改四份内存状态（作息表 / 全部档案 / 设置 / 当前课表），再分两次
///   落盘；第二笔失败时必须**补偿回写旧作息表** —— 第一笔已经成功落盘了，光退内存
///   会留下"盘上是新节次表、内存是旧节次表"，冷启动时用户被告知"没改成"的节次会
///   自己生效。
/// - [delete]：被任何档案/分组/日期规则引用时直接拒绝（不落盘、不动内存）。
/// - [rename]：只改内存里那一条，失败把它换回原样。
class TimetableTimeSchemeService {
  const TimetableTimeSchemeService._();

  /// 新建一套作息；[applyToActiveProfile] 为真时顺手套到当前课表。
  static Future<TimeScheme> create(
    TimetableTimeSchemePort port, {
    required String name,
    List<SectionTime>? sections,
    bool applyToActiveProfile = false,
  }) async {
    await port.initialize();
    final now = DateTime.now();
    final scheme = TimeScheme(
      id: const Uuid().v4(),
      name: name.trim(),
      sections: List<SectionTime>.from(
        sections ?? port.activeTimeScheme?.sections ?? port.settings.sections,
      ),
      createdAt: now,
      updatedAt: now,
    );
    port.timeSchemes = <TimeScheme>[...port.timeSchemes, scheme];
    try {
      await port.persistTimeSchemes();
    } catch (_) {
      // 落库失败必须把刚加进内存的那条摘掉：本类大量入口是「先改内存、后写盘」，
      // 幻影作息会被下一次任意成功写入当成既有状态永久落盘。
      port.timeSchemes = port.timeSchemes
          .where((item) => item.id != scheme.id)
          .toList();
      rethrow;
    }
    if (applyToActiveProfile) {
      await apply(port, scheme.id);
    } else {
      port.notifyStateChanged();
    }
    return scheme;
  }

  /// 把某套作息套到当前课表；成功返回 null，失败返回可直接展示的消息编码。
  static Future<String?> apply(
    TimetableTimeSchemePort port,
    String schemeId,
  ) async {
    await port.initialize();
    final scheme = port.timeSchemeById(schemeId);
    if (scheme == null) {
      return 'time_scheme_not_found';
    }

    // Same rule as shrinking a scheme via [update]: active-profile courses keep
    // their section indexes, so the target scheme must cover them.
    Course? highestSectionCourse;
    for (final course in port.courses) {
      if (highestSectionCourse == null ||
          course.endSection > highestSectionCourse.endSection) {
        highestSectionCourse = course;
      }
    }
    final requiredMaxSection = highestSectionCourse?.endSection ?? 0;
    if (requiredMaxSection > scheme.sections.length) {
      return encodeServiceMessage('section_count_below_usage', {
        'requiredMaxSection': requiredMaxSection,
      });
    }

    // 本函数改两份内存状态（活动作息 + 按新作息重排出来的课程钟点），再 await 落盘，
    // 而落盘还会先把它们并进档案。任一步失败都必须整体退回：否则磁盘回滚了而内存
    // 停在方案 B、界面还显示 A，下一次任意成功写入会把 B 当成既有状态落盘 ——
    // 用户的上课时间在一次"失败"提示之后被真的改掉。
    final snapshotSettings = port.settings;
    final snapshotCourses = List<Course>.from(port.courses);
    final snapshotProfiles = List<TimetableProfile>.from(port.profiles);
    port.settings = port.settings.copyWith(
      activeTimeSchemeId: scheme.id,
      sections: List<SectionTime>.from(scheme.sections),
    );
    port.courses = port.syncCoursesWithEffectiveTimeSchemes(
      List<Course>.from(port.courses),
      settings: port.settings,
    );
    try {
      await port.persistActiveProfileState();
    } catch (_) {
      port.settings = snapshotSettings;
      port.courses = snapshotCourses;
      port.profiles = snapshotProfiles;
      rethrow;
    }
    port.clearCurrentLiveCourseId();
    port.notifyStateChanged();
    await port.updateLiveActivity();
    return null;
  }

  /// 改名；找不到返回 null。
  static Future<TimeScheme?> rename(
    TimetableTimeSchemePort port,
    String schemeId,
    String name,
  ) async {
    await port.initialize();
    final schemes = List<TimeScheme>.from(port.timeSchemes);
    final index = schemes.indexWhere((scheme) => scheme.id == schemeId);
    if (index == -1) {
      return null;
    }

    final original = schemes[index];
    final updated = original.copyWith(
      name: name.trim(),
      updatedAt: DateTime.now(),
    );
    schemes[index] = updated;
    port.timeSchemes = schemes;
    try {
      await port.persistTimeSchemes();
    } catch (_) {
      final rollback = List<TimeScheme>.from(port.timeSchemes);
      rollback[index] = original;
      port.timeSchemes = rollback;
      rethrow;
    }
    port.notifyStateChanged();
    return updated;
  }

  /// 复制一套作息（默认名字加"副本"）；源不存在返回 null。
  static Future<TimeScheme?> duplicate(
    TimetableTimeSchemePort port,
    String schemeId, {
    String? name,
  }) async {
    await port.initialize();
    final source = port.timeSchemeById(schemeId);
    if (source == null) {
      return null;
    }

    final now = DateTime.now();
    final duplicated = source.copyWith(
      id: const Uuid().v4(),
      name: (name ?? '${source.name} 副本').trim(),
      createdAt: now,
      updatedAt: now,
      sections: List<SectionTime>.from(source.sections),
    );
    port.timeSchemes = <TimeScheme>[...port.timeSchemes, duplicated];
    try {
      await port.persistTimeSchemes();
    } catch (_) {
      port.timeSchemes = port.timeSchemes
          .where((item) => item.id != duplicated.id)
          .toList();
      rethrow;
    }
    port.notifyStateChanged();
    return duplicated;
  }

  /// 改一套作息的节次表；成功返回 null，失败返回消息编码。
  ///
  /// 节次表的收窄要按"现有课程最靠后的那一节"把关：收得太短会让课程无处取钟点，
  /// 报错要指出是哪份课表、哪门课（`section_count_below_usage_detail`）。
  static Future<String?> update(
    TimetableTimeSchemePort port, {
    required String schemeId,
    required String name,
    required List<SectionTime> sections,
  }) async {
    await port.initialize();
    final validationMessage = validateSectionTimes(sections);
    if (validationMessage != null) {
      return validationMessage;
    }
    final requiredMaxSection = TimeSchemeLogic.maxUsedSection(
      port.profiles,
      schemeId,
      schemes: port.timeSchemes,
      locationTimeGroups: port.locationTimeGroups,
    );
    if (requiredMaxSection > 0 && sections.length < requiredMaxSection) {
      final usage = TimeSchemeLogic.maxSectionUsage(
        port.profiles,
        schemeId,
        schemes: port.timeSchemes,
        locationTimeGroups: port.locationTimeGroups,
      );
      if (usage != null) {
        final usageType = usage.usesOverride
            ? 'usage_type_override'
            : 'usage_type_profile';
        return encodeServiceMessage('section_count_below_usage_detail', {
          'requiredMaxSection': requiredMaxSection,
          'profileName': usage.profileName,
          'courseName': usage.course.name,
          'dayOfWeek': usage.course.dayOfWeek,
          'startSection': usage.course.startSection,
          'endSection': usage.course.endSection,
          'usageType': usageType,
        });
      }
      return encodeServiceMessage('section_count_below_usage', {
        'requiredMaxSection': requiredMaxSection,
      });
    }

    final schemes = List<TimeScheme>.from(port.timeSchemes);
    final index = schemes.indexWhere((scheme) => scheme.id == schemeId);
    if (index == -1) {
      return 'time_scheme_not_found';
    }

    final updatedScheme = schemes[index].copyWith(
      name: name.trim(),
      sections: List<SectionTime>.from(sections),
      updatedAt: DateTime.now(),
    );
    // 本函数会同时改四份内存状态（作息表 / 全部档案 / 设置 / 当前课表），再分两次
    // await 落盘。任一步失败都必须整体退回，否则「内存已是新课表、盘上还是旧的」
    // 会被下一次成功写入当成既有状态落盘 —— 用户看到的是改了作息却只生效一半。
    final snapshotSchemes = List<TimeScheme>.from(port.timeSchemes);
    final snapshotProfiles = List<TimetableProfile>.from(port.profiles);
    final snapshotSettings = port.settings;
    final snapshotCourses = List<Course>.from(port.courses);
    schemes[index] = updatedScheme;
    port.timeSchemes = schemes;

    final nextProfiles = List<TimetableProfile>.from(port.profiles);
    for (var i = 0; i < nextProfiles.length; i++) {
      final profile = nextProfiles[i];
      final normalizedSettings = profile.settings.activeTimeSchemeId == schemeId
          ? profile.settings.copyWith(
              activeTimeSchemeId: schemeId,
              sections: List<SectionTime>.from(updatedScheme.sections),
            )
          : profile.settings;
      nextProfiles[i] = profile.copyWith(
        courses: port.syncCoursesWithEffectiveTimeSchemes(
          List<Course>.from(profile.courses),
          settings: normalizedSettings,
        ),
        settings: normalizedSettings,
      );
    }
    port.profiles = nextProfiles;

    if (port.settings.activeTimeSchemeId == schemeId) {
      port.settings = port.settings.copyWith(
        activeTimeSchemeId: schemeId,
        sections: List<SectionTime>.from(updatedScheme.sections),
      );
    }

    final activeProfileIndex = nextProfiles.indexWhere(
      (profile) => profile.id == port.activeProfileId,
    );
    if (activeProfileIndex != -1) {
      port.courses = List<Course>.from(nextProfiles[activeProfileIndex].courses);
      // 课表里的 settings 只是全局设置的备份镜像；从这里恢复内存状态时
      // 必须重新叠加全局真源，否则删除/导入留下的旧镜像会把设置倒退。
      port.settings = port.settingsFromProfile(nextProfiles[activeProfileIndex]);
      // 内存已叠加全局设置；同步写回活动课表镜像，避免下一次备份继续携带旧值。
      port.mergeActiveProfileIntoProfilesList();
    }

    try {
      await port.persistTimeSchemes();
      await port.saveProfiles(port.profiles);
    } catch (_) {
      port.timeSchemes = snapshotSchemes;
      port.profiles = snapshotProfiles;
      port.settings = snapshotSettings;
      port.courses = snapshotCourses;
      // 上面那次 `persistTimeSchemes` 已经**成功落盘**了（作息表是先写的那一份），
      // 所以光退内存会留下一半成功的状态：盘上是新节次表，内存是旧节次表。
      // 后果具体是「重启后作息自己变了」——启动时会把盘上那份作息对齐进各课表，
      // 于是用户被告知「没改成」的节次在下次冷启动时生效。
      // 补偿失败不遮住原始错误：原始失败对用户更有价值。
      try {
        await port.persistTimeSchemes();
      } catch (_) {
        // 与更新设置那条路径同处理：回滚本身失败只留在存储层。
      }
      rethrow;
    }
    port.clearCurrentLiveCourseId();
    port.notifyStateChanged();
    await port.updateLiveActivity();
    return null;
  }

  /// 删一套作息；被引用或不存在返回 false。
  static Future<bool> delete(
    TimetableTimeSchemePort port,
    String schemeId,
  ) async {
    await port.initialize();
    if (TimeSchemeLogic.isSchemeInUse(
      port.profiles,
      schemeId,
      locationTimeGroups: port.locationTimeGroups,
      schemes: port.timeSchemes,
      scheduleDateRules: port.scheduleDateRules,
    )) {
      return false;
    }

    final schemes = List<TimeScheme>.from(port.timeSchemes);
    final index = schemes.indexWhere((scheme) => scheme.id == schemeId);
    if (index == -1) {
      return false;
    }
    final removed = schemes.removeAt(index);
    port.timeSchemes = schemes;
    try {
      await port.persistTimeSchemes();
    } catch (_) {
      final rollback = List<TimeScheme>.from(port.timeSchemes);
      rollback.insert(index, removed);
      port.timeSchemes = rollback;
      rethrow;
    }
    port.notifyStateChanged();
    return true;
  }
}
