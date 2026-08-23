import 'dart:async';

import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/timetable_settings.dart';
import '../ui/hyperos/hyperos.dart';

/// Real-time super-island preview for the live reminder display settings.
///
/// The mock mirrors the native text composition in
/// \`android/app/src/main/kotlin/com/mutx163/qingyu/MainActivity.kt\`
/// bug-for-bug so every toggle on the settings page has a visible effect:
///
/// * 摘要态胶囊 = buildIslandSummary() A区（imageTextInfoLeft）：恒为倒计时
///   风格，不受 showCountdown / showStageText 控制，且始终带
///   “距上课 / 距下课”前缀 —— 与原生行为一致。
/// * 课中环形进度 + 课间节点条 = DuringClassProgress。
/// * 展开态卡片 = promotedContentText：受 showCountdown / showStageText /
///   hidePrefixText 控制。
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

  /// Native endSecondsCountdownThreshold; only the before-end status-line
  /// countdown formatting uses it (computeRemainingText parity).
  final int endSecondsCountdownThresholdSeconds;

  @override
  State<LiveIslandPreviewCard> createState() => _LiveIslandPreviewCardState();
}

enum _PreviewStage { beforeClass, duringClass, beforeEnd }

class _LiveIslandPreviewCardState extends State<LiveIslandPreviewCard> {
  static const _islandBg = Color(0xFF0A0A0C);
  static const _cardBg = Color(0xFF14161B);
  static const _avatarBg = Color(0xFF26282E);
  static const _progressGreen = Color(0xFF4CAF50);

  late final DateTime _anchor = DateTime.now();
  Timer? _ticker;
  int _stageIndex = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
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
        const SizedBox(height: 12),
        Text(
          l10n.liveIslandPreviewSummaryLabel,
          style: HyperosTypography.listDetail(context),
        ),
        const SizedBox(height: 6),
        _SummaryPill(
          stage: selectedStage,
          progressPercent: _progressFraction(selectedStage),
          title: _islandName(l10n, d),
          content: _islandContent(l10n, selectedStage, d),
        ),
        if (selectedStage == _PreviewStage.duringClass) ...[
          const SizedBox(height: 8),
          _MilestoneBar(
            percent: _progressFraction(_PreviewStage.duringClass),
            milestoneFraction: 0.7,
            leading: _nextMilestoneText(l10n, d) ?? '',
            trailing: _finalDismissText(l10n, d),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          l10n.liveIslandPreviewExpandedLabel,
          style: HyperosTypography.listDetail(context),
        ),
        const SizedBox(height: 6),
        _ExpandedCard(
          iconStage: selectedStage,
          title: _expandedTitle(l10n, selectedStage, d),
          body: _promotedContentText(l10n, selectedStage, d),
        ),
      ],
    );
  }

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

  /// visibleStatusText: gated by showCountdown → showStageText.
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

  /// computeRemainingText: prefix honours hidePrefixText; the during-class
  /// branch is fixed to the "in class" word.
  String _countdownStatus(
    AppLocalizations l10n,
    _PreviewStage stage,
    LiveDisplaySettings d,
  ) {
    final now = DateTime.now();
    switch (stage) {
      case _PreviewStage.beforeClass:
        // Native before-class formatting uses a fixed 60s smart threshold.
        return _untilStart(
          l10n,
          d,
          _beforeWindow.start.difference(now),
          60,
        );
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
    final text = _formatDuration(remaining, d.countdownTextStyle, thresholdSeconds);
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
    final text = _formatDuration(remaining, d.countdownTextStyle, thresholdSeconds);
    return d.hidePrefixText ? text : l10n.liveIslandPreviewUntilClassEnd(text);
  }

  /// buildIslandSummary islandContentText: ignores showCountdown /
  /// showStageText / hidePrefixText entirely (native parity), and its
  /// countdown always uses the default 60s smart threshold.
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

  /// compactDisplayText: nearest → next milestone, total → final dismiss.
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

  /// promotedContentText / baseInfo.content of the expanded card.
  String _promotedContentText(
    AppLocalizations l10n,
    _PreviewStage stage,
    LiveDisplaySettings d,
  ) {
    // classProgress is only built during the during-class stage natively,
    // so the progress branch never applies to beforeEnd.
    final hasProgress =
        stage == _PreviewStage.duringClass && d.showCountdown;
    final parts = <String>[
      if (hasProgress)
        _compactDisplayText(l10n, d) ?? ''
      else
        _statusLine(l10n, stage, d),
      if (d.showLocation) l10n.liveIslandPreviewSampleLocation,
    ].where((part) => part.trim().isNotEmpty).toList();
    // baseInfo.content falls back to the hint text when blank; the closest
    // stable analogue here is the stage word itself.
    if (parts.isEmpty) {
      parts.add(_stageWord(l10n, stage));
    }
    return parts.join(' · ');
  }

  /// Pill A区 title: course name honouring showCourseName/useShortName with
  /// the native 5-char truncation (islandCourseName).
  String _islandName(AppLocalizations l10n, LiveDisplaySettings d) {
    if (!d.showCourseName) {
      return '';
    }
    final name = d.useShortName
        ? l10n.liveIslandPreviewSampleCourseShort
        : l10n.liveIslandPreviewSampleCourse;
    return name.length > 5 ? name.substring(0, 5) : name;
  }

  /// Expanded-card header title (title in buildNotification): uses the
  /// short-name rule with 8-char truncation.
  String _expandedTitle(
    AppLocalizations l10n,
    _PreviewStage stage,
    LiveDisplaySettings d,
  ) {
    final nameToUse = d.useShortName
        ? l10n.liveIslandPreviewSampleCourseShort
        : l10n.liveIslandPreviewSampleCourse;
    final shortCourseName =
        nameToUse.length > 8 ? '${nameToUse.substring(0, 8)}..' : nameToUse;
    switch (stage) {
      case _PreviewStage.beforeClass:
      case _PreviewStage.beforeEnd:
        return '${_stageWord(l10n, stage)}: $shortCourseName';
      case _PreviewStage.duringClass:
        return shortCourseName;
    }
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
        // Adjacent-literal concat: '59s' without triggering
        // unnecessary_brace_in_string_interps ('s' would extend the ident).
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
      // Kotlin trims the trailing slash for the min/ variant.
      final trimmed = minuteSuffix.endsWith('/')
          ? minuteSuffix.substring(0, minuteSuffix.length - 1)
          : minuteSuffix;
      return '$minutes$trimmed';
    }
    return '$seconds$secondSuffix';
  }

  int _minutesFloor(int totalSeconds) => (totalSeconds ~/ 60).clamp(1, 1 << 30);
}

