import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/timetable_settings.dart';
import '../services/bundled_assets.dart';
import '../services/miui_live_activities_service.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/hex_color.dart';

/// Real-time HyperOS super-island capsule preview.
///
/// 还原真实摘要态胶囊的单行左右分区：中间是摄像头开孔；左侧只有通知小图标位，
/// 右侧是整条 islandCriticalText（课程名 + 地点 + 状态）。也就是说——「显示
/// 内容」那组开关（课程名 / 简称 / 地点 / 倒计时 / 阶段文字 / 前缀）控制的是
/// **右侧文本**，左侧图标位只由下面的实验性图片开关（小米岛左侧文字图标）和
/// 机型能力决定。展开态的详情行由下方的 [LiveIslandExpandedPreviewCard] 负责。
///
/// 与原生 `MainActivity.kt` 的对应关系。真机摘要态胶囊的文本来自提升通知的
/// shortCriticalText，即 islandCriticalText 的组合规则：
///
/// * 左侧小图标位 = 通知 smallIcon（不承载文本）：
///   - 开启自定义标签（enableMiuiIslandLabelImage）时 = 原生
///     buildIslandLabelBitmap() 生成的位图（图标/自定义 Logo + 标签文字，
///     颜色、字号、字重、圆角均跟随设置）；
///   - 否则小米系机型 = 随阶段切换的白色模板图标（ic_upcoming / ic_course /
///     ic_countdown）；
///   - 否则（非小米系机型且未开自定义标签）= **空**：非小米机型没有超级岛，
///     原生 resolveIslandLabelBitmap() 也会因 !isXiaomiFamilyDevice() 直接
///     返回 null，设置只影响右侧文本。
/// * 右侧文本 = islandCriticalText = [islandCourseName, islandLocation,
///   islandCriticalStatusText] 过滤空白后以空格拼接（与原生同一行代码）：
///   - islandCourseName 受 showCourseName 门控，课程名跟随 useShortName 并按
///     原生规则截断 5 字；
///   - islandLocation 受 showLocation 门控；
///   - islandCriticalStatusText：课中且显示倒计时时 =
///     classProgress.criticalTimeText 裸倒计时（不带“距下课”前缀），样式由
///     countdownTextStyle 决定；原生 nearest 模式会优先最近课间节点的剩余
///     时间，示例课为单节课、没有课间节点（buildLiveProgressMilestones 对
///     单节课返回空），因此与 total 模式同为整节剩余时间；其余情况 =
///     visibleStatusText，受 showCountdown → showStageText 控制，倒计时前缀
///     （距上课/距下课）受 hidePrefixText 控制。
///
/// 注意：原生参数里的 progressInfo（环形进度）/ progressTextInfo 服务于点开
/// 后的展开态卡片（由系统渲染），摘要态胶囊没有它；本预览只模拟摘要态，
/// 因此不画环与节点条。原生的发送逻辑保持不变。
class LiveIslandPreviewCard extends StatefulWidget {
  const LiveIslandPreviewCard({
    super.key,
    required this.display,
    required this.forDuringEnd,
    this.followBeforeClass = false,
    this.endSecondsCountdownThresholdSeconds = 60,
  });

  final LiveDisplaySettings display;

  /// 课中/下课提醒页传 true：该页同时预览「上课中」与「下课提醒」两个岛；
  /// 课前提醒页传 false：只预览「即将上课」岛。
  final bool forDuringEnd;

  /// True on the during/end page while it follows the before-class config;
  /// renders an explanatory badge instead of silently previewing.
  final bool followBeforeClass;

  /// Native endSecondsCountdownThreshold; only the before-end right-side
  /// countdown formatting uses it (computeRemainingText parity).
  final int endSecondsCountdownThresholdSeconds;

  @override
  State<LiveIslandPreviewCard> createState() => _LiveIslandPreviewCardState();
}

enum _PreviewStage { beforeClass, duringClass, beforeEnd }

