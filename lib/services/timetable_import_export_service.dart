import 'dart:async';

import 'package:uuid/uuid.dart';

import 'package:flutter/foundation.dart';

import '../domain/import_export_logic.dart';
import '../l10n/service_message_localizer.dart';
import '../models/course.dart';
import '../models/course_task.dart';
import '../models/exam.dart';
import '../models/location_time_group.dart';
import '../models/partner_timetable_binding.dart';
import '../models/schedule_date_rule.dart';
import '../models/schedule_item.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import '../data/timetable_repository.dart';
import 'timetable_core_state_port.dart';
import 'app_analytics.dart';
import 'app_global_settings_service.dart';
import 'data_transfer_service.dart';
import 'ics_import_service.dart';
import 'storage_service.dart';
import 'user_data_sync_hooks.dart';
import 'partner_timetable_service.dart';
import 'timetable_live_activity_service.dart';

/// 导入导出管线（课表/整包备份/唤醒日历）的宿主依赖面。
///
/// 由 `TimetableProvider` 实现。导入失败要「内存先退回、再尽力写回盘」，
/// 所以这个端口除了读数据，还必须能**写回 provider 的整份内存状态**——
/// 这是它比别的端口宽的唯一原因；快照对象 [FullBackupRestoreSnapshot] 因此
/// 也由服务库定义，provider 只负责把快照写回自己的字段。
abstract interface class TimetableImportExportPort implements TimetableCoreStatePort {
  // ── 数据面（读 + 写回） ──
  TimetableSettings get settings;
  set settings(TimetableSettings value);
  List<Course> get courses;
  set courses(List<Course> value);
  List<CourseTask> get tasks;
  set tasks(List<CourseTask> value);
  List<ScheduleItem> get scheduleItems;
  set scheduleItems(List<ScheduleItem> value);
  List<Exam> get exams;
  set exams(List<Exam> value);
  set profiles(List<TimetableProfile> value);
  List<TimeScheme> get timeSchemes;
  set timeSchemes(List<TimeScheme> value);
  List<LocationTimeGroup> get locationTimeGroups;
  set locationTimeGroups(List<LocationTimeGroup> value);
  List<ScheduleDateRule> get scheduleDateRules;
  set scheduleDateRules(List<ScheduleDateRule> value);
  PartnerTimetableBinding? get partnerBinding;
  set partnerBinding(PartnerTimetableBinding? value);
  String? get activeProfileId;
  set activeProfileId(String? value);
  String? get scheduleDateRuleLastAppliedSignature;
  set scheduleDateRuleLastAppliedSignature(String? value);
  int get currentWeek;
  set currentWeek(int value);
  int get currentDateWeek;
  set currentDateWeek(int value);
  int get currentCalendarWeek;
  set currentCalendarWeek(int value);
  int get currentDayOfWeek;
  set currentDayOfWeek(int value);
  Map<String, int> get lastImportDroppedCounts;
  set lastImportDroppedCounts(Map<String, int> value);
  TimetableProfile? get activeProfile;
  TimeScheme? get activeTimeScheme;
  LiveActivityRuntimeState get liveRuntime;

  /// 把快照写回 provider 的内存状态（写回是 provider 的职责，见类注释）。
  void restoreImportedMemory(FullBackupRestoreSnapshot snapshot);

  /// 新增一门课/一份课表时不走整体替换（保持 setter 语义干净）。
  void addTimeScheme(TimeScheme scheme);
  void addProfile(TimetableProfile profile);
  void clearCurrentLiveCourseId();

  // ── 服务/仓储句柄 ──
  //
  // `repository` / `storage` / `icsImporter` / `analytics` 原先都在这组。2026-10-20 起
  // 按「注入依赖不进端口」的设计意图（`provider 拆分诚实定界` 笔记「下一步」第 2 条
  // 引 provider 计划评审 :72-74）改为**调用方参数直传**：
  //
  //   端口只该暴露宿主的状态与内存写回（上面那两节），不该兼作依赖定位器。
  //   这四个是 provider 构造时注入进来的外部依赖，宿主持有它们只是为了装配；
  //   经端口再交出去等于把装配细节写进服务之间的契约——服务的可测性反而被拖住
  //   （要造一个假端口就得连仓储、存储、解析器、埋点一起造）。
  //
  // 收法：静态方法多出几个具名必填参数（`repository:` / `storage:` / `icsImporter:` /
  // `analytics:`），由唯一调用方 `TimetableProvider` 把自己的私有字段直传；
  // [FullBackupRestoreSnapshot] 在构造时把 repository / storage 一起接住，
  // 所以 `restorePersistence()` 不再需要 host 参数（7 处
  // `restoreAfterFullBackupFailure` 调用点因此全不用动）。
  //
  // `liveRuntime` 与四个原生面服务句柄属方案 B 范畴（真状态容器 / 原生面句柄），
  // 不在这一刀里动。`dataTransferService` 是**本族自带的解析器**（不是外部注入
  // 依赖，和本服务同属导入导出族），仍经端口取。
  DataTransferService get dataTransferService;

