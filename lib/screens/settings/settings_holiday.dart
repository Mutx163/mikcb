part of '../timetable_settings_screen.dart';

class _HolidaySettingsScreen extends StatefulWidget {
  const _HolidaySettingsScreen();

  @override
  State<_HolidaySettingsScreen> createState() => _HolidaySettingsScreenState();
}

class _HolidaySettingsScreenState extends State<_HolidaySettingsScreen> {
  late final TimetableProvider _timetableProvider;
  late TimetableSettings _draft;
  Future<void> _saveQueue = Future<void>.value();
  List<HolidayEntry> _customHolidays = [];

  @override
  void initState() {
    super.initState();
    _timetableProvider = context.read<TimetableProvider>();
    _draft = _timetableProvider.settings;
    _loadCustomHolidays();
  }

  Future<void> _loadCustomHolidays() async {
    final provider = _timetableProvider;
    final entries = await provider.getCustomHolidays();
    if (mounted) {
      setState(() {
        _customHolidays = entries;
      });
    }
  }

  void _updateDraft(TimetableSettings next) {
    setState(() {
      _draft = next;
    });
    _enqueuePersist(next);
  }

  void _enqueuePersist(TimetableSettings next) {
    _saveQueue = _saveQueue.catchError((_) {}).then((_) => _persistDraft(next));
  }

  Future<void> _persistDraft(TimetableSettings next) async {
    final provider = _timetableProvider;
    await provider.updateTimetableSettings(next);
  }