/// 阶段词：即将上课 / 上课中 / 下课提醒（对应原生 stage_* 字符串）。
String _stageWord(AppLocalizations l10n, _PreviewStage stage) {
  switch (stage) {
    case _PreviewStage.beforeClass:
      return l10n.liveIslandPreviewStageBeforeClass;
    case _PreviewStage.duringClass:
      return l10n.liveIslandPreviewStageInClass;
    case _PreviewStage.beforeEnd:
      return l10n.liveIslandPreviewStageBeforeEnd;
  }
}

/// 对应原生 ic_upcoming / ic_course / ic_countdown 三枚白色矢量图标的
/// 最接近的 Material 字形。
IconData _stageSmallIconData(_PreviewStage stage) => switch (stage) {
      _PreviewStage.beforeClass => Icons.access_time,
      _PreviewStage.duringClass => Icons.import_contacts,
      _PreviewStage.beforeEnd => Icons.check_circle_outline,
    };

class _LiveIslandPreviewCardState extends State<LiveIslandPreviewCard> {
  static const _pillColor = Color(0xFF060608);
  static const _defaultLabelColor = Color(0xFFFFFFFF);

  late final DateTime _anchor = DateTime.now();
  Timer? _ticker;
  bool _isXiaomiFamily = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    _detectXiaomiFamily();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// 只有小米系机型才会真正渲染自定义标签（isXiaomiFamilyDevice()），
  /// 预览同样按机型能力展示。
  Future<void> _detectXiaomiFamily() async {
    try {
      final status =
          await MiuiLiveActivitiesService().getLiveUpdateDebugStatus();
      final environment = status['environment'];
      final flag = environment is Map
          ? environment['isXiaomiFamilyDevice']
          : null;
      if (mounted) {
        setState(() => _isXiaomiFamily = flag == true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isXiaomiFamily = false);
      }
    }
  }

  // --- Demo course windows anchored at [_anchor]; numbers tick naturally ---

  ({DateTime start, DateTime end}) get _beforeWindow {
    final start = _anchor.add(const Duration(minutes: 12, seconds: 37));
    return (start: start, end: start.add(const Duration(minutes: 45)));
  }

