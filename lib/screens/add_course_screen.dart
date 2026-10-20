import 'dart:async';

import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../domain/course_domain.dart';
import '../models/course.dart';
import '../models/time_scheme.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/app_log_service.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';
import '../widgets/course_palette_sheet.dart';
import '../widgets/course_field_picker_sheet.dart';
import '../widgets/course_template_picker_sheet.dart';
import '../ui/hyperos/hyperos.dart';
import 'add_course_week_picker_tiles.dart';
import '../widgets/miuix_number_picker_sheet.dart';
import '../widgets/time_scheme_picker_sheet.dart';

/// 「按范围选周」叠加单/双周时，这门课究竟排在哪些周。
///
/// 本仓认可同时勾上单周与双周（`isOddWeek` 与 `isEvenWeek` 可以都为 true，
/// 两个筛选条件是按周逐个 continue 的），所以两种情况会算出**空集**：
/// ① 范围收在一周上（开始周 == 结束周）又只勾了与之相反的那一侧 ——
/// 例如第 2 周 + 单周；② 单周与双周同时勾上（每一条都被某个条件滤掉）。
/// 空集存进去后 `Course.activeWeeks`/`isInWeek` 对任何一周都是 false：
/// **这门课在课表上任何一周都不出现**，却仍留在数据里、仍计入统计与伴侣同步，
/// 而当时界面报的是"添加成功"。
///
/// 抽成公有纯函数有两个理由：① 摘要显示（`_buildEntryWeeksFromRange`）与弹层里的
/// 临时计算原先各抄了一份同样的循环，两份都可能出现"过滤做一半"；
/// ② 空集这件事必须由**确定按钮与保存校验共用同一个判据**拦住，
/// 不能只在自定义模式上挡（`selectedCustomWeeks.isEmpty`）。
List<int> weeksFromRangeSelection({
  required int startWeek,
  required int endWeek,
  required bool isOddWeek,
  required bool isEvenWeek,
}) {
  final weeks = <int>[];
  for (var week = startWeek; week <= endWeek; week++) {
    if (isOddWeek && week.isEven) {
      continue;
    }
    if (isEvenWeek && week.isOdd) {
      continue;
    }
    weeks.add(week);
  }
  return weeks;
}

/// 新建条目时周次范围的默认值（一门课默认从第 1 周排到第 16 周）。
/// 抽出来是因为"表单初值"有两处要写同一个默认（`_ScheduleEntryData` 的形参默认值
/// 与 initState 的新建分支），而 `initialWeek` 传进来时起始周要跟着那一周走。
const int _defaultEntryStartWeek = 1;
const int _defaultEntryEndWeek = 16;


/// 这门课能选到哪些节次。
///
/// 必须跟着**这门课自己的**节次表走，与改课弹层里那份 `_sectionNumbers`
/// （`course_followup_sheets.dart:306-333`，第 6 轮修的同一处）同一口径：
/// 保存时算钟点（`_resolveEntryTimeScheme` → `CourseDomain.editCourseClock`）与
/// `validateCourseTimeSchemeOverride` 校验用的都是解析出来的那份模板，
/// 而 `settings.sectionCount` 是**全局**作息的节数。
///
/// 用全局数会出两种错：模板比全局长时那几节压根选不到；更糟的是
/// 「结束节次」的 `minValue` 取的是课程现存的 `startSection`，一旦它大于全局节数
/// （课程钉着 12 节模板、全局只有 10 节，`TimeSchemeLogic` 对越界节次原样保留），
/// `showMiuixNumberPickerSheet` 的 `currentValue.clamp(minValue, maxValue)`
/// （`miuix_number_picker_sheet.dart:20`）会直接抛 ArgumentError ——
/// 点那一行在 release 里毫无反应、在 debug 里断言崩。
/// 因此候选集是"该课模板的 1..N"并上"课程现存的起止节次"，回写一定能落回范围内。
List<int> editableSectionNumbers({
  required int globalSectionCount,
  int? courseSchemeSectionCount,
  required int currentStartSection,
  required int currentEndSection,
}) {
  final count =
      courseSchemeSectionCount == null || courseSchemeSectionCount <= 0
      ? globalSectionCount
      : courseSchemeSectionCount;
  final numbers = <int>{
    for (var index = 1; index <= count; index++) index,
    if (currentStartSection >= 1) currentStartSection,
    if (currentEndSection >= 1) currentEndSection,
  }.toList()..sort();
  return numbers;
}

class AddCourseScreen extends StatefulWidget {
  final Course? course;
  final CourseGroup? courseGroup;
  final Course? initialCourse;
  final int? initialDayOfWeek;
  final int? initialStartSection;

  /// 从课表虚线框进来时框住的末节次（含）：框拉到几节，表单就预填几节。
  final int? initialEndSection;
  final int? initialWeek;

