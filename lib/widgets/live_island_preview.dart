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
/// 机型能力决定。展开态不在此预览范围内。
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

  /// 对应原生 ic_upcoming / ic_course / ic_countdown 三枚白色矢量图标的
  /// 最接近的 Material 字形。
  IconData _stageSmallIconData(_PreviewStage stage) => switch (stage) {
        _PreviewStage.beforeClass => Icons.access_time,
        _PreviewStage.duringClass => Icons.import_contacts,
        _PreviewStage.beforeEnd => Icons.check_circle_outline,
      };

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
        return _untilStart(
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
        return _untilEnd(
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
    return _formatDuration(remaining, d.countdownTextStyle, 60);
  }

  String _untilStart(
    AppLocalizations l10n,
    LiveDisplaySettings d,
    Duration remaining,
    int thresholdSeconds,
  ) {
    final text =
        _formatDuration(remaining, d.countdownTextStyle, thresholdSeconds);
    return d.hidePrefixText
        ? text
        : l10n.liveIslandPreviewUntilClassStart(text);
  }

  String _untilEnd(
    AppLocalizations l10n,
    LiveDisplaySettings d,
    Duration remaining,
    int thresholdSeconds,
  ) {
    final text =
        _formatDuration(remaining, d.countdownTextStyle, thresholdSeconds);
    return d.hidePrefixText ? text : l10n.liveIslandPreviewUntilClassEnd(text);
  }

  // --- Countdown formatter (port of CountdownFormat.kt) -------------------

  String _formatDuration(
    Duration duration,
    LiveCountdownTextStyle style,
    int thresholdSeconds,
  ) {
    final millis = duration.inMilliseconds;
    final totalSeconds = millis <= 0 ? 0 : millis ~/ 1000;
    switch (style) {
      case LiveCountdownTextStyle.smartMinS:
        return _smart(totalSeconds, thresholdSeconds, 'min', 's');
      case LiveCountdownTextStyle.minuteSecondCn:
        return _minuteSecond(totalSeconds, '分钟', '秒');
      case LiveCountdownTextStyle.minuteSecondColon:
        final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
        final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
        return '$minutes:$seconds';
      case LiveCountdownTextStyle.minuteSecondMinS:
        return _minuteSecond(totalSeconds, 'min', 's');
      case LiveCountdownTextStyle.minuteSecondMinSlashS:
        return _minuteSecond(totalSeconds, 'min/', 's');
      case LiveCountdownTextStyle.minuteOnlyCn:
        return '${_minutesFloor(totalSeconds)}分钟';
      case LiveCountdownTextStyle.minuteOnlyMin:
        return '${_minutesFloor(totalSeconds)}min';
      case LiveCountdownTextStyle.minuteOnlySlash:
        return '${_minutesFloor(totalSeconds)}/min';
      case LiveCountdownTextStyle.secondOnlyCn:
        return '$totalSeconds秒';
      case LiveCountdownTextStyle.secondOnlyShort:
        // 相邻字面量拼接：'59s'，避免 's' 并入标识符触发插值花括号 lint。
        return '$totalSeconds' 's';
      case LiveCountdownTextStyle.secondOnlySlash:
        return '$totalSeconds/s';
      case LiveCountdownTextStyle.smart:
        return _smart(totalSeconds, thresholdSeconds, '分钟', '秒');
    }
  }

  String _smart(
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

  String _minuteSecond(int totalSeconds, String minuteSuffix, String secondSuffix) {
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

  int _minutesFloor(int totalSeconds) => (totalSeconds ~/ 60).clamp(1, 1 << 30);
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
