import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../services/storage_service.dart';
import '../services/ics_import_service.dart';
import '../services/miui_live_activities_service.dart';

class TimetableProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final IcsImportService _icsImportService = IcsImportService();
  final MiuiLiveActivitiesService _liveActivitiesService = MiuiLiveActivitiesService();

  List<Course> _courses = [];
  TimetableSettings _settings = TimetableSettings.defaults();
  int _currentWeek = 1;
  int _currentDayOfWeek = DateTime.now().weekday;
  bool _isLoading = false;

  List<Course> get courses => _courses;
  TimetableSettings get settings => _settings;
  int get currentWeek => _currentWeek;
  int get currentDayOfWeek => _currentDayOfWeek;
  bool get isLoading => _isLoading;
  DateTime? get semesterStartDate => _settings.semesterStartDate;
  int get maxUsedSection => _courses.isEmpty
      ? 1
      : _courses.map((course) => course.endSection).reduce((a, b) => a > b ? a : b);

  TimetableProvider() {
    _init();
  }

  Future<void> _init() async {
    await _storageService.init();
    await loadSettings();
    await loadCourses();
    await loadCurrentWeek();
    _startLiveActivityIfAvailable();
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
      print('Error loading timetable settings: $e');
    }
  }

  Future<void> loadCourses() async {
    _isLoading = true;
    notifyListeners();

    try {
      _courses = await _storageService.getCourses();
    } catch (e) {
      print('Error loading courses: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCurrentWeek() async {
    try {
      _currentWeek = await _storageService.getCurrentWeek();
      notifyListeners();
    } catch (e) {
      print('Error loading current week: $e');
    }
  }

  Future<void> setCurrentWeek(int week) async {
    _currentWeek = week;
    await _storageService.setCurrentWeek(week);
    notifyListeners();
    _updateLiveActivity();
  }

  Future<void> addCourse(Course course) async {
    await _storageService.addCourse(course);
    _courses.add(course);
    notifyListeners();
    _updateLiveActivity();
  }

  Future<void> updateCourse(Course course) async {
    await _storageService.updateCourse(course);
    final index = _courses.indexWhere((c) => c.id == course.id);
    if (index != -1) {
      _courses[index] = course;
      notifyListeners();
      _updateLiveActivity();
    }
  }

  Future<void> deleteCourse(String courseId) async {
    await _storageService.deleteCourse(courseId);
    _courses.removeWhere((c) => c.id == courseId);
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
    notifyListeners();
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

    final mergedCourses = replaceExisting
        ? result.courses
        : [..._courses, ...result.courses];

    _courses = mergedCourses;
    await _storageService.saveCourses(_courses);
    await _storageService.setSemesterStart(result.semesterStart);
    _settings = _settings.copyWith(semesterStartDate: result.semesterStart);
    await _storageService.saveTimetableSettings(_settings);
    notifyListeners();
    await _updateLiveActivity();
    return result.courses.length;
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

  List<Course> getCoursesForDay(int dayOfWeek) {
    return _courses.where((course) => 
      course.dayOfWeek == dayOfWeek && course.isInWeek(_currentWeek)
    ).toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
  }

  List<Course> getTodayCourses() {
    return getCoursesForDay(_currentDayOfWeek);
  }

  Course? getCurrentCourse() {
    final todayCourses = getTodayCourses();
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
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
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    for (final course in todayCourses) {
      if (currentTime.compareTo(course.startTime) < 0) {
        return course;
      }
    }
    return null;
  }

  Future<void> _startLiveActivityIfAvailable() async {
    final currentCourse = getCurrentCourse();
    final nextCourse = getNextCourse();
    
    if (currentCourse != null) {
      await _liveActivitiesService.startLiveUpdate(currentCourse, nextCourse);
    }
  }

  Future<void> _updateLiveActivity() async {
    final currentCourse = getCurrentCourse();
    final nextCourse = getNextCourse();
    
    if (currentCourse != null) {
      await _liveActivitiesService.startLiveUpdate(currentCourse, nextCourse);
    } else {
      await _liveActivitiesService.stopLiveUpdate();
    }
  }

  void updateCurrentDayOfWeek() {
    final newDay = DateTime.now().weekday;
    if (newDay != _currentDayOfWeek) {
      _currentDayOfWeek = newDay;
      notifyListeners();
      _updateLiveActivity();
    }
  }
}