  // ── 命令 ──
  Future<T> runMutation<T>(Future<T> Function() operation);
  Future<void> persistActiveProfileState({
    bool touchLastUsedAt = false,
    bool notifySync = true,
  });
  TimetableSettings normalizeTimetableSettings(TimetableSettings settings);
  Future<void> persistTimeSchemes();
  Future<void> syncExamReminders();
  Future<void> updateLiveActivity({bool syncScheduleSnapshot = true});
  void applyProfileState(TimetableProfile profile);
  List<Course> syncCoursesWithEffectiveTimeSchemes(
    List<Course> source, {
    TimetableSettings? settings,
  });
  Future<TimetableSettings> resolveSettingsAgainstTimeSchemes(
    TimetableSettings settings, {
    required String fallbackName,
  });
  int calculateWeekForDate(DateTime date, {int? fallbackWeek});
  int resolveCurrentDateWeek();
  int previewImportedCourseRequiredSectionCount(
    List<Course> importedCourses, {
    required bool replaceExisting,
  });
  Future<String?> updateTimeScheme({
    required String schemeId,
    required String name,
    required List<SectionTime> sections,
  });
}

/// 导入扩节为「多张课表共用同一套作息」新建的作息副本的后缀。
///
/// 生成处在下面 `（导入补齐）` 分支，识别处在
/// `lib/services/import_time_scheme_restore_point.dart` 的 `_importSupplementSchemes`
/// （按名字含此后缀判定「导入自己造的副本」）。**判据必须同源**：两处若各写一份
/// 字面量，改一处漏一处就会漏删副本（中止导入后模板列表越攒越多）或误删用户作息。
/// 所以后缀只在这里定义一次，两边都引用它。
const importSupplementNameSuffix = '（导入补齐）';

/// 完整备份导入失败时使用的内存快照。
///
/// SharedPreferences 没有跨多个 key 的事务；这个对象先把 provider 的旧状态
/// 留一份，任何一步写盘或导入后同步失败时，至少先把界面恢复成导入前的样子，
/// 再尽力把旧数据写回各个 key。
///
/// 回滚要用的两个注入依赖（`repository` / `storage`）在构造时随宿主一起交进来：
/// 2026-10-20 起它们不再经端口取（「注入依赖不进端口」，见
/// [TimetableImportExportPort] 那节注释），所以 [restorePersistence] 也不再需要
/// host 参数——快照自己记住该往哪儿写。
class FullBackupRestoreSnapshot {
  FullBackupRestoreSnapshot(
    TimetableImportExportPort host, {
    required this._repository,
    required this._storage,
  }) : // 事务基准取构造时抓住的盘上值：用形参（= 私有字段）而不是 host 上的
       // 同一个对象绕一圈，快照不依赖宿主是否还持有它。
       mirrorBaseline = _storage.captureSettingsMirrorSnapshot(),
       timeSchemes = host.timeSchemes
          .map(
            (scheme) => scheme.copyWith(
              sections: List<SectionTime>.from(scheme.sections),
            ),
          )
          .toList(),
      locationTimeGroups = host.locationTimeGroups
          .map(
            (group) => group.copyWith(
              keywords: List<LocationKeyword>.from(group.keywords),
            ),
          )
          .toList(),
      scheduleDateRules = host.scheduleDateRules
          .map((rule) => rule.copyWith())
          .toList(),
      profiles = host.profiles
          .map(
            (profile) => profile.copyWith(
              courses: List<Course>.from(profile.courses),
              tasks: List<CourseTask>.from(profile.tasks),
              scheduleItems: List<ScheduleItem>.from(profile.scheduleItems),
              exams: List<Exam>.from(profile.exams),
            ),
          )
          .toList(),
      courses = List<Course>.from(host.courses),
      tasks = List<CourseTask>.from(host.tasks),
      scheduleItems = List<ScheduleItem>.from(host.scheduleItems),
      exams = List<Exam>.from(host.exams),
      settings = host.settings,
      currentWeek = host.currentWeek,
      currentDateWeek = host.currentDateWeek,
      currentCalendarWeek = host.currentCalendarWeek,
      currentDayOfWeek = host.currentDayOfWeek,
      activeProfileId = host.activeProfileId,
      partnerBinding = host.partnerBinding,
      scheduleDateRuleLastAppliedSignature =
          host.scheduleDateRuleLastAppliedSignature;

  final List<TimeScheme> timeSchemes;
  final List<LocationTimeGroup> locationTimeGroups;
  final List<ScheduleDateRule> scheduleDateRules;
  final List<TimetableProfile> profiles;
  final List<Course> courses;
  final List<CourseTask> tasks;
  final List<ScheduleItem> scheduleItems;
  final List<Exam> exams;
  final TimetableSettings settings;
  final int currentWeek;
  final int currentDateWeek;
  final int currentCalendarWeek;
  final int currentDayOfWeek;
  final String? activeProfileId;
  final PartnerTimetableBinding? partnerBinding;
  final String? scheduleDateRuleLastAppliedSignature;
  final Map<String, dynamic> mirrorBaseline;

