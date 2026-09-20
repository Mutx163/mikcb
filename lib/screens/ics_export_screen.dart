import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/timetable_profile.dart';
import '../providers/timetable_provider.dart';
import '../services/calendar_sync_service.dart';
import '../services/ics_export_service.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';

/// 首次同步确认弹层的「已阅」记忆键：确认过一次后就一键直达，不再弹。
const String _calendarSyncNoticePrefsKey =
    'ics_calendar_sync_notice_acknowledged_v1';

/// Test seam for the "save to device folder" action: receives the generated
/// file name + bytes, returns the saved location (or null when the user
/// cancelled). The production implementation delegates to [FilePicker.saveFile].
typedef IcsSaveCallback =
    Future<String?> Function(String fileName, Uint8List bytes);

class IcsExportScreen extends StatefulWidget {
  const IcsExportScreen({
    super.key,
    this.exportService,
    this.shareCallback,
    this.saveCallback,
    this.calendarSyncService,
  });

  final IcsExportService? exportService;
  final Future<ShareResult> Function(ShareParams params)? shareCallback;
  final IcsSaveCallback? saveCallback;

  /// 测试注入口；null 时走真实平台通道（见 [CalendarSyncService]）。
  final CalendarSyncService? calendarSyncService;

  @override
  State<IcsExportScreen> createState() => _IcsExportScreenState();
}

/// 导出按钮弹出菜单的两个去向。
enum _IcsExportAction { share, save }

class _IcsExportScreenState extends State<IcsExportScreen> {
  late final IcsExportService _exportService;
  late final CalendarSyncService _calendarSyncService;
  final GlobalKey _exportButtonAnchorKey = GlobalKey();
  bool _initialized = false;
  bool _isExporting = false;
  bool _isSyncing = false;
  bool _isRemoving = false;
  String? _selectedProfileId;
  late DateTime _fromDate;
  late DateTime _toDate;
  Set<IcsExportEventKind> _eventKinds = Set<IcsExportEventKind>.of(
    IcsExportEventKind.all,
  );

  /// 导出/同步时是否排除落在节假日上的**课程**事件。
  ///
  /// 默认开启：ICS 文件导出与「同步到系统日历」两条路径都受它控制
  /// （2026-09-19 用户拍板：一个开关管所有日历输出；此前同步固定跳过、
  /// 开关只管文件，默认值也曾为关闭）。只影响课程，考试与自定义日程照常。
  bool _skipHolidayCourses = true;

  @override
  void initState() {
    super.initState();
    _exportService = widget.exportService ?? IcsExportService();
    _calendarSyncService = widget.calendarSyncService ?? CalendarSyncService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }

    final provider = context.read<TimetableProvider>();
    final profile = _profileForProvider(provider);
    _selectedProfileId = profile?.id;
    final range = _defaultRangeFor(profile);
    _fromDate = range.$1;
    _toDate = range.$2;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final profile = _profileForProvider(provider);

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.icsExportTitle),
      child: HyperosListView(
        children: [
          if (provider.profiles.isNotEmpty) ...[
            HyperosSectionLabel(text: l10n.icsExportProfileLabel),
            HyperosListGroup(
              children: [
                HyperosSelectTile<String>(
                  label: l10n.icsExportProfileLabel,
                  subtitle: l10n.icsExportProfileSelectTitle,
                  items: _profileItems(provider.profiles, l10n),
                  value: profile?.id,
                  onChanged: _handleProfileChanged,
                  useSheetForPopup: true,
                  sheetTitle: l10n.icsExportProfileLabel,
                ),
              ],
            ),
            const HyperosSectionGap(),
          ] else ...[
            HyperosSectionLabel(text: l10n.icsExportProfileLabel),
            HyperosControlCard(
              child: HyperosControlCardInset(
                child: Text(
                  l10n.icsExportNoProfiles,
                  style: HyperosTypography.listDetail(context),
                ),
              ),
            ),
            const HyperosSectionGap(),
          ],
          HyperosSectionLabel(text: l10n.icsExportDateRangeTitle),
          HyperosListGroup(
            children: [
              HyperosDateTile(
                label: l10n.icsExportStartDate,
                value: _fromDate,
                formatter: (date) => _formatDate(context, date),
                onChanged: _handleFromDateChanged,
                firstDate: DateTime(1970),
                lastDate: DateTime(2100),
              ),
              HyperosDateTile(
                label: l10n.icsExportEndDate,
                value: _toDate,
                formatter: (date) => _formatDate(context, date),
                onChanged: _handleToDateChanged,
                firstDate: DateTime(1970),
                lastDate: DateTime(2100),
              ),
            ],
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.icsExportTypesTitle),
          HyperosListGroup(
            children: [
              _buildEventTypeTile(
                kind: IcsExportEventKind.course,
                title: l10n.icsExportCourses,
              ),
              _buildEventTypeTile(
                kind: IcsExportEventKind.exam,
                title: l10n.icsExportExams,
              ),
              _buildEventTypeTile(
                kind: IcsExportEventKind.scheduleItem,
                title: l10n.icsExportSchedules,
              ),
              // 节假日过滤只对课程有意义：没勾课程时不展示，
              // 避免留一个改了不生效的开关。
              if (_eventKinds.contains(IcsExportEventKind.course))
                HyperosSwitchTile(
                  key: const Key('ics-export-skip-holiday-courses'),
                  title: l10n.icsExportSkipHolidayCourses,
                  subtitle: l10n.icsExportSkipHolidayCoursesSubtitle,
                  value: _skipHolidayCourses,
                  onChanged: (value) {
                    setState(() {
                      _skipHolidayCourses = value;
                    });
                  },
                ),
            ],
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            child: HyperosControlCardInset(
              child: _buildSummary(context, l10n, profile),
            ),
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            child: HyperosControlCardInset(
              child: Column(
                children: [
                  HyperosButton(
                    key: const Key('ics-export-sync-calendar'),
                    label: l10n.icsExportSyncCalendarButton,
                    loading: _isSyncing,
                    expand: true,
                    onPressed: _isSyncing ? null : _syncToSystemCalendar,
                  ),
                  const SizedBox(height: 8),
                  HyperosButton(
                    key: const Key('ics-export-remove-calendar'),
                    label: l10n.icsExportRemoveCalendarButton,
                    variant: HyperosButtonVariant.secondary,
                    loading: _isRemoving,
                    expand: true,
                    onPressed: _isRemoving ? null : _removeFromSystemCalendar,
                  ),
                ],
              ),
            ),
          ),
          const HyperosSectionGap(),
          HyperosControlCard(
            child: HyperosControlCardInset(
              child: KeyedSubtree(
                key: _exportButtonAnchorKey,
                child: HyperosButton(
                  key: const Key('ics-export-share'),
                  label: l10n.icsExportButton,
                  loading: _isExporting,
                  expand: true,
                  onPressed: _isExporting ? null : _export,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TimetableProfile? _profileForProvider(TimetableProvider provider) {
    for (final profile in provider.profiles) {
      if (profile.id == _selectedProfileId) {
        return profile;
      }
    }
    return provider.activeProfile ??
        (provider.profiles.isEmpty ? null : provider.profiles.first);
  }

  Map<String, String> _profileItems(
    List<TimetableProfile> profiles,
    AppLocalizations l10n,
  ) {
    final items = <String, String>{};
    final nameCounts = <String, int>{};
    for (final profile in profiles) {
      final baseName = profile.name.trim().isEmpty
          ? l10n.icsExportProfileLabel
          : profile.name.trim();
      final count = (nameCounts[baseName] ?? 0) + 1;
      nameCounts[baseName] = count;
      var label = count == 1 ? baseName : '$baseName ($count)';
      while (items.containsKey(label)) {
        label = '$baseName (${nameCounts[baseName]! + 1})';
        nameCounts[baseName] = nameCounts[baseName]! + 1;
      }
      items[label] = profile.id;
    }
    return items;
  }

  (DateTime, DateTime) _defaultRangeFor(TimetableProfile? profile) {
    final semesterStart = profile?.settings.semesterStartDate;
    if (semesterStart != null) {
      final from = _mondayOf(semesterStart);
      final weeks = profile!.settings.semesterWeekCount < 1
          ? 1
          : profile.settings.semesterWeekCount;
      return (from, from.add(Duration(days: weeks * 7 - 1)));
    }

    final from = _dateOnly(DateTime.now());
    return (from, from.add(const Duration(days: 30)));
  }

  Widget _buildEventTypeTile({
    required IcsExportEventKind kind,
    required String title,
  }) {
    return HyperosCheckboxTile(
      title: title,
      value: _eventKinds.contains(kind),
      onChanged: (selected) {
        setState(() {
          final next = Set<IcsExportEventKind>.of(_eventKinds);
          if (selected) {
            next.add(kind);
          } else {
            next.remove(kind);
          }
          _eventKinds = next;
        });
      },
    );
  }

  Widget _buildSummary(
    BuildContext context,
    AppLocalizations l10n,
    TimetableProfile? profile,
  ) {
    final selectedTypes = <String>[
      if (_eventKinds.contains(IcsExportEventKind.course))
        l10n.icsExportCourses,
      if (_eventKinds.contains(IcsExportEventKind.exam)) l10n.icsExportExams,
      if (_eventKinds.contains(IcsExportEventKind.scheduleItem))
        l10n.icsExportSchedules,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile?.name ?? l10n.icsExportNoProfiles,
          style: HyperosTypography.listTitle(context),
        ),
        const SizedBox(height: 8),
        Text(
          '${l10n.icsExportStartDate}: ${_formatDate(context, _fromDate)}',
          style: HyperosTypography.listDetail(context),
        ),
        Text(
          '${l10n.icsExportEndDate}: ${_formatDate(context, _toDate)}',
          style: HyperosTypography.listDetail(context),
        ),
        Text(
          '${l10n.icsExportTypesTitle}: ${selectedTypes.isEmpty ? '-' : selectedTypes.join(', ')}',
          style: HyperosTypography.listDetail(context),
        ),
        if (_skipHolidayCourses &&
            _eventKinds.contains(IcsExportEventKind.course))
          Text(
            l10n.icsExportSkipHolidayCoursesOn,
            style: HyperosTypography.listDetail(context),
          ),
        if (_eventKinds.contains(IcsExportEventKind.course) &&
            profile?.settings.semesterStartDate == null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.icsExportSemesterStartRequired,
            style: HyperosTypography.listDetail(
              context,
            ).copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  void _handleProfileChanged(String profileId) {
    final provider = context.read<TimetableProvider>();
    final profile = provider.profiles.firstWhere(
      (item) => item.id == profileId,
      orElse: () => provider.activeProfile!,
    );
    final range = _defaultRangeFor(profile);
    setState(() {
      _selectedProfileId = profile.id;
      _fromDate = range.$1;
      _toDate = range.$2;
    });
  }

  void _handleFromDateChanged(DateTime value) {
    final from = _dateOnly(value);
    setState(() {
      _fromDate = from;
      if (_toDate.isBefore(from)) {
        _toDate = from;
      }
    });
  }

  void _handleToDateChanged(DateTime value) {
    final to = _dateOnly(value);
    setState(() {
      _toDate = to.isBefore(_fromDate) ? _fromDate : to;
    });
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final profile = _profileForProvider(provider);

    if (profile == null) {
      showAppToast(
        context,
        message: l10n.icsExportNoProfiles,
        kind: AppToastKind.error,
      );
      return;
    }
    if (_eventKinds.isEmpty) {
      showAppToast(
        context,
        message: l10n.icsExportNoSelection,
        kind: AppToastKind.warning,
      );
      return;
    }
    if (_eventKinds.contains(IcsExportEventKind.course) &&
        profile.settings.semesterStartDate == null) {
      showAppToast(
        context,
        message: l10n.icsExportSemesterStartRequired,
        kind: AppToastKind.error,
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final result = _exportService.build(
        profile: profile,
        fromDate: _fromDate,
        toDate: _toDate,
        eventKinds: _eventKinds,
        // 只在用户勾选且本次导出含课程时生效；判定与首页同源（同一
        // HolidayResolver + 同一份假期数据 + 同一个「假期标记」开关）。
        //
        // ⚠️ **不消费** holidayOverrideEnabled：那是「诊断 → 实时」里的
        // **测试开关**，文案自述「开启后模拟假期状态，用于测试提醒和小组件
        // 是否正确隐藏课程」。而 HolidayResolver 在它开启时的语义是「除调休
        // 上班日外**每一天**都是假期」——一旦被导出继承，用户在测试后忘了关，
        // 导出的日历会**一节课都不剩**，而摘要仍只说「已跳过节假日课程」，
        // 没有任何提示。日历导出是面向真实学期的用户产物，不该复现调试模拟：
        // 这里固定传 false，只保留用户真实的假期数据与标记开关。
        holidayFilter:
            _skipHolidayCourses &&
                _eventKinds.contains(IcsExportEventKind.course)
            ? IcsHolidayFilter(
                data: provider.holidayData,
                overrideEnabled: false,
                markingEnabled: provider.settings.enableHolidayMarking,
              )
            : null,
        generatedAt: DateTime.now(),
      );
      if (!mounted) {
        return;
      }
      if (result.eventCount == 0) {
        showAppToast(
          context,
          message: l10n.icsExportNoEvents,
        );
        return;
      }

      // 生成成功后让用户二选一：系统分享面板 / 系统保存对话框。
      // 分享面板里不保证有目标日历 App（它必须声明能接收 text/calendar
      // 的 SEND 才会出现，小米日历等只声明了「打开 .ics」），保存到目录
      // 是兜底路径：用户可从文件管理里用「打开方式」导入。
      final action = await showHyperosListPopup<_IcsExportAction>(
        context: context,
        position: hyperosPopupPositionBelow(context, _exportButtonAnchorKey),
        items: [
          HyperosPopupMenuItem(
            label: l10n.icsExportActionShare,
            value: _IcsExportAction.share,
            icon: Icons.ios_share_rounded,
          ),
          HyperosPopupMenuItem(
            label: l10n.icsExportActionSave,
            value: _IcsExportAction.save,
            icon: Icons.folder_outlined,
          ),
        ],
      );
      if (!mounted || action == null) {
        return;
      }
      switch (action) {
        case _IcsExportAction.share:
          await _shareResult(l10n, result);
        case _IcsExportAction.save:
          await _saveResult(l10n, result);
      }
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          message: l10n.icsExportFailed,
          kind: AppToastKind.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  /// 一键同步：把当前页选的课表 + 时间范围 + 事件类型直接写进手机系统
  /// 日历，不走「生成文件 → 分享 → 手动导入」链路。
  Future<void> _syncToSystemCalendar() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final profile = _profileForProvider(provider);

    if (profile == null) {
      showAppToast(
        context,
        message: l10n.icsExportNoProfiles,
        kind: AppToastKind.error,
      );
      return;
    }
    if (_eventKinds.isEmpty) {
      showAppToast(
        context,
        message: l10n.icsExportNoSelection,
        kind: AppToastKind.warning,
      );
      return;
    }
    if (_eventKinds.contains(IcsExportEventKind.course) &&
        profile.settings.semesterStartDate == null) {
      showAppToast(
        context,
        message: l10n.icsExportSemesterStartRequired,
        kind: AppToastKind.error,
      );
      return;
    }

    // 首次使用先讲清规则（覆盖语义 + 假期不写入 + 日历归属），确认过一次
    // 之后按钮即真·一键直达。prefs 实例自带内存缓存，重复读取无 IO。
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_calendarSyncNoticePrefsKey) ?? false)) {
      if (!mounted) {
        return;
      }
      final confirmed = await showHyperosConfirmDialog(
        context: context,
        title: l10n.icsExportSyncCalendarTitle,
        message: l10n.icsExportSyncCalendarBody(
          l10n.icsExportSyncCalendarName(profile.name),
        ),
        cancelLabel: l10n.cancelAction,
        confirmLabel: l10n.icsExportSyncCalendarConfirm,
      );
      if (confirmed != true || !mounted) {
        return;
      }
      await prefs.setBool(_calendarSyncNoticePrefsKey, true);
    }

    if (!mounted) {
      return;
    }
    // 权限缺就申请；弹系统对话框期间用户可能已关页，回来自先查 mounted。
    var granted = await _calendarSyncService.isPermissionGranted();
    if (!granted) {
      granted = await _calendarSyncService.requestPermission();
    }
    if (!granted || !mounted) {
      if (mounted) {
        showAppToast(
          context,
          message: l10n.icsExportSyncCalendarPermissionDenied,
          kind: AppToastKind.error,
        );
      }
      return;
    }

    // 事件收集与 ICS 文件导出同源（同一套周次换算 + 去重）。假期过滤跟随
    // 页面「跳过节假日课程」开关（默认开启）：关掉开关后同步会把假期课
    // 一并写入日历——两条导出路径由同一个开关控制。overrideEnabled 固定
    // false 的理由同 _export()：那是诊断页的模拟测试开关，不该进用户真实日历。
    final collected = _exportService.collectEvents(
      IcsExportRequest(
        profile: profile,
        fromDate: _fromDate,
        toDate: _toDate,
        eventKinds: _eventKinds,
        holidayFilter: _skipHolidayCourses
            ? IcsHolidayFilter(
                data: provider.holidayData,
                overrideEnabled: false,
                markingEnabled: provider.settings.enableHolidayMarking,
              )
            : null,
      ),
    );
    if (!mounted) {
      return;
    }
    if (collected.events.isEmpty) {
      showAppToast(context, message: l10n.icsExportNoEvents);
      return;
    }

    setState(() {
      _isSyncing = true;
    });
    try {
      final outcome = await _calendarSyncService.sync(
        calendarName: l10n.icsExportSyncCalendarName(profile.name),
        events: [
          for (final event in collected.events)
            CalendarSyncEvent(
              start: event.start,
              end: event.end,
              title: event.summary,
              location: event.location,
              description: event.description,
            ),
        ],
      );
      if (!mounted) {
        return;
      }
      if (outcome.isSuccess) {
        var message = l10n.icsExportSyncCalendarSuccess(outcome.syncedCount);
        if (collected.skippedHolidayCourses > 0) {
          message +=
              '\n${l10n.icsExportSyncCalendarSkipped(collected.skippedHolidayCourses)}';
        }
        showAppToast(
          context,
          message: message,
          kind: AppToastKind.success,
        );
      } else {
        showAppToast(
          context,
          message: l10n.icsExportSyncCalendarFailed,
          kind: AppToastKind.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  /// 移除已同步到系统日历的全部日程：删掉专属日历（连带其中所有日程），
  /// 用户自己的其他日历不受影响。删掉后想再同步，点上面的同步按钮即可
  /// 原样重建。破坏性动作，每次都确认，不做「已阅」记忆。
  Future<void> _removeFromSystemCalendar() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.icsExportRemoveCalendarTitle,
      message: l10n.icsExportRemoveCalendarBody,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.icsExportRemoveCalendarConfirm,
      destructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isRemoving = true;
    });
    try {
      final outcome = await _calendarSyncService.deleteSynced();
      if (!mounted) {
        return;
      }
      final (message, kind) = switch (outcome) {
        CalendarDeleteResult.deleted => (
          l10n.icsExportRemoveCalendarSuccess,
          AppToastKind.success,
        ),
        CalendarDeleteResult.notSynced => (
          l10n.icsExportRemoveCalendarNothing,
          AppToastKind.info,
        ),
        CalendarDeleteResult.failed => (
          l10n.icsExportRemoveCalendarFailed,
          AppToastKind.error,
        ),
      };
      showAppToast(context, message: message, kind: kind);
    } finally {
      if (mounted) {
        setState(() {
          _isRemoving = false;
        });
      }
    }
  }

  Future<void> _shareResult(
    AppLocalizations l10n,
    IcsExportResult result,
  ) async {
    final params = ShareParams(
      files: [
        XFile.fromData(
          Uint8List.fromList(utf8.encode(result.content)),
          mimeType: 'text/calendar',
          name: result.fileName,
        ),
      ],
      text: l10n.icsExportShareText,
      subject: l10n.icsExportShareSubject,
    );
    final shareResult =
        await (widget.shareCallback?.call(params) ??
            SharePlus.instance.share(params));
    if (!mounted) {
      return;
    }
    if (shareResult.status == ShareResultStatus.success) {
      showAppToast(
        context,
        message: l10n.icsExportShared(result.eventCount),
        kind: AppToastKind.success,
      );
    } else if (shareResult.status == ShareResultStatus.dismissed) {
      showAppToast(
        context,
        message: l10n.icsExportCancelled,
      );
    } else if (shareResult.status == ShareResultStatus.unavailable) {
      showAppToast(
        context,
        message: l10n.icsExportFailed,
        kind: AppToastKind.error,
      );
    }
  }

  /// 走系统「保存文件」对话框（Android 上是 SAF 的创建文档选择器，无需
  /// 存储权限）把 ICS 写到用户选的目录；文件名预先带 .ics 扩展名，
  /// file_picker 按 `MimeTypeMap` 把它映射成 text/calendar。
  Future<void> _saveResult(
    AppLocalizations l10n,
    IcsExportResult result,
  ) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(result.content));
      final savedPath =
          await (widget.saveCallback?.call(result.fileName, bytes) ??
              FilePicker.saveFile(
                dialogTitle: l10n.icsExportActionSave,
                fileName: result.fileName,
                type: FileType.custom,
                allowedExtensions: const ['ics'],
                bytes: bytes,
              ));
      if (!mounted) {
        return;
      }
      if (savedPath == null) {
        showAppToast(context, message: l10n.icsExportSaveCancelled);
      } else {
        showAppToast(
          context,
          message: l10n.icsExportSavedCount(result.eventCount),
          kind: AppToastKind.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          message: l10n.icsExportSaveFailed,
          kind: AppToastKind.error,
        );
      }
    }
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _mondayOf(DateTime date) {
    final day = _dateOnly(date);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  String _formatDate(BuildContext context, DateTime date) {
    return DateFormat.yMMMd(
      AppLocalizations.of(context)!.localeName,
    ).format(date);
  }
}
