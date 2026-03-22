import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';

class StorageService {
  static const String _coursesKey = 'courses';
  static const String _currentWeekKey = 'current_week';
  static const String _semesterStartKey = 'semester_start';
  static const String _timetableSettingsKey = 'timetable_settings';
  static const String _profilesKey = 'timetable_profiles';
  static const String _activeProfileIdKey = 'active_timetable_profile_id';
  static const String _timeSchemesKey = 'time_schemes';
  static const String _hasSeenUserGuideKey = 'has_seen_user_guide';

  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // 课程存储
  Future<List<Course>> getCourses() async {
    if (_prefs == null) await init();
    final coursesJson = _prefs?.getStringList(_coursesKey) ?? [];
    return coursesJson.map((json) => Course.fromJsonString(json)).toList();
  }

  Future<void> saveCourses(List<Course> courses) async {
    if (_prefs == null) await init();
    final coursesJson = courses.map((course) => course.toJsonString()).toList();
    await _prefs?.setStringList(_coursesKey, coursesJson);
  }

  Future<void> addCourse(Course course) async {
    final courses = await getCourses();
    courses.add(course);
    await saveCourses(courses);
  }

  Future<void> updateCourse(Course updatedCourse) async {
    final courses = await getCourses();
    final index = courses.indexWhere((c) => c.id == updatedCourse.id);
    if (index != -1) {
      courses[index] = updatedCourse;
      await saveCourses(courses);
    }
  }

  Future<void> deleteCourse(String courseId) async {
    final courses = await getCourses();
    courses.removeWhere((c) => c.id == courseId);
    await saveCourses(courses);
  }

  Future<TimetableSettings> getTimetableSettings() async {
    if (_prefs == null) await init();
    final settingsJson = _prefs?.getString(_timetableSettingsKey);
    if (settingsJson == null || settingsJson.isEmpty) {
      return TimetableSettings.defaults();
    }
    return TimetableSettings.fromJsonString(settingsJson);
  }

  Future<void> saveTimetableSettings(TimetableSettings settings) async {
    if (_prefs == null) await init();
    await _prefs?.setString(_timetableSettingsKey, settings.toJsonString());
  }

  // 当前周次存储
  Future<int> getCurrentWeek() async {
    if (_prefs == null) await init();
    return _prefs?.getInt(_currentWeekKey) ?? 1;
  }

  Future<void> setCurrentWeek(int week) async {
    if (_prefs == null) await init();
    await _prefs?.setInt(_currentWeekKey, week);
  }

  // 学期开始日期存储
  Future<DateTime?> getSemesterStart() async {
    if (_prefs == null) await init();
    final timestamp = _prefs?.getInt(_semesterStartKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  Future<void> setSemesterStart(DateTime date) async {
    if (_prefs == null) await init();
    await _prefs?.setInt(_semesterStartKey, date.millisecondsSinceEpoch);
  }

  Future<void> clearSemesterStart() async {
    if (_prefs == null) await init();
    await _prefs?.remove(_semesterStartKey);
  }

  Future<bool> hasSeenUserGuide() async {
    if (_prefs == null) await init();
    return _prefs?.getBool(_hasSeenUserGuideKey) ?? false;
  }

  Future<void> setHasSeenUserGuide(bool value) async {
    if (_prefs == null) await init();
    await _prefs?.setBool(_hasSeenUserGuideKey, value);
  }

  // 获取指定周次的课程
  Future<List<Course>> getCoursesForWeek(int week) async {
    final allCourses = await getCourses();
    return allCourses.where((course) => course.isInWeek(week)).toList();
  }

  // 获取今天的课程
  Future<List<Course>> getTodayCourses(int week, int dayOfWeek) async {
    final weekCourses = await getCoursesForWeek(week);
    return weekCourses.where((course) => course.dayOfWeek == dayOfWeek).toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
  }

  // 获取当前正在进行的课程
  Future<Course?> getCurrentCourse(int week, int dayOfWeek) async {
    final todayCourses = await getTodayCourses(week, dayOfWeek);
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final course in todayCourses) {
      if (currentTime.compareTo(course.startTime) >= 0 &&
          currentTime.compareTo(course.endTime) <= 0) {
        return course;
      }
    }
    return null;
  }

  // 获取下一节课
  Future<Course?> getNextCourse(int week, int dayOfWeek) async {
    final todayCourses = await getTodayCourses(week, dayOfWeek);
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final course in todayCourses) {
      if (currentTime.compareTo(course.startTime) < 0) {
        return course;
      }
    }
    return null;
  }