  ({DateTime start, DateTime end}) get _endWindow {
    final start = _anchor.subtract(const Duration(minutes: 41, seconds: 40));
    return (start: start, end: start.add(const Duration(minutes: 45)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final d = widget.display;
    final stages = widget.forDuringEnd
        ? const [_PreviewStage.duringClass, _PreviewStage.beforeEnd]
        : const [_PreviewStage.beforeClass];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.followBeforeClass)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.liveIslandPreviewFollowBadge,
                    style: HyperosTypography.listDetail(context),
                  ),
                ),
              ],
            ),
          ),
        for (var index = 0; index < stages.length; index++) ...[
          if (stages.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _stageWord(l10n, stages[index]),
                style: HyperosTypography.listDetail(context),
              ),
            ),
          _IslandCapsule(
            iconSlot: _buildSmallIcon(l10n, d, stages[index]),
            criticalText: _criticalText(l10n, stages[index], d),
          ),
          if (index != stages.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  // --- Left icon slot (notification small-icon position) ------------------

  Widget _buildSmallIcon(
    AppLocalizations l10n,
    LiveDisplaySettings d,
    _PreviewStage stage,
  ) {
    // 实验性左图（小米岛左侧文字图标）优先：开关打开就按配置预览左图；
    // 非小米真机上原生 resolveIslandLabelBitmap() 会因 !isXiaomiFamilyDevice()
    // 放弃下发，预览里仍按开关展示，方便先调样式。
    if (d.enableMiuiIslandLabelImage) {
      return _buildIslandLabel(l10n, d);
    }
    // 非小米机型没有超级岛：左侧图标位为空，设置只影响右侧文本。
    if (!_isXiaomiFamily) {
      return const SizedBox.shrink();
    }
    // 原生 setSmallIcon：beforeClass=ic_upcoming（时钟）、
    // duringClass=ic_course（书）、beforeEnd=ic_countdown（对勾圆环），
    // 都是白色模板图标而不是应用图标。
    return SizedBox.square(
      dimension: 28,
      child: Icon(_stageSmallIconData(stage), size: 24, color: Colors.white),
    );
  }

  Widget _buildIslandLabel(AppLocalizations l10n, LiveDisplaySettings d) {
    // 原生 buildIslandLabelBitmap：可选图标部分 + 自动缩放的标签文字。
    final includeIcon =
        d.miuiIslandLabelStyle == MiuiIslandLabelStyle.iconAndText;
    final nameToUse = d.useShortName
        ? l10n.liveIslandPreviewSampleCourseShort
        : l10n.liveIslandPreviewSampleCourse;
    final labelText = switch (d.miuiIslandLabelContent) {
      MiuiIslandLabelContent.courseName => nameToUse,
      MiuiIslandLabelContent.location =>
        l10n.liveIslandPreviewSampleLocation,
      MiuiIslandLabelContent.courseNameAndLocation =>
        '$nameToUse ${l10n.liveIslandPreviewSampleLocation}',
    };
    final fontWeight = switch (d.miuiIslandLabelFontWeight) {
      MiuiIslandLabelFontWeight.medium => FontWeight.w500,
      MiuiIslandLabelFontWeight.bold => FontWeight.w700,
      MiuiIslandLabelFontWeight.regular => FontWeight.w400,
    };
    final label = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          labelText,
          maxLines: 1,
          style: TextStyle(
            color: parseHexColorOrFallback(
              d.miuiIslandLabelFontColor,
              fallback: _defaultLabelColor,
            ),
            fontSize: d.miuiIslandLabelFontSize.clamp(4.0, 32.0),
            fontWeight: fontWeight,
          ),
        ),
      );
    if (!includeIcon) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: label,
      );
    }
    final logoPath = d.miuiIslandLabelLogoPath;
    final corner = d.miuiIslandLabelLogoCornerRadius.clamp(0.0, 12.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(corner),
          child: logoPath != null
              ? Image.file(
                  File(logoPath),
                  width: 22,
                  height: 22,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _appIconImage(22),
                )
              : _appIconImage(22),
        ),
        const SizedBox(width: 3),
        Flexible(child: label),
      ],
    );
  }

  /// 应用图标圆角位图（对应原生 buildRoundedLauncherIcon）。
  Widget _appIconImage(double size) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset(
          BundledAssets.launcherIcon,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );

  // --- Right critical text (islandCriticalText) ---------------------------

  /// 与原生同一行规则：`listOf(islandCourseName, islandLocation,
  /// islandCriticalStatusText).filter { isNotBlank }.joinToString(" ")`。
  /// 三者都渲染在摄像头右侧——「显示内容」那组开关影响的正是这里。
  String _criticalText(
    AppLocalizations l10n,
    _PreviewStage stage,
    LiveDisplaySettings d,
  ) {
    final name = _islandCourseName(l10n, d);
    final location = d.showLocation ? l10n.liveIslandPreviewSampleLocation : '';
    final status = _statusLine(l10n, stage, d);
    return [name, location, status].where((part) => part.isNotEmpty).join(' ');
  }

  /// islandCourseName：showCourseName / useShortName + 原生 5 字截断。
  String _islandCourseName(AppLocalizations l10n, LiveDisplaySettings d) {
    if (!d.showCourseName) {
      return '';
    }
    final name = d.useShortName
        ? l10n.liveIslandPreviewSampleCourseShort
        : l10n.liveIslandPreviewSampleCourse;
    return name.length > 5 ? name.substring(0, 5) : name;
  }

  // --- Right status line (ports of MainActivity.kt rules) -----------------

  /// islandCriticalStatusText：课中且显示倒计时时 = criticalTimeText，
  /// 其余情况 = visibleStatusText。
  String _statusLine(
    AppLocalizations l10n,
    _PreviewStage stage,
    LiveDisplaySettings d,
  ) {
    final isDuringOrEndingSoon =
        stage == _PreviewStage.duringClass || stage == _PreviewStage.beforeEnd;
    if (isDuringOrEndingSoon &&
        d.showCountdown &&
        stage == _PreviewStage.duringClass) {
      // 原生只在 duringClass 阶段构建 classProgress；beforeEnd 阶段
      // classProgress == null，回退到带前缀的 visibleStatusText。
      return _duringClassCriticalTime(d);
    }
    return _visibleStatusText(l10n, stage, d);
  }

  /// computeRemainingText + ifBlank(stageTitle)：!showCountdown 时由
  /// showStageText 决定阶段词；倒计时前缀受 hidePrefixText 控制。
  String _visibleStatusText(
    AppLocalizations l10n,
    _PreviewStage stage,
    LiveDisplaySettings d,
  ) {
    if (!d.showCountdown) {
      return d.showStageText ? _stageWord(l10n, stage) : '';
    }
    switch (stage) {
      case _PreviewStage.beforeClass:
        // 原生课前格式化使用固定的 60s smart 阈值。
        return _islandUntilClassStart(
          l10n,
          d,
          _beforeWindow.start.difference(DateTime.now()),
          60,
        );
      case _PreviewStage.duringClass:
        // 原生 remainingText 在课中固定为“上课中”，但该值只进入 hintInfo /
        // 非提升路径；摘要态胶囊在课中走 criticalTimeText（见 _statusLine），
        // 这里仅为完整性保留同一回退语义。
        return l10n.liveIslandPreviewStageInClass;
      case _PreviewStage.beforeEnd:
        return _islandUntilClassEnd(
          l10n,
          d,
          _endWindow.end.difference(DateTime.now()),
          widget.endSecondsCountdownThresholdSeconds,
        );
    }
  }

  /// buildDuringClassProgress.criticalTimeText：裸倒计时（无前缀），使用
  /// 原生 formatCountdownDuration 的默认 60s smart 阈值。nearest 模式原生会
  /// 优先显示最近课间节点的剩余时间，但示例课只有一节、不存在课间节点
  /// （buildLiveProgressMilestones 对 sectionCount < 2 返回空），因此两种
  /// 课中时间模式在这里同为整节剩余。
  String _duringClassCriticalTime(LiveDisplaySettings d) {
    final remaining = _endWindow.end.difference(DateTime.now());
    return _formatIslandCountdown(remaining, d.countdownTextStyle, 60);
  }

}