  Future<void> _showCustomHolidayDialog({
    HolidayEntry? existing,
    DateTime? initialStart,
    DateTime? initialEnd,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: existing?.name ?? '');
    DateTime? startDate = initialStart ?? existing?.date;
    DateTime? endDate = initialEnd ?? existing?.date;
    HolidayType selectedType = existing?.type ?? HolidayType.vacation;

    final result = await showHyperosSheet<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // showHyperosSheet already pads by viewInsets.bottom — do not add it
            // again on the frame or keyboard leaves a huge empty band.
            return PickerSheetScaffold(
              actions: Row(
                children: [
                  Expanded(
                    child: HyperosButton(
                      label: l10n.cancelAction,
                      variant: HyperosButtonVariant.secondary,
                      expand: true,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HyperosButton(
                      label: l10n.saveAction,
                      expand: true,
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) {
                          showAppToast(
                            ctx,
                            message: l10n.customHolidayNameRequired,
                            kind: AppToastKind.warning,
                          );
                          return;
                        }
                        if (startDate == null || endDate == null) {
                          return;
                        }
                        Navigator.pop(ctx, 'save');
                      },
                    ),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing != null
                        ? l10n.customHolidayEdit
                        : l10n.customHolidayAdd,
                    style: HyperosTypography.sheetTitle(ctx),
                  ),
                  const SizedBox(height: 16),
                  HyperosTextField(
                    controller: nameController,
                    label: l10n.customHolidayNameLabel,
                  ),
                  const SizedBox(height: 12),
                  // Match [HyperosTextField] / [HyperosPickerField] chrome on
                  // frosted sheets — avoid white [HyperosListGroup] islands.
                  // Start / end fields each open the Miuix calendar sheet
                  // (same range pattern as the schedule date rule dialog).
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final now = DateTime.now();
                      final startField = HyperosPickerField(
                        label: l10n.customHolidayStartDate,
                        value: startDate != null
                            ? _formatFullDate(startDate!)
                            : '--',
                        isPlaceholder: startDate == null,
                        onTap: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final picked = await showMiuixDatePickerSheet(
                            ctx,
                            title: l10n.customHolidayStartDate,
                            initialDate: startDate ?? now,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 2),
                          );
                          if (picked == null) return;
                          setDialogState(() {
                            startDate = picked;
                            if (endDate == null || endDate!.isBefore(picked)) {
                              endDate = picked;
                            }
                          });
                        },
                      );
                      final endField = HyperosPickerField(
                        label: l10n.customHolidayEndDate,
                        value: endDate != null
                            ? _formatFullDate(endDate!)
                            : '--',
                        isPlaceholder: endDate == null,
                        onTap: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final picked = await showMiuixDatePickerSheet(
                            ctx,
                            title: l10n.customHolidayEndDate,
                            initialDate: endDate ?? startDate ?? now,
                            firstDate: startDate ?? DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 2),
                          );
                          if (picked == null) return;
                          setDialogState(() => endDate = picked);
                        },
                      );
                      if (constraints.maxWidth < 300) {
                        return Column(
                          children: [
                            startField,
                            const SizedBox(height: 12),
                            endField,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: startField),
                          const SizedBox(width: 12),
                          Expanded(child: endField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.customHolidayType,
                    style: TextStyle(
                      fontSize: HyperosMiuixTextField.labelFontSizeNormal,
                      color: HyperosColors.onSurface(ctx),
                    ),
                  ),
                  const SizedBox(height: 8),
                  HyperosSegmentedControl(
                    tabs: [
                      l10n.customHolidayTypeVacation,
                      l10n.customHolidayTypeWorkday,
                    ],
                    selectedIndex: selectedType == HolidayType.vacation ? 0 : 1,
                    onChanged: (index) {
                      setDialogState(() {
                        selectedType = index == 0
                            ? HolidayType.vacation
                            : HolidayType.adjustedWorkday;
                      });
                    },
                  ),
                  if (existing?.groupId != null) ...[
                    const SizedBox(height: 16),
                    HyperosButton(
                      label: l10n.customHolidayDelete,
                      variant: HyperosButtonVariant.destructive,
                      expand: true,
                      // Close the edit sheet first; confirm is a separate
                      // bottom sheet so we never stack dialog-on-sheet.
                      onPressed: () => Navigator.pop(ctx, 'delete'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (result == 'delete' && existing?.groupId != null) {
      await _confirmDeleteCustomHoliday(existing!.groupId!);
      return;
    }
    if (result != 'save' || startDate == null || endDate == null) return;
    final name = nameController.text.trim();
    final groupId =
        existing?.groupId ?? 'custom-${DateTime.now().millisecondsSinceEpoch}';
    final provider = context.read<TimetableProvider>();

    final entries = <HolidayEntry>[];
    var d = startDate!;
    while (!d.isAfter(endDate!)) {
      entries.add(
        HolidayEntry(
          date: DateTime(d.year, d.month, d.day),
          name: name,
          type: selectedType,
          groupId: groupId,
        ),
      );
      d = d.add(const Duration(days: 1));
    }

    // saveCustomHolidays 写失败会向上抛（不再被整体 catch 吞掉）。此处
    // 兜底给用户明确反馈：失败不是成功——旧实现吞掉异常后内存里看似
    // 保存成功，进程结束数据凭空消失。
    try {
      if (existing != null) {
        await provider.updateCustomHoliday(groupId, entries);
      } else {
        await provider.addCustomHolidays(entries);
      }
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        message: AppLocalizations.of(
          context,
        )!.saveFailedWithError('$error'),
        kind: AppToastKind.error,
      );
      return;
    }
    await _loadCustomHolidays();
  }

  /// Bottom confirm sheet with solid HyperOS buttons (not center HyperosDialog).
  Future<bool> _showCustomHolidayDeleteConfirmSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return HyperosSheetFrame(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.customHolidayDelete,
                style: HyperosTypography.sheetTitle(sheetContext),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.customHolidayDeleteConfirm,
                style: HyperosTypography.listDetail(sheetContext),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: HyperosButton(
                      label: l10n.cancelAction,
                      variant: HyperosButtonVariant.secondary,
                      expand: true,
                      onPressed: () => Navigator.pop(sheetContext, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HyperosButton(
                      label: l10n.deleteAction,
                      variant: HyperosButtonVariant.destructive,
                      expand: true,
                      onPressed: () => Navigator.pop(sheetContext, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _confirmDeleteCustomHoliday(String groupId) async {
    final confirmed = await _showCustomHolidayDeleteConfirmSheet();
    if (confirmed && mounted) {
      final provider = context.read<TimetableProvider>();
      final l10n = AppLocalizations.of(context)!;
      try {
        await provider.removeCustomHoliday(groupId);
      } catch (error) {
        if (!mounted) return;
        showAppToast(
          context,
          message: l10n.saveFailedWithError('$error'),
          kind: AppToastKind.error,
        );
        return;
      }
      await _loadCustomHolidays();
    }
  }

  /// Group custom holiday entries by groupId for display.
  List<_CustomHolidayGroup> _groupCustomHolidays() {
    final map = <String, List<HolidayEntry>>{};
    for (final entry in _customHolidays) {
      final key = entry.groupId ?? 'ungrouped';
      map.putIfAbsent(key, () => []).add(entry);
    }
    return map.entries.map((e) {
      e.value.sort((a, b) => a.date.compareTo(b.date));
      return _CustomHolidayGroup(
        groupId: e.key,
        name: e.value.first.name,
        startDate: e.value.first.date,
        endDate: e.value.last.date,
        type: e.value.first.type,
      );
    }).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final holidayData = provider.holidayData;
    final now = DateTime.now();

    // Collect official holidays (exclude custom ones)
    final officialHolidays = <_HolidayDisplayItem>[];
    if (holidayData != null) {
      final seenGroups = <String>{};
      for (final entry in holidayData.entries) {
        if (entry.groupId != null && entry.groupId!.startsWith('custom-')) {
          continue;
        }
        if (entry.groupId != null && seenGroups.add(entry.groupId!)) {
          final groupEntries = holidayData.entriesForGroup(entry.groupId!);
          final vacationEntries = groupEntries
              .where((e) => e.type == HolidayType.vacation)
              .toList();
          final representative = vacationEntries.isNotEmpty
              ? vacationEntries
              : groupEntries;
          officialHolidays.add(
            _HolidayDisplayItem(
              name: localizedHolidayName(l10n, representative.first.name),
              startDate: representative.first.date,
              endDate: representative.last.date,
              type: representative.first.type,
              isPast: representative.last.date.isBefore(now),
            ),
          );
        } else if (entry.groupId == null &&
            entry.type == HolidayType.adjustedWorkday) {
          officialHolidays.add(
            _HolidayDisplayItem(
              name: l10n.holidayMakeupWorkday,
              startDate: entry.date,
              endDate: entry.date,
              type: entry.type,
              isPast: entry.date.isBefore(now),
            ),
          );
        }
      }
    }

    // Sort by start date
    officialHolidays.sort((a, b) => a.startDate.compareTo(b.startDate));

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.tune_rounded),
          semanticsLabel: l10n.holidayAdvancedTitle,
          onPress: () {
            HyperosNavigation.push(
              context,
              settings: const RouteSettings(name: '/settings/holiday/advanced'),
              builder: (_) => const _HolidayAdvancedSettingsScreen(),
            );
          },
        ),
      ],
      title: Text(l10n.holidaySettingsTitle),
      child: HyperosListView(
        itemCount: _holidaySectionCount,
        itemBuilder: (context, index) => _buildHolidaySection(
          context,
          index,
          l10n: l10n,
          holidayData: holidayData,
          officialHolidays: officialHolidays,
        ),
      ),
    );
  }

  static const _holidaySectionCount = 3;

  Widget _buildHolidaySection(
    BuildContext context,
    int index, {
    required AppLocalizations l10n,
    required HolidayData? holidayData,
    required List<_HolidayDisplayItem> officialHolidays,
  }) {
    return switch (index) {
      0 => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                title: l10n.holidayEnableTitle,
                subtitle: l10n.holidayEnableSubtitle,
                value: _draft.enableHolidayMarking,
                onChanged: (value) {
                  _updateDraft(_draft.copyWith(enableHolidayMarking: value));
                },
              ),
            ],
          ),
          const HyperosSectionGap(),
        ],
      ),
      1 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(text: l10n.customHolidayTitle),
          HyperosListGroup(
            children: [
              if (_customHolidays.isEmpty)
                HyperosNavTile(
                  title: l10n.customHolidayEmpty,
                  enabled: false,
                  showChevron: false,
                )
              else
                ..._groupCustomHolidays().map((group) {
                  final typeLabel = group.type == HolidayType.vacation
                      ? l10n.customHolidayTypeVacation
                      : l10n.customHolidayTypeWorkday;
                  final rangeLabel = _formatHolidayRange(
                    group.startDate,
                    group.endDate,
                    l10n,
                  );
                  return HyperosNavTile(
                    title: group.name,
                    // System preference style: primary title, gray caption, trailing summary.
                    subtitle: typeLabel,
                    details: rangeLabel,
                    holdHighlightThroughTransition: false,
                    onTap: () {
                      final entries = _customHolidays
                          .where((e) => e.groupId == group.groupId)
                          .toList();
                      if (entries.isNotEmpty) {
                        _showCustomHolidayDialog(
                          existing: entries.first,
                          initialStart: group.startDate,
                          initialEnd: group.endDate,
                        );
                      }
                    },
                    onLongPress: () =>
                        _confirmDeleteCustomHoliday(group.groupId),
                  );
                }),
            ],
          ),
          const SizedBox(height: 12),
          // Full-width Miuix button (same pattern as data transfer / empty states).
          HyperosControlCard(
            child: HyperosControlCardInset(
              child: HyperosButton(
                label: l10n.customHolidayAdd,
                variant: HyperosButtonVariant.secondary,
                expand: true,
                onPressed: () => _showCustomHolidayDialog(),
              ),
            ),
          ),
          const HyperosSectionGap(),
        ],
      ),
      _ => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSectionLabel(
            text: l10n.holidayDataYearLabel(holidayData?.year ?? ''),
          ),
          if (officialHolidays.isEmpty)
            HyperosListGroup(
              children: [
                HyperosNavTile(title: l10n.holidayNoUpcoming, enabled: false),
              ],
            )
          else
            HyperosListGroup(
              children: [
                for (final holiday in officialHolidays)
                  Opacity(
                    opacity: holiday.isPast ? 0.55 : 1,
                    child: HyperosNavTile(
                      title: holiday.name,
                      details: _formatHolidayRange(
                        holiday.startDate,
                        holiday.endDate,
                        l10n,
                      ),
                      showChevron: false,
                      holdHighlightThroughTransition: false,
                    ),
                  ),
              ],
            ),
        ],
      ),
    };
  }

  String _formatHolidayRange(
    DateTime start,
    DateTime end,
    AppLocalizations l10n,
  ) {
    if (_isSameDate(start, end)) {
      return l10n.holidayDateSameDay(start.month, start.day);
    }
    if (start.month == end.month) {
      return l10n.holidayDateSameMonth(start.month, start.day, end.day);
    }
    return l10n.holidayDateDiffMonth(
      start.month,
      start.day,
      end.month,
      end.day,
    );
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatFullDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// Advanced holiday tools: manual refresh + update log (hidden from casual users).
class _HolidayAdvancedSettingsScreen extends StatefulWidget {
  const _HolidayAdvancedSettingsScreen();

  @override
  State<_HolidayAdvancedSettingsScreen> createState() =>
      _HolidayAdvancedSettingsScreenState();
}

class _HolidayAdvancedSettingsScreenState
    extends State<_HolidayAdvancedSettingsScreen> {
  bool _refreshing = false;

  Future<void> _refreshHolidayData() async {
    if (_refreshing) {
      return;
    }
    setState(() => _refreshing = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<TimetableProvider>().refreshHolidayData();
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.holidayCheckUpdate,
        kind: AppToastKind.success,
      );
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final logs = provider.holidayLogs;
    final cardColor = HyperosColors.card(context);
    final divider = HyperosColors.dividerLine(context);

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.holidayAdvancedTitle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: HyperosBlurredBodyInset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  HyperosSectionLabel(text: l10n.holidayUpdateLog),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Material(
                        color: cardColor,
                        shape: HyperosTheme.cardShape(),
                        clipBehavior: Clip.antiAlias,
                        child: logs.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无日志',
                                  style: HyperosTypography.listDetail(context),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  12,
                                ),
                                itemCount: logs.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (_, index) {
                                  final log = logs[index];
                                  final message = HolidayLogLocalizer.localize(
                                    l10n,
                                    log.message,
                                  );
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log.timeString,
                                        style:
                                            HyperosTypography.listDetail(
                                              context,
                                            ).copyWith(
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                              height: 1.2,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        message,
                                        style:
                                            HyperosTypography.listDetail(
                                              context,
                                            ).copyWith(
                                              color: HyperosColors.primaryText(
                                                context,
                                              ),
                                              height: 1.4,
                                              letterSpacing: 0.1,
                                            ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Fixed footer: solid bar + full-width refresh action.
          Material(
            color: cardColor,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(top: BorderSide(color: divider, width: 0.5)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: HyperosButton(
                    label: l10n.holidayCheckUpdate,
                    expand: true,
                    loading: _refreshing,
                    onPressed: _refreshing ? null : _refreshHolidayData,
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

class _HolidayDisplayItem {
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final HolidayType type;
  final bool isPast;

  const _HolidayDisplayItem({
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.isPast,
  });
}

class _CustomHolidayGroup {
  final String groupId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final HolidayType type;

  const _CustomHolidayGroup({
    required this.groupId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.type,
  });
}
