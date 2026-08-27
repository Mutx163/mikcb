library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import '../l10n/service_message_localizer.dart';
import '../models/class_reminder.dart';
import '../models/course.dart';
import '../models/course_task.dart';
import '../models/exam.dart';
import '../models/holiday_entry.dart';
import '../models/location_time_group.dart';
import '../models/schedule_date_rule.dart';
import '../models/schedule_item.dart';
import '../models/time_scheme.dart';
import '../models/partner_timetable_binding.dart';
import '../models/timetable_profile.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable/couple_timetable_logic.dart';
import '../ui/hyperos_motion_bridge.dart';
import '../ui/hyperos/hyperos_overscroll.dart';
import '../services/app_analytics.dart';
import '../logging/app_debug_log.dart';
import '../logging/app_log_messages.dart';
import '../services/app_log_service.dart';
import '../services/data_transfer_service.dart';
import '../services/holiday_service.dart';
import '../services/home_widget_service.dart';
import '../services/home_widget_snapshot_service.dart';
import '../services/class_reminder_service.dart';
import '../services/exam_reminder_service.dart';
import '../services/partner_timetable_service.dart';
import '../services/stats_widget_service.dart';
import '../services/storage_service.dart';
import '../services/sync_operation_gate.dart';
import '../services/user_data_sync_hooks.dart';
import '../services/ics_import_service.dart';
import '../services/miui_live_activities_service.dart';
import '../utils/home_page_background.dart';
import 'timetable/location_time_match_logic.dart';
import 'timetable/schedule_date_rule_logic.dart';
import 'timetable/time_scheme_logic.dart';
import 'timetable/import_export_logic.dart';
import 'timetable/live_activity_logic.dart';

export 'timetable/location_time_match_logic.dart'
    show LocationTimeMatchResult, LocationTimeMatchLogic;
export 'timetable/schedule_date_rule_logic.dart'
    show
        ScheduleDateRuleLogic,
        ScheduleDateRuleApplyOutcome,
        ScheduleDateRuleApplyResult;
export 'timetable/time_scheme_logic.dart' show TimeSchemeCourseUsageReference;
export 'timetable/live_activity_logic.dart'
    show LiveActivityCourseSelection, LiveActivityStage;
export 'timetable/import_export_logic.dart'
    show
        ImportedCourseSyncResult,
        buildImportedCourseDedupKey,
        dedupeImportedCourses,
        mergeImportedCourseWithExisting,
        mergeImportedSharedFieldsIntoExistingSchedule,
        preserveImportedCourseLocalSharedFields,
        replaceImportedCoursesPreservingLocalFields,
        syncImportedCourses;

part 'timetable/time_scheme_repository.dart';
part 'timetable/import_export_service.dart';
part 'timetable/live_activity_controller.dart';

bool _isLiveTestingFixture(Course course) => course.id.startsWith('live_test_');

class CourseConflict {
  final Course course;
  final Course otherCourse;

  const CourseConflict({required this.course, required this.otherCourse});
}

/// Stats returned after applying location-time rules to the active profile.
class LocationTimeApplyStats {
  final int unlockedCount;
  final int matchedCount;
  final int updatedCount;

  /// Matched, but start/end clocks already equaled the target scheme.
  final int alreadySameClockCount;

  /// Location hit a group, but course section range cannot map into that
  /// scheme — synchronization is rejected (no mode or clock rewrite).
  final int sectionOverflowCount;

  /// First few course names rejected for section overflow (for toast).
  final List<String> sectionOverflowCourseNames;

  const LocationTimeApplyStats({
    required this.unlockedCount,
    required this.matchedCount,
    required this.updatedCount,
    this.alreadySameClockCount = 0,
    this.sectionOverflowCount = 0,
    this.sectionOverflowCourseNames = const [],
  });
}

/// Groups courses that share the same name (i.e. the same subject with
/// multiple schedule entries).  This is a UI-layer aggregation – the
/// underlying storage still uses individual [Course] objects.
class CourseGroup {
  final String name;
  final List<Course> courses;

  const CourseGroup({required this.name, required this.courses});

  /// Shared fields taken from the first course in the group.
  String get teacher => courses.first.teacher;
  String get color => courses.first.color;
  String? get shortName => courses.first.shortName;
  CourseNature get courseNature => courses.first.courseNature;
  String? get description => courses.first.description;
  String? get note => courses.first.note;

  /// Summarised schedule chips, e.g. ["周一1-2节", "周三3-4节"].
  List<String> scheduleChipLabels(AppLocalizations l10n) {
    return courses.map((c) {
      final dayLabel = _weekdayShortLabel(l10n, c.dayOfWeek);
      return l10n.weekdaySectionSummary(dayLabel, c.startSection, c.endSection);
    }).toList();
  }

  /// Earliest day/slot for sorting.
  int get earliestDayOfWeek =>
      courses.map((c) => c.dayOfWeek).reduce((a, b) => a < b ? a : b);
  int get earliestStartSection =>
      courses.map((c) => c.startSection).reduce((a, b) => a < b ? a : b);
}

String _weekdayShortLabel(AppLocalizations l10n, int dayOfWeek) {
  return switch (dayOfWeek) {
    1 => l10n.weekdayShortMonday,
    2 => l10n.weekdayShortTuesday,
    3 => l10n.weekdayShortWednesday,
    4 => l10n.weekdayShortThursday,
    5 => l10n.weekdayShortFriday,
    6 => l10n.weekdayShortSaturday,
    7 => l10n.weekdayShortSunday,
    _ => dayOfWeek.toString(),
  };
}

class ScheduleDateRuleSaveResult {
  final ScheduleDateRule rule;
  final ScheduleDateRuleApplyResult applyResult;

  const ScheduleDateRuleSaveResult({
    required this.rule,
    required this.applyResult,
  });

  bool get didApply => applyResult.didApply;
  bool get failedWhileDue => applyResult.failedWhileDue;
}

class TimetableProvider with ChangeNotifier {
  static const Duration _liveEndReminderWindow = Duration(minutes: 10);

  final StorageService _storageService;
  final IcsImportService _icsImportService;
  final MiuiLiveActivitiesService _liveActivitiesService;
  final DataTransferService _dataTransferService;
  final PartnerTimetableService _partnerTimetableService;
  final HomeWidgetService _homeWidgetService;
  final HomeWidgetSnapshotService _homeWidgetSnapshotService;
  final ExamReminderService _examReminderService;
  final HolidayService _holidayService;
  final AppAnalytics _analytics;
  final bool _enableLiveActivitySync;

  List<Course> _courses = [];
  List<CourseTask> _tasks = [];
  List<ScheduleItem> _scheduleItems = [];
  List<Exam> _exams = [];
  TimetableSettings _settings = TimetableSettings.defaults();
  int _currentWeek = 1;
  int _currentDateWeek = 1;

  // Calendar week used for today's courses; unlike currentDateWeek it is not
  // clamped to the configured semester length.
  int _currentCalendarWeek = 1;
  List<TimeScheme> _timeSchemes = [];
  List<LocationTimeGroup> _locationTimeGroups = [];
  List<ScheduleDateRule> _scheduleDateRules = [];
  List<TimetableProfile> _profiles = [];
  String? _activeProfileId;
  int _currentDayOfWeek = DateTime.now().weekday;
  bool _isLoading = false;
  Timer? _liveActivityTimer;
  String? _currentLiveCourseId;
  String? _lastLiveActivityStageKey;
  String? _lastLiveSnapshotSignature;
  String? _lastHomeWidgetSnapshotSignature;
  DateTime? _liveActivitySuspendedUntil;
  Future<void>? _initializationFuture;
  Future<void>? _deferredDataFuture;

  /// Serializes native live/home-widget surface updates (island + widget).
  final SyncOperationGate _liveSurfaceGate = SyncOperationGate();

  /// Serializes in-memory timetable mutations (courses/profiles/import/apply).
  final SyncOperationGate _mutationGate = SyncOperationGate();
  HolidayData? _holidayData;
  List<String> _teacherRecords = [];
  List<String> _locationRecords = [];
  PartnerTimetableBinding? _partnerBinding;

  List<Course> get courses => List.unmodifiable(_courses);
  List<CourseTask> get tasks => List.unmodifiable(_tasks);
  List<ScheduleItem> get scheduleItems => List.unmodifiable(_scheduleItems);
  List<Exam> get exams => List.unmodifiable(_exams);
  TimetableSettings get settings => _settings;

  // 主题撤销状态（仅保存主题相关字段，避免误回滚其他设置）
  ThemeConfig? _undoThemeConfig;
  String? _undoThemeName;
  Timer? _undoTimer;

  /// 持久化写入纪元，用于检测 write-after-write 竞争
  int _writeEpoch = 0;

  /// 是否有待撤销的主题变更
  bool get hasPendingUndo => _undoThemeConfig != null;

  /// 撤销主题名称
  String? get undoThemeName => _undoThemeName;

