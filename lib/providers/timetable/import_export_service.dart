part of '../timetable_provider.dart';

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
}) async {
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
    );
    effectiveImportedCount = dedupedImportedCourses.length;
    syncResult = null;
  } else {
    final result = syncImportedCourses(
      existingCourses: host._courses,
      importedCourses: importedCourses,
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
  host._settings = host._settings.copyWith(
    semesterStartDate: semesterStart ?? host._settings.semesterStartDate,
    semesterWeekCount: requiredWeekCount > host._settings.semesterWeekCount
        ? requiredWeekCount
        : host._settings.semesterWeekCount,
  );
  if (semesterStart != null) {
    host._currentWeek = host._calculateWeekForDate(
      DateTime.now(),
      fallbackWeek: host._currentWeek,
    );
  }
  host._currentDateWeek = host._resolveCurrentDateWeek();
  await host._persistActiveProfileState();
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
    host._exams = List<Exam>.from(backup.exams);
    host._settings = resolvedSettings;
    host._currentWeek = clampCurrentWeekToSettings(
      backup.currentWeek,
      host._settings,
    );

    await host._persistActiveProfileState();
    host._currentLiveCourseId = null;
    host._notifyStateChanged();
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
    final now = DateTime.now();
    final nextProfile = TimetableProfile(
      id: const Uuid().v4(),
      name: nextName,
      courses: host._syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(backup.courses),
        settings: resolvedSettings,
      ),
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
) async {
  try {
    final backup = host._dataTransferService.parseFullBackupJson(content);
    if (backup.profiles.isEmpty) {
      return 'import_no_profiles_in_backup';
    }

    host._timeSchemes = List<TimeScheme>.from(backup.timeSchemes);
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

    await host._storageService.saveTimeSchemes(host._timeSchemes);
    await host._storageService.saveProfiles(host._profiles);
    if (host._activeProfileId != null) {
      await host._storageService.setActiveProfileId(host._activeProfileId!);
    }

    host._applyProfileState(
      host._profiles.firstWhere(
        (profile) => profile.id == host._activeProfileId,
      ),
    );
    host._currentLiveCourseId = null;
    host._notifyStateChanged();
    await host._updateLiveActivity();
    return null;
  } on FormatException catch (e) {
    return e.message;
  } catch (_) {
    return 'import_file_unrecognized';
  }
}