  /// 回滚写盘用的仓储与存储（构造时从调用方接住，不再经端口取）。
  final TimetableRepository _repository;
  final StorageService _storage;

  void restoreMemory(TimetableImportExportPort host) {
    host.timeSchemes = List<TimeScheme>.from(timeSchemes);
    host.locationTimeGroups = List<LocationTimeGroup>.from(locationTimeGroups);
    host.scheduleDateRules = List<ScheduleDateRule>.from(scheduleDateRules);
    host.profiles = List<TimetableProfile>.from(profiles);
    host.courses = List<Course>.from(courses);
    host.tasks = List<CourseTask>.from(tasks);
    host.scheduleItems = List<ScheduleItem>.from(scheduleItems);
    host.exams = List<Exam>.from(exams);
    host.settings = settings;
    host.currentWeek = currentWeek;
    host.currentDateWeek = currentDateWeek;
    host.currentCalendarWeek = currentCalendarWeek;
    host.currentDayOfWeek = currentDayOfWeek;
    host.activeProfileId = activeProfileId;
    host.partnerBinding = partnerBinding;
    host.scheduleDateRuleLastAppliedSignature =
        scheduleDateRuleLastAppliedSignature;
    host.clearCurrentLiveCourseId();
    host.liveRuntime.lastLiveSnapshotSignature = null;
    host.liveRuntime.lastHomeWidgetSnapshotSignature = null;
  }

  /// 把 [restoreMemory] 恢复出来的那份状态写回磁盘（失败导入的补偿写）。
  ///
  /// 事务基准用 [mirrorBaseline]（构造时抓住的盘上值），不能用开事务时的
  /// 盘上值 —— 那时盘上已经是失败导入的半成品。
  Future<List<FullBackupRollbackFailure>> restorePersistence() async {
    final failures = <FullBackupRollbackFailure>[];

    Future<void> step(String name, Future<void> Function() operation) async {
      try {
        await operation();
      } catch (error, stackTrace) {
        failures.add(FullBackupRollbackFailure(name, error, stackTrace));
        if (kDebugMode) {
          debugPrint('Full backup rollback step "$name" failed: $error');
        }
      }
    }

    // 「profiles + activeProfileId + 全局设置键」这三个 key 必须整体过
    // `runSettingsMirrorTransaction`：普通导入路径经 `_persistActiveProfileState`
    // 写同一组 key 时都有这份保护（见 timetable_provider.dart:1435-1444），
    // 唯独这里逐条裸写 —— 三条写之间进程被杀，冷启动就是「课表列表已是新的、
    // activeProfileId 还指旧档」的固化混合态（2026-09-29 审计指认）。
    // 事务的 before 用 [mirrorBaseline]（构造时抓住的盘上值）：本函数紧跟
    // restoreMemory 运行，盘上已是失败导入，拿它当基准会把失败导入「恢复」回来。
    // step() 的逐条收集保留：非镜像 key（作息/分组/规则/伴侣绑定/签名）没有
    // 事务覆盖，失败语义与原先一致——继续把剩余 key 写完并如实上报；
    // 事务机制自身失败（恢复记录残留、日志写不进）会从这里上抛，记一条
    // 汇总失败项，返回值语义仍是「非空 = 回滚不完整」。
    try {
      // 与 _persistActiveProfileState 的事务分支同口径：先排空全局设置写队列，
      // 队列里未落盘的旧值不许与事务快照交错。
      await AppGlobalSettingsService.waitForPendingWrites();
      await _storage.runSettingsMirrorTransaction(() async {
        await step(
          'time_schemes',
          () => _repository.saveTimeSchemes(timeSchemes),
        );
        await step(
          'location_time_groups',
          () => _repository.saveLocationTimeGroups(locationTimeGroups),
        );
        await step(
          'schedule_date_rules',
          () => _repository.saveScheduleDateRules(scheduleDateRules),
        );
        await step('profiles', () => _repository.saveProfiles(profiles));
        await step('active_profile_id', () {
          if (activeProfileId == null) {
            return _repository.clearActiveProfileId();
          }
          return _repository.setActiveProfileId(activeProfileId!);
        });
        await step(
          'schedule_date_rule_signature',
          () => _repository.saveScheduleDateRuleLastAppliedSignature(
            scheduleDateRuleLastAppliedSignature,
          ),
        );
        await step(
          'partner_binding',
          () => _repository.savePartnerTimetableBinding(partnerBinding),
        );
        await step(
          'global_settings',
          () => AppGlobalSettingsService.syncFrom(settings),
        );
      }, beforeOverride: mirrorBaseline);
    } catch (error, stackTrace) {
      failures.add(
        FullBackupRollbackFailure(
          'settings_mirror_transaction',
          error,
          stackTrace,
        ),
      );
      if (kDebugMode) {
        debugPrint(
          'Full backup rollback settings mirror transaction failed: $error',
        );
      }
    }
    return failures;
  }
}

