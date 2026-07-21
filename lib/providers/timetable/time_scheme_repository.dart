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
  await host._persistTimeSchemes();
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

  host._settings = host._settings.copyWith(
    activeTimeSchemeId: scheme.id,
    sections: List<SectionTime>.from(scheme.sections),
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

  final updated = host._timeSchemes[index].copyWith(
    name: name.trim(),
    updatedAt: DateTime.now(),
  );
  host._timeSchemes[index] = updated;
  await host._persistTimeSchemes();
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
  await host._persistTimeSchemes();
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
    host._settings = host._profiles[activeProfileIndex].settings;
  }

  await host._persistTimeSchemes();
  await host._storageService.saveProfiles(host._profiles);
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
  )) {
    return false;
  }

  final index = host._timeSchemes.indexWhere((scheme) => scheme.id == schemeId);
  if (index == -1) {
    return false;
  }
  host._timeSchemes.removeAt(index);

  await host._persistTimeSchemes();
  host._notifyStateChanged();
  return true;
}
