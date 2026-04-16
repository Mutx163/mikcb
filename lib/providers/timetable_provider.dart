import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import '../services/app_analytics.dart';
import '../services/app_log_service.dart';
import '../services/data_transfer_service.dart';
import '../services/home_widget_service.dart';
import '../services/home_widget_snapshot_service.dart';
import '../services/storage_service.dart';
import '../services/ics_import_service.dart';
import '../services/miui_live_activities_service.dart';

class LiveActivityCourseSelection {
  final Course currentCourse;
  final Course? nextCourse;
  final LiveActivityStage stage;

  const LiveActivityCourseSelection({
    required this.currentCourse,
    required this.nextCourse,
    required this.stage,
  });
}

class CourseConflict {
  final Course course;
  final Course otherCourse;

  const CourseConflict({
    required this.course,
    required this.otherCourse,
  });
}

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

enum LiveActivityStage {
  beforeClass,
  duringClassStatusBar,
  duringClass,
  beforeEnd,
}

class TimetableProvider with ChangeNotifier {
  static const Duration _liveEndReminderWindow = Duration(minutes: 10);

  final StorageService _storageService;
  final IcsImportService _icsImportService;
  final MiuiLiveActivitiesService _liveActivitiesService;
  final DataTransferService _dataTransferService;
  final HomeWidgetService _homeWidgetService;
  final HomeWidgetSnapshotService _homeWidgetSnapshotService;
  final AppAnalytics _analytics;
  final bool _enableLiveActivitySync;

  List<Course> _courses = [];
  TimetableSettings _settings = TimetableSettings.defaults();
  int _currentWeek = 1;
  List<TimeScheme> _timeSchemes = [];
  List<TimetableProfile> _profiles = [];
  String? _activeProfileId;
  int _currentDayOfWeek = DateTime.now().weekday;
  bool _isLoading = false;
  Timer? _liveActivityTimer;
  String? _currentLiveCourseId;
  bool _hasVisibleLiveUpdate = false;
  String? _lastLiveSnapshotSignature;
  String? _lastHomeWidgetSnapshotSignature;
  DateTime? _liveActivitySuspendedUntil;
  Future<void>? _initializationFuture;

  List<Course> get courses => _courses;
  TimetableSettings get settings => _settings;
  int get currentWeek => _currentWeek;
  List<TimeScheme> get timeSchemes => List.unmodifiable(_timeSchemes);
  List<TimetableProfile> get profiles => List.unmodifiable(_profiles);
  String? get activeProfileId => _activeProfileId;
  Map<String, List<Course>> get courseConflictMap => _buildCourseConflictMap();
  Map<String, List<Course>> courseConflictMapForWeek(int week) =>
      _buildCourseConflictMap(week: week);
  int get currentDayOfWeek => _currentDayOfWeek;
  bool get isLoading => _isLoading;
  DateTime? get semesterStartDate => _settings.semesterStartDate;
  DataTransferService get dataTransferService => _dataTransferService;
  TimetableProfile? get activeProfile => _getProfileById(_activeProfileId);
  TimeScheme? get activeTimeScheme =>
      _getTimeSchemeById(_settings.activeTimeSchemeId);
  int get maxUsedSection => _courses.isEmpty
      ? 1
      : _courses
          .map((course) => course.endSection)
          .reduce((a, b) => a > b ? a : b);

  TimetableProvider({
    StorageService? storageService,
    IcsImportService? icsImportService,
    MiuiLiveActivitiesService? liveActivitiesService,
    DataTransferService? dataTransferService,
    HomeWidgetService? homeWidgetService,
    HomeWidgetSnapshotService? homeWidgetSnapshotService,
    AppAnalytics? analytics,
    bool autoInitialize = true,
    bool enableLiveActivitySync = true,
  })  : _storageService = storageService ?? StorageService(),
        _icsImportService = icsImportService ?? IcsImportService(),
        _liveActivitiesService =
            liveActivitiesService ?? MiuiLiveActivitiesService(),
        _dataTransferService = dataTransferService ?? DataTransferService(),
        _homeWidgetService = homeWidgetService ?? HomeWidgetService(),
        _homeWidgetSnapshotService =
            homeWidgetSnapshotService ?? const HomeWidgetSnapshotService(),
        _analytics = analytics ?? AppAnalytics.instance,
        _enableLiveActivitySync = enableLiveActivitySync {
    if (autoInitialize) {
      unawaited(initialize());
    }
  }

  Future<void> initialize() {
    return _initializationFuture ??= _init();
  }

