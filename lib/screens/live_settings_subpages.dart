import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/live_testing_access.dart';
import '../providers/timetable_provider.dart';
import '../services/android_move_to_back_service.dart';
import '../services/live_testing_trigger.dart';
import '../services/live_testing_fixture_service.dart';
import '../services/miui_live_activities_service.dart';
import '../services/app_log_service.dart';
import '../ui/hyperos/hyperos_motion.dart';
import '../utils/hex_color.dart';
import '../utils/app_toast.dart';
import '../utils/import_file_reader.dart';
import '../services/unified_transfer_service.dart';
import '../utils/live_expanded_detail_fields.dart';
import '../ui/hyperos/hyperos.dart';
import '../ui/hyperos/liquid/liquid_glass_surface.dart'
    show LiquidGlassSurface, LiquidGlassRole, narrowSurfaceMaxRefraction;
import '../widgets/live_island_preview.dart';

const String _expandedIconDir = 'miui_expanded_icons';
const String _labelLogoDir = 'miui_label_logos';
const List<String> _labelColors = [
  '#FFFFFF',
  '#E2E8F0',
  '#BFDBFE',
  '#A7F3D0',
  '#FDE68A',
  '#F9A8D4',
];

/// 「重点提醒切入时机」右侧的当前效果摘要。
///
/// 只描述「怎么切」，不重复具体分钟/秒数——那两个值就在本页「时间阈值」
/// 组里明摆着，写进摘要会把这一行撑成三行（真机 2026-10-21 截图：灰字
/// 两行 + 右侧取值挤在中间，读成一句被劈开的话）。
String _buildLiveClassReminderLeadSummary(
  AppLocalizations l10n,
  TimetableSettings settings,
) {
  if (settings.liveClassReminderStartMinutes == 0) {
    return l10n.liveClassReminderLeadSummaryImmediate;
  }
  if (settings.liveEnableDuringClass &&
      settings.liveShowDuringClassNotification &&
      !settings.livePromoteDuringClass) {
    return l10n.liveClassReminderLeadSummaryKeepNormal;
  }
  if (settings.liveEnableDuringClass &&
      settings.liveShowDuringClassNotification) {
    return l10n.liveClassReminderLeadSummaryIsland;
  }
  return l10n.liveClassReminderLeadSummaryFocused;
}

/// 上课前快捷操作「自动执行」的可选提前分钟数。
const List<int> _quickActionAutoMinutesOptions = [5, 10, 15, 20, 30];

class LiveReminderTimingScreen extends StatefulWidget {
  const LiveReminderTimingScreen({super.key});

  @override
  State<LiveReminderTimingScreen> createState() =>
      _LiveReminderTimingScreenState();
}

class _LiveReminderTimingScreenState extends State<LiveReminderTimingScreen> {
  static const List<int> _beforeClassMinutesOptions = [
    1,
    5,
    10,
    15,
    20,
    30,
    40,
    50,
    60,
  ];
  static const List<int> _endSecondsOptions = [15, 30, 45, 60, 90];

  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
  }

  @override
  void dispose() {
    if (_autoSaveTimer?.isActive ?? false) {
      _autoSaveTimer?.cancel();
      _enqueuePersist(_draft);
    } else {
      _autoSaveTimer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final duringClassEnabled =
        _draft.liveEnableDuringClass || _draft.liveEnableBeforeEnd;
    // HyperOS list style: section label + one list group of equal-height rows.
    // Avoid ControlCard wrappers and long footnotes so the page scans like
    // system settings (title / one-line subtitle / trailing control).
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.liveReminderTimingTitle),
      child: HyperosListView(
        children: [
          HyperosSectionLabel(text: l10n.liveReminderSwitchesTitle),
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                title: l10n.beforeClassReminderTitle,
                subtitle: l10n.beforeClassReminderSubtitle(
                  _draft.liveShowBeforeClassMinutes,
                ),
                value: _draft.liveEnableBeforeClass,
                onChanged: (value) =>
                    _updateDraft(_draft.copyWith(liveEnableBeforeClass: value)),
              ),
              HyperosSwitchTile(
                title: l10n.duringClassReminderTitle,
                // 副标题删：复述标题「课中与下课提醒」，零新增信息。
                value: duringClassEnabled,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(
                    liveEnableDuringClass: value,
                    liveEnableBeforeEnd: value,
                  ),
                ),
              ),
              if (duringClassEnabled)
                HyperosSelectTile<int>(
                  label: l10n.liveClassReminderLeadTitle,
                  subtitle: _buildLiveClassReminderLeadSummary(l10n, _draft),
                  items: {
                    l10n.liveClassReminderLeadOptionImmediate: 0,
                    l10n.liveClassReminderLeadOptionMinutes(5): 5,
                    l10n.liveClassReminderLeadOptionMinutes(10): 10,
                    l10n.liveClassReminderLeadOptionMinutes(15): 15,
                    l10n.liveClassReminderLeadOptionMinutes(20): 20,
                    l10n.liveClassReminderLeadOptionMinutes(30): 30,
                  },
                  value: _draft.liveClassReminderStartMinutes,
                  onChanged: (value) => _updateDraft(
                    _draft.copyWith(liveClassReminderStartMinutes: value),
                  ),
                ),
            ],
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.liveDisplayModeTitle),
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                title: l10n.duringClassStatusNotificationTitle,
                subtitle: _draft.liveClassReminderStartMinutes == 0
                    ? l10n.duringClassStatusNotificationImmediate
                    : _draft.livePromoteDuringClass
                    ? l10n.duringClassStatusNotificationBeforeEnd
                    : l10n.duringClassStatusNotificationPersistent,
                value: _draft.liveShowDuringClassNotification,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(liveShowDuringClassNotification: value),
                ),
              ),
              HyperosSwitchTile(
                title: l10n.enableIslandDisplayTitle,
                subtitle: l10n.enableIslandDisplaySubtitle,
                value: _draft.livePromoteDuringClass,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(livePromoteDuringClass: value),
                ),
              ),
            ],
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.liveTimeThresholdTitle),
          HyperosListGroup(
            children: [
              HyperosSelectTile<int>(
                label: l10n.beforeClassPopupLabel,
                items: {
                  for (final value in _beforeClassMinutesOptions)
                    l10n.beforeClassMinutesOption(value): value,
                },
                value: _draft.liveShowBeforeClassMinutes,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(liveShowBeforeClassMinutes: value),
                ),
              ),
              HyperosSelectTile<int>(
                label: l10n.beforeEndSecondsLabel,
                items: {
                  for (final value in _endSecondsOptions)
                    l10n.beforeEndSecondsOption(value): value,
                },
                value: _draft.liveEndSecondsCountdownThreshold,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(liveEndSecondsCountdownThreshold: value),
                ),
              ),
              HyperosSelectTile<LiveDuringClassTimeDisplayMode>(
                label: l10n.duringEndTimeDisplayLabel,
                // 副标题「紧凑提醒显示最近时间或总时长」删：两个选项的字面
                // 就是「最近时间／总时间」，副标题只是把它们念一遍。
                items: {
                  for (final value in LiveDuringClassTimeDisplayMode.values)
                    liveDuringClassTimeDisplayModeLabel(l10n, value): value,
                },
                value: _draft.liveDuringEndTimeDisplayMode,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(liveDuringEndTimeDisplayMode: value),
                ),
              ),
            ],
          ),
          const HyperosSectionGap(),
          // 「铃声时间矫正」整组删：与自检页同一字段（liveTimeCorrectionSeconds）、
          // 同参数同文案的重复入口——自检页注释明说「从『提醒时间』页移到这里」，
          // 这份是搬走时漏删的残页；纯排障旋钮不再占用户偏好路径。
        ],
      ),
    );
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() => _draft = next);
    _autoSaveTimer?.cancel();
    if (debounce) {
      _autoSaveTimer = Timer(
        const Duration(milliseconds: 250),
        () => _enqueuePersist(next),
      );
      return;
    }
    _enqueuePersist(next);
  }

  void _enqueuePersist(TimetableSettings next) {
    _saveQueue = _saveQueue.catchError((_) {}).then((_) => _persistDraft(next));
  }

  Future<void> _persistDraft(TimetableSettings next) async {
    final provider = context.read<TimetableProvider>();
    // 草稿快照可能比真源旧：节次表与激活作息一律回灌，避免把换季批量套用的
    // 结果顺手回滚（见 TimetableSettings.withLiveScheduleFieldsFrom）。
    String? message;
    try {
      message = await provider.updateTimetableSettings(
        next.withLiveScheduleFieldsFrom(provider.settings),
      );
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    if (!mounted) return;
    if (message != null) {
      showAppToast(
        context,
        message: localizeServiceMessage(AppLocalizations.of(context)!, message),
      );
      setState(() => _draft = provider.settings);
    }
  }
}