// --- Mock widgets (HyperOS island look, theme-independent dark style) ------

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.stage,
    required this.progressPercent,
    required this.title,
    required this.content,
  });

  final _PreviewStage stage;
  final double progressPercent;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: _LiveIslandPreviewCardState._islandBg,
        borderRadius: BorderRadius.circular(29),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
      child: Row(
        children: [
          _StageAvatar(stage: stage, progressPercent: progressPercent),
          const SizedBox(width: 10),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageAvatar extends StatelessWidget {
  const _StageAvatar({required this.stage, required this.progressPercent});

  final _PreviewStage stage;
  final double progressPercent;

  @override
  Widget build(BuildContext context) {
    const avatarSize = 46.0;
    final showRing = stage == _PreviewStage.duringClass;
    final icon = switch (stage) {
      _PreviewStage.beforeClass => Icons.notifications_active_outlined,
      _PreviewStage.duringClass => Icons.menu_book_outlined,
      _PreviewStage.beforeEnd => Icons.alarm_outlined,
    };
    return SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showRing)
            CustomPaint(painter: _RingPainter(progress: progressPercent))
          else
            DecoratedBox(
              decoration: BoxDecoration(
                color: _LiveIslandPreviewCardState._avatarBg,
                shape: BoxShape.circle,
              ),
            ),
          Center(
            child: Icon(
              icon,
              size: 20,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
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
    const strokeWidth = 3.0;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withValues(alpha: 0.2);
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawCircle(
      center,
      radius - strokeWidth,
      Paint()..color = _LiveIslandPreviewCardState._avatarBg,
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
                          color: _LiveIslandPreviewCardState._islandBg,
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

class _ExpandedCard extends StatelessWidget {
  const _ExpandedCard({
    required this.iconStage,
    required this.title,
    required this.body,
  });

  final _PreviewStage iconStage;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _LiveIslandPreviewCardState._cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _StageAvatar(stage: iconStage, progressPercent: 0),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 4),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
