part of '../timetable_provider.dart';

Future<TimeScheme> _timetableCreateTimeScheme(
  TimetableProvider host, {
  required String name,
  List<SectionTime>? sections,
  bool applyToActiveProfile = false,
}) async {
  await host.initialize();
  final now = DateTime.now();
  final scheme = TimeScheme(
    id: const Uuid().v4(),
    name: name.trim(),
    sections: List<SectionTime>.from(
      sections ?? host.activeTimeScheme?.sections ?? host._settings.sections,
    ),
    createdAt: now,
    updatedAt: now,
  );
  host._timeSchemes.add(scheme);
  try {
    await host._persistTimeSchemes();
  } catch (_) {
    // 落库失败必须把刚加进内存的那条摘掉：本类大量入口是「先改内存、后写盘」，
    // 幻影作息会被下一次任意成功写入经 `_mergeActiveProfileIntoProfilesList`
    // 当成既有状态永久落盘。形状同 `_applySavedThemes`（主题族已收口）。
    host._timeSchemes.removeWhere((item) => item.id == scheme.id);
    rethrow;
  }
  if (applyToActiveProfile) {
    await _timetableApplyTimeScheme(host, scheme.id);
  } else {
    host._notifyStateChanged();
  }
  return scheme;
}

Future<String?> _timetableApplyTimeScheme(
  TimetableProvider host,
  String schemeId,
) async {
  await host.initialize();
  final scheme = host._getTimeSchemeById(schemeId);
  if (scheme == null) {
    return 'time_scheme_not_found';
  }

  // Same rule as shrinking a scheme via [updateTimeScheme]: active-profile
  // courses keep their section indexes, so the target scheme must cover them.
  Course? highestSectionCourse;
  for (final course in host._courses) {
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
  // 而 `_persistActiveProfileState` 还会先把它们并进 `_profiles`。任一步失败都必须
  // 整体退回：本类其余写入（create / rename / duplicate / delete / updateTimeScheme）
  // 都已按这个形状收口，只有这里是「先改内存、裸 await」——一旦 saveProfiles 或
  // AppGlobalSettingsService.syncFrom 抛错，磁盘回滚了而内存停在方案 B，并且下面那句
  // notify 被跳过：UI 还显示 A，getter 已经是 B；下一次任意成功写入（加课、切周、
  // 30 秒一次的 syncTemporalContext 心跳）都会把 B 当成既有状态落盘 —— 用户的上课
  // 时间在一次"失败"提示之后被真的改掉。
  final snapshotSettings = host._settings;
  final snapshotCourses = List<Course>.from(host._courses);
  final snapshotProfiles = List<TimetableProfile>.from(host._profiles);
  host._settings = host._settings.copyWith(
    activeTimeSchemeId: scheme.id,
    sections: List<SectionTime>.from(scheme.sections),
  );
  host._courses = host._syncCoursesWithEffectiveTimeSchemes(
    List<Course>.from(host._courses),
    settings: host._settings,
  );
  try {
    await host._persistActiveProfileState();
  } catch (_) {
    host._settings = snapshotSettings;
    host._courses = snapshotCourses;
    host._profiles = snapshotProfiles;
    rethrow;
  }
  host._currentLiveCourseId = null;
  host._notifyStateChanged();
  await host._updateLiveActivity();
  return null;
}

Future<TimeScheme?> _timetableRenameTimeScheme(
  TimetableProvider host,
  String schemeId,
  String name,
) async {
  await host.initialize();
  final index = host._timeSchemes.indexWhere((scheme) => scheme.id == schemeId);
  if (index == -1) {
    return null;
  }

  final original = host._timeSchemes[index];
  final updated = original.copyWith(
    name: name.trim(),
    updatedAt: DateTime.now(),
  );
  host._timeSchemes[index] = updated;
  try {
    await host._persistTimeSchemes();
  } catch (_) {
    host._timeSchemes[index] = original;
    rethrow;
  }
  host._notifyStateChanged();
  return updated;
}

Future<TimeScheme?> _timetableDuplicateTimeScheme(
  TimetableProvider host,
  String schemeId, {
  String? name,
}) async {
  await host.initialize();
  final source = host._getTimeSchemeById(schemeId);
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
  host._timeSchemes.add(duplicated);
  try {
    await host._persistTimeSchemes();
  } catch (_) {
    host._timeSchemes.removeWhere((item) => item.id == duplicated.id);
    rethrow;
  }
  host._notifyStateChanged();
  return duplicated;
}

Future<String?> _timetableUpdateTimeScheme(
  TimetableProvider host, {
  required String schemeId,
  required String name,
  required List<SectionTime> sections,
}) async {
  await host.initialize();
  final validationMessage = validateSectionTimes(sections);
  if (validationMessage != null) {
    return validationMessage;
  }
  final requiredMaxSection = host.maxUsedSectionForTimeScheme(schemeId);
  if (requiredMaxSection > 0 && sections.length < requiredMaxSection) {
    final usage = host.maxSectionUsageForTimeScheme(schemeId);
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

  final index = host._timeSchemes.indexWhere((scheme) => scheme.id == schemeId);
  if (index == -1) {
    return 'time_scheme_not_found';
  }

  final updatedScheme = host._timeSchemes[index].copyWith(
    name: name.trim(),
    sections: List<SectionTime>.from(sections),
    updatedAt: DateTime.now(),
  );
  // 本函数会同时改四份内存状态（作息表 / 全部档案 / 设置 / 当前课表），再分两次
  // await 落盘。任一步失败都必须整体退回，否则「内存已是新课表、盘上还是旧的」
  // 会被下一次成功写入当成既有状态落盘 —— 用户看到的是改了作息却只生效一半。
  final snapshotSchemes = List<TimeScheme>.from(host._timeSchemes);
  final snapshotProfiles = List<TimetableProfile>.from(host._profiles);
  final snapshotSettings = host._settings;
  final snapshotCourses = List<Course>.from(host._courses);
  host._timeSchemes[index] = updatedScheme;

  for (var i = 0; i < host._profiles.length; i++) {
    final profile = host._profiles[i];
    final normalizedSettings = profile.settings.activeTimeSchemeId == schemeId
        ? profile.settings.copyWith(
            activeTimeSchemeId: schemeId,
            sections: List<SectionTime>.from(updatedScheme.sections),
          )
        : profile.settings;
    host._profiles[i] = profile.copyWith(
      courses: host._syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(profile.courses),
        settings: normalizedSettings,
      ),
      settings: normalizedSettings,
    );
  }

  if (host._settings.activeTimeSchemeId == schemeId) {
    host._settings = host._settings.copyWith(
      activeTimeSchemeId: schemeId,
      sections: List<SectionTime>.from(updatedScheme.sections),
    );
  }

  final activeProfileIndex = host._profiles.indexWhere(
    (profile) => profile.id == host._activeProfileId,
  );
  if (activeProfileIndex != -1) {
    host._courses = List<Course>.from(
      host._profiles[activeProfileIndex].courses,
    );
    // 课表里的 settings 只是全局设置的备份镜像；从这里恢复内存状态时
    // 必须重新叠加全局真源，否则删除/导入留下的旧镜像会把设置倒退。
    host._settings = host._settingsFromProfile(
      host._profiles[activeProfileIndex],
    );
    // 内存已叠加全局设置；同步写回活动课表镜像，避免下一次备份继续携带旧值。
    host._mergeActiveProfileIntoProfilesList();
  }

  try {
    await host._persistTimeSchemes();
    await host._profileRepository.saveProfiles(host._profiles);
  } catch (_) {
    host._timeSchemes = snapshotSchemes;
    host._profiles = snapshotProfiles;
    host._settings = snapshotSettings;
    host._courses = snapshotCourses;
    rethrow;
  }
  host._currentLiveCourseId = null;
  host._notifyStateChanged();
  await host._updateLiveActivity();
  return null;
}

Future<bool> _timetableDeleteTimeScheme(
  TimetableProvider host,
  String schemeId,
) async {
  await host.initialize();
  if (TimeSchemeLogic.isSchemeInUse(
    host._profiles,
    schemeId,
    locationTimeGroups: host._locationTimeGroups,
    schemes: host._timeSchemes,
    scheduleDateRules: host._scheduleDateRules,
  )) {
    return false;
  }

  final index = host._timeSchemes.indexWhere((scheme) => scheme.id == schemeId);
  if (index == -1) {
    return false;
  }
  final removed = host._timeSchemes.removeAt(index);
  try {
    await host._persistTimeSchemes();
  } catch (_) {
    host._timeSchemes.insert(index, removed);
    rethrow;
  }
  host._notifyStateChanged();
  return true;
}
