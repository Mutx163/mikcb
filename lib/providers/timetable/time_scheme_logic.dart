import '../../l10n/service_message_localizer.dart';
import '../../models/course.dart';
import '../../models/time_scheme.dart';
import '../../models/timetable_profile.dart';
import '../../models/timetable_settings.dart';

class TimeSchemeCourseUsageReference {
  final String profileName;
  final Course course;
  final bool usesOverride;

  const TimeSchemeCourseUsageReference({
    required this.profileName,
    required this.course,
    required this.usesOverride,
  });
}

/// Pure time-scheme query helpers extracted from [TimetableProvider].
class TimeSchemeLogic {
  TimeSchemeLogic._();

  static TimeScheme? getSchemeById(List<TimeScheme> schemes, String? schemeId) {
    if (schemeId == null) {
      return null;
    }
    for (final scheme in schemes) {
      if (scheme.id == schemeId) {
        return scheme;
      }
    }
    return null;
  }

  static TimeScheme? resolveCourseTimeScheme(
    List<TimeScheme> schemes,
    TimetableSettings settings,
    Course course, {
    TimetableSettings? settingsOverride,
  }) {
    final effectiveSettings = settingsOverride ?? settings;
    final overrideScheme = getSchemeById(schemes, course.timeSchemeIdOverride);
    if (overrideScheme != null) {
      return overrideScheme;
    }
    return getSchemeById(schemes, effectiveSettings.activeTimeSchemeId);
  }

  static List<TimeSchemeCourseUsageReference> getCourseUsages(
    List<TimetableProfile> profiles,
    String schemeId, {
    List<TimetableProfile>? profilesOverride,
  }) {
    final sourceProfiles = profilesOverride ?? profiles;
    final usages = <TimeSchemeCourseUsageReference>[];

    for (final profile in sourceProfiles) {
      for (final course in profile.courses) {
        final usesOverride = course.timeSchemeIdOverride == schemeId;
        final followsProfileScheme =
            course.timeSchemeIdOverride == null &&
            profile.settings.activeTimeSchemeId == schemeId;
        if (!usesOverride && !followsProfileScheme) {
          continue;
        }
        usages.add(
          TimeSchemeCourseUsageReference(
            profileName: profile.name,
            course: course,
            usesOverride: usesOverride,
          ),
        );
      }
    }

    return usages;
  }

  static int maxUsedSection(
    List<TimetableProfile> profiles,
    String schemeId, {
    List<TimetableProfile>? profilesOverride,
  }) {
    final usages = getCourseUsages(
      profiles,
      schemeId,
      profilesOverride: profilesOverride,
    );
    if (usages.isEmpty) {
      return 0;
    }
    return usages
        .map((usage) => usage.course.endSection)
        .reduce((left, right) => left > right ? left : right);
  }

  static TimeSchemeCourseUsageReference? maxSectionUsage(
    List<TimetableProfile> profiles,
    String schemeId, {
    List<TimetableProfile>? profilesOverride,
  }) {
    final usages = getCourseUsages(
      profiles,
      schemeId,
      profilesOverride: profilesOverride,
    );
    if (usages.isEmpty) {
      return null;
    }
    usages.sort(
      (left, right) =>
          right.course.endSection.compareTo(left.course.endSection),
    );
    return usages.first;
  }

  static String? validateCourseTimeSchemeOverride({
    required List<TimeScheme> schemes,
    required TimetableSettings settings,
    String? timeSchemeId,
    required int startSection,
    required int endSection,
  }) {
    final scheme = timeSchemeId == null
        ? getSchemeById(schemes, settings.activeTimeSchemeId)
        : getSchemeById(schemes, timeSchemeId);
    final sectionCount = scheme?.sections.length ?? settings.sections.length;
    if (sectionCount <= 0) {
      return timeSchemeId == null
          ? 'time_scheme_config_unavailable'
          : 'time_scheme_not_found_selected';
    }
    if (startSection < 1 || endSection > sectionCount) {
      return encodeServiceMessage(
        'time_scheme_sections_insufficient',
        {'startSection': startSection, 'endSection': endSection},
      );
    }
    return null;
  }

  static bool isSchemeInUse(List<TimetableProfile> profiles, String schemeId) {
    return profiles.any(
      (profile) =>
          profile.settings.activeTimeSchemeId == schemeId ||
          profile.courses.any(
            (course) => course.timeSchemeIdOverride == schemeId,
          ),
    );
  }
}
