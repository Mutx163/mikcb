import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../models/course.dart';
import '../../models/exam.dart';
import '../../models/schedule_item.dart';
import '../../utils/course_group.dart';

/// 表单页 / 管理页的构造器签名（2026-10-20 泳道 B 阶段 3a）。
///
/// 这些页面**都要带上下文**（点日程卡要预填那节课、点考试卡要预填那场考试），
/// 所以不能像八宫格那样用无参 `Widget Function()`——参数原样透传，一个都不能丢。
/// 丢参数的后果不是「页面打不开」，而是「打开了但表单是空的」，用户会以为数据没了。
typedef CourseFormBuilder =
    Widget Function({
      Course? initialCourse,
      CourseGroup? courseGroup,
      int? initialWeek,
      int? initialDayOfWeek,
      int? initialStartSection,
      int? initialEndSection,
    });

typedef ExamFormBuilder = Widget Function({Exam? exam});

typedef ScheduleItemFormBuilder =
    Widget Function({
      ScheduleItem? scheduleItem,
      DateTime? initialDate,
      DateTime? occurrenceDate,
    });

typedef TimeSchemeManagementBuilder = Widget Function({
  String? initialEditSchemeId,
});

typedef AboutUpdateBuilder = Widget Function({
  required PackageInfo packageInfo,
});

/// widgets 层需要的「表单页怎么造」接口：**只描述，不实现**。
///
/// 实现住 screens 层（`lib/screens/timetable_form_pages_impl.dart`），由
/// `TimetableScreen.initState` 经 [registerTimetableFormPages] 注入。widgets
/// 侧因此不再 import 任何 `screens/*` 表单页——`widgets → screens` 那批反向
/// 依赖是真的没了（方向反过来：screens 组装 widgets 天经地义，见裁定 R1，
/// 没有把 import 搬进任何被度量跳过的目录）。
///
/// 与八宫格路由表（`home_menu_route_catalog`）共用同一套注入时机，但两者
/// **形态不同**：那个是「无参造页 + 按 id 查」，这里是「带上下文造页 +
/// 按函数调」，所以没有合并成一张表。
class TimetableFormPages {
  const TimetableFormPages({
    required this.courseForm,
    required this.examForm,
    required this.scheduleItemForm,
    required this.timeSchemeManagement,
    required this.aboutUpdate,
  });

  /// 加课/改课表单（`AddCourseScreen`）。
  ///
  /// 两种典型调用：日视图/周网格的课程卡展开进编辑页（传 `initialCourse` +
  /// `courseGroup`），首页「+」弹层的添加课程（传 `initialWeek` /
  /// `initialDayOfWeek`）。
  final CourseFormBuilder courseForm;

  /// 考试表单（`AddExamScreen`）；`exam` 为 null 是新建。
  final ExamFormBuilder examForm;

  /// 日程表单（`AddScheduleItemScreen`）。
  ///
  /// `initialDate` 与 `occurrenceDate` 是两条不同的入口：前者来自首页「+」
  /// 弹层（新建，只给日期），后者来自点击某一次日程（编辑单次覆盖，要带
  /// 那一次的 occurrenceDate）。**两者不能互相顶替**。
  final ScheduleItemFormBuilder scheduleItemForm;

  /// 作息方案管理页（`TimeSchemeManagementScreen`）。
  final TimeSchemeManagementBuilder timeSchemeManagement;

  /// 更新详情页（`AboutUpdateScreen`）。`PackageInfo` 由调用方自己取——
  /// 取包信息+`mounted` 判断是导航语义，留在 widgets 侧不动。
  final AboutUpdateBuilder aboutUpdate;
}

TimetableFormPages? _pages;

/// 注入实现。调用点在 `TimetableScreen.initState`，与八宫格路由表同一处。
///
/// 幂等：测试会在同一进程里多次挂首页，重复注入以最后一次为准。
void registerTimetableFormPages(TimetableFormPages pages) {
  _pages = pages;
}

/// 取实现。未注入时**抛 StateError**，不给「空表单页」这种静默降级：
///
/// 拿不到实现只会在「首页还没挂载就先点了某张卡」时发生。此时若静默返回一个
/// 空容器，用户看到的是「点了没反应」或「表单全空」，比直接报错难查一个数量级。
TimetableFormPages get timetableFormPages {
  final pages = _pages;
  if (pages == null) {
    throw StateError(
      'timetable_form_pages: 表单页实现尚未注入（registerTimetableFormPages）。'
      '生产侧由 TimetableScreen.initState 注入，早于任何议程卡渲染。',
    );
  }
  return pages;
}
