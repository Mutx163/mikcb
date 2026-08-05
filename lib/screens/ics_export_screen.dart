import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/timetable_profile.dart';
import '../providers/timetable_provider.dart';
import '../services/ics_export_service.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';

class IcsExportScreen extends StatefulWidget {
  const IcsExportScreen({super.key, this.exportService, this.shareCallback});

  final IcsExportService? exportService;
  final Future<ShareResult> Function(ShareParams params)? shareCallback;

  @override
  State<IcsExportScreen> createState() => _IcsExportScreenState();
}

class _IcsExportScreenState extends State<IcsExportScreen> {
  late final IcsExportService _exportService;
  bool _initialized = false;
  bool _isExporting = false;
  String? _selectedProfileId;
  late DateTime _fromDate;
  late DateTime _toDate;
  Set<IcsExportEventKind> _eventKinds = Set<IcsExportEventKind>.of(
    IcsExportEventKind.all,
  );

  @override
  void initState() {
    super.initState();
    _exportService = widget.exportService ?? IcsExportService();
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
              child: HyperosButton(
                key: const Key('ics-export-share'),
                label: l10n.icsExportButton,
                loading: _isExporting,
                expand: true,
                onPressed: _isExporting ? null : _export,
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
        generatedAt: DateTime.now(),
      );
      if (!mounted) {
        return;
      }
      if (result.eventCount == 0) {
        showAppToast(
          context,
          message: l10n.icsExportNoEvents,
          kind: AppToastKind.info,
        );
        return;
      }

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
          kind: AppToastKind.info,
        );
      } else if (shareResult.status == ShareResultStatus.unavailable) {
        showAppToast(
          context,
          message: l10n.icsExportFailed,
          kind: AppToastKind.error,
        );
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
