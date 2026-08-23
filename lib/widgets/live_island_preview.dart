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
/// 还原真实摘要态胶囊的左右分区：中间是摄像头开孔，左侧是实际会显示的
/// 小图标位 + 文本块（imageTextInfoLeft），右侧是实际的提示位
/// （hintInfo，即状态文字）。展开态不在此预览范围内。
///
/// 与原生 `MainActivity.kt` 的对应关系：
///
/// * 左侧文本块 = buildIslandSummary() A区：恒为倒计时风格，不受
///   showCountdown / showStageText 控制，且始终带“距上课 / 距下课”前缀。
/// * 左侧图标位 = 通知 smallIcon：默认为应用图标；仅小米设备允许开启
///   自定义标签（enableMiuiIslandLabelImage），开启后按原生
///   buildIslandLabelBitmap() 的规则绘制（图标/自定义 Logo + 标签文字，
///   颜色、字号、字重、圆角均跟随设置）。
/// * 右侧提示位 = hintInfo.title = visibleStatusText：受 showCountdown →
///   showStageText 控制，课中固定为“上课中”。
/// * 课中环形进度包住左侧图标；课间节点进度条与原生摘要态一致，
///   显示在胶囊下方。
class LiveIslandPreviewCard extends StatefulWidget {
  const LiveIslandPreviewCard({
    super.key,
    required this.display,
    this.followBeforeClass = false,
    this.endSecondsCountdownThresholdSeconds = 60,
  });

  final LiveDisplaySettings display;

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
  static const _progressGreen = Color(0xFF4CAF50);
  static const _defaultLabelColor = Color(0xFFFFFFFF);

  late final DateTime _anchor = DateTime.now();
  Timer? _ticker;
  int _stageIndex = 0;
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

  ({DateTime start, DateTime end}) get _duringWindow {
    final start = _anchor.subtract(const Duration(minutes: 27, seconds: 14));
    return (start: start, end: start.add(const Duration(minutes: 45)));
  }

  ({DateTime start, DateTime end}) get _endWindow {
    final start = _anchor.subtract(const Duration(minutes: 41, seconds: 40));
    return (start: start, end: start.add(const Duration(minutes: 45)));
  }

