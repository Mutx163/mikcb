import '../l10n/service_message_localizer.dart';
import '../logging/app_debug_log.dart';
import '../models/course.dart';
import '../models/location_time_group.dart';
import '../models/schedule_date_rule.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
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

/// Every reference that keeps a time scheme from being deleted.
///
/// Returned by [TimeSchemeLogic.collectDeleteBlockers] so the delete guard in
/// the provider and the explanation shown in the management page read the same
/// data.  They used to drift apart: the page only counted profiles and courses
/// while the guard also counted location groups and date rules, which left the
/// menu row silently disabled (no prompt at all) in one case and a misleading
/// "it is in use" toast in the other.
class TimeSchemeDeleteBlockers {
  /// Profiles that use the scheme as their default (main) time scheme.
  final List<String> profileNames;

  /// Courses that set the scheme manually as their override time scheme.
  final int overrideCourseCount;

  /// Courses routed to the scheme by a location keyword group.
  final int locationCourseCount;

  /// Location groups bound to the scheme (enabled or not — any reference
  /// blocks deletion, matching [LocationTimeMatchLogic.isSchemeReferencedByGroups]).
  final List<String> locationGroupNames;

  /// Date rules that switch a profile to the scheme.
  final List<String> dateRuleNames;

  const TimeSchemeDeleteBlockers({
    this.profileNames = const [],
    this.overrideCourseCount = 0,
    this.locationCourseCount = 0,
    this.locationGroupNames = const [],
    this.dateRuleNames = const [],
  });

  int get totalCourseCount => overrideCourseCount + locationCourseCount;

  bool get isEmpty =>
      profileNames.isEmpty &&
      overrideCourseCount == 0 &&
      locationCourseCount == 0 &&
      locationGroupNames.isEmpty &&
      dateRuleNames.isEmpty;

  bool get isNotEmpty => !isEmpty;
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
  ///
  /// Seasonal date rules do **not** soft-overlay here. They bulk-apply the
  /// profile default scheme once on the rule start day (see provider).
  static TimeScheme? resolveCourseTimeScheme(
    List<TimeScheme> schemes,
    TimetableSettings settings,
    Course course, {
    TimetableSettings? settingsOverride,
    List<LocationTimeGroup> locationTimeGroups = const [],
    List<ScheduleDateRule> scheduleDateRules = const [],
    DateTime? onDate,
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
    List<ScheduleDateRule> scheduleDateRules = const [],
    DateTime? onDate,
  }) {
    final TimeScheme? scheme;
    if (timeSchemeId != null) {
      scheme = getSchemeById(schemes, timeSchemeId);
    } else {
      scheme = resolveCourseTimeScheme(
        schemes,
        settings,
        Course(
          id: '_validate',
          name: '_',
          teacher: '',
          location: location ?? '',
          dayOfWeek: 1,
          startSection: startSection,
          endSection: endSection,
          startTime: '08:00',
          endTime: '09:00',
        ),
        locationTimeGroups: locationTimeGroups,
        scheduleDateRules: scheduleDateRules,
        onDate: onDate,
      );
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
    List<ScheduleDateRule> scheduleDateRules = const [],
  }) => collectDeleteBlockers(
    profiles,
    schemeId,
    locationTimeGroups: locationTimeGroups,
    schemes: schemes,
    scheduleDateRules: scheduleDateRules,
  ).isNotEmpty;

  /// Lists every reference that blocks deleting [schemeId].
  ///
  /// This is the single source of truth behind [isSchemeInUse]: the provider
  /// guard and the management page's delete prompt both go through it, so a
  /// scheme can never look deletable while the guard still refuses it.
  static TimeSchemeDeleteBlockers collectDeleteBlockers(
    List<TimetableProfile> profiles,
    String schemeId, {
    List<LocationTimeGroup> locationTimeGroups = const [],
    List<TimeScheme> schemes = const [],
    List<ScheduleDateRule> scheduleDateRules = const [],
  }) {
    // Any location group referencing the scheme blocks deletion, enabled or
    // not — a disabled group still holds a stale id and would resurrect the
    // scheme if re-enabled later.
    final locationGroupNames = locationTimeGroups
        .where((group) => group.timeSchemeId == schemeId)
        .map((group) => group.name)
        .toList(growable: false);
    final dateRuleNames = scheduleDateRules
        .where((rule) => rule.timeSchemeId == schemeId)
        .map((rule) => rule.name)
        .toList(growable: false);

    final profileNames = <String>[];
    var overrideCourseCount = 0;
    var locationCourseCount = 0;

    for (final profile in profiles) {
      if (profile.settings.activeTimeSchemeId == schemeId) {
        profileNames.add(profile.name);
      }
      for (final course in profile.courses) {
        if (course.timeSchemeIdOverride == schemeId) {
          overrideCourseCount++;
          continue;
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
          locationCourseCount++;
        }
      }
    }

    return TimeSchemeDeleteBlockers(
      profileNames: profileNames,
      overrideCourseCount: overrideCourseCount,
      locationCourseCount: locationCourseCount,
      locationGroupNames: locationGroupNames,
      dateRuleNames: dateRuleNames,
    );
  }