  Future<List<TimetableProfile>> getProfiles() async {
    if (_prefs == null) await init();
    await _ensureProfilesInitialized();
    await _ensureTimeSchemesInitialized();
    final profilesJson = _prefs?.getString(_profilesKey);
    if (profilesJson == null || profilesJson.isEmpty) {
      return const [];
    }

    final rawProfiles = jsonDecode(profilesJson) as List<dynamic>;
    return rawProfiles
        .map((item) =>
            TimetableProfile.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> saveProfiles(List<TimetableProfile> profiles) async {
    if (_prefs == null) await init();
    final payload =
        jsonEncode(profiles.map((profile) => profile.toJson()).toList());
    await _prefs?.setString(_profilesKey, payload);
  }

  Future<String?> getActiveProfileId() async {
    if (_prefs == null) await init();
    await _ensureProfilesInitialized();
    await _ensureTimeSchemesInitialized();
    return _prefs?.getString(_activeProfileIdKey);
  }

  Future<void> setActiveProfileId(String profileId) async {
    if (_prefs == null) await init();
    await _prefs?.setString(_activeProfileIdKey, profileId);
  }

  Future<List<TimeScheme>> getTimeSchemes() async {
    if (_prefs == null) await init();
    await _ensureProfilesInitialized();
    await _ensureTimeSchemesInitialized();
    final rawSchemes = _prefs?.getString(_timeSchemesKey);
    if (rawSchemes == null || rawSchemes.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(rawSchemes) as List<dynamic>;
    return decoded
        .map((item) => TimeScheme.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> saveTimeSchemes(List<TimeScheme> schemes) async {
    if (_prefs == null) await init();
    final payload = jsonEncode(schemes.map((scheme) => scheme.toJson()).toList());
    await _prefs?.setString(_timeSchemesKey, payload);
  }

  Future<void> _ensureProfilesInitialized() async {
    final rawProfiles = _prefs?.getString(_profilesKey);
    if (rawProfiles != null && rawProfiles.isNotEmpty) {
      final activeProfileId = _prefs?.getString(_activeProfileIdKey);
      if (activeProfileId == null || activeProfileId.isEmpty) {
        final profiles = (jsonDecode(rawProfiles) as List<dynamic>)
            .map((item) => TimetableProfile.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
        if (profiles.isNotEmpty) {
          await setActiveProfileId(profiles.first.id);
        }
      }
      return;
    }

    final now = DateTime.now();
    final legacySettings = await getTimetableSettings();
    final legacySemesterStart = await getSemesterStart();
    final migratedSettings =
        legacySemesterStart != null && legacySettings.semesterStartDate == null
            ? legacySettings.copyWith(semesterStartDate: legacySemesterStart)
            : legacySettings;
    final migratedProfile = TimetableProfile(
      id: 'profile-${now.microsecondsSinceEpoch}',
      name: '默认课表',
      courses: await getCourses(),
      settings: migratedSettings,
      currentWeek: await getCurrentWeek(),
      createdAt: now,
      lastUsedAt: now,
    );

    await saveProfiles([migratedProfile]);
    await setActiveProfileId(migratedProfile.id);
  }

  Future<void> _ensureTimeSchemesInitialized() async {
    final rawProfiles = _prefs?.getString(_profilesKey);
    if (rawProfiles == null || rawProfiles.isEmpty) {
      return;
    }

    final storedSchemesJson = _prefs?.getString(_timeSchemesKey);
    final storedSchemes = <TimeScheme>[
      if (storedSchemesJson != null && storedSchemesJson.isNotEmpty)
        ...(jsonDecode(storedSchemesJson) as List<dynamic>).map(
          (item) => TimeScheme.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
    ];
    final schemesById = {
      for (final scheme in storedSchemes) scheme.id: scheme,
    };
    final schemesBySignature = {
      for (final scheme in storedSchemes) _sectionSignature(scheme.sections): scheme,
    };

    final profiles = (jsonDecode(rawProfiles) as List<dynamic>)
        .map((item) =>
            TimetableProfile.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    var hasProfileChanges = false;
    for (var index = 0; index < profiles.length; index++) {
      final profile = profiles[index];
      final settings = profile.settings;
      final signature = _sectionSignature(settings.sections);
      final referencedSchemeId = settings.activeTimeSchemeId;
      var resolvedScheme = referencedSchemeId == null
          ? null
          : schemesById[referencedSchemeId];

      resolvedScheme ??= schemesBySignature[signature];

      if (resolvedScheme == null) {
        final now = DateTime.now();
        resolvedScheme = TimeScheme(
          id: 'scheme-${now.microsecondsSinceEpoch}-${index + 1}',
          name: profiles.length == 1 ? '当前课表时间' : '${profile.name} 时间',
          sections: List<SectionTime>.from(settings.sections),
          createdAt: now,
          updatedAt: now,
        );
        storedSchemes.add(resolvedScheme);
        schemesById[resolvedScheme.id] = resolvedScheme;
        schemesBySignature[signature] = resolvedScheme;
      }

      if (settings.activeTimeSchemeId != resolvedScheme.id ||
          _sectionSignature(settings.sections) !=
              _sectionSignature(resolvedScheme.sections)) {
        profiles[index] = profile.copyWith(
          settings: settings.copyWith(
            activeTimeSchemeId: resolvedScheme.id,
            sections: List<SectionTime>.from(resolvedScheme.sections),
          ),
        );
        hasProfileChanges = true;
      }
    }

    if (storedSchemesJson == null ||
        storedSchemesJson.isEmpty ||
        storedSchemes.length != schemesById.length ||
        hasProfileChanges) {
      await saveTimeSchemes(storedSchemes);
      if (hasProfileChanges) {
        await saveProfiles(profiles);
      }
    }
  }

  String _sectionSignature(List<SectionTime> sections) {
    return jsonEncode(
      sections.map((section) => section.toJson()).toList(),
    );
  }
}
