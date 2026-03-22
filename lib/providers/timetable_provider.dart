import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../services/data_transfer_service.dart';
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

enum LiveActivityStage {
  beforeClass,
  duringClass,
  beforeEnd,
}

class TimetableProvider with ChangeNotifier {
  static const Duration _liveEndReminderWindow = Duration(minutes: 10);

  final StorageService _storageService = StorageService();
  final IcsImportService _icsImportService = IcsImportService();
  final MiuiLiveActivitiesService _liveActivitiesService =
      MiuiLiveActivitiesService();
  final DataTransferService _dataTransferService = DataTransferService();

  List<Course> _courses = [];
  TimetableSettings _settings = TimetableSettings.defaults();
  int _currentWeek = 1;
  int _currentDayOfWeek = DateTime.now().weekday;
  bool _isLoading = false;
  Timer? _liveActivityTimer;
  String? _currentLiveCourseId;
  DateTime? _liveActivitySuspendedUntil;

  List<Course> get courses => _courses;
  TimetableSettings get settings => _settings;
  int get currentWeek => _currentWeek;
  int get currentDayOfWeek => _currentDayOfWeek;
  bool get isLoading => _isLoading;
  DateTime? get semesterStartDate => _settings.semesterStartDate;
  DataTransferService get dataTransferService => _dataTransferService;
  int get maxUsedSection => _courses.isEmpty
      ? 1
      : _courses
          .map((course) => course.endSection)
          .reduce((a, b) => a > b ? a : b);

  TimetableProvider() {
    _init();
  }

  Future<void> _init() async {
    await _storageService.init();
    await loadSettings();
    await loadCourses();
    await loadCurrentWeek();
    _startLiveActivityTick();
  }