class FullBackupRollbackFailure {
  const FullBackupRollbackFailure(this.name, this.error, this.stackTrace);

  final String name;
  final Object error;
  final StackTrace stackTrace;
}

/// 导入导出用例：课程导入、整包备份导入（含失败回滚）、唤醒日历、节次扩容。
///
/// 2026-10-20 从 TimetableProvider 的 import_export_service.dart 分片整体搬出。
/// 写入纪律不变：内存先改、落盘失败整体回退并把失败项如实上报（见
/// [FullBackupRestoreSnapshot]）；所有入口都在宿主 mutation gate 内。
class TimetableImportExportService {
  const TimetableImportExportService._();

  static int previewWakeUpImportRequiredSectionCount(
    TimetableImportExportPort host,
    String content, {
    required bool replaceExisting,
    required IcsImportService icsImporter,
  }) {
    final result = icsImporter.parseWakeUpSchedule(content);
    return host.previewImportedCourseRequiredSectionCount(
      result.courses,
      replaceExisting: replaceExisting,
    );
  }

  static Future<String?> ensureSectionCapacityForImport(
    TimetableImportExportPort host,
    int requiredSectionCount,
  ) async {
    await host.initialize();
    if (requiredSectionCount <= host.settings.sectionCount) {
      return null;
    }

    final expandedSections = ImportExportLogic.buildExpandedSections(
      host.settings.sections,
      requiredSectionCount,
    );
    // 补不满就必须如实报错（2026-10-08）。`buildExpandedSections` 在
    // 「一条结束时间都解析不出来」或「当天已无余量」时会提前 `break`，返回的表**比
    // 要求短**；而下面两条分支都不检查长度，直接用这张短表去改作息、随后照常导入 ——
    // 界面拿到 null 以为补齐了，越界的那些课却拿不到钟点（读侧守卫
    // `resolvedCourseStartTime` / `time_scheme_logic.dart:446` 会静默跳过它们），
    // 用户看到的是"导入成功"而部分课在时间轴/超级岛里没有时间。
    // `buildExpandedSections` 自己那条注释承诺"节数不够由导入侧的校验与提示处理"，
    // 而这份校验此前并不存在 —— 这里补上，复用既有话术，不做任何写入。
    if (expandedSections.length < requiredSectionCount) {
      return encodeServiceMessage('section_count_below_usage', {
        'requiredMaxSection': requiredSectionCount,
      });
    }
    final currentScheme = host.activeTimeScheme;

    if (currentScheme == null) {
      // 形状：改 `_settings` / `_courses` → await 落盘 → notify。落盘抛错（磁盘满、
      // `commit()` 失败）时内存停在没落库的扩节结果上，而 `_persistActiveProfileState`
      // 的第一步 `_mergeActiveProfileIntoProfilesList` 已把它并进 `_profiles` ——
      // 下一次任意成功写入（切课表、加课、心跳）就把「导入失败」时的课表表头坐实。
      //
      // 契约与 `updateTimetableSettings` / `course_repository.dart` 的课程更新族、
      // `time_scheme_repository.dart` 的 `updateTimeScheme` 一致：抓快照 + catch 里
      // 整体退回 + `Error.throwWithStackTrace` 保留原始栈上抛（`import_shared.dart`
      // 的 `ensureImportSectionCapacity` 会把它当 `ensureMessage` 显示给用户，
      // 不能吞）。
      final snapshotSettings = host.settings;
      final snapshotCourses = List<Course>.from(host.courses);
      final snapshotProfiles = List<TimetableProfile>.from(host.profiles);
      host.settings = host.settings.copyWith(sections: expandedSections);
      host.courses = host.syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(host.courses),
        settings: host.settings,
      );
      try {
        await host.persistActiveProfileState();
      } catch (error, stackTrace) {
        host.settings = snapshotSettings;
        host.courses = snapshotCourses;
        host.profiles = snapshotProfiles;
        Error.throwWithStackTrace(error, stackTrace);
      }
      host.clearCurrentLiveCourseId();
      host.notifyStateChanged();
      await host.updateLiveActivity();
      return null;
    }

    final usageCount = host.profiles
        .where(
          (profile) => profile.settings.activeTimeSchemeId == currentScheme.id,
        )
        .length;

    if (usageCount <= 1) {
      return host.updateTimeScheme(
        schemeId: currentScheme.id,
        name: currentScheme.name,
        sections: expandedSections,
      );
    }