class LiveDisplaySettingsScreen extends StatefulWidget {
  final String title;
  final bool forDuringEnd;

  const LiveDisplaySettingsScreen({
    super.key,
    required this.title,
    required this.forDuringEnd,
  });

  @override
  State<LiveDisplaySettingsScreen> createState() =>
      _LiveDisplaySettingsScreenState();
}

class _LiveDisplaySettingsScreenState extends State<LiveDisplaySettingsScreen> {
  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  // 底部悬浮「速览」按钮的会话状态：测试中 → 按钮变「停止测试」，到点
  // （约 30 秒）或手动停止后回到「试弹」态。会话本体记录在全局
  // activeLiveCourseTestSession（返回重进页面要能恢复按钮态），这里只持有
  // 翻面定时器；进入页面时按全局会话恢复。
  bool _stagePreviewBusy = false;
  bool _stagePreviewActive = false;
  Timer? _stagePreviewEndTimer;

  late final Course _sampleCourse;

  /// 速览会话的实况转播源：测试进行中时，预览卡用会话的真实课程/窗口/
  /// 下一节渲染，与真机弹出的岛同源；空闲时为 null，预览回落静态演示。
  LiveCourseTestSession? _liveSession;

  /// 预览用的展示课程：速览中 = 会话课程 + 会话合成钟点（与下发一致，
  /// 倒计时也按会话窗口走）；空闲 = 进页时挑选的示例课。
  Course? get _previewCourse {
    final session = _liveSession;
    final course = session?.course;
    if (session == null || course == null) return _sampleCourse;
    final start = session.start;
    final clockEnd = session.clockEnd;
    if (start == null || clockEnd == null) return course;
    return course.copyWith(
      startTime: LiveTestingFixtureService.formatClock(start),
      endTime: LiveTestingFixtureService.formatClock(clockEnd),
    );
  }