  void _startLiveActivityTick() {
    _liveActivityTimer?.cancel();
    _updateLiveActivity();
    _liveActivityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateLiveActivity();
    });
  }

  @override
  void dispose() {
    _liveActivityTimer?.cancel();
    super.dispose();
  }

  Future<void> loadSettings() async {
    try {
      _settings = await _storageService.getTimetableSettings();
      final semesterStart = await _storageService.getSemesterStart();
      if (semesterStart != null && _settings.semesterStartDate == null) {
        _settings = _settings.copyWith(semesterStartDate: semesterStart);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading timetable settings: $e');
    }
  }

  Future<void> loadCourses() async {
    _isLoading = true;
    notifyListeners();

    try {
      _courses = await _storageService.getCourses();
    } catch (e) {
      debugPrint('Error loading courses: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCurrentWeek() async {
    try {
      _currentWeek = await _storageService.getCurrentWeek();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading current week: $e');
    }
  }

  Future<void> setCurrentWeek(int week) async {
    _currentWeek = week;
    await _storageService.setCurrentWeek(week);
    notifyListeners();
    return;
    // ignore: dead_code
    _currentLiveCourseId = null; // 触发超级岛重刷
    notifyListeners();
    _updateLiveActivity();
  }

  Future<void> addCourse(Course course) async {
    await _storageService.addCourse(course);
    _courses.add(course);
    _currentLiveCourseId = null;
    notifyListeners();
    _updateLiveActivity();
  }

  Future<void> updateCourse(Course course) async {
    await _storageService.updateCourse(course);
    final index = _courses.indexWhere((c) => c.id == course.id);
    if (index != -1) {
      _courses[index] = course;
      _currentLiveCourseId = null;
      notifyListeners();
      _updateLiveActivity();
    }
  }

  Future<void> deleteCourse(String courseId) async {
    await _storageService.deleteCourse(courseId);
    _courses.removeWhere((c) => c.id == courseId);
    _currentLiveCourseId = null;
    notifyListeners();
    _updateLiveActivity();
  }

  Future<String?> updateTimetableSettings(TimetableSettings settings) async {
    if (settings.sectionCount < maxUsedSection) {
      return '节次数量不能小于当前已使用的最大节次（第$maxUsedSection节）';
    }

    _settings = settings;
    await _storageService.saveTimetableSettings(settings);
    if (settings.semesterStartDate != null) {
      await _storageService.setSemesterStart(settings.semesterStartDate!);
    }
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
    if (result.courses.isEmpty) {
      return 0;
    }

    final mergedCourses =
        replaceExisting ? result.courses : [..._courses, ...result.courses];

    _courses = mergedCourses;
    await _storageService.saveCourses(_courses);
    await _storageService.setSemesterStart(result.semesterStart);
    _settings = _settings.copyWith(semesterStartDate: result.semesterStart);
    await _storageService.saveTimetableSettings(_settings);
    _currentLiveCourseId = null;
    notifyListeners();
    await _updateLiveActivity();
    return result.courses.length;
  }

  Future<String?> importAppDataBackup(String content) async {
    try {
      final backup = _dataTransferService.parseBackupJson(content);
      _courses = backup.courses;
      _settings = backup.settings;
      _currentWeek = backup.currentWeek;

      await _storageService.saveCourses(_courses);
      await _storageService.saveTimetableSettings(_settings);
      await _storageService.setCurrentWeek(_currentWeek);
      if (_settings.semesterStartDate != null) {
        await _storageService.setSemesterStart(_settings.semesterStartDate!);
      } else {
        await _storageService.clearSemesterStart();
      }

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
    final normalizedNow = DateTime(now.year, now.month, now.day);
    final normalizedStart = DateTime(
      semesterStart.year,
      semesterStart.month,
      semesterStart.day,
    );
    final week = (normalizedNow.difference(normalizedStart).inDays ~/ 7) + 1;
    await setCurrentWeek(week < 1 ? 1 : week);
  }

  int _calculateWeekForDate(DateTime date) {
    final semesterStart = _settings.semesterStartDate;
    if (semesterStart == null) {
      return _currentWeek;
    }

    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(
      semesterStart.year,
      semesterStart.month,
      semesterStart.day,
    );
    final week = (normalizedDate.difference(normalizedStart).inDays ~/ 7) + 1;
    return week < 1 ? 1 : week;
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
          currentTime.compareTo(course.endTime) <= 0) {
        return course;
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

    final firstSectionIndex = course.startSection - 1;
    final lastSectionIndex = course.endSection - 1;
    if (firstSectionIndex < 0 || lastSectionIndex >= _settings.sections.length) {
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
        _parseClockMinutes(_settings.sections[firstSectionIndex].startTime);
    final sectionEndMinutes =
        _parseClockMinutes(_settings.sections[lastSectionIndex].endTime);
    if (sectionStartMinutes == null ||
        sectionEndMinutes == null ||
        sectionEndMinutes <= sectionStartMinutes) {
      return const [];
    }

    final referenceTotalMinutes = sectionEndMinutes - sectionStartMinutes;
    final totalDurationMillis = resolvedEndAtMillis - resolvedStartAtMillis;
    final milestones = <Map<String, dynamic>>[];

    for (var sectionIndex = firstSectionIndex; sectionIndex < lastSectionIndex; sectionIndex++) {
      final currentSection = _settings.sections[sectionIndex];
      final nextSection = _settings.sections[sectionIndex + 1];
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
    final sectionIndex = (isStart ? course.startSection : course.endSection) - 1;
    if (sectionIndex >= 0 && sectionIndex < _settings.sections.length) {
      return isStart 
          ? _settings.sections[sectionIndex].startTime 
          : _settings.sections[sectionIndex].endTime;
    }
    return isStart ? course.startTime : course.endTime;
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
      final startTime = _buildCourseDateTime(currentTime, _resolveRealTime(course, true));
      final endTime = _buildCourseDateTime(currentTime, _resolveRealTime(course, false));
      if (startTime == null || endTime == null) {
        continue;
      }

      final aheadTime = startTime.subtract(
        Duration(minutes: _settings.liveShowBeforeClassMinutes),
      );
      final stage = _resolveLiveActivityStage(
        currentTime: currentTime,
        startTime: startTime,
        endTime: endTime,
        aheadTime: aheadTime,
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
      final startTime = _buildCourseDateTime(currentTime, _resolveRealTime(course, true));
      if (startTime == null || !startTime.isAfter(currentTime)) {
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
        final candidateStart =
            _buildCourseDateTime(candidateDate, _resolveRealTime(course, true));
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

  Future<void> _updateLiveActivity() async {
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
      final settings = _settings;
      final nextCourse = selection!.nextCourse;
      final nextCourseKey = nextCourse != null ? '${nextCourse.id}:${nextCourse.name}:${nextCourse.startSection}' : 'null';
      final liveActivityKey = '${liveCourse.id}:${selection.stage.name}:${liveCourse.name}:${liveCourse.startSection}:${liveCourse.endSection}:${liveCourse.location}:${liveCourse.teacher}:$nextCourseKey:${settings.hashCode}';
      if (_currentLiveCourseId == liveActivityKey) {
        return; // 防抖，避免频繁唤起 Android 服务
      }
      _currentLiveCourseId = liveActivityKey;

      final displayCourse = liveCourse.copyWith(
        startTime: _resolveRealTime(liveCourse, true),
        endTime: _resolveRealTime(liveCourse, false),
      );
      final displayNextCourse = selection.nextCourse == null
          ? null
          : selection.nextCourse!.copyWith(
              startTime: _resolveRealTime(selection.nextCourse!, true),
              endTime: _resolveRealTime(selection.nextCourse!, false),
            );
      final startAtMillis = _buildCourseDateTime(DateTime.now(), _resolveRealTime(displayCourse, true))
          ?.millisecondsSinceEpoch;
      final endAtMillis = _buildCourseDateTime(DateTime.now(), _resolveRealTime(displayCourse, false))
          ?.millisecondsSinceEpoch;
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
        endSecondsCountdownThreshold: settings.liveEndSecondsCountdownThreshold,
        promoteDuringClass: settings.livePromoteDuringClass,
        showNotificationDuringClass: settings.liveShowDuringClassNotification,
        enableBeforeClass: settings.liveEnableBeforeClass,
        enableDuringClass: settings.liveEnableDuringClass,
        enableBeforeEnd: settings.liveEnableBeforeEnd,
        showCountdown: settings.liveShowCountdown,
        showCourseNameInIsland: settings.liveShowCourseName,
        showLocationInIsland: settings.liveShowLocation,
        useShortNameInIsland: settings.liveUseShortName,
        hidePrefixText: settings.liveHidePrefixText,
        progressBreakOffsetsMillis: progressBreakOffsetsMillis,
        progressMilestoneLabels:
            progressMilestones.map((milestone) => milestone['label'] as String).toList(),
        progressMilestoneTimeTexts:
            progressMilestones.map((milestone) => milestone['timeText'] as String).toList(),
      );
    } else {
      if (_currentLiveCourseId != null) {
        _currentLiveCourseId = null;
        await _liveActivitiesService.stopLiveUpdate();
      }
    }
  }

  void suspendLiveActivitySyncFor(Duration duration) {
    _liveActivitySuspendedUntil = DateTime.now().add(duration);
  }

  void updateCurrentDayOfWeek() {
    final newDay = DateTime.now().weekday;
    if (newDay != _currentDayOfWeek) {
      _currentDayOfWeek = newDay;
      _currentLiveCourseId = null;
      notifyListeners();
      _updateLiveActivity();
    }
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
      return null;
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
      case LiveActivityStage.duringClass:
        return _settings.liveEnableDuringClass &&
            (_settings.livePromoteDuringClass ||
                _settings.liveShowDuringClassNotification);
      case LiveActivityStage.beforeEnd:
        return _settings.liveEnableDuringClass;
    }
  }
}