  Future<void> _init() async {
    await _storageService.init();
    _profiles = await _storageService.getProfiles();
    _timeSchemes = await _storageService.getTimeSchemes();
    _activeProfileId = await _storageService.getActiveProfileId();
    final activeProfile =
        this.activeProfile ?? (_profiles.isEmpty ? null : _profiles.first);
    if (activeProfile == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    _applyProfileState(activeProfile);
    final didMigrateAppLogsDefault =
        await _storageService.hasMigratedAppLogsDefault();
    if (!didMigrateAppLogsDefault && !_settings.liveEnableLocalDiagnostics) {
      _settings = _settings.copyWith(liveEnableLocalDiagnostics: true);
      await _persistActiveProfileState();
      await _storageService.setMigratedAppLogsDefault(true);
      unawaited(
        AppLogService.instance.info(
          'app_logs_default_migrated',
          'Enabled app log recording during migration',
          extras: {'profileId': activeProfile.id},
          force: true,
        ),
      );
    } else if (!didMigrateAppLogsDefault) {
      await _storageService.setMigratedAppLogsDefault(true);
    }
    if (_activeProfileId != activeProfile.id) {
      _activeProfileId = activeProfile.id;
      await _storageService.setActiveProfileId(activeProfile.id);
    }
    if (_settings.semesterStartDate != null) {
      await syncCurrentWeekWithSemesterStart();
    }
    await _syncHomeWidgetSnapshot();
    await _syncNativeRuntimePreferences();
    if (_enableLiveActivitySync) {
      _startLiveActivityTick();
    }
    notifyListeners();
  }

  void _startLiveActivityTick() {
    _liveActivityTimer?.cancel();
    unawaited(syncTemporalContext());
    _liveActivityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(syncTemporalContext());
    });
  }

  @override
  void dispose() {
    _liveActivityTimer?.cancel();
    super.dispose();
  }

  TimetableProfile? _getProfileById(String? profileId) {
    if (profileId == null) {
      return null;
    }
    for (final profile in _profiles) {
      if (profile.id == profileId) {
        return profile;
      }
    }
    return null;
  }

  TimeScheme? _getTimeSchemeById(String? schemeId) {
    if (schemeId == null) {
      return null;
    }
    for (final scheme in _timeSchemes) {
      if (scheme.id == schemeId) {
        return scheme;
      }
    }
    return null;
  }

  void _applyProfileState(TimetableProfile profile) {
    _settings = _normalizeSettingsWithTimeScheme(profile.settings);
    _courses = _syncCoursesWithEffectiveTimeSchemes(
      List<Course>.from(profile.courses),
      settings: _settings,
    );
    _currentWeek = clampCurrentWeekToSettings(profile.currentWeek, _settings);
    unawaited(_syncNativeRuntimePreferences());
  }

  Future<void> _syncNativeRuntimePreferences() async {
    await AppLogService.instance.updateLoggingEnabled(
      _settings.liveEnableLocalDiagnostics,
    );
    await _liveActivitiesService.setLiveDiagnosticsEnabled(
      _settings.liveEnableLocalDiagnostics,
    );
    await _liveActivitiesService.setHideFromRecents(
      _settings.liveHideFromRecents,
    );
  }

  TimetableSettings _normalizeSettingsWithTimeScheme(
      TimetableSettings settings) {
    final scheme = _getTimeSchemeById(settings.activeTimeSchemeId);
    if (scheme == null) {
      return settings;
    }
    final hasSameSections = _sectionSignature(settings.sections) ==
        _sectionSignature(scheme.sections);
    if (hasSameSections) {
      return settings;
    }
    return settings.copyWith(
      sections: List<SectionTime>.from(scheme.sections),
      activeTimeSchemeId: scheme.id,
    );
  }

  List<Course> _syncCoursesWithEffectiveTimeSchemes(List<Course> source,
      {TimetableSettings? settings}) {
    return source
        .map((course) => _syncCourseWithEffectiveTimeScheme(
              course,
              settings: settings,
            ))
        .toList();
  }

  Course _syncCourseWithEffectiveTimeScheme(
    Course course, {
    TimetableSettings? settings,
  }) {
    final sections = _resolveSectionsForCourse(course, settings: settings);
    final startIndex = course.startSection - 1;
    final endIndex = course.endSection - 1;
    if (sections == null || startIndex < 0 || endIndex >= sections.length) {
      return course.copyWith(timeSchemeIdOverride: course.timeSchemeIdOverride);
    }

    final startTime = sections[startIndex].startTime;
    final endTime = sections[endIndex].endTime;
    if (course.startTime == startTime && course.endTime == endTime) {
      return course;
    }

    return course.copyWith(
      startTime: startTime,
      endTime: endTime,
      timeSchemeIdOverride: course.timeSchemeIdOverride,
    );
  }

  TimeScheme? resolveCourseTimeScheme(
    Course course, {
    TimetableSettings? settings,
  }) {
    final overrideScheme = _getTimeSchemeById(course.timeSchemeIdOverride);
    if (overrideScheme != null) {
      return overrideScheme;
    }
    return _getTimeSchemeById((settings ?? _settings).activeTimeSchemeId);
  }

  List<SectionTime>? _resolveSectionsForCourse(
    Course course, {
    TimetableSettings? settings,
  }) {
    final scheme = resolveCourseTimeScheme(course, settings: settings);
    if (scheme != null) {
      return scheme.sections;
    }
    final activeSettings = settings ?? _settings;
    return activeSettings.sections;
  }

  List<TimeSchemeCourseUsageReference> getTimeSchemeCourseUsages(
    String schemeId, {
    List<TimetableProfile>? profiles,
  }) {
    final sourceProfiles = profiles ?? _profiles;
    final usages = <TimeSchemeCourseUsageReference>[];

    for (final profile in sourceProfiles) {
      for (final course in profile.courses) {
        final usesOverride = course.timeSchemeIdOverride == schemeId;
        final followsProfileScheme = course.timeSchemeIdOverride == null &&
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

  int maxUsedSectionForTimeScheme(
    String schemeId, {
    List<TimetableProfile>? profiles,
  }) {
    final usages = getTimeSchemeCourseUsages(
      schemeId,
      profiles: profiles,
    );
    if (usages.isEmpty) {
      return 0;
    }
    return usages
        .map((usage) => usage.course.endSection)
        .reduce((left, right) => left > right ? left : right);
  }

  TimeSchemeCourseUsageReference? maxSectionUsageForTimeScheme(
    String schemeId, {
    List<TimetableProfile>? profiles,
  }) {
    final usages = getTimeSchemeCourseUsages(
      schemeId,
      profiles: profiles,
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

  String? validateCourseTimeSchemeOverride({
    String? timeSchemeId,
    required int startSection,
    required int endSection,
  }) {
    final scheme = timeSchemeId == null
        ? activeTimeScheme
        : _getTimeSchemeById(timeSchemeId);
    final sectionCount = scheme?.sections.length ?? _settings.sections.length;
    if (sectionCount <= 0) {
      return timeSchemeId == null ? '当前课表时间配置不可用' : '未找到所选时间模板';
    }
    if (startSection < 1 || endSection > sectionCount) {
      return '所选时间模板节次数不足，无法覆盖第 $startSection-$endSection 节';
    }
    return null;
  }

  Future<void> _persistActiveProfileState({
    bool touchLastUsedAt = false,
  }) async {
    final activeProfile = this.activeProfile;
    if (activeProfile == null) {
      return;
    }

    final index =
        _profiles.indexWhere((profile) => profile.id == activeProfile.id);
    if (index == -1) {
      return;
    }

    _profiles[index] = activeProfile.copyWith(
      courses: List<Course>.from(_courses),
      settings: _settings,
      currentWeek: _currentWeek,
      lastUsedAt: touchLastUsedAt ? DateTime.now() : activeProfile.lastUsedAt,
    );
    await _storageService.saveProfiles(_profiles);
    if (_activeProfileId != null) {
      await _storageService.setActiveProfileId(_activeProfileId!);
    }
  }

  Future<void> _persistTimeSchemes() async {
    await _storageService.saveTimeSchemes(_timeSchemes);
  }

  String _sectionSignature(List<SectionTime> sections) {
    return jsonEncode(
      sections.map((section) => section.toJson()).toList(),
    );
  }

  TimetableSettings _buildDefaultSettingsForNewProfile() {
    final baseDefaults = TimetableSettings.defaults();
    final fallbackScheme =
        activeTimeScheme ?? (_timeSchemes.isEmpty ? null : _timeSchemes.first);
    if (fallbackScheme == null) {
      return baseDefaults;
    }
    return baseDefaults.copyWith(
      activeTimeSchemeId: fallbackScheme.id,
      sections: List<SectionTime>.from(fallbackScheme.sections),
    );
  }

  Future<TimetableSettings> _resolveSettingsAgainstTimeSchemes(
    TimetableSettings settings, {
    required String fallbackName,
  }) async {
    final currentScheme = _getTimeSchemeById(settings.activeTimeSchemeId);
    if (currentScheme != null) {
      return settings.copyWith(
        activeTimeSchemeId: currentScheme.id,
        sections: List<SectionTime>.from(currentScheme.sections),
      );
    }

    final signature = _sectionSignature(settings.sections);
    final existingScheme = _timeSchemes.firstWhere(
      (scheme) => _sectionSignature(scheme.sections) == signature,
      orElse: () => TimeScheme(
        id: '',
        name: '',
        sections: const [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    if (existingScheme.id.isNotEmpty) {
      return settings.copyWith(
        activeTimeSchemeId: existingScheme.id,
        sections: List<SectionTime>.from(existingScheme.sections),
      );
    }

    final now = DateTime.now();
    final createdScheme = TimeScheme(
      id: const Uuid().v4(),
      name: fallbackName,
      sections: List<SectionTime>.from(settings.sections),
      createdAt: now,
      updatedAt: now,
    );
    _timeSchemes.add(createdScheme);
    await _persistTimeSchemes();
    return settings.copyWith(
      activeTimeSchemeId: createdScheme.id,
      sections: List<SectionTime>.from(createdScheme.sections),
    );
  }

  Future<void> loadSettings() async {
    try {
      final profile = activeProfile;
      if (profile != null) {
        _settings = _normalizeSettingsWithTimeScheme(profile.settings);
      }
      notifyListeners();
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'timetable_load_settings_failed',
          'Error loading timetable settings',
          extras: {'error': '$e'},
        ),
      );
      debugPrint('Error loading timetable settings: $e');
    }
  }

  Future<void> loadCourses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final profile = activeProfile;
      if (profile != null) {
        _courses = _syncCoursesWithEffectiveTimeSchemes(
          List<Course>.from(profile.courses),
          settings: _settings,
        );
      }
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'timetable_load_courses_failed',
          'Error loading courses',
          extras: {'error': '$e'},
        ),
      );
      debugPrint('Error loading courses: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCurrentWeek() async {
    try {
      _currentWeek = activeProfile?.currentWeek ?? 1;
      notifyListeners();
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'timetable_load_current_week_failed',
          'Error loading current week',
          extras: {'error': '$e'},
        ),
      );
      debugPrint('Error loading current week: $e');
    }
  }

  Future<void> setCurrentWeek(int week) async {
    _currentWeek = clampCurrentWeekToSettings(week, _settings);
    await _persistActiveProfileState();
    _currentLiveCourseId = null; // 触发超级岛重刷
    notifyListeners();
    await _updateLiveActivity();
  }

  Future<TimeScheme> createTimeScheme({
    required String name,
    List<SectionTime>? sections,
    bool applyToActiveProfile = false,
  }) async {
    await initialize();
    final now = DateTime.now();
    final scheme = TimeScheme(
      id: const Uuid().v4(),
      name: name.trim(),
      sections: List<SectionTime>.from(
        sections ?? activeTimeScheme?.sections ?? _settings.sections,
      ),
      createdAt: now,
      updatedAt: now,
    );
    _timeSchemes.add(scheme);
    await _persistTimeSchemes();
    if (applyToActiveProfile) {
      await applyTimeScheme(scheme.id);
    } else {
      notifyListeners();
    }
    return scheme;
  }

  Future<void> applyTimeScheme(String schemeId) async {
    await initialize();
    final scheme = _getTimeSchemeById(schemeId);
    if (scheme == null) {
      return;
    }

    _settings = _settings.copyWith(
      activeTimeSchemeId: scheme.id,
      sections: List<SectionTime>.from(scheme.sections),
    );
    _courses = _syncCoursesWithEffectiveTimeSchemes(
      List<Course>.from(_courses),
      settings: _settings,
    );
    await _persistActiveProfileState();
    _currentLiveCourseId = null;
    notifyListeners();
    await _updateLiveActivity();
  }

  Future<TimeScheme?> renameTimeScheme(String schemeId, String name) async {
    await initialize();
    final index = _timeSchemes.indexWhere((scheme) => scheme.id == schemeId);
    if (index == -1) {
      return null;
    }

    final updated = _timeSchemes[index].copyWith(
      name: name.trim(),
      updatedAt: DateTime.now(),
    );
    _timeSchemes[index] = updated;
    await _persistTimeSchemes();
    notifyListeners();
    return updated;
  }

  Future<TimeScheme?> duplicateTimeScheme(String schemeId,
      {String? name}) async {
    await initialize();
    final source = _getTimeSchemeById(schemeId);
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
    _timeSchemes.add(duplicated);
    await _persistTimeSchemes();
    notifyListeners();
    return duplicated;
  }

  Future<String?> updateTimeScheme({
    required String schemeId,
    required String name,
    required List<SectionTime> sections,
  }) async {
    await initialize();
    final validationMessage = validateSectionTimes(sections);
    if (validationMessage != null) {
      return validationMessage;
    }
    final requiredMaxSection = maxUsedSectionForTimeScheme(schemeId);
    if (requiredMaxSection > 0 && sections.length < requiredMaxSection) {
      final usage = maxSectionUsageForTimeScheme(schemeId);
      if (usage != null) {
        final usageType = usage.usesOverride ? '副时间表' : '课表主时间表';
        return '节次数量不能小于当前已使用的最大节次（第$requiredMaxSection节）。'
            '正在使用：${usage.profileName} · ${usage.course.name}'
            '（周${usage.course.dayOfWeek} ${usage.course.startSection}-${usage.course.endSection}节，$usageType）';
      }
      return '节次数量不能小于当前已使用的最大节次（第$requiredMaxSection节）';
    }

    final index = _timeSchemes.indexWhere((scheme) => scheme.id == schemeId);
    if (index == -1) {
      return '时间模板不存在';
    }

    final updatedScheme = _timeSchemes[index].copyWith(
      name: name.trim(),
      sections: List<SectionTime>.from(sections),
      updatedAt: DateTime.now(),
    );
    _timeSchemes[index] = updatedScheme;

    for (var i = 0; i < _profiles.length; i++) {
      final profile = _profiles[i];
      final normalizedSettings = profile.settings.activeTimeSchemeId == schemeId
          ? profile.settings.copyWith(
              activeTimeSchemeId: schemeId,
              sections: List<SectionTime>.from(updatedScheme.sections),
            )
          : profile.settings;
      _profiles[i] = profile.copyWith(
        courses: _syncCoursesWithEffectiveTimeSchemes(
          List<Course>.from(profile.courses),
          settings: normalizedSettings,
        ),
        settings: normalizedSettings,
      );
    }

    if (_settings.activeTimeSchemeId == schemeId) {
      _settings = _settings.copyWith(
        activeTimeSchemeId: schemeId,
        sections: List<SectionTime>.from(updatedScheme.sections),
      );
    }

    final activeProfileIndex = _profiles.indexWhere(
      (profile) => profile.id == _activeProfileId,
    );
    if (activeProfileIndex != -1) {
      _courses = List<Course>.from(_profiles[activeProfileIndex].courses);
      _settings = _profiles[activeProfileIndex].settings;
    }

    await _persistTimeSchemes();
    await _storageService.saveProfiles(_profiles);
    _currentLiveCourseId = null;
    notifyListeners();
    await _updateLiveActivity();
    return null;
  }

  Future<bool> deleteTimeScheme(String schemeId) async {
    await initialize();
    final isInUse = _profiles.any(
      (profile) =>
          profile.settings.activeTimeSchemeId == schemeId ||
          profile.courses
              .any((course) => course.timeSchemeIdOverride == schemeId),
    );
    if (isInUse) {
      return false;
    }

    final index = _timeSchemes.indexWhere((scheme) => scheme.id == schemeId);
    if (index == -1) {
      return false;
    }
    _timeSchemes.removeAt(index);

    await _persistTimeSchemes();
    notifyListeners();
    return true;
  }

  Future<TimetableProfile> createProfile({
    required String name,
  }) async {
    await initialize();
    if (activeProfile != null) {
      await _persistActiveProfileState();
    }

    final now = DateTime.now();
    final profile = TimetableProfile(
      id: const Uuid().v4(),
      name: name,
      courses: const [],
      settings: _buildDefaultSettingsForNewProfile(),
      currentWeek: 1,
      createdAt: now,
      lastUsedAt: now,
    );

    _profiles.add(profile);
    _activeProfileId = profile.id;
    _applyProfileState(profile);
    await _persistActiveProfileState(touchLastUsedAt: true);
    _currentLiveCourseId = null;
    notifyListeners();
    await _updateLiveActivity();
    return activeProfile!;
  }

  Future<TimetableProfile?> duplicateActiveProfile({
    String? name,
  }) async {
    await initialize();
    final source = activeProfile;
    if (source == null) {
      return null;
    }

    await _persistActiveProfileState();
    final now = DateTime.now();
    final profile = source.copyWith(
      id: const Uuid().v4(),
      name: name ?? '${source.name} 副本',
      createdAt: now,
      lastUsedAt: now,
    );
    _profiles.add(profile);
    _activeProfileId = profile.id;
    _applyProfileState(profile);
    await _persistActiveProfileState(touchLastUsedAt: true);
    _currentLiveCourseId = null;
    notifyListeners();
    await _updateLiveActivity();
    return activeProfile;
  }

  Future<void> switchProfile(String profileId) async {
    await initialize();
    if (_activeProfileId == profileId) {
      return;
    }
    final targetProfile = _getProfileById(profileId);
    if (targetProfile == null) {
      return;
    }

    await _persistActiveProfileState();
    _activeProfileId = profileId;
    _applyProfileState(targetProfile);
    await _persistActiveProfileState(touchLastUsedAt: true);
    _currentLiveCourseId = null;
    _hasVisibleLiveUpdate = false;
    _lastLiveSnapshotSignature = null;
    notifyListeners();
    await _liveActivitiesService.stopLiveUpdate();
    await _syncLiveScheduleSnapshot();
    await _updateLiveActivity(syncScheduleSnapshot: false);
  }

  Future<void> renameProfile(String profileId, String name) async {
    await initialize();
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    if (index == -1) {
      return;
    }

    _profiles[index] = _profiles[index].copyWith(name: name.trim());
    await _storageService.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<bool> deleteProfile(String profileId) async {
    await initialize();
    if (_profiles.length <= 1) {
      return false;
    }

    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    if (index == -1) {
      return false;
    }

    final isActive = _profiles[index].id == _activeProfileId;
    _profiles.removeAt(index);
    if (isActive) {
      final fallbackProfile = _profiles.first;
      _activeProfileId = fallbackProfile.id;
      _applyProfileState(fallbackProfile);
      _currentLiveCourseId = null;
    }
    await _storageService.saveProfiles(_profiles);
    if (_activeProfileId != null) {
      await _storageService.setActiveProfileId(_activeProfileId!);
    }
    notifyListeners();
    await _updateLiveActivity();
    return true;
  }

  Future<void> addCourse(Course course) async {
    final validationMessage = validateCourseTimeSchemeOverride(
      timeSchemeId: course.timeSchemeIdOverride,
      startSection: course.startSection,
      endSection: course.endSection,
    );
    if (validationMessage != null) {
      throw ArgumentError(validationMessage);
    }
    final normalizedCourse =
        _syncCourseWithEffectiveTimeScheme(_normalizeCourse(course));
    final existingSharedCourse = _courses.cast<Course?>().firstWhere(
          (item) =>
              item != null &&
              _sharedCourseKey(item) == _sharedCourseKey(normalizedCourse),
          orElse: () => null,
        );
    final preparedCourse = existingSharedCourse == null
        ? normalizedCourse
        : _applySharedCourseFields(normalizedCourse, existingSharedCourse);

    _courses.add(preparedCourse);
    await _persistActiveProfileState();
    _currentLiveCourseId = null;
    notifyListeners();
    _analytics.logEventLater(
      name: 'course_created',
      parameters: {
        'day_of_week': preparedCourse.dayOfWeek,
        'section_count': preparedCourse.sectionCount,
        'has_short_name': preparedCourse.shortName?.isNotEmpty == true ? 1 : 0,
      },
    );
    _updateLiveActivity();
  }

  Future<void> updateCourse(Course course, {String? previousSharedName}) async {
    final index = _courses.indexWhere((c) => c.id == course.id);
    if (index != -1) {
      final validationMessage = validateCourseTimeSchemeOverride(
        timeSchemeId: course.timeSchemeIdOverride,
        startSection: course.startSection,
        endSection: course.endSection,
      );
      if (validationMessage != null) {
        throw ArgumentError(validationMessage);
      }
      final normalizedCourse =
          _syncCourseWithEffectiveTimeScheme(_normalizeCourse(course));
      final originalCourse = _courses[index];
      final previousKey =
          _sharedCourseKeyFromName(previousSharedName ?? originalCourse.name);
      final newKey = _sharedCourseKey(normalizedCourse);

      _courses[index] = normalizedCourse;
      for (var i = 0; i < _courses.length; i++) {
        if (i == index) {
          continue;
        }
        final current = _courses[i];
        final currentKey = _sharedCourseKey(current);
        if (currentKey == previousKey || currentKey == newKey) {
          _courses[i] = _applySharedCourseFields(current, normalizedCourse);
        }
      }

      await _persistActiveProfileState();
      _currentLiveCourseId = null;
      notifyListeners();
      _analytics.logEventLater(
        name: 'course_updated',
        parameters: {
          'day_of_week': normalizedCourse.dayOfWeek,
          'section_count': normalizedCourse.sectionCount,
          'has_short_name':
              normalizedCourse.shortName?.isNotEmpty == true ? 1 : 0,
        },
      );
      _updateLiveActivity();
    }
  }

  Future<void> deleteCourse(String courseId) async {
    _courses.removeWhere((c) => c.id == courseId);
    await _persistActiveProfileState();
    _currentLiveCourseId = null;
    notifyListeners();
    _analytics.logEventLater(
      name: 'course_deleted',
      parameters: {
        'remaining_course_count': _courses.length,
      },
    );
    _updateLiveActivity();
  }

  Future<bool> deleteCourseOccurrence({
    required String courseId,
    required int sourceWeek,
  }) async {
    await initialize();
    final index = _courses.indexWhere((course) => course.id == courseId);
    if (index == -1) {
      throw ArgumentError('未找到要删除的课程');
    }

    final originalCourse = _courses[index];
    if (!originalCourse.isInWeek(sourceWeek)) {
      throw ArgumentError('这门课在第 $sourceWeek 周没有排课');
    }

    final remainingWeeks = originalCourse.activeWeeks
        .where((week) => week != sourceWeek)
        .toList()
      ..sort();

    if (remainingWeeks.isEmpty) {
      _courses.removeAt(index);
    } else {
      _courses[index] = _syncCourseWithEffectiveTimeScheme(
        _normalizeCourse(
          originalCourse.copyWith(
            startWeek: remainingWeeks.first,
            endWeek: remainingWeeks.last,
            isOddWeek: false,
            isEvenWeek: false,
            customWeeks: remainingWeeks,
          ),
        ),
      );
    }

    await _persistActiveProfileState();
    _currentLiveCourseId = null;
    notifyListeners();
    _analytics.logEventLater(
      name: 'course_occurrence_deleted',
      parameters: {
        'source_week': sourceWeek,
        'remaining_course_count': _courses.length,
      },
    );
    await _updateLiveActivity();
    return true;
  }

  Future<bool> rescheduleCourseOccurrence({
    required String courseId,
    required int sourceWeek,
    required int targetWeek,
    required int targetDayOfWeek,
    required int targetStartSection,
    required int targetEndSection,
    String? targetLocation,
    String? targetTimeSchemeIdOverride,
  }) async {
    await initialize();
    final index = _courses.indexWhere((course) => course.id == courseId);
    if (index == -1) {
      throw ArgumentError('未找到要调课的课程');
    }

    final originalCourse = _courses[index];
    if (!originalCourse.isInWeek(sourceWeek)) {
      throw ArgumentError('这门课在第 $sourceWeek 周没有排课');
    }
    if (targetWeek < 1 || targetWeek > _settings.semesterWeekCount) {
      throw ArgumentError('目标周次超出当前学期范围');
    }

    final validationMessage = validateCourseTimeSchemeOverride(
      timeSchemeId:
          targetTimeSchemeIdOverride ?? originalCourse.timeSchemeIdOverride,
      startSection: targetStartSection,
      endSection: targetEndSection,
    );
    if (validationMessage != null) {
      throw ArgumentError(validationMessage);
    }

    final normalizedLocation =
        targetLocation?.trim() ?? originalCourse.location;
    final normalizedTimeSchemeId =
        targetTimeSchemeIdOverride ?? originalCourse.timeSchemeIdOverride;
    final isNoop = sourceWeek == targetWeek &&
        originalCourse.dayOfWeek == targetDayOfWeek &&
        originalCourse.startSection == targetStartSection &&
        originalCourse.endSection == targetEndSection &&
        originalCourse.location == normalizedLocation &&
        originalCourse.timeSchemeIdOverride == normalizedTimeSchemeId;
    if (isNoop) {
      return false;
    }

    final remainingWeeks = originalCourse.activeWeeks
        .where((week) => week != sourceWeek)
        .toList()
      ..sort();

    final movedOccurrence = _syncCourseWithEffectiveTimeScheme(
      _normalizeCourse(
        originalCourse.copyWith(
          id: remainingWeeks.isEmpty ? originalCourse.id : const Uuid().v4(),
          dayOfWeek: targetDayOfWeek,
          startSection: targetStartSection,
          endSection: targetEndSection,
          location: normalizedLocation,
          startWeek: targetWeek,
          endWeek: targetWeek,
          isOddWeek: false,
          isEvenWeek: false,
          customWeeks: [targetWeek],
          timeSchemeIdOverride: normalizedTimeSchemeId,
        ),
      ),
    );

    if (remainingWeeks.isEmpty) {
      _courses[index] = movedOccurrence;
    } else {
      _courses[index] = _syncCourseWithEffectiveTimeScheme(
        _normalizeCourse(
          originalCourse.copyWith(
            startWeek: remainingWeeks.first,
            endWeek: remainingWeeks.last,
            isOddWeek: false,
            isEvenWeek: false,
            customWeeks: remainingWeeks,
          ),
        ),
      );
      _courses.add(movedOccurrence);
    }

    await _persistActiveProfileState();
    _currentLiveCourseId = null;
    notifyListeners();
    _analytics.logEventLater(
      name: 'course_rescheduled',
      parameters: {
        'source_week': sourceWeek,
        'target_week': targetWeek,
        'target_day_of_week': targetDayOfWeek,
      },
    );
    await _updateLiveActivity();
    return true;
  }

  Future<bool> clearActiveProfileCourses() async {
    await initialize();
    final clearedCourseCount = _courses.length;
    if (clearedCourseCount == 0) {
      return false;
    }

    _courses = [];
    await _persistActiveProfileState();
    _currentLiveCourseId = null;
    notifyListeners();
    _analytics.logEventLater(
      name: 'courses_cleared',
      parameters: {
        'cleared_course_count': clearedCourseCount,
      },
    );
    await _updateLiveActivity();
    return true;
  }

  Future<String?> updateTimetableSettings(TimetableSettings settings) async {
    final sectionConfigChanged =
        settings.sectionCount != _settings.sectionCount ||
            _sectionSignature(settings.sections) !=
                _sectionSignature(_settings.sections) ||
            settings.activeTimeSchemeId != _settings.activeTimeSchemeId;

    if (sectionConfigChanged && settings.sectionCount < maxUsedSection) {
      return '节次数量不能小于当前已使用的最大节次（第$maxUsedSection节）';
    }

    _settings = _normalizeSettingsWithTimeScheme(settings);
    await _persistActiveProfileState();
    await _syncNativeRuntimePreferences();
    _lastLiveSnapshotSignature = null;
    _currentLiveCourseId = null;
    notifyListeners();
    await _syncLiveScheduleSnapshot();
    await _updateLiveActivity(syncScheduleSnapshot: false);
    return null;
  }

  int previewWakeUpImportRequiredSectionCount(
    String content, {
    required bool replaceExisting,
  }) {
    final result = _icsImportService.parseWakeUpSchedule(content);
    return previewImportedCourseRequiredSectionCount(
      result.courses,
      replaceExisting: replaceExisting,
    );
  }

  int previewImportedCourseRequiredSectionCount(
    List<Course> importedCourses, {
    required bool replaceExisting,
  }) {
    if (importedCourses.isEmpty) {
      return _settings.sectionCount;
    }

    return importedCourses
        .map((course) => course.endSection)
        .reduce((left, right) => left > right ? left : right);
  }

  Future<String?> ensureSectionCapacityForImport(
      int requiredSectionCount) async {
    await initialize();
    if (requiredSectionCount <= _settings.sectionCount) {
      return null;
    }

    final expandedSections = _buildExpandedSections(
      _settings.sections,
      requiredSectionCount,
    );
    final currentScheme = activeTimeScheme;

    if (currentScheme == null) {
      _settings = _settings.copyWith(sections: expandedSections);
      _courses = _syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(_courses),
        settings: _settings,
      );
      await _persistActiveProfileState();
      _currentLiveCourseId = null;
      notifyListeners();
      await _updateLiveActivity();
      return null;
    }

    final usageCount = _profiles
        .where((profile) =>
            profile.settings.activeTimeSchemeId == currentScheme.id)
        .length;

    if (usageCount <= 1) {
      return updateTimeScheme(
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
    _timeSchemes.add(duplicatedScheme);
    await _persistTimeSchemes();

    _settings = _settings.copyWith(
      activeTimeSchemeId: duplicatedScheme.id,
      sections: expandedSections,
    );
    _courses = _syncCoursesWithEffectiveTimeSchemes(
      List<Course>.from(_courses),
      settings: _settings,
    );
    await _persistActiveProfileState();
    _currentLiveCourseId = null;
    notifyListeners();
    await _updateLiveActivity();
    return null;
  }

  Future<int> importWakeUpCalendar(
    String content, {
    required bool replaceExisting,
  }) async {
    final result = _icsImportService.parseWakeUpSchedule(content);
    return importParsedCourses(
      result.courses,
      replaceExisting: replaceExisting,
      semesterStart: result.semesterStart,
      source: 'ics',
    );
  }

  Future<int> importParsedCourses(
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
      mergedCourses = dedupedImportedCourses;
      effectiveImportedCount = dedupedImportedCourses.length;
      syncResult = null;
    } else {
      final replacedCourses = replaceImportedCoursesPreservingLocalFields(
        existingCourses: _courses,
        importedCourses: importedCourses,
      );
      if (_courseListsEqual(_courses, replacedCourses)) {
        return 0;
      }
      syncResult = null;
      mergedCourses = replacedCourses;
      effectiveImportedCount = replacedCourses.length;
    }

    _courses = _syncCoursesWithEffectiveTimeSchemes(
      mergedCourses,
      settings: _settings,
    );
    final requiredWeekCount = _maxCourseWeek(_courses);
    _settings = _settings.copyWith(
      semesterStartDate: semesterStart ?? _settings.semesterStartDate,
      semesterWeekCount: requiredWeekCount > _settings.semesterWeekCount
          ? requiredWeekCount
          : _settings.semesterWeekCount,
    );
    if (semesterStart != null) {
      _currentWeek = _calculateWeekForDate(DateTime.now());
    }
    await _persistActiveProfileState();
    _currentLiveCourseId = null;
    notifyListeners();
    _analytics.logEventLater(
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
    await _updateLiveActivity();
    return effectiveImportedCount;
  }

  List<SectionTime> _buildExpandedSections(
    List<SectionTime> sections,
    int requiredSectionCount,
  ) {
    final expanded = sections.isEmpty
        ? List<SectionTime>.from(TimetableSettings.defaults().sections)
        : List<SectionTime>.from(sections);

    final defaultDuration = _inferSectionDurationMinutes(expanded);
    final defaultBreak = _inferBreakDurationMinutes(expanded);
    while (expanded.length < requiredSectionCount) {
      final last = expanded.last;
      final lastEndMinutes = _parseClockToMinutes(last.endTime);
      final nextStartMinutes = lastEndMinutes + defaultBreak;
      final nextEndMinutes = nextStartMinutes + defaultDuration;
      expanded.add(
        SectionTime(
          startTime: _formatClockMinutes(nextStartMinutes),
          endTime: _formatClockMinutes(nextEndMinutes),
        ),
      );
    }
    return expanded;
  }

  int _inferSectionDurationMinutes(List<SectionTime> sections) {
    for (var index = sections.length - 1; index >= 0; index--) {
      final start = _parseClockToMinutes(sections[index].startTime);
      final end = _parseClockToMinutes(sections[index].endTime);
      final duration = end - start;
      if (duration > 0) {
        return duration;
      }
    }
    return 45;
  }

  int _inferBreakDurationMinutes(List<SectionTime> sections) {
    if (sections.length < 2) {
      return 10;
    }

    for (var index = sections.length - 1; index > 0; index--) {
      final previousEnd = _parseClockToMinutes(sections[index - 1].endTime);
      final currentStart = _parseClockToMinutes(sections[index].startTime);
      final gap = currentStart - previousEnd;
      if (gap > 0) {
        return gap;
      }
    }
    return 10;
  }

  int _parseClockToMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return 0;
    }
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  String _formatClockMinutes(int minutes) {
    final normalized = minutes % (24 * 60);
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<String?> importAppDataBackup(String content) async {
    try {
      if (_dataTransferService.isFullBackupJson(content)) {
        return await importFullAppDataBackup(content);
      }
      final backup = _dataTransferService.parseBackupJson(content);
      final resolvedSettings = await _resolveSettingsAgainstTimeSchemes(
        backup.settings,
        fallbackName: '${activeProfile?.name ?? "导入课表"} 时间',
      );
      _courses = _syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(backup.courses),
        settings: resolvedSettings,
      );
      _settings = resolvedSettings;
      _currentWeek = clampCurrentWeekToSettings(backup.currentWeek, _settings);

      await _persistActiveProfileState();
      _currentLiveCourseId = null;
      notifyListeners();
      _analytics.logEventLater(
        name: 'backup_imported',
        parameters: {
          'course_count': _courses.length,
          'current_week': _currentWeek,
        },
      );
      await _updateLiveActivity();
      return null;
    } on FormatException catch (e) {
      return e.message;
    } catch (_) {
      return '导入失败，文件内容无法识别';
    }
  }

  Future<String?> importAppDataBackupAsNewProfile(
    String content, {
    String? profileName,
  }) async {
    try {
      if (_dataTransferService.isFullBackupJson(content)) {
        return '这是全部数据备份，请使用“覆盖当前课表”方式导入';
      }
      final backup = _dataTransferService.parseBackupJson(content);
      final nextName = (profileName ?? backup.profileName ?? '导入课表').trim();
      final resolvedSettings = await _resolveSettingsAgainstTimeSchemes(
        backup.settings,
        fallbackName: '$nextName 时间',
      );
      final now = DateTime.now();
      final nextProfile = TimetableProfile(
        id: const Uuid().v4(),
        name: nextName,
        courses: _syncCoursesWithEffectiveTimeSchemes(
          List<Course>.from(backup.courses),
          settings: resolvedSettings,
        ),
        settings: resolvedSettings,
        currentWeek: clampCurrentWeekToSettings(
          backup.currentWeek,
          resolvedSettings,
        ),
        createdAt: now,
        lastUsedAt: now,
      );

      await _persistActiveProfileState();
      _profiles.add(nextProfile);
      _activeProfileId = nextProfile.id;
      _applyProfileState(nextProfile);
      await _persistActiveProfileState(touchLastUsedAt: true);
      _currentLiveCourseId = null;
      notifyListeners();
      _analytics.logEventLater(
        name: 'backup_imported',
        parameters: {
          'course_count': _courses.length,
          'current_week': _currentWeek,
          'created_profile': 1,
        },
      );
      await _updateLiveActivity();
      return null;
    } on FormatException catch (e) {
      return e.message;
    } catch (_) {
      return '导入失败，文件内容无法识别';
    }
  }

  Future<String?> importFullAppDataBackup(String content) async {
    try {
      final backup = _dataTransferService.parseFullBackupJson(content);
      if (backup.profiles.isEmpty) {
        return '备份文件中没有可恢复的课表';
      }

      _timeSchemes = List<TimeScheme>.from(backup.timeSchemes);
      _profiles = backup.profiles
          .map(
            (profile) => profile.copyWith(
              settings: _normalizeSettingsWithTimeScheme(profile.settings),
            ),
          )
          .toList();
      _profiles = _profiles
          .map(
            (profile) => profile.copyWith(
              courses: _syncCoursesWithEffectiveTimeSchemes(
                List<Course>.from(profile.courses),
                settings: profile.settings,
              ),
            ),
          )
          .toList();
      _activeProfileId = backup.activeProfileId != null &&
              _profiles.any((profile) => profile.id == backup.activeProfileId)
          ? backup.activeProfileId
          : _profiles.first.id;

      await _storageService.saveTimeSchemes(_timeSchemes);
      await _storageService.saveProfiles(_profiles);
      if (_activeProfileId != null) {
        await _storageService.setActiveProfileId(_activeProfileId!);
      }

      _applyProfileState(
          _profiles.firstWhere((profile) => profile.id == _activeProfileId));
      _currentLiveCourseId = null;
      notifyListeners();
      await _updateLiveActivity();
      return null;
    } on FormatException catch (e) {
      return e.message;
    } catch (_) {
      return '导入失败，文件内容无法识别';
    }
  }

  Future<void> syncCurrentWeekWithSemesterStart() async {
    final semesterStart = _settings.semesterStartDate;
    if (semesterStart == null) {
      return;
    }

    final now = DateTime.now();
    final normalizedNow = _startOfWeek(now);
    final normalizedStart = _startOfWeek(semesterStart);
    final week = (normalizedNow.difference(normalizedStart).inDays ~/ 7) + 1;
    final targetWeek = week < 1 ? 1 : week;
    await setCurrentWeek(
      targetWeek > _settings.semesterWeekCount
          ? _settings.semesterWeekCount
          : targetWeek,
    );
  }

  Future<bool> syncTemporalContext({
    DateTime? now,
  }) async {
    await initialize();
    final reference = now ?? DateTime.now();
    final targetDayOfWeek = reference.weekday;
    final targetWeek = _calculateWeekForDate(reference);
    final didChangeWeek = targetWeek != _currentWeek;
    final didChangeDay = targetDayOfWeek != _currentDayOfWeek;

    if (!didChangeWeek && !didChangeDay) {
      return false;
    }

    if (didChangeWeek) {
      _currentWeek = clampCurrentWeekToSettings(targetWeek, _settings);
      await _persistActiveProfileState();
    }
    if (didChangeDay) {
      _currentDayOfWeek = targetDayOfWeek;
    }

    _currentLiveCourseId = null;
    notifyListeners();
    await _updateLiveActivity();
    return true;
  }

  Map<String, List<Course>> _buildCourseConflictMap({int? week}) {
    final conflictMap = <String, List<Course>>{};

    for (var i = 0; i < _courses.length; i++) {
      for (var j = i + 1; j < _courses.length; j++) {
        final course = _courses[i];
        final otherCourse = _courses[j];
        if (!_coursesActuallyConflict(course, otherCourse, week: week)) {
          continue;
        }

        conflictMap.putIfAbsent(course.id, () => []).add(otherCourse);
        conflictMap.putIfAbsent(otherCourse.id, () => []).add(course);
      }
    }

    return conflictMap;
  }

  bool _coursesActuallyConflict(Course left, Course right, {int? week}) {
    if (left.id == right.id) {
      return false;
    }
    if (left.dayOfWeek != right.dayOfWeek) {
      return false;
    }
    if (left.endSection < right.startSection ||
        right.endSection < left.startSection) {
      return false;
    }

    final overlapStartWeek =
        left.startWeek > right.startWeek ? left.startWeek : right.startWeek;
    final overlapEndWeek =
        left.endWeek < right.endWeek ? left.endWeek : right.endWeek;
    if (overlapStartWeek > overlapEndWeek) {
      return false;
    }

    if (week != null) {
      if (week < overlapStartWeek || week > overlapEndWeek) {
        return false;
      }
      return left.isInWeek(week) && right.isInWeek(week);
    }

    for (var week = overlapStartWeek; week <= overlapEndWeek; week++) {
      if (left.isInWeek(week) && right.isInWeek(week)) {
        return true;
      }
    }

    return false;
  }

  Course _normalizeCourse(Course course) {
    return course.copyWith(
      name: course.name.trim(),
      shortName: course.shortName?.trim().isEmpty == true
          ? null
          : course.shortName?.trim(),
      teacher: course.teacher.trim(),
      location: course.location.trim(),
      description: course.description?.trim().isEmpty == true
          ? null
          : course.description?.trim(),
      note: course.note?.trim().isEmpty == true ? null : course.note?.trim(),
    );
  }

  Course _applySharedCourseFields(Course target, Course source) {
    return target.copyWith(
      name: source.name,
      shortName: source.shortName,
      teacher: source.teacher,
      color: source.color,
      courseNature: source.courseNature,
      description: source.description,
    );
  }

  String _sharedCourseKey(Course course) =>
      _buildSharedCourseNameKey(course.name);

  String _sharedCourseKeyFromName(String name) =>
      _buildSharedCourseNameKey(name);

  int _calculateWeekForDate(DateTime date) {
    final semesterStart = _settings.semesterStartDate;
    if (semesterStart == null) {
      return _currentWeek;
    }

    final normalizedDate = _startOfWeek(date);
    final normalizedStart = _startOfWeek(semesterStart);
    final week = (normalizedDate.difference(normalizedStart).inDays ~/ 7) + 1;
    if (week < 1) {
      return 1;
    }
    if (week > _settings.semesterWeekCount) {
      return _settings.semesterWeekCount;
    }
    return week;
  }

  int _maxCourseWeek(List<Course> courses) {
    if (courses.isEmpty) {
      return _settings.semesterWeekCount;
    }

    return courses
        .map((course) => course.normalizedCustomWeeks?.last ?? course.endWeek)
        .reduce((left, right) => left > right ? left : right);
  }

  DateTime _startOfWeek(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return normalizedDate.subtract(Duration(days: normalizedDate.weekday - 1));
  }

  List<Course> getCoursesForDay(int dayOfWeek, {int? week}) {
    final targetWeek = week ?? _currentWeek;
    return _courses
        .where((course) =>
            course.dayOfWeek == dayOfWeek && course.isInWeek(targetWeek))
        .toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
  }

  List<Course> getTodayCourses() {
    return getCoursesForDay(_currentDayOfWeek);
  }

  Course? getCurrentCourse() {
    final todayCourses = getTodayCourses();
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

  Course? getCourseInProgress({
    required int dayOfWeek,
    int? week,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final targetWeek = week ?? _calculateWeekForDate(reference);
    final currentMinutes = reference.hour * 60 + reference.minute;

    for (final course in getCoursesForDay(dayOfWeek, week: targetWeek)) {
      final startMinutes = _parseClockMinutes(_resolveRealTime(course, true));
      final endMinutes = _parseClockMinutes(_resolveRealTime(course, false));
      if (startMinutes == null || endMinutes == null) {
        continue;
      }
      if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
        return resolveCourseDisplayName(course);
      }
    }
    return null;
  }

  Course? getNextCourse() {
    final todayCourses = getTodayCourses();
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

  String? _normalizeShortName(String? shortName) {
    final value = shortName?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String? resolveCourseShortName(Course course) {
    final directShortName = _normalizeShortName(course.shortName);
    if (directShortName != null) {
      return directShortName;
    }

    final normalizedName = course.name.trim();
    if (normalizedName.isEmpty) {
      return null;
    }

    for (final candidate in _courses) {
      if (candidate.id == course.id) {
        continue;
      }
      if (candidate.name.trim() != normalizedName) {
        continue;
      }

      final fallbackShortName = _normalizeShortName(candidate.shortName);
      if (fallbackShortName != null) {
        return fallbackShortName;
      }
    }

    return null;
  }

  Course resolveCourseDisplayName(Course course) {
    final resolvedShortName = resolveCourseShortName(course);
    if (resolvedShortName == null || resolvedShortName == course.shortName) {
      return course;
    }
    return course.copyWith(shortName: resolvedShortName);
  }

  DateTime? _buildCourseDateTime(DateTime date, String courseTime) {
    final parts = courseTime.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  int? _parseClockMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    return hour * 60 + minute;
  }

  List<Map<String, dynamic>> buildLiveProgressMilestones(
    Course course, {
    int? startAtMillis,
    int? endAtMillis,
  }) {
    if (course.sectionCount < 2) {
      return const [];
    }

    final sections = _resolveSectionsForCourse(course);
    if (sections == null) {
      return const [];
    }
    final firstSectionIndex = course.startSection - 1;
    final lastSectionIndex = course.endSection - 1;
    if (firstSectionIndex < 0 || lastSectionIndex >= sections.length) {
      return const [];
    }

    final resolvedStartAtMillis = startAtMillis;
    final resolvedEndAtMillis = endAtMillis;
    if (resolvedStartAtMillis == null ||
        resolvedEndAtMillis == null ||
        resolvedEndAtMillis <= resolvedStartAtMillis) {
      return const [];
    }

    final sectionStartMinutes =
        _parseClockMinutes(sections[firstSectionIndex].startTime);
    final sectionEndMinutes =
        _parseClockMinutes(sections[lastSectionIndex].endTime);
    if (sectionStartMinutes == null ||
        sectionEndMinutes == null ||
        sectionEndMinutes <= sectionStartMinutes) {
      return const [];
    }

    final referenceTotalMinutes = sectionEndMinutes - sectionStartMinutes;
    final totalDurationMillis = resolvedEndAtMillis - resolvedStartAtMillis;
    final milestones = <Map<String, dynamic>>[];

    for (var sectionIndex = firstSectionIndex;
        sectionIndex < lastSectionIndex;
        sectionIndex++) {
      final currentSection = sections[sectionIndex];
      final nextSection = sections[sectionIndex + 1];
      final currentEndMinutes = _parseClockMinutes(currentSection.endTime);
      final nextStartMinutes = _parseClockMinutes(nextSection.startTime);
      if (currentEndMinutes == null ||
          nextStartMinutes == null ||
          nextStartMinutes <= currentEndMinutes) {
        continue;
      }

      final breakStartOffsetMillis =
          (((currentEndMinutes - sectionStartMinutes) / referenceTotalMinutes) *
                  totalDurationMillis)
              .round()
              .clamp(1, totalDurationMillis - 1);
      final breakEndOffsetMillis =
          (((nextStartMinutes - sectionStartMinutes) / referenceTotalMinutes) *
                  totalDurationMillis)
              .round()
              .clamp(1, totalDurationMillis - 1);

      milestones.add({
        'offsetMillis': breakStartOffsetMillis,
        'label': '最近下课',
        'timeText': currentSection.endTime,
      });
      milestones.add({
        'offsetMillis': breakEndOffsetMillis,
        'label': '下节上课',
        'timeText': nextSection.startTime,
      });
    }

    milestones.sort((left, right) =>
        (left['offsetMillis'] as int).compareTo(right['offsetMillis'] as int));
    return milestones;
  }

  List<int> buildLiveProgressBreakOffsetsMillis(
    Course course, {
    int? startAtMillis,
    int? endAtMillis,
  }) {
    return buildLiveProgressMilestones(
      course,
      startAtMillis: startAtMillis,
      endAtMillis: endAtMillis,
    ).map((milestone) => milestone['offsetMillis'] as int).toList();
  }

  String _resolveRealTime(Course course, bool isStart) {
    final sections = _resolveSectionsForCourse(course);
    final sectionIndex =
        (isStart ? course.startSection : course.endSection) - 1;
    if (sections != null &&
        sectionIndex >= 0 &&
        sectionIndex < sections.length) {
      return isStart
          ? sections[sectionIndex].startTime
          : sections[sectionIndex].endTime;
    }
    return isStart ? course.startTime : course.endTime;
  }

  DateTime _applyLiveTimeCorrection(DateTime dateTime) {
    final correctionSeconds = _settings.liveTimeCorrectionSeconds;
    if (correctionSeconds == 0) {
      return dateTime;
    }
    return dateTime.add(Duration(seconds: correctionSeconds));
  }

  DateTime? _buildCorrectedCourseDateTime(DateTime date, String courseTime) {
    final base = _buildCourseDateTime(date, courseTime);
    if (base == null) {
      return null;
    }
    return _applyLiveTimeCorrection(base);
  }

  DateTime? _resolveBeforeClassBlockedUntil(
    List<Course> todayCourses,
    int courseIndex,
    DateTime referenceDate,
  ) {
    if (courseIndex <= 0 || courseIndex >= todayCourses.length) {
      return null;
    }

    final course = todayCourses[courseIndex];
    final courseStartTime = _buildCorrectedCourseDateTime(
      referenceDate,
      _resolveRealTime(course, true),
    );
    if (courseStartTime == null) {
      return null;
    }

    DateTime? blockedUntil;
    for (var i = 0; i < courseIndex; i++) {
      final previousCourse = todayCourses[i];
      final previousStartTime = _buildCorrectedCourseDateTime(
        referenceDate,
        _resolveRealTime(previousCourse, true),
      );
      final previousEndTime = _buildCorrectedCourseDateTime(
        referenceDate,
        _resolveRealTime(previousCourse, false),
      );
      if (previousStartTime == null || previousEndTime == null) {
        continue;
      }
      if (previousStartTime.isAfter(courseStartTime)) {
        continue;
      }
      if (blockedUntil == null || previousEndTime.isAfter(blockedUntil)) {
        blockedUntil = previousEndTime;
      }
    }

    return blockedUntil;
  }

  LiveActivityCourseSelection? getLiveActivityCourseSelection({
    DateTime? now,
    bool allowUpcomingFallback = false,
    int? week,
  }) {
    final currentTime = now ?? DateTime.now();
    final targetWeek = week ?? _calculateWeekForDate(currentTime);
    final todayCourses =
        getCoursesForDay(currentTime.weekday, week: targetWeek);
    if (todayCourses.isEmpty) return null;

    for (var i = 0; i < todayCourses.length; i++) {
      final course = todayCourses[i];
      final startTime = _buildCorrectedCourseDateTime(
          currentTime, _resolveRealTime(course, true));
      final endTime = _buildCorrectedCourseDateTime(
          currentTime, _resolveRealTime(course, false));
      if (startTime == null || endTime == null) {
        continue;
      }

      final aheadTime = startTime.subtract(
        Duration(minutes: _settings.liveShowBeforeClassMinutes),
      );
      final blockedUntil =
          _resolveBeforeClassBlockedUntil(todayCourses, i, currentTime);
      final effectiveAheadTime =
          blockedUntil != null && blockedUntil.isAfter(aheadTime)
              ? blockedUntil
              : aheadTime;
      final stage = _resolveLiveActivityStage(
        currentTime: currentTime,
        startTime: startTime,
        endTime: endTime,
        aheadTime: effectiveAheadTime,
      );
      if (stage != null) {
        final nextCourse =
            i + 1 < todayCourses.length ? todayCourses[i + 1] : null;
        return LiveActivityCourseSelection(
          currentCourse: resolveCourseDisplayName(course),
          nextCourse:
              nextCourse == null ? null : resolveCourseDisplayName(nextCourse),
          stage: stage,
        );
      }
    }

    if (!allowUpcomingFallback || !_settings.liveEnableBeforeClass) {
      return null;
    }

    for (var i = 0; i < todayCourses.length; i++) {
      final course = todayCourses[i];
      final startTime = _buildCorrectedCourseDateTime(
          currentTime, _resolveRealTime(course, true));
      if (startTime == null || !startTime.isAfter(currentTime)) {
        continue;
      }
      final blockedUntil =
          _resolveBeforeClassBlockedUntil(todayCourses, i, currentTime);
      if (blockedUntil != null && currentTime.isBefore(blockedUntil)) {
        continue;
      }

      final nextCourse =
          i + 1 < todayCourses.length ? todayCourses[i + 1] : null;
      return LiveActivityCourseSelection(
        currentCourse: resolveCourseDisplayName(course),
        nextCourse:
            nextCourse == null ? null : resolveCourseDisplayName(nextCourse),
        stage: LiveActivityStage.beforeClass,
      );
    }

    return null;
  }

  LiveActivityCourseSelection? getTestLiveActivityCourseSelection({
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final targetWeek = _calculateWeekForDate(currentTime);
    final immediateSelection = getLiveActivityCourseSelection(
      now: currentTime,
      allowUpcomingFallback: true,
      week: targetWeek,
    );
    if (immediateSelection != null) {
      return immediateSelection;
    }

    final today = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    );
    final maxWeek = _courses.isEmpty
        ? targetWeek
        : _courses
            .map((course) => course.endWeek)
            .reduce((a, b) => a > b ? a : b);

    Course? bestCourse;
    DateTime? bestStartTime;
    int? bestWeek;

    for (final course in _courses) {
      for (var week = targetWeek; week <= maxWeek; week++) {
        if (!course.isInWeek(week)) {
          continue;
        }

        final dayOffset =
            (week - targetWeek) * 7 + course.dayOfWeek - currentTime.weekday;
        if (dayOffset < 0) {
          continue;
        }

        final candidateDate = today.add(Duration(days: dayOffset));
        final candidateStart = _buildCorrectedCourseDateTime(
          candidateDate,
          _resolveRealTime(course, true),
        );
        if (candidateStart == null || !candidateStart.isAfter(currentTime)) {
          continue;
        }

        if (bestStartTime == null || candidateStart.isBefore(bestStartTime)) {
          bestCourse = course;
          bestStartTime = candidateStart;
          bestWeek = week;
        }
        break;
      }
    }

    final fallbackStage = _preferredTestStage();
    if (bestCourse == null || bestWeek == null || fallbackStage == null) {
      return null;
    }
    final resolvedWeek = bestWeek;

    final sameDayCourses = _courses
        .where((course) =>
            course.dayOfWeek == bestCourse!.dayOfWeek &&
            course.isInWeek(resolvedWeek))
        .toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
    final currentIndex =
        sameDayCourses.indexWhere((course) => course.id == bestCourse!.id);
    final nextCourse =
        currentIndex != -1 && currentIndex + 1 < sameDayCourses.length
            ? sameDayCourses[currentIndex + 1]
            : null;

    return LiveActivityCourseSelection(
      currentCourse: resolveCourseDisplayName(bestCourse),
      nextCourse:
          nextCourse == null ? null : resolveCourseDisplayName(nextCourse),
      stage: fallbackStage,
    );
  }

  HomeWidgetSnapshot? buildHomeWidgetSnapshot({
    DateTime? now,
  }) {
    final profile = activeProfile;
    if (profile == null) {
      return null;
    }

    final currentTime = now ?? DateTime.now();
    final targetWeek = _calculateWeekForDate(currentTime);
    final todayCourses = getCoursesForDay(currentTime.weekday, week: targetWeek)
        .map(resolveCourseDisplayName)
        .toList(growable: false);

    return _homeWidgetSnapshotService.build(
      profileId: profile.id,
      profileName: profile.name,
      currentWeek: targetWeek,
      settings: _settings,
      todayCourses: todayCourses,
      now: currentTime,
    );
  }

  Future<void> _updateLiveActivity({
    bool syncScheduleSnapshot = true,
  }) async {
    await _syncHomeWidgetSnapshot();
    if (!_enableLiveActivitySync) {
      return;
    }

    if (syncScheduleSnapshot) {
      await _syncLiveScheduleSnapshot();
    }

    final suspendedUntil = _liveActivitySuspendedUntil;
    if (suspendedUntil != null) {
      if (DateTime.now().isBefore(suspendedUntil)) {
        return;
      }
      _liveActivitySuspendedUntil = null;
    }

    final selection = getLiveActivityCourseSelection();
    final liveCourse = selection?.currentCourse;

    if (liveCourse != null) {
      final activeSelection = selection!;
      final settings = _settings;
      final displaySettings =
          activeSelection.stage == LiveActivityStage.beforeClass
              ? settings.beforeClassDisplaySettings
              : settings.duringEndDisplaySettings;
      final nextCourse = activeSelection.nextCourse;
      final nextCourseKey = nextCourse != null
          ? '${nextCourse.id}:${nextCourse.name}:${nextCourse.startSection}'
          : 'null';
      final liveActivityKey =
          '${liveCourse.id}:${activeSelection.stage.name}:${liveCourse.name}:${liveCourse.startSection}:${liveCourse.endSection}:${liveCourse.location}:${liveCourse.teacher}:$nextCourseKey:${settings.hashCode}';
      if (_currentLiveCourseId == liveActivityKey) {
        return; // 防抖，避免频繁唤起 Android 服务
      }
      _currentLiveCourseId = liveActivityKey;

      final displayCourse = liveCourse.copyWith(
        startTime: _resolveRealTime(liveCourse, true),
        endTime: _resolveRealTime(liveCourse, false),
      );
      final displayNextCourse = activeSelection.nextCourse?.copyWith(
        startTime: _resolveRealTime(activeSelection.nextCourse!, true),
        endTime: _resolveRealTime(activeSelection.nextCourse!, false),
      );
      final startAtMillis = _buildCorrectedCourseDateTime(
        DateTime.now(),
        _resolveRealTime(displayCourse, true),
      )?.millisecondsSinceEpoch;
      final endAtMillis = _buildCorrectedCourseDateTime(
        DateTime.now(),
        _resolveRealTime(displayCourse, false),
      )?.millisecondsSinceEpoch;
      final progressMilestones = buildLiveProgressMilestones(
        displayCourse,
        startAtMillis: startAtMillis,
        endAtMillis: endAtMillis,
      );
      final progressBreakOffsetsMillis = buildLiveProgressBreakOffsetsMillis(
        displayCourse,
        startAtMillis: startAtMillis,
        endAtMillis: endAtMillis,
      );

      await _liveActivitiesService.startLiveUpdate(
        displayCourse,
        displayNextCourse,
        stage: selection.stage.name,
        liveClassReminderStartMinutes: settings.liveClassReminderStartMinutes,
        endSecondsCountdownThreshold: settings.liveEndSecondsCountdownThreshold,
        promoteDuringClass:
            activeSelection.stage == LiveActivityStage.duringClassStatusBar
                ? false
                : settings.livePromoteDuringClass,
        showNotificationDuringClass:
            activeSelection.stage == LiveActivityStage.duringClassStatusBar
                ? true
                : settings.liveShowDuringClassNotification,
        enableBeforeClass: settings.liveEnableBeforeClass,
        enableDuringClass: settings.liveEnableDuringClass,
        enableBeforeEnd: settings.liveEnableBeforeEnd,
        showCountdown: displaySettings.showCountdown,
        countdownTextStyle: displaySettings.countdownTextStyle,
        showStageText: displaySettings.showStageText,
        showCourseNameInIsland: displaySettings.showCourseName,
        showLocationInIsland: displaySettings.showLocation,
        useShortNameInIsland: displaySettings.useShortName,
        hidePrefixText: displaySettings.hidePrefixText,
        duringClassTimeDisplayMode: displaySettings.duringClassTimeDisplayMode,
        enableMiuiIslandLabelImage: displaySettings.enableMiuiIslandLabelImage,
        miuiIslandLabelStyle: displaySettings.miuiIslandLabelStyle,
        miuiIslandLabelContent: displaySettings.miuiIslandLabelContent,
        miuiIslandLabelFontColor: displaySettings.miuiIslandLabelFontColor,
        miuiIslandLabelFontWeight: displaySettings.miuiIslandLabelFontWeight,
        miuiIslandLabelRenderQuality:
            displaySettings.miuiIslandLabelRenderQuality,
        miuiIslandLabelFontSize: displaySettings.miuiIslandLabelFontSize,
        miuiIslandLabelOffsetX: displaySettings.miuiIslandLabelOffsetX,
        miuiIslandLabelOffsetY: displaySettings.miuiIslandLabelOffsetY,
        miuiIslandLabelLogoPath: displaySettings.miuiIslandLabelLogoPath,
        miuiIslandLabelLogoCornerRadius:
            displaySettings.miuiIslandLabelLogoCornerRadius,
        miuiIslandExpandedIconMode: displaySettings.miuiIslandExpandedIconMode,
        miuiIslandExpandedIconPath: displaySettings.miuiIslandExpandedIconPath,
        beforeClassQuickAction: settings.liveBeforeClassQuickAction,
        progressBreakOffsetsMillis: progressBreakOffsetsMillis,
        progressMilestoneLabels: progressMilestones
            .map((milestone) => milestone['label'] as String)
            .toList(),
        progressMilestoneTimeTexts: progressMilestones
            .map((milestone) => milestone['timeText'] as String)
            .toList(),
      );
      _hasVisibleLiveUpdate = true;
    } else {
      if (_currentLiveCourseId != null || _hasVisibleLiveUpdate) {
        _currentLiveCourseId = null;
        await _liveActivitiesService.stopLiveUpdate();
        _hasVisibleLiveUpdate = false;
      }
    }
  }

  Future<void> _syncLiveScheduleSnapshot() async {
    final activeProfile = this.activeProfile;
    if (activeProfile == null || _courses.isEmpty) {
      if (_lastLiveSnapshotSignature != null) {
        final cleared = await _liveActivitiesService.clearScheduleSnapshot();
        if (cleared) {
          _lastLiveSnapshotSignature = null;
        }
      }
      return;
    }

    final displayCourses =
        _courses.map(resolveCourseDisplayName).toList(growable: false);
    final snapshotSignature = jsonEncode({
      'profileId': activeProfile.id,
      'currentWeek': _currentWeek,
      'semesterStartDate': _settings.semesterStartDate?.millisecondsSinceEpoch,
      'settings': _settings.toJson(),
      'courses': displayCourses.map((course) => course.toJson()).toList(),
    });
    if (_lastLiveSnapshotSignature == snapshotSignature) {
      return;
    }

    final synced = await _liveActivitiesService.syncScheduleSnapshot(
      courses: displayCourses,
      settings: _settings,
      currentWeek: _currentWeek,
      semesterStartDate: _settings.semesterStartDate,
      endReminderLeadMillis: _liveEndReminderWindow.inMilliseconds,
    );
    if (synced) {
      _lastLiveSnapshotSignature = snapshotSignature;
    }
  }

  Future<void> _syncHomeWidgetSnapshot() async {
    final now = DateTime.now();
    final snapshot = buildHomeWidgetSnapshot();
    if (snapshot == null) {
      if (_lastHomeWidgetSnapshotSignature != null) {
        final cleared = await _homeWidgetService.clearSnapshot();
        if (cleared) {
          _lastHomeWidgetSnapshotSignature = null;
        }
      }
      return;
    }

    final snapshotSignature = jsonEncode(snapshot.toJson());
    if (_lastHomeWidgetSnapshotSignature != snapshotSignature) {
      final synced = await _homeWidgetService.syncSnapshot(snapshot);
      if (synced) {
        _lastHomeWidgetSnapshotSignature = snapshotSignature;
      }
    }
    final triggerAtMillis = _homeWidgetSnapshotService.buildRefreshTriggers(
      todayCourses: getCoursesForDay(now.weekday, week: snapshot.currentWeek),
      now: now,
    );
    await _homeWidgetService.scheduleRefresh(triggerAtMillis);
  }

  void suspendLiveActivitySyncFor(Duration duration) {
    _liveActivitySuspendedUntil = DateTime.now().add(duration);
  }

  Future<void> refreshLiveActivityNow({
    bool forceSnapshotSync = false,
  }) async {
    await initialize();
    if (forceSnapshotSync) {
      _lastLiveSnapshotSignature = null;
    }
    _currentLiveCourseId = null;
    await _syncLiveScheduleSnapshot();
    await _updateLiveActivity(syncScheduleSnapshot: false);
  }

  void updateCurrentDayOfWeek() {
    unawaited(syncTemporalContext());
  }

  LiveActivityStage? _resolveLiveActivityStage({
    required DateTime currentTime,
    required DateTime startTime,
    required DateTime endTime,
    required DateTime aheadTime,
  }) {
    if (currentTime.isBefore(aheadTime) || !currentTime.isBefore(endTime)) {
      return null;
    }

    if (currentTime.isBefore(startTime)) {
      return _canDisplayStage(LiveActivityStage.beforeClass)
          ? LiveActivityStage.beforeClass
          : null;
    }

    final startMinutes = _settings.liveClassReminderStartMinutes;
    final reminderStartTime = startMinutes == 0
        ? startTime
        : endTime.subtract(Duration(minutes: startMinutes));

    if (currentTime.isBefore(reminderStartTime)) {
      if (startMinutes > 0 &&
          _canDisplayStage(LiveActivityStage.duringClassStatusBar)) {
        return LiveActivityStage.duringClassStatusBar;
      }
      return null;
    }

    if (startMinutes > 0) {
      if (_canDisplayStage(LiveActivityStage.beforeEnd)) {
        return LiveActivityStage.beforeEnd;
      }
      return _canDisplayStage(LiveActivityStage.duringClass)
          ? LiveActivityStage.duringClass
          : null;
    }

    final endReminderStart = _resolveEndReminderStart(startTime, endTime);
    if (!currentTime.isBefore(endReminderStart)) {
      if (_canDisplayStage(LiveActivityStage.beforeEnd)) {
        return LiveActivityStage.beforeEnd;
      }
      if (_canDisplayStage(LiveActivityStage.duringClass)) {
        return LiveActivityStage.duringClass;
      }
      return null;
    }

    return _canDisplayStage(LiveActivityStage.duringClass)
        ? LiveActivityStage.duringClass
        : null;
  }

  DateTime _resolveEndReminderStart(DateTime startTime, DateTime endTime) {
    final endReminderStart = endTime.subtract(_liveEndReminderWindow);
    return endReminderStart.isBefore(startTime) ? startTime : endReminderStart;
  }

  LiveActivityStage? _preferredTestStage() {
    if (_canDisplayStage(LiveActivityStage.beforeClass)) {
      return LiveActivityStage.beforeClass;
    }
    if (_canDisplayStage(LiveActivityStage.duringClass)) {
      return LiveActivityStage.duringClass;
    }
    if (_canDisplayStage(LiveActivityStage.beforeEnd)) {
      return LiveActivityStage.beforeEnd;
    }
    return null;
  }

  bool _canDisplayStage(LiveActivityStage stage) {
    switch (stage) {
      case LiveActivityStage.beforeClass:
        return _settings.liveEnableBeforeClass;
      case LiveActivityStage.duringClassStatusBar:
        return _settings.liveEnableDuringClass &&
            _settings.liveShowDuringClassNotification;
      case LiveActivityStage.duringClass:
        return _settings.liveEnableDuringClass &&
            (_settings.livePromoteDuringClass ||
                _settings.liveShowDuringClassNotification);
      case LiveActivityStage.beforeEnd:
        return _settings.liveEnableBeforeEnd;
    }
  }
}

@visibleForTesting
String buildImportedCourseDedupKey(Course course) {
  final weeks = [...course.activeWeeks]..sort();
  return [
    course.name.trim().toLowerCase(),
    course.teacher.trim().toLowerCase(),
    course.location.trim().toLowerCase(),
    course.dayOfWeek.toString(),
    course.startSection.toString(),
    course.endSection.toString(),
    weeks.join(','),
  ].join('|');
}

@visibleForTesting
List<Course> dedupeImportedCourses(
  List<Course> importedCourses, {
  List<Course> existingCourses = const [],
}) {
  final keys = existingCourses.map(buildImportedCourseDedupKey).toSet();
  final result = <Course>[];
  for (final course in importedCourses) {
    final key = buildImportedCourseDedupKey(course);
    if (keys.add(key)) {
      result.add(course);
    }
  }
  return result;
}

class ImportedCourseSyncResult {
  final List<Course> mergedCourses;
  final int addedCount;
  final int updatedCount;

  const ImportedCourseSyncResult({
    required this.mergedCourses,
    required this.addedCount,
    required this.updatedCount,
  });
}

@visibleForTesting
Course mergeImportedCourseWithExisting(Course existing, Course imported) {
  return imported.copyWith(
    id: existing.id,
    name: imported.name.trim().isEmpty ? existing.name : imported.name,
    teacher:
        imported.teacher.trim().isEmpty ? existing.teacher : imported.teacher,
    location: imported.location.trim().isEmpty
        ? existing.location
        : imported.location,
    shortName: existing.shortName,
    color: existing.color,
    courseNature: existing.courseNature,
    description: existing.description,
    note: existing.note,
    timeSchemeIdOverride: existing.timeSchemeIdOverride,
  );
}

@visibleForTesting
Course preserveImportedCourseLocalSharedFields(
  Course existing,
  Course imported,
) {
  return imported.copyWith(
    name: imported.name.trim().isEmpty ? existing.name : imported.name,
    teacher:
        imported.teacher.trim().isEmpty ? existing.teacher : imported.teacher,
    location: imported.location.trim().isEmpty
        ? existing.location
        : imported.location,
    shortName: existing.shortName,
    color: existing.color,
    courseNature: existing.courseNature,
    description: existing.description,
  );
}

@visibleForTesting
Course mergeImportedSharedFieldsIntoExistingSchedule(
  Course existing,
  Course imported,
) {
  return existing.copyWith(
    name: imported.name.trim().isEmpty ? existing.name : imported.name,
    teacher:
        imported.teacher.trim().isEmpty ? existing.teacher : imported.teacher,
    location: imported.location.trim().isEmpty
        ? existing.location
        : imported.location,
    shortName: existing.shortName,
    color: existing.color,
    courseNature: existing.courseNature,
    description: existing.description,
    note: existing.note,
    timeSchemeIdOverride: existing.timeSchemeIdOverride,
  );
}

@visibleForTesting
List<Course> replaceImportedCoursesPreservingLocalFields({
  required List<Course> existingCourses,
  required List<Course> importedCourses,
}) {
  final dedupedImported = dedupeImportedCourses(importedCourses);
  final existingSharedCoursesByName = <String, Course>{};
  for (final existing in existingCourses) {
    existingSharedCoursesByName.putIfAbsent(
      _buildSharedCourseNameKey(existing.name),
      () => existing,
    );
  }

  final matchedExistingIds = <String>{};
  final replacedCourses = <Course>[];

  for (final imported in dedupedImported) {
    var rebuilt = imported;
    final sharedExisting =
        existingSharedCoursesByName[_buildSharedCourseNameKey(imported.name)];
    if (sharedExisting != null) {
      rebuilt = preserveImportedCourseLocalSharedFields(
        sharedExisting,
        rebuilt,
      );
    }

    final groupedMatchIndices = _findGroupedImportedCourseMatchIndices(
      existingCourses,
      imported,
      matchedExistingIds,
    );
    if (groupedMatchIndices.isNotEmpty) {
      final existing = existingCourses[groupedMatchIndices.first];
      matchedExistingIds.addAll(
        groupedMatchIndices.map((index) => existingCourses[index].id),
      );
      rebuilt = mergeImportedCourseWithExisting(existing, rebuilt);
      replacedCourses.add(rebuilt);
      continue;
    }

    var matchedIndex = _findExactImportedCourseMatchIndex(
      existingCourses,
      imported,
      matchedExistingIds,
    );
    matchedIndex = matchedIndex != -1
        ? matchedIndex
        : _findSoftImportedCourseMatchIndex(
            existingCourses,
            imported,
            matchedExistingIds,
          );

    if (matchedIndex != -1) {
      final existing = existingCourses[matchedIndex];
      matchedExistingIds.add(existing.id);
      rebuilt = mergeImportedCourseWithExisting(existing, rebuilt);
    }

    replacedCourses.add(rebuilt);
  }

  return replacedCourses;
}

@visibleForTesting
ImportedCourseSyncResult syncImportedCourses({
  required List<Course> existingCourses,
  required List<Course> importedCourses,
}) {
  final dedupedImported = dedupeImportedCourses(importedCourses);
  final merged = List<Course>.from(existingCourses);
  final matchedExistingIds = <String>{};
  var addedCount = 0;
  var updatedCount = 0;

  for (final imported in dedupedImported) {
    final groupedMatchIndices = _findGroupedImportedCourseMatchIndices(
      merged,
      imported,
      matchedExistingIds,
    );
    if (groupedMatchIndices.isNotEmpty) {
      for (final index in groupedMatchIndices) {
        final existing = merged[index];
        matchedExistingIds.add(existing.id);
        merged[index] = mergeImportedSharedFieldsIntoExistingSchedule(
          existing,
          imported,
        );
        updatedCount += 1;
      }
      continue;
    }

    var matchedIndex = _findExactImportedCourseMatchIndex(
      merged,
      imported,
      matchedExistingIds,
    );
    matchedIndex = matchedIndex != -1
        ? matchedIndex
        : _findSoftImportedCourseMatchIndex(
            merged,
            imported,
            matchedExistingIds,
          );

    if (matchedIndex != -1) {
      final existing = merged[matchedIndex];
      matchedExistingIds.add(existing.id);
      merged[matchedIndex] =
          mergeImportedCourseWithExisting(existing, imported);
      updatedCount += 1;
    } else {
      merged.add(imported);
      addedCount += 1;
    }
  }

  return ImportedCourseSyncResult(
    mergedCourses: merged,
    addedCount: addedCount,
    updatedCount: updatedCount,
  );
}

bool _courseListsEqual(List<Course> left, List<Course> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index].toJsonString() != right[index].toJsonString()) {
      return false;
    }
  }
  return true;
}

String _buildSharedCourseNameKey(String name) => name.trim().toLowerCase();

int _findExactImportedCourseMatchIndex(
  List<Course> existingCourses,
  Course imported,
  Set<String> matchedExistingIds,
) {
  final importedKey = _buildImportedCourseExactMatchKey(imported);
  for (var index = 0; index < existingCourses.length; index++) {
    final existing = existingCourses[index];
    if (matchedExistingIds.contains(existing.id)) {
      continue;
    }
    if (_buildImportedCourseExactMatchKey(existing) == importedKey) {
      return index;
    }
  }
  return -1;
}

int _findSoftImportedCourseMatchIndex(
  List<Course> existingCourses,
  Course imported,
  Set<String> matchedExistingIds,
) {
  var bestIndex = -1;
  var bestScore = 0.0;
  for (var index = 0; index < existingCourses.length; index++) {
    final existing = existingCourses[index];
    if (matchedExistingIds.contains(existing.id)) {
      continue;
    }
    if (existing.name.trim().toLowerCase() !=
        imported.name.trim().toLowerCase()) {
      continue;
    }
    if (existing.sectionCount != imported.sectionCount) {
      continue;
    }
    final overlapScore =
        _weekOverlapScore(existing.activeWeeks, imported.activeWeeks);
    if (overlapScore < 0.5) {
      continue;
    }
    final teacherBonus = existing.teacher.trim().isNotEmpty &&
            imported.teacher.trim().isNotEmpty &&
            existing.teacher.trim().toLowerCase() ==
                imported.teacher.trim().toLowerCase()
        ? 0.2
        : 0.0;
    final locationBonus = existing.location.trim().isNotEmpty &&
            imported.location.trim().isNotEmpty &&
            existing.location.trim().toLowerCase() ==
                imported.location.trim().toLowerCase()
        ? 0.1
        : 0.0;
    final score = overlapScore + teacherBonus + locationBonus;
    if (score > bestScore) {
      bestScore = score;
      bestIndex = index;
    }
  }
  return bestIndex;
}

String _buildImportedCourseExactMatchKey(Course course) {
  final weeks = [...course.activeWeeks]..sort();
  return [
    course.name.trim().toLowerCase(),
    course.dayOfWeek.toString(),
    course.startSection.toString(),
    course.endSection.toString(),
    weeks.join(','),
  ].join('|');
}

List<int> _findGroupedImportedCourseMatchIndices(
  List<Course> existingCourses,
  Course imported,
  Set<String> matchedExistingIds,
) {
  final importedWeeks = {...imported.activeWeeks}
    ..removeWhere((week) => week < 1);
  if (importedWeeks.isEmpty) {
    return const <int>[];
  }
  final indices = <int>[];
  final coveredWeeks = <int>{};
  for (var index = 0; index < existingCourses.length; index++) {
    final existing = existingCourses[index];
    if (matchedExistingIds.contains(existing.id)) {
      continue;
    }
    if (!_hasSameStructuralKey(existing, imported)) {
      continue;
    }
    final existingWeeks = {...existing.activeWeeks}
      ..removeWhere((week) => week < 1);
    if (existingWeeks.isEmpty) {
      continue;
    }
    if (!importedWeeks.containsAll(existingWeeks)) {
      continue;
    }
    indices.add(index);
    coveredWeeks.addAll(existingWeeks);
  }
  if (indices.length <= 1) {
    return const <int>[];
  }
  if (coveredWeeks.length != importedWeeks.length ||
      !coveredWeeks.containsAll(importedWeeks)) {
    return const <int>[];
  }
  return indices;
}

bool _hasSameStructuralKey(Course left, Course right) {
  return left.name.trim().toLowerCase() == right.name.trim().toLowerCase() &&
      left.dayOfWeek == right.dayOfWeek &&
      left.startSection == right.startSection &&
      left.endSection == right.endSection;
}

double _weekOverlapScore(List<int> left, List<int> right) {
  if (left.isEmpty || right.isEmpty) {
    return 0;
  }
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  final intersection = leftSet.intersection(rightSet).length;
  final base =
      leftSet.length > rightSet.length ? leftSet.length : rightSet.length;
  return base == 0 ? 0 : intersection / base;
}