/// 展开态预览卡片：模拟提升通知被展开后的真实排版。
///
/// 还原原生 `LiveUpdateService.buildNotification()` 的展开内容：
/// * 标题 = `notificationTitle`：课前 = `即将上课: <课程名>`，下课提醒 =
///   `下课提醒: <课程名>`，课中 = 课程名；非提升路径标题为空，这里只画提升态；
/// * 正文 = `promotedContentText` = `[visibleStatusText, timeRangeText,
///   visibleLocation, teacher]` 过滤空白后以 ` · ` 拼接；
/// * 详情行 = `promotedExpandedDetailText`，由 `expandedDetailFields`（未设置时
///   用原生默认顺序 `progress, status, time, location, teacher, shortName,
///   next, note`）逐字段拼行；空列表 = 全部隐藏。
///
/// 也就是说设置页里拖动排序 / 开关的正是这套详情行——摘要态胶囊看不到它们，
/// 只有展开后才可见，所以必须给一张展开态预览，否则用户改完设置屏幕上毫无反馈。
///
/// 平台限制：Android 16（SDK 36）在课中带进度条时使用系统进度展开样式
/// （`usesProgressExpandedStyle`），此时系统自己画展开界面，`expandedDetailText`
/// 不会生效；卡片顶部会按需展示这条说明。
class LiveIslandExpandedPreviewCard extends StatefulWidget {
  const LiveIslandExpandedPreviewCard({
    super.key,
    required this.display,
    required this.forDuringEnd,
    this.followBeforeClass = false,
    this.endSecondsCountdownThresholdSeconds = 60,
    this.promoteDuringClass = true,
  });

  final LiveDisplaySettings display;
  final bool forDuringEnd;
  final bool followBeforeClass;
  final int endSecondsCountdownThresholdSeconds;

  /// 课中「提升通知」开关（livePromoteDuringClass）。
  ///
  /// 课前/下课提醒原生恒定 shouldPromote=true，课中才看这个开关；关掉后课中
  /// 走非提升态 `expandedDetailText`，`stage` 与 `status` 两行又会出现。
  /// 因此预览必须带上它，否则关掉开关后预览又会失真。
  final bool promoteDuringClass;

