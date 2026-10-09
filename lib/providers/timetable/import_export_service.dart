part of '../timetable_provider.dart';

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
class _FullBackupRestoreSnapshot {
  _FullBackupRestoreSnapshot(TimetableProvider host)
    : timeSchemes = host._timeSchemes
          .map(
            (scheme) => scheme.copyWith(
              sections: List<SectionTime>.from(scheme.sections),
            ),
          )
          .toList(),
      locationTimeGroups = host._locationTimeGroups
          .map(
            (group) => group.copyWith(
              keywords: List<LocationKeyword>.from(group.keywords),
            ),
          )
          .toList(),
      scheduleDateRules = host._scheduleDateRules
          .map((rule) => rule.copyWith())
          .toList(),
      profiles = host._profiles
          .map(
            (profile) => profile.copyWith(
              courses: List<Course>.from(profile.courses),
              tasks: List<CourseTask>.from(profile.tasks),
              scheduleItems: List<ScheduleItem>.from(profile.scheduleItems),
              exams: List<Exam>.from(profile.exams),
            ),
          )
          .toList(),
      courses = List<Course>.from(host._courses),
      tasks = List<CourseTask>.from(host._tasks),
      scheduleItems = List<ScheduleItem>.from(host._scheduleItems),
      exams = List<Exam>.from(host._exams),
      settings = host._settings,
      currentWeek = host._currentWeek,
      currentDateWeek = host._currentDateWeek,
      currentCalendarWeek = host._currentCalendarWeek,
      currentDayOfWeek = host._currentDayOfWeek,
      activeProfileId = host._activeProfileId,
      partnerBinding = host._partnerBinding,
      scheduleDateRuleLastAppliedSignature =
          host._scheduleDateRuleLastAppliedSignature;

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

  void restoreMemory(TimetableProvider host) {
    host._timeSchemes = List<TimeScheme>.from(timeSchemes);
    host._locationTimeGroups = List<LocationTimeGroup>.from(locationTimeGroups);
    host._scheduleDateRules = List<ScheduleDateRule>.from(scheduleDateRules);
    host._profiles = List<TimetableProfile>.from(profiles);
    host._courses = List<Course>.from(courses);
    host._tasks = List<CourseTask>.from(tasks);
    host._scheduleItems = List<ScheduleItem>.from(scheduleItems);
    host._exams = List<Exam>.from(exams);
    host._settings = settings;
    host._currentWeek = currentWeek;
    host._currentDateWeek = currentDateWeek;
    host._currentCalendarWeek = currentCalendarWeek;
    host._currentDayOfWeek = currentDayOfWeek;
    host._activeProfileId = activeProfileId;
    host._partnerBinding = partnerBinding;
    host._scheduleDateRuleLastAppliedSignature =
        scheduleDateRuleLastAppliedSignature;
    host._currentLiveCourseId = null;
    host._lastLiveSnapshotSignature = null;
    host._lastHomeWidgetSnapshotSignature = null;
  }

  Future<List<_FullBackupRollbackFailure>> restorePersistence(
    TimetableProvider host,
  ) async {
    final repository = host._profileRepository;
    final failures = <_FullBackupRollbackFailure>[];

    Future<void> step(String name, Future<void> Function() operation) async {
      try {
        await operation();
      } catch (error, stackTrace) {
        failures.add(_FullBackupRollbackFailure(name, error, stackTrace));
        if (kDebugMode) {
          debugPrint('Full backup rollback step "$name" failed: $error');
        }
      }
    }

    await step('time_schemes', () => repository.saveTimeSchemes(timeSchemes));
    await step(
      'location_time_groups',
      () => repository.saveLocationTimeGroups(locationTimeGroups),
    );
    await step(
      'schedule_date_rules',
      () => repository.saveScheduleDateRules(scheduleDateRules),
    );
    await step('profiles', () => repository.saveProfiles(profiles));
    await step('active_profile_id', () {
      if (activeProfileId == null) {
        return repository.clearActiveProfileId();
      }
      return repository.setActiveProfileId(activeProfileId!);
    });
    await step(
      'schedule_date_rule_signature',
      () => repository.saveScheduleDateRuleLastAppliedSignature(
        scheduleDateRuleLastAppliedSignature,
      ),
    );
    await step(
      'partner_binding',
      () => repository.savePartnerTimetableBinding(partnerBinding),
    );
    await step(
      'global_settings',
      () => AppGlobalSettingsService.syncFrom(settings),
    );
    return failures;
  }
}

class _FullBackupRollbackFailure {
  const _FullBackupRollbackFailure(this.name, this.error, this.stackTrace);