    final now = DateTime.now();
    final duplicatedScheme = currentScheme.copyWith(
      id: const Uuid().v4(),
      name: '${currentScheme.name}$importSupplementNameSuffix',
      sections: expandedSections,
      createdAt: now,
      updatedAt: now,
    );
    // 这条分支比上面那条多改一份 `_timeSchemes`，而且**分三次落盘**
    // （作息表 → 课表档案 → 活动课表镜像）。快照要覆盖全部四份内存状态，
    // catch 里也要把已成功落盘的那几次补偿回写，否则留下一半成功的状态：
    // 只退内存的话盘上留着「导入补齐」那份作息，冷启动的 `_ensureTimeSchemes`
    // 会把它对齐进各课表，用户视角是「导入失败了但作息自己多出一套」。
    //
    // 契约与 `time_scheme_repository.dart` 的 `updateTimeScheme` 一致（那份也是两次
    // 落盘、catch 里补一次 `_persistTimeSchemes`）。
    final snapshotSchemes = List<TimeScheme>.from(host.timeSchemes);
    final snapshotSettings = host.settings;
    final snapshotCourses = List<Course>.from(host.courses);
    final snapshotProfiles = List<TimetableProfile>.from(host.profiles);
    host.addTimeScheme(duplicatedScheme);
    try {
      await host.persistTimeSchemes();

      host.settings = host.settings.copyWith(
        activeTimeSchemeId: duplicatedScheme.id,
        sections: expandedSections,
      );
      host.courses = host.syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(host.courses),
        settings: host.settings,
      );
      await host.persistActiveProfileState();
    } catch (error, stackTrace) {
      host.timeSchemes = snapshotSchemes;
      host.settings = snapshotSettings;
      host.courses = snapshotCourses;
      host.profiles = snapshotProfiles;
      // 补偿已成功落盘的作息表；失败不遮住原始错误。
      try {
        await host.persistTimeSchemes();
      } catch (_) {
        // 回滚本身失败只留在存储层，原始失败对用户更有价值。
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    host.clearCurrentLiveCourseId();
    host.notifyStateChanged();
    await host.updateLiveActivity();
    return null;
  }

  static Future<int> importWakeUpCalendar(
    TimetableImportExportPort host,
    String content, {
    required bool replaceExisting,
    required IcsImportService icsImporter,
    required TimetableRepository repository,
    required StorageService storage,
    required AppAnalytics analytics,
  }) async {
    final result = icsImporter.parseWakeUpSchedule(content);
    return importParsedCourses(
      host,
      result.courses,
      replaceExisting: replaceExisting,
      semesterStart: result.semesterStart,
      source: 'ics',
      repository: repository,
      storage: storage,
      analytics: analytics,
    );
  }

  static Future<int> importParsedCourses(
    TimetableImportExportPort host,
    List<Course> importedCourses, {
    required bool replaceExisting,
    DateTime? semesterStart,
    required String source,
    required TimetableRepository repository,
    required StorageService storage,
    required AppAnalytics analytics,
    bool preserveLocalColors = true,
  }) {
    return host.runMutation(() async {
      if (importedCourses.isEmpty) {
        return 0;
      }

      // 快照必须抓在第一次改动之前：下面 `host.scheduleItems = []`（覆盖式导入）
      // 与 `_courses`/`_settings`/周次的整份替换都靠它退回。理由同 :359 与 :519
      // 那两条导入路径 —— 「先换内存、后写盘」一旦落盘失败而不退回，内存里就是
      // 一份从未落库的课表，而 `_persistActiveProfileState` 第一步
      // `_mergeActiveProfileIntoProfilesList` 已经把它并进了 `_profiles`，
      // 下一次任意成功写入会替用户坐实「日程整份没了」。
      final snapshot = FullBackupRestoreSnapshot(
        host,
        repository: repository,
        storage: storage,
      );

      final ImportedCourseSyncResult? syncResult;
      final List<Course> mergedCourses;
      final int effectiveImportedCount;
      if (replaceExisting) {
        final dedupedImportedCourses = dedupeImportedCourses(importedCourses);
        // Preserve local metadata (color/shortName/note/…) for matching courses.
        mergedCourses = replaceImportedCoursesPreservingLocalFields(
          existingCourses: host.courses,
          importedCourses: dedupedImportedCourses,
          preserveLocalColors: preserveLocalColors,
        );
        effectiveImportedCount = dedupedImportedCourses.length;
        syncResult = null;
        // Overwrite import replaces the active timetable: drop leftover agenda
        // rows that belonged to the previous course set (aligns with backup path).
        host.scheduleItems = [];
      } else {
        final result = syncImportedCourses(
          existingCourses: host.courses,
          importedCourses: importedCourses,
          preserveLocalColors: preserveLocalColors,
        );
        // 「课程一字不差」不等于「这次导入无事可做」：开学日期的唯一写入口在
        // 下面（`semesterStartDate: semesterStart ?? …`）以及随后的周次重算。
        // 早退会把用户在这一次导入里确认的学期开始日期整个丢掉 —— 面板提示
        // 「课表没有变化」，首页周次、选课提醒、超级岛、桌面卡却仍按旧日期排。
        final coursesUnchanged = courseListsEqual(
          host.courses,
          result.mergedCourses,
        );
        if (coursesUnchanged && semesterStart == null) {
          return 0;
        }
        syncResult = result;
        mergedCourses = result.mergedCourses;
        // 课程确实一门没变时，对外仍然报 0 变化（UI 据此提示「课表没有变化」），
        // 不能因为 `updatedCount` 把「匹配上并重建了同值课程」算成更新。
        effectiveImportedCount = coursesUnchanged
            ? 0
            : result.addedCount + result.updatedCount;
      }

      host.courses = host.syncCoursesWithEffectiveTimeSchemes(
        mergedCourses,
        settings: host.settings,
      );
      final requiredWeekCount = ImportExportLogic.maxCourseWeek(
        host.courses,
        fallbackWeekCount: host.settings.semesterWeekCount,
      );
      final cappedRequiredWeekCount = requiredWeekCount.clamp(
        1,
        ImportExportLogic.maxAllowedSemesterWeekCount,
      );
      host.settings = host.settings.copyWith(
        semesterStartDate: semesterStart ?? host.settings.semesterStartDate,
        semesterWeekCount:
            cappedRequiredWeekCount > host.settings.semesterWeekCount
            ? cappedRequiredWeekCount
            : host.settings.semesterWeekCount,
      );
      if (semesterStart != null) {
        host.currentWeek = host.calculateWeekForDate(
          DateTime.now(),
          fallbackWeek: host.currentWeek,
        );
      }
      host.currentDateWeek = host.resolveCurrentDateWeek();
      // Persist once at end of import; suppress mid-import cloud sync notify.
      try {
        await host.persistActiveProfileState(notifySync: false);
      } catch (error, stackTrace) {
        // 回滚里的补偿写入同样可能失败（磁盘本来就写不进去），那些失败由
        // `restoreAfterFullBackupFailure` 收进返回值；原始错误更有诊断价值，
        // 保留栈原样上抛，与 :406/:412 那两条导入路径同处理。
        await restoreAfterFullBackupFailure(host, snapshot);
        Error.throwWithStackTrace(error, stackTrace);
      }
      notifyUserDataChangedForSync();
      host.clearCurrentLiveCourseId();
      host.notifyStateChanged();
      analytics.logEventLater(
        name: 'schedule_imported',
        parameters: {
          'imported_course_count': effectiveImportedCount,
          'replace_existing': replaceExisting ? 1 : 0,
          'source': source,
          if (syncResult != null) ...{
            'sync_added_count': syncResult.addedCount,
            'sync_updated_count': syncResult.updatedCount,
          },
        },
      );
      await host.updateLiveActivity();
      return effectiveImportedCount;
    });
  }

  static Future<String?> importAppDataBackup(
    TimetableImportExportPort host,
    String content, {
    required TimetableRepository repository,
    required StorageService storage,
    required AppAnalytics analytics,
  }) async {
    // 回滚快照：与完整备份那条路径同款。缺了它，这条路径是**先换内存、后写盘**——
    // 磁盘满 → 抛错 → 内存里已经是新课表（界面立刻显示新课表），盘上还是旧的；
    // 用户退出 App 再进来，课表凭空消失。同一次改动里被一起包住的完整备份路径
    // 早就加了这个保护，单课表路径却没有，两条路径的失败后果完全不同却只有一条
    // 能自愈。
    //
    // 代价：快照会把全部课表档案各拷一份，而这里只改动当前档案的那几个字段。
    // 复用已有且已被测试的机制，好过再写一套只覆盖部分字段的平行实现。
    FullBackupRestoreSnapshot? snapshot;
    try {
      if (host.dataTransferService.isFullBackupJson(content)) {
        return importFullAppDataBackup(
          host,
          content,
          repository: repository,
          storage: storage,
        );
      }
      final backup = host.dataTransferService.parseBackupJson(content);
      snapshot = FullBackupRestoreSnapshot(
        host,
        repository: repository,
        storage: storage,
      );
      // 2026-10-08：`parseBackupJson` 现在会带回「跳过了多少条」（部分损坏）。
      // 原先这一档被静默吞掉：100 门课里坏 40 门会安静地导入 60 门、写盘、
      // 界面报「导入成功」，用户下次打开才发现少了几十节。
      // 这里把它挂到 host 上，由调用方（`data_transfer_screen.dart`）在成功提示里
      // 如实追加「跳过了 N 条」—— 覆盖写入照常发生（能救回 60 门比整份拒收友好），
      // 但不再谎报。
      host.lastImportDroppedCounts = Map<String, int>.of(backup.droppedCounts);
      final resolvedSettings = await host.resolveSettingsAgainstTimeSchemes(
        backup.settings,
        fallbackName: '${host.activeProfile?.name ?? "导入课表"} 时间',
      );
      host.courses = host.syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(backup.courses),
        settings: resolvedSettings,
      );
      final courseIds = host.courses.map((course) => course.id).toSet();
      host.tasks = backup.tasks
          .where(
            (task) => task.courseId == null || courseIds.contains(task.courseId),
          )
          .toList();
      host.exams = List<Exam>.from(backup.exams);
      host.scheduleItems = List<ScheduleItem>.from(backup.scheduleItems);
      // 设备级信任锚（更新镜像）保持本机取值：这条路径的入参是外部文件/局域网
      // 请求体，不该能改机主的更新通道。
      host.settings = resolvedSettings.keepingDeviceTrustAnchorsFrom(
        host.settings,
      );
      host.currentWeek = clampCurrentWeekToSettings(
        backup.currentWeek,
        host.settings,
      );

      await host.persistActiveProfileState();
      host.clearCurrentLiveCourseId();
      host.notifyStateChanged();
      unawaited(host.syncExamReminders());
      analytics.logEventLater(
        name: 'backup_imported',
        parameters: {
          'course_count': host.courses.length,
          'current_week': host.currentWeek,
        },
      );
      await host.updateLiveActivity();
      return null;
    } on FormatException catch (e) {
      final rollbackFailures = await restoreAfterFullBackupFailure(
        host,
        snapshot,
      );
      return rollbackFailures.isEmpty ? e.message : 'import_rollback_incomplete';
    } catch (_) {
      final rollbackFailures = await restoreAfterFullBackupFailure(
        host,
        snapshot,
      );
      if (rollbackFailures.isNotEmpty) {
        return 'import_rollback_incomplete';
      }
      return 'import_file_unrecognized';
    }
  }

  static Future<String?> importAppDataBackupAsNewProfile(
    TimetableImportExportPort host,
    String content, {
    String? profileName,
    required TimetableRepository repository,
    required StorageService storage,
    required AppAnalytics analytics,
  }) async {
    FullBackupRestoreSnapshot? snapshot;
    try {
      if (host.dataTransferService.isFullBackupJson(content)) {
        return 'import_use_overwrite_for_full_backup';
      }
      final backup = host.dataTransferService.parseBackupJson(content);
      // 2026-10-08：与「覆盖导入」那条路同款，把「跳过了多少条」挂到 host 上，
      // 由 `main.dart` 在成功提示里如实追加「跳过了 N 条」。这条路径原先也静默
      // 吞掉部分损坏：100 门里坏 40 门会安静导入 60 门、报「已创建新课表」——
      // 用户看到「成功」却少了几十节。整份拒收不友好，能救多少救多少，但不谎报。
      host.lastImportDroppedCounts = Map<String, int>.of(backup.droppedCounts);
      // 快照必须在第一次改动之前抓：下面 `_resolveSettingsAgainstTimeSchemes` 就会
      // 创建并落盘新作息，之后还要 add 新档案、切激活档案、`_applyProfileState`。
      snapshot = FullBackupRestoreSnapshot(
        host,
        repository: repository,
        storage: storage,
      );
      final nextName = (profileName ?? backup.profileName ?? '导入课表').trim();
      final resolvedSettings = await host.resolveSettingsAgainstTimeSchemes(
        backup.settings,
        fallbackName: '$nextName 时间',
      );
      final profileCourses = host.syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(backup.courses),
        settings: resolvedSettings,
      );
      final now = DateTime.now();
      final nextProfile = TimetableProfile(
        id: const Uuid().v4(),
        name: nextName,
        courses: profileCourses,
        tasks: backup.tasks
            .where(
              (task) =>
                  task.courseId == null ||
                  profileCourses.any((course) => course.id == task.courseId),
            )
            .toList(),
        scheduleItems: List<ScheduleItem>.from(backup.scheduleItems),
        exams: List<Exam>.from(backup.exams),
        settings: resolvedSettings,
        currentWeek: clampCurrentWeekToSettings(
          backup.currentWeek,
          resolvedSettings,
        ),
        createdAt: now,
        lastUsedAt: now,
      );

      await host.persistActiveProfileState();
      host.addProfile(nextProfile);
      host.activeProfileId = nextProfile.id;
      host.applyProfileState(nextProfile);
      await host.persistActiveProfileState(touchLastUsedAt: true);
      host.clearCurrentLiveCourseId();
      host.notifyStateChanged();
      unawaited(host.syncExamReminders());
      analytics.logEventLater(
        name: 'backup_imported',
        parameters: {
          'course_count': host.courses.length,
          'current_week': host.currentWeek,
          'created_profile': 1,
        },
      );
      await host.updateLiveActivity();
      return null;
    } on FormatException catch (e) {
      // 与整表覆盖那条路径同款：失败要按快照把内存与盘都退回去。这里原先直接
      // return 错误串，内存里却已经 add 了新档案并切了激活档案（`_applyProfileState`
      // 还不 notify，UI 仍显示旧课表），随后任意一次成功写入会把这份幻影档案永久落盘。
      final rollbackFailures = await restoreAfterFullBackupFailure(
        host,
        snapshot,
      );
      return rollbackFailures.isEmpty ? e.message : 'import_rollback_incomplete';
    } catch (_) {
      final rollbackFailures = await restoreAfterFullBackupFailure(
        host,
        snapshot,
      );
      if (rollbackFailures.isNotEmpty) {
        return 'import_rollback_incomplete';
      }
      return 'import_file_unrecognized';
    }
  }

  static Future<String?> importFullAppDataBackup(
    TimetableImportExportPort host,
    String content, {
    required TimetableRepository repository,
    required StorageService storage,
  }) {
    return host.runMutation(() async {
      FullBackupRestoreSnapshot? snapshot;
      try {
        final backup = host.dataTransferService.parseFullBackupJson(content);
        if (backup.profiles.isEmpty) {
          return 'import_no_profiles_in_backup';
        }
        snapshot = FullBackupRestoreSnapshot(
          host,
          repository: repository,
          storage: storage,
        );

        host.timeSchemes = List<TimeScheme>.from(backup.timeSchemes);
        host.locationTimeGroups = List<LocationTimeGroup>.from(
          backup.locationTimeGroups,
        );
        host.scheduleDateRules = List<ScheduleDateRule>.from(
          backup.scheduleDateRules,
        );
        host.profiles = backup.profiles
            .map(
              (profile) => profile.copyWith(
                // 设备级信任锚不随备份/云快照外来数据改写，见该方法注释。
                settings: host
                    .normalizeTimetableSettings(profile.settings)
                    .keepingDeviceTrustAnchorsFrom(host.settings),
              ),
            )
            .toList();
        host.profiles = host.profiles
            .map(
              (profile) => profile.copyWith(
                courses: host.syncCoursesWithEffectiveTimeSchemes(
                  List<Course>.from(profile.courses),
                  settings: profile.settings,
                ),
              ),
            )
            .toList();
        host.activeProfileId =
            backup.activeProfileId != null &&
                host.profiles.any(
                  (profile) => profile.id == backup.activeProfileId,
                )
            ? backup.activeProfileId
            : host.profiles.first.id;

        await repository.saveTimeSchemes(host.timeSchemes);
        await repository.saveLocationTimeGroups(host.locationTimeGroups);
        await repository.saveScheduleDateRules(host.scheduleDateRules);
        await repository.saveProfiles(host.profiles);
        if (host.activeProfileId != null) {
          await repository.setActiveProfileId(host.activeProfileId!);
        }

        host.applyProfileState(
          host.profiles.firstWhere(
            (profile) => profile.id == host.activeProfileId,
          ),
        );

        // 完整备份携带的课表镜像是全局设置的来源。导入路径也必须重推一次，
        // 否则本机旧的全局键会把刚恢复的语言 / 主题 / 材质重新盖回去。
        await AppGlobalSettingsService.refreshFromImportedProfiles(
          profiles: host.profiles,
          activeProfileId: host.activeProfileId,
        );
        final importedActive = host.activeProfile;
        if (importedActive != null) {
          host.applyProfileState(importedActive);
        }

        // Full backup schema does not carry partner binding; drop orphans when
        // the partner profile is missing from the restored profiles list.
        final hasPartnerProfile = host.profiles.any(
          (profile) => profile.id == PartnerTimetableService.partnerProfileId,
        );
        if (!hasPartnerProfile && host.partnerBinding != null) {
          host.partnerBinding = null;
          await repository.savePartnerTimetableBinding(null);
        }

        host.clearCurrentLiveCourseId();
        host.notifyStateChanged();
        unawaited(host.syncExamReminders());
        await host.updateLiveActivity();
        return null;
      } on FormatException catch (e) {
        final rollbackFailures = await restoreAfterFullBackupFailure(
          host,
          snapshot,
        );
        return rollbackFailures.isEmpty
            ? e.message
            : 'import_rollback_incomplete';
      } catch (_) {
        final rollbackFailures = await restoreAfterFullBackupFailure(
          host,
          snapshot,
        );
        if (rollbackFailures.isNotEmpty) {
          return 'import_rollback_incomplete';
        }
        return 'import_file_unrecognized';
      }
    });
  }

  static Future<List<FullBackupRollbackFailure>> restoreAfterFullBackupFailure(
    TimetableImportExportPort host,
    FullBackupRestoreSnapshot? snapshot,
  ) async {
    if (snapshot == null) {
      return const <FullBackupRollbackFailure>[];
    }
    snapshot.restoreMemory(host);
    final failures = await snapshot.restorePersistence();
    host.clearCurrentLiveCourseId();
    host.notifyStateChanged();
    try {
      await host.updateLiveActivity();
    } catch (error, stackTrace) {
      failures.add(FullBackupRollbackFailure('live_surface', error, stackTrace));
      if (kDebugMode) {
        debugPrint('Full backup rollback live-surface refresh failed: $error');
      }
    }
    return failures;
  }
}