  const AddCourseScreen({
    super.key,
    this.course,
    this.courseGroup,
    this.initialCourse,
    this.initialDayOfWeek,
    this.initialStartSection,
    this.initialEndSection,
    this.initialWeek,
  });

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _ScheduleEntryData {
  String id;
  int dayOfWeek;
  int startSection;
  int endSection;
  String teacher;
  String location;
  int startWeek;
  int endWeek;
  bool isOddWeek;
  bool isEvenWeek;
  WeekSelectionMode weekSelectionMode;
  Set<int> selectedCustomWeeks;
  List<int>? suspendedWeeks;
  String? note;
  Map<int, CourseSessionNote>? sessionNotes;
  String? timeSchemeIdOverride;

  /// 编辑既有课程时带来的那一份原值。
  ///
  /// 只用于把适配脚本/教务导入钉住的权威钟点（`Course.hasCustomTime`）
  /// 穿过"按节次算钟点"的保存流程，见 [CourseDomain.editCourseClock]。
  Course? originalCourse;

  _ScheduleEntryData({
    required this.id,
    this.dayOfWeek = 1,
    this.startSection = 1,
    this.endSection = 2,
    this.teacher = '',
    this.location = '',
    this.startWeek = _defaultEntryStartWeek,
    this.endWeek = _defaultEntryEndWeek,
    this.isOddWeek = false,
    this.isEvenWeek = false,
    this.weekSelectionMode = WeekSelectionMode.range,
    Set<int>? selectedCustomWeeks,
    this.suspendedWeeks,
    this.note,
    this.sessionNotes,
    this.timeSchemeIdOverride,
    this.originalCourse,
  }) : selectedCustomWeeks = selectedCustomWeeks ?? <int>{};

  static _ScheduleEntryData fromCourse(Course course) {
    final customWeeks = course.normalizedCustomWeeks;
    return _ScheduleEntryData(
      id: course.id,
      dayOfWeek: course.dayOfWeek,
      startSection: course.startSection,
      endSection: course.endSection,
      teacher: course.teacher,
      location: course.location,
      startWeek: course.startWeek,
      endWeek: course.endWeek,
      isOddWeek: course.isOddWeek,
      isEvenWeek: course.isEvenWeek,
      weekSelectionMode: customWeeks != null
          ? WeekSelectionMode.custom
          : WeekSelectionMode.range,
      selectedCustomWeeks: customWeeks?.toSet() ?? <int>{},
      suspendedWeeks: course.normalizedSuspendedWeeks,
      note: course.note,
      sessionNotes: course.sessionNotes,
      timeSchemeIdOverride: course.timeSchemeIdOverride,
      originalCourse: course,
    );
  }

  Course toCourse({
    required String name,
    String? shortName,
    required String color,
    required CourseNature courseNature,
    String? description,
    required String startTime,
    required String endTime,
    bool hasCustomTime = false,
  }) {
    List<int>? customWeeks;
    if (weekSelectionMode == WeekSelectionMode.custom &&
        selectedCustomWeeks.isNotEmpty) {
      customWeeks = selectedCustomWeeks.toList()..sort();
    }
    return Course(
      id: id,
      name: name,
      shortName: shortName,
      teacher: teacher,
      location: location,
      dayOfWeek: dayOfWeek,
      startSection: startSection,
      endSection: endSection,
      startTime: startTime,
      endTime: endTime,
      hasCustomTime: hasCustomTime,
      color: color,
      startWeek: customWeeks == null ? startWeek : customWeeks.first,
      endWeek: customWeeks == null ? endWeek : customWeeks.last,
      isOddWeek: customWeeks == null ? isOddWeek : false,
      isEvenWeek: customWeeks == null ? isEvenWeek : false,
      customWeeks: customWeeks,
      suspendedWeeks: suspendedWeeks,
      courseNature: courseNature,
      description: description,
      note: note,
      sessionNotes: sessionNotes,
      timeSchemeIdOverride: timeSchemeIdOverride,
    );
  }
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _teacherController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  CourseNature _courseNature = CourseNature.required;
  String _selectedColor = '#2196F3';
  List<_ScheduleEntryData> _scheduleEntries = [];
  final List<TextEditingController> _entryTeacherControllers = [];
  final List<TextEditingController> _entryLocationControllers = [];

  /// 本页是「新建一门课」而不是「编辑一门已存在的课」。
  ///
  /// 两条入口传的东西不同：新建只带初始星期/节次/周次（`course` 与 `courseGroup`
  /// 都是 null），编辑则**至少**会带 `course`（从月历/待办进）或 `courseGroup`
  /// （从课程总览、课表、统计页进）。判断「编辑」必须把两者都算上——只看
  /// `widget.course` 会把「总览 → 编辑」当成新建。
  bool get _isCreatingNewCourse =>
      widget.course == null && widget.courseGroup == null;

  /// 保存进行中：期间禁止再次保存。
  ///
  /// 保存键在顶栏，一次成功要跑完落盘才关页；没有这个闸时连点两下 = 存两遍 +
  /// 弹两次「已保存」+ `pop` 两次（第二次把下面那页也弹掉）。
  bool _saving = false;

  /// 用户改动过内容（用于返回时决定要不要问「放弃修改？」）。
  ///
  /// 只在新建页有意义：编辑页同样适用，判据是「与进来时的初值不同」。
  bool _dirty = false;

  /// 记一次改动。所有能改变表单结果的操作都要调它（输入、选值、加/删排课记录）。
  void _markDirty() {
    if (!_dirty) {
      setState(() => _dirty = true);
    }
  }

  List<String> _weekdayLabels(AppLocalizations l10n) => [
    l10n.weekdayMon,
    l10n.weekdayTue,
    l10n.weekdayWed,
    l10n.weekdayThu,
    l10n.weekdayFri,
    l10n.weekdaySat,
    l10n.weekdaySun,
  ];

  Color _parseColor(String colorHex) {
    return parseHexColorOrFallback(colorHex, fallback: const Color(0xFF2196F3));
  }

  @override
  void initState() {
    super.initState();
    {
      if (widget.courseGroup != null) {
        // Editing existing group: load shared fields from the first course.
        final courses = widget.courseGroup!.courses;
        // Put the tapped course first so it's immediately visible.
        final ordered = widget.initialCourse != null
            ? [
                widget.initialCourse!,
                ...courses.where((c) => c.id != widget.initialCourse!.id),
              ]
            : courses;
        final first = ordered.first;
        _nameController.text = first.name;
        _shortNameController.text = first.shortName ?? '';
        _descriptionController.text = first.description ?? first.note ?? '';
        _courseNature = first.courseNature;
        _selectedColor = first.color;
        // Build per-schedule entries from all courses.
        _scheduleEntries = ordered.map(_ScheduleEntryData.fromCourse).toList();
      } else if (widget.course != null) {
        // Editing a single existing course in group mode: wrap as one entry.
        _loadCourseData(widget.course!);
        _scheduleEntries = [_ScheduleEntryData.fromCourse(widget.course!)];
      } else {
        // Adding new course: start with one empty schedule entry.
        // `initialWeek` 是课表虚线框/空格带进来的那一周（timetable_screen.dart:7344、
        // :8832、:9751 与 task_list_screen.dart:272 都在传），原先这个分支根本不读它：
        // 在第 8 周的空格里加课，周次仍是 1..16，用户不改就从第 1 周开始排课，
        // 而 `initialDayOfWeek` / `initialStartSection` 两个同族参数都是生效的。
        final initialStartWeek = widget.initialWeek ?? _defaultEntryStartWeek;
        _scheduleEntries = [
          _ScheduleEntryData(
            id: const Uuid().v4(),
            dayOfWeek: widget.initialDayOfWeek ?? 1,
            startSection: widget.initialStartSection ?? 1,
            endSection:
                widget.initialEndSection ??
                (widget.initialStartSection ?? 1) + 1,
            startWeek: initialStartWeek,
            // 结束周不能低于起始周，否则第 33 轮那道"空集不许保存"的守卫会把
            // 这张表单直接锁死。
            endWeek: initialStartWeek > _defaultEntryEndWeek
                ? initialStartWeek
                : _defaultEntryEndWeek,
          ),
        ];
      }
      for (final entry in _scheduleEntries) {
        _entryTeacherControllers.add(
          TextEditingController(text: entry.teacher),
        );
        _entryLocationControllers.add(
          TextEditingController(text: entry.location),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    _teacherController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    for (final c in _entryTeacherControllers) {
      c.dispose();
    }
    for (final c in _entryLocationControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final settings = provider.settings;

    return PopScope(
      // 改过内容就先问一句再走：这张表单没有自动保存、也没有撤销，
      // 顶栏返回键与系统返回手势原先都是直接关页——误触一下填了半天的
      // 名称/周次/教室全没了。没改过东西时不打扰（canPop 直接放行）。
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        unawaited(_confirmDiscardAndPop());
      },
      child: HyperosSubpage(
        // 顶栏返回键走同一道闸：`onBack` 自己 pop 会绕过 PopScope，
        // 所以这里改成 `maybePop`，由上面那条 `canPop` 统一判定。
        onBack: _handleBackPress,
        title: Text(_resolveTitle()),
        suffixes: [
          if (widget.courseGroup != null)
            FHeaderAction(
              icon: const Icon(Icons.delete_outline_rounded),
              semanticsLabel: l10n.deleteCourseTitle,
              onPress: _confirmDeleteGroup,
            )
          else if (widget.course != null)
            FHeaderAction(
              icon: const Icon(Icons.delete_outline_rounded),
              semanticsLabel: l10n.deleteCourseTitle,
              onPress: _confirmDeleteCourse,
            ),
          FHeaderAction(
            icon: const Icon(Icons.check_rounded),
            semanticsLabel: _saving ? l10n.savingAction : l10n.saveAction,
            // 保存中置空 onPressed：`MiuixIconButton` 对 null 会转成禁用态
            // （不触发、不显示按压反馈），这是这个按钮唯一可用的禁用手段。
            onPress: _saving ? null : () => _saveCourse(provider, settings),
          ),
        ],
        child: Form(
          key: _formKey,
          child: _buildGroupEditingBody(provider, settings),
        ),
      ),
    );
  }

  /// 顶栏返回键：交给 [PopScope] 判「要不要问」。
  void _handleBackPress() {
    if (!mounted) {
      return;
    }
    Navigator.maybePop(context);
  }

  /// 有未保存改动时确认一次；确认后直接关页（此时 `_dirty` 已清，不会再问）。
  Future<void> _confirmDiscardAndPop() async {
    if (_saving) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final discard = await showHyperosConfirmDialog(
      context: context,
      title: l10n.courseFormDiscardTitle,
      message: l10n.courseFormDiscardMessage,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.courseFormDiscardAction,
      destructive: true,
    );
    if (discard != true || !mounted) {
      return;
    }
    _dirty = false;
    Navigator.pop(context);
  }

  Future<void> _confirmDeleteCourse() async {
    final course = widget.course;
    if (course == null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.deleteCourseTitle,
      message: l10n.confirmDeleteCourseMessage(course.name),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );

    if (confirmed != true || !mounted) {
      return;
    }

    // provider 侧落盘失败会**回滚内存并 rethrow**（`course_repository.dart` 的
    // `_timetableDeleteCourse`）。这里不接这个异常就是三件事同时发生：错误落进
    // zone 成为未处理异步错误、用户零提示，而确认弹窗已经关掉 ——
    // 用户看到的就是「点了删除，什么也没发生」。失败必须说出来，且不报成功、不关页。
    try {
      await context.read<TimetableProvider>().deleteCourse(course.id);
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.deleteFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.courseDeleted,
      kind: AppToastKind.success,
    );
    Navigator.pop(context);
  }

  void _loadCourseData(Course course) {
    _nameController.text = course.name;
    _shortNameController.text = course.shortName ?? '';
    _teacherController.text = course.teacher;
    _locationController.text = course.location;
    _descriptionController.text = course.description ?? course.note ?? '';
    _courseNature = course.courseNature;
    _selectedColor = course.color;
  }

  String _resolveTitle() {
    final l10n = AppLocalizations.of(context)!;
    return widget.courseGroup != null || widget.course != null
        ? l10n.editCourseTitle
        : l10n.addCourseTitle;
  }

  // ---------------------------------------------------------------------------
  // Teacher / Location picker — see [showCourseFieldPickerSheet]
  // ---------------------------------------------------------------------------

  /// Shows a time scheme picker bottom sheet.
  ///
  /// [currentValue] is the currently selected time scheme override ID
  /// (null means "follow profile").
  /// [onSelected] is called when the user picks a scheme (null = follow profile).
  // ---------------------------------------------------------------------------
  // Group editing UI
  // ---------------------------------------------------------------------------

  List<Widget> _withSpacing(List<Widget> children, {double spacing = 16}) {
    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        spaced.add(SizedBox(height: spacing));
      }
      spaced.add(children[index]);
    }
    return spaced;
  }

  Widget _buildPickerTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onPress,
    bool isPlaceholder = false,
  }) {
    return HyperosListTile(
      icon: icon,
      title: label,
      details: isPlaceholder ? null : value,
      onTap: onPress,
    );
  }

