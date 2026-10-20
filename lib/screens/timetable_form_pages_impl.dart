import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/course.dart';
import '../models/exam.dart';
import '../models/schedule_item.dart';
import '../utils/course_group.dart';
import '../widgets/timetable/timetable_form_pages.dart';
import 'add_course_screen.dart';
import 'add_exam_screen.dart';
import 'add_schedule_item_screen.dart';
import 'about_screen.dart';
import 'time_scheme_management_screen.dart';

/// 表单页 / 管理页的实现（2026-10-20 泳道 B 阶段 3a）。
///
/// ## 为什么这个文件在 screens 层
///
/// 页面构造必须由**上层**持有：`screens → widgets` 合法（页面组装控件），
/// `widgets → screens` 违规。日视图议程卡、周网格议程卡、「+」添加弹层原先
/// 直接 import 三个 add_* 表单页，构成 8 条反向依赖；把构造搬到这里之后，
/// widgets 侧只拿到一个 `TimetableFormPages` 接口（函数签名在
/// `widgets/timetable/timetable_form_pages.dart`），不再认识任何页面类型。
///
/// 这不是「把 import 挪进度量免检目录」：本文件在 `lib/screens/`，
/// `local/dep_graph.py` 照常把它算进 screens 层并逐条判定。裁定 R1 禁止的是
/// `lib/controllers/` 那种被 `CROSS_CUTTING` 跳过、边还在只是账上不见的搬法。
///
/// ## 参数为什么必须逐个透传
///
/// 这批页面的**全部价值就在上下文**：点课程的日程卡进编辑页要带着那门课、
/// 点考试卡要带着那场考试、点某次日程要带着 occurrenceDate。任何一个参数在
/// 这层被吞掉，用户看到的都是「打开了，但表单是空的」——比页面打不开更糟，
/// 因为那看起来像数据丢了。所以这里的每个具名参数都与页面构造函数一一对应，
/// 不做「取个默认值」的简化。
const TimetableFormPages kTimetableFormPages = TimetableFormPages(
  courseForm: _buildCourseForm,
  examForm: _buildExamForm,
  scheduleItemForm: _buildScheduleItemForm,
  timeSchemeManagement: _buildTimeSchemeManagement,
  aboutUpdate: _buildAboutUpdate,
);

Widget _buildCourseForm({
  Course? initialCourse,
  CourseGroup? courseGroup,
  int? initialWeek,
  int? initialDayOfWeek,
  int? initialStartSection,
  int? initialEndSection,
}) {
  return AddCourseScreen(
    initialCourse: initialCourse,
    courseGroup: courseGroup,
    initialWeek: initialWeek,
    initialDayOfWeek: initialDayOfWeek,
    initialStartSection: initialStartSection,
    initialEndSection: initialEndSection,
  );
}

Widget _buildExamForm({Exam? exam}) => AddExamScreen(exam: exam);

Widget _buildScheduleItemForm({
  ScheduleItem? scheduleItem,
  DateTime? initialDate,
  DateTime? occurrenceDate,
}) {
  return AddScheduleItemScreen(
    scheduleItem: scheduleItem,
    initialDate: initialDate,
    occurrenceDate: occurrenceDate,
  );
}

Widget _buildTimeSchemeManagement({String? initialEditSchemeId}) {
  return TimeSchemeManagementScreen(initialEditSchemeId: initialEditSchemeId);
}

Widget _buildAboutUpdate({required PackageInfo packageInfo}) {
  return AboutUpdateScreen(packageInfo: packageInfo);
}