  @override
  State<LiveIslandExpandedPreviewCard> createState() =>
      _LiveIslandExpandedPreviewCardState();
}

class _LiveIslandExpandedPreviewCardState
    extends State<LiveIslandExpandedPreviewCard> {
  late final DateTime _anchor = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  ({DateTime start, DateTime end}) get _beforeWindow {
    final start = _anchor.add(const Duration(minutes: 12, seconds: 37));
    return (start: start, end: start.add(const Duration(minutes: 45)));
  }

  ({DateTime start, DateTime end}) get _endWindow {
    final start = _anchor.subtract(const Duration(minutes: 41, seconds: 40));
    return (start: start, end: start.add(const Duration(minutes: 45)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final d = widget.display;
    final stages = widget.forDuringEnd
        ? const [_PreviewStage.duringClass, _PreviewStage.beforeEnd]
        : const [_PreviewStage.beforeClass];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.followBeforeClass)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.liveIslandPreviewFollowBadge,
                    style: HyperosTypography.listDetail(context),
                  ),
                ),
              ],
            ),
          ),
        for (var index = 0; index < stages.length; index++) ...[
          if (stages.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _stageWord(l10n, stages[index]),
                style: HyperosTypography.listDetail(context),
              ),
            ),
          _ExpandedNotificationCard(
            title: _title(l10n, stages[index]),
            summary: _summaryLine(l10n, stages[index], d),
            detailLines: _detailLines(l10n, stages[index], d),
            emptyHint: l10n.liveIslandExpandedPreviewEmptyHint,
            platformCaption: l10n.liveIslandExpandedPreviewCaption,
          ),
          if (index != stages.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  /// `notificationTitle` 用的课程名。
  ///
  /// 原生 title 由 `shortCourseName` 拼出，而 `shortCourseName` 只做「超过 8 字
  /// 截断 + `..`」，**不看 useShortNameInIsland**（简称只进岛内文本 / A 区
  /// islandName）。所以这里不能用 `_islandCourseName` 那套简称逻辑，否则开了
  /// 「简称」后预览标题会变成「高数」而真机仍是「高等数学」。
  /// 课程名超过 8 字时同样要截断，保持与原生逐字一致。
  String _titleCourseName(AppLocalizations l10n) {
    final course = l10n.liveIslandPreviewSampleCourse;
    return course.length > 8 ? '${course.substring(0, 8)}..' : course;
  }

  /// `notificationTitle`：课前/下课提醒带阶段前缀，课中只有课程名。
  String _title(
    AppLocalizations l10n,
    _PreviewStage stage,
  ) {
    final course = _titleCourseName(l10n);
    return switch (stage) {
      _PreviewStage.beforeClass =>
        l10n.liveIslandPreviewTitleBeforeClass(course),
      _PreviewStage.beforeEnd =>
        l10n.liveIslandPreviewTitleBeforeEnd(course),
      _PreviewStage.duringClass => course,
    };
  }

  /// `promotedContentText`：课中带进度块时 = 倒计时 · 地点，其余 =
  /// `visibleStatusText · timeRangeText · 地点 · 教师`，逐项过滤空白。
  String _summaryLine(
    AppLocalizations l10n,
    _PreviewStage stage,
    LiveDisplaySettings d,
  ) {
    // 原生 promotedContentText：
    // * (课中 || 临近下课) && classProgress != null → compactDisplayText · 地点；
    // * 其余 → visibleStatusText · timeRangeText · 地点 · 教师。
    // 课中带进度块时正文只留倒计时与地点；示例课的字面值相同。
    final hasProgressBlock =
        stage == _PreviewStage.duringClass && d.showCountdown;
    final parts = hasProgressBlock
        ? <String>[
            _formatIslandCountdown(
              _endWindow.end.difference(DateTime.now()),
              d.countdownTextStyle,
              60,
            ),
            if (d.showLocation) l10n.liveIslandPreviewSampleLocation,
          ]
        : <String>[
            _expandedStatusText(l10n, stage, d),
            _timeRangeText(),
            if (d.showLocation) l10n.liveIslandPreviewSampleLocation,
            l10n.liveIslandPreviewSampleTeacher,
          ];
    return parts.where((part) => part.isNotEmpty).join(' · ');
  }

  /// 课中且显示倒计时 = 裸倒计时；其余 = `visibleStatusText`。
  String _expandedStatusText(
    AppLocalizations l10n,
    _PreviewStage stage,
    LiveDisplaySettings d,
  ) {
    if (!d.showCountdown) {
      return d.showStageText ? _stageWord(l10n, stage) : '';
    }
    switch (stage) {
      case _PreviewStage.beforeClass:
        return _islandUntilClassStart(
          l10n,
          d,
          _beforeWindow.start.difference(DateTime.now()),
          60,
        );
      case _PreviewStage.duringClass:
        return _formatIslandCountdown(
          _endWindow.end.difference(DateTime.now()),
          d.countdownTextStyle,
          60,
        );
      case _PreviewStage.beforeEnd:
        return _islandUntilClassEnd(
          l10n,
          d,
          _endWindow.end.difference(DateTime.now()),
          widget.endSecondsCountdownThresholdSeconds,
        );
    }
  }

  /// 原生 `timeRangeText`：`"$startTimeText - $endTimeText"`。示例课统一
  /// 08:00-08:45，三个阶段的展开卡片都用同一个时间串。
  String _timeRangeText() => '08:00 - 08:45';

  /// 原生 `shouldPromote`：课前与下课提醒恒定提升，课中看「提升通知」开关。
  bool _isPromoted(_PreviewStage stage) =>
      stage == _PreviewStage.duringClass ? widget.promoteDuringClass : true;

  /// 展开详情行：与原生 `expandedDetailLineList` 同一份字段语义。
  ///
  /// 展示顺序 = 用户配置顺序（未配置 → 原生默认顺序）；每条字段都有格式化
  /// 前缀（`简称: `、`状态: ` 等），值空缺时跳过——这与原生一致。
  ///
  /// **提升态（超级岛展开）会吞掉 `stage` / `status` 两行**：
  /// * `promotedExpandedDetailText` 给 stage 传的是 `null`，所以阶段行不出——
  ///   阶段信息由标题「即将上课: <课程名>」承载；
  /// * `detailStatusText` 带 `&& !shouldPromote`，提升时恒为 null，所以状态行
  ///   不出——状态信息由正文 `promotedContentText` 首项承载。
  /// 两者都只在非提升态（关闭「提升通知」的课中状态栏通知展开）才显示，
  /// 预览同样按提升与否决定，不再为了「让开关可见」而画实际不存在的行。
  List<String> _detailLines(
    AppLocalizations l10n,
    _PreviewStage stage,
    LiveDisplaySettings d,
  ) {
    final order = d.expandedDetailFields ??
        const [
          LiveExpandedDetailField.progress,
          LiveExpandedDetailField.status,
          LiveExpandedDetailField.time,
          LiveExpandedDetailField.location,
          LiveExpandedDetailField.teacher,
          LiveExpandedDetailField.shortName,
          LiveExpandedDetailField.nextCourse,
          LiveExpandedDetailField.note,
        ];
    final promoted = _isPromoted(stage);
    final lines = <String>[];
    for (final field in order) {
      switch (field) {
        case LiveExpandedDetailField.stage:
          // 阶段行：原生取 stageTitle（无 detail_status 前缀），提升路径传
          // null 因而跳过。
          if (!promoted) {
            lines.add(_stageWord(l10n, stage));
          }
        case LiveExpandedDetailField.shortName:
          lines.add(l10n.liveExpandedDetailLineShortName(
            l10n.liveIslandPreviewSampleCourseShort,
          ));
        case LiveExpandedDetailField.progress:
          // 原生 showProgressBlock = (课中 || 临近下课) && classProgress != null
          // && showCountdown；beforeEnd 阶段 classProgress == null，因此只有
          // 课中且显示倒计时时才出进度行。
          if (stage == _PreviewStage.duringClass && d.showCountdown) {
            lines.add(l10n.liveExpandedDetailLineProgressNext(
              l10n.liveIslandPreviewStageBeforeEnd,
            ));
            lines.add(l10n.liveExpandedDetailLineProgressFinal(
              _formatIslandCountdown(
                _endWindow.end.difference(DateTime.now()),
                d.countdownTextStyle,
                60,
              ),
            ));
          }
        case LiveExpandedDetailField.status:
          // 原生 detailStatusText = visibleStatusText.isNotBlank() &&
          // !shouldPromote，且课中带进度块时为 null（状态已在正文/进度行体现）。
          final hasProgressBlock =
              stage == _PreviewStage.duringClass && d.showCountdown;
          if (!promoted && !hasProgressBlock) {
            final status = _expandedStatusText(l10n, stage, d);
            if (status.isNotEmpty) {
              lines.add(l10n.liveExpandedDetailLineStatus(status));
            }
          }
        case LiveExpandedDetailField.time:
          lines.add(l10n.liveExpandedDetailLineTime(_timeRangeText()));
        case LiveExpandedDetailField.location:
          // 展开态的 location 字段独立于折叠态「显示地点」开关：原生
          // expandedDetailLineList 只判断 `location.isNotBlank()`，不看
          // showLocationInIsland（设计文档 §10.3）。此处不能再套 showLocation，
          // 否则折叠态关掉地点时预览会少一行、实际展开却照旧显示。
          lines.add(l10n.liveExpandedDetailLineLocation(
            l10n.liveIslandPreviewSampleLocation,
          ));
        case LiveExpandedDetailField.teacher:
          lines.add(l10n.liveExpandedDetailLineTeacher(
            l10n.liveIslandPreviewSampleTeacher,
          ));
        case LiveExpandedDetailField.nextCourse:
          lines.add(l10n.liveExpandedDetailLineNext(
            l10n.liveIslandPreviewSampleNextClass,
          ));
        case LiveExpandedDetailField.note:
          lines.add(l10n.liveExpandedDetailLineNote(
            l10n.liveIslandPreviewSampleNote,
          ));
      }
    }
    return lines;
  }
}

