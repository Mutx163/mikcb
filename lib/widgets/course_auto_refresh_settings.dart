import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/course_auto_refresh_controller.dart';
import '../domain/course_auto_refresh_decision.dart';
import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../screens/import/course_auto_refresh_runner.dart';
import '../services/course_auto_refresh_store.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';
import 'miuix_time_picker_sheet.dart';

/// 通用设置里的「课表自动更新」整块（开关 + 时机 + 间隔 + 定时 + 立即试一次）。
///
/// ## 为什么单独成一个文件，而不是写进 `screens/settings/settings_general.dart`
///
/// 设置域有一条行数棘轮（`lib/screens/settings/` 全目录合计只减不增），当前只剩
/// 个位数余量。整块约 200 行放进去必然顶爆，而「把行数搬进另一个也不会被扫的
/// 目录」不是解决办法——所以按 `wallpaper_blur_tile.dart` 的先例，把**控件本体**
/// 放进 `lib/widgets/`，宿主只加一行调用。`lib/widgets` 不受设置域棘轮约束。
///
/// ## provider 由宿主传入，本文件不读
///
/// 「立即试一次」要拿课表内容指纹，需要 `TimetableProvider`。但
/// `dependency_guards_test` 有一条「Provider 读取调用点只减不增」的棘轮，当前
/// 余量为 0 —— 本文件再 `context.read` 一次就会顶破。宿主
/// （`settings_general.dart`）本来就持有一份 provider，原样传进来即可。
///
/// ## 配置存在设备本地，不进 `TimetableSettings`
///
/// 理由写在 [CourseAutoRefreshStore] 的类注释里：运行台账（上次成功时间）必须
/// 设备本地，偏好与台账放同一处，避免「偏好跟着课表走、台账不跟」。
class CourseAutoRefreshSettingsSection extends StatefulWidget {
  const CourseAutoRefreshSettingsSection({
    super.key,
    required this.provider,
  });

  final TimetableProvider provider;

  @override
  State<CourseAutoRefreshSettingsSection> createState() =>
      _CourseAutoRefreshSettingsSectionState();
}