  Future<void> _pickFromSelectSheet({
    required String title,
    required Map<String, int> items,
    required int currentValue,
    required ValueChanged<int> onSelected,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showHyperosSelectSheet<int>(
      context: context,
      title: title,
      items: items,
      currentValue: currentValue,
      cancelLabel: l10n.cancelAction,
    );
    if (!mounted || selected == null || selected == currentValue) {
      return;
    }
    onSelected(selected);
  }

  /// Miuix wheel sheet for numeric ranges (sections / weeks) — same picker as
  /// the semester week count sheet on the settings home page.
  Future<void> _pickFromNumberWheelSheet({
    required String title,
    required int currentValue,
    required int minValue,
    required int maxValue,
    required String Function(int value) label,
    required ValueChanged<int> onSelected,
  }) async {
    final selected = await showMiuixNumberPickerSheet(
      context,
      title: title,
      currentValue: currentValue,
      minValue: minValue,
      maxValue: maxValue,
      label: label,
    );
    if (!mounted || selected == null || selected == currentValue) {
      return;
    }
    onSelected(selected);
  }

  Widget _buildGroupEditingBody(
    TimetableProvider provider,
    TimetableSettings settings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosListView(
      children: [
        _buildGroupSharedInfoSection(provider, l10n),
        const HyperosSectionGap(),
        _buildScheduleEntriesSection(provider, settings, l10n),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildGroupSharedInfoSection(
    TimetableProvider provider,
    AppLocalizations l10n,
  ) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;
    // 版式依据 flutter_miuix 原生规矩（不是自创画法）：
    // - 文本输入走 MiuixTextField 的**框内浮动标签**（label 参数），标签在框里、
    //   聚焦/有内容时缩到 10px 上浮；不给它外挂「框上方小标签」。
    // - 需要「点开选一项」的行走偏好行（标签在左、值在右 + 箭头）。
    // 2026-10-20 收紧（用户：「很空旷、很杂、很烦躁」）：性质+颜色并排一行、
    // 撤常驻说明灰字、节间距收到 8；详见提交信息与
    // .agents/notes/implemented/feature/2026-10-20-course-shared-info-compact.md。
    return HyperosControlCard(
      edgeToEdge: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HyperosControlCardScope.defaultHorizontalPadding,
              HyperosControlCardScope.defaultHorizontalPadding,
              HyperosControlCardScope.defaultHorizontalPadding,
              0,
            ),
            // 卡头：标题独占一行，那句「同步给同名排课」放到下一行整宽。
            //
            // 原先它挤在标题右侧（`Row` + `Flexible` + `maxLines: 1`），21 个字
            // 在半屏宽里必然被省略号切断——切掉的恰恰是本卡唯一重要的规则
            // （改一门课的简称/颜色/性质/简介会同步给所有同名排课）。
            // 一行放不下就换行，比留个看得见却读不全的残句好。
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sharedInfoTitle,
                  // 卡标题必须≥卡内条目标题：原先这里 14sp，卡内「沿用已有课程」
                  // 是 17sp，层级是倒挂的（卡名比里面的一行还小）。
                  style: HyperosTypography.title(context),
                ),
                const SizedBox(height: HyperosTokens.titleCaptionGap),
                Text(
                  l10n.sharedInfoInlineHint,
                  style: typo.xs.copyWith(color: colors.mutedForeground),
                ),
              ],
            ),
          ),
          // 「沿用已有课程」只在**新建**时出现（`course` 与 `courseGroup` 都为空）。
          //
          // 原先判据只写了 `widget.course == null`，而「课程总览 → 编辑」这条入口
          // 传的是 `courseGroup`、`course` 为 null，于是编辑一门已存在的课时这行
          // 照样出现——点一下就把整门课的名称、颜色、性质、教师、教室全换成
          // 另一门课的，中间没有确认。注释说的是「编辑时换一门课不是一个操作」，
          // 判据没跟上。
          if (_isCreatingNewCourse)
            HyperosListTile(
              title: l10n.reuseExistingCourseLabel,
              subtitle: l10n.reuseExistingCourseHelper,
              onTap: () => _showCourseTemplateSheet(provider),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HyperosControlCardScope.defaultHorizontalPadding,
              HyperosControlCardScope.defaultHorizontalPadding,
              HyperosControlCardScope.defaultHorizontalPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _withSpacing([
                _buildCourseNameField(provider, l10n),
                _buildShortNameField(l10n),
              ], spacing: 12),
            ),
          ),
          // 性质 + 颜色：一行两条。两者都是短值偏好行，合并省掉一整行高度，
          // 也让「这门课是个什么样的东西」（名/简称/性质/颜色）在视觉上成为
          // 一组，而不是被两个整行控件隔开。
          const SizedBox(height: 8),
          _buildNatureAndColorRow(l10n),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HyperosControlCardScope.defaultHorizontalPadding,
              8,
              HyperosControlCardScope.defaultHorizontalPadding,
              HyperosControlCardScope.defaultBodyBottomInset,
            ),
            child: HyperosTextField(
              controller: _descriptionController,
              label: l10n.courseDescriptionOptional,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => _markDirty(),
            ),
          ),
        ],
      ),
    );
  }

  /// 「课程性质 + 课程颜色」并排一行。
  ///
  /// 两条各自保留 Miuix 偏好行语义（标签 + 值 + 箭头、整块可点），只是把
  /// 「一整行一条」换成「一行两条」：性质值最长四个字（必修/选修/限选…），
  /// 颜色值固定 7 字符色值，等分宽度都放得下。
  Widget _buildNatureAndColorRow(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HyperosControlCardScope.defaultHorizontalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: HyperosCompactPreferenceField(
              key: const ValueKey('course-nature-field'),
              label: l10n.courseNatureLabel,
              value: courseNatureLabel(l10n, _courseNature),
              onTap: _showNatureSheet,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: HyperosCompactPreferenceField(
              key: const ValueKey('course-color-field'),
              label: l10n.courseColorTitle,
              value: _selectedColor.toUpperCase(),
              onTap: _showFullColorPalette,
              leading: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _parseColor(_selectedColor),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: HyperosColors.outline(context)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNatureSheet() {
    final l10n = AppLocalizations.of(context)!;
    return _pickFromSelectSheet(
      title: l10n.courseNatureLabel,
      items: {
        for (final item in CourseNature.values)
          courseNatureLabel(l10n, item): item.index,
      },
      currentValue: _courseNature.index,
      onSelected: (index) {
        setState(() => _courseNature = CourseNature.values[index]);
        _markDirty();
      },
    );
  }

  void _autofillShortNameFromCourseName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() {
      _shortNameController.text = name.characters.take(2).string;
    });
  }

  Widget _buildCourseNameField(
    TimetableProvider provider,
    AppLocalizations l10n,
  ) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    return FormField<String>(
      validator: (value) {
        final name = (value ?? _nameController.text).trim();
        if (name.isEmpty) {
          return l10n.pleaseEnterCourseName;
        }
        return null;
      },
      builder: (field) {
        final helperText = field.hasError
            ? field.errorText
            : l10n.courseNameHelper;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标签走 MiuixTextField 的框内浮动标签；「沿用已有课程」已上移为
            // 本卡顶部的偏好行，输入框恢复整行宽度。
            HyperosTextField(
              controller: _nameController,
              label: l10n.courseNameLabel,
              textInputAction: TextInputAction.next,
              onChanged: (value) {
                field.didChange(value);
                _markDirty();
              },
            ),
            // 2026-10-20：常驻的「同名排课会归为同一门课」收进卡片标题右侧的
            // 一句明话（sharedInfoInlineHint，同一信息只说一次），框下只在
            // **校验失败**时出现红字。原先两处说明常驻，一屏灰字比字段还多。
            if (field.hasError) ...[
              const SizedBox(height: 6),
              Text(
                helperText!,
                style: typo.xs2.copyWith(
                  color: colors.destructive,
                  height: 1.35,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildShortNameField(AppLocalizations l10n) {
    final colors = context.theme.colors;

    return HyperosTextField(
      controller: _shortNameController,
      label: l10n.courseShortNameOptional,
      textInputAction: TextInputAction.next,
      onChanged: (_) => _markDirty(),
      // 就地补全放框内末尾（MiuixTextField.trailingIcon），不再用框外按钮
      // 挤窄输入宽度。
      trailing: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        // 「建议 3 字内」这类提示走 tooltip：真需要时点一下就看到，
        // 不需要时不再常驻占一整行灰字。
        tooltip: '${l10n.courseShortNameAutoFillAction} · '
            '${l10n.courseShortNameHelper}',
        onPressed: _autofillShortNameFromCourseName,
        icon: Icon(
          Icons.auto_fix_high_rounded,
          size: 20,
          color: colors.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildScheduleConflictLinks(int index, AppLocalizations l10n) {
    final entry = _scheduleEntries[index];
    final provider = context.read<TimetableProvider>();
    final partners = provider.courseConflictMap[entry.id] ?? const <Course>[];
    if (partners.isEmpty) {
      return const SizedBox.shrink();
    }

    // HyperOS preference-row style (not a custom alert banner):
    // title + optional tag + detail + chevron; whole row is the action.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (
          var partnerIndex = 0;
          partnerIndex < partners.length;
          partnerIndex++
        )
          Padding(
            padding: EdgeInsets.only(top: partnerIndex == 0 ? 4 : 8),
            child: _ScheduleConflictPartnerRow(
              partner: partners[partnerIndex],
              onOpen: () => _openPartnerSchedule(partners[partnerIndex]),
            ),
          ),
      ],
    );
  }

  void _openPartnerSchedule(Course partner) {
    CourseGroup? group;
    for (final candidate in context.read<TimetableProvider>().courseGroups) {
      if (candidate.courses.any((course) => course.id == partner.id)) {
        group = candidate;
        break;
      }
    }
    if (group == null || !mounted) {
      return;
    }
    Navigator.of(context).push(
      HyperosPageRoute(
        settings: const RouteSettings(name: '/course/edit-partner'),
        builder: (_) =>
            AddCourseScreen(courseGroup: group, initialCourse: partner),
      ),
    );
  }

  Widget _buildScheduleEntriesSection(
    TimetableProvider provider,
    TimetableSettings settings,
    AppLocalizations l10n,
  ) {
    final hasMultipleEntries = _scheduleEntries.length > 1;
    return HyperosControlCard(
      title: hasMultipleEntries
          ? l10n.scheduleEntryTitle(1).replaceFirst(RegExp(r'\s?1$'), '')
          : l10n.scheduleEntrySingleTitle,
      subtitle: l10n.scheduleEntryCardSubtitle,
      child: HyperosControlCardInset(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _scheduleEntries.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _buildScheduleEntryFields(provider, settings, i, l10n),
            ],
            if (_scheduleEntries.isNotEmpty) const SizedBox(height: 8),
            _buildAddScheduleEntryButton(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleEntryFields(
    TimetableProvider provider,
    TimetableSettings settings,
    int index,
    AppLocalizations l10n,
  ) {
    final entry = _scheduleEntries[index];
    final weekDays = _weekdayLabels(l10n);
    final availableWeeks = settings.availableWeeks;
    final teacherText = _entryTeacherControllers[index].text;
    final locationText = _entryLocationControllers[index].text;
    // 候选节次跟着这门课解析出的作息模板，理由见 editableSectionNumbers。
    final sectionNumbers = editableSectionNumbers(
      globalSectionCount: settings.sectionCount,
      courseSchemeSectionCount: _resolveEntryTimeScheme(
        provider,
        entry,
        locationOverride: locationText,
      )?.sections.length,
      currentStartSection: entry.startSection,
      currentEndSection: entry.endSection,
    );
    final hasMultipleEntries = _scheduleEntries.length > 1;
    final entrySelectedWeeks = _selectedWeeksFor(entry);
    final entryWeekSummary = _selectedWeeksSummaryText(
      entrySelectedWeeks,
      availableWeeks,
      entry.startWeek,
      entry.endWeek,
      entry.isOddWeek,
      entry.isEvenWeek,
      entry.weekSelectionMode,
      l10n,
    );

    final entryFields = _withSpacing([
      _buildScheduleTimeRow(
        weekDays: weekDays,
        sectionNumbers: sectionNumbers,
        entry: entry,
        l10n: l10n,
      ),
      _buildCompactWeekSummaryRow(
        label: l10n.scheduleEntryWeeksSectionTitle,
        summary: entryWeekSummary,
        onTap: () => _showEntryWeekPickerDialog(entry, availableWeeks, l10n),
      ),
      _buildResponsiveFieldPair(
        spacing: 8,
        leading: _buildCompactPickerField(
          label: l10n.teacherLabel,
          value: teacherText.isEmpty ? l10n.manualInputLabel : teacherText,
          isPlaceholder: teacherText.isEmpty,
          onPress: () => showCourseFieldPickerSheet(
            context,
            title: l10n.selectTeacherTitle,
            suggestions: provider.uniqueTeachers,
            controller: _entryTeacherControllers[index],
            onConfirmed: () {
              setState(() {
                entry.teacher = _entryTeacherControllers[index].text;
                _dirty = true;
              });
            },
          ),
        ),
        trailing: _buildCompactPickerField(
          label: l10n.locationLabel,
          value: locationText.isEmpty ? l10n.manualInputLabel : locationText,
          isPlaceholder: locationText.isEmpty,
          onPress: () => showCourseFieldPickerSheet(
            context,
            title: l10n.selectLocationTitle,
            suggestions: provider.uniqueLocations,
            controller: _entryLocationControllers[index],
            onConfirmed: () {
              setState(() {
                entry.location = _entryLocationControllers[index].text;
                _dirty = true;
              });
            },
          ),
        ),
      ),
      _buildEntryTimeSchemeField(provider, index, l10n, compact: true),
      // 删除入口已上移到本条记录的标题行（右侧「删除」），不再单占一行：
      // 多条排课时每行一条删除按钮，既省 50dp/条，也让「删哪一条」与
      // 「这是第几条」在同一处，不用先看标题再往下找按钮。
      _buildScheduleConflictLinks(index, l10n),
    ], spacing: 8);

    if (!hasMultipleEntries) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entryFields,
      );
    }

    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final courseColor = parseHexColorOrFallback(
      _selectedColor,
      fallback: colors.primary,
    );
    final weekdayLabel =
        weekDays[entry.dayOfWeek.clamp(1, weekDays.length) - 1];
    // 单节课（起 == 止）不写成「第 8～8 节」：那是空区间读法，
    // 用户看到的是「这节课上了一个什么都不包含的区间」。
    final sectionText = entry.startSection == entry.endSection
        ? l10n.sectionLabel(entry.startSection)
        : l10n.sectionRangeLabel(entry.startSection, entry.endSection);
    final timePreview = '$weekdayLabel · $sectionText';

    // 多条排课记录之间**不套灰底**（用户 2026-10-28：「如果有多个的话，
    // 怎么变成灰色的了，只有一个排课记录的时候还挺好看」）。
    //
    // 原先每条记录包一层 5% 黑的内衬容器，多条时整块读作一片死灰、把卡片
    // 本身的白底吃掉。现在改成「与卡片同色 + 一条细分隔线 + 编号徽标」：
    // 分隔靠线不靠底色，卡片保持通透；编号（1/2/3）与「排课记录 N」标题
    // 本就在，区分度不靠底色也够（用户原话：「你也不用改成分不清是哪条
    // 排课记录那种」）。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (index > 0) ...[
          const SizedBox(height: 12),
          const HyperosInsetDivider(indent: 0),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: HyperosTokens.iconBadgeSize,
              height: HyperosTokens.iconBadgeSize,
              decoration: BoxDecoration(
                color: courseColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(
                  HyperosTokens.iconBadgeRadius,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: typo.sm.copyWith(
                  color: courseColor,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.scheduleEntryTitle(index + 1),
                    style: typo.sm.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timePreview,
                    style: typo.xs2.copyWith(
                      color: colors.mutedForeground,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (_scheduleEntries.length > 1)
              TextButton(
                onPressed: () => _removeScheduleEntry(index),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: colors.mutedForeground,
                ),
                child: Text(
                  l10n.deleteAction,
                  style: typo.xs2.copyWith(color: colors.mutedForeground),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...entryFields,
      ],
    );
  }

  Widget _buildScheduleTimeRow({
    required List<String> weekDays,
    required List<int> sectionNumbers,
    required _ScheduleEntryData entry,
    required AppLocalizations l10n,
  }) {
    final weekdayItems = {
      for (var i = 0; i < weekDays.length; i++) weekDays[i]: i + 1,
    };
    final weekdaySelect = _buildCompactPickerField(
      label: l10n.weekdayLabel,
      value: weekDays[entry.dayOfWeek - 1],
      onPress: () => _pickFromSelectSheet(
        title: l10n.weekdayLabel,
        items: weekdayItems,
        currentValue: entry.dayOfWeek,
        onSelected: (value) {
          setState(() => entry.dayOfWeek = value);
          _markDirty();
        },
      ),
    );
    final startSelect = _buildCompactPickerField(
      label: l10n.startSectionLabel,
      value: l10n.scheduleSectionNumberLabel(entry.startSection),
      onPress: () => _pickFromNumberWheelSheet(
        title: l10n.startSectionLabel,
        currentValue: entry.startSection,
        minValue: sectionNumbers.first,
        maxValue: sectionNumbers.last,
        label: (section) => l10n.scheduleSectionNumberLabel(section),
        onSelected: (value) {
          setState(() {
            entry.startSection = value;
            if (entry.endSection < entry.startSection) {
              entry.endSection = entry.startSection;
            }
            _dirty = true;
          });
        },
      ),
    );
    final endSelect = _buildCompactPickerField(
      label: l10n.endSectionLabel,
      value: l10n.scheduleSectionNumberLabel(entry.endSection),
      onPress: () => _pickFromNumberWheelSheet(
        title: l10n.endSectionLabel,
        currentValue: entry.endSection,
        minValue: entry.startSection,
        maxValue: sectionNumbers.last,
        label: (section) => l10n.scheduleSectionNumberLabel(section),
        onSelected: (value) {
          setState(() => entry.endSection = value);
          _markDirty();
        },
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            children: [
              weekdaySelect,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: startSelect),
                  const SizedBox(width: 8),
                  Expanded(child: endSelect),
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: weekdaySelect),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: startSelect),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: endSelect),
          ],
        );
      },
    );
  }

  /// 一个「点开选一项」的紧凑字段。
  ///
  /// 版式与同页的 [HyperosCompactPreferenceField]（性质/颜色）**完全相同**：
  /// 小标签在上、值 + 箭头在下、填充底、无描边。原先这里是「白底 + 描边 +
  /// 标签与值同一行」，而性质/颜色与输入框又是另外两种长相——同一张卡里
  /// 三种控件干同一件事，靠外形区分不出「能不能点」，只能靠试。
  ///
  /// 抽成一个方法而不是各写一份：`_buildCompactPickerField` 与
  /// `_buildCompactWeekSummaryRow` 原先几乎是逐行复制的两份（只有分隔符
  /// 一个是空格一个是「·」），改一处漏一处的风险已经实际发生过。
  Widget _buildCompactPickerField({
    required String label,
    required String value,
    required VoidCallback onPress,
    bool isPlaceholder = false,
  }) {
    return HyperosCompactPreferenceField(
      label: label,
      value: value,
      onTap: onPress,
      isPlaceholder: isPlaceholder,
    );
  }

  /// 「哪些周上」的摘要行——和上面那个字段是**同一个控件**。
  ///
  /// 原先这里把 label 与摘要拼成一行富文本（`'哪些周上 · 第 6 周-第 16 周'`），
  /// 而旁边的星期/节次是「标签在上、值在下」。同一组字段里两种排法，
  /// 摘要一长就把自己的标签挤成省略号。现在统一成标签在上。
  Widget _buildCompactWeekSummaryRow({
    required String label,
    required String summary,
    required VoidCallback onTap,
  }) {
    return HyperosCompactPreferenceField(
      label: label,
      value: summary,
      onTap: onTap,
    );
  }

  Widget _buildEntryTimeSchemeField(
    TimetableProvider provider,
    int index,
    AppLocalizations l10n, {
    bool compact = false,
  }) {
    final entry = _scheduleEntries[index];
    final followLabel =
        provider.activeTimeScheme?.name ?? l10n.timetableAppName;
    final locationText = index < _entryLocationControllers.length
        ? _entryLocationControllers[index].text
        : entry.location;
    // Never mutate draft entry during build — use [locationText] for resolve
    // only. Controllers are flushed to entry on save / picker confirm.
    final isAutoMode = entry.timeSchemeIdOverride == null;
    final locationMatch = isAutoMode
        ? provider.matchLocationTime(locationText)
        : null;
    final resolvedScheme = _resolveEntryTimeScheme(
      provider,
      entry,
      locationOverride: locationText,
    );
    final sectionCount = resolvedScheme?.sections.length ?? 0;
    String? clockHint;
    if (resolvedScheme != null &&
        entry.startSection >= 1 &&
        entry.endSection <= sectionCount) {
      // 这一行必须显示"保存后真正会用的钟点"：适配脚本钉过时间的课程
      // 在节次没变时用的是那份权威时间而不是模板铃点，
      // 否则这里写着 08:00-08:45，课表卡与闹钟却是 07:00-07:40
      // （与改课弹层同一处口径，见 timetable_screen 的 resolvedSectionsForCourse）。
      final clock = CourseDomain.editCourseClock(
        original: entry.originalCourse,
        startSection: entry.startSection,
        endSection: entry.endSection,
        templateStartTime:
            resolvedScheme.sections[entry.startSection - 1].startTime,
        templateEndTime: resolvedScheme.sections[entry.endSection - 1].endTime,
      );
      clockHint = '${clock.startTime}-${clock.endTime}';
    }

    // Always surface the *effective* scheme name. "Follow auto" is a mode, not
    // a scheme — users expect to see which template will actually be used.
    final String currentName;
    String? autoResolvedSubtitle;
    if (!isAutoMode) {
      currentName =
          provider.timeSchemes
              .where((scheme) => scheme.id == entry.timeSchemeIdOverride)
              .firstOrNull
              ?.name ??
          l10n.followCurrentTimetableWithName(followLabel);
      autoResolvedSubtitle = null;
    } else if (resolvedScheme != null) {
      if (locationMatch != null) {
        currentName = compact
            ? resolvedScheme.name
            : l10n.locationTimeMatchedSchemeHint(resolvedScheme.name);
        autoResolvedSubtitle = l10n.locationTimeAutoResolvedByGroup(
          locationMatch.groupName,
          resolvedScheme.name,
        );
      } else {
        currentName = compact
            ? resolvedScheme.name
            : l10n.followCurrentTimetableWithName(resolvedScheme.name);
        autoResolvedSubtitle = l10n.locationTimeAutoResolvedByTimetable(
          resolvedScheme.name,
        );
      }
    } else {
      currentName = l10n.followLocationAutoTimeScheme;
      autoResolvedSubtitle = null;
    }

    // Compact row is single-line with ellipsis: put the clock first so
    // truncation eats the scheme name, not the times.
    final displayValue = clockHint == null
        ? currentName
        : compact
        ? '$clockHint · $currentName'
        : '$currentName · $clockHint';
    void onPress() {
      showTimeSchemePickerSheet(
        context,
        currentValue: entry.timeSchemeIdOverride,
        autoResolvedSubtitle: autoResolvedSubtitle,
        onSelected: (value) {
          setState(() {
            entry.timeSchemeIdOverride = value;
            _dirty = true;
          });
        },
      ).whenComplete(() {
        if (mounted) setState(() {});
      });
    }

    if (compact) {
      return _buildCompactPickerField(
        label: l10n.timeSchemeLabel,
        value: displayValue,
        onPress: onPress,
      );
    }
    return _buildPickerTile(
      label: l10n.timeSchemeLabel,
      value: displayValue,
      icon: Icons.schedule_rounded,
      onPress: onPress,
    );
  }

  Widget _buildAddScheduleEntryButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: HyperosButton(
        label: l10n.addScheduleEntryAction,
        variant: HyperosButtonVariant.secondary,
        expand: true,
        onPressed: _addScheduleEntry,
      ),
    );
  }

  void _addScheduleEntry() {
    final last = _scheduleEntries.isNotEmpty ? _scheduleEntries.last : null;
    setState(() {
      final newEntry = _ScheduleEntryData(
        id: const Uuid().v4(),
        dayOfWeek: last?.dayOfWeek ?? 1,
        startSection: last?.startSection ?? 1,
        endSection: last?.endSection ?? 2,
        startWeek: last?.startWeek ?? 1,
        endWeek: last?.endWeek ?? 16,
        teacher: last?.teacher ?? _teacherController.text,
        location: last?.location ?? _locationController.text,
      );
      _scheduleEntries.add(newEntry);
      _entryTeacherControllers.add(
        TextEditingController(text: newEntry.teacher),
      );
      _entryLocationControllers.add(
        TextEditingController(text: newEntry.location),
      );
      _dirty = true;
    });
  }

  void _removeScheduleEntry(int index) {
    setState(() {
      _dirty = true;
      _scheduleEntries.removeAt(index);
      _entryTeacherControllers[index].dispose();
      _entryTeacherControllers.removeAt(index);
      _entryLocationControllers[index].dispose();
      _entryLocationControllers.removeAt(index);
    });
  }

  Future<void> _confirmDeleteGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final name = widget.courseGroup!.name;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.deleteCourseTitle,
      message: l10n.confirmDeleteCourseMessage(name),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );

    if (confirmed != true || !mounted) return;

    // 同本文件 :397 的删单门课：provider 侧 `_timetableDeleteCourseGroup` 落盘失败
    // 会回滚内存并 rethrow（它连带摘掉的考试/作业必须一起退回）。原先这里是
    // 裸 await：不接就是「点了删除、零提示、未处理异步错误」，而且下面还会
    // **照常弹成功 toast 并关页** —— 用户被告知「已删除」，课表却原封不动。
    try {
      await context.read<TimetableProvider>().deleteCourseGroup(name);
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.deleteFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    if (!mounted) return;
    showAppToast(
      context,
      message: l10n.courseDeleted,
      kind: AppToastKind.success,
    );
    Navigator.pop(context);
  }

  void _applyCourseTemplate(Course course) {
    _nameController.text = course.name;
    _shortNameController.text = course.shortName ?? '';
    _teacherController.text = course.teacher;
    _descriptionController.text = course.description ?? course.note ?? '';
    _courseNature = course.courseNature;
    _selectedColor = course.color;
    // Sync existing schedule entries' teacher/location with shared info.
    for (var i = 0; i < _scheduleEntries.length; i++) {
      _scheduleEntries[i].teacher = course.teacher;
      _entryTeacherControllers[i].text = course.teacher;
      _scheduleEntries[i].location = course.location;
      _entryLocationControllers[i].text = course.location;
    }
  }

  Future<void> _showCourseTemplateSheet(TimetableProvider provider) async {
    final l10n = AppLocalizations.of(context)!;
    if (provider.courseGroups.isEmpty) {
      showAppLightTip(context, message: l10n.noTemplateCoursesHint);
      return;
    }
    final course = await showCourseTemplatePickerSheet(
      context,
      title: l10n.reuseExistingCourseHelper,
      courseGroups: provider.courseGroups,
    );
    if (course != null && mounted) {
      setState(() {
      _applyCourseTemplate(course);
      _dirty = true;
    });
    }
  }

  Widget _buildResponsiveFieldPair({
    required Widget leading,
    required Widget trailing,
    double spacing = 16,
    double breakpoint = 420,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            children: [
              leading,
              SizedBox(height: spacing),
              trailing,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: leading),
            SizedBox(width: spacing),
            Expanded(child: trailing),
          ],
        );
      },
    );
  }

  Future<void> _showFullColorPalette() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showCoursePaletteSheet(
      context,
      initialColorHex: _selectedColor,
      previewText: _nameController.text.trim(),
      title: l10n.courseColorTitle,
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedColor = result;
      _dirty = true;
    });
  }

  List<int> _buildEntryWeeksFromRange(_ScheduleEntryData entry) {
    return weeksFromRangeSelection(
      startWeek: entry.startWeek,
      endWeek: entry.endWeek,
      isOddWeek: entry.isOddWeek,
      isEvenWeek: entry.isEvenWeek,
    );
  }

  /// 该条目最终会排到哪些周（范围模式按单双周过滤，自定义模式取勾选集）。
  /// 摘要显示与保存校验必须用同一个表达式 —— 原先只有自定义模式被挡，
  /// 范围 + 单/双周算出空集照样保存（理由见 `weeksFromRangeSelection`）。
  List<int> _selectedWeeksFor(_ScheduleEntryData entry) {
    if (entry.weekSelectionMode == WeekSelectionMode.range) {
      return _buildEntryWeeksFromRange(entry);
    }
    return entry.selectedCustomWeeks.toList()..sort();
  }

  String _formatWeekList(List<int> weeks) {
    if (weeks.isEmpty) {
      return '';
    }
    final ranges = <String>[];
    var rangeStart = weeks.first;
    var previous = weeks.first;
    for (var index = 1; index < weeks.length; index++) {
      final current = weeks[index];
      if (current == previous + 1) {
        previous = current;
        continue;
      }
      ranges.add(
        rangeStart == previous ? '$rangeStart' : '$rangeStart-$previous',
      );
      rangeStart = current;
      previous = current;
    }
    ranges.add(
      rangeStart == previous ? '$rangeStart' : '$rangeStart-$previous',
    );
    return ranges.join('、');
  }

  String _selectedWeeksSummaryText(
    List<int> selectedWeeks,
    List<int> availableWeeks,
    int startWeek,
    int endWeek,
    bool isOddWeek,
    bool isEvenWeek,
    WeekSelectionMode mode,
    AppLocalizations l10n,
  ) {
    if (mode == WeekSelectionMode.range) {
      final isAll =
          startWeek == availableWeeks.first &&
          endWeek == availableWeeks.last &&
          !isOddWeek &&
          !isEvenWeek;
      if (isAll) return l10n.allWeeksFilter;
      // 单周（起 == 止）不写成「第 6 周-第 6 周」：那是空区间读法，
      // 与「第 8～8 节」同一个毛病，单周只留一个周次。
      //
      // 区间用**排版连接号**（en dash 带空格）而不是 ASCII 连字符：
      // 原先 `'${weekLabel(a)}-${weekLabel(b)}'` 在中文里读作「第 6 周-第 16 周」，
      // 那个半角减号既不是中文标点、也跟同一页节次用的「～」不是一套。
      // 保留「第 N 周」这个整词仍是刻意的：`add_course_initial_week_prefill_test`
      // 用它判断带进来的那一周有没有落到摘要上（该测试在冻结目录里，不得改）。
      final range = startWeek == endWeek
          ? l10n.weekLabel(startWeek)
          : '${l10n.weekLabel(startWeek)} – ${l10n.weekLabel(endWeek)}';
      if (isOddWeek) return '$range · ${l10n.oddWeeksFilter}';
      if (isEvenWeek) return '$range · ${l10n.evenWeeksFilter}';
      return range;
    }
    if (selectedWeeks.isEmpty) return '';
    if (selectedWeeks.length == availableWeeks.length) {
      return l10n.allWeeksFilter;
    }
    return _formatWeekList(selectedWeeks);
  }

  // ---------------------------------------------------------------------------
  // Week summary row (compact)
  // ---------------------------------------------------------------------------


  // ---------------------------------------------------------------------------
  // Entry-week picker dialog (group editing mode)
  //
  // 2026-10-20：三个纯构建小件（周网格按钮 / 模式组 / 单双周组）搬到了
  // add_course_week_picker_tiles.dart（本文件行数棘轮），弹层本体与
  // weeksFromRangeSelection 判据仍在这里（冻结的接线测试钉住原文件）。
  // ---------------------------------------------------------------------------

  Future<void> _showEntryWeekPickerDialog(
    _ScheduleEntryData entry,
    List<int> availableWeeks,
    AppLocalizations l10n,
  ) async {
    var tempMode = entry.weekSelectionMode;
    var tempStartWeek = entry.startWeek;
    var tempEndWeek = entry.endWeek;
    var tempIsOddWeek = entry.isOddWeek;
    var tempIsEvenWeek = entry.isEvenWeek;
    var tempCustomWeeks = Set<int>.from(entry.selectedCustomWeeks);

    List<int> buildTempWeeksFromRange() {
      return weeksFromRangeSelection(
        startWeek: tempStartWeek,
        endWeek: tempEndWeek,
        isOddWeek: tempIsOddWeek,
        isEvenWeek: tempIsEvenWeek,
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedWeeks = tempMode == WeekSelectionMode.range
                ? buildTempWeeksFromRange()
                : (tempCustomWeeks.toList()..sort());

            return Dialog.fullscreen(
              child: HyperosSubpage(
                onBack: () => Navigator.pop(context, false),
                title: Text(l10n.weekPickerTitle),
                child: Material(
                  type: MaterialType.transparency,
                  child: HyperosBlurredBodyInset(
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              buildCourseWeekModeTileGroup(
                                tempMode: tempMode,
                                l10n: l10n,
                                onSelect: (nextMode) {
                                  setDialogState(() {
                                    if (nextMode == WeekSelectionMode.custom &&
                                        tempCustomWeeks.isEmpty) {
                                      tempCustomWeeks =
                                          buildTempWeeksFromRange().toSet();
                                      if (tempCustomWeeks.isEmpty) {
                                        tempCustomWeeks = {tempStartWeek};
                                      }
                                    }
                                    if (nextMode == WeekSelectionMode.range &&
                                        tempCustomWeeks.isNotEmpty) {
                                      final sorted = tempCustomWeeks.toList()
                                        ..sort();
                                      tempStartWeek = sorted.first;
                                      tempEndWeek = sorted.last;
                                      tempIsOddWeek = false;
                                      tempIsEvenWeek = false;
                                    }
                                    tempMode = nextMode;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              if (tempMode == WeekSelectionMode.range) ...[
                                _buildResponsiveFieldPair(
                                  spacing: 8,
                                  leading: HyperosPickerField(
                                    label: l10n.startWeekLabel,
                                    value: l10n.weekLabel(tempStartWeek),
                                    onTap: () => _pickFromNumberWheelSheet(
                                      title: l10n.startWeekLabel,
                                      currentValue: tempStartWeek,
                                      minValue: availableWeeks.first,
                                      maxValue: availableWeeks.last,
                                      label: (week) => l10n.weekLabel(week),
                                      onSelected: (value) {
                                        setDialogState(() {
                                          tempStartWeek = value;
                                          if (tempEndWeek < tempStartWeek) {
                                            tempEndWeek = tempStartWeek;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  trailing: HyperosPickerField(
                                    label: l10n.endWeekLabel,
                                    value: l10n.weekLabel(tempEndWeek),
                                    onTap: () => _pickFromNumberWheelSheet(
                                      title: l10n.endWeekLabel,
                                      currentValue: tempEndWeek,
                                      minValue: tempStartWeek,
                                      maxValue: availableWeeks.last,
                                      label: (week) => l10n.weekLabel(week),
                                      onSelected: (value) {
                                        setDialogState(
                                          () => tempEndWeek = value,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                buildCourseWeekParityTileGroup(
                                  l10n: l10n,
                                  isAllWeeks: !tempIsOddWeek && !tempIsEvenWeek,
                                  isOddWeek: tempIsOddWeek,
                                  isEvenWeek: tempIsEvenWeek,
                                  onSelectAll: () {
                                    setDialogState(() {
                                      tempIsOddWeek = false;
                                      tempIsEvenWeek = false;
                                    });
                                  },
                                  onSelectOdd: () {
                                    setDialogState(() {
                                      tempIsOddWeek = true;
                                      tempIsEvenWeek = false;
                                    });
                                  },
                                  onSelectEven: () {
                                    setDialogState(() {
                                      tempIsOddWeek = false;
                                      tempIsEvenWeek = true;
                                    });
                                  },
                                ),
                              ] else ...[
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final width = constraints.maxWidth;
                                    final crossAxisCount = width < 340
                                        ? 4
                                        : width < 420
                                        ? 5
                                        : 6;
                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: availableWeeks.length,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: crossAxisCount,
                                            mainAxisSpacing: 8,
                                            crossAxisSpacing: 8,
                                            mainAxisExtent: 44,
                                          ),
                                      itemBuilder: (context, i) {
                                        final week = availableWeeks[i];
                                        final isSelected = tempCustomWeeks
                                            .contains(week);
                                        return buildCourseWeekGridTile(
                                          week: week,
                                          isSelected: isSelected,
                                          onPress: () {
                                            setDialogState(() {
                                              if (isSelected) {
                                                if (tempCustomWeeks.length >
                                                    1) {
                                                  tempCustomWeeks.remove(week);
                                                }
                                              } else {
                                                tempCustomWeeks.add(week);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    HyperosButton(
                                      label: l10n.selectAllAction,
                                      variant: HyperosButtonVariant.secondary,
                                      dense: true,
                                      onPressed: () {
                                        setDialogState(() {
                                          tempCustomWeeks = availableWeeks
                                              .toSet();
                                        });
                                      },
                                    ),
                                    HyperosButton(
                                      label: l10n.selectOddWeeksAction,
                                      variant: HyperosButtonVariant.secondary,
                                      dense: true,
                                      onPressed: () {
                                        setDialogState(() {
                                          tempCustomWeeks = availableWeeks
                                              .where((week) => week.isOdd)
                                              .toSet();
                                        });
                                      },
                                    ),
                                    HyperosButton(
                                      label: l10n.selectEvenWeeksAction,
                                      variant: HyperosButtonVariant.secondary,
                                      dense: true,
                                      onPressed: () {
                                        setDialogState(() {
                                          tempCustomWeeks = availableWeeks
                                              .where((week) => week.isEven)
                                              .toSet();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                l10n.selectedWeeksSummary(
                                  selectedWeeks.length,
                                  _formatWeekList(selectedWeeks),
                                ),
                                style: HyperosTypography.listDetail(context),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: HyperosButton(
                                  label: l10n.cancelAction,
                                  variant: HyperosButtonVariant.secondary,
                                  expand: true,
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: HyperosButton(
                                  label: l10n.confirmAction,
                                  expand: true,
                                  // 算出来的周次为空（第 2 周 + 单周、或单双周同时勾）时
                                  // 不许确认：这样存进去的课在任何一周都不出现，
                                  // 却仍计入统计与伴侣同步，而界面当时报"添加成功"。
                                  onPressed: selectedWeeks.isEmpty
                                      ? null
                                      : () => Navigator.pop(context, true),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() {
      entry.weekSelectionMode = tempMode;
      entry.startWeek = tempStartWeek;
      entry.endWeek = tempEndWeek;
      entry.isOddWeek = tempIsOddWeek;
      entry.isEvenWeek = tempIsEvenWeek;
      entry.selectedCustomWeeks = tempCustomWeeks;
    });
  }

  Future<void> _saveCourse(
    TimetableProvider provider,
    TimetableSettings settings,
  ) async {
    // 连点闸：置位到 `_saveGroup` 自己 `Navigator.pop` 为止（失败分支会复位）。
    // 没有它时两下点击会并行跑两遍落盘，各自弹一次「已保存」、各自 pop 一次。
    if (_saving) {
      return;
    }
    setState(() => _saving = true);

    final l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) {
      return;
    }

    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      _formKey.currentState?.validate();
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(
        context,
        message: l10n.pleaseEnterCourseName,
        kind: AppToastKind.warning,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      setState(() => _saving = false);
      return;
    }
    final saved = await _saveGroup(provider, settings, l10n);
    if (!saved && mounted) {
      // 校验没过或落盘失败：保存态必须退回，否则按钮永远是灰的、再点也没反应。
      setState(() => _saving = false);
    }
  }

  /// 返回「是否真的落盘成功」。
  ///
  /// 调用方（[_saveCourse]）用它决定要不要把保存态退回去：校验失败与落盘失败
  /// 都必须让保存键重新可用，只有成功才会关页。
  Future<bool> _saveGroup(
    TimetableProvider provider,
    TimetableSettings settings,
    AppLocalizations l10n,
  ) async {
    final name = _nameController.text.trim();
    final shortName = _shortNameController.text.isEmpty
        ? null
        : _shortNameController.text;
    final description = _descriptionController.text.isEmpty
        ? null
        : _descriptionController.text;

    // Validate all entries.
    //
    // 表单这里的口径**故意比数据层严**：手动加课录的是节次区间，钟点由解析出来的
    // 时间模板给（见 _resolveEntryTimeScheme）。未绑定模板的课一旦放进超出当前模板
    // 的节次，既没钟点可取、课表上也画不出那一行，所以这里当场拦。
    // 数据层（timetable_provider.addCourse）只校验显式绑定了模板的课，是因为它服务的
    // 导入/恢复路径自带钟点——两条路的真源不同，不是这两处该改成一样。
    for (var i = 0; i < _scheduleEntries.length; i++) {
      final entry = _scheduleEntries[i];
      // Sync teacher/location from controllers.
      entry.teacher = _entryTeacherControllers[i].text;
      entry.location = _entryLocationControllers[i].text;

      final validationMessage = provider.validateCourseTimeSchemeOverride(
        timeSchemeId: entry.timeSchemeIdOverride,
        startSection: entry.startSection,
        endSection: entry.endSection,
        location: entry.location,
      );
      if (validationMessage != null) {
        showAppToast(
          context,
          message:
              '${l10n.scheduleEntryTitle(i + 1)}: ${localizeServiceMessage(l10n, validationMessage)}',
          kind: AppToastKind.warning,
        );
        return false;
      }

      // 两种模式都要挡：范围模式叠上单/双周也能算出空集（见 weeksFromRangeSelection），
      // 原先只挡自定义模式，于是"第 2 周 + 单周"照样保存成功，而这门课在课表上
      // 任何一周都不出现，却仍留在数据里计入统计与伴侣同步。
      if (_selectedWeeksFor(entry).isEmpty) {
        showAppToast(
          context,
          message:
              '${l10n.scheduleEntryTitle(i + 1)}: ${l10n.selectAtLeastOneWeek}',
          kind: AppToastKind.warning,
        );
        return false;
      }
    }

    // Build courses from entries.
    final courses = <Course>[];
    for (final entry in _scheduleEntries) {
      final resolvedScheme = _resolveEntryTimeScheme(provider, entry);
      final templateStartTime = resolvedScheme == null
          ? settings.sectionAt(entry.startSection).startTime
          : resolvedScheme.sections[entry.startSection - 1].startTime;
      final templateEndTime = resolvedScheme == null
          ? settings.sectionAt(entry.endSection).endTime
          : resolvedScheme.sections[entry.endSection - 1].endTime;
      // 条目模型只有节次，钟点一律由模板算出来；不先把适配脚本钉住的那份
      // 权威时间接回来，"改个教师再保存"就会把早读 07:00 静默改回 08:00
      // （TimeSchemeLogic:436 写明模板不得覆盖 hasCustomTime 的时间）。
      final clock = CourseDomain.editCourseClock(
        original: entry.originalCourse,
        startSection: entry.startSection,
        endSection: entry.endSection,
        templateStartTime: templateStartTime,
        templateEndTime: templateEndTime,
      );

      courses.add(
        entry.toCourse(
          name: name,
          shortName: shortName,
          color: _selectedColor,
          courseNature: _courseNature,
          description: description,
          startTime: clock.startTime,
          endTime: clock.endTime,
          hasCustomTime: clock.hasCustomTime,
        ),
      );
    }

    try {
      if (widget.courseGroup != null) {
        // Editing existing group: replace all entries.
        await provider.updateCourseGroup(widget.courseGroup!.name, courses);
      } else if (widget.course != null) {
        // Editing a single existing course: replace every entry of the
        // ORIGINAL name group with the edited set. Must NOT go through
        // deleteCourse + addCourse: same-name sibling entries would survive
        // the delete and addCourse's shared-field step would then resurrect
        // their OLD color/name/nature over the user's edits — the save toast
        // still shows success but nothing visibly changes.
        // updateCourseGroup removes the whole original-name group first, so
        // no stale sibling remains to overwrite the new shared fields. It is
        // also atomic under the provider mutation gate.
        await provider.updateCourseGroup(widget.course!.name, courses);
      } else {
        // Adding new courses: add all entries.
        for (final course in courses) {
          await provider.addCourse(course);
        }
      }
    } on ArgumentError catch (error) {
      if (!mounted) return false;
      showAppToast(
        context,
        message: error.message != null
            ? localizeServiceMessage(l10n, error.message! as String)
            : l10n.saveFailed,
        kind: AppToastKind.error,
      );
      return false;
    } on Object catch (error, stackTrace) {
      // 落盘失败不再静默：provider 侧回滚并 rethrow，这里既要说出来、
      // 又要把保存态放回去（原先这个异常会直接漏到 zone，用户零提示）。
      unawaited(
        AppLogService.instance.error(
          'course_save',
          'save course failed',
          error: error,
          stackTrace: stackTrace,
        ),
      );
      if (!mounted) return false;
      showAppToast(
        context,
        message: l10n.saveFailed,
        kind: AppToastKind.error,
      );
      return false;
    }

    if (!mounted) return false;
    showAppToast(
      context,
      message: _isCreatingNewCourse
          ? l10n.courseAddedSuccess
          : l10n.courseUpdatedSuccess,
      kind: AppToastKind.success,
    );
    // 关页前清脏标记：PopScope 的 canPop 依赖它，不清就会在 pop 那一瞬
    // 被自己拦住，反问「放弃修改？」
    _dirty = false;
    Navigator.pop(context);
    return true;
  }

  TimeScheme? _resolveEntryTimeScheme(
    TimetableProvider provider,
    _ScheduleEntryData entry, {
    String? locationOverride,
  }) {
    // Keep the same priority as runtime resolve:
    // override > location match > date rule > active timetable scheme.
    // Using only [activeTimeScheme] here would discard location routing when
    // the user leaves the entry on "follow auto", and overwrite applied clocks
    // on the next save.
    return provider.resolveCourseTimeScheme(
      Course(
        id: entry.id,
        name: '_',
        teacher: entry.teacher,
        location: locationOverride ?? entry.location,
        dayOfWeek: entry.dayOfWeek,
        startSection: entry.startSection,
        endSection: entry.endSection,
        startTime: '08:00',
        endTime: '09:00',
        timeSchemeIdOverride: entry.timeSchemeIdOverride,
      ),
    );
  }
}

/// Compact HyperOS list row for a conflicting partner schedule.
///
/// Matches preference navigation chrome: title + status tag + detail + chevron.
/// Avoids custom red banners and trailing text-as-button.
class _ScheduleConflictPartnerRow extends StatelessWidget {
  const _ScheduleConflictPartnerRow({
    required this.partner,
    required this.onOpen,
  });

  final Course partner;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final dayLabel = _weekdayShort(l10n, partner.dayOfWeek);
    final schedule = l10n.weekdaySectionSummary(
      dayLabel,
      partner.startSection,
      partner.endSection,
    );

    return Material(
      color: HyperosColors.secondaryVariant(context),
      // Nested compact row — use control radius, not settings-group 24.
      borderRadius: BorderRadius.circular(HyperosTokens.controlRadius),
      clipBehavior: Clip.antiAlias,
      child: HyperosPressableRow(
        onTap: onOpen,
        backgroundColor: HyperosColors.secondaryVariant(context),
        highlightColor: HyperosColors.rowHighlight(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: HyperosTokens.controlMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              partner.name,
                              style: HyperosTypography.listTitle(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          HyperosTag(
                            label: l10n.conflictLabel,
                            backgroundColor: theme.colors.destructive
                                .withValues(alpha: 0.12),
                            textStyle: HyperosTypography.listDetail(context)
                                .copyWith(
                                  color: theme.colors.destructive,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schedule,
                        style: HyperosTypography.listDetail(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: HyperosTokens.titleChevronGap),
                const HyperosChevron(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _weekdayShort(AppLocalizations l10n, int dayOfWeek) {
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
}