  final String name;
  final Object error;
  final StackTrace stackTrace;
}

int _timetablePreviewWakeUpImportRequiredSectionCount(
  TimetableProvider host,
  String content, {
  required bool replaceExisting,
}) {
  final result = host._icsImportService.parseWakeUpSchedule(content);
  return host.previewImportedCourseRequiredSectionCount(
    result.courses,
    replaceExisting: replaceExisting,
  );
}

Future<String?> _timetableEnsureSectionCapacityForImport(
  TimetableProvider host,
  int requiredSectionCount,
) async {
  await host.initialize();
  if (requiredSectionCount <= host._settings.sectionCount) {
    return null;
  }

  final expandedSections = ImportExportLogic.buildExpandedSections(
    host._settings.sections,
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
    final snapshotSettings = host._settings;
    final snapshotCourses = List<Course>.from(host._courses);
    final snapshotProfiles = List<TimetableProfile>.from(host._profiles);
    host._settings = host._settings.copyWith(sections: expandedSections);
    host._courses = host._syncCoursesWithEffectiveTimeSchemes(
      List<Course>.from(host._courses),
      settings: host._settings,
    );
    try {
      await host._persistActiveProfileState();
    } catch (error, stackTrace) {
      host._settings = snapshotSettings;
      host._courses = snapshotCourses;
      host._profiles = snapshotProfiles;
      Error.throwWithStackTrace(error, stackTrace);
    }
    host._currentLiveCourseId = null;
    host._notifyStateChanged();
    await host._updateLiveActivity();
    return null;
  }

  final usageCount = host._profiles
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
  final snapshotSchemes = List<TimeScheme>.from(host._timeSchemes);
  final snapshotSettings = host._settings;
  final snapshotCourses = List<Course>.from(host._courses);
  final snapshotProfiles = List<TimetableProfile>.from(host._profiles);
  host._timeSchemes.add(duplicatedScheme);
  try {
    await host._persistTimeSchemes();

    host._settings = host._settings.copyWith(
      activeTimeSchemeId: duplicatedScheme.id,
      sections: expandedSections,
    );
    host._courses = host._syncCoursesWithEffectiveTimeSchemes(
      List<Course>.from(host._courses),
      settings: host._settings,
    );
    await host._persistActiveProfileState();
  } catch (error, stackTrace) {
    host._timeSchemes = snapshotSchemes;
    host._settings = snapshotSettings;
    host._courses = snapshotCourses;
    host._profiles = snapshotProfiles;
    // 补偿已成功落盘的作息表；失败不遮住原始错误。
    try {
      await host._persistTimeSchemes();
    } catch (_) {
      // 回滚本身失败只留在存储层，原始失败对用户更有价值。
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
  host._currentLiveCourseId = null;
  host._notifyStateChanged();
  await host._updateLiveActivity();
  return null;
}

Future<int> _timetableImportWakeUpCalendar(
  TimetableProvider host,
  String content, {
  required bool replaceExisting,
}) async {
  final result = host._icsImportService.parseWakeUpSchedule(content);
  return host.importParsedCourses(
    result.courses,
    replaceExisting: replaceExisting,
    semesterStart: result.semesterStart,
    source: 'ics',
  );
}

Future<int> _timetableImportParsedCourses(
  TimetableProvider host,
  List<Course> importedCourses, {
  required bool replaceExisting,
  DateTime? semesterStart,
  required String source,
  bool preserveLocalColors = true,
}) {
  return host._runMutation(() async {
    if (importedCourses.isEmpty) {
      return 0;
    }

    // 快照必须抓在第一次改动之前：下面 `host._scheduleItems = []`（覆盖式导入）
    // 与 `_courses`/`_settings`/周次的整份替换都靠它退回。理由同 :359 与 :519
    // 那两条导入路径 —— 「先换内存、后写盘」一旦落盘失败而不退回，内存里就是
    // 一份从未落库的课表，而 `_persistActiveProfileState` 第一步
    // `_mergeActiveProfileIntoProfilesList` 已经把它并进了 `_profiles`，
    // 下一次任意成功写入会替用户坐实「日程整份没了」。
    final snapshot = _FullBackupRestoreSnapshot(host);

    final ImportedCourseSyncResult? syncResult;
    final List<Course> mergedCourses;
    final int effectiveImportedCount;
    if (replaceExisting) {
      final dedupedImportedCourses = dedupeImportedCourses(importedCourses);
      // Preserve local metadata (color/shortName/note/…) for matching courses.
      mergedCourses = replaceImportedCoursesPreservingLocalFields(
        existingCourses: host._courses,
        importedCourses: dedupedImportedCourses,
        preserveLocalColors: preserveLocalColors,
      );
      effectiveImportedCount = dedupedImportedCourses.length;
      syncResult = null;
      // Overwrite import replaces the active timetable: drop leftover agenda
      // rows that belonged to the previous course set (aligns with backup path).
      host._scheduleItems = [];
    } else {
      final result = syncImportedCourses(
        existingCourses: host._courses,
        importedCourses: importedCourses,
        preserveLocalColors: preserveLocalColors,
      );
      // 「课程一字不差」不等于「这次导入无事可做」：开学日期的唯一写入口在
      // 下面（`semesterStartDate: semesterStart ?? …`）以及随后的周次重算。
      // 早退会把用户在这一次导入里确认的学期开始日期整个丢掉 —— 面板提示
      // 「课表没有变化」，首页周次、选课提醒、超级岛、桌面卡却仍按旧日期排。
      final coursesUnchanged = courseListsEqual(
        host._courses,
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

    host._courses = host._syncCoursesWithEffectiveTimeSchemes(
      mergedCourses,
      settings: host._settings,
    );
    final requiredWeekCount = ImportExportLogic.maxCourseWeek(
      host._courses,
      fallbackWeekCount: host._settings.semesterWeekCount,
    );
    final cappedRequiredWeekCount = requiredWeekCount.clamp(
      1,
      ImportExportLogic.maxAllowedSemesterWeekCount,
    );
    host._settings = host._settings.copyWith(
      semesterStartDate: semesterStart ?? host._settings.semesterStartDate,
      semesterWeekCount:
          cappedRequiredWeekCount > host._settings.semesterWeekCount
          ? cappedRequiredWeekCount
          : host._settings.semesterWeekCount,
    );
    if (semesterStart != null) {
      host._currentWeek = host._calculateWeekForDate(
        DateTime.now(),
        fallbackWeek: host._currentWeek,
      );
    }
    host._currentDateWeek = host._resolveCurrentDateWeek();
    // Persist once at end of import; suppress mid-import cloud sync notify.
    try {
      await host._persistActiveProfileState(notifySync: false);
    } catch (error, stackTrace) {
      // 回滚里的补偿写入同样可能失败（磁盘本来就写不进去），那些失败由
      // `_restoreAfterFullBackupFailure` 收进返回值；原始错误更有诊断价值，
      // 保留栈原样上抛，与 :406/:412 那两条导入路径同处理。
      await _restoreAfterFullBackupFailure(host, snapshot);
      Error.throwWithStackTrace(error, stackTrace);
    }
    notifyUserDataChangedForSync();
    host._currentLiveCourseId = null;
    host._notifyStateChanged();
    host._analytics.logEventLater(
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
    await host._updateLiveActivity();
    return effectiveImportedCount;
  });
}

Future<String?> _timetableImportAppDataBackup(
  TimetableProvider host,
  String content,
) async {
  // 回滚快照：与完整备份那条路径同款。缺了它，这条路径是**先换内存、后写盘**——
  // 磁盘满 → 抛错 → 内存里已经是新课表（界面立刻显示新课表），盘上还是旧的；
  // 用户退出 App 再进来，课表凭空消失。同一次改动里被一起包住的完整备份路径
  // 早就加了这个保护，单课表路径却没有，两条路径的失败后果完全不同却只有一条
  // 能自愈。
  //
  // 代价：快照会把全部课表档案各拷一份，而这里只改动当前档案的那几个字段。
  // 复用已有且已被测试的机制，好过再写一套只覆盖部分字段的平行实现。
  _FullBackupRestoreSnapshot? snapshot;
  try {
    if (host._dataTransferService.isFullBackupJson(content)) {
      return host.importFullAppDataBackup(content);
    }
    final backup = host._dataTransferService.parseBackupJson(content);
    snapshot = _FullBackupRestoreSnapshot(host);
    // 2026-10-08：`parseBackupJson` 现在会带回「跳过了多少条」（部分损坏）。
    // 原先这一档被静默吞掉：100 门课里坏 40 门会安静地导入 60 门、写盘、
    // 界面报「导入成功」，用户下次打开才发现少了几十节。
    // 这里把它挂到 host 上，由调用方（`data_transfer_screen.dart`）在成功提示里
    // 如实追加「跳过了 N 条」—— 覆盖写入照常发生（能救回 60 门比整份拒收友好），
    // 但不再谎报。
    host._lastImportDroppedCounts = Map<String, int>.of(backup.droppedCounts);
    final resolvedSettings = await host._resolveSettingsAgainstTimeSchemes(
      backup.settings,
      fallbackName: '${host.activeProfile?.name ?? "导入课表"} 时间',
    );
    host._courses = host._syncCoursesWithEffectiveTimeSchemes(
      List<Course>.from(backup.courses),
      settings: resolvedSettings,
    );
    final courseIds = host._courses.map((course) => course.id).toSet();
    host._tasks = backup.tasks
        .where(
          (task) => task.courseId == null || courseIds.contains(task.courseId),
        )
        .toList();
    host._exams = List<Exam>.from(backup.exams);
    host._scheduleItems = List<ScheduleItem>.from(backup.scheduleItems);
    // 设备级信任锚（更新镜像）保持本机取值：这条路径的入参是外部文件/局域网
    // 请求体，不该能改机主的更新通道。
    host._settings = resolvedSettings.keepingDeviceTrustAnchorsFrom(
      host._settings,
    );
    host._currentWeek = clampCurrentWeekToSettings(
      backup.currentWeek,
      host._settings,
    );

    await host._persistActiveProfileState();
    host._currentLiveCourseId = null;
    host._notifyStateChanged();
    unawaited(host._syncExamReminders());
    host._analytics.logEventLater(
      name: 'backup_imported',
      parameters: {
        'course_count': host._courses.length,
        'current_week': host._currentWeek,
      },
    );
    await host._updateLiveActivity();
    return null;
  } on FormatException catch (e) {
    final rollbackFailures = await _restoreAfterFullBackupFailure(
      host,
      snapshot,
    );
    return rollbackFailures.isEmpty ? e.message : 'import_rollback_incomplete';
  } catch (_) {
    final rollbackFailures = await _restoreAfterFullBackupFailure(
      host,
      snapshot,
    );
    if (rollbackFailures.isNotEmpty) {
      return 'import_rollback_incomplete';
    }
    return 'import_file_unrecognized';
  }
}

Future<String?> _timetableImportAppDataBackupAsNewProfile(
  TimetableProvider host,
  String content, {
  String? profileName,
}) async {
  _FullBackupRestoreSnapshot? snapshot;
  try {
    if (host._dataTransferService.isFullBackupJson(content)) {
      return 'import_use_overwrite_for_full_backup';
    }
    final backup = host._dataTransferService.parseBackupJson(content);
    // 2026-10-08：与「覆盖导入」那条路同款，把「跳过了多少条」挂到 host 上，
    // 由 `main.dart` 在成功提示里如实追加「跳过了 N 条」。这条路径原先也静默
    // 吞掉部分损坏：100 门里坏 40 门会安静导入 60 门、报「已创建新课表」——
    // 用户看到「成功」却少了几十节。整份拒收不友好，能救多少救多少，但不谎报。
    host._lastImportDroppedCounts = Map<String, int>.of(backup.droppedCounts);
    // 快照必须在第一次改动之前抓：下面 `_resolveSettingsAgainstTimeSchemes` 就会
    // 创建并落盘新作息，之后还要 add 新档案、切激活档案、`_applyProfileState`。
    snapshot = _FullBackupRestoreSnapshot(host);
    final nextName = (profileName ?? backup.profileName ?? '导入课表').trim();
    final resolvedSettings = await host._resolveSettingsAgainstTimeSchemes(
      backup.settings,
      fallbackName: '$nextName 时间',
    );
    final profileCourses = host._syncCoursesWithEffectiveTimeSchemes(
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

    await host._persistActiveProfileState();
    host._profiles.add(nextProfile);
    host._activeProfileId = nextProfile.id;
    host._applyProfileState(nextProfile);
    await host._persistActiveProfileState(touchLastUsedAt: true);
    host._currentLiveCourseId = null;
    host._notifyStateChanged();
    unawaited(host._syncExamReminders());
    host._analytics.logEventLater(
      name: 'backup_imported',
      parameters: {
        'course_count': host._courses.length,
        'current_week': host._currentWeek,
        'created_profile': 1,
      },
    );
    await host._updateLiveActivity();
    return null;
  } on FormatException catch (e) {
    // 与整表覆盖那条路径同款：失败要按快照把内存与盘都退回去。这里原先直接
    // return 错误串，内存里却已经 add 了新档案并切了激活档案（`_applyProfileState`
    // 还不 notify，UI 仍显示旧课表），随后任意一次成功写入会把这份幻影档案永久落盘。
    final rollbackFailures = await _restoreAfterFullBackupFailure(
      host,
      snapshot,
    );
    return rollbackFailures.isEmpty ? e.message : 'import_rollback_incomplete';
  } catch (_) {
    final rollbackFailures = await _restoreAfterFullBackupFailure(
      host,
      snapshot,
    );
    if (rollbackFailures.isNotEmpty) {
      return 'import_rollback_incomplete';
    }
    return 'import_file_unrecognized';
  }
}

Future<String?> _timetableImportFullAppDataBackup(
  TimetableProvider host,
  String content,
) {
  return host._runMutation(() async {
    _FullBackupRestoreSnapshot? snapshot;
    try {
      final backup = host._dataTransferService.parseFullBackupJson(content);
      if (backup.profiles.isEmpty) {
        return 'import_no_profiles_in_backup';
      }
      snapshot = _FullBackupRestoreSnapshot(host);

      host._timeSchemes = List<TimeScheme>.from(backup.timeSchemes);
      host._locationTimeGroups = List<LocationTimeGroup>.from(
        backup.locationTimeGroups,
      );
      host._scheduleDateRules = List<ScheduleDateRule>.from(
        backup.scheduleDateRules,
      );
      host._profiles = backup.profiles
          .map(
            (profile) => profile.copyWith(
              // 设备级信任锚不随备份/云快照外来数据改写，见该方法注释。
              settings: _normalizeSettingsWithTimeScheme(
                host,
                profile.settings,
              ).keepingDeviceTrustAnchorsFrom(host._settings),
            ),
          )
          .toList();
      host._profiles = host._profiles
          .map(
            (profile) => profile.copyWith(
              courses: host._syncCoursesWithEffectiveTimeSchemes(
                List<Course>.from(profile.courses),
                settings: profile.settings,
              ),
            ),
          )
          .toList();
      host._activeProfileId =
          backup.activeProfileId != null &&
              host._profiles.any(
                (profile) => profile.id == backup.activeProfileId,
              )
          ? backup.activeProfileId
          : host._profiles.first.id;

      await host._profileRepository.saveTimeSchemes(host._timeSchemes);
      await host._profileRepository.saveLocationTimeGroups(
        host._locationTimeGroups,
      );
      await host._profileRepository.saveScheduleDateRules(
        host._scheduleDateRules,
      );
      await host._profileRepository.saveProfiles(host._profiles);
      if (host._activeProfileId != null) {
        await host._profileRepository.setActiveProfileId(
          host._activeProfileId!,
        );
      }

      host._applyProfileState(
        host._profiles.firstWhere(
          (profile) => profile.id == host._activeProfileId,
        ),
      );

      // 完整备份携带的课表镜像是全局设置的来源。导入路径也必须重推一次，
      // 否则本机旧的全局键会把刚恢复的语言 / 主题 / 材质重新盖回去。
      await AppGlobalSettingsService.refreshFromImportedProfiles(
        profiles: host._profiles,
        activeProfileId: host._activeProfileId,
      );
      final importedActive = host.activeProfile;
      if (importedActive != null) {
        host._applyProfileState(importedActive);
      }

      // Full backup schema does not carry partner binding; drop orphans when
      // the partner profile is missing from the restored profiles list.
      final hasPartnerProfile = host._profiles.any(
        (profile) => profile.id == PartnerTimetableService.partnerProfileId,
      );
      if (!hasPartnerProfile && host._partnerBinding != null) {
        host._partnerBinding = null;
        await host._profileRepository.savePartnerTimetableBinding(null);
      }

      host._currentLiveCourseId = null;
      host._notifyStateChanged();
      unawaited(host._syncExamReminders());
      await host._updateLiveActivity();
      return null;
    } on FormatException catch (e) {
      final rollbackFailures = await _restoreAfterFullBackupFailure(
        host,
        snapshot,
      );
      return rollbackFailures.isEmpty
          ? e.message
          : 'import_rollback_incomplete';
    } catch (_) {
      final rollbackFailures = await _restoreAfterFullBackupFailure(
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

Future<List<_FullBackupRollbackFailure>> _restoreAfterFullBackupFailure(
  TimetableProvider host,
  _FullBackupRestoreSnapshot? snapshot,
) async {
  if (snapshot == null) {
    return const <_FullBackupRollbackFailure>[];
  }
  snapshot.restoreMemory(host);
  final failures = await snapshot.restorePersistence(host);
  host._currentLiveCourseId = null;
  host._notifyStateChanged();
  try {
    await host._updateLiveActivity();
  } catch (error, stackTrace) {
    failures.add(_FullBackupRollbackFailure('live_surface', error, stackTrace));
    if (kDebugMode) {
      debugPrint('Full backup rollback live-surface refresh failed: $error');
    }
  }
  return failures;
}
