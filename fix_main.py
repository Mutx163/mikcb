import os

file_path = "lib/providers/timetable_provider.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add _resolveRealTime helper before getLiveActivityCourseSelection
helper_code = """
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
"""

content = content.replace("  LiveActivityCourseSelection? getLiveActivityCourseSelection({\n", helper_code, 1)

# 2. Fix getLiveActivityCourseSelection (first loop)
old_loop_1 = """      final startTime = _buildCourseDateTime(currentTime, course.startTime);
      final endTime = _buildCourseDateTime(currentTime, course.endTime);"""
new_loop_1 = """      final startTime = _buildCourseDateTime(currentTime, _resolveRealTime(course, true));
      final endTime = _buildCourseDateTime(currentTime, _resolveRealTime(course, false));"""
content = content.replace(old_loop_1, new_loop_1, 1)

# 3. Fix getLiveActivityCourseSelection (second loop)
old_loop_2 = """      final startTime = _buildCourseDateTime(currentTime, course.startTime);
      if (startTime == null || !startTime.isAfter(currentTime)) {"""
new_loop_2 = """      final startTime = _buildCourseDateTime(currentTime, _resolveRealTime(course, true));
      if (startTime == null || !startTime.isAfter(currentTime)) {"""
content = content.replace(old_loop_2, new_loop_2, 1)

# 4. Fix getTestLiveActivityCourseSelection
old_loop_3 = """        final candidateStart =
            _buildCourseDateTime(candidateDate, course.startTime);"""
new_loop_3 = """        final candidateStart =
            _buildCourseDateTime(candidateDate, _resolveRealTime(course, true));"""
content = content.replace(old_loop_3, new_loop_3, 1)

# 5. Fix _updateLiveActivity debounce and time logic
old_update = """    if (liveCourse != null) {
      final liveActivityKey = '${liveCourse.id}:${selection!.stage.name}';
      if (_currentLiveCourseId == liveActivityKey) {
        return; // 防抖，避免频繁唤起 Android 服务
      }
      _currentLiveCourseId = liveActivityKey;

      final settings = _settings;
      final displayCourse = liveCourse;
      final displayNextCourse = selection.nextCourse;
      final startAtMillis = _buildCourseDateTime(DateTime.now(), displayCourse.startTime)
          ?.millisecondsSinceEpoch;
      final endAtMillis = _buildCourseDateTime(DateTime.now(), displayCourse.endTime)
          ?.millisecondsSinceEpoch;"""

new_update = """    if (liveCourse != null) {
      final settings = _settings;
      final nextCourse = selection!.nextCourse;
      final nextCourseKey = nextCourse != null ? '${nextCourse.id}:${nextCourse.name}:${nextCourse.startSection}' : 'null';
      final liveActivityKey = '${liveCourse.id}:${selection.stage.name}:${liveCourse.name}:${liveCourse.startSection}:${liveCourse.endSection}:${liveCourse.location}:${liveCourse.teacher}:$nextCourseKey:${settings.hashCode}';
      if (_currentLiveCourseId == liveActivityKey) {
        return; // 防抖，避免频繁唤起 Android 服务
      }
      _currentLiveCourseId = liveActivityKey;

      final displayCourse = liveCourse;
      final displayNextCourse = selection.nextCourse;
      final startAtMillis = _buildCourseDateTime(DateTime.now(), _resolveRealTime(displayCourse, true))
          ?.millisecondsSinceEpoch;
      final endAtMillis = _buildCourseDateTime(DateTime.now(), _resolveRealTime(displayCourse, false))
          ?.millisecondsSinceEpoch;"""
content = content.replace(old_update, new_update, 1)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Patched timetable_provider.dart successfully")