  /// 按课程生效时间模板改写全部课程的钟点（迁移自 timetable_provider，
  /// 纯映射：读 [schemes]/[settings]/[locationTimeGroups]/[scheduleDateRules]，
  /// 不触碰任何 Provider 状态）。
  static List<Course> syncCoursesWithEffectiveTimeSchemes(
    List<Course> source, {
    required List<TimeScheme> schemes,
    required TimetableSettings settings,
    List<LocationTimeGroup> locationTimeGroups = const [],
    List<ScheduleDateRule> scheduleDateRules = const [],
    TimetableSettings? settingsOverride,
  }) {
    return source
        .map(
          (course) => syncCourseWithEffectiveTimeScheme(
            course,
            schemes: schemes,
            settings: settings,
            locationTimeGroups: locationTimeGroups,
            scheduleDateRules: scheduleDateRules,
            settingsOverride: settingsOverride,
          ),
        )
        .toList();
  }

  /// 单节课钟点同步：课程无生效模板或节次越界时原样返回（带覆盖字段
  /// 的 copyWith 以保持引用语义），钟点已一致时原样返回，否则改写
  /// startTime/endTime。[onDate] 仅限运行时预览路径，持久化路径禁止传。
  static Course syncCourseWithEffectiveTimeScheme(
    Course course, {
    required List<TimeScheme> schemes,
    required TimetableSettings settings,
    List<LocationTimeGroup> locationTimeGroups = const [],
    List<ScheduleDateRule> scheduleDateRules = const [],
    TimetableSettings? settingsOverride,
    DateTime? onDate,
    bool debugTrace = false,
    String debugTag = 'LocationTimeApply',
  }) {
    // 与 provider 原实现同口径：debugTrace 时解析出的 scheme 用于日志，
    // 但 sections 仍按「scheme 优先，缺省回退 settings.sections」解析。
    final resolvedScheme = resolveCourseTimeScheme(
      schemes,
      settings,
      course,
      settingsOverride: settingsOverride,
      locationTimeGroups: locationTimeGroups,
      scheduleDateRules: scheduleDateRules,
      onDate: onDate,
    );
    final sections =
        resolvedScheme?.sections ?? (settingsOverride ?? settings).sections;
    final startIndex = course.startSection - 1;
    final endIndex = course.endSection - 1;
    if (sections.isEmpty || startIndex < 0 || endIndex >= sections.length) {
      if (debugTrace) {
        appDebugLog(
          debugTag,
          '跳过改写(节次越界/无sections): course=${course.name} '
          'loc=${course.location} sections=${course.startSection}-${course.endSection} '
          'scheme=${resolvedScheme?.name ?? "null"} '
          'schemeSectionCount=${resolvedScheme?.sections.length ?? sections.length} '
          'override=${course.timeSchemeIdOverride ?? "null"} '
          'currentClock=${course.startTime}-${course.endTime}',
        );
      }
      return course.copyWith(timeSchemeIdOverride: course.timeSchemeIdOverride);
    }

    final startTime = sections[startIndex].startTime;
    final endTime = sections[endIndex].endTime;
    if (course.startTime == startTime && course.endTime == endTime) {
      if (debugTrace) {
        appDebugLog(
          debugTag,
          '钟点已相同(不改写): course=${course.name} '
          'loc=${course.location} sections=${course.startSection}-${course.endSection} '
          'scheme=${resolvedScheme?.name ?? "null"}(${resolvedScheme?.id ?? "-"}) '
          'clock=$startTime-$endTime override=${course.timeSchemeIdOverride ?? "null"}',
        );
      }
      return course;
    }

    if (debugTrace) {
      appDebugLog(
        debugTag,
        '改写钟点: course=${course.name} loc=${course.location} '
        'sections=${course.startSection}-${course.endSection} '
        'scheme=${resolvedScheme?.name ?? "null"}(${resolvedScheme?.id ?? "-"}) '
        '${course.startTime}-${course.endTime} -> $startTime-$endTime '
        'override=${course.timeSchemeIdOverride ?? "null"}',
      );
    }
    return course.copyWith(
      startTime: startTime,
      endTime: endTime,
      timeSchemeIdOverride: course.timeSchemeIdOverride,
    );
  }
}
