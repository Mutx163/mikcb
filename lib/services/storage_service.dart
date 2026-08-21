import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/partner_timetable_binding.dart';
import '../models/course.dart';
import '../models/location_time_group.dart';
import '../models/schedule_date_rule.dart';
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
  static const String _locationTimeGroupsKey = 'location_time_groups';
  static const String _scheduleDateRulesKey = 'schedule_date_rules';
  static const String _scheduleDateRuleLastAppliedSignatureKey =
      'schedule_date_rule_last_applied_signature';
  static const String _hasSeenUserGuideKey = 'has_seen_user_guide';
  static const String _acceptedPrivacyPolicyKey = 'accepted_privacy_policy';
  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';
  static const String _hasHandledPackageMigrationKey =
      'has_handled_package_migration';
  static const String _appLogsDefaultMigrationKey =
      'did_migrate_app_logs_default';
  static const String _hidePrefixDefaultMigrationKey =
      'did_migrate_live_hide_prefix_default';
  static const String _partnerTimetableBindingKey = 'partner_timetable_binding';

  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  @visibleForTesting
  StorageService.forTesting();

  SharedPreferences? _prefs;
  SharedPreferences? _ensuredForPrefs;
  bool _profilesEnsured = false;
  bool _timeSchemesEnsured = false;
  List<TimetableProfile>? _profilesListCache;
  List<TimeScheme>? _timeSchemesListCache;
  List<LocationTimeGroup>? _locationTimeGroupsListCache;
  List<ScheduleDateRule>? _scheduleDateRulesListCache;

  void _invalidateProfilesListCache() {
    _profilesListCache = null;
    _profilesEnsured = false;
  }

  void _invalidateTimeSchemesListCache() {
    _timeSchemesListCache = null;
    _timeSchemesEnsured = false;
  }

  bool _hidePrefixMigrated = false;
  Future<void>? _profilesEnsureFuture;
  Future<void>? _timeSchemesEnsureFuture;
  Future<void>? _hidePrefixMigrateFuture;

  Future<void>? _initFuture;
  Future<void> _coursesWriteChain = Future<void>.value();
  Future<void> _profilesWriteChain = Future<void>.value();
  Future<void> _timeSchemesWriteChain = Future<void>.value();
  Future<void> _locationTimeGroupsWriteChain = Future<void>.value();
  Future<void> _scheduleDateRulesWriteChain = Future<void>.value();
  Future<void> _teacherRecordsWriteChain = Future<void>.value();
  Future<void> _locationRecordsWriteChain = Future<void>.value();

  /// 仅用于测试：重置缓存的初始化状态
  @visibleForTesting
  void resetForTesting() {
    _initFuture = null;
    _profilesEnsureFuture = null;
    _timeSchemesEnsureFuture = null;
    _hidePrefixMigrateFuture = null;
    _prefs = null;
    _ensuredForPrefs = null;
    _profilesListCache = null;
    _timeSchemesListCache = null;
    _locationTimeGroupsListCache = null;
    _scheduleDateRulesListCache = null;
    _profilesEnsured = false;
    _timeSchemesEnsured = false;
    _hidePrefixMigrated = false;
    _coursesWriteChain = Future<void>.value();
    _profilesWriteChain = Future<void>.value();
    _timeSchemesWriteChain = Future<void>.value();
    _locationTimeGroupsWriteChain = Future<void>.value();
    _scheduleDateRulesWriteChain = Future<void>.value();
    _teacherRecordsWriteChain = Future<void>.value();
    _locationRecordsWriteChain = Future<void>.value();
  }

  Future<void> init() async {
    _initFuture ??= _doInit();
    try {
      return await _initFuture!;
    } catch (e) {
      _initFuture = null;
      rethrow;
    }
  }

  Future<void> _doInit() async {
    _prefs = await SharedPreferences.getInstance();
  }

  TimeScheme _snapshotTimeScheme(TimeScheme scheme) =>
      TimeScheme.fromJson(Map<String, dynamic>.from(scheme.toJson()));

  LocationTimeGroup _snapshotLocationTimeGroup(LocationTimeGroup group) =>
      LocationTimeGroup.fromJson(Map<String, dynamic>.from(group.toJson()));

  TimetableProfile _snapshotProfile(TimetableProfile profile) =>
      TimetableProfile.fromJson(Map<String, dynamic>.from(profile.toJson()));

  List<TimeScheme> _snapshotTimeSchemes(Iterable<TimeScheme> schemes) =>
      schemes.map(_snapshotTimeScheme).toList();

  List<LocationTimeGroup> _snapshotLocationTimeGroups(
    Iterable<LocationTimeGroup> groups,
  ) => groups.map(_snapshotLocationTimeGroup).toList();

  List<TimetableProfile> _snapshotProfiles(
    Iterable<TimetableProfile> profiles,
  ) => profiles.map(_snapshotProfile).toList();

  Future<void> _backupAndRemoveCorruptString(String key, String raw) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final backupKey =
        '${key}_corrupt_backup_${DateTime.now().microsecondsSinceEpoch}';
    await prefs.setString(backupKey, raw);
    await prefs.remove(key);
  }

  Future<void> _backupAndRemoveCorruptStringList(
    String key,
    List<String> raw,
  ) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final backupKey =
        '${key}_corrupt_backup_${DateTime.now().microsecondsSinceEpoch}';
    await prefs.setString(backupKey, jsonEncode(raw));
    await prefs.remove(key);
  }

  Future<List<dynamic>?> _readJsonListPreference(String key) async {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Backed up below.
    }
    await _backupAndRemoveCorruptString(key, raw);
    return null;
  }

  void _resetEnsureCacheIfNeeded() {
    if (_ensuredForPrefs != _prefs) {
      _ensuredForPrefs = _prefs;
      _invalidateProfilesListCache();
      _invalidateTimeSchemesListCache();
      _locationTimeGroupsListCache = null;
      _scheduleDateRulesListCache = null;
      _hidePrefixMigrated = false;
    }
  }

  // 课程存储
  Future<List<Course>> getCourses() => _readCoursesWithoutLock();

  Future<List<Course>> _readCoursesWithoutLock() async {
    if (_prefs == null) await init();
    final coursesJson = _prefs?.getStringList(_coursesKey) ?? [];
    try {
      return coursesJson.map((json) => Course.fromJsonString(json)).toList();
    } catch (_) {
      await _backupAndRemoveCorruptStringList(_coursesKey, coursesJson);
      return const [];
    }
  }

  Future<void> saveCourses(List<Course> courses) {
    final coursesSnapshot = List<Course>.from(courses);
    return _runCoursesWrite(() => _writeCoursesWithoutLock(coursesSnapshot));
  }

  Future<void> _writeCoursesWithoutLock(List<Course> courses) async {
    if (_prefs == null) await init();
    final coursesJson = courses.map((course) => course.toJsonString()).toList();
    await _prefs?.setStringList(_coursesKey, coursesJson);
  }

  Future<void> addCourse(Course course) {
    return _runCoursesWrite(() async {
      final courses = await _readCoursesWithoutLock();
      courses.add(course);
      await _writeCoursesWithoutLock(courses);
    });
  }

  Future<void> updateCourse(Course updatedCourse) {
    return _runCoursesWrite(() async {
      final courses = await _readCoursesWithoutLock();
      final index = courses.indexWhere(
        (course) => course.id == updatedCourse.id,
      );
      if (index == -1) {
        return;
      }
      courses[index] = updatedCourse;
      await _writeCoursesWithoutLock(courses);
    });
  }

  Future<void> deleteCourse(String courseId) {
    return _runCoursesWrite(() async {
      final courses = await _readCoursesWithoutLock();
      courses.removeWhere((course) => course.id == courseId);
      await _writeCoursesWithoutLock(courses);
    });
  }

  Future<T> _runCoursesWrite<T>(Future<T> Function() operation) async {
    final previousWrite = _coursesWriteChain;
    final writeCompleter = Completer<void>();
    _coursesWriteChain = writeCompleter.future;

    await previousWrite.catchError((_) {});
    try {
      return await operation();
    } finally {
      writeCompleter.complete();
    }
  }

  Future<TimetableSettings> getTimetableSettings() async {
    if (_prefs == null) await init();
    final settingsJson = _prefs?.getString(_timetableSettingsKey);
    if (settingsJson == null || settingsJson.isEmpty) {
      return TimetableSettings.defaults();
    }
    try {
      return TimetableSettings.fromJsonString(settingsJson);
    } catch (_) {
      await _backupAndRemoveCorruptString(_timetableSettingsKey, settingsJson);
      return TimetableSettings.defaults();
    }
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
    if (_prefs?.getBool(_hasSeenUserGuideKey) != value) {
      await _prefs?.setBool(_hasSeenUserGuideKey, value);
    }
  }

  Future<bool> hasAcceptedPrivacyPolicy() async {
    if (_prefs == null) await init();
    return _prefs?.getBool(_acceptedPrivacyPolicyKey) ?? false;
  }

  Future<void> setAcceptedPrivacyPolicy(bool value) async {
    if (_prefs == null) await init();
    await _prefs?.setBool(_acceptedPrivacyPolicyKey, value);
    if (_prefs?.getBool(_acceptedPrivacyPolicyKey) != value) {
      await _prefs?.setBool(_acceptedPrivacyPolicyKey, value);
    }
  }

  Future<bool> hasCompletedOnboarding() async {
    if (_prefs == null) await init();
    return _prefs?.getBool(_hasCompletedOnboardingKey) ?? false;
  }

  Future<void> setCompletedOnboarding(bool value) async {
    if (_prefs == null) await init();
    await _prefs?.setBool(_hasCompletedOnboardingKey, value);
    // 防御性验证：某些国产 ROM 的 commit() 可能不可靠
    if (_prefs?.getBool(_hasCompletedOnboardingKey) != value) {
      await _prefs?.setBool(_hasCompletedOnboardingKey, value);
    }
  }

  Future<bool> hasHandledPackageMigration() async {
    if (_prefs == null) await init();
    return _prefs?.getBool(_hasHandledPackageMigrationKey) ?? false;
  }

  Future<void> setHandledPackageMigration(bool value) async {
    if (_prefs == null) await init();
    await _prefs?.setBool(_hasHandledPackageMigrationKey, value);
  }

  Future<bool> hasMigratedAppLogsDefault() async {
    if (_prefs == null) await init();
    return _prefs?.getBool(_appLogsDefaultMigrationKey) ?? false;
  }

  Future<void> setMigratedAppLogsDefault(bool value) async {
    if (_prefs == null) await init();
    await _prefs?.setBool(_appLogsDefaultMigrationKey, value);
  }

  Future<bool> isAppDataEffectivelyEmpty() async {
    if (_prefs == null) await init();

    final legacyCourses = _prefs?.getStringList(_coursesKey) ?? const [];
    if (legacyCourses.isNotEmpty) {
      return false;
    }

    final profilesJson = _prefs?.getString(_profilesKey);
    if (profilesJson != null && profilesJson.isNotEmpty) {
      final rawProfiles = await _readJsonListPreference(_profilesKey);
      if (!_isProfilesPayloadEffectivelyEmpty(rawProfiles)) {
        return false;
      }
    }

    final timeSchemesJson = _prefs?.getString(_timeSchemesKey);
    if (timeSchemesJson != null && timeSchemesJson.isNotEmpty) {
      final schemes = await _readJsonListPreference(_timeSchemesKey);
      if (!_isTimeSchemesPayloadEffectivelyEmpty(schemes)) {
        return false;
      }
    }

    final settingsJson = _prefs?.getString(_timetableSettingsKey);
    if (settingsJson != null &&
        settingsJson.isNotEmpty &&
        !_isSettingsJsonEffectivelyDefault(settingsJson)) {
      return false;
    }
    if (_prefs?.getInt(_semesterStartKey) != null) {
      return false;
    }
    final currentWeek = _prefs?.getInt(_currentWeekKey);
    if (currentWeek != null && currentWeek != 1) {
      return false;
    }

    return true;
  }

  bool _isProfilesPayloadEffectivelyEmpty(List<dynamic>? rawProfiles) {
    if (rawProfiles == null) {
      return true;
    }
    if (rawProfiles.isEmpty) {
      return true;
    }
    if (rawProfiles.length != 1) {
      return false;
    }

    try {
      final profile = TimetableProfile.fromJson(
        Map<String, dynamic>.from(rawProfiles.first as Map),
      );
      return profile.courses.isEmpty &&
          profile.scheduleItems.isEmpty &&
          profile.currentWeek == 1 &&
          _isSettingsEffectivelyDefault(profile.settings);
    } catch (_) {
      return false;
    }
  }

  bool _isTimeSchemesPayloadEffectivelyEmpty(List<dynamic>? rawSchemes) {
    if (rawSchemes == null) {
      return true;
    }
    if (rawSchemes.isEmpty) {
      return true;
    }
    if (rawSchemes.length != 1) {
      return false;
    }

    try {
      final scheme = TimeScheme.fromJson(
        Map<String, dynamic>.from(rawSchemes.first as Map),
      );
      return _sectionSignature(scheme.sections) ==
          _sectionSignature(TimetableSettings.defaults().sections);
    } catch (_) {
      return false;
    }
  }

  bool _isSettingsJsonEffectivelyDefault(String settingsJson) {
    try {
      final settings = TimetableSettings.fromJsonString(settingsJson);
      return _isSettingsEffectivelyDefault(settings);
    } catch (_) {
      return false;
    }
  }

  bool _isSettingsEffectivelyDefault(TimetableSettings settings) {
    final defaults = TimetableSettings.defaults();
    final normalizedSettings = settings
        .copyWith(activeTimeSchemeId: null)
        .toJson();
    final normalizedDefaults = defaults.toJson();
    return jsonEncode(normalizedSettings) == jsonEncode(normalizedDefaults);
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
          currentTime.compareTo(course.endTime) < 0) {
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
    await _migrateHidePrefixDefault();
    final cached = _profilesListCache;
    if (cached != null) {
      return _snapshotProfiles(cached);
    }

    final parseResult = await _parseProfilesFromDisk();
    if (parseResult.didDrop && parseResult.profiles.isNotEmpty) {
      // Self-heal under the write chain so concurrent puts cannot be clobbered
      // by a stale cleaned snapshot.
      await runProfilesWrite(() async {
        final lockedResult = await _parseProfilesFromDisk();
        if (lockedResult.didDrop && lockedResult.profiles.isNotEmpty) {
          await _writeProfilesWithoutLock(lockedResult.profiles);
        } else if (!lockedResult.didDrop) {
          _profilesListCache = _snapshotProfiles(lockedResult.profiles);
        }
      });
      final healed = _profilesListCache;
      if (healed != null) {
        return _snapshotProfiles(healed);
      }
    }

    _profilesListCache = _snapshotProfiles(parseResult.profiles);
    return _snapshotProfiles(parseResult.profiles);
  }

  /// Disk parse only (no write chain). Safe to call under [runProfilesWrite].
  Future<({List<TimetableProfile> profiles, bool didDrop})>
  _parseProfilesFromDisk() async {
    if (_prefs == null) await init();
    final profilesJson = _prefs?.getString(_profilesKey);
    if (profilesJson == null || profilesJson.isEmpty) {
      return (profiles: const <TimetableProfile>[], didDrop: false);
    }

    final rawProfiles = await _readJsonListPreference(_profilesKey);
    if (rawProfiles == null) {
      return (profiles: const <TimetableProfile>[], didDrop: false);
    }

    final parsed = TimetableProfile.parseProfilesPayload(rawProfiles);
    if (parsed.profiles.isEmpty && rawProfiles.isNotEmpty) {
      // No recoverable profile — only then wipe the key (top-level total loss).
      final raw = _prefs?.getString(_profilesKey);
      if (raw != null) {
        await _backupAndRemoveCorruptString(_profilesKey, raw);
      }
      return (profiles: const <TimetableProfile>[], didDrop: true);
    }

    return (profiles: parsed.profiles, didDrop: parsed.didDrop);
  }

  Future<List<TimetableProfile>> _readProfilesWithoutLock() async {
    final parsed = await _parseProfilesFromDisk();
    return parsed.profiles;
  }

  Future<void> _writeProfilesWithoutLock(
    List<TimetableProfile> profiles,
  ) async {
    if (_prefs == null) await init();
    final payload = jsonEncode(
      profiles.map((profile) => profile.toJson()).toList(),
    );
    await _prefs?.setString(_profilesKey, payload);
    _profilesListCache = _snapshotProfiles(profiles);
  }

  /// Serializes profile disk writes (full put and RMW) on one chain.
  Future<T> runProfilesWrite<T>(Future<T> Function() operation) async {
    final previousWrite = _profilesWriteChain;
    final writeCompleter = Completer<void>();
    _profilesWriteChain = writeCompleter.future;
    await previousWrite.catchError((_) {});
    try {
      final result = await operation();
      writeCompleter.complete();
      return result;
    } catch (error) {
      // Keep later writes progressing without creating an unobserved error
      // future in the chain. The failed operation still reports its own error.
      writeCompleter.complete();
      rethrow;
    }
  }

  Future<T> _runSerializedWrite<T>({
    required Future<void> current,
    required void Function(Future<void>) update,
    required Future<T> Function() operation,
  }) async {
    final previous = current;
    final completer = Completer<void>();
    update(completer.future);
    await previous.catchError((_) {});
    try {
      return await operation();
    } finally {
      completer.complete();
    }
  }

  /// Atomically transforms the current profiles list under the write chain.
  Future<List<TimetableProfile>> updateProfiles(
    FutureOr<List<TimetableProfile>> Function(List<TimetableProfile> current)
    transform,
  ) {
    return runProfilesWrite(() async {
      final current = await _readProfilesWithoutLock();
      final next = await transform(List<TimetableProfile>.from(current));
      await _writeProfilesWithoutLock(next);
      return List<TimetableProfile>.from(next);
    });
  }

  Future<void> saveProfiles(List<TimetableProfile> profiles) {
    final profilesSnapshot = List<TimetableProfile>.from(profiles);
    return runProfilesWrite(() => _writeProfilesWithoutLock(profilesSnapshot));
  }

  Future<String?> getActiveProfileId() async {
    if (_prefs == null) await init();
    await _ensureProfilesInitialized();
    await _ensureTimeSchemesInitialized();
    await _migrateHidePrefixDefault();
    return _prefs?.getString(_activeProfileIdKey);
  }

  Future<void> setActiveProfileId(String profileId) async {
    if (_prefs == null) await init();
    await _prefs?.setString(_activeProfileIdKey, profileId);
  }

  Future<List<TimeScheme>> getTimeSchemes() async {
    if (_prefs == null) await init();
    await _timeSchemesWriteChain;
    await _ensureProfilesInitialized();
    await _ensureTimeSchemesInitialized();
    final cached = _timeSchemesListCache;
    if (cached != null) {
      return _snapshotTimeSchemes(cached);
    }

    final rawSchemes = _prefs?.getString(_timeSchemesKey);
    if (rawSchemes == null || rawSchemes.isEmpty) {
      _timeSchemesListCache = const [];
      return const [];
    }

    final decoded = await _readJsonListPreference(_timeSchemesKey);
    if (decoded == null) {
      _timeSchemesListCache = const [];
      return const [];
    }
    try {
      final schemes = <TimeScheme>[];
      for (final item in decoded) {
        try {
          if (item is! Map) continue;
          schemes.add(
            TimeScheme.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (_) {
          continue;
        }
      }
      _timeSchemesListCache = _snapshotTimeSchemes(schemes);
      return _snapshotTimeSchemes(schemes);
    } catch (_) {
      final raw = _prefs?.getString(_timeSchemesKey);
      if (raw != null) {
        await _backupAndRemoveCorruptString(_timeSchemesKey, raw);
      }
      _timeSchemesListCache = const [];
      return const [];
    }
  }

  Future<void> saveTimeSchemes(List<TimeScheme> schemes) {
    final snapshot = _snapshotTimeSchemes(schemes);
    return _runSerializedWrite<void>(
      current: _timeSchemesWriteChain,
      update: (future) => _timeSchemesWriteChain = future,
      operation: () async {
        if (_prefs == null) await init();
        final payload = jsonEncode(
          snapshot.map((scheme) => scheme.toJson()).toList(),
        );
        await _prefs?.setString(_timeSchemesKey, payload);
        _timeSchemesListCache = _snapshotTimeSchemes(snapshot);
      },
    );
  }

  Future<List<LocationTimeGroup>> getLocationTimeGroups() async {
    if (_prefs == null) await init();
    await _locationTimeGroupsWriteChain;
    final cached = _locationTimeGroupsListCache;
    if (cached != null) {
      return _snapshotLocationTimeGroups(cached);
    }

    final rawGroups = _prefs?.getString(_locationTimeGroupsKey);
    if (rawGroups == null || rawGroups.isEmpty) {
      _locationTimeGroupsListCache = const [];
      return const [];
    }

    final decoded = await _readJsonListPreference(_locationTimeGroupsKey);
    if (decoded == null) {
      _locationTimeGroupsListCache = const [];
      return const [];
    }
    try {
      final groups = <LocationTimeGroup>[];
      for (final item in decoded) {
        try {
          if (item is! Map) continue;
          final group = LocationTimeGroup.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (group.id.isNotEmpty) groups.add(group);
        } catch (_) {
          continue;
        }
      }
      _locationTimeGroupsListCache = _snapshotLocationTimeGroups(groups);
      return _snapshotLocationTimeGroups(groups);
    } catch (_) {
      final raw = _prefs?.getString(_locationTimeGroupsKey);
      if (raw != null) {
        await _backupAndRemoveCorruptString(_locationTimeGroupsKey, raw);
      }
      _locationTimeGroupsListCache = const [];
      return const [];
    }
  }

  Future<void> saveLocationTimeGroups(List<LocationTimeGroup> groups) {
    final snapshot = _snapshotLocationTimeGroups(groups);
    return _runSerializedWrite<void>(
      current: _locationTimeGroupsWriteChain,
      update: (future) => _locationTimeGroupsWriteChain = future,
      operation: () async {
        if (_prefs == null) await init();
        final payload = jsonEncode(
          snapshot.map((group) => group.toJson()).toList(),
        );
        await _prefs?.setString(_locationTimeGroupsKey, payload);
        _locationTimeGroupsListCache = _snapshotLocationTimeGroups(snapshot);
      },
    );
  }

  Future<List<ScheduleDateRule>> getScheduleDateRules() async {
    if (_prefs == null) await init();
    await _scheduleDateRulesWriteChain;
    final cached = _scheduleDateRulesListCache;
    if (cached != null) {
      return List<ScheduleDateRule>.from(cached);
    }

    final rawRules = _prefs?.getString(_scheduleDateRulesKey);
    if (rawRules == null || rawRules.isEmpty) {
      _scheduleDateRulesListCache = const [];
      return const [];
    }

    final decoded = await _readJsonListPreference(_scheduleDateRulesKey);
    if (decoded == null) {
      _scheduleDateRulesListCache = const [];
      return const [];
    }
    try {
      final rules = <ScheduleDateRule>[];
      for (final item in decoded) {
        try {
          if (item is! Map) continue;
          final rule = ScheduleDateRule.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (rule.id.isNotEmpty) rules.add(rule);
        } catch (_) {
          continue;
        }
      }
      _scheduleDateRulesListCache = List<ScheduleDateRule>.from(rules);
      return List<ScheduleDateRule>.from(rules);
    } catch (_) {
      final raw = _prefs?.getString(_scheduleDateRulesKey);
      if (raw != null) {
        await _backupAndRemoveCorruptString(_scheduleDateRulesKey, raw);
      }
      _scheduleDateRulesListCache = const [];
      return const [];
    }
  }

  Future<void> saveScheduleDateRules(List<ScheduleDateRule> rules) {
    final snapshot = rules.map((rule) => rule.copyWith()).toList();
    return _runSerializedWrite<void>(
      current: _scheduleDateRulesWriteChain,
      update: (future) => _scheduleDateRulesWriteChain = future,
      operation: () async {
        if (_prefs == null) await init();
        final payload = jsonEncode(
          snapshot.map((rule) => rule.toJson()).toList(),
        );
        await _prefs?.setString(_scheduleDateRulesKey, payload);
        _scheduleDateRulesListCache = snapshot
            .map((rule) => rule.copyWith())
            .toList();
      },
    );
  }

  /// Last bulk-applied date-rule signature (ruleId|schemeId|start|end).
  Future<String?> getScheduleDateRuleLastAppliedSignature() async {
    if (_prefs == null) await init();
    final value = _prefs
        ?.getString(_scheduleDateRuleLastAppliedSignatureKey)
        ?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> saveScheduleDateRuleLastAppliedSignature(
    String? signature,
  ) async {
    if (_prefs == null) await init();
    final trimmed = signature?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _prefs?.remove(_scheduleDateRuleLastAppliedSignatureKey);
      return;
    }
    await _prefs?.setString(_scheduleDateRuleLastAppliedSignatureKey, trimmed);
  }

  // ---------------------------------------------------------------------------
  // Teacher / Location records (persistent across courses)
  // ---------------------------------------------------------------------------

  static const String _teacherRecordsKey = 'teacher_records';
  static const String _locationRecordsKey = 'location_records';

  Future<List<String>> getTeacherRecords() async {
    if (_prefs == null) await init();
    await _teacherRecordsWriteChain;
    final raw = _prefs?.getStringList(_teacherRecordsKey);
    return List<String>.from(raw ?? const []);
  }

  Future<void> saveTeacherRecords(List<String> teachers) {
    final snapshot = List<String>.from(teachers);
    return _runSerializedWrite<void>(
      current: _teacherRecordsWriteChain,
      update: (future) => _teacherRecordsWriteChain = future,
      operation: () async {
        if (_prefs == null) await init();
        await _prefs?.setStringList(_teacherRecordsKey, snapshot);
      },
    );
  }

  Future<List<String>> getLocationRecords() async {
    if (_prefs == null) await init();
    await _locationRecordsWriteChain;
    final raw = _prefs?.getStringList(_locationRecordsKey);
    return List<String>.from(raw ?? const []);
  }

  Future<void> saveLocationRecords(List<String> locations) {
    final snapshot = List<String>.from(locations);
    return _runSerializedWrite<void>(
      current: _locationRecordsWriteChain,
      update: (future) => _locationRecordsWriteChain = future,
      operation: () async {
        if (_prefs == null) await init();
        await _prefs?.setStringList(_locationRecordsKey, snapshot);
      },
    );
  }

  Future<void> _ensureProfilesInitialized() {
    _resetEnsureCacheIfNeeded();
    if (_profilesEnsured) return Future.value();
    final existing = _profilesEnsureFuture;
    if (existing != null) return existing;
    final future = _doEnsureProfilesInitialized();
    _profilesEnsureFuture = future;
    return future.whenComplete(() {
      if (identical(_profilesEnsureFuture, future)) {
        _profilesEnsureFuture = null;
      }
    });
  }

  Future<void> _doEnsureProfilesInitialized() async {
    // _resetEnsureCacheIfNeeded already handled by wrapper; re-check flag
    if (_profilesEnsured) return;
    final rawProfiles = _prefs?.getString(_profilesKey);
    if (rawProfiles != null && rawProfiles.isNotEmpty) {
      final rawProfileList = await _readJsonListPreference(_profilesKey);
      if (rawProfileList == null) {
        // Corrupt stored profiles were backed up and removed. Continue below so
        // the app can recreate a valid default profile.
      } else {
        final profiles = _parseStoredProfiles(rawProfileList);
        if (profiles.isEmpty) {
          // A valid empty container is still not usable by the Provider. For a
          // non-empty payload, preserve the total-loss input before falling
          // through to default-profile creation.
          if (rawProfileList.isNotEmpty) {
            final raw = _prefs?.getString(_profilesKey);
            if (raw != null) {
              await _backupAndRemoveCorruptString(_profilesKey, raw);
            }
          }
        } else {
          final activeProfileId = _prefs?.getString(_activeProfileIdKey);
          if (activeProfileId == null || activeProfileId.isEmpty) {
            await setActiveProfileId(profiles.first.id);
          }
          _profilesEnsured = true;
          return;
        }
      }
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
    _profilesEnsured = true;
  }

  Future<void> _ensureTimeSchemesInitialized() {
    _resetEnsureCacheIfNeeded();
    if (_timeSchemesEnsured) return Future.value();
    final existing = _timeSchemesEnsureFuture;
    if (existing != null) return existing;
    final future = _doEnsureTimeSchemesInitialized();
    _timeSchemesEnsureFuture = future;
    return future.whenComplete(() {
      if (identical(_timeSchemesEnsureFuture, future)) {
        _timeSchemesEnsureFuture = null;
      }
    });
  }

  Future<void> _doEnsureTimeSchemesInitialized() async {
    if (_timeSchemesEnsured) return;
    // Profile initialization always creates a usable default profile when the
    // stored collection is empty. At this point that profile is already on disk,
    // so an empty time-scheme collection must still be initialized from it.
    final rawProfiles = _prefs?.getString(_profilesKey);
    if (rawProfiles == null || rawProfiles.isEmpty) {
      _timeSchemesEnsured = true;
      return;
    }

    final storedSchemesJson = _prefs?.getString(_timeSchemesKey);
    final rawStoredSchemes =
        storedSchemesJson == null || storedSchemesJson.isEmpty
        ? null
        : await _readJsonListPreference(_timeSchemesKey);
    var storedSchemes = <TimeScheme>[];
    if (rawStoredSchemes != null) {
      try {
        storedSchemes = _parseStoredTimeSchemes(rawStoredSchemes);
      } catch (_) {
        if (storedSchemesJson != null) {
          await _backupAndRemoveCorruptString(
            _timeSchemesKey,
            storedSchemesJson,
          );
        }
      }
    }
    final schemesById = {for (final scheme in storedSchemes) scheme.id: scheme};
    final schemesBySignature = {
      for (final scheme in storedSchemes)
        _sectionSignature(scheme.sections): scheme,
    };

    final rawProfileList = await _readJsonListPreference(_profilesKey);
    if (rawProfileList == null) {
      _timeSchemesEnsured = true;
      return;
    }
    final profiles = _parseStoredProfiles(rawProfileList);
    if (profiles.isEmpty) {
      _timeSchemesEnsured = true;
      return;
    }

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
    _timeSchemesEnsured = true;
  }

  String _sectionSignature(List<SectionTime> sections) {
    return jsonEncode(sections.map((section) => section.toJson()).toList());
  }

  List<TimetableProfile> _parseStoredProfiles(List<dynamic> rawProfiles) {
    return TimetableProfile.parseProfilesPayload(rawProfiles).profiles;
  }

  List<TimeScheme> _parseStoredTimeSchemes(List<dynamic> rawSchemes) {
    final schemes = <TimeScheme>[];
    for (final item in rawSchemes) {
      try {
        if (item is! Map) continue;
        schemes.add(
          TimeScheme.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        continue;
      }
    }
    return schemes;
  }

  Future<void> _migrateHidePrefixDefault() {
    _resetEnsureCacheIfNeeded();
    if (_hidePrefixMigrated) return Future.value();
    final existing = _hidePrefixMigrateFuture;
    if (existing != null) return existing;
    final future = _doMigrateHidePrefixDefault();
    _hidePrefixMigrateFuture = future;
    return future.whenComplete(() {
      if (identical(_hidePrefixMigrateFuture, future)) {
        _hidePrefixMigrateFuture = null;
      }
    });
  }

  Future<void> _doMigrateHidePrefixDefault() async {
    if (_hidePrefixMigrated) return;
    if (_prefs?.getBool(_hidePrefixDefaultMigrationKey) == true) {
      _hidePrefixMigrated = true;
      return;
    }

    final rawProfiles = _prefs?.getString(_profilesKey);
    if (rawProfiles == null || rawProfiles.isEmpty) {
      await _prefs?.setBool(_hidePrefixDefaultMigrationKey, true);
      _hidePrefixMigrated = true;
      return;
    }

    final rawProfileList = await _readJsonListPreference(_profilesKey);
    if (rawProfileList == null) {
      await _prefs?.setBool(_hidePrefixDefaultMigrationKey, true);
      _hidePrefixMigrated = true;
      return;
    }
    final profiles = _parseStoredProfiles(rawProfileList);
    if (profiles.isEmpty) {
      await _prefs?.setBool(_hidePrefixDefaultMigrationKey, true);
      _hidePrefixMigrated = true;
      return;
    }

    final migratedProfiles = profiles
        .map(
          (profile) => profile.copyWith(
            settings: profile.settings.copyWith(liveHidePrefixText: true),
          ),
        )
        .toList();

    await saveProfiles(migratedProfiles);
    await _prefs?.setBool(_hidePrefixDefaultMigrationKey, true);
    _hidePrefixMigrated = true;
  }

  Future<PartnerTimetableBinding?> getPartnerTimetableBinding() async {
    if (_prefs == null) await init();
    final raw = _prefs?.getString(_partnerTimetableBindingKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return PartnerTimetableBinding.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      await _backupAndRemoveCorruptString(_partnerTimetableBindingKey, raw);
      return null;
    }
  }

  Future<void> savePartnerTimetableBinding(
    PartnerTimetableBinding? binding,
  ) async {
    if (_prefs == null) await init();
    if (binding == null) {
      await _prefs?.remove(_partnerTimetableBindingKey);
      return;
    }
    await _prefs?.setString(
      _partnerTimetableBindingKey,
      jsonEncode(binding.toJson()),
    );
  }
}
