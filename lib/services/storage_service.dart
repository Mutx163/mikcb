import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';
import '../models/timetable_settings.dart';

class StorageService {
  static const String _coursesKey = 'courses';
  static const String _currentWeekKey = 'current_week';
  static const String _semesterStartKey = 'semester_start';
  static const String _timetableSettingsKey = 'timetable_settings';

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
}