/// 提升通知展开后的卡片观感：圆角深色卡片 + 标题 + 正文 + 分隔线 + 详情行。
class _ExpandedNotificationCard extends StatelessWidget {
  const _ExpandedNotificationCard({
    required this.title,
    required this.summary,
    required this.detailLines,
    required this.emptyHint,
    required this.platformCaption,
  });

  final String title;
  final String summary;
  final List<String> detailLines;
  final String emptyHint;
  final String platformCaption;

  static const _cardColor = Color(0xFF101114);
  static const _detailColor = Color(0xFFB9BDC4);
  static const _captionColor = Color(0xFF8A8F98);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _detailColor,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          if (detailLines.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              emptyHint,
              style: const TextStyle(
                color: _captionColor,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 10),
            for (final line in detailLines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _detailColor,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            platformCaption,
            style: const TextStyle(
              color: _captionColor,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Mock widgets（HyperOS 超级岛观感，深色、与主题无关） --------------------

/// 摘要态胶囊（单行）：中间摄像头，左侧只有小图标位，右侧是整条
/// islandCriticalText（课程名 + 地点 + 状态）。
class _IslandCapsule extends StatelessWidget {
  const _IslandCapsule({required this.iconSlot, required this.criticalText});

  /// 摄像头左侧的图标位（通知 smallIcon）。非小米机型且未开自定义标签时为空。
  final Widget iconSlot;

  /// 摄像头右侧的文本（islandCriticalText）。
  final String criticalText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _LiveIslandPreviewCardState._pillColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 4, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: iconSlot,
              ),
            ),
          ),
          const _CameraHole(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 13, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: criticalText.isEmpty
                    ? const SizedBox.shrink()
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          criticalText,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 居中前置摄像头开孔。
class _CameraHole extends StatelessWidget {
  const _CameraHole();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 27,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF08090B),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Center(
        child: Container(
          width: 11,
          height: 11,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF191B20),
          ),
        ),
      ),
    );
  }
}

