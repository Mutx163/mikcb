import '../../l10n/service_message_localizer.dart';
import '../../models/course.dart';
import '../../models/location_time_group.dart';
import '../../models/time_scheme.dart';
import '../../models/timetable_profile.dart';
import '../../models/timetable_settings.dart';
import 'location_time_match_logic.dart';

class TimeSchemeCourseUsageReference {
  final String profileName;
  final Course course;
  final bool usesOverride;

  /// True when the course has no manual override and is routed via a location
  /// keyword group rather than the profile default scheme.
  final bool usesLocationMatch;

  const TimeSchemeCourseUsageReference({
    required this.profileName,
    required this.course,
    required this.usesOverride,
    this.usesLocationMatch = false,
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

  /// Resolves the effective time scheme for a course.
  ///
  /// Priority:
  /// 1. Manual [Course.timeSchemeIdOverride]
  /// 2. Location keyword match → group.timeSchemeId (if scheme exists)
  /// 3. Profile [TimetableSettings.activeTimeSchemeId]
  static TimeScheme? resolveCourseTimeScheme(
    List<TimeScheme> schemes,
    TimetableSettings settings,
    Course course, {
    TimetableSettings? settingsOverride,
    List<LocationTimeGroup> locationTimeGroups = const [],
  }) {
    final effectiveSettings = settingsOverride ?? settings;
    final overrideScheme = getSchemeById(schemes, course.timeSchemeIdOverride);
    if (overrideScheme != null) {
      return overrideScheme;
    }

    final locationMatch = LocationTimeMatchLogic.match(
      course.location,
      locationTimeGroups,
    );
    if (locationMatch != null) {
      final locationScheme = getSchemeById(schemes, locationMatch.timeSchemeId);
      if (locationScheme != null) {
        return locationScheme;
      }
    }

    return getSchemeById(schemes, effectiveSettings.activeTimeSchemeId);
  }

  static List<TimeSchemeCourseUsageReference> getCourseUsages(
    List<TimetableProfile> profiles,
    String schemeId, {
    List<TimetableProfile>? profilesOverride,
    List<TimeScheme> schemes = const [],
    List<LocationTimeGroup> locationTimeGroups = const [],
  }) {
    final sourceProfiles = profilesOverride ?? profiles;
    final usages = <TimeSchemeCourseUsageReference>[];

    for (final profile in sourceProfiles) {
      for (final course in profile.courses) {
        if (course.timeSchemeIdOverride != null) {
          if (course.timeSchemeIdOverride == schemeId) {
            usages.add(
              TimeSchemeCourseUsageReference(
                profileName: profile.name,
                course: course,
                usesOverride: true,
              ),
            );
          }
          continue;
        }

        final locationMatch = LocationTimeMatchLogic.match(
          course.location,
          locationTimeGroups,
        );
        if (locationMatch != null) {
          final locationScheme = getSchemeById(
            schemes,
            locationMatch.timeSchemeId,
          );
          if (locationScheme != null) {
            if (locationMatch.timeSchemeId == schemeId) {
              usages.add(
                TimeSchemeCourseUsageReference(
                  profileName: profile.name,
                  course: course,
                  usesOverride: false,
                  usesLocationMatch: true,
                ),
              );
            }
            continue;
          }
        }

        if (profile.settings.activeTimeSchemeId == schemeId) {
          usages.add(
            TimeSchemeCourseUsageReference(
              profileName: profile.name,
              course: course,
              usesOverride: false,
            ),
          );
        }
      }
    }

    return usages;
  }

  static int maxUsedSection(
    List<TimetableProfile> profiles,
    String schemeId, {
    List<TimetableProfile>? profilesOverride,
    List<TimeScheme> schemes = const [],
    List<LocationTimeGroup> locationTimeGroups = const [],
  }) {
    final usages = getCourseUsages(
      profiles,
      schemeId,
      profilesOverride: profilesOverride,
      schemes: schemes,
      locationTimeGroups: locationTimeGroups,
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
    List<TimeScheme> schemes = const [],
    List<LocationTimeGroup> locationTimeGroups = const [],
  }) {
    final usages = getCourseUsages(
      profiles,
      schemeId,
      profilesOverride: profilesOverride,
      schemes: schemes,
      locationTimeGroups: locationTimeGroups,
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
    String? location,
    List<LocationTimeGroup> locationTimeGroups = const [],
  }) {
    final TimeScheme? scheme;
    if (timeSchemeId != null) {
      scheme = getSchemeById(schemes, timeSchemeId);
    } else {
      final locationMatch = LocationTimeMatchLogic.match(
        location,
        locationTimeGroups,
      );
      if (locationMatch != null) {
        scheme =
            getSchemeById(schemes, locationMatch.timeSchemeId) ??
            getSchemeById(schemes, settings.activeTimeSchemeId);
      } else {
        scheme = getSchemeById(schemes, settings.activeTimeSchemeId);
      }
    }

    final sectionCount = scheme?.sections.length ?? settings.sections.length;
    if (sectionCount <= 0) {
      return timeSchemeId == null
          ? 'time_scheme_config_unavailable'
          : 'time_scheme_not_found_selected';
    }
    if (startSection < 1 || endSection > sectionCount) {
      return encodeServiceMessage('time_scheme_sections_insufficient', {
        'startSection': startSection,
        'endSection': endSection,
      });
    }
    return null;
  }

  static bool isSchemeInUse(
    List<TimetableProfile> profiles,
    String schemeId, {
    List<LocationTimeGroup> locationTimeGroups = const [],
    List<TimeScheme> schemes = const [],
  }) {
    if (LocationTimeMatchLogic.isSchemeReferencedByGroups(
      locationTimeGroups,
      schemeId,
    )) {
      return true;
    }

    return profiles.any((profile) {
      if (profile.settings.activeTimeSchemeId == schemeId) {
        return true;
      }
      for (final course in profile.courses) {
        if (course.timeSchemeIdOverride == schemeId) {
          return true;
        }
        if (course.timeSchemeIdOverride != null) {
          continue;
        }
        final locationMatch = LocationTimeMatchLogic.match(
          course.location,
          locationTimeGroups,
        );
        if (locationMatch != null &&
            locationMatch.timeSchemeId == schemeId &&
            getSchemeById(schemes, schemeId) != null) {
          return true;
        }
      }
      return false;
    });
  }
}