class _CourseAutoRefreshSettingsSectionState
    extends State<CourseAutoRefreshSettingsSection> {
  final CourseAutoRefreshStore _store = CourseAutoRefreshStore.instance;
  CourseAutoRefreshSchedule _draft = const CourseAutoRefreshSchedule();
  bool _loading = true;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _draft = _store.schedule;
    if (_store.isLoaded) {
      _loading = false;
    } else {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    await _store.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _draft = _store.schedule;
      _loading = false;
    });
  }

  /// 落盘失败时把草稿拉回存档里的真实值，避免界面停在「看着已保存、其实没存」。
  Future<void> _apply(CourseAutoRefreshSchedule next) async {
    setState(() => _draft = next);
    final ok = await _store.saveSchedule(next);
    if (!mounted) {
      return;
    }
    if (!ok) {
      setState(() => _draft = _store.schedule);
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        HyperosSectionLabel(text: l10n.courseAutoRefreshSectionTitle),
        HyperosListGroup(
          children: [
            HyperosSwitchTile(
              title: l10n.courseAutoRefreshTitle,
              subtitle: l10n.courseAutoRefreshSubtitle,
              value: _draft.enabled,
              onChanged: (value) {
                unawaited(_apply(_draft.copyWith(enabled: value)));
              },
            ),
            if (_draft.enabled) ...[
              HyperosSelectTile<CourseAutoRefreshMode>(
                label: l10n.courseAutoRefreshModeLabel,
                items: <String, CourseAutoRefreshMode>{
                  l10n.courseAutoRefreshModeEveryLaunch:
                      CourseAutoRefreshMode.everyLaunch,
                  l10n.courseAutoRefreshModeInterval:
                      CourseAutoRefreshMode.intervalHours,
                  l10n.courseAutoRefreshModeDaily:
                      CourseAutoRefreshMode.dailyAt,
                },
                value: _draft.mode,
                onChanged: (value) {
                  unawaited(_apply(_draft.copyWith(mode: value)));
                },
              ),
              if (_draft.mode == CourseAutoRefreshMode.intervalHours)
                HyperosSliderTile(
                  title: l10n.courseAutoRefreshIntervalTitle,
                  value: _draft.intervalHours.toDouble(),
                  min: kCourseAutoRefreshMinIntervalHours.toDouble(),
                  max: kCourseAutoRefreshMaxIntervalHours.toDouble(),
                  // 1..168 小时逐档可调；档数跟着上下限走，不写死。
                  divisions:
                      kCourseAutoRefreshMaxIntervalHours -
                      kCourseAutoRefreshMinIntervalHours,
                  valueLabel: '${_draft.intervalHours}h',
                  onChanged: (value) {
                    unawaited(
                      _apply(_draft.copyWith(intervalHours: value.round())),
                    );
                  },
                ),
              if (_draft.mode == CourseAutoRefreshMode.dailyAt)
                HyperosNavTile(
                  title: l10n.courseAutoRefreshDailyTimeTitle,
                  details: _formatMinuteOfDay(context, _draft.dailyMinuteOfDay),
                  onTap: () => unawaited(_pickDailyTime()),
                ),
              HyperosNavTile(
                title: l10n.courseAutoRefreshTryNowTitle,
                subtitle: l10n.courseAutoRefreshTryNowSubtitle,
                onTap: _running ? null : () => unawaited(_runNow()),
              ),
            ],
          ],
        ),
        HyperosSectionDescription(text: _summaryText(context, l10n)),
      ],
    );
  }

  Future<void> _pickDailyTime() async {
    final picked = await showMiuixTimePickerSheet(
      context,
      initialTime: TimeOfDay(
        hour: _draft.dailyMinuteOfDay ~/ 60,
        minute: _draft.dailyMinuteOfDay % 60,
      ),
      title: AppLocalizations.of(context)!.courseAutoRefreshDailyTimeTitle,
    );
    if (picked == null || !mounted) {
      return;
    }
    await _apply(
      _draft.copyWith(dailyMinuteOfDay: picked.hour * 60 + picked.minute),
    );
  }

  Future<void> _runNow() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _running = true);
    final outcome = await runCourseAutoRefreshNow(
      context,
      provider: widget.provider,
    );
    if (!mounted) {
      return;
    }
    setState(() => _running = false);
    // 「立即试一次」是用户当场的动作，四种结局都要给一句反馈：静默在这里
    // 会被读成「点了没反应」。
    final message = switch (outcome) {
      CourseAutoRefreshOutcome.updated => l10n.courseAutoRefreshUpdatedTip,
      CourseAutoRefreshOutcome.unchanged => l10n.importNoCourseChanges,
      CourseAutoRefreshOutcome.busy => l10n.courseAutoRefreshFailedTip,
      _ => l10n.courseAutoRefreshFailedTip,
    };
    showAppLightTip(
      context,
      message: message,
      kind: outcome == CourseAutoRefreshOutcome.updated
          ? AppToastKind.success
          : AppToastKind.warning,
    );
  }

  /// 「07:30」。
  ///
  /// 不走 `MaterialLocalizations`：那个依赖 context 的 locale，而这行要在
  /// 每次重建里稳定输出同一串字符，用本地化格式反而会因语言不同长短不一。
  String _formatMinuteOfDay(BuildContext context, int minuteOfDay) {
    final hour = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
    final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 底部那句灰字：上次成功 / 下次预计。
  ///
  /// 放在整宽段落（[HyperosSectionDescription]）而不是行控件的副标题里：两段
  /// 时间加起来的字数肯定超过单行口径（17 字），塞进副标题就是真的折两行。
  String _summaryText(BuildContext context, AppLocalizations l10n) {
    if (!_draft.enabled) {
      return l10n.courseAutoRefreshSubtitle;
    }
    final last = _store.lastSuccessAt;
    if (last == null) {
      return l10n.courseAutoRefreshSummaryNever;
    }
    final lastLine = l10n.courseAutoRefreshSummaryLast(_shortDateTime(last));
    final next = _store.nextRunAt(DateTime.now());
    if (next == null) {
      return lastLine;
    }
    return '$lastLine · ${l10n.courseAutoRefreshSummaryNext(_shortDateTime(next))}';
  }

  /// 「9-21 07:30」这类短格式：只给月日与时刻，不带年份与秒。
  ///
  /// 不引 `intl` 的 `DateFormat`：本仓已有 `intl` 依赖，但设置页其它行都不带
  /// 日期格式化，为一个短标签引它会多一条运行时本地化路径要维护。
  String _shortDateTime(DateTime value) {
    final month = value.month.toString().padLeft(1, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}