/// 原生 `computeRemainingText` + 前缀拼接：距上课 / 距下课。
String _islandUntilClassStart(
  AppLocalizations l10n,
  LiveDisplaySettings d,
  Duration remaining,
  int thresholdSeconds,
) {
  final text =
      _formatIslandCountdown(remaining, d.countdownTextStyle, thresholdSeconds);
  return d.hidePrefixText ? text : l10n.liveIslandPreviewUntilClassStart(text);
}

String _islandUntilClassEnd(
  AppLocalizations l10n,
  LiveDisplaySettings d,
  Duration remaining,
  int thresholdSeconds,
) {
  final text =
      _formatIslandCountdown(remaining, d.countdownTextStyle, thresholdSeconds);
  return d.hidePrefixText ? text : l10n.liveIslandPreviewUntilClassEnd(text);
}

// --- Countdown formatter (port of CountdownFormat.kt) -------------------

String _formatIslandCountdown(
  Duration duration,
  LiveCountdownTextStyle style,
  int thresholdSeconds,
) {
  final millis = duration.inMilliseconds;
  final totalSeconds = millis <= 0 ? 0 : millis ~/ 1000;
  switch (style) {
    case LiveCountdownTextStyle.smartMinS:
      return _islandCountdownSmart(totalSeconds, thresholdSeconds, 'min', 's');
    case LiveCountdownTextStyle.minuteSecondCn:
      return _islandCountdownMinuteSecond(totalSeconds, '分钟', '秒');
    case LiveCountdownTextStyle.minuteSecondColon:
      final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
      final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    case LiveCountdownTextStyle.minuteSecondMinS:
      return _islandCountdownMinuteSecond(totalSeconds, 'min', 's');
    case LiveCountdownTextStyle.minuteSecondMinSlashS:
      return _islandCountdownMinuteSecond(totalSeconds, 'min/', 's');
    case LiveCountdownTextStyle.minuteOnlyCn:
      return '${_islandCountdownMinutesFloor(totalSeconds)}分钟';
    case LiveCountdownTextStyle.minuteOnlyMin:
      return '${_islandCountdownMinutesFloor(totalSeconds)}min';
    case LiveCountdownTextStyle.minuteOnlySlash:
      return '${_islandCountdownMinutesFloor(totalSeconds)}/min';
    case LiveCountdownTextStyle.secondOnlyCn:
      return '$totalSeconds秒';
    case LiveCountdownTextStyle.secondOnlyShort:
      // 相邻字面量拼接：'59s'，避免 's' 并入标识符触发插值花括号 lint。
      return '$totalSeconds' 's';
    case LiveCountdownTextStyle.secondOnlySlash:
      return '$totalSeconds/s';
    case LiveCountdownTextStyle.smart:
      return _islandCountdownSmart(totalSeconds, thresholdSeconds, '分钟', '秒');
  }
}

