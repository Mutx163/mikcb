part of '../timetable_provider.dart';

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

    Future<void> step(
      String name,
      Future<void> Function() operation,
    ) async {
      try {
        await operation();
      } catch (error, stackTrace) {
        failures.add(
          _FullBackupRollbackFailure(name, error, stackTrace),
        );
        if (kDebugMode) {
          debugPrint(
            'Full backup rollback step "$name" failed: $error',
          );
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
  final currentScheme = host.activeTimeScheme;

  if (currentScheme == null) {
    host._settings = host._settings.copyWith(sections: expandedSections);
    host._courses = host._syncCoursesWithEffectiveTimeSchemes(
      List<Course>.from(host._courses),
      settings: host._settings,
    );
    await host._persistActiveProfileState();
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
    name: '${currentScheme.name}（导入补齐）',
    sections: expandedSections,
    createdAt: now,
    updatedAt: now,
  );
  host._timeSchemes.add(duplicatedScheme);
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
      if (courseListsEqual(host._courses, result.mergedCourses)) {
        return 0;
      }
      syncResult = result;
      mergedCourses = result.mergedCourses;
      effectiveImportedCount = result.addedCount + result.updatedCount;
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
    await host._persistActiveProfileState(notifySync: false);
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
  try {
    if (host._dataTransferService.isFullBackupJson(content)) {
      return host.importFullAppDataBackup(content);
    }
    final backup = host._dataTransferService.parseBackupJson(content);
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
    host._settings = resolvedSettings;
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
    return e.message;
  } catch (_) {
    return 'import_file_unrecognized';
  }
}

Future<String?> _timetableImportAppDataBackupAsNewProfile(
  TimetableProvider host,
  String content, {
  String? profileName,
}) async {
  try {
    if (host._dataTransferService.isFullBackupJson(content)) {
      return 'import_use_overwrite_for_full_backup';
    }
    final backup = host._dataTransferService.parseBackupJson(content);
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
    return e.message;
  } catch (_) {
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
              settings: host._normalizeSettingsWithTimeScheme(profile.settings),
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
    failures.add(
      _FullBackupRollbackFailure('live_surface', error, stackTrace),
    );
    if (kDebugMode) {
      debugPrint('Full backup rollback live-surface refresh failed: $error');
    }
  }
  return failures;
}