  /// 应用主题并保存撤销状态
  Future<void> applyThemeWithUndo(
    TimetableSettings newSettings, {
    String? themeName,
  }) async {
    _undoThemeConfig = ThemeConfig.fromSettings(_settings);
    _undoThemeName = themeName;
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 2), () {
      _undoThemeConfig = null;
      _undoThemeName = null;
      notifyListeners();
    });
    await updateSettings(newSettings);
  }

  /// 撤销主题变更
  Future<void> undoThemeChange() async {
    if (_undoThemeConfig == null) return;
    final restored = _undoThemeConfig!.applyToSettings(_settings);
    _undoThemeConfig = null;
    _undoThemeName = null;
    _undoTimer?.cancel();
    await updateSettings(restored);
  }

  /// 批量更新设置（用于主题导入）
  Future<void> updateSettings(TimetableSettings newSettings) {
    return _runMutation(() async {
      _settings = _normalizeSettingsWithTimeScheme(newSettings);
      hyperosSetEdgeHapticsEnabled(_settings.enableHaptics);
      _writeEpoch++;
      final epoch = _writeEpoch;
      await _persistActiveProfileState();
      if (_writeEpoch == epoch) {
        notifyListeners();
      }
    });
  }

  /// 保存主题
  Future<void> saveTheme(String name, Map<String, dynamic> themeData) {
    return _runMutation(() async {
      final theme = SavedTheme(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        config: ThemeConfig.fromJson(themeData),
        createdAt: DateTime.now(),
      );
      final updatedThemes = [..._settings.savedThemes, theme];
      _settings = _settings.copyWith(savedThemes: updatedThemes);
      await _persistActiveProfileState();
      notifyListeners();
    });
  }

  /// 删除主题
  Future<void> deleteTheme(String themeId) {
    return _runMutation(() async {
      final updatedThemes = _settings.savedThemes
          .where((theme) => theme.id != themeId)
          .toList();
      _settings = _settings.copyWith(savedThemes: updatedThemes);
      await _persistActiveProfileState();
      notifyListeners();
    });
  }

  /// 重命名主题
  Future<void> renameTheme(String themeId, String newName) {
    return _runMutation(() async {
      final updatedThemes = _settings.savedThemes.map((theme) {
        if (theme.id == themeId) {
          return SavedTheme(
            id: theme.id,
            name: newName,
            config: theme.config,
            createdAt: theme.createdAt,
          );
        }
        return theme;
      }).toList();
      _settings = _settings.copyWith(savedThemes: updatedThemes);
      await _persistActiveProfileState();
      notifyListeners();
    });
  }

  int get currentWeek => _currentWeek;
  int get currentDateWeek => _currentDateWeek;
  List<TimeScheme> get timeSchemes => List.unmodifiable(_timeSchemes);
  List<LocationTimeGroup> get locationTimeGroups =>
      List.unmodifiable(_locationTimeGroups);
  List<ScheduleDateRule> get scheduleDateRules =>
      List.unmodifiable(_scheduleDateRules);

  /// Last successful bulk-apply signature for seasonal date rules.
  String? _scheduleDateRuleLastAppliedSignature;
  List<TimetableProfile> get profiles => List.unmodifiable(_profiles);
  String? get activeProfileId => _activeProfileId;
  Map<String, List<Course>> get courseConflictMap => _buildCourseConflictMap();
  Map<String, List<Course>> courseConflictMapForWeek(int week) =>
      _buildCourseConflictMap(week: week);

  /// Courses grouped by name – each group represents one subject with
  /// one or more schedule entries.
  List<CourseGroup> get courseGroups {
    final Map<String, List<Course>> grouped = {};
    for (final course in _courses) {
      grouped.putIfAbsent(course.name, () => []).add(course);
    }
    return grouped.entries
        .map((e) => CourseGroup(name: e.key, courses: e.value))
        .toList();
  }

  /// Find the [CourseGroup] that contains [course], or `null` if not found.
  CourseGroup? courseGroupForCourse(Course course) {
    final siblings = _courses.where((c) => c.name == course.name).toList();
    if (siblings.isEmpty) return null;
    return CourseGroup(name: course.name, courses: siblings);
  }

  /// All unique non-empty teacher names (persistent records + current courses), sorted.
  List<String> get uniqueTeachers {
    final all = <String>{..._teacherRecords};
    for (final c in _courses) {
      if (c.teacher.isNotEmpty) all.add(c.teacher);
    }
    return all.toList()..sort();
  }

  /// All unique non-empty location names (persistent records + current courses), sorted.
  List<String> get uniqueLocations {
    final all = <String>{..._locationRecords};
    for (final c in _courses) {
      if (c.location.isNotEmpty) all.add(c.location);
    }
    return all.toList()..sort();
  }

  /// Record a teacher name persistently (if not already recorded).
  Future<void> recordTeacher(String teacher) {
    return _runMutation(() => _recordTeacherImpl(teacher));
  }

  Future<void> _recordTeacherImpl(String teacher) async {
    if (teacher.isEmpty) return;
    if (_teacherRecords.contains(teacher)) return;
    _teacherRecords.add(teacher);
    _teacherRecords.sort();
    await _storageService.saveTeacherRecords(_teacherRecords);
    notifyUserDataChangedForSync();
  }

  /// Record a location name persistently (if not already recorded).
  Future<void> recordLocation(String location) {
    return _runMutation(() => _recordLocationImpl(location));
  }

  Future<void> _recordLocationImpl(String location) async {
    if (location.isEmpty) return;
    if (_locationRecords.contains(location)) return;
    _locationRecords.add(location);
    _locationRecords.sort();
    await _storageService.saveLocationRecords(_locationRecords);
    notifyUserDataChangedForSync();
  }

  int get currentDayOfWeek => _currentDayOfWeek;
  bool get isLoading => _isLoading;
  DateTime? get semesterStartDate => _settings.semesterStartDate;
  DataTransferService get dataTransferService => _dataTransferService;
  PartnerTimetableBinding? get partnerBinding => _partnerBinding;
  bool get hasPartnerBinding => _partnerBinding != null;
  int get partnerWeekOffset => _partnerBinding?.weekOffset ?? 0;
  int partnerWeekFor(int myWeek) =>
      CoupleTimetableLogic.partnerWeekForMyWeek(myWeek, partnerWeekOffset);

  String coupleColorForKind(CoupleCourseKind kind) {
    final binding = _partnerBinding;
    return CoupleTimetableLogic.colorHexForKind(
      kind,
      mineColorHex: binding?.mineColorHex,
      partnerColorHex: binding?.partnerColorHex,
      togetherColorHex: binding?.togetherColorHex,
    );
  }

  TimetableProfile? get partnerProfile =>
      _getProfileById(PartnerTimetableService.partnerProfileId);
  List<Course> get partnerCourses =>
      partnerProfile?.courses ?? const <Course>[];
  TimetableProfile? get activeProfile {
    final profile = _getProfileById(_activeProfileId);
    if (profile != null && !profile.isPartnerImported) {
      return profile;
    }
    for (final candidate in _profiles) {
      if (!candidate.isPartnerImported) {
        return candidate;
      }
    }
    return null;
  }

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
    PartnerTimetableService? partnerTimetableService,
    HomeWidgetService? homeWidgetService,
    HomeWidgetSnapshotService? homeWidgetSnapshotService,
    ExamReminderService? examReminderService,
    HolidayService? holidayService,
    AppAnalytics? analytics,
    bool autoInitialize = true,
    bool enableLiveActivitySync = true,
  }) : _storageService = storageService ?? StorageService(),
       _icsImportService = icsImportService ?? IcsImportService(),
       _liveActivitiesService =
           liveActivitiesService ?? MiuiLiveActivitiesService(),
       _dataTransferService = dataTransferService ?? DataTransferService(),
       _partnerTimetableService =
           partnerTimetableService ?? PartnerTimetableService(),
       _homeWidgetService = homeWidgetService ?? HomeWidgetService(),
       _homeWidgetSnapshotService =
           homeWidgetSnapshotService ?? const HomeWidgetSnapshotService(),
       _examReminderService = examReminderService ?? ExamReminderService(),
       _holidayService = holidayService ?? HolidayService(),
       _analytics = analytics ?? AppAnalytics.instance,
       _enableLiveActivitySync = enableLiveActivitySync {
    _holidayService.onRemoteHolidayDataUpdated = (_) {
      unawaited(_loadHolidayData());
    };
    if (autoInitialize) {
      unawaited(initialize());
    }
  }

  Future<void> initialize() {
    final existingInitialization = _initializationFuture;
    if (existingInitialization != null) {
      return existingInitialization;
    }

    final initializationCompleter = Completer<void>();
    final initializationFuture = initializationCompleter.future;
    _initializationFuture = initializationFuture;

    _init().then(
      (_) => initializationCompleter.complete(),
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_initializationFuture, initializationFuture)) {
          _initializationFuture = null;
        }
        initializationCompleter.completeError(error, stackTrace);
      },
    );
    return initializationFuture;
  }

  Future<void> handleAppResumed() async {
    try {
      await initialize();
      if (!_enableLiveActivitySync) {
        return;
      }
      await _liveHandleAppResumed(this);
    } catch (error, stackTrace) {
      await AppLogService.instance.error(
        'live_activity_resume_recovery_failed',
        '应用恢复时修复超级岛状态失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Re-read profiles/binding/teachers after an external snapshot apply (C4).
  ///
  /// [initialize] is process-idempotent; cloud restore must force a full load.
  Future<void> reloadFromStorageAfterExternalApply() {
    return _runMutation(() async {
      // Join any in-flight init before resetting the future, so two _init()
      // bodies cannot interleave memory writes.
      final existingInitialization = _initializationFuture;
      if (existingInitialization != null) {
        try {
          await existingInitialization;
        } catch (_) {
          // Previous attempt failed; continue with a forced reload.
        }
      }
      _initializationFuture = null;
      await initialize();
      // This method already holds the mutation gate. Load directly so it does
      // not enqueue behind itself and deadlock.
      await _loadDeferredDataImpl();
      // importFullAppDataBackup may have pushed live surfaces before teachers /
      // locations were reloaded; force one consistent resync after storage load.
      await _runLiveSurfaceExclusive(() async {
        _lastLiveSnapshotSignature = null;
        _lastHomeWidgetSnapshotSignature = null;
        _currentLiveCourseId = null;
        await _liveUpdateActivityBody(this);
      });
      await _syncExamReminders();
      notifyListeners();
    });
  }

  Future<T> _runLiveSurfaceExclusive<T>(Future<T> Function() action) {
    return _liveSurfaceGate.runExclusive(action);
  }

  /// Public entry for external apply paths (WebDAV) that must share the
  /// timetable mutation gate with local / LAN writes.
  Future<T> runMutationExclusive<T>(Future<T> Function() action) {
    return _runMutation(action);
  }

  Future<T> _runMutation<T>(Future<T> Function() action) {
    return _mutationGate.runExclusive(action);
  }

  /// Merges in-memory active courses/settings into [_profiles] without disk I/O.
  void _mergeActiveProfileIntoProfilesList({bool touchLastUsedAt = false}) {
    final activeProfile = this.activeProfile;
    if (activeProfile == null) {
      return;
    }
    final index = _profiles.indexWhere(
      (profile) => profile.id == activeProfile.id,
    );
    if (index == -1) {
      return;
    }
    _profiles[index] = activeProfile.copyWith(
      courses: List<Course>.from(_courses),
      tasks: List<CourseTask>.from(_tasks),
      scheduleItems: List<ScheduleItem>.from(_scheduleItems),
      exams: List<Exam>.from(_exams),
      settings: _settings,
      currentWeek: _currentWeek,
      lastUsedAt: touchLastUsedAt ? DateTime.now() : activeProfile.lastUsedAt,
    );
  }

  Future<void> _init() async {
    await _storageService.init();

    // Profiles and time schemes both run ensure* migrations that may write
    // under the same profiles write chain — load sequentially to avoid
    // re-entrant wait deadlocks under Future.wait.
    final profiles = await _storageService.getProfiles();
    final timeSchemes = await _storageService.getTimeSchemes();
    final locationTimeGroups = await _storageService.getLocationTimeGroups();
    final scheduleDateRules = await _storageService.getScheduleDateRules();
    final activeProfileId = await _storageService.getActiveProfileId();
    final partnerBinding = await _storageService.getPartnerTimetableBinding();
    final lastAppliedSignature = await _storageService
        .getScheduleDateRuleLastAppliedSignature();

    _profiles = profiles;
    _timeSchemes = timeSchemes;
    _locationTimeGroups = locationTimeGroups;
    _scheduleDateRules = scheduleDateRules;
    _activeProfileId = activeProfileId;
    _partnerBinding = partnerBinding;
    _scheduleDateRuleLastAppliedSignature = lastAppliedSignature;

    if (_activeProfileId != null) {
      final storedActive = _getProfileById(_activeProfileId);
      if (storedActive?.isPartnerImported == true) {
        final fallback = _profiles
            .where((profile) => !profile.isPartnerImported)
            .firstOrNull;
        _activeProfileId = fallback?.id;
      }
    }

    // --- 非关键数据：后台加载，不阻塞首帧 ---
    unawaited(_loadDeferredData());

    final activeProfile =
        this.activeProfile ?? (_profiles.isEmpty ? null : _profiles.first);
    if (activeProfile == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    _applyProfileState(activeProfile);

    // Existing per-session homework marks become actionable once, while the
    // original course note remains the source of truth for the badge.
    await _syncHomeworkTasksWithCourses(persist: true);

    // 壁纸预加载不阻塞首帧；无壁纸时此调用会立即返回。
    unawaited(precacheHomePageBackdropImage(_settings));

    // --- 迁移逻辑：不阻塞首帧，后台完成 ---
    unawaited(_runAppLogsMigrationIfNeeded(activeProfile));

    if (_activeProfileId != activeProfile.id) {
      _activeProfileId = activeProfile.id;
      unawaited(_storageService.setActiveProfileId(activeProfile.id));
    }
    if (_settings.semesterStartDate != null) {
      unawaited(syncCurrentWeekWithSemesterStart());
    }

    // --- 首帧已可渲染，立即通知 ---
    notifyListeners();

    // Seasonal bulk-apply may rewrite default scheme/clocks after first paint.
    unawaited(applyDueScheduleDateRules());

    // Holiday must finish before the first live/widget push so cold start on a
    // holiday day does not briefly publish courses (empty holidayData ⇒ false).
    unawaited(_bootstrapHolidayAwareSurfaces());
  }

  /// Load holidays first, then push widget/island once with correct semantics.
  Future<void> _bootstrapHolidayAwareSurfaces() async {
    unawaited(_syncNativeRuntimePreferences());
    await _loadHolidayData();
    // _loadHolidayData already re-pushes surfaces on success. If it failed
    // silently, still push once so widgets are not stuck empty forever.
    if (_lastHomeWidgetSnapshotSignature == null) {
      await _syncHomeWidgetSnapshot();
    }
    unawaited(_syncExamReminders());
    if (_enableLiveActivitySync) {
      _startLiveActivityTick();
    }
  }

  /// 后台加载非关键数据：教师/地点记录。
  ///
  /// This load is placed on the same mutation gate as recordTeacher/Location.
  /// Otherwise a stale read started before the first frame could overwrite a
  /// record written by the user while the read was in flight.
  Future<void> _loadDeferredData() {
    final existing = _deferredDataFuture;
    if (existing != null) {
      return existing;
    }
    final future = _runMutation(_loadDeferredDataImpl);
    _deferredDataFuture = future;
    return future.whenComplete(() {
      if (identical(_deferredDataFuture, future)) {
        _deferredDataFuture = null;
      }
    });
  }

  Future<void> _loadDeferredDataImpl() async {
    final teacherFuture = _storageService.getTeacherRecords();
    final locationFuture = _storageService.getLocationRecords();
    final results = await Future.wait<List<String>>([
      teacherFuture,
      locationFuture,
    ]);
    final loadedTeachers = List<String>.from(results[0]);
    final loadedLocations = List<String>.from(results[1]);
    final nextTeachers = <String>{...loadedTeachers, ..._teacherRecords}.toList()..sort();
    final nextLocations = <String>{...loadedLocations, ..._locationRecords}.toList()..sort();
    final teachersChanged = !listEquals(_teacherRecords, nextTeachers);
    final locationsChanged = !listEquals(_locationRecords, nextLocations);
    _teacherRecords = nextTeachers;
    _locationRecords = nextLocations;
    if (teachersChanged || locationsChanged) {
      notifyListeners();
    }
  }

  /// 后台执行 app logs 迁移，不阻塞首帧
  Future<void> _runAppLogsMigrationIfNeeded(
    TimetableProfile activeProfile,
  ) async {
    final didMigrateAppLogsDefault = await _storageService
        .hasMigratedAppLogsDefault();
    if (!didMigrateAppLogsDefault && !_settings.liveEnableLocalDiagnostics) {
      _settings = _settings.copyWith(liveEnableLocalDiagnostics: true);
      await _persistActiveProfileState();
      await _storageService.setMigratedAppLogsDefault(true);
      await AppLogService.instance.updateLoggingEnabled(true);
      unawaited(
        AppLogService.instance.info(
          'app_logs_default_migrated',
          AppLogMessages.appLogsDefaultMigrated,
          extras: {'profileId': activeProfile.id},
        ),
      );
    } else if (!didMigrateAppLogsDefault) {
      await _storageService.setMigratedAppLogsDefault(true);
    }
  }

  void _startLiveActivityTick() => _liveStartActivityTick(this);

  @visibleForTesting
  void seedLiveActivityTrackingForTesting({
    String? lastStageKey,
    String? currentCourseId,
  }) => _liveSeedTrackingForTesting(
    this,
    lastStageKey: lastStageKey,
    currentCourseId: currentCourseId,
  );

  @visibleForTesting
  void checkLiveActivityStageTransitionForTesting() =>
      _liveCheckActivityStageTransition(this);

  @visibleForTesting
  Future<void> updateLiveActivityForTesting({
    bool syncScheduleSnapshot = true,
  }) => _liveUpdateActivityForTesting(
    this,
    syncScheduleSnapshot: syncScheduleSnapshot,
  );

  @override
  void dispose() {
    _holidayService.onRemoteHolidayDataUpdated = null;
    _liveActivityTimer?.cancel();
    _undoTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateLiveActivity({bool syncScheduleSnapshot = true}) =>
      _liveUpdateActivity(this, syncScheduleSnapshot: syncScheduleSnapshot);

  Future<void> _syncLiveScheduleSnapshot() => _liveSyncScheduleSnapshot(this);

  Future<void> _syncHomeWidgetSnapshot() => _liveSyncHomeWidgetSnapshot(this);

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

  TimeScheme? _getTimeSchemeById(String? schemeId) =>
      TimeSchemeLogic.getSchemeById(_timeSchemes, schemeId);

  void _applyProfileState(TimetableProfile profile) {
    _settings = _normalizeSettingsWithTimeScheme(profile.settings);
    hyperosSetEdgeHapticsEnabled(_settings.enableHaptics);
    _courses = _syncCoursesWithEffectiveTimeSchemes(
      List<Course>.from(profile.courses),
      settings: _settings,
    );
    _scheduleItems = _sortScheduleItems(
      List<ScheduleItem>.from(profile.scheduleItems),
    );
    _tasks = _sortTasks(List<CourseTask>.from(profile.tasks));
    _exams = List<Exam>.from(profile.exams);
    _currentWeek = clampCurrentWeekToSettings(profile.currentWeek, _settings);
    _currentCalendarWeek = _resolveCurrentCalendarWeek();
    _currentDateWeek = clampCurrentWeekToSettings(
      _currentCalendarWeek,
      _settings,
    );
    unawaited(_syncNativeRuntimePreferences());
  }

  Future<void> _syncNativeRuntimePreferences() async {
    applyHyperosUserTransitionSpeed(_settings.pageTransitionSpeed);
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
    TimetableSettings settings,
  ) {
    final scheme = _getTimeSchemeById(settings.activeTimeSchemeId);
    if (scheme == null) {
      return settings;
    }
    final hasSameSections =
        _sectionSignature(settings.sections) ==
        _sectionSignature(scheme.sections);
    if (hasSameSections) {
      return settings;
    }
    return settings.copyWith(
      sections: List<SectionTime>.from(scheme.sections),
      activeTimeSchemeId: scheme.id,
    );
  }

  List<Course> _syncCoursesWithEffectiveTimeSchemes(
    List<Course> source, {
    TimetableSettings? settings,
  }) {
    return source
        .map(
          (course) =>
              _syncCourseWithEffectiveTimeScheme(course, settings: settings),
        )
        .toList();
  }

  Course _syncCourseWithEffectiveTimeScheme(
    Course course, {
    TimetableSettings? settings,
    DateTime? onDate,
    bool debugTrace = false,
    String debugTag = 'LocationTimeApply',
  }) {
    final resolvedScheme = debugTrace
        ? resolveCourseTimeScheme(course, settings: settings, onDate: onDate)
        : null;
    final sections = _resolveSectionsForCourse(
      course,
      settings: settings,
      onDate: onDate,
    );
    final startIndex = course.startSection - 1;
    final endIndex = course.endSection - 1;
    if (sections == null || startIndex < 0 || endIndex >= sections.length) {
      if (debugTrace) {
        appDebugLog(
          debugTag,
          '跳过改写(节次越界/无sections): course=${course.name} '
          'loc=${course.location} sections=${course.startSection}-${course.endSection} '
          'scheme=${resolvedScheme?.name ?? "null"} '
          'schemeSectionCount=${resolvedScheme?.sections.length ?? sections?.length ?? 0} '
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

  /// Resolves the effective time scheme for a course.
  ///
  /// Priority: manual override → location group → date rule for [onDate] →
  /// active profile scheme.
  ///
  /// **Persist / list resync must not pass [onDate].** Date rules are day-
  /// scoped; baking "today" into [Course.startTime]/[Course.endTime] corrupts
  /// the whole timetable. Pass [onDate] only for runtime preview (live island,
  /// day view, validation that intentionally cares about a calendar day).
  TimeScheme? resolveCourseTimeScheme(
    Course course, {
    TimetableSettings? settings,
    DateTime? onDate,
  }) => TimeSchemeLogic.resolveCourseTimeScheme(
    _timeSchemes,
    _settings,
    course,
    settingsOverride: settings,
    locationTimeGroups: _locationTimeGroups,
    scheduleDateRules: _scheduleDateRules,
    onDate: onDate,
  );

  /// 上课闹钟等场景用：解析课程在其生效时间模板下的真实开始钟点。
  ///
  /// 与 LiveActivityLogic.resolveRealTime 同一套节次语义；当课程的开始节次
  /// 超出模板节数（例如导入产生的幻影节次）时返回 null，调用方应跳过该课程，
  /// 绝不能退回 Course.startTime 存量值（可能是不再同步的旧钟点或占位 00:00）。
  String? resolvedCourseStartTime(Course course) {
    final sections = _resolveSectionsForCourse(course);
    final index = course.startSection - 1;
    if (sections == null || index < 0 || index >= sections.length) {
      return null;
    }
    return sections[index].startTime;
  }

  /// Preview location → place-group routing without writing course times.
  LocationTimeMatchResult? matchLocationTime(String? location) =>
      LocationTimeMatchLogic.match(location, _locationTimeGroups);

  /// Preview which date rule applies on [date] (null = none).
  ScheduleDateRule? matchScheduleDateRule(DateTime date) =>
      ScheduleDateRuleLogic.match(date, _scheduleDateRules);

  /// Signature of the last date-rule bulk apply, used to explain save results
  /// without exposing the provider's mutable internal state.
  String? get scheduleDateRuleLastAppliedSignature =>
      _scheduleDateRuleLastAppliedSignature;

  List<SectionTime>? _resolveSectionsForCourse(
    Course course, {
    TimetableSettings? settings,
    DateTime? onDate,
  }) {
    final scheme = resolveCourseTimeScheme(
      course,
      settings: settings,
      onDate: onDate,
    );
    if (scheme != null) {
      return scheme.sections;
    }
    final activeSettings = settings ?? _settings;
    return activeSettings.sections;
  }

  List<TimeSchemeCourseUsageReference> getTimeSchemeCourseUsages(
    String schemeId, {
    List<TimetableProfile>? profiles,
  }) => TimeSchemeLogic.getCourseUsages(
    _profiles,
    schemeId,
    profilesOverride: profiles,
    schemes: _timeSchemes,
    locationTimeGroups: _locationTimeGroups,
  );

  int maxUsedSectionForTimeScheme(
    String schemeId, {
    List<TimetableProfile>? profiles,
  }) => TimeSchemeLogic.maxUsedSection(
    _profiles,
    schemeId,
    profilesOverride: profiles,
    schemes: _timeSchemes,
    locationTimeGroups: _locationTimeGroups,
  );

  TimeSchemeCourseUsageReference? maxSectionUsageForTimeScheme(
    String schemeId, {
    List<TimetableProfile>? profiles,
  }) => TimeSchemeLogic.maxSectionUsage(
    _profiles,
    schemeId,
    profilesOverride: profiles,
    schemes: _timeSchemes,
    locationTimeGroups: _locationTimeGroups,
  );

  String? validateCourseTimeSchemeOverride({
    String? timeSchemeId,
    required int startSection,
    required int endSection,
    String? location,
  }) => TimeSchemeLogic.validateCourseTimeSchemeOverride(
    schemes: _timeSchemes,
    settings: _settings,
    timeSchemeId: timeSchemeId,
    startSection: startSection,
    endSection: endSection,
    location: location,
    locationTimeGroups: _locationTimeGroups,
    scheduleDateRules: _scheduleDateRules,
    // No onDate: save/sync validation matches persisted clocks (override /
    // location / active), not today's date-rule scheme.
  );

  Future<void> _persistActiveProfileState({
    bool touchLastUsedAt = false,
    bool notifySync = true,
  }) async {
    _mergeActiveProfileIntoProfilesList(touchLastUsedAt: touchLastUsedAt);
    if (activeProfile == null) {
      return;
    }
    await _storageService.saveProfiles(_profiles);
    if (_activeProfileId != null) {
      await _storageService.setActiveProfileId(_activeProfileId!);
    }
    if (notifySync) {
      notifyUserDataChangedForSync();
    }
  }

  Future<void> _persistTimeSchemes() async {
    await _storageService.saveTimeSchemes(_timeSchemes);
    notifyUserDataChangedForSync();
  }

  Future<void> _persistLocationTimeGroups() async {
    await _storageService.saveLocationTimeGroups(_locationTimeGroups);
    notifyUserDataChangedForSync();
  }

  /// Re-sync course clock times for every profile after location rules change.
  Future<void> _resyncAllProfilesWithLocationRules({bool notify = true}) async {
    for (var index = 0; index < _profiles.length; index++) {
      final profile = _profiles[index];
      final syncedCourses = _syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(profile.courses),
        settings: profile.settings,
      );
      _profiles[index] = profile.copyWith(courses: syncedCourses);
    }

    final activeIndex = _profiles.indexWhere(
      (profile) => profile.id == _activeProfileId,
    );
    if (activeIndex != -1) {
      _courses = List<Course>.from(_profiles[activeIndex].courses);
      _settings = _profiles[activeIndex].settings;
    }

    await _storageService.saveProfiles(_profiles);
    notifyUserDataChangedForSync();
    _currentLiveCourseId = null;
    if (notify) {
      _notifyStateChanged();
    }
    await _updateLiveActivity();
  }

  Future<LocationTimeGroup> createLocationTimeGroup({
    required String name,
    required String timeSchemeId,
    List<LocationKeyword> keywords = const [],
    bool enabled = true,
    int priority = 0,
  }) async {
    await initialize();
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('location_time_group_name_required');
    }
    if (_getTimeSchemeById(timeSchemeId) == null) {
      throw ArgumentError('time_scheme_not_found');
    }

    final group = LocationTimeGroup(
      id: const Uuid().v4(),
      name: trimmedName,
      timeSchemeId: timeSchemeId,
      enabled: enabled,
      priority: priority,
      keywords: List<LocationKeyword>.from(keywords),
    );
    _locationTimeGroups = [..._locationTimeGroups, group];
    await _persistLocationTimeGroups();
    await _resyncAllProfilesWithLocationRules();
    return group;
  }

  Future<LocationTimeGroup?> updateLocationTimeGroup(
    LocationTimeGroup group,
  ) async {
    await initialize();
    final index = _locationTimeGroups.indexWhere((item) => item.id == group.id);
    if (index == -1) {
      return null;
    }
    final trimmedName = group.name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('location_time_group_name_required');
    }
    if (_getTimeSchemeById(group.timeSchemeId) == null) {
      throw ArgumentError('time_scheme_not_found');
    }

    final updated = group.copyWith(
      name: trimmedName,
      keywords: List<LocationKeyword>.from(group.keywords),
    );
    final next = List<LocationTimeGroup>.from(_locationTimeGroups);
    next[index] = updated;
    _locationTimeGroups = next;
    await _persistLocationTimeGroups();
    await _resyncAllProfilesWithLocationRules();
    return updated;
  }

  Future<bool> deleteLocationTimeGroup(String groupId) async {
    await initialize();
    final beforeCount = _locationTimeGroups.length;
    _locationTimeGroups = _locationTimeGroups
        .where((group) => group.id != groupId)
        .toList();
    if (_locationTimeGroups.length == beforeCount) {
      return false;
    }
    await _persistLocationTimeGroups();
    await _resyncAllProfilesWithLocationRules();
    return true;
  }

  Future<void> replaceLocationTimeGroups(
    List<LocationTimeGroup> groups, {
    bool resync = true,
  }) async {
    await initialize();
    _locationTimeGroups = List<LocationTimeGroup>.from(groups);
    await _persistLocationTimeGroups();
    if (resync) {
      await _resyncAllProfilesWithLocationRules();
    } else {
      _notifyStateChanged();
    }
  }

  Future<void> _persistScheduleDateRules() async {
    await _storageService.saveScheduleDateRules(_scheduleDateRules);
    notifyUserDataChangedForSync();
  }

  /// Create a date-range rule that switches the default time scheme.
  ///
  /// Product cap: [ScheduleDateRuleLogic.maxRulesPerDevice] rules total.
  Future<ScheduleDateRuleSaveResult> createScheduleDateRule({
    required String name,
    required String timeSchemeId,
    required String startDate,
    required String endDate,
    bool enabled = true,
  }) {
    return _runMutation(() async {
      await initialize();
      if (_scheduleDateRules.length >=
          ScheduleDateRuleLogic.maxRulesPerDevice) {
        throw ArgumentError('schedule_date_rule_max_exceeded');
      }
      if (_getTimeSchemeById(timeSchemeId) == null) {
        throw ArgumentError('time_scheme_not_found');
      }

      final rule = ScheduleDateRule(
        id: const Uuid().v4(),
        name: name.trim(),
        timeSchemeId: timeSchemeId,
        startDate: startDate.trim(),
        endDate: endDate.trim(),
        enabled: enabled,
      );
      final next = [..._scheduleDateRules, rule];
      final validationError = ScheduleDateRuleLogic.validateRules(next);
      if (validationError != null) {
        throw ArgumentError(validationError);
      }

      _scheduleDateRules = next;
      await _persistScheduleDateRules();
      // Nested under the same mutation gate (re-entrant).
      final applyResult = await applyDueScheduleDateRulesDetailed();
      if (!applyResult.didApply) {
        _notifyStateChanged();
      }
      return ScheduleDateRuleSaveResult(rule: rule, applyResult: applyResult);
    });
  }

  Future<ScheduleDateRuleSaveResult?> updateScheduleDateRule(
    ScheduleDateRule rule,
  ) {
    return _runMutation(() async {
      await initialize();
      final index = _scheduleDateRules.indexWhere((item) => item.id == rule.id);
      if (index == -1) {
        return null;
      }
      if (_getTimeSchemeById(rule.timeSchemeId) == null) {
        throw ArgumentError('time_scheme_not_found');
      }

      final updated = rule.copyWith(
        name: rule.name.trim(),
        startDate: rule.startDate.trim(),
        endDate: rule.endDate.trim(),
      );
      final next = List<ScheduleDateRule>.from(_scheduleDateRules);
      next[index] = updated;
      final validationError = ScheduleDateRuleLogic.validateRules(next);
      if (validationError != null) {
        throw ArgumentError(validationError);
      }

      _scheduleDateRules = next;
      await _persistScheduleDateRules();
      final applyResult = await applyDueScheduleDateRulesDetailed();
      if (!applyResult.didApply) {
        _notifyStateChanged();
      }
      return ScheduleDateRuleSaveResult(
        rule: updated,
        applyResult: applyResult,
      );
    });
  }

  Future<bool> deleteScheduleDateRule(String ruleId) {
    return _runMutation(() async {
      await initialize();
      final beforeCount = _scheduleDateRules.length;
      _scheduleDateRules = _scheduleDateRules
          .where((rule) => rule.id != ruleId)
          .toList();
      if (_scheduleDateRules.length == beforeCount) {
        return false;
      }
      await _persistScheduleDateRules();
      _notifyStateChanged();
      return true;
    });
  }

  Future<void> replaceScheduleDateRules(
    List<ScheduleDateRule> rules, {
    bool resync = true,
  }) {
    return _runMutation(() async {
      await initialize();
      final next = List<ScheduleDateRule>.from(rules);
      if (next.length > ScheduleDateRuleLogic.maxRulesPerDevice) {
        throw ArgumentError('schedule_date_rule_max_exceeded');
      }
      final validationError = ScheduleDateRuleLogic.validateRules(next);
      if (validationError != null) {
        throw ArgumentError(validationError);
      }
      _scheduleDateRules = next;
      await _persistScheduleDateRules();
      if (resync) {
        final didApply = await applyDueScheduleDateRules();
        if (!didApply) {
          _notifyStateChanged();
        }
      } else {
        _notifyStateChanged();
      }
    });
  }

  /// One-shot bulk apply of the seasonal date rule that matches [now].
  ///
  /// Product rules:
  /// 1. Same as tapping「应用时间模板」on the matched scheme (all profiles get
  ///    that default; unlocked clocks rewrite).
  /// 2. Runs on the first open at/after the rule start while still in range.
  /// 3. Does not re-run daily once applied, so manual course edits stick.
  Future<bool> applyDueScheduleDateRules({DateTime? now}) {
    return _runMutation(() => _applyDueScheduleDateRules(now: now));
  }

  /// Variant that returns structured outcome instead of plain bool, so callers
  /// (e.g. date-rule editor) can show specific failure feedback (B3).
  Future<ScheduleDateRuleApplyResult> applyDueScheduleDateRulesDetailed({
    DateTime? now,
  }) {
    return _runMutation(() => _applyDueScheduleDateRulesDetailed(now: now));
  }

  /// Bool facade kept for existing callers; always delegates to the detailed
  /// path so failure logging and apply side effects cannot drift.
  Future<bool> _applyDueScheduleDateRules({DateTime? now}) async {
    final applyResult = await _applyDueScheduleDateRulesDetailed(now: now);
    return applyResult.didApply;
  }

  /// Single implementation of seasonal bulk-apply. Returns structured outcome
  /// for UI toasts; [applyDueScheduleDateRules] maps [didApply] to bool.
  Future<ScheduleDateRuleApplyResult> _applyDueScheduleDateRulesDetailed({
    DateTime? now,
  }) async {
    await initialize();
    final reference = now ?? DateTime.now();
    final matched = ScheduleDateRuleLogic.match(reference, _scheduleDateRules);
    if (!ScheduleDateRuleLogic.shouldBulkApply(
      matchedRule: matched,
      lastAppliedSignature: _scheduleDateRuleLastAppliedSignature,
    )) {
      return const ScheduleDateRuleApplyResult(
        outcome: ScheduleDateRuleApplyOutcome.notDue,
      );
    }

    final rule = matched!;
    final scheme = _getTimeSchemeById(rule.timeSchemeId);
    if (scheme == null) {
      appDebugLog(
        'ScheduleDateRule',
        '跳过批量套用: 模板不存在 rule=${rule.name} schemeId=${rule.timeSchemeId}',
      );
      await AppLogService.instance.warn(
        'schedule_date_rule',
        '日期规则批量套用失败：时间模板不存在',
        extras: {
          'ruleId': rule.id,
          'ruleName': rule.name,
          'schemeId': rule.timeSchemeId,
        },
      );
      return const ScheduleDateRuleApplyResult(
        outcome: ScheduleDateRuleApplyOutcome.schemeMissing,
      );
    }

    // Validate every profile before rewriting clocks; active-only checks can
    // leave inactive profiles pointing at a scheme that cannot represent them.
    var requiredMaxSection = 0;
    for (final profile in _profiles) {
      for (final course in profile.courses) {
        if (course.endSection > requiredMaxSection) {
          requiredMaxSection = course.endSection;
        }
      }
    }
    for (final course in _courses) {
      if (course.endSection > requiredMaxSection) {
        requiredMaxSection = course.endSection;
      }
    }
    if (requiredMaxSection > scheme.sections.length) {
      appDebugLog(
        'ScheduleDateRule',
        '跳过批量套用: 节次超出模板 rule=${rule.name} need=$requiredMaxSection '
            'has=${scheme.sections.length}',
      );
      await AppLogService.instance.warn(
        'schedule_date_rule',
        '日期规则批量套用失败：节次超出模板',
        extras: {
          'ruleId': rule.id,
          'ruleName': rule.name,
          'schemeId': scheme.id,
          'requiredMaxSection': requiredMaxSection,
          'schemeSections': scheme.sections.length,
        },
      );
      return ScheduleDateRuleApplyResult(
        outcome: ScheduleDateRuleApplyOutcome.sectionOverflow,
        requiredMaxSection: requiredMaxSection,
        schemeSectionCount: scheme.sections.length,
      );
    }

    final signature = ScheduleDateRuleLogic.appliedSignature(rule);
    appDebugLog(
      'ScheduleDateRule',
      '批量套用作息: rule=${rule.name} scheme=${scheme.name} '
          'range=${rule.startDate}~${rule.endDate} signature=$signature',
    );

    for (var index = 0; index < _profiles.length; index++) {
      final profile = _profiles[index];
      final nextSettings = profile.settings.copyWith(
        activeTimeSchemeId: scheme.id,
        sections: List<SectionTime>.from(scheme.sections),
      );
      final syncedCourses = _syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(profile.courses),
        settings: nextSettings,
      );
      _profiles[index] = profile.copyWith(
        settings: nextSettings,
        courses: syncedCourses,
      );
    }

    final activeIndex = _profiles.indexWhere(
      (profile) => profile.id == _activeProfileId,
    );
    if (activeIndex != -1) {
      _courses = List<Course>.from(_profiles[activeIndex].courses);
      _settings = _profiles[activeIndex].settings;
    } else {
      _settings = _settings.copyWith(
        activeTimeSchemeId: scheme.id,
        sections: List<SectionTime>.from(scheme.sections),
      );
      _courses = _syncCoursesWithEffectiveTimeSchemes(
        List<Course>.from(_courses),
        settings: _settings,
      );
    }

    await _storageService.saveProfiles(_profiles);
    _scheduleDateRuleLastAppliedSignature = signature;
    await _storageService.saveScheduleDateRuleLastAppliedSignature(signature);
    notifyUserDataChangedForSync();
    _currentLiveCourseId = null;
    _notifyStateChanged();
    await _updateLiveActivity();

    unawaited(
      AppLogService.instance.info(
        'schedule_date_rule',
        '已按日期规则批量套用作息',
        extras: {
          'ruleId': rule.id,
          'ruleName': rule.name,
          'schemeId': scheme.id,
          'schemeName': scheme.name,
          'startDate': rule.startDate,
          'endDate': rule.endDate,
          'signature': signature,
        },
      ),
    );
    return const ScheduleDateRuleApplyResult(
      outcome: ScheduleDateRuleApplyOutcome.applied,
    );
  }

  /// Apply location routing to unlocked courses on the active profile.
  ///
  /// Returns match/update counts for toast feedback.
  Future<LocationTimeApplyStats> applyLocationTimeRulesToActiveProfile() {
    return _runMutation(() => _applyLocationTimeRulesToActiveProfileImpl());
  }

  Future<LocationTimeApplyStats>
  _applyLocationTimeRulesToActiveProfileImpl() async {
    await initialize();
    const debugTag = 'LocationTimeApply';
    var unlockedCount = 0;
    var matchedCount = 0;
    var updatedCount = 0;
    var alreadySameClockCount = 0;
    var sectionOverflowCount = 0;
    final sectionOverflowCourseNames = <String>[];
    var noMatchCount = 0;
    var matchMissingSchemeCount = 0;
    var autoReleasedCount = 0;
    var clockRewriteCount = 0;
    final changeSamples = <String>[];

    void audit(String message, {Map<String, Object?> extras = const {}}) {
      appDebugLog(debugTag, message);
      unawaited(
        AppLogService.instance.info(
          'location_time_apply',
          message,
          extras: extras,
        ),
      );
    }

    final activeScheme = activeTimeScheme;
    audit(
      '===== 开始应用到当前课表 ===== '
      'profile=${activeProfile?.name ?? "null"}(${_activeProfileId ?? "-"}) '
      'courses=${_courses.length} '
      'locationGroups=${_locationTimeGroups.length} '
      'activeScheme=${activeScheme?.name ?? "null"}(${activeScheme?.id ?? "-"}) '
      'activeSections=${activeScheme?.sections.length ?? _settings.sections.length} '
      'manualOverridesBefore=${_courses.where((c) => c.timeSchemeIdOverride != null).length}',
      extras: {
        'profileId': _activeProfileId,
        'courseCount': _courses.length,
        'groupCount': _locationTimeGroups.length,
        'activeSchemeId': activeScheme?.id,
        'manualOverridesBefore': _courses
            .where((course) => course.timeSchemeIdOverride != null)
            .length,
      },
    );
    for (final group in _locationTimeGroups) {
      final scheme = _getTimeSchemeById(group.timeSchemeId);
      final keywords = group.keywords
          .map((keyword) => '${keyword.pattern}(${keyword.mode.name})')
          .join('|');
      audit(
        '地点组: id=${group.id} name=${group.name} enabled=${group.enabled} '
        'priority=${group.priority} scheme=${scheme?.name ?? "MISSING"}(${group.timeSchemeId}) '
        'schemeSections=${scheme?.sections.length ?? 0} keywords=[$keywords]',
        extras: {
          'groupId': group.id,
          'groupName': group.name,
          'enabled': group.enabled,
          'schemeId': group.timeSchemeId,
          'schemeName': scheme?.name,
          'schemeSections': scheme?.sections.length ?? 0,
          'keywords': keywords,
        },
      );
      if (scheme != null && scheme.sections.isNotEmpty) {
        final first = scheme.sections.first;
        final last = scheme.sections.last;
        audit(
          '  模板首末节: ${first.startTime}-${first.endTime} ... '
          '${last.startTime}-${last.endTime}',
        );
      }
    }
    if (activeScheme != null && activeScheme.sections.isNotEmpty) {
      final first = activeScheme.sections.first;
      final last = activeScheme.sections.last;
      audit(
        '主课表模板首末节: ${first.startTime}-${first.endTime} ... '
        '${last.startTime}-${last.endTime}',
      );
    }

    final synced = <Course>[];
    for (final course in _courses) {
      unlockedCount += 1;
      final beforeOverride = course.timeSchemeIdOverride;
      final beforeClock = '${course.startTime}-${course.endTime}';
      final match = matchLocationTime(course.location);
      final matchedScheme = match == null
          ? null
          : _getTimeSchemeById(match.timeSchemeId);

      Course courseToSync = course;

      if (match == null) {
        noMatchCount += 1;
        if (changeSamples.length < 40) {
          audit(
            '未命中地点: course=${course.name} id=${course.id} loc=${course.location} '
            'sections=${course.startSection}-${course.endSection} '
            'override=${beforeOverride ?? "null"} clock=$beforeClock',
            extras: {
              'action': 'no_match',
              'courseId': course.id,
              'courseName': course.name,
              'location': course.location,
              'beforeOverride': beforeOverride,
              'beforeClock': beforeClock,
            },
          );
        }
        synced.add(course);
        continue;
      }

      if (matchedScheme == null) {
        matchMissingSchemeCount += 1;
        audit(
          '命中但模板不存在: course=${course.name} id=${course.id} loc=${course.location} '
          'group=${match.groupName} schemeId=${match.timeSchemeId} '
          'keyword=${match.matchedKeyword.pattern}/${match.matchedKeyword.mode.name}',
          extras: {
            'action': 'match_missing_scheme',
            'courseId': course.id,
            'courseName': course.name,
            'location': course.location,
            'groupName': match.groupName,
            'schemeId': match.timeSchemeId,
            'beforeOverride': beforeOverride,
          },
        );
        synced.add(course);
        continue;
      }

      final startIndex = course.startSection - 1;
      final endIndex = course.endSection - 1;
      final sectionCount = matchedScheme.sections.length;
      // HARD RULE: only fully seat-mapable courses may be synchronized.
      // Applying a short scheme to a later section would produce nonsense
      // clocks, so leave the course untouched and report it.
      if (startIndex < 0 || endIndex < startIndex || endIndex >= sectionCount) {
        sectionOverflowCount += 1;
        if (sectionOverflowCourseNames.length < 5) {
          sectionOverflowCourseNames.add(course.name);
        }
        audit(
          '拒绝套用(节次无法对号入座): course=${course.name} id=${course.id} '
          'loc=${course.location} need=${course.startSection}-${course.endSection} '
          'scheme=${matchedScheme.name} has=$sectionCount '
          'beforeOverride=${beforeOverride ?? "null"} clock=$beforeClock '
          '→ 不写 override、不改钟点',
          extras: {
            'action': 'overflow_reject_no_sync',
            'courseId': course.id,
            'courseName': course.name,
            'location': course.location,
            'startSection': course.startSection,
            'endSection': course.endSection,
            'schemeId': matchedScheme.id,
            'schemeName': matchedScheme.name,
            'schemeSections': sectionCount,
            'beforeOverride': beforeOverride,
            'beforeClock': beforeClock,
          },
        );
        // Leave course completely unchanged.
        synced.add(course);
        if (changeSamples.length < 30) {
          changeSamples.add(
            '${course.name}|${course.id}|REJECT overflow '
            'need=${course.startSection}-${course.endSection} schemeHas=$sectionCount',
          );
        }
        continue;
      }

      // Only fully seat-mapped courses count as matched/synchronized.
      matchedCount += 1;
      // Return the course to automatic mode, then resolve it through the
      // current location rule. This keeps future rule edits automatic instead
      // of turning a rematch into another permanent manual override.
      courseToSync = course.copyWith(timeSchemeIdOverride: null);
      if (beforeOverride != null) {
        autoReleasedCount += 1;
      }

      final expectedStart = matchedScheme.sections[startIndex].startTime;
      final expectedEnd = matchedScheme.sections[endIndex].endTime;
      final sameClock =
          course.startTime == expectedStart && course.endTime == expectedEnd;
      if (sameClock) {
        alreadySameClockCount += 1;
      }

      final next = _syncCourseWithEffectiveTimeScheme(
        courseToSync,
        settings: _settings,
        debugTrace: true,
        debugTag: debugTag,
      );
      synced.add(next);

      final clockChanged =
          next.startTime != course.startTime || next.endTime != course.endTime;
      final overrideChanged =
          next.timeSchemeIdOverride != course.timeSchemeIdOverride;
      if (clockChanged || overrideChanged) {
        updatedCount += 1;
        if (clockChanged) {
          clockRewriteCount += 1;
        }
        if (changeSamples.length < 30) {
          changeSamples.add(
            '${course.name}|${course.id}|'
            'override ${beforeOverride ?? "null"}->${next.timeSchemeIdOverride ?? "null"}|'
            'clock $beforeClock->${next.startTime}-${next.endTime}',
          );
        }
      }
      audit(
        '${sameClock ? "SAME" : "DIFF"} course=${course.name} id=${course.id} '
        'loc=${course.location} group=${match.groupName} '
        'scheme=${matchedScheme.name} '
        'beforeOverride=${beforeOverride ?? "null"} '
        'afterOverride=${next.timeSchemeIdOverride ?? "null"} '
        'beforeClock=$beforeClock afterClock=${next.startTime}-${next.endTime} '
        'clockChanged=$clockChanged overrideChanged=$overrideChanged',
        extras: {
          'action': sameClock
              ? 'auto_match_same_clock'
              : 'auto_match_and_rewrite_clock',
          'courseId': course.id,
          'courseName': course.name,
          'location': course.location,
          'groupName': match.groupName,
          'schemeId': matchedScheme.id,
          'schemeName': matchedScheme.name,
          'beforeOverride': beforeOverride,
          'afterOverride': next.timeSchemeIdOverride,
          'beforeClock': beforeClock,
          'afterClock': '${next.startTime}-${next.endTime}',
          'expectedClock': '$expectedStart-$expectedEnd',
          'sameClock': sameClock,
          'clockChanged': clockChanged,
          'overrideChanged': overrideChanged,
        },
      );
    }

    if (updatedCount > 0) {
      _courses = synced;
      await _persistActiveProfileState();
      _currentLiveCourseId = null;
      _notifyStateChanged();
      await _updateLiveActivity();
    }

    final overridesAfter = _courses
        .where((course) => course.timeSchemeIdOverride != null)
        .length;
    final profileOverrides =
        activeProfile?.courses
            .where((course) => course.timeSchemeIdOverride != null)
            .length ??
        -1;
    audit(
      '===== 应用结束 ===== unlocked=$unlockedCount matched=$matchedCount '
      'updated=$updatedCount sameClock=$alreadySameClockCount '
      'overflow=$sectionOverflowCount noMatch=$noMatchCount '
      'missingScheme=$matchMissingSchemeCount '
      'autoReleased=$autoReleasedCount clockRewrite=$clockRewriteCount '
      'overridesInMemoryAfter=$overridesAfter overridesInActiveProfile=$profileOverrides '
      'didPersist=${updatedCount > 0} '
      'overflowNames=${sectionOverflowCourseNames.join(",")} '
      'samples=${changeSamples.take(12).join(" || ")}',
      extras: {
        'unlocked': unlockedCount,
        'matched': matchedCount,
        'updated': updatedCount,
        'sameClock': alreadySameClockCount,
        'overflow': sectionOverflowCount,
        'noMatch': noMatchCount,
        'missingScheme': matchMissingSchemeCount,
        'autoReleased': autoReleasedCount,
        'clockRewrite': clockRewriteCount,
        'overridesInMemoryAfter': overridesAfter,
        'overridesInActiveProfile': profileOverrides,
        'didPersist': updatedCount > 0,
        'changeSamples': changeSamples,
        'overflowNames': sectionOverflowCourseNames,
      },
    );
    if (matchedCount > 0 && updatedCount == 0) {
      audit(
        '结论: 地点规则已命中，但课程未改写（钟点已相同且未绑定 override，或全部节次越界）。'
        'sameClock=$alreadySameClockCount overflow=$sectionOverflowCount。'
        '请对比地点组绑定模板 vs 主课表模板各节起止时间是否完全一致。',
      );
    }
    if (overridesAfter != profileOverrides && profileOverrides >= 0) {
      audit(
        '严重异常: 内存课表与 activeProfile 的模板覆盖数量不一致。持久化/合并失败。',
        extras: {
          'fatal': true,
          'overridesInMemoryAfter': overridesAfter,
          'overridesInActiveProfile': profileOverrides,
        },
      );
    }

    return LocationTimeApplyStats(
      unlockedCount: unlockedCount,
      matchedCount: matchedCount,
      updatedCount: updatedCount,
      alreadySameClockCount: alreadySameClockCount,
      sectionOverflowCount: sectionOverflowCount,
      sectionOverflowCourseNames: sectionOverflowCourseNames,
    );
  }

  String _sectionSignature(List<SectionTime> sections) {
    return jsonEncode(sections.map((section) => section.toJson()).toList());
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
          AppLogMessages.timetableLoadSettingsFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('TimetableProvider', '加载课表设置失败：$e');
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
          AppLogMessages.timetableLoadCoursesFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('TimetableProvider', '加载课程数据失败：$e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCurrentWeek() async {
    try {
      _currentWeek = activeProfile?.currentWeek ?? 1;
      _currentCalendarWeek = _resolveCurrentCalendarWeek();
      _currentDateWeek = clampCurrentWeekToSettings(
        _currentCalendarWeek,
        _settings,
      );
      notifyListeners();
    } catch (e) {
      unawaited(
        AppLogService.instance.warn(
          'timetable_load_current_week_failed',
          AppLogMessages.timetableLoadCurrentWeekFailed,
          extras: {'error': '$e'},
        ),
      );
      appDebugLog('TimetableProvider', '加载当前周次失败：$e');
    }
  }

  Future<void> setCurrentWeek(int week, {bool notify = true}) async {
    _currentWeek = clampCurrentWeekToSettings(week, _settings);
    if (_settings.semesterStartDate == null) {
      _currentDateWeek = _currentWeek;
      _currentCalendarWeek = _currentWeek;
    }
    _currentLiveCourseId = null; // 触发超级岛重刷
    final persistFuture = _persistActiveProfileState();
    if (notify) {
      notifyListeners();
    }
    await persistFuture;
    await _updateLiveActivity();
  }

  void _notifyStateChanged() => notifyListeners();

  Future<TimeScheme> createTimeScheme({
    required String name,
    List<SectionTime>? sections,
    bool applyToActiveProfile = false,
  }) => _timetableCreateTimeScheme(
    this,
    name: name,
    sections: sections,
    applyToActiveProfile: applyToActiveProfile,
  );

  Future<String?> applyTimeScheme(String schemeId) =>
      _timetableApplyTimeScheme(this, schemeId);

  Future<TimeScheme?> renameTimeScheme(String schemeId, String name) =>
      _timetableRenameTimeScheme(this, schemeId, name);

  Future<TimeScheme?> duplicateTimeScheme(String schemeId, {String? name}) =>
      _timetableDuplicateTimeScheme(this, schemeId, name: name);

  Future<String?> updateTimeScheme({
    required String schemeId,
    required String name,
    required List<SectionTime> sections,
  }) => _timetableUpdateTimeScheme(
    this,
    schemeId: schemeId,
    name: name,
    sections: sections,
  );

  Future<bool> deleteTimeScheme(String schemeId) =>
      _timetableDeleteTimeScheme(this, schemeId);

  Future<TimetableProfile> createProfile({required String name}) {
    return _runMutation(() async {
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
      unawaited(_syncExamReminders());
      _currentLiveCourseId = null;
      notifyListeners();
      await _updateLiveActivity();
      return activeProfile!;
    });
  }

  Future<TimetableProfile?> duplicateActiveProfile({String? name}) {
    return _runMutation(() async {
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
      unawaited(_syncExamReminders());
      _currentLiveCourseId = null;
      notifyListeners();
      await _updateLiveActivity();
      return activeProfile;
    });
  }

  Future<void> switchProfile(String profileId) {
    return _runMutation(() async {
      await initialize();
      if (_activeProfileId == profileId) {
        return;
      }
      final targetProfile = _getProfileById(profileId);
      if (targetProfile == null || targetProfile.isPartnerImported) {
        return;
      }

      // Capture the outgoing profile in memory, then switch immediately. The
      // single save below contains both the outgoing snapshot and the newly
      // active profile, so there is no need to block the UI on two full writes.
      _mergeActiveProfileIntoProfilesList();
      final previousProfileId = _activeProfileId;
      _activeProfileId = profileId;
      _applyProfileState(targetProfile);
      _currentLiveCourseId = null;
      _lastLiveSnapshotSignature = null;
      notifyListeners();

      try {
        await _persistActiveProfileState(touchLastUsedAt: true);
      } catch (_) {
        // Persist failed: roll memory back so UI does not diverge from disk.
        if (previousProfileId != null) {
          _activeProfileId = previousProfileId;
          final previousProfile = _getProfileById(previousProfileId);
          if (previousProfile != null) {
            _applyProfileState(previousProfile);
          }
        }
        _currentLiveCourseId = null;
        _lastLiveSnapshotSignature = null;
        notifyListeners();
        rethrow;
      }

      await _liveActivitiesService.stopLiveUpdate();
      _lastLiveActivityStageKey = null;
      await _syncLiveScheduleSnapshot();
      await _updateLiveActivity(syncScheduleSnapshot: false);
      unawaited(_syncExamReminders());
    });
  }

  Future<void> renameProfile(String profileId, String name) {
    return _runMutation(() async {
      await initialize();
      // Flush active memory into _profiles before any whole-list save so a
      // rename cannot persist a stale courses snapshot over concurrent edits.
      _mergeActiveProfileIntoProfilesList();
      final index = _profiles.indexWhere((profile) => profile.id == profileId);
      if (index == -1) {
        return;
      }

      _profiles[index] = _profiles[index].copyWith(name: name.trim());
      await _storageService.saveProfiles(_profiles);
      notifyUserDataChangedForSync();
      notifyListeners();
    });
  }

  Future<bool> deleteProfile(String profileId) {
    return _runMutation(() async {
      await initialize();
      if (_profiles.length <= 1) {
        return false;
      }

      final index = _profiles.indexWhere((profile) => profile.id == profileId);
      if (index == -1 || _profiles[index].isPartnerImported) {
        return false;
      }

      final isActive = _profiles[index].id == _activeProfileId;
      if (isActive) {
        final hasNormalFallback = _profiles
            .where(
              (profile) =>
                  profile.id != profileId && !profile.isPartnerImported,
            )
            .isNotEmpty;
        if (!hasNormalFallback) {
          // Keep at least one non-partner profile as the working set.
          return false;
        }
      } else {
        _mergeActiveProfileIntoProfilesList();
      }
      _profiles.removeAt(index);
      if (isActive) {
        final fallbackProfile = _profiles
            .where((profile) => !profile.isPartnerImported)
            .first;
        _activeProfileId = fallbackProfile.id;
        _applyProfileState(fallbackProfile);
        _currentLiveCourseId = null;
      }
      await _storageService.saveProfiles(_profiles);
      if (_activeProfileId != null) {
        await _storageService.setActiveProfileId(_activeProfileId!);
      }
      notifyUserDataChangedForSync();
      notifyListeners();
      if (isActive) {
        unawaited(_syncExamReminders());
      }
      await _updateLiveActivity();
      return true;
    });
  }

  Future<void> addCourse(Course course) {
    return _runMutation(() async {
      final validationMessage = validateCourseTimeSchemeOverride(
        timeSchemeId: course.timeSchemeIdOverride,
        startSection: course.startSection,
        endSection: course.endSection,
      );
      if (validationMessage != null) {
        throw ArgumentError(validationMessage);
      }
      final normalized = _normalizeCourse(course);
      final normalizedCourse = _isLiveTestingFixture(normalized)
          ? normalized
          : _syncCourseWithEffectiveTimeScheme(normalized);
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
      await _syncHomeworkTasksWithCourses();
      await _persistActiveProfileState();
      await _recordTeacherImpl(preparedCourse.teacher);
      await _recordLocationImpl(preparedCourse.location);
      _currentLiveCourseId = null;
      notifyListeners();
      _analytics.logEventLater(
        name: 'course_created',
        parameters: {
          'day_of_week': preparedCourse.dayOfWeek,
          'section_count': preparedCourse.sectionCount,
          'has_short_name': preparedCourse.shortName?.isNotEmpty == true
              ? 1
              : 0,
        },
      );
      _updateLiveActivity();
    });
  }

  Future<void> updateCourse(Course course, {String? previousSharedName}) {
    return _runMutation(() async {
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
        final normalized = _normalizeCourse(course);
        final normalizedCourse = _isLiveTestingFixture(normalized)
            ? normalized
            : _syncCourseWithEffectiveTimeScheme(normalized);
        final originalCourse = _courses[index];
        final previousKey = _sharedCourseKeyFromName(
          previousSharedName ?? originalCourse.name,
        );
        final newKey = _sharedCourseKey(normalizedCourse);

        _courses[index] = normalizedCourse;
        await _recordTeacherImpl(normalizedCourse.teacher);
        await _recordLocationImpl(normalizedCourse.location);
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

        await _syncHomeworkTasksWithCourses();
        await _persistActiveProfileState();
        _currentLiveCourseId = null;
        notifyListeners();
        unawaited(_syncExamReminders());
        _analytics.logEventLater(
          name: 'course_updated',
          parameters: {
            'day_of_week': normalizedCourse.dayOfWeek,
            'section_count': normalizedCourse.sectionCount,
            'has_short_name': normalizedCourse.shortName?.isNotEmpty == true
                ? 1
                : 0,
          },
        );
        _updateLiveActivity();
      }
    });
  }

  Future<void> deleteCourse(String courseId) {
    return _runMutation(() async {
      _courses.removeWhere((c) => c.id == courseId);
      _exams.removeWhere((e) => e.courseId == courseId);
      _tasks.removeWhere((task) => task.courseId == courseId);
      await _persistActiveProfileState();
      _currentLiveCourseId = null;
      notifyListeners();
      unawaited(_syncExamReminders());
      _analytics.logEventLater(
        name: 'course_deleted',
        parameters: {'remaining_course_count': _courses.length},
      );
      _updateLiveActivity();
    });
  }

  /// Delete all schedule entries (courses) for a given course name.
  Future<void> deleteCourseGroup(String name) {
    return _runMutation(() async {
      final key = _buildSharedCourseNameKey(name);
      final deletedCourseIds = _courses
          .where((c) => _buildSharedCourseNameKey(c.name) == key)
          .map((c) => c.id)
          .toSet();
      _courses.removeWhere((c) => deletedCourseIds.contains(c.id));
      _exams.removeWhere((e) => deletedCourseIds.contains(e.courseId));
      _tasks.removeWhere((task) => deletedCourseIds.contains(task.courseId));
      await _persistActiveProfileState();
      _currentLiveCourseId = null;
      notifyListeners();
      unawaited(_syncExamReminders());
      _analytics.logEventLater(
        name: 'course_group_deleted',
        parameters: {'remaining_course_count': _courses.length},
      );
      _updateLiveActivity();
    });
  }

  // ---- 课程任务 CRUD ----

  CourseTask? getTaskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }

  Course? getCourseForTask(CourseTask task) {
    final courseId = task.courseId;
    return courseId == null ? null : getCourseById(courseId);
  }

  List<CourseTask> getTasksForCourse(String courseId, {int? sourceWeek}) {
    return _tasks
        .where(
          (task) =>
              task.courseId == courseId &&
              (sourceWeek == null || task.sourceWeek == sourceWeek),
        )
        .toList()
      ..sort(CourseTask.compareByDueDate);
  }

  DateTime? dateForCourseOccurrence(Course course, int week) {
    final semesterStart = _settings.semesterStartDate;
    if (semesterStart == null || week < 1) {
      return null;
    }
    final startOfSemesterWeek = _startOfWeek(semesterStart);
    return startOfSemesterWeek.add(
      Duration(days: (week - 1) * 7 + course.dayOfWeek - 1),
    );
  }

  Future<void> addTask(CourseTask task) {
    return _runMutation(() async {
      final normalized = _normalizeTask(task);
      _validateTask(normalized);
      _tasks = _sortTasks([..._tasks, normalized]);
      await _persistActiveProfileState();
      notifyListeners();
      _analytics.logEventLater(
        name: 'task_created',
        parameters: {
          'has_course': normalized.courseId == null ? 0 : 1,
          'has_due_date': normalized.dueDate == null ? 0 : 1,
        },
      );
    });
  }

  Future<void> updateTask(CourseTask task) {
    return _runMutation(() async {
      final index = _tasks.indexWhere((item) => item.id == task.id);
      if (index == -1) {
        return;
      }
      final normalized = _normalizeTask(
        task,
      ).copyWith(createdAt: _tasks[index].createdAt, updatedAt: DateTime.now());
      _validateTask(normalized);
      _tasks[index] = normalized;
      _tasks = _sortTasks(_tasks);
      await _persistActiveProfileState();
      notifyListeners();
    });
  }

  Future<void> toggleTaskCompleted(String taskId) {
    return _runMutation(() async {
      final index = _tasks.indexWhere((task) => task.id == taskId);
      if (index == -1) {
        return;
      }
      final current = _tasks[index];
      _tasks[index] = current.copyWith(
        isCompleted: !current.isCompleted,
        updatedAt: DateTime.now(),
      );
      _tasks = _sortTasks(_tasks);
      await _persistActiveProfileState();
      notifyListeners();
    });
  }

  Future<void> deleteTask(String taskId) {
    return _runMutation(() async {
      final index = _tasks.indexWhere((task) => task.id == taskId);
      if (index == -1) {
        return;
      }
      final task = _tasks[index];
      if (task.source == CourseTaskSource.homeworkMark &&
          task.courseId != null &&
          task.sourceWeek != null) {
        _clearHomeworkMark(task.courseId!, task.sourceWeek!);
      }
      _tasks.removeAt(index);
      await _persistActiveProfileState();
      notifyListeners();
      _analytics.logEventLater(
        name: 'task_deleted',
        parameters: {'remaining_task_count': _tasks.length},
      );
    });
  }

  CourseTask _normalizeTask(CourseTask task) {
    final title = task.title.trim();
    final note = task.note?.trim();
    final courseId = task.courseId?.trim();
    final sourceWeek = task.sourceWeek != null && task.sourceWeek! > 0
        ? task.sourceWeek
        : null;
    return task.copyWith(
      title: title,
      courseId: courseId == null || courseId.isEmpty ? null : courseId,
      sourceWeek: sourceWeek,
      dueDate: task.dueDate == null ? null : CourseTask.dateOnly(task.dueDate!),
      note: note == null || note.isEmpty ? null : note,
      updatedAt: DateTime.now(),
    );
  }

  void _validateTask(CourseTask task) {
    if (task.title.isEmpty) {
      throw ArgumentError('task_title_required');
    }
    if (task.courseId != null && getCourseById(task.courseId!) == null) {
      throw ArgumentError('task_course_not_found');
    }
  }

  List<CourseTask> _sortTasks(List<CourseTask> source) {
    source.sort(CourseTask.compareByDueDate);
    return source;
  }

  Future<bool> _syncHomeworkTasksWithCourses({bool persist = false}) async {
    final before = jsonEncode(_tasks.map((task) => task.toJson()).toList());
    final existingHomework = _tasks
        .where((task) => task.source == CourseTaskSource.homeworkMark)
        .toList();
    final next = _tasks
        .where((task) => task.source != CourseTaskSource.homeworkMark)
        .toList();
    final now = DateTime.now();

    for (final course in _courses) {
      final notes = course.normalizedSessionNotesMap;
      if (notes == null) {
        continue;
      }
      for (final entry in notes.entries) {
        final note = entry.value;
        if (!note.hasHomework) {
          continue;
        }
        CourseTask? existing;
        for (final candidate in existingHomework) {
          if (candidate.courseId == course.id &&
              candidate.sourceWeek == entry.key) {
            existing = candidate;
            break;
          }
        }
        final noteTitle = note.trimmedText;
        if (noteTitle.isEmpty && existing == null) {
          continue;
        }
        final title = noteTitle.isEmpty ? existing!.title : noteTitle;
        next.add(
          (existing ??
                  CourseTask(
                    id: const Uuid().v4(),
                    title: title,
                    courseId: course.id,
                    sourceWeek: entry.key,
                    source: CourseTaskSource.homeworkMark,
                    createdAt: now,
                    updatedAt: now,
                  ))
              .copyWith(
                title: title,
                courseId: course.id,
                sourceWeek: entry.key,
                dueDate: dateForCourseOccurrence(course, entry.key),
                source: CourseTaskSource.homeworkMark,
                updatedAt: now,
              ),
        );
      }
    }

    _tasks = _sortTasks(next);
    final after = jsonEncode(_tasks.map((task) => task.toJson()).toList());
    final changed = before != after;
    if (changed && persist) {
      await _persistActiveProfileState();
    }
    return changed;
  }

  void _clearHomeworkMark(String courseId, int week) {
    final index = _courses.indexWhere((course) => course.id == courseId);
    if (index == -1) {
      return;
    }
    final course = _courses[index];
    final note = course.sessionNoteForWeek(week);
    if (note == null) {
      return;
    }
    _courses[index] = course.copyWith(
      sessionNotes: course.withSessionNote(
        week,
        note.copyWith(hasHomework: false),
      ),
    );
  }

  /// Replace all schedule entries for a course group.  [updatedCourses] is
  /// the full list of schedules that should exist after the update.
  /// Shared metadata fields (name, short name, color, course nature,
  /// description) are propagated to all entries; per-entry fields such as
  /// teacher and location keep each slot’s own value.
  Future<void> updateCourseGroup(
    String originalName,
    List<Course> updatedCourses,
  ) {
    return _runMutation(() async {
      final key = _buildSharedCourseNameKey(originalName);
      // Remove old entries for this group.
      _courses.removeWhere((c) => _buildSharedCourseNameKey(c.name) == key);
      // Add the updated entries, applying shared fields.
      final shared = updatedCourses.first;
      for (final course in updatedCourses) {
        final normalized = _normalizeCourse(
          _applySharedCourseFields(course, shared),
        );
        _courses.add(normalized);
        await _recordTeacherImpl(normalized.teacher);
        await _recordLocationImpl(normalized.location);
      }
      _tasks.removeWhere(
        (task) =>
            task.courseId != null &&
            !_courses.any((course) => course.id == task.courseId),
      );
      await _syncHomeworkTasksWithCourses();
      await _persistActiveProfileState();
      _currentLiveCourseId = null;
      notifyListeners();
      unawaited(_syncExamReminders());
      _analytics.logEventLater(
        name: 'course_group_updated',
        parameters: {
          'schedule_count': updatedCourses.length,
          'remaining_course_count': _courses.length,
        },
      );
      _updateLiveActivity();
    });
  }

  /// Add multiple schedule entries for a new course group in one persist.
  Future<void> addCourseGroup(List<Course> courses) {
    return _runMutation(() async {
      if (courses.isEmpty) {
        return;
      }
      final shared = courses.first;
      // 先收集到临时列表，验证全部通过后再批量添加，避免中途失败导致状态不一致
      final normalizedCourses = <Course>[];
      final teachers = <String>{};
      final locations = <String>{};
      for (final course in courses) {
        final validationMessage = validateCourseTimeSchemeOverride(
          timeSchemeId: course.timeSchemeIdOverride,
          startSection: course.startSection,
          endSection: course.endSection,
        );
        if (validationMessage != null) {
          throw ArgumentError(validationMessage);
        }
        final normalized = _syncCourseWithEffectiveTimeScheme(
          _normalizeCourse(_applySharedCourseFields(course, shared)),
        );
        normalizedCourses.add(normalized);
        if (normalized.teacher.isNotEmpty) teachers.add(normalized.teacher);
        if (normalized.location.isNotEmpty) locations.add(normalized.location);
      }
      // 所有验证通过，批量添加
      _courses.addAll(normalizedCourses);
      await _syncHomeworkTasksWithCourses();
      for (final teacher in teachers) {
        await _recordTeacherImpl(teacher);
      }
      for (final location in locations) {
        await _recordLocationImpl(location);
      }
      await _persistActiveProfileState();
      _currentLiveCourseId = null;
      notifyListeners();
      _analytics.logEventLater(
        name: 'course_group_created',
        parameters: {
          'schedule_count': courses.length,
          'remaining_course_count': _courses.length,
        },
      );
      _updateLiveActivity();
    });
  }

  /// 切换课程在指定周次的停课状态
  Future<void> toggleCourseSuspension(String courseId, int week) {
    return _runMutation(() => _toggleCourseSuspensionImpl(courseId, week));
  }

  Future<void> _toggleCourseSuspensionImpl(String courseId, int week) async {
    await initialize();
    final index = _courses.indexWhere((c) => c.id == courseId);
    if (index == -1) return;

    final course = _courses[index];
    final currentSuspended = course.suspendedWeeks ?? [];
    List<int> newSuspended;
    if (currentSuspended.contains(week)) {
      newSuspended = currentSuspended.where((w) => w != week).toList();
    } else {
      newSuspended = [...currentSuspended, week]..sort();
    }
    _courses[index] = course.copyWith(
      suspendedWeeks: newSuspended.isEmpty ? null : newSuspended,
    );
    await _persistActiveProfileState();
    notifyListeners();
    _analytics.logEventLater(
      name: 'course_suspension_toggled',
      parameters: {
        'course_id': courseId,
        'week': week,
        'suspended': !currentSuspended.contains(week),
      },
    );
    await _updateLiveActivity();
  }

  /// 停课全部周次
  Future<void> suspendAllWeeks(String courseId) {
    return _runMutation(() => _suspendAllWeeksImpl(courseId));
  }

  Future<void> _suspendAllWeeksImpl(String courseId) async {
    await initialize();
    final index = _courses.indexWhere((c) => c.id == courseId);
    if (index == -1) return;
    final course = _courses[index];
    final allWeeks = course.activeWeeks;
    _courses[index] = course.copyWith(suspendedWeeks: allWeeks);
    await _persistActiveProfileState();
    notifyListeners();
    _analytics.logEventLater(
      name: 'course_all_weeks_suspended',
      parameters: {'course_id': courseId},
    );
    await _updateLiveActivity();
  }

  /// 取消全部停课
  Future<void> unsuspendAllWeeks(String courseId) {
    return _runMutation(() => _unsuspendAllWeeksImpl(courseId));
  }

  Future<void> _unsuspendAllWeeksImpl(String courseId) async {
    await initialize();
    final index = _courses.indexWhere((c) => c.id == courseId);
    if (index == -1) return;
    _courses[index] = _courses[index].copyWith(suspendedWeeks: null);
    await _persistActiveProfileState();
    notifyListeners();
    _analytics.logEventLater(
      name: 'course_all_weeks_unsuspended',
      parameters: {'course_id': courseId},
    );
    await _updateLiveActivity();
  }

  /// Returns concrete schedule occurrences for one local calendar date.
  ///
  /// The source item remains attached to each instance so callers can choose
  /// between editing the whole series and editing only this occurrence.
  List<ScheduleItemInstance> getScheduleItemInstancesForDate(DateTime date) {
    final normalizedDate = ScheduleItem.dateOnly(date);
    final instancesByDisplayDate = <String, ScheduleItemInstance>{};
    for (final item in _scheduleItems) {
      for (final instance in item.expandInstances(
        fromDate: normalizedDate,
        toDate: normalizedDate,
      )) {
        _putScheduleInstanceByDisplayDate(instancesByDisplayDate, instance);
      }
    }
    return _sortScheduleItemInstances(instancesByDisplayDate.values.toList());
  }

  List<ScheduleItemInstance> getScheduleItemOccurrencesForDate(DateTime date) {
    return getScheduleItemInstancesForDate(date);
  }

  /// Expands all persisted items in an inclusive local calendar date range.
  List<ScheduleItemInstance> getScheduleItemInstancesForRange(
    DateTime fromDate,
    DateTime toDate,
  ) {
    final instancesByDisplayDate = <String, ScheduleItemInstance>{};
    for (final item in _scheduleItems) {
      for (final instance in item.expandInstances(
        fromDate: fromDate,
        toDate: toDate,
      )) {
        _putScheduleInstanceByDisplayDate(instancesByDisplayDate, instance);
      }
    }
    return _sortScheduleItemInstances(instancesByDisplayDate.values.toList());
  }

  /// Backward-compatible source-item query used by existing screens.
  List<ScheduleItem> getScheduleItemsForDate(DateTime date) {
    return getScheduleItemInstancesForDate(
      date,
    ).map((instance) => instance.item).toList(growable: false);
  }

  Future<void> addScheduleItem(ScheduleItem item) {
    return _runMutation(() async {
      await initialize();
      final normalizedItem = _normalizeScheduleItem(item);
      _scheduleItems = _sortScheduleItems(<ScheduleItem>[
        ..._scheduleItems,
        normalizedItem,
      ]);
      await _persistActiveProfileState();
      notifyListeners();
      _analytics.logEventLater(
        name: 'schedule_item_created',
        parameters: {
          'has_location': normalizedItem.location?.isNotEmpty == true ? 1 : 0,
          'has_note': normalizedItem.note?.isNotEmpty == true ? 1 : 0,
        },
      );
      unawaited(_syncExamReminders());
    });
  }

  Future<void> updateScheduleItem(ScheduleItem item) {
    return _runMutation(() async {
      await initialize();
      final index = _scheduleItems.indexWhere(
        (existing) => existing.id == item.id,
      );
      if (index == -1) {
        return;
      }

      final normalizedItem = _normalizeScheduleItem(item);
      final nextItems = List<ScheduleItem>.from(_scheduleItems);
      final existing = nextItems[index];
      if (existing.seriesId == null) {
        // Updating a root item means "all occurrences". Single-occurrence
        // overrides are intentionally discarded by this series operation.
        nextItems.removeWhere((candidate) => candidate.seriesId == existing.id);
      }
      final nextIndex = nextItems.indexWhere(
        (candidate) => candidate.id == existing.id,
      );
      if (nextIndex == -1) {
        return;
      }
      nextItems[nextIndex] = normalizedItem;
      _scheduleItems = _sortScheduleItems(nextItems);
      await _persistActiveProfileState();
      notifyListeners();
      _analytics.logEventLater(
        name: 'schedule_item_updated',
        parameters: {
          'has_location': normalizedItem.location?.isNotEmpty == true ? 1 : 0,
          'has_note': normalizedItem.note?.isNotEmpty == true ? 1 : 0,
        },
      );
      unawaited(_syncExamReminders());
    });
  }

  Future<void> deleteScheduleItem(String itemId) {
    return _runMutation(() async {
      await initialize();
      final target = _findScheduleItem(itemId);
      if (target == null) {
        return;
      }
      final seriesId = target.seriesId ?? target.id;
      final previousCount = _scheduleItems.length;
      _scheduleItems = _scheduleItems
          .where((item) => item.id != seriesId && item.seriesId != seriesId)
          .toList(growable: false);
      if (_scheduleItems.length == previousCount) {
        return;
      }

      await _persistActiveProfileState();
      notifyListeners();
      _analytics.logEventLater(
        name: 'schedule_item_deleted',
        parameters: {'remaining_schedule_item_count': _scheduleItems.length},
      );
      unawaited(_syncExamReminders());
    });
  }

  /// Deletes one occurrence while leaving the rest of its series intact.
  Future<void> deleteScheduleItemOccurrence(
    String itemId,
    DateTime occurrenceDate,
  ) {
    return _runMutation(() async {
      await initialize();
      final target = _findScheduleItem(itemId);
      final root = _findSeriesRoot(target);
      if (root == null) {
        return;
      }

      final requestedDate =
          target?.seriesId != null && target?.occurrenceDate != null
          ? target!.occurrenceDate!
          : ScheduleItem.dateOnly(occurrenceDate);
      final hasOverride = _scheduleItems.any(
        (item) => _isOverrideForOccurrence(item, root.id, requestedDate),
      );
      if (!root.occursOn(requestedDate) && !hasOverride) {
        return;
      }

      // A date-only one-off has no remaining occurrences after this operation,
      // so removing its persisted row matches whole-item deletion semantics.
      if (root.seriesId == null &&
          root.recurrence == ScheduleRecurrence.none &&
          _isSameDate(root.startDate, root.endDate) &&
          _isSameDate(root.startDate, requestedDate)) {
        await deleteScheduleItem(root.id);
        return;
      }

      final updatedRoot = root.copyWith(
        exceptionDates: _normalizedExceptionDates(
          root.exceptionDates,
          requestedDate,
        ),
        updatedAt: DateTime.now(),
      );
      final nextItems = <ScheduleItem>[];
      for (final item in _scheduleItems) {
        if (item.id == root.id) {
          nextItems.add(updatedRoot);
        } else if (_isOverrideForOccurrence(item, root.id, requestedDate)) {
          continue;
        } else {
          nextItems.add(item);
        }
      }
      _scheduleItems = _sortScheduleItems(nextItems);
      await _persistActiveProfileState();
      notifyListeners();
      _analytics.logEventLater(
        name: 'schedule_item_occurrence_deleted',
        parameters: {
          'schedule_item_id': root.id,
          'occurrence_date': ScheduleItem.formatCalendarDate(requestedDate),
        },
      );
      unawaited(_syncExamReminders());
    });
  }

  /// Edits one occurrence by replacing it with a persisted one-time override.
  /// The base series stores the original date as an exception, so the base
  /// occurrence cannot reappear alongside the override.
  ///
  /// Existing editors use [root.startDate] as an unchanged-date sentinel. Set
  /// [dateWasExplicitlyEdited] when the user intentionally moves an occurrence
  /// to that same date, so the move remains distinguishable from that legacy
  /// sentinel.
  Future<void> updateScheduleItemOccurrence(
    String itemId,
    DateTime occurrenceDate,
    ScheduleItem updatedItem, {
    bool dateWasExplicitlyEdited = false,
  }) {
    return _runMutation(() async {
      await initialize();
      final target = _findScheduleItem(itemId);
      final root = _findSeriesRoot(target);
      if (root == null) {
        return;
      }

      final requestedDate =
          target?.seriesId != null && target?.occurrenceDate != null
          ? target!.occurrenceDate!
          : ScheduleItem.dateOnly(occurrenceDate);
      final existingOverride = _scheduleItems.any(
        (item) => _isOverrideForOccurrence(item, root.id, requestedDate),
      );
      if (!root.occursOn(requestedDate) && !existingOverride) {
        return;
      }

      // Editing the only occurrence of a one-off can update the original row,
      // retaining its established id and avoiding an unnecessary override.
      if (root.seriesId == null &&
          root.recurrence == ScheduleRecurrence.none &&
          _isSameDate(root.startDate, root.endDate) &&
          _isSameDate(root.startDate, requestedDate)) {
        await updateScheduleItem(updatedItem.copyWith(id: root.id));
        return;
      }

      final effectiveDate = _resolveOccurrenceEditDate(
        root: root,
        occurrenceDate: requestedDate,
        updatedItem: updatedItem,
        dateWasExplicitlyEdited: dateWasExplicitlyEdited,
      );
      final overrideId = ScheduleItem.buildOccurrenceId(root.id, requestedDate);
      final override = _normalizeScheduleItem(
        updatedItem.copyWith(
          id: overrideId,
          startDate: effectiveDate,
          endDate: effectiveDate,
          recurrence: ScheduleRecurrence.none,
          exceptionDates: const <DateTime>[],
          seriesId: root.id,
          occurrenceDate: requestedDate,
        ),
      );
      final updatedRoot = root.copyWith(
        exceptionDates: _normalizedExceptionDates(
          root.exceptionDates,
          requestedDate,
        ),
        updatedAt: DateTime.now(),
      );
      final nextItems = <ScheduleItem>[];
      for (final item in _scheduleItems) {
        if (item.id == root.id) {
          nextItems.add(updatedRoot);
        } else if (_isOverrideForOccurrence(item, root.id, requestedDate)) {
          continue;
        } else {
          nextItems.add(item);
        }
      }
      nextItems.add(override);
      _scheduleItems = _sortScheduleItems(nextItems);
      await _persistActiveProfileState();
      notifyListeners();
      _analytics.logEventLater(
        name: 'schedule_item_occurrence_updated',
        parameters: {
          'schedule_item_id': root.id,
          'occurrence_date': ScheduleItem.formatCalendarDate(requestedDate),
        },
      );
      unawaited(_syncExamReminders());
    });
  }

  /// Convenience API for callers holding the stable occurrence id.
  Future<void> deleteScheduleItemInstance(String occurrenceId) {
    return _runMutation(() async {
      await initialize();
      final instance = _findScheduleItemInstanceById(occurrenceId);
      if (instance == null) {
        return;
      }
      await deleteScheduleItemOccurrence(
        instance.sourceItemId,
        instance.occurrenceDate,
      );
    });
  }

  /// Convenience API for callers holding the stable occurrence id.
  Future<void> updateScheduleItemInstance(
    String occurrenceId,
    ScheduleItem updatedItem, {
    bool dateWasExplicitlyEdited = false,
  }) {
    return _runMutation(() async {
      await initialize();
      final instance = _findScheduleItemInstanceById(occurrenceId);
      if (instance == null) {
        return;
      }
      await updateScheduleItemOccurrence(
        instance.sourceItemId,
        instance.occurrenceDate,
        updatedItem,
        dateWasExplicitlyEdited: dateWasExplicitlyEdited,
      );
    });
  }

  Future<void> updateScheduleItemSeries(ScheduleItem item) {
    return updateScheduleItem(item);
  }

  Future<void> deleteScheduleItemSeries(String itemId) {
    return deleteScheduleItem(itemId);
  }

  ScheduleItem? getScheduleItemById(String itemId) {
    return _findScheduleItem(itemId);
  }

  ScheduleItem? getScheduleItemSeriesRoot(String itemId) {
    return _findSeriesRoot(_findScheduleItem(itemId));
  }

  // ---- 考试 CRUD ----

  Exam? getExamById(String id) {
    for (final exam in _exams) {
      if (exam.id == id) return exam;
    }
    return null;
  }

  Course? getCourseForExam(Exam exam) => getCourseById(exam.courseId);

  /// 根据课程 ID 查找课程，找不到返回 null。
  Course? getCourseById(String id) {
    for (final course in _courses) {
      if (course.id == id) return course;
    }
    return null;
  }

  /// 计算 [date] 在学期中的周次（从 1 开始），周一为每周起始日。
  /// 返回 null 表示 [date] 早于学期开始日期。
  int? getWeekIndex(DateTime date, DateTime semesterStart) {
    final alignedStart = _startOfWeek(semesterStart);
    final alignedTarget = _startOfWeek(date);
    final diffDays =
        DateTime.utc(alignedTarget.year, alignedTarget.month, alignedTarget.day)
            .difference(
              DateTime.utc(
                alignedStart.year,
                alignedStart.month,
                alignedStart.day,
              ),
            )
            .inDays;
    if (diffDays < 0) return null;
    return (diffDays ~/ 7) + 1;
  }

  List<Exam> getExamsForCourse(String courseId) {
    return _exams.where((exam) => exam.courseId == courseId).toList()
      ..sort(Exam.compareByStart);
  }

  List<Exam> getUpcomingExams({int? limit}) {
    final upcoming = _exams.where((exam) => !exam.isExpired).toList()
      ..sort(Exam.compareByStart);
    if (limit != null && upcoming.length > limit) {
      return upcoming.sublist(0, limit);
    }
    return upcoming;
  }

  Exam? getNextExam() {
    final upcoming = getUpcomingExams(limit: 1);
    return upcoming.isEmpty ? null : upcoming.first;
  }

  bool hasExamOnDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return _exams.any((exam) {
      final examDate = DateTime(
        exam.dateTime.year,
        exam.dateTime.month,
        exam.dateTime.day,
      );
      return examDate == target;
    });
  }

  Future<void> addExam(Exam exam) {
    return _runMutation(() async {
      await initialize();
      if (getCourseForExam(exam) == null) {
        throw ArgumentError('linked_course_not_found');
      }
      _exams.add(exam);
      await _persistActiveProfileState();
      notifyListeners();
      unawaited(_syncExamReminders());
      // Native widgets re-read profiles; force a snapshot push so exam line
      // appears without waiting for the next course-boundary refresh.
      _lastHomeWidgetSnapshotSignature = null;
      unawaited(_syncHomeWidgetSnapshot());
      _analytics.logEventLater(
        name: 'exam_created',
        parameters: {
          'has_location': exam.location?.isNotEmpty == true ? 1 : 0,
          'has_seat': exam.seatNumber?.isNotEmpty == true ? 1 : 0,
        },
      );
    });
  }

  Future<void> updateExam(Exam exam) {
    return _runMutation(() async {
      await initialize();
      final index = _exams.indexWhere((e) => e.id == exam.id);
      if (index == -1) return;
      _exams[index] = exam;
      await _persistActiveProfileState();
      notifyListeners();
      unawaited(_syncExamReminders());
      _lastHomeWidgetSnapshotSignature = null;
      unawaited(_syncHomeWidgetSnapshot());
      _analytics.logEventLater(
        name: 'exam_updated',
        parameters: {'exam_id': exam.id},
      );
    });
  }

  Future<void> deleteExam(String examId) {
    return _runMutation(() async {
      await initialize();
      _exams.removeWhere((e) => e.id == examId);
      await _persistActiveProfileState();
      notifyListeners();
      unawaited(_syncExamReminders());
      _lastHomeWidgetSnapshotSignature = null;
      unawaited(_syncHomeWidgetSnapshot());
      _analytics.logEventLater(
        name: 'exam_deleted',
        parameters: {'remaining_exam_count': _exams.length},
      );
    });
  }

  /// Reconcile native exam-reminder alarms with the active profile exam list.
  Future<void> _syncExamReminders() async {
    try {
      final coursesById = <String, Course>{
        for (final course in courses) course.id: course,
      };
      await _examReminderService.reconcile(
        exams: _exams,
        resolveCourse: getCourseForExam,
        scheduleItems: _scheduleItems,
        // 单节课提醒与考试/日程共用同一原生调度管线：全量重建，
        // 课程被删、日期已过或条目非法都会在这里被自然过滤。
        additionalFires: ClassReminderService.buildFires(
          entries: settings.classReminders,
          resolveCourse: (courseId) => coursesById[courseId],
        ),
      );
    } catch (error) {
      appDebugLog('ExamReminder', 'sync failed: $error');
    }
  }

  /// 查询某节课在某个真实日期的提醒条目；无则返回 null。
  ClassReminderEntry? classReminderFor(String courseId, String date) {
    for (final entry in settings.classReminders) {
      if (entry.courseId == courseId && entry.date == date) {
        return entry;
      }
    }
    return null;
  }

  /// 设置（或覆盖）某节课某天的提醒；同课同日只保留一条。
  Future<void> setClassReminder(ClassReminderEntry entry) async {
    final current = settings;
    final rest = current.classReminders
        .where(
          (existing) =>
              !(existing.courseId == entry.courseId &&
                  existing.date == entry.date),
        )
        .toList()
      ..add(entry)
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) {
          return byDate;
        }
        return a.minuteOfDay.compareTo(b.minuteOfDay);
      });
    await updateSettings(current.copyWith(classReminders: rest));
    unawaited(_syncExamReminders());
  }

  /// 取消某节课某天的提醒；不存在时静默幂等。
  Future<void> removeClassReminder(String courseId, String date) async {
    final current = settings;
    final rest = current.classReminders
        .where(
          (existing) => !(existing.courseId == courseId && existing.date == date),
        )
        .toList();
    if (rest.length == current.classReminders.length) {
      return;
    }
    await updateSettings(current.copyWith(classReminders: rest));
    unawaited(_syncExamReminders());
  }

  // ---- 节假日相关 ----

  Future<void> _loadHolidayData() async {
    try {
      final now = DateTime.now();
      final data = await _holidayService.getDataForYear(now.year);
      var allEntries = <HolidayEntry>[...data.entries];
      // If semester spans two years, also load next year
      if (now.month >= 11) {
        final nextYearData = await _holidayService.getDataForYear(now.year + 1);
        allEntries.addAll(nextYearData.entries);
      }
      // Merge user-defined custom holidays
      final customEntries = await _holidayService.loadCustomHolidays();
      allEntries.addAll(customEntries);
      _holidayData = HolidayData(
        year: data.year,
        version: data.version,
        entries: allEntries,
      );
      notifyListeners();
      // Holiday data is not stored in timetable profiles; force home widget /
      // live schedule resync so desktop widgets pick up vacation days.
      await _syncSurfacesAfterHolidayDataChanged();
    } catch (_) {
      // Holiday data is non-critical; silently ignore failures
    }
  }

  /// Invalidate cached native surfaces and fully refresh live gate (stop island
  /// on holiday). Must not only sync schedule snapshot — that path leaves a
  /// running island session until the next resume/tick that happens to stop.
  Future<void> _syncSurfacesAfterHolidayDataChanged() async {
    _lastHomeWidgetSnapshotSignature = null;
    _lastLiveSnapshotSignature = null;
    _currentLiveCourseId = null;
    _lastLiveActivityStageKey = null;
    // Full body: home widget + schedule snapshot + stopLiveUpdate when holiday.
    await _updateLiveActivity();
  }

  /// 获取指定日期的节假日条目
  HolidayEntry? getHolidayForDate(DateTime date) {
    return _holidayData?.entryForDate(date);
  }

  /// 当前加载的节假日数据信息
  HolidayData? get holidayData => _holidayData;

  /// 节假日数据更新日志
  List<HolidayLogEntry> get holidayLogs => _holidayService.logs;

  /// Refresh holiday data (clear cache and reload)
  Future<void> refreshHolidayData() async {
    await _holidayService.clearCache(DateTime.now().year);
    await _loadHolidayData();
  }

  /// 用户自定义假期列表（不含远程/内置数据）
  Future<List<HolidayEntry>> getCustomHolidays() async {
    return _holidayService.loadCustomHolidays();
  }

  /// 新增一条自定义假期
  Future<void> addCustomHoliday(HolidayEntry entry) async {
    await _holidayService.addCustomHoliday(entry);
    await _loadHolidayData();
  }

  /// 批量新增自定义假期（单次 load → append → save，避免逐条写入的竞态问题）
  Future<void> addCustomHolidays(List<HolidayEntry> entries) async {
    final existing = await _holidayService.loadCustomHolidays();
    existing.addAll(entries);
    await _holidayService.saveCustomHolidays(existing);
    await _loadHolidayData();
  }

  /// 按 groupId 删除自定义假期
  Future<void> removeCustomHoliday(String groupId) async {
    await _holidayService.removeCustomHoliday(groupId);
    await _loadHolidayData();
  }

  /// 按 groupId 更新自定义假期
  Future<void> updateCustomHoliday(
    String groupId,
    List<HolidayEntry> newEntries,
  ) async {
    await _holidayService.updateCustomHoliday(groupId, newEntries);
    await _loadHolidayData();
  }

  /// 指定日期是否为假期（应隐藏课程）
  bool isHoliday(DateTime date) {
    // 调休上班日优先级最高，即使是假期覆盖模式也要显示课程
    if (_holidayData?.isAdjustedWorkday(date) ?? false) return false;
    if (_settings.holidayOverrideEnabled) return true;
    if (!_settings.enableHolidayMarking) return false;
    return _holidayData?.isHoliday(date) ?? false;
  }

  /// 指定日期是否为调休上班日
  bool isAdjustedWorkday(DateTime date) {
    return _holidayData?.isAdjustedWorkday(date) ?? false;
  }

  Future<bool> deleteCourseOccurrence({
    required String courseId,
    required int sourceWeek,
  }) {
    return _runMutation(
      () => _deleteCourseOccurrenceImpl(
        courseId: courseId,
        sourceWeek: sourceWeek,
      ),
    );
  }

  Future<bool> _deleteCourseOccurrenceImpl({
    required String courseId,
    required int sourceWeek,
  }) async {
    await initialize();
    final index = _courses.indexWhere((course) => course.id == courseId);
    if (index == -1) {
      throw ArgumentError('course_not_found_for_delete');
    }

    final originalCourse = _courses[index];
    if (!originalCourse.isInWeek(sourceWeek)) {
      throw ArgumentError(
        encodeServiceMessage('course_not_scheduled_week', {
          'sourceWeek': sourceWeek,
        }),
      );
    }

    final remainingWeeks =
        originalCourse.activeWeeks.where((week) => week != sourceWeek).toList()
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
            sessionNotes: originalCourse.sessionNotesExcludingWeek(sourceWeek),
          ),
        ),
      );
    }

    await _syncHomeworkTasksWithCourses();
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
  }) {
    return _runMutation(
      () => _rescheduleCourseOccurrenceImpl(
        courseId: courseId,
        sourceWeek: sourceWeek,
        targetWeek: targetWeek,
        targetDayOfWeek: targetDayOfWeek,
        targetStartSection: targetStartSection,
        targetEndSection: targetEndSection,
        targetLocation: targetLocation,
        targetTimeSchemeIdOverride: targetTimeSchemeIdOverride,
      ),
    );
  }

  Future<bool> _rescheduleCourseOccurrenceImpl({
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
      throw ArgumentError('course_not_found_for_reschedule');
    }

    final originalCourse = _courses[index];
    if (!originalCourse.isInWeek(sourceWeek)) {
      throw ArgumentError(
        encodeServiceMessage('course_not_scheduled_week', {
          'sourceWeek': sourceWeek,
        }),
      );
    }
    if (targetWeek < 1 || targetWeek > _settings.semesterWeekCount) {
      throw ArgumentError('target_week_out_of_range');
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
    final isNoop =
        sourceWeek == targetWeek &&
        originalCourse.dayOfWeek == targetDayOfWeek &&
        originalCourse.startSection == targetStartSection &&
        originalCourse.endSection == targetEndSection &&
        originalCourse.location == normalizedLocation &&
        originalCourse.timeSchemeIdOverride == normalizedTimeSchemeId;
    if (isNoop) {
      return false;
    }

    final remainingWeeks =
        originalCourse.activeWeeks.where((week) => week != sourceWeek).toList()
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
          sessionNotes: originalCourse.sessionNotesForSingleWeek(
            sourceWeek: sourceWeek,
            targetWeek: targetWeek,
          ),
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
            sessionNotes: originalCourse.sessionNotesExcludingWeek(sourceWeek),
          ),
        ),
      );
      _courses.add(movedOccurrence);
    }

    await _syncHomeworkTasksWithCourses();
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

  Future<bool> clearActiveProfileCourses() {
    return _runMutation(() => _clearActiveProfileCoursesImpl());
  }

  Future<bool> _clearActiveProfileCoursesImpl() async {
    await initialize();
    final clearedCourseCount = _courses.length;
    if (clearedCourseCount == 0) {
      return false;
    }

    _courses = [];
    _tasks.removeWhere((task) => task.courseId != null);
    await _persistActiveProfileState();
    _currentLiveCourseId = null;
    notifyListeners();
    _analytics.logEventLater(
      name: 'courses_cleared',
      parameters: {'cleared_course_count': clearedCourseCount},
    );
    await _updateLiveActivity();
    return true;
  }

  /// Persists home view mode / last viewed day without the full settings
  /// pipeline: no notifyListeners (the home State owns this UI state locally),
  /// no live-activity / native pref sync — nothing there reads these fields.
  ///
  /// Routing this through [updateTimetableSettings] made every day-view page
  /// switch broadcast a whole-app rebuild plus platform-channel work while the
  /// pager was still animating.
  Future<void> persistHomeViewState({
    required TimetableHomeViewMode mode,
    required int dayOfWeek,
  }) async {
    if (_settings.timetableHomeViewMode == mode &&
        _settings.timetableLastViewedDayOfWeek == dayOfWeek) {
      return;
    }
    _settings = _settings.copyWith(
      timetableHomeViewMode: mode,
      timetableLastViewedDayOfWeek: dayOfWeek,
    );
    await _persistActiveProfileState();
  }

  Future<String?> updateTimetableSettings(TimetableSettings settings) async {
    final sectionConfigChanged =
        settings.sectionCount != _settings.sectionCount ||
        _sectionSignature(settings.sections) !=
            _sectionSignature(_settings.sections) ||
        settings.activeTimeSchemeId != _settings.activeTimeSchemeId;

    if (sectionConfigChanged && settings.sectionCount < maxUsedSection) {
      return encodeServiceMessage('section_count_below_usage', {
        'requiredMaxSection': maxUsedSection,
      });
    }

    final previousBackdropPath = resolveHomePageBackdropImagePath(_settings);
    _settings = _normalizeSettingsWithTimeScheme(settings);
    hyperosSetEdgeHapticsEnabled(_settings.enableHaptics);
    _currentCalendarWeek = _resolveCurrentCalendarWeek();
    _currentDateWeek = clampCurrentWeekToSettings(
      _currentCalendarWeek,
      _settings,
    );
    await _persistActiveProfileState();
    unawaited(_syncNativeRuntimePreferences());
    _lastLiveSnapshotSignature = null;
    _currentLiveCourseId = null;
    if (resolveHomePageBackdropImagePath(_settings) != previousBackdropPath) {
      await precacheHomePageBackdropImage(_settings);
    }
    notifyListeners();
    unawaited(_syncLiveScheduleSnapshot());
    unawaited(_updateLiveActivity(syncScheduleSnapshot: false));
    return null;
  }

  int previewWakeUpImportRequiredSectionCount(
    String content, {
    required bool replaceExisting,
  }) => _timetablePreviewWakeUpImportRequiredSectionCount(
    this,
    content,
    replaceExisting: replaceExisting,
  );

  int previewImportedCourseRequiredSectionCount(
    List<Course> importedCourses, {
    required bool replaceExisting,
  }) => ImportExportLogic.previewImportedCourseRequiredSectionCount(
    importedCourses: importedCourses,
    currentSectionCount: _settings.sectionCount,
  );

  Future<String?> ensureSectionCapacityForImport(int requiredSectionCount) =>
      _timetableEnsureSectionCapacityForImport(this, requiredSectionCount);

  Future<int> importWakeUpCalendar(
    String content, {
    required bool replaceExisting,
  }) => _timetableImportWakeUpCalendar(
    this,
    content,
    replaceExisting: replaceExisting,
  );

  Future<int> importParsedCourses(
    List<Course> importedCourses, {
    required bool replaceExisting,
    DateTime? semesterStart,
    required String source,
    bool preserveLocalColors = true,
  }) => _timetableImportParsedCourses(
    this,
    importedCourses,
    replaceExisting: replaceExisting,
    semesterStart: semesterStart,
    source: source,
    preserveLocalColors: preserveLocalColors,
  );

  Future<String?> importAppDataBackup(String content) =>
      _timetableImportAppDataBackup(this, content);

  Future<String?> importAppDataBackupAsNewProfile(
    String content, {
    String? profileName,
  }) => _timetableImportAppDataBackupAsNewProfile(
    this,
    content,
    profileName: profileName,
  );

  Future<String?> importFullAppDataBackup(String content) =>
      _timetableImportFullAppDataBackup(this, content);

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
    // Stay within the user-configured semester length. Do not auto-expand
    // semesterWeekCount when the calendar has moved past the last teaching week.
    _currentCalendarWeek = week;
    _currentDateWeek = targetWeek > _settings.semesterWeekCount
        ? _settings.semesterWeekCount
        : targetWeek;
    await setCurrentWeek(
      targetWeek > _settings.semesterWeekCount
          ? _settings.semesterWeekCount
          : targetWeek,
    );
  }

  Future<bool> syncTemporalContext({DateTime? now}) {
    return _runMutation(() => _syncTemporalContextImpl(now: now));
  }

  Future<bool> _syncTemporalContextImpl({DateTime? now}) async {
    await initialize();
    final reference = now ?? DateTime.now();
    final targetDayOfWeek = reference.weekday;
    final targetCalendarWeek = _calculateCalendarWeekForDate(
      reference,
      fallbackWeek: _currentWeek,
    );
    final targetWeek = _calculateWeekForDate(
      reference,
      fallbackWeek: _currentWeek,
    );
    final didChangeWeek =
        _settings.semesterStartDate != null && targetWeek != _currentDateWeek;
    final didChangeCalendarWeek = targetCalendarWeek != _currentCalendarWeek;
    final didChangeDay = targetDayOfWeek != _currentDayOfWeek;

    // Seasonal bulk-apply must run even when week/day labels did not change
    // (e.g. cold start after midnight, or rule starts mid-session).
    final didApplySeasonal = await _applyDueScheduleDateRules(now: reference);

    if (!didChangeWeek && !didChangeCalendarWeek && !didChangeDay) {
      return didApplySeasonal;
    }

    _currentCalendarWeek = targetCalendarWeek;
    if (didChangeWeek) {
      _currentDateWeek = clampCurrentWeekToSettings(targetWeek, _settings);
    }
    if (didChangeDay) {
      _currentDayOfWeek = targetDayOfWeek;
    }

    // applyDueScheduleDateRules already notified if it mutated; still refresh
    // week/day surfaces when only temporal labels changed.
    if (!didApplySeasonal) {
      _currentLiveCourseId = null;
      notifyListeners();
      await _updateLiveActivity();
    } else {
      notifyListeners();
    }
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

    // Use isInWeek (respects customWeeks), not startWeek/endWeek envelope alone.
    // Warehouse imports often leave default 1–16 while customWeeks sits outside.
    if (week != null) {
      // Prefer isActiveInWeek so suspended weeks do not false-positive conflicts.
      return left.isActiveInWeek(week) && right.isActiveInWeek(week);
    }

    final candidateWeeks = <int>{
      ..._courseWeekCandidates(left),
      ..._courseWeekCandidates(right),
    };
    for (final candidateWeek in candidateWeeks) {
      if (left.isActiveInWeek(candidateWeek) &&
          right.isActiveInWeek(candidateWeek)) {
        return true;
      }
    }
    return false;
  }

  Set<int> _courseWeekCandidates(Course course) {
    final custom = course.normalizedCustomWeeks;
    if (custom != null && custom.isNotEmpty) {
      return custom.toSet();
    }
    final weeks = <int>{};
    final start = course.startWeek < 1 ? 1 : course.startWeek;
    final end = course.endWeek < start ? start : course.endWeek;
    for (var week = start; week <= end; week++) {
      weeks.add(week);
    }
    return weeks;
  }

  Course _normalizeCourse(Course course) {
    final trimmedDescription = course.description?.trim();
    final trimmedNote = course.note?.trim();
    final resolvedDescription =
        (trimmedDescription != null && trimmedDescription.isNotEmpty)
        ? trimmedDescription
        // Promote legacy per-entry note into the shared course description.
        : ((trimmedNote != null && trimmedNote.isNotEmpty)
              ? trimmedNote
              : null);
    final normalizedWeeks = Course.normalizeWeeks(
      startWeek: course.startWeek,
      endWeek: course.endWeek,
      maxWeek: _settings.semesterWeekCount,
    );
    return course.copyWith(
      name: course.name.trim(),
      shortName: course.shortName?.trim().isEmpty == true
          ? null
          : course.shortName?.trim(),
      teacher: course.teacher.trim(),
      location: course.location.trim(),
      description: resolvedDescription,
      note: (trimmedNote != null && trimmedNote.isNotEmpty)
          ? trimmedNote
          : null,
      startWeek: normalizedWeeks.startWeek,
      endWeek: normalizedWeeks.endWeek,
    );
  }

  ScheduleItem _normalizeScheduleItem(ScheduleItem item) {
    final normalizedStartDate = DateTime(
      item.startDate.year,
      item.startDate.month,
      item.startDate.day,
    );
    final normalizedEndDate = DateTime(
      item.endDate.year,
      item.endDate.month,
      item.endDate.day,
    );
    return item.copyWith(
      title: item.title.trim(),
      location: item.location?.trim().isEmpty == true
          ? null
          : item.location?.trim(),
      note: item.note?.trim().isEmpty == true ? null : item.note?.trim(),
      startDate: normalizedStartDate,
      endDate: normalizedEndDate.isBefore(normalizedStartDate)
          ? normalizedStartDate
          : normalizedEndDate,
    );
  }

  ScheduleItem? _findScheduleItem(String itemId) {
    for (final item in _scheduleItems) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }

  ScheduleItem? _findSeriesRoot(ScheduleItem? target) {
    if (target == null) {
      return null;
    }
    final rootId = target.seriesId ?? target.id;
    return _findScheduleItem(rootId);
  }

  ScheduleItemInstance? _findScheduleItemInstanceById(String occurrenceId) {
    for (final item in _scheduleItems) {
      if (item.id != occurrenceId) {
        continue;
      }
      if (item.seriesId != null) {
        final date = item.occurrenceDate ?? item.startDate;
        return ScheduleItemInstance(
          item: item,
          date: item.startDate,
          occurrenceDate: date,
        );
      }
      if (!item.isRecurring) {
        return ScheduleItemInstance(item: item, date: item.startDate);
      }
    }

    final separatorIndex = occurrenceId.lastIndexOf('@');
    if (separatorIndex <= 0 || separatorIndex == occurrenceId.length - 1) {
      return null;
    }
    final sourceId = occurrenceId.substring(0, separatorIndex);
    final date = DateTime.tryParse(occurrenceId.substring(separatorIndex + 1));
    final source = date == null ? null : _findScheduleItem(sourceId);
    if (source == null || date == null) {
      return null;
    }
    return ScheduleItemInstance(item: source, date: date);
  }

  bool _isOverrideForOccurrence(
    ScheduleItem item,
    String seriesId,
    DateTime occurrenceDate,
  ) {
    if (item.seriesId != seriesId) {
      return false;
    }
    final candidateDate = item.occurrenceDate ?? item.startDate;
    return _isSameDate(candidateDate, occurrenceDate);
  }

  DateTime _resolveOccurrenceEditDate({
    required ScheduleItem root,
    required DateTime occurrenceDate,
    required ScheduleItem updatedItem,
    required bool dateWasExplicitlyEdited,
  }) {
    final requestedDate = ScheduleItem.dateOnly(updatedItem.startDate);
    // A copy of the series item usually carries the series start date. Treat
    // that unchanged value as "keep this occurrence's date" unless the caller
    // explicitly reports that the date field was edited.
    if (!dateWasExplicitlyEdited &&
        _isSameDate(requestedDate, root.startDate)) {
      return ScheduleItem.dateOnly(occurrenceDate);
    }
    return requestedDate;
  }

  List<DateTime> _normalizedExceptionDates(
    List<DateTime> existing,
    DateTime candidate,
  ) {
    final normalizedCandidate = ScheduleItem.dateOnly(candidate);
    final merged = <String, DateTime>{};
    for (final date in existing) {
      final normalized = ScheduleItem.dateOnly(date);
      merged[ScheduleItem.formatCalendarDate(normalized)] = normalized;
    }
    merged[ScheduleItem.formatCalendarDate(normalizedCandidate)] =
        normalizedCandidate;
    final result = merged.values.toList()..sort((a, b) => a.compareTo(b));
    return result;
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  void _putScheduleInstanceByDisplayDate(
    Map<String, ScheduleItemInstance> instancesByDisplayDate,
    ScheduleItemInstance instance,
  ) {
    final key =
        '${instance.sourceItemId}@${ScheduleItem.formatCalendarDate(instance.date)}';
    final existing = instancesByDisplayDate[key];
    // The stable occurrence id keeps pointing at the original series date for
    // persistence, but a moved override wins when both items display on the
    // same actual date.
    if (existing == null ||
        (instance.isSeriesOverride && !existing.isSeriesOverride)) {
      instancesByDisplayDate[key] = instance;
    }
  }

  List<ScheduleItemInstance> _sortScheduleItemInstances(
    List<ScheduleItemInstance> source,
  ) {
    source.sort((left, right) {
      final dateCompare = left.date.compareTo(right.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      final sourceDateCompare = left.item.startDate.compareTo(
        right.item.startDate,
      );
      if (sourceDateCompare != 0) {
        return sourceDateCompare;
      }
      final startCompare = left.item.startTime.compareTo(right.item.startTime);
      if (startCompare != 0) {
        return startCompare;
      }
      final endCompare = left.item.endTime.compareTo(right.item.endTime);
      if (endCompare != 0) {
        return endCompare;
      }
      return left.occurrenceId.compareTo(right.occurrenceId);
    });
    return List.unmodifiable(source);
  }

  List<ScheduleItem> _sortScheduleItems(List<ScheduleItem> source) {
    source.sort((left, right) {
      final dateCompare = left.startDate.compareTo(right.startDate);
      if (dateCompare != 0) {
        return dateCompare;
      }
      final startCompare = left.startTime.compareTo(right.startTime);
      if (startCompare != 0) {
        return startCompare;
      }
      final endCompare = left.endTime.compareTo(right.endTime);
      if (endCompare != 0) {
        return endCompare;
      }
      return left.id.compareTo(right.id);
    });
    return source;
  }

  Course _applySharedCourseFields(Course target, Course source) {
    final sharedDescription = () {
      final description = source.description?.trim();
      if (description != null && description.isNotEmpty) {
        return description;
      }
      final legacyNote = source.note?.trim();
      if (legacyNote != null && legacyNote.isNotEmpty) {
        return legacyNote;
      }
      return null;
    }();
    // teacher (and location) are per-schedule-entry values: when a course name
    // is shared across multiple schedule times each slot keeps its own teacher.
    // Only genuinely shared/course-level metadata propagates here.
    return target.copyWith(
      name: source.name,
      shortName: source.shortName,
      color: source.color,
      textColor: source.textColor,
      courseNature: source.courseNature,
      description: sharedDescription,
    );
  }

  String _buildSharedCourseNameKey(String name) => name.trim().toLowerCase();

  String _sharedCourseKey(Course course) =>
      _buildSharedCourseNameKey(course.name);

  String _sharedCourseKeyFromName(String name) =>
      _buildSharedCourseNameKey(name);

  int _calculateWeekForDate(DateTime date, {int? fallbackWeek}) {
    final semesterStart = _settings.semesterStartDate;
    if (semesterStart == null) {
      return fallbackWeek ?? _currentWeek;
    }

    final week = getWeekIndex(date, semesterStart);
    if (week == null) return 1;
    if (week > _settings.semesterWeekCount) return _settings.semesterWeekCount;
    return week;
  }

  /// Real calendar week for [date] without clamping to [semesterWeekCount].
  ///
  /// UI week display clamps so users can stay on the last configured week after
  /// the term ends. Live activity must use the calendar week so courses past
  /// their [Course.endWeek] are not shown again (each school may use a
  /// different [semesterWeekCount]).
  int _calculateCalendarWeekForDate(DateTime date, {int? fallbackWeek}) {
    final semesterStart = _settings.semesterStartDate;
    if (semesterStart == null) {
      return fallbackWeek ?? _currentWeek;
    }

    final week = getWeekIndex(date, semesterStart);
    if (week == null) return 0; // 学期开始前返回 0，避免课程提前显示
    return week;
  }

  int _resolveCurrentCalendarWeek() {
    if (_settings.semesterStartDate == null) {
      return _currentWeek;
    }
    return _calculateCalendarWeekForDate(
      DateTime.now(),
      fallbackWeek: _currentWeek,
    );
  }

  int _resolveCurrentDateWeek() {
    return clampCurrentWeekToSettings(_resolveCurrentCalendarWeek(), _settings);
  }

  DateTime _startOfWeek(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return normalizedDate.subtract(Duration(days: normalizedDate.weekday - 1));
  }

  List<Course> getCoursesForDay(int dayOfWeek, {int? week}) {
    final targetWeek = week ?? _currentWeek;
    return _courses
        .where(
          (course) =>
              course.dayOfWeek == dayOfWeek && course.isInWeek(targetWeek),
        )
        .toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
  }

  /// 获取指定天的有效课程（排除停课），用于小组件和超级岛
  List<Course> getActiveCoursesForDay(int dayOfWeek, {int? week}) {
    final targetWeek = week ?? _currentWeek;
    return _courses
        .where(
          (course) =>
              course.dayOfWeek == dayOfWeek &&
              course.isActiveInWeek(targetWeek),
        )
        .toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
  }

  List<Course> getTodayCourses({DateTime? now}) {
    // After the term ends, UI currentDateWeek is clamped to semesterWeekCount.
    // "Today's courses" must use the real calendar week so finished courses do
    // not keep appearing every weekday that matches the last teaching week.
    final reference = now ?? DateTime.now();
    final targetWeek = _settings.semesterStartDate == null
        ? _currentDateWeek
        : _calculateCalendarWeekForDate(reference);
    return getCoursesForDay(_currentDayOfWeek, week: targetWeek);
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
    final courses = getCoursesInProgress(
      dayOfWeek: dayOfWeek,
      week: week,
      now: now,
    );
    return courses.isEmpty ? null : courses.first;
  }

  List<Course> getCoursesInProgress({
    required int dayOfWeek,
    int? week,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final targetWeek = week ?? _calculateWeekForDate(reference);
    final currentMinutes = reference.hour * 60 + reference.minute;
    final matches = <Course>[];

    for (final course in getCoursesForDay(dayOfWeek, week: targetWeek)) {
      final startMinutes = LiveActivityLogic.parseClockMinutes(
        LiveActivityLogic.resolveRealTime(
          course,
          true,
          _resolveSectionsForCourse(course),
        ),
      );
      final endMinutes = LiveActivityLogic.parseClockMinutes(
        LiveActivityLogic.resolveRealTime(
          course,
          false,
          _resolveSectionsForCourse(course),
        ),
      );
      if (startMinutes == null || endMinutes == null) {
        continue;
      }
      if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
        matches.add(resolveCourseDisplayName(course));
      }
    }
    return matches;
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

  List<Map<String, dynamic>> buildLiveProgressMilestones(
    Course course, {
    int? startAtMillis,
    int? endAtMillis,
  }) => LiveActivityLogic.buildLiveProgressMilestones(
    course,
    _resolveSectionsForCourse(course),
    startAtMillis: startAtMillis,
    endAtMillis: endAtMillis,
  );

  List<int> buildLiveProgressBreakOffsetsMillis(
    Course course, {
    int? startAtMillis,
    int? endAtMillis,
  }) => LiveActivityLogic.buildLiveProgressBreakOffsetsMillis(
    course,
    _resolveSectionsForCourse(course),
    startAtMillis: startAtMillis,
    endAtMillis: endAtMillis,
  );

  LiveActivityCourseSelection? getLiveActivityCourseSelection({
    DateTime? now,
    bool allowUpcomingFallback = false,
    int? week,
  }) => _liveGetActivityCourseSelection(
    this,
    now: now,
    allowUpcomingFallback: allowUpcomingFallback,
    week: week,
  );

  LiveActivityCourseSelection? getTestLiveActivityCourseSelection({
    DateTime? now,
  }) => _liveGetTestActivityCourseSelection(this, now: now);

  HomeWidgetSnapshot? buildHomeWidgetSnapshot({DateTime? now}) =>
      _liveBuildHomeWidgetSnapshot(this, now: now);

  void suspendLiveActivitySyncFor(Duration duration) {
    _liveActivitySuspendedUntil = DateTime.now().add(duration);
  }

  /// Clears a temporary live-sync pause (e.g. leftover from older test helpers).
  void clearLiveActivitySyncSuspend() {
    _liveActivitySuspendedUntil = null;
  }

  Future<void> refreshLiveActivityNow({bool forceSnapshotSync = false}) =>
      _liveRefreshNow(this, forceSnapshotSync: forceSnapshotSync);

  void updateCurrentDayOfWeek() {
    unawaited(syncTemporalContext());
  }

  Future<PartnerImportResult> importPartnerTimetable(
    String content, {
    String? partnerName,
  }) {
    return _runMutation(() async {
      await initialize();
      final result = await _partnerTimetableService.importFromContent(
        content,
        partnerName: partnerName,
      );
      _profiles = await _storageService.getProfiles();
      _partnerBinding = result.binding;
      notifyUserDataChangedForSync();
      notifyListeners();
      return result;
    });
  }

  Future<void> updatePartnerWeekOffset(int offset) {
    // 与其他用户写入一致走 mutation 门：避免与云恢复/LAN 应用等
    // 门内写者交错读写 _partnerBinding（check-then-act 竞态）。
    return _runMutation(() async {
      await initialize();
      final binding = _partnerBinding;
      if (binding == null) {
        return;
      }
      final clamped = CoupleTimetableLogic.clampWeekOffset(offset);
      if (clamped == binding.weekOffset) {
        return;
      }
      _partnerBinding = binding.copyWith(weekOffset: clamped);
      await _storageService.savePartnerTimetableBinding(_partnerBinding);
      notifyUserDataChangedForSync();
      notifyListeners();
    });
  }

  Future<void> updatePartnerCoupleColors({
    String? mineColorHex,
    String? partnerColorHex,
    String? togetherColorHex,
  }) {
    // 同 updatePartnerWeekOffset：纳入 mutation 门串行化。
    return _runMutation(() async {
      await initialize();
      final binding = _partnerBinding;
      if (binding == null) {
        return;
      }
      _partnerBinding = binding.copyWith(
        mineColorHex: mineColorHex,
        partnerColorHex: partnerColorHex,
        togetherColorHex: togetherColorHex,
      );
      await _storageService.savePartnerTimetableBinding(_partnerBinding);
      notifyUserDataChangedForSync();
      notifyListeners();
    });
  }

  Future<void> unlinkPartner() {
    return _runMutation(() async {
      await initialize();
      await _partnerTimetableService.unlink();
      _profiles = await _storageService.getProfiles();
      _partnerBinding = null;
      if (_activeProfileId == PartnerTimetableService.partnerProfileId) {
        final fallback = _profiles
            .where((profile) => !profile.isPartnerImported)
            .firstOrNull;
        if (fallback != null) {
          _activeProfileId = fallback.id;
          _applyProfileState(fallback);
          await _storageService.setActiveProfileId(fallback.id);
          unawaited(_syncExamReminders());
        }
      }
      notifyUserDataChangedForSync();
      notifyListeners();
    });
  }
}