  /// 预览「下一节」名：速览中与真机同源（测试通道解析的同日下一条）。
  /// 为避免页面内重复维护解析规则，速览起手时记录一次即可（30 秒内课表
  /// 不会变）；热更新路径由 trigger 侧重算，名字变化不影响展示正确性。
  String? _previewNextCourseName;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TimetableProvider>();
    _draft = provider.settings;
    _sampleCourse = resolveLivePreviewTestCourse(LiveTestingProviderAccess(provider));
    _restoreStagePreviewFromGlobalSession();
    unawaited(provider.refreshLiveActivityNow(forceSnapshotSync: true));
  }

  /// 按全局会话恢复按钮态：会话仍在（含其他入口起的选课测试）→ 直接进
  /// 「停止测试」态，并把翻面定时器对齐到会话终点；已过期 → 读侧惰性清槽。
  void _restoreStagePreviewFromGlobalSession() {
    final session = currentLiveCourseTestSession();
    if (session == null) return;
    _liveSession = session;
    _previewNextCourseName = _resolvePreviewNextCourseName(session);
    _stagePreviewActive = true;
    _stagePreviewEndTimer?.cancel();
    _stagePreviewEndTimer = Timer(
      session.sessionEnd.difference(DateTime.now()),
      () {
        if (mounted) {
          setState(() {
            _stagePreviewActive = false;
            _liveSession = null;
            _previewNextCourseName = null;
          });
        }
      },
    );
  }

  /// 与测试通道同源的「下一节」解析（同一公开 API 组合，避免两套规则）。
  String? _resolvePreviewNextCourseName(LiveCourseTestSession session) {
    final course = session.course;
    if (course == null) return null;
    final provider = context.read<TimetableProvider>();
    final week = provider.liveSelectionCalendarWeek;
    final sameDayCourses = provider.getActiveCoursesForDay(
      course.dayOfWeek,
      week: week,
    )..sort((a, b) => a.startSection.compareTo(b.startSection));
    final index = sameDayCourses.indexWhere((c) => c.id == course.id);
    if (index == -1 || index + 1 >= sameDayCourses.length) return null;
    return provider.resolveCourseDisplayName(sameDayCourses[index + 1]).name;
  }

  @override
  void dispose() {
    if (_autoSaveTimer?.isActive ?? false) {
      _autoSaveTimer?.cancel();
      _enqueuePersist(_draft);
    } else {
      _autoSaveTimer?.cancel();
    }
    _stagePreviewEndTimer?.cancel();
    super.dispose();
  }

  LiveCourseTestStage get _previewStage => widget.forDuringEnd
      ? LiveCourseTestStage.duringClass
      : LiveCourseTestStage.beforeClass;

  /// 速览：直接弹本页对应阶段的岛（约 30 秒自动收岛），成功后按钮翻到
  /// 「停止测试」态，到点由会话终点驱动自动翻回。
  Future<void> _startStagePreview() async {
    if (_stagePreviewBusy) return;
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    setState(() => _stagePreviewBusy = true);
    try {
      final result = await triggerLiveStagePreviewTest(
        context: context,
        host: LiveTestingProviderAccess(provider),
        stage: _previewStage,
      );
      if (!mounted) return;
      showAppToast(
        context,
        message: switch (result.status) {
          LiveTestingTriggerStatus.success => l10n.liveStagePreviewStartedToast(
            widget.forDuringEnd
                ? l10n.liveStagePreviewStageDuringClass
                : l10n.liveStagePreviewStageBeforeClass,
          ),
          LiveTestingTriggerStatus.inFlight ||
          LiveTestingTriggerStatus.error => result.message ?? '',
        },
        kind: switch (result.status) {
          LiveTestingTriggerStatus.success => AppToastKind.success,
          LiveTestingTriggerStatus.inFlight => AppToastKind.warning,
          LiveTestingTriggerStatus.error => AppToastKind.error,
        },
      );
      if (result.status == LiveTestingTriggerStatus.success) {
        _stagePreviewEndTimer?.cancel();
        // 记下会话供预览实况转播：课程、窗口锚点与「下一节」都与真机
        // 下发载荷同源，预览不再演假数据。
        final session = currentLiveCourseTestSession();
        setState(() {
          _stagePreviewActive = true;
          _liveSession = session;
          _previewNextCourseName = session == null
              ? null
              : _resolvePreviewNextCourseName(session);
        });
        final sessionEnd =
            result.sessionEnd ??
            DateTime.now().add(const Duration(seconds: 35));
        _stagePreviewEndTimer = Timer(
          sessionEnd.difference(DateTime.now()),
          () {
            if (mounted) {
              setState(() {
                _stagePreviewActive = false;
                _liveSession = null;
                _previewNextCourseName = null;
              });
            }
          },
        );
        // 岛只在桌面/状态栏可见：起岛成功后自动退后台（等效按 Home），
        // 省去用户手动按。失败（MIUI 分屏等非常规形态）不打断流程，
        // toast 里本就引导按 Home 查看。
        unawaited(AndroidMoveToBackService.moveTaskToBack());
      }    } finally {
      if (mounted) {
        setState(() => _stagePreviewBusy = false);
      }
    }
  }

  /// 停止速览：立即收岛并恢复正式调度（与自检页停止选课测试同路）。
  Future<void> _stopStagePreview() async {
    if (_stagePreviewBusy) return;
    final provider = context.read<TimetableProvider>();
    setState(() => _stagePreviewBusy = true);
    try {
      await cancelLiveUpdateCourseTest(LiveTestingProviderAccess(provider));
      _stagePreviewEndTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _stagePreviewActive = false;
        _liveSession = null;
        _previewNextCourseName = null;
      });
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.liveStagePreviewStoppedToast,
        kind: AppToastKind.success,
      );
    } finally {
      if (mounted) {
        setState(() => _stagePreviewBusy = false);
      }
    }
  }

  LiveDisplaySettings get _display => widget.forDuringEnd
      ? _draft.duringEndDisplaySettings
      : _draft.beforeClassDisplaySettings;

  bool get _followBeforeClass =>
      widget.forDuringEnd && _draft.liveDuringEndFollowBeforeClass;

  String? _courseNameSubtitle(
    AppLocalizations l10n,
    LiveDisplaySettings display,
  ) {
    // 开关已关时不再提示「可关闭」（自相矛盾，真机 2026-10-21 反馈）。
    if (!display.showCourseName) return null;
    if (display.enableMiuiIslandLabelImage &&
        (display.miuiIslandLabelContent == MiuiIslandLabelContent.courseName ||
            display.miuiIslandLabelContent ==
                MiuiIslandLabelContent.courseNameAndLocation)) {
      return l10n.courseNameDuplicatedHint;
    }
    return null;
  }

  String? _locationSubtitle(
    AppLocalizations l10n,
    LiveDisplaySettings display,
  ) {
    if (!display.showLocation) return null;
    if (display.enableMiuiIslandLabelImage &&
        (display.miuiIslandLabelContent == MiuiIslandLabelContent.location ||
            display.miuiIslandLabelContent ==
                MiuiIslandLabelContent.courseNameAndLocation)) {
      return l10n.locationDuplicatedHint;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 速览测试进行中 → 预览用会话的真实课程/窗口/下一节（实况转播）；
    // 空闲 → 静态示例课（进页时挑选）。
    final sampleCourse = _previewCourse;
    final previewAnchor = _liveSession?.start;
    final previewNextCourseName = _previewNextCourseName;
    final display = _display;
    final sectionCards = <Widget>[
      HyperosSectionLabel(text: l10n.liveDisplayContentTitle),
      HyperosListGroup(
        children: [
          HyperosSwitchTile(
            title: l10n.showCourseNameTitle,
            subtitle: _courseNameSubtitle(l10n, display),
            value: display.showCourseName,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(showCourseName: value)),
          ),
          HyperosSwitchTile(
            title: l10n.preferShortNameTitle,
            subtitle: l10n.preferShortNameSubtitle,
            value: display.useShortName,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(useShortName: value)),
          ),
          HyperosSwitchTile(
            title: l10n.showLocationTitle,
            subtitle: _locationSubtitle(l10n, display),
            value: display.showLocation,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(showLocation: value)),
          ),
          HyperosSwitchTile(
            title: l10n.showCountdownTitle,
            value: display.showCountdown,
            onChanged: (value) =>
                _updateDisplay(display.copyWith(showCountdown: value)),
          ),
          AnimatedOpacity(
            duration: 160.scaledMs,
            opacity: display.showCountdown ? 0.55 : 1.0,
            child: HyperosSwitchTile(
              title: l10n.showStageTextTitle,
              // 条件不成立时不解释；只在「为什么这行灰着」时说（真机 2026-10-21）。
              subtitle: display.showCountdown
                  ? l10n.showStageTextInactiveHint
                  : null,
              value: display.showStageText,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(showStageText: value)),
            ),
          ),
          AnimatedOpacity(
            duration: 160.scaledMs,
            opacity: !display.showCountdown ? 0.55 : 1.0,
            child: HyperosSwitchTile(
              title: l10n.hidePrefixTextTitle,
              // 生效态不挂副标题：原句把标题又念一遍（真机 2026-10-21）。
              subtitle: !display.showCountdown
                  ? l10n.hidePrefixTextInactiveHint
                  : null,
              value: display.hidePrefixText,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(hidePrefixText: value)),
            ),
          ),
        ],
      ),
      if (display.showCountdown) ...[
        const HyperosSectionGap(),
        // 分组标签「倒计时格式」删：与该组唯一那行的标题是同一个词。
        HyperosListGroup(
          children: [
            HyperosSelectTile<LiveCountdownTextStyle>(
              label: l10n.countdownFormatLabel,
              subtitle: l10n.countdownFormatHelp,
              items: {
                for (final value in LiveCountdownTextStyle.values)
                  liveCountdownTextStyleLabel(l10n, value): value,
              },
              value: display.countdownTextStyle,
              onChanged: (value) =>
                  _updateDisplay(display.copyWith(countdownTextStyle: value)),
            ),
          ],
        ),
      ],
      if (!widget.forDuringEnd) ...[
        const HyperosSectionGap(),
        // 分组标签「上课前快捷操作」删：与该组那行标题是同一个词。
        HyperosListGroup(
          children: [
            HyperosSelectTile<LiveBeforeClassQuickAction>(
              label: l10n.beforeClassQuickActionTitle,
              items: {
                for (final value in LiveBeforeClassQuickAction.values)
                  liveBeforeClassQuickActionLabel(l10n, value): value,
              },
              value: _draft.liveBeforeClassQuickAction,
              onChanged: (value) => _updateDraft(
                _draft.copyWith(liveBeforeClassQuickAction: value),
              ),
            ),
            if (_draft.liveBeforeClassQuickAction !=
                LiveBeforeClassQuickAction.none)
              HyperosSelectTile<int>(
                label: l10n.liveBeforeClassQuickActionAutoTitle,
                subtitle: l10n.liveBeforeClassQuickActionAutoSubtitle,
                items: {
                  l10n.liveBeforeClassQuickActionAutoOptionOff: 0,
                  for (final value in _quickActionAutoMinutesOptions)
                    l10n.liveBeforeClassQuickActionAutoOptionMinutes(value):
                        value,
                },
                value: _draft.liveBeforeClassQuickActionAutoMinutes,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(liveBeforeClassQuickActionAutoMinutes: value),
                ),
              ),
            // 免打扰档需要「勿扰模式访问权限」，没授权时通知上的按钮点了
            // 不报错也没反应。这里直接把缺什么、怎么去授说清楚。
            if (_draft.liveBeforeClassQuickAction
                .requiresDoNotDisturbAccess)
              _DoNotDisturbAccessTile(
                onOpenSettings: () => MiuiLiveActivitiesService()
                    .openDoNotDisturbAccessSettings(),
              ),
          ],
        ),
      ],
      const HyperosSectionGap(),
      HyperosSectionLabel(text: l10n.liveIslandVisualTitle),
      HyperosListGroup(
        children: [
          HyperosSwitchTile(
            title: l10n.liveMiuiLabelImageTitle,
            subtitle: l10n.liveMiuiLabelImageSubtitle,
            value: display.enableMiuiIslandLabelImage,
            onChanged: (value) => _updateDisplay(
              display.copyWith(enableMiuiIslandLabelImage: value),
            ),
          ),
        ],
      ),
      if (display.enableMiuiIslandLabelImage) ...[
        const HyperosSectionGap(),
        HyperosControlCard(
          edgeToEdge: true,
          child: HyperosControlCardRows(
            children: [
              HyperosSelectTile<MiuiIslandLabelContent>(
                label: l10n.liveMiuiLabelContentLabel,
                items: {
                  for (final value in MiuiIslandLabelContent.values)
                    miuiIslandLabelContentLabel(l10n, value): value,
                },
                value: display.miuiIslandLabelContent,
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelContent: value),
                ),
              ),
              HyperosSelectTile<MiuiIslandLabelStyle>(
                label: l10n.liveMiuiLabelStyleLabel,
                items: {
                  for (final value in MiuiIslandLabelStyle.values)
                    miuiIslandLabelStyleLabel(l10n, value): value,
                },
                value: display.miuiIslandLabelStyle,
                onChanged: (value) => _updateDisplay(
                  display.copyWith(miuiIslandLabelStyle: value),
                ),
              ),
              if (display.miuiIslandLabelStyle ==
                  MiuiIslandLabelStyle.iconAndText)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HyperosControlCardScope.defaultHorizontalPadding,
                    4,
                    HyperosControlCardScope.defaultHorizontalPadding,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.liveMiuiLabelLogoTitle,
                        style: HyperosTypography.listTitle(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.liveMiuiLabelLogoSubtitle,
                        style: HyperosTypography.listDetail(context),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: HyperosButton(
                              label: display.miuiIslandLabelLogoPath == null
                                  ? l10n.selectImageAction
                                  : l10n.replaceImageAction,
                              variant: HyperosButtonVariant.secondary,
                              expand: true,
                              onPressed: () => _pickLabelLogoImage(display),
                            ),
                          ),
                          if (display.miuiIslandLabelLogoPath != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: HyperosButton(
                                label: l10n.deleteAction,
                                variant: HyperosButtonVariant.destructive,
                                expand: true,
                                onPressed: () async {
                                  await _deleteManagedImageArtifacts(
                                    directoryName: _labelLogoDir,
                                    filePrefix: widget.forDuringEnd
                                        ? 'during_end_label_logo'
                                        : 'before_class_label_logo',
                                  );
                                  _updateDisplay(
                                    display.copyWith(
                                      clearMiuiIslandLabelLogoPath: true,
                                    ),
                                    clearLabelLogoPath: true,
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (display.miuiIslandLabelLogoPath != null) ...[
                        const SizedBox(height: 12),
                        _ImagePreview(
                          path: display.miuiIslandLabelLogoPath!,
                          imageCornerRadius:
                              display.miuiIslandLabelLogoCornerRadius,
                        ),
                      ],
                    ],
                  ),
                ),
              if (display.miuiIslandLabelStyle ==
                      MiuiIslandLabelStyle.iconAndText &&
                  display.miuiIslandLabelLogoPath != null)
                HyperosSliderTile(
                  title: l10n.liveMiuiLabelLogoCornerRadiusLabel(
                    display.miuiIslandLabelLogoCornerRadius.toStringAsFixed(0),
                  ),
                  value: display.miuiIslandLabelLogoCornerRadius.clamp(
                    0.0,
                    12.0,
                  ),
                  max: 12,
                  divisions: 12,
                  onChanged: (value) => _updateDisplay(
                    display.copyWith(miuiIslandLabelLogoCornerRadius: value),
                    debounce: true,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HyperosControlCardScope.defaultHorizontalPadding,
                  4,
                  HyperosControlCardScope.defaultHorizontalPadding,
                  13,
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _labelColors
                      .map(
                        (color) => _ColorDot(
                          colorHex: color,
                          selected: display.miuiIslandLabelFontColor == color,
                          onTap: () => _updateDisplay(
                            display.copyWith(miuiIslandLabelFontColor: color),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const HyperosSectionGap(),
        HyperosControlCard(
          edgeToEdge: true,
          child: HyperosAccordion(
            items: [
              HyperosAccordionItem(
                insetChild: false,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.liveMiuiLabelAdvancedAccordionTitle,
                      style: HyperosTypography.listTitle(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.liveMiuiLabelAdvancedAccordionSubtitle,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ],
                ),
                child: HyperosControlCardRows(
                  children: [
                    HyperosSliderTile(
                      title: l10n.liveMiuiLabelFontSizeLabel(
                        display.miuiIslandLabelFontSize.toStringAsFixed(0),
                      ),
                      value: display.miuiIslandLabelFontSize,
                      min: 1,
                      max: 32,
                      divisions: 31,
                      onChanged: (value) => _updateDisplay(
                        display.copyWith(miuiIslandLabelFontSize: value),
                        debounce: true,
                      ),
                    ),
                    HyperosSliderTile(
                      title: l10n.liveMiuiLabelOffsetXLabel(
                        display.miuiIslandLabelOffsetX.toStringAsFixed(1),
                      ),
                      value: display.miuiIslandLabelOffsetX.clamp(-2.0, 2.0),
                      min: -2,
                      max: 2,
                      divisions: 40,
                      onChanged: (value) => _updateDisplay(
                        display.copyWith(miuiIslandLabelOffsetX: value),
                        debounce: true,
                      ),
                    ),
                    HyperosSliderTile(
                      title: l10n.liveMiuiLabelOffsetYLabel(
                        display.miuiIslandLabelOffsetY.toStringAsFixed(1),
                      ),
                      value: display.miuiIslandLabelOffsetY.clamp(-2.0, 2.0),
                      min: -2,
                      max: 2,
                      divisions: 40,
                      onChanged: (value) => _updateDisplay(
                        display.copyWith(miuiIslandLabelOffsetY: value),
                        debounce: true,
                      ),
                    ),
                    HyperosSelectTile<MiuiIslandLabelFontWeight>(
                      label: l10n.liveMiuiLabelFontWeightLabel,
                      items: {
                        for (final value in MiuiIslandLabelFontWeight.values)
                          miuiIslandLabelFontWeightLabel(l10n, value): value,
                      },
                      value: display.miuiIslandLabelFontWeight,
                      onChanged: (value) => _updateDisplay(
                        display.copyWith(miuiIslandLabelFontWeight: value),
                      ),
                    ),
                    HyperosSelectTile<MiuiIslandLabelRenderQuality>(
                      label: l10n.liveMiuiLabelRenderQualityLabel,
                      items: {
                        for (final value in MiuiIslandLabelRenderQuality.values)
                          miuiIslandLabelRenderQualityLabel(l10n, value): value,
                      },
                      value: display.miuiIslandLabelRenderQuality,
                      onChanged: (value) => _updateDisplay(
                        display.copyWith(miuiIslandLabelRenderQuality: value),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      const HyperosSectionGap(),
      HyperosSectionLabel(text: l10n.liveExpandedIconSectionTitle),
      HyperosControlCard(
        edgeToEdge: true,
        child: HyperosControlCardRows(
          children: [
            HyperosSelectTile<MiuiIslandExpandedIconMode>(
              label: l10n.liveMiuiExpandedIconLabel,
              items: {
                for (final value in MiuiIslandExpandedIconMode.values)
                  miuiIslandExpandedIconModeLabel(l10n, value): value,
              },
              value: display.miuiIslandExpandedIconMode,
              onChanged: (value) {
                () async {
                  if (value != MiuiIslandExpandedIconMode.customImage) {
                    await _deleteManagedImageArtifacts(
                      directoryName: _expandedIconDir,
                      filePrefix: widget.forDuringEnd
                          ? 'during_end_expanded_icon'
                          : 'before_class_expanded_icon',
                    );
                  }
                  _updateDisplay(
                    display.copyWith(
                      miuiIslandExpandedIconMode: value,
                      clearMiuiIslandExpandedIconPath:
                          value != MiuiIslandExpandedIconMode.customImage,
                    ),
                    clearExpandedIconPath:
                        value != MiuiIslandExpandedIconMode.customImage,
                  );
                }();
              },
            ),
            if (display.miuiIslandExpandedIconMode ==
                MiuiIslandExpandedIconMode.customImage)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HyperosControlCardScope.defaultHorizontalPadding,
                  4,
                  HyperosControlCardScope.defaultHorizontalPadding,
                  // Match last-row bottom of preference tiles (not card bleed).
                  13,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: HyperosButton(
                            label: display.miuiIslandExpandedIconPath == null
                                ? l10n.selectImageAction
                                : l10n.replaceImageAction,
                            variant: HyperosButtonVariant.secondary,
                            expand: true,
                            onPressed: () => _pickExpandedIconImage(display),
                          ),
                        ),
                        if (display.miuiIslandExpandedIconPath != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: HyperosButton(
                              label: l10n.deleteAction,
                              variant: HyperosButtonVariant.destructive,
                              expand: true,
                              onPressed: () async {
                                await _deleteManagedImageArtifacts(
                                  directoryName: _expandedIconDir,
                                  filePrefix: widget.forDuringEnd
                                      ? 'during_end_expanded_icon'
                                      : 'before_class_expanded_icon',
                                );
                                _updateDisplay(
                                  display.copyWith(
                                    clearMiuiIslandExpandedIconPath: true,
                                  ),
                                  clearExpandedIconPath: true,
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (display.miuiIslandExpandedIconPath != null) ...[
                      const SizedBox(height: 12),
                      _ImagePreview(path: display.miuiIslandExpandedIconPath!),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
      const HyperosSectionGap(),
      HyperosSectionLabel(text: l10n.liveExpandedDetailGroupTitle),
      // 「长按拖动调整顺序」说明卡删：实现是右手柄直接拖（说明与行为不符），
      // 行序与预览一致预览就在下方自证，字段缺席原因属实现口径。
      const HyperosSectionGap(),
      _ExpandedDetailGroup(
        display: display,
        fields: _visibleDetailFields,
        l10n: l10n,
        onToggle: (field) => _toggleExpandedDetailField(display, field),
        onReorder: (oldIndex, newIndex) =>
            _reorderExpandedDetailField(display, oldIndex, newIndex),
        onMoveUp: (field) => _moveExpandedDetailFieldBy(display, field, -1),
        onMoveDown: (field) => _moveExpandedDetailFieldBy(display, field, 1),
      ),
      if (display.expandedDetailFields != null) ...[
        const HyperosSectionGap(),
        HyperosListGroup(
          children: [
            HyperosActionTile(
              icon: Icons.restore_rounded,
              title: l10n.resetExpandedDetailDefaultAction,
              onTap: () => _resetExpandedDetailFields(display),
            ),
          ],
        ),
      ],
      const HyperosSectionGap(),
      HyperosSectionLabel(text: l10n.liveIslandExpandedPreviewTitle),
      LiveIslandExpandedPreviewCard(
        display: _followBeforeClass
            ? _draft.beforeClassDisplaySettings
            : display,
        forDuringEnd: widget.forDuringEnd,
        sampleCourse: sampleCourse,
        followBeforeClass: _followBeforeClass,
        endSecondsCountdownThresholdSeconds:
            _draft.liveEndSecondsCountdownThreshold,
        promoteDuringClass: _draft.livePromoteDuringClass,
        anchor: previewAnchor,
        nextCourseName: previewNextCourseName,
      ),
    ];
    final previewLabel = widget.forDuringEnd
        ? l10n.liveStagePreviewDuringClassAction
        : l10n.liveStagePreviewBeforeClassAction;
    return HyperosSubpage(
      // 排序后待落盘的状态已在 dispose 补写；maybePop 同时兼容
      // 返回键与系统返回手势。
      onBack: () => Navigator.maybePop(context),
      title: Text(widget.title),
      child: Stack(
        children: [
          HyperosListView(
            // 底部留出悬浮按钮的高度，末尾卡片不被遮住。
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            children: [
              if (widget.forDuringEnd) ...[
                HyperosSectionLabel(text: l10n.liveDisplayConfigModeTitle),
                HyperosListGroup(
                  children: [
                    HyperosSwitchTile(
                      title: l10n.followBeforeClassDisplayTitle,
                      value: _draft.liveDuringEndFollowBeforeClass,
                      onChanged: (value) => _updateDraft(
                        _draft.copyWith(liveDuringEndFollowBeforeClass: value),
                      ),
                    ),
                  ],
                ),
                const HyperosSectionGap(),
              ],
              HyperosSectionLabel(text: l10n.liveIslandPreviewTitle),
              LiveIslandPreviewCard(
                display: _followBeforeClass
                    ? _draft.beforeClassDisplaySettings
                    : display,
                forDuringEnd: widget.forDuringEnd,
                sampleCourse: sampleCourse,
                followBeforeClass: _followBeforeClass,
                endSecondsCountdownThresholdSeconds:
                    _draft.liveEndSecondsCountdownThreshold,
                anchor: previewAnchor,
              ),
              const HyperosSectionGap(),
              if (_followBeforeClass)
                IgnorePointer(
                  child: AnimatedOpacity(
                    duration: 180.scaledMs,
                    opacity: 0.5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: sectionCards,
                    ),
                  ),
                )
              else
                ...sectionCards,
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _LiveStagePreviewFab(
              label: _stagePreviewActive
                  ? l10n.liveTestingCourseTestStopAction
                  : previewLabel,
              active: _stagePreviewActive,
              busy: _stagePreviewBusy,
              onTap: _stagePreviewActive
                  ? _stopStagePreview
                  : _startStagePreview,
            ),
          ),
        ],
      ),
    );
  }

  void _updateDisplay(
    LiveDisplaySettings next, {
    bool debounce = false,
    bool clearExpandedIconPath = false,
    bool clearLabelLogoPath = false,
    bool clearExpandedDetailFields = false,
  }) {
    final nextSettings = widget.forDuringEnd
        ? _draft.copyWithDuringEndDisplaySettings(
            next,
            clearExpandedIconPath: clearExpandedIconPath,
            clearLabelLogoPath: clearLabelLogoPath,
            clearExpandedDetailFields: clearExpandedDetailFields,
          )
        : _draft.copyWithBeforeClassDisplaySettings(
            next,
            clearExpandedIconPath: clearExpandedIconPath,
            clearLabelLogoPath: clearLabelLogoPath,
            clearExpandedDetailFields: clearExpandedDetailFields,
          );
    _updateDraft(nextSettings, debounce: debounce);
  }

  /// 本页可操作的展开详情字段全集（同时也是默认顺序）：课前页不含
  /// stage / progress / status（恒为提升态，渲染不出行），课中页按提升态
  /// 行序排列。见 [liveExpandedDetailFieldsForStage]。
  List<LiveExpandedDetailField> get _visibleDetailFields =>
      liveExpandedDetailFieldsForStage(forDuringEnd: widget.forDuringEnd);

  /// 展开详情当前工作顺序。见 [resolveExpandedDetailWorkOrder]。
  List<LiveExpandedDetailField> _expandedFieldWorkOrder(
    LiveDisplaySettings display,
  ) => resolveExpandedDetailWorkOrder(
    display,
    forDuringEnd: widget.forDuringEnd,
  );

  /// [ReorderableListView] 的落位回调：把 [oldIndex] 处的字段挪到 [newIndex]。
  ///
  /// 用的是 onReorderItem 回调（非已废弃的 onReorder）：框架已把「插入位」
  /// 校正为目标下标（下移时自动减一），这里直接落位即可，与首页菜单 /
  /// 玻璃 Dock 编辑器同一口径；再手动减一会让下移一格等于没动。
  void _reorderExpandedDetailField(
    LiveDisplaySettings display,
    int oldIndex,
    int newIndex,
  ) {
    final work = _expandedFieldWorkOrder(display);
    if (oldIndex < 0 || oldIndex >= work.length) return;
    final target = newIndex.clamp(0, work.length - 1);
    if (target == oldIndex) return;
    work.insert(target, work.removeAt(oldIndex));
    _updateDisplay(display.copyWith(expandedDetailFields: work));
  }

  void _toggleExpandedDetailField(
    LiveDisplaySettings display,
    LiveExpandedDetailField field,
  ) {
    final work = _expandedFieldWorkOrder(display);
    if (work.contains(field)) {
      // 关到只剩一个时保留「最后开会话」：列表始终至少渲染一行，且用户
      // 关掉最后一行的意图显然是隐藏它，而不是被静默顶回默认全开。
      if (work.length == 1) return;
      work.remove(field);
    } else {
      work.add(field);
    }
    _updateDisplay(display.copyWith(expandedDetailFields: work));
  }

  /// 无障碍「上移 / 下移」：把某个字段在已显示顺序里挪一格。
  ///
  /// 手柄在 TalkBack 下不好拖，补这组自定义动作；边界处由 [delta] 越界返回。
  void _moveExpandedDetailFieldBy(
    LiveDisplaySettings display,
    LiveExpandedDetailField field,
    int delta,
  ) {
    final work = _expandedFieldWorkOrder(display);
    final index = work.indexOf(field);
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= work.length) return;
    work.insert(target, work.removeAt(index));
    _updateDisplay(display.copyWith(expandedDetailFields: work));
  }

  /// 重置「展开详情」为本页可见集：名单清空回 null（未自定义），页面即按
  /// 本阶段默认顺序与全显示渲染，与真机两套默认行序一致。
  void _resetExpandedDetailFields(LiveDisplaySettings display) =>
      _updateDisplay(
        display.copyWith(clearExpandedDetailFields: true),
        clearExpandedDetailFields: true,
      );

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() => _draft = next);
    _autoSaveTimer?.cancel();
    if (debounce) {
      _autoSaveTimer = Timer(
        const Duration(milliseconds: 250),
        () => _enqueuePersist(next),
      );
      return;
    }
    _enqueuePersist(next);
  }

  void _enqueuePersist(TimetableSettings next) {
    _saveQueue = _saveQueue.catchError((_) {}).then((_) => _persistDraft(next));
  }

  Future<void> _persistDraft(TimetableSettings next) async {
    final provider = context.read<TimetableProvider>();
    // 草稿快照可能比真源旧：节次表与激活作息一律回灌，避免把换季批量套用的
    // 结果顺手回滚（见 TimetableSettings.withLiveScheduleFieldsFrom）。
    String? message;
    try {
      message = await provider.updateTimetableSettings(
        next.withLiveScheduleFieldsFrom(provider.settings),
      );
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    if (!mounted) return;
    if (message != null) {
      showAppToast(
        context,
        message: localizeServiceMessage(AppLocalizations.of(context)!, message),
      );
      setState(() => _draft = provider.settings);
    } else if (currentLiveCourseTestSession() != null) {
      unawaited(
        hotUpdateLiveCourseTestSession(LiveTestingProviderAccess(provider)),
      );
    }
  }

  Future<void> _pickExpandedIconImage(LiveDisplaySettings display) async {
    final targetPath = await _pickAndStoreImage(
      directoryName: _expandedIconDir,
      filePrefix: widget.forDuringEnd
          ? 'during_end_expanded_icon'
          : 'before_class_expanded_icon',
    );
    if (!mounted || targetPath == null) return;
    _updateDisplay(
      display.copyWith(
        miuiIslandExpandedIconMode: MiuiIslandExpandedIconMode.customImage,
        miuiIslandExpandedIconPath: targetPath,
      ),
    );
  }

  Future<void> _pickLabelLogoImage(LiveDisplaySettings display) async {
    final targetPath = await _pickAndStoreImage(
      directoryName: _labelLogoDir,
      filePrefix: widget.forDuringEnd
          ? 'during_end_label_logo'
          : 'before_class_label_logo',
    );
    if (!mounted || targetPath == null) return;
    _updateDisplay(display.copyWith(miuiIslandLabelLogoPath: targetPath));
  }

  Future<String?> _pickAndStoreImage({
    required String directoryName,
    required String filePrefix,
  }) async {
    // 刻意不用 withData: true —— 那会在任何体积检查之前把整个文件读进内存，而
    // Android 内存不足是直接杀进程、不抛可捕获异常。c461c54 / d6f772f 已按这条
    // 口径给四条文件入口补了 20MB 上限，超级岛这两个图片入口是漏网的：用户选一张
    // 相机原图就会当场被杀，表现为「点了没反应」。
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (!mounted || result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final sourcePath = file.path;
    if (sourcePath == null) return null;
    final source = File(sourcePath);
    if (!source.existsSync()) return null;
    final tooLarge =
        await source.length() > UnifiedTransferService.maxImportFileBytes;
    if (tooLarge) {
      // 又一次 await 之后才用 context：先确认组件还挂载着。
      if (!mounted) return null;
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.importFileTooLarge(
          formatByteBudget(UnifiedTransferService.maxImportFileBytes),
        ),
      );
      return null;
    }
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) return null;
    final ext = (file.extension?.isNotEmpty ?? false)
        ? file.extension!.toLowerCase()
        : 'png';
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(
      '${dir.path}${Platform.pathSeparator}$directoryName',
    );
    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }
    final targetPath =
        '${targetDir.path}${Platform.pathSeparator}$filePrefix.$ext';
    await File(targetPath).writeAsBytes(bytes, flush: true);
    await _deleteManagedImageArtifacts(
      directoryName: directoryName,
      filePrefix: filePrefix,
      preservePath: targetPath,
    );
    return targetPath;
  }

  Future<void> _deleteManagedImageArtifacts({
    required String directoryName,
    required String filePrefix,
    String? preservePath,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(
      '${dir.path}${Platform.pathSeparator}$directoryName',
    );
    if (!targetDir.existsSync()) {
      return;
    }
    final preservedAbsolutePath = preservePath == null
        ? null
        : File(preservePath).absolute.path;
    var deleted = 0;
    var failed = 0;
    await for (final entity in targetDir.list()) {
      if (entity is! File) {
        continue;
      }
      final fileName = entity.uri.pathSegments.isEmpty
          ? ''
          : entity.uri.pathSegments.last;
      if (!fileName.startsWith('$filePrefix.')) {
        continue;
      }
      if (preservedAbsolutePath != null &&
          entity.absolute.path == preservedAbsolutePath) {
        continue;
      }
      try {
        if (entity.existsSync()) {
          await entity.delete();
          deleted++;
        }
      } catch (_) {
        // 单文件删除失败不中断清理循环；汇总计数后统一留一条 debug
        // 痕迹，避免历史生成图片静默累积且无观测手段。
        failed++;
      }
    }
    if (failed > 0) {
      // 走 AppLogService 而非 debugPrint：包在 assert 里的输出 release 包
      // 会被整体剥离，清理失败恰恰最需要 release 可观测。warn 失败不外抛。
      try {
        await AppLogService.instance.warn(
          'live_island_artifact_cleanup_failed',
          'Live island preview artifact cleanup had failures',
          extras: {
            'deleted': deleted,
            'failed': failed,
            'dir': directoryName,
            'prefix': filePrefix,
          },
        );
      } catch (_) {
        // 日志通道不可用时静默，不影响清理主流程。
      }
    }
  }
}

/// 底部悬浮「速览」按钮：首页「回本周 / 回今日」浮钮同款的标准玻璃胶囊。
///
/// 材质**锁液态玻璃的标准档**（[LiquidGlassRole.pinnedChrome]，与弹窗家族 /
/// 设置页返回键同一档）：全局材质档位、模糊总开关都不参与 —— 固定小件的
/// 观感必须与其他固定小件一致。门禁回落链与弹层族同口径：
///
/// - 采不到背景（平台视图上方 / 系统无障碍降级）→ 实体卡片；
/// - 只是画不出折射（无 shader 后端，如桌面 / 测试环境）→ 实时磨砂玻璃 + 描边。
///
/// 浮影用 [HyperosGlassShadow.compactShadow]（玻璃坞药丸与两颗浮钮同款）：
/// 浅色页面底上轻轻分开边界，不把大范围阴影铺进旁边的模糊区。液态档
/// 不叠描边（玻璃自带折射带），磨砂回落必须描边（磨砂片自己不画边）。
class _LiveStagePreviewFab extends StatelessWidget {
  const _LiveStagePreviewFab({
    required this.label,
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool busy;
  final VoidCallback? onTap;

  /// 成品高度 = 圆角直径（48 = 审计 pill 豁免线，胶囊形）。
  static const double _height = 48;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    // 玻璃底上的墨色走全 app 主题色口径（回今日浮钮同款）：idle 主题色、
    // 停止态红色 —— 底是玻璃，"跟随主题色"落在内容上。
    final ink = active
        ? HyperosColors.error(context)
        : HyperosColors.primary(context);
    final radius = BorderRadius.circular(_height / 2);

    // 按压内容：图标 + 文字，两条材质分支共用，只有「底」不同。
    Widget chipBody() => Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        borderRadius: radius,
        child: Opacity(
          // busy 时内容压半透（底仍是玻璃），与磨砂/液态两档都兼容。
          opacity: busy ? 0.55 : 1.0,
          child: SizedBox(
            height: _height,
            child: Padding(
              // 4dp 网格口径：24 = 16 + 8（settingsRowPadding 同源）。
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ink,
                      ),
                    )
                  else
                    Icon(
                      active ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 20,
                      color: ink,
                    ),
                  const SizedBox(width: 8),
                  Text(label, style: HyperosTypography.title(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // 磨砂回落：既是"画不出折射"时的玻璃观感，与玻璃坞磨砂底同参。
    Widget frostedChip() => ClipRRect(
      borderRadius: radius,
      child: HyperosFrostedSurface(
        borderRadius: radius,
        tint: HyperosBlurredHeader.sheetTintColor(context, withBlur: true),
        child: chipBody(),
      ),
    );

    // 描边按「液态是否真的画得出来」判：着色器后端缺失时表面整层回落成
    // 磨砂片，此时描边必须回来（磨砂片自己不画边）；液态档不描边，避免
    // 与玻璃自己的折射带叠成两层圈圈。
    final liquidActuallyRenders = LiquidGlassSurface.isAvailable(
      context,
      LiquidGlassRole.pinnedChrome,
    );

    final surface = LiquidGlassSurface(
      borderRadius: _height / 2,
      role: LiquidGlassRole.pinnedChrome,
      // 窄件几何适配：48dp 短边 < 52 窄件阈值，全量折射带会连成一整圈
      // 轮廓（见 [narrowSurfaceMaxRefraction]）。
      maxRefraction: narrowSurfaceMaxRefraction(_height),
      // 采不到背景（平台视图上方 / 系统无障碍降级）→ 实体卡片，不再透明。
      fallbackBuilder: (fallbackContext) =>
          LiquidGlassDegradation.shouldDegrade(fallbackContext)
          ? Material(
              color: HyperosColors.surfaceContainer(fallbackContext),
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: chipBody(),
            )
          : frostedChip(),
      child: chipBody(),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HyperosGlassShadow.wrap(
              borderRadius: radius,
              shadowOverride: HyperosGlassShadow.compactShadow,
              shadowKey: const ValueKey('live-stage-preview-fab-shadow'),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: liquidActuallyRenders
                      ? null
                      : Border.all(color: HyperosColors.outline(context)),
                ),
                child: surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveKeepAliveSettingsScreen extends StatefulWidget {
  const LiveKeepAliveSettingsScreen({super.key});
  @override
  State<LiveKeepAliveSettingsScreen> createState() =>
      _LiveKeepAliveSettingsScreenState();
}

class _LiveKeepAliveSettingsScreenState
    extends State<LiveKeepAliveSettingsScreen>
    with WidgetsBindingObserver {
  final MiuiLiveActivitiesService _liveService = MiuiLiveActivitiesService();
  late TimetableSettings _draft;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draft = context.read<TimetableProvider>().settings;
    unawaited(_refresh(retryIfDisabled: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh(retryIfDisabled: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.liveKeepAliveTitle),
      child: HyperosListView(
        children: [
          // 单组页面不再拉「保活选项」分组标签：页标题「后台保活」已说清。
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                title: l10n.hideFromRecentsTitle,
                value: _draft.liveHideFromRecents,
                onChanged: (value) async {
                  final provider = context.read<TimetableProvider>();
                  String? message;
                  try {
                    message = await provider.updateTimetableSettings(
                      _draft.copyWith(liveHideFromRecents: value),
                    );
                  } catch (_) {
                    if (!context.mounted) return;
                    showAppToast(
                      context,
                      message: l10n.saveFailed,
                      kind: AppToastKind.error,
                    );
                    return;
                  }
                  if (!context.mounted) return;
                  if (message != null) {
                    showAppToast(
                      context,
                      message: localizeServiceMessage(l10n, message),
                    );
                  }
                  setState(() => _draft = provider.settings);
                },
              ),
              _LiveKeepAliveServiceTile(
                enabled: _enabled,
                onOpenSettings: _openSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    // 无障碍保活属于敏感权限：跳系统设置前先弹窗说明用途与边界（不读屏、
    // 不代点），用户确认后再进入系统设置，降低误开与投诉风险。
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.keepAliveConfirmTitle,
      message: l10n.keepAliveConfirmBody,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.keepAliveConfirmGoAction,
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await _liveService.openAccessibilitySettings();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _refresh(retryIfDisabled: true);
  }

  Future<void> _refresh({bool retryIfDisabled = false}) async {
    var enabled = await _liveService.isKeepAliveAccessibilityEnabled();
    if (!enabled && retryIfDisabled) {
      for (var i = 0; i < 3 && !enabled; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        enabled = await _liveService.isKeepAliveAccessibilityEnabled();
      }
    }
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
    });
  }
}

/// 「勿扰模式访问权限」提示行：只在选了免打扰档时出现。
///
/// 缺这项权限时通知上的按钮既不报错也没反应，用户没有任何线索知道
/// 该去哪里授权，所以把状态与入口直接摆在设置项下面。
class _DoNotDisturbAccessTile extends StatefulWidget {
  const _DoNotDisturbAccessTile({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  State<_DoNotDisturbAccessTile> createState() =>
      _DoNotDisturbAccessTileState();
}

class _DoNotDisturbAccessTileState extends State<_DoNotDisturbAccessTile>
    with WidgetsBindingObserver {
  bool _granted = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置页返回时重新读一次，授权完立刻变绿。
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final granted = await MiuiLiveActivitiesService()
        .isDoNotDisturbAccessGranted();
    if (!mounted) return;
    setState(() {
      _granted = granted;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    // 未探到状态前不猜：宁可显示中性色，也不要在权限其实已授予时
    // 摆一条橙色的「未开启」吓人。
    final unknown = !_checked;
    final iconAccent = unknown
        ? HyperosIconColors.blue
        : (_granted ? HyperosIconColors.green : HyperosIconColors.orange);
    final statusLabel = unknown
        ? l10n.guideStatusSuggestedCheck
        : (_granted ? l10n.guideStatusEnabled : l10n.guideStatusDisabled);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowMinHeight,
      ),
      child: Padding(
        padding: HyperosTokens.rowPaddingUniform,
        child: Row(
          children: [
            HyperosIconBadge(
              icon: _granted
                  ? Icons.check_circle_rounded
                  : Icons.do_not_disturb_on_outlined,
              accent: iconAccent,
            ),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.guideStatusDoNotDisturbAccess,
                    style: HyperosTypography.listTitle(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.guideStatusDoNotDisturbAccessHint,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Text(
              statusLabel,
              style: HyperosTypography.listDetail(context),
            ),
          ],
        ),
      ),
    );

    return HyperosPressableRow(
      onTap: widget.onOpenSettings,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}

class _LiveKeepAliveServiceTile extends StatelessWidget {
  const _LiveKeepAliveServiceTile({
    required this.enabled,
    required this.onOpenSettings,
  });

  final bool enabled;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final iconAccent = enabled
        ? HyperosIconColors.green
        : HyperosIconColors.orange;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowMinHeight,
      ),
      child: Padding(
        padding: HyperosTokens.rowPaddingUniform,
        child: Row(
          children: [
            HyperosIconBadge(
              icon: enabled
                  ? Icons.check_circle_rounded
                  : Icons.accessibility_new_rounded,
              accent: iconAccent,
            ),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.keepAliveServiceTitle,
                    style: HyperosTypography.listTitle(context),
                  ),
                  // 状态副标题删：绿勾/橙图标已表达状态，「当前已开启」后半句
                  // 复述标题；未开启态的「可进入系统无障碍设置…」是右侧按钮的说明书。
                ],
              ),
            ),
            // 已开启时隐藏「去开启」：按钮唯一用途是开启，开着再引去确认弹窗是噪声。
            if (!enabled) ...[
              const SizedBox(width: 8),
              HyperosButton(
                label: l10n.goEnableAction,
                variant: HyperosButtonVariant.secondary,
                onPressed: onOpenSettings,
              ),
            ],
          ],
        ),
      ),
    );

    return HyperosPressableRow(
      onTap: onOpenSettings,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}

class _ColorDot extends StatelessWidget {
  final String colorHex;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.colorHex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _parseColor(colorHex),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final String path;
  final double imageCornerRadius;

  const _ImagePreview({required this.path, this.imageCornerRadius = 12});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(imageCornerRadius),
            child: file.existsSync()
                ? Image.file(
                    file,
                    width: 56,
                    height: 56,
                    // width/height 只是布局尺寸；不给 cache* 就按原图全尺寸解码，
                    // 一张 12MP 照片约 48MB RGBA 会整个进 ImageCache（同仓正解见
                    // settings_timetable_page.dart:582 的 cacheWidth: 240）。
                    cacheWidth: 168,
                    cacheHeight: 168,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 56,
                        height: 56,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      );
                    },
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              path,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.theme.typography.body.xs2,
            ),
          ),
        ],
      ),
    );
  }
}

Color _parseColor(String hexColor) {
  return parseHexColorOrFallback(hexColor, fallback: const Color(0xFF2563EB));
}

/// 展开详情分组：已显示区可拖拽排序（HyperosListGroup 卡片 + 拖动手柄），
/// 已隐藏区排在后面、只有开关没有手柄。
///
/// 与「首页八宫格编辑器」同一套交互语言，不再用行首上/下箭头——箭头按钮
/// 既不像本项目控件，也让人分不清哪些行能拖。
///
/// [fields] 是本页可操作的字段全集（同时也是默认顺序）：课前页不含
/// stage / progress / status（恒为提升态，渲染不出行），列表与预览、
/// 真机严格一致——列表上的每一行都对应展开态里真实存在的一行。
/// 见 `liveExpandedDetailFieldsForStage`。
class _ExpandedDetailGroup extends StatelessWidget {
  const _ExpandedDetailGroup({
    required this.display,
    required this.fields,
    required this.l10n,
    required this.onToggle,
    required this.onReorder,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final LiveDisplaySettings display;

  /// 本页可见字段（顺序即默认行序），由页面按阶段给出。
  final List<LiveExpandedDetailField> fields;

  final AppLocalizations l10n;
  final ValueChanged<LiveExpandedDetailField> onToggle;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<LiveExpandedDetailField> onMoveUp;
  final ValueChanged<LiveExpandedDetailField> onMoveDown;

  @override
  Widget build(BuildContext context) {
    final enabledList = _enabledFields;
    final hiddenList = _hiddenFields(enabledList);

    return HyperosListGroup(
      children: [
        if (enabledList.isNotEmpty)
          ReorderableListView.builder(
            key: const ValueKey('expanded-detail-enabled'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: enabledList.length,
            onReorderItem: onReorder,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final elevation = Tween<double>(
                    begin: 0,
                    end: 6,
                  ).animate(animation);
                  return Material(
                    elevation: elevation.value,
                    borderRadius: BorderRadius.circular(16),
                    color: HyperosColors.card(context),
                    child: child,
                  );
                },
              );
            },
            itemBuilder: (context, index) {
              final field = enabledList[index];
              return _ExpandedDetailFieldRow(
                key: ValueKey(field),
                index: index,
                title: liveExpandedDetailFieldLabel(l10n, field),
                enabled: true,
                reorderable: true,
                handleLabel: l10n.liveExpandedDetailReorderHandleLabel,
                moveUpLabel: l10n.liveExpandedDetailMoveUpAction,
                moveDownLabel: l10n.liveExpandedDetailMoveDownAction,
                canMoveUp: index > 0,
                canMoveDown: index < enabledList.length - 1,
                onMoveUp: () => onMoveUp(field),
                onMoveDown: () => onMoveDown(field),
                onToggle: () => onToggle(field),
              );
            },
          ),
        if (hiddenList.isNotEmpty) ...[
          _HiddenFieldsCaption(
            title: l10n.liveExpandedDetailHiddenCaption,
            showDivider: enabledList.isNotEmpty,
          ),
          for (final field in hiddenList)
            _ExpandedDetailFieldRow(
              key: ValueKey(field),
              title: liveExpandedDetailFieldLabel(l10n, field),
              enabled: false,
              onToggle: () => onToggle(field),
            ),
        ],
      ],
    );
  }

  /// 已显示字段：名单未设置 → 全部按默认顺序显示；已设置 → 名单 ∩ 可见集。
  List<LiveExpandedDetailField> get _enabledFields =>
      display.expandedDetailFields == null
      ? List.of(fields)
      : [
          for (final field in display.expandedDetailFields!)
            if (fields.contains(field)) field,
        ];

  List<LiveExpandedDetailField> _hiddenFields(
    List<LiveExpandedDetailField> enabledFields,
  ) => [
    for (final field in fields)
      if (!enabledFields.contains(field)) field,
  ];
}

/// 展开详情字段列表中「已隐藏」区块的标题行。
class _HiddenFieldsCaption extends StatelessWidget {
  const _HiddenFieldsCaption({required this.title, this.showDivider = false});

  final String title;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider) const HyperosInsetDivider(indent: 0),
        hyperosListRowShell(
          padding: hyperosRowPadding(context),
          child: Text(
            title,
            style: HyperosTypography.listDetail(
              context,
            ).copyWith(color: HyperosColors.secondaryText(context)),
          ),
        ),
      ],
    );
  }
}

/// 展开详情字段的一行：拖动手柄 + 标题 + 显示开关。
///
/// 行首不再是上/下箭头按钮（不像本项目控件且不好用），改为与首页八宫格
/// 编辑器一致的拖动手柄；隐藏区的行没有手柄，靠开关重新加回已显示区。
/// 手柄区「点下去不切开关」（想拖结果切了开关很反直觉），拖动本身由
/// [ReorderableDragStartListener] 的 Listener 起手，不经过手势竞技场。
class _ExpandedDetailFieldRow extends StatelessWidget {
  const _ExpandedDetailFieldRow({
    super.key,
    required this.title,
    required this.enabled,
    required this.onToggle,
    this.index,
    this.reorderable = false,
    this.handleLabel,
    this.moveUpLabel,
    this.moveDownLabel,
    this.canMoveUp = false,
    this.canMoveDown = false,
    this.onMoveUp,
    this.onMoveDown,
  });

  /// 已显示区在 [ReorderableListView] 中的下标；隐藏区为 null。
  final int? index;
  final String title;
  final bool enabled;
  final VoidCallback onToggle;
  final bool reorderable;
  final String? handleLabel;

  /// 长按排序的无障碍开关：手柄本身在 TalkBack 下不好拖，补一组
  /// 「上移 / 下移」自定义动作（不开可视按钮，避免又回到箭头矩阵）。
  final String? moveUpLabel;
  final String? moveDownLabel;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final primary = HyperosColors.primaryText(context);
    final titleStyle = HyperosTypography.listTitle(
      context,
    ).copyWith(color: enabled ? primary : primary.withValues(alpha: 0.45));

    final handle = reorderable && index != null;
    final row = hyperosListRowShell(
      padding: hyperosRowPadding(context),
      child: Row(
        children: [
          if (handle) ...[
            // 手柄热区要「点了不切开关」：行级 onTap 在祖先节点，手势竞技场
            // 里内层识别器先入、pointer-up 时先接受——这里包一层 no-op
            // GestureDetector（opaque 铺满整个手柄格），普通点击被它吃掉，
            // 祖先行永远收不到 tap；拖动不走竞技场，由 Listener 的
            // onPointerDown 直接起 ImmediateMultiDrag，不受影响。
            SizedBox(
              width: HyperosTokens.listRowMinHeight,
              child: ReorderableDragStartListener(
                index: index!,
                child: Semantics(
                  label: handleLabel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: Center(
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 20,
                        color: HyperosColors.secondaryText(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),

          // 与 HyperosSwitchTile 一致：整行是唯一开关目标，避免行与开关
          // 在同一处触点上抢手势。
          AbsorbPointer(
            child: HyperosSwitch(value: enabled, onChanged: (_) => onToggle()),
          ),
        ],
      ),
    );

    // 隐藏区行没有手柄，整行按压即切开关；已显示区的整行按压由
    // [onToggle] 承接，拖动只从手柄发起。
    final pressable = HyperosPressableRow(
      onTap: onToggle,
      backgroundColor: HyperosColors.card(context),
      highlightColor: HyperosColors.rowHighlight(context),
      child: row,
    );
    final upLabel = moveUpLabel;
    final downLabel = moveDownLabel;
    final actions = <CustomSemanticsAction, VoidCallback>{};
    if (enabled && canMoveUp && onMoveUp != null && upLabel != null) {
      actions[CustomSemanticsAction(label: upLabel)] = onMoveUp!;
    }
    if (enabled && canMoveDown && onMoveDown != null && downLabel != null) {
      actions[CustomSemanticsAction(label: downLabel)] = onMoveDown!;
    }
    if (actions.isEmpty) {
      return pressable;
    }
    return Semantics(customSemanticsActions: actions, child: pressable);
  }
}