  /// Milestone break at 70% of the demo lesson (stands in for course breaks).
  static const _duringTotal = Duration(minutes: 45);
  Duration get _duringMilestoneOffset => _duringTotal * 0.7;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final d = widget.display;
    const stages = _PreviewStage.values;
    final selectedStage = stages[_stageIndex];

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
        HyperosSegmentedControl(
          tabs: [
            l10n.liveIslandPreviewStageBeforeClass,
            l10n.liveIslandPreviewStageInClass,
            l10n.liveIslandPreviewStageBeforeEnd,
          ],
          selectedIndex: _stageIndex,
          onChanged: (index) => setState(() => _stageIndex = index),
        ),
        const SizedBox(height: 14),
        _IslandCapsule(
          iconSlot: _buildIconSlot(l10n, selectedStage, d),
          title: _islandName(l10n, d),
          content: _islandContent(l10n, selectedStage, d),
          statusLine: _statusLine(l10n, selectedStage, d),
        ),
        if (selectedStage == _PreviewStage.duringClass) ...[
          const SizedBox(height: 8),
          _MilestoneBar(
            percent: _progressFraction(selectedStage),
            milestoneFraction: 0.7,
            leading: _nextMilestoneText(l10n, d) ?? '',
            trailing: _finalDismissText(l10n, d),
          ),
        ],
      ],
    );
  }

  // --- Left icon slot (notification small-icon position) ------------------

  Widget _buildIconSlot(
    AppLocalizations l10n,
    _PreviewStage stage,
    LiveDisplaySettings d,
  ) {
    final icon = _buildSmallIcon(l10n, d);
    if (stage != _PreviewStage.duringClass) {
      return icon;
    }
    // 原生把 progressInfo 放进 imageTextInfoLeft：环包住小图标。
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _RingPainter(progress: _progressFraction(stage))),
          Center(child: icon),
        ],
      ),
    );
  }

  Widget _buildSmallIcon(AppLocalizations l10n, LiveDisplaySettings d) {
    final labelEnabled = _isXiaomiFamily && d.enableMiuiIslandLabelImage;
    if (!labelEnabled) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(
          BundledAssets.launcherIcon,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
        ),
      );
    }
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
    final label = Flexible(
      child: FittedBox(
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
        label,
      ],
    );
  }

  Widget _appIconImage(double size) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset(
          BundledAssets.launcherIcon,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );

  // --- Text composition (ports of MainActivity.kt rules) ------------------

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

  /// hintInfo.title = visibleStatusText：受 showCountdown → showStageText 控制。
  String _statusLine(
    AppLocalizations l10n,
    _PreviewStage stage,
    LiveDisplaySettings d,
  ) {
    if (!d.showCountdown) {
      return d.showStageText ? _stageWord(l10n, stage) : '';
    }
    return _countdownStatus(l10n, stage, d);
  }

  /// computeRemainingText：前缀受 hidePrefixText 影响；课中固定“上课中”。
  String _countdownStatus(
    AppLocalizations l10n,
    _PreviewStage stage,
    LiveDisplaySettings d,
  ) {
    final now = DateTime.now();
    switch (stage) {
      case _PreviewStage.beforeClass:
        // 原生课前格式化使用固定的 60s smart 阈值。
        return _untilStart(l10n, d, _beforeWindow.start.difference(now), 60);
      case _PreviewStage.duringClass:
        return l10n.liveIslandPreviewStageInClass;
      case _PreviewStage.beforeEnd:
        return _untilEnd(
          l10n,
          d,
          _endWindow.end.difference(now),
          widget.endSecondsCountdownThresholdSeconds,
        );
    }
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

  /// buildIslandSummary islandContentText（A区 content）：无视 showCountdown /
  /// showStageText / hidePrefixText（原生如此），倒计时恒用默认 60s 阈值。
  String _islandContent(
    AppLocalizations l10n,
    _PreviewStage stage,
    LiveDisplaySettings d,
  ) {
    final now = DateTime.now();
    switch (stage) {
      case _PreviewStage.beforeClass:
        final remaining = _beforeWindow.start.difference(now);
        if (!remaining.isNegative) {
          return l10n.liveIslandPreviewUntilClassStart(
            _formatDuration(remaining, d.countdownTextStyle, 60),
          );
        }
        return l10n.liveIslandPreviewStageBeforeClass;
      case _PreviewStage.beforeEnd:
        final remaining = _endWindow.end.difference(now);
        if (!remaining.isNegative) {
          return l10n.liveIslandPreviewUntilClassEnd(
            _formatDuration(remaining, d.countdownTextStyle, 60),
          );
        }
        return l10n.liveIslandPreviewStageBeforeEnd;
      case _PreviewStage.duringClass:
        return _compactDisplayText(l10n, d) ??
            l10n.liveIslandPreviewStageInClass;
    }
  }

  String? _nextMilestoneText(AppLocalizations l10n, LiveDisplaySettings d) {
    final elapsed = DateTime.now().difference(_duringWindow.start);
    final remaining = _duringMilestoneOffset - elapsed;
    if (remaining.isNegative || remaining.inMilliseconds == 0) {
      return null;
    }
    return '${l10n.liveIslandPreviewMilestoneLabel} '
        '${_formatDuration(remaining, d.countdownTextStyle, 60)}';
  }

  String _finalDismissText(AppLocalizations l10n, LiveDisplaySettings d) {
    final remaining = _duringWindow.end.difference(DateTime.now());
    return l10n.liveIslandPreviewFinalDismiss(
      _formatDuration(remaining, d.countdownTextStyle, 60),
    );
  }

  /// compactDisplayText：nearest → 最近节点，total → 整节下课。
  String? _compactDisplayText(AppLocalizations l10n, LiveDisplaySettings d) {
    final finalText = _finalDismissText(l10n, d);
    if (d.duringClassTimeDisplayMode == LiveDuringClassTimeDisplayMode.total) {
      return finalText;
    }
    return _nextMilestoneText(l10n, d) ?? finalText;
  }

  double _progressFraction(_PreviewStage stage) {
    if (stage != _PreviewStage.duringClass) {
      return 0;
    }
    final window = _duringWindow;
    final total = window.end.difference(window.start);
    if (total.inMilliseconds <= 0) {
      return 0;
    }
    final elapsed = DateTime.now().difference(window.start);
    final fraction = elapsed.inMilliseconds / total.inMilliseconds;
    return fraction.clamp(0.0, 1.0);
  }

  /// A区 title：课程名（showCourseName / useShortName + 原生 5 字截断）。
  String _islandName(AppLocalizations l10n, LiveDisplaySettings d) {
    if (!d.showCourseName) {
      return '';
    }
    final name = d.useShortName
        ? l10n.liveIslandPreviewSampleCourseShort
        : l10n.liveIslandPreviewSampleCourse;
    return name.length > 5 ? name.substring(0, 5) : name;
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

/// 摘要态胶囊：中间摄像头，左侧图标+文本块，右侧提示文字。
class _IslandCapsule extends StatelessWidget {
  const _IslandCapsule({
    required this.iconSlot,
    required this.title,
    required this.content,
    required this.statusLine,
  });

  final Widget iconSlot;
  final String title;
  final String content;
  final String statusLine;

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
              child: Row(
                children: [
                  iconSlot,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _CameraHole(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 13, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: statusLine.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        statusLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
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

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 2;
    const strokeWidth = 2.5;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white.withValues(alpha: 0.2),
    );
    if (progress <= 0) {
      return;
    }
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.1415926535897932 / 2,
      3.1415926535897932 * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = _LiveIslandPreviewCardState._progressGreen,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MilestoneBar extends StatelessWidget {
  const _MilestoneBar({
    required this.percent,
    required this.milestoneFraction,
    required this.leading,
    required this.trailing,
  });

  final double percent;
  final double milestoneFraction;
  final String leading;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 8,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Container(
                    width: (width * percent).clamp(0.0, width),
                    decoration: BoxDecoration(
                      color: _LiveIslandPreviewCardState._progressGreen,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Positioned(
                    left: (width * milestoneFraction).clamp(0.0, width - 8),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _LiveIslandPreviewCardState._pillColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                leading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trailing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