String _islandCountdownSmart(
  int totalSeconds,
  int thresholdSeconds,
  String minuteSuffix,
  String secondSuffix,
) {
  if (totalSeconds <= thresholdSeconds) {
    return '$totalSeconds$secondSuffix';
  }
  if (totalSeconds > 120) {
    return '${(totalSeconds ~/ 60).clamp(1, 1 << 30)}$minuteSuffix';
  }
  if (totalSeconds > 60) {
    return '${((totalSeconds + 59) ~/ 60).clamp(1, 1 << 30)}$minuteSuffix';
  }
  return '$totalSeconds$secondSuffix';
}

String _islandCountdownMinuteSecond(
  int totalSeconds,
  String minuteSuffix,
  String secondSuffix,
) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes > 0 && seconds > 0) {
    return '$minutes$minuteSuffix$seconds$secondSuffix';
  }
  if (minutes > 0) {
    // Kotlin 对 min/ 变体去掉尾部斜杠。
    final trimmed = minuteSuffix.endsWith('/')
        ? minuteSuffix.substring(0, minuteSuffix.length - 1)
        : minuteSuffix;
    return '$minutes$trimmed';
  }
  return '$seconds$secondSuffix';
}

int _islandCountdownMinutesFloor(int totalSeconds) =>
    (totalSeconds ~/ 60).clamp(1, 1 << 30);
