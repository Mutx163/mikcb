import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/course.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../services/home_widget_service.dart';
import '../services/miui_live_activities_service.dart';
import '../services/umeng_analytics_service.dart';
import '../utils/hex_color.dart';
import '../widgets/course_card.dart';
import 'about_screen.dart';
import 'data_transfer_screen.dart';
import 'feedback_screen.dart';
import 'live_settings_subpages.dart';
import 'live_diagnostics_log_viewer_screen.dart';
import 'time_scheme_management_screen.dart';
import 'timetable_profiles_screen.dart';
import 'user_guide_screen.dart';

class TimetableSettingsScreen extends StatelessWidget {
  const TimetableSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final l10n = AppLocalizations.of(context)!;
        final settings = provider.settings;
        void openAppearance() {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/settings/appearance'),
              builder: (_) => const _AppearanceSettingsScreen(),
            ),
          );
        }

        void openLiveSettings() {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/settings/live'),
              builder: (_) => const _LiveSettingsScreen(),
            ),
          );
        }

        void openLayoutSettings() {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/settings/layout'),
              builder: (_) => const _LayoutSettingsScreen(),
            ),
          );
        }

        void openHomeWidgetSettings() {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/settings/home-widget'),
              builder: (_) => const _HomeWidgetSettingsScreen(),
            ),
          );
        }

        void openDataTransfer() {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/settings/data-transfer'),
              builder: (_) => const DataTransferScreen(),
            ),
          );
        }

        void openUserGuide() {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/user-guide'),
              builder: (_) => const UserGuideScreen(),
            ),
          );
        }

        void openAbout() {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/about'),
              builder: (_) => const AboutScreen(),
            ),
          );
        }

        void openFeedback() {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/feedback'),
              builder: (_) => const FeedbackScreen(),
            ),
          );
        }

        void openProfiles() {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/profiles'),
              builder: (_) => const TimetableProfilesScreen(),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(l10n.settingsTitle)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SemesterOverviewCard(
                currentWeek: provider.currentWeek,
                semesterWeekCount: settings.semesterWeekCount,
                semesterStartDate: settings.semesterStartDate,
                onPickSemesterStartDate: () => _pickSemesterStartDate(context),
                onSyncCurrentWeek: settings.semesterStartDate == null
                    ? null
                    : () => _syncCurrentWeek(context),
                onPickSemesterWeekCount: () => _pickSemesterWeekCount(context),
              ),
              const SizedBox(height: 8),
              _SettingsSectionCard(
                title: l10n.dailyUsageSectionTitle,
                child: Column(
                  children: [
                    _SettingsEntryTile(
                      icon: Icons.palette_outlined,
                      title: l10n.appearanceEntryTitle,
                      subtitle: l10n.appearanceEntrySubtitle,
                      trailing: _ColorDot(
                        color: _colorFromHex(settings.themeSeedColor),
                      ),
                      onTap: openAppearance,
                    ),
                    _SettingsEntryTile(
                      icon: Icons.view_week_outlined,
                      title: l10n.layoutSectionEntryTitle,
                      subtitle: l10n.layoutSectionEntrySubtitle,
                      onTap: openLayoutSettings,
                    ),
                    _SettingsEntryTile(
                      icon: Icons.widgets_outlined,
                      title: l10n.homeWidgetEntryTitle,
                      subtitle: l10n.homeWidgetEntrySubtitle,
                      trailing: Text(
                        settings.widgetBackgroundStyle.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: openHomeWidgetSettings,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Divider(height: 12),
              ),
              _SettingsSectionCard(
                title: l10n.reminderNotificationSectionTitle,
                child: Column(
                  children: [
                    _SettingsEntryTile(
                      icon: Icons.notifications_active_outlined,
                      title: l10n.liveSettingsTitle,
                      subtitle: l10n.liveSettingsEntrySubtitle,
                      onTap: openLiveSettings,
                    ),
                    _SettingsEntryTile(
                      icon: Icons.menu_book_outlined,
                      title: l10n.userGuideEntryTitle,
                      subtitle: l10n.userGuideEntrySubtitle,
                      onTap: openUserGuide,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Divider(height: 12),
              ),
              _SettingsSectionCard(
                title: l10n.timetableManagementSectionTitle,
                child: Column(
                  children: [
                    _SettingsEntryTile(
                      icon: Icons.layers_outlined,
                      title: l10n.timetableManagement,
                      subtitle: l10n.timetableProfilesEntrySubtitle,
                      onTap: openProfiles,
                    ),
                    _SettingsEntryTile(
                      icon: Icons.schedule_rounded,
                      title: l10n.timeSchemeEntryTitle,
                      subtitle: settings.activeTimeSchemeId == null
                          ? l10n.timeSchemeEntrySubtitleNoneSelected
                          : l10n.timeSchemeEntrySubtitleSelected(
                              provider.activeTimeScheme?.name ?? '',
                            ),
                      onTap: () => _openTimeSchemeQuickSwitcher(context),
                    ),
                    _SettingsEntryTile(
                      icon: Icons.swap_horiz_rounded,
                      title: l10n.dataTransferEntryTitle,
                      subtitle: l10n.dataTransferEntrySubtitle,
                      onTap: openDataTransfer,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Divider(height: 12),
              ),
              _SettingsSectionCard(
                title: l10n.aboutSupportSectionTitle,
                child: Column(
                  children: [
                    _SettingsEntryTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: l10n.feedbackEntryTitle,
                      subtitle: l10n.feedbackEntrySubtitle,
                      onTap: openFeedback,
                    ),
                    _SettingsEntryTile(
                      icon: Icons.info_outline_rounded,
                      title: l10n.aboutEntryTitle,
                      subtitle: l10n.aboutEntrySubtitle,
                      onTap: openAbout,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickSemesterStartDate(BuildContext context) async {
    final provider = context.read<TimetableProvider>();
    final selected = await showDatePicker(
      context: context,
      initialDate: provider.settings.semesterStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (selected == null || !context.mounted) {
      return;
    }

    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(semesterStartDate: selected),
    );
    if (!context.mounted || message == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _syncCurrentWeek(BuildContext context) async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    await provider.syncCurrentWeekWithSemesterStart();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.currentWeekBullet(provider.currentWeek))),
    );
  }

  Future<void> _pickSemesterWeekCount(BuildContext context) async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    final currentWeekCount = provider.settings.semesterWeekCount;
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: null, subtitle: null),
              ListTile(
                title: Text(
                  l10n.selectSemesterWeekCountTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(l10n.selectSemesterWeekCountSubtitle),
              ),
              ...List.generate(30, (index) {
                final weekCount = index + 1;
                return ListTile(
                  title: Text(l10n.semesterWeekCountAction(weekCount)),
                  trailing: weekCount == currentWeekCount
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(context, weekCount),
                );
              }),
            ],
          ),
        );
      },
    );

    if (selected == null || !context.mounted || selected == currentWeekCount) {
      return;
    }

    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(semesterWeekCount: selected),
    );
    if (message != null) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    if (provider.currentWeek > selected) {
      await provider.setCurrentWeek(selected);
    }
  }

  Future<void> _openTimeSchemeQuickSwitcher(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/settings/time-schemes'),
        builder: (_) => const TimeSchemeManagementScreen(),
      ),
    );
  }
}

class _SemesterOverviewCard extends StatelessWidget {
  final int currentWeek;
  final int semesterWeekCount;
  final DateTime? semesterStartDate;
  final VoidCallback onPickSemesterStartDate;
  final VoidCallback? onSyncCurrentWeek;
  final VoidCallback onPickSemesterWeekCount;

  const _SemesterOverviewCard({
    required this.currentWeek,
    required this.semesterWeekCount,
    required this.semesterStartDate,
    required this.onPickSemesterStartDate,
    required this.onSyncCurrentWeek,
    required this.onPickSemesterWeekCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/branding/launcher_icon.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.semesterOverviewCurrentWeek(
                          currentWeek,
                          semesterWeekCount,
                        ),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        semesterStartDate == null
                            ? l10n.semesterStartUnset
                            : l10n.semesterStartSet(
                                _formatDate(semesterStartDate!),
                              ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onPickSemesterStartDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    semesterStartDate == null
                        ? AppLocalizations.of(
                            context,
                          )!.setSemesterStartDateAction
                        : AppLocalizations.of(context)!.semesterStartDateAction,
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onSyncCurrentWeek,
                  icon: const Icon(Icons.sync_outlined),
                  label: Text(
                    AppLocalizations.of(context)!.syncCurrentWeekAction,
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onPickSemesterWeekCount,
                  icon: const Icon(Icons.view_week_outlined),
                  label: Text(
                    AppLocalizations.of(
                      context,
                    )!.semesterWeekCountAction(semesterWeekCount),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceSettingsScreen extends StatefulWidget {
  const _AppearanceSettingsScreen();

  @override
  State<_AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<_AppearanceSettingsScreen> {
  static const List<String> _themeColors = [
    '#2563EB',
    '#0891B2',
    '#0F766E',
    '#4F46E5',
    '#DC2626',
    '#EA580C',
    '#CA8A04',
    '#111827',
  ];

  static const List<String> _backgroundColors = [
    '#F8FAFC',
    '#F7F7F5',
    '#FDF6EC',
    '#F2F7FF',
    '#F5F3FF',
    '#ECFDF5',
  ];

  static const List<String> _cardColors = [
    '#2563EB',
    '#4CAF50',
    '#FF9800',
    '#E91E63',
    '#9C27B0',
    '#00BCD4',
    '#FF5722',
    '#795548',
    '#607D8B',
  ];

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
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final previewCardColor = _draft.timetableUseUnifiedCardColor
        ? _draft.timetableUnifiedCardColor
        : _draft.themeSeedColor;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearanceTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : _colorFromHex(_draft.timetablePageBackgroundColor),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.previewTitle,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainer.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 72,
                            decoration: BoxDecoration(
                              color: _colorFromHex(previewCardColor),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.sampleCourseNumericalControl,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'A301',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 72,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              l10n.timetableBackgroundPreview,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            title: l10n.displayModeTitle,
            subtitle: l10n.displayModeSubtitle,
            child: DropdownButtonFormField<AppThemeMode>(
              initialValue: _draft.appThemeMode,
              decoration: InputDecoration(
                labelText: l10n.themeModeLabel,
                border: OutlineInputBorder(),
              ),
              items: AppThemeMode.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_themeModeLabel(context, value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                _updateDraft(_draft.copyWith(appThemeMode: value));
              },
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            title: l10n.fontSectionTitle,
            subtitle: l10n.fontSectionSubtitle,
            child: DropdownButtonFormField<AppFontMode>(
              initialValue: _draft.appFontMode,
              decoration: InputDecoration(
                labelText: l10n.fontModeLabel,
                border: const OutlineInputBorder(),
              ),
              items: AppFontMode.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_fontModeLabel(context, value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                _updateDraft(_draft.copyWith(appFontMode: value));
              },
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            title: l10n.languageSectionTitle,
            subtitle: l10n.languageSectionSubtitle,
            child: DropdownButtonFormField<String>(
              initialValue: normalizeLocaleTagForDropdown(_draft.appLocaleTag),
              decoration: InputDecoration(
                labelText: l10n.languageModeLabel,
                border: const OutlineInputBorder(),
              ),
              items: buildLocaleDropdownItems(context),
              onChanged: (value) {
                if (value == null) return;
                _updateDraft(_draft.copyWith(appLocaleTag: value));
              },
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            title: l10n.homeTitleSectionTitle,
            subtitle: l10n.homeTitleSectionSubtitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<HomeTitleStyle>(
                  initialValue: _draft.homeTitleStyle,
                  decoration: InputDecoration(
                    labelText: l10n.homeTitleStyleLabel,
                    border: OutlineInputBorder(),
                  ),
                  items: HomeTitleStyle.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_homeTitleStyleLabel(context, value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _updateDraft(_draft.copyWith(homeTitleStyle: value));
                  },
                ),
                const SizedBox(height: 12),
                _HomeTitleStylePreview(style: _draft.homeTitleStyle),
                const SizedBox(height: 8),
                Text(
                  _homeTitleStyleDescription(context, _draft.homeTitleStyle),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            title: l10n.themeSeedSectionTitle,
            subtitle: l10n.themeSeedSectionSubtitle,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _themeColors
                  .map(
                    (color) => _SelectableColorChip(
                      colorHex: color,
                      selected: _draft.themeSeedColor == color,
                      onTap: () {
                        _updateDraft(_draft.copyWith(themeSeedColor: color));
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            title: l10n.timetableBackgroundColorSectionTitle,
            subtitle: l10n.timetableBackgroundColorSectionSubtitle,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _backgroundColors
                  .map(
                    (color) => _SelectableColorChip(
                      colorHex: color,
                      selected: _draft.timetablePageBackgroundColor == color,
                      onTap: () {
                        _updateDraft(
                          _draft.copyWith(timetablePageBackgroundColor: color),
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.unifiedCourseCardColorTitle),
                  subtitle: Text(l10n.unifiedCourseCardColorSubtitle),
                  value: _draft.timetableUseUnifiedCardColor,
                  onChanged: (value) {
                    _updateDraft(
                      _draft.copyWith(timetableUseUnifiedCardColor: value),
                    );
                  },
                ),
                if (_draft.timetableUseUnifiedCardColor) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _cardColors
                          .map(
                            (color) => _SelectableColorChip(
                              colorHex: color,
                              selected:
                                  _draft.timetableUnifiedCardColor == color,
                              onTap: () {
                                _updateDraft(
                                  _draft.copyWith(
                                    timetableUnifiedCardColor: color,
                                  ),
                                );
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() {
      _draft = next;
    });
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
    if (next.liveMiuiIslandExpandedIconMode ==
            MiuiIslandExpandedIconMode.customImage &&
        (next.liveMiuiIslandExpandedIconPath == null ||
            next.liveMiuiIslandExpandedIconPath!.isEmpty)) {
      return;
    }
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(next);
    if (!mounted) {
      return;
    }
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _draft = provider.settings;
      });
    }
  }
}

String _themeModeLabel(BuildContext context, AppThemeMode mode) {
  final l10n = AppLocalizations.of(context)!;
  return switch (mode) {
    AppThemeMode.system => l10n.themeModeSystem,
    AppThemeMode.light => l10n.themeModeLight,
    AppThemeMode.dark => l10n.themeModeDark,
  };
}

String _fontModeLabel(BuildContext context, AppFontMode mode) {
  final l10n = AppLocalizations.of(context)!;
  return switch (mode) {
    AppFontMode.system => l10n.fontModeSystem,
    AppFontMode.miSans => l10n.fontModeMiSans,
  };
}

List<DropdownMenuItem<String>> buildLocaleDropdownItems(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final seen = <String>{''};
  final items = <DropdownMenuItem<String>>[
    DropdownMenuItem<String>(value: '', child: Text(l10n.languageModeSystem)),
  ];
  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.countryCode?.isNotEmpty == true
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    if (!seen.add(tag)) {
      continue;
    }
    items.add(
      DropdownMenuItem<String>(
        value: tag,
        child: Text(localeLabel(context, locale)),
      ),
    );
  }
  return items;
}

String localeLabel(BuildContext context, Locale locale) {
  final l10n = AppLocalizations.of(context)!;
  final tag = locale.countryCode?.isNotEmpty == true
      ? '${locale.languageCode}_${locale.countryCode}'
      : locale.languageCode;
  switch (tag) {
    case 'zh':
    case 'zh_CN':
      return l10n.languageModeZhCn;
    case 'zh_HK':
      return l10n.languageModeZhHk;
    case 'zh_TW':
      return l10n.languageModeZhTw;
    case 'en':
    case 'en_US':
      return l10n.languageModeEnUs;
    default:
      return tag;
  }
}

String normalizeLocaleTagForDropdown(String tag) {
  final normalized = tag.trim();
  if (normalized.isEmpty) {
    return '';
  }
  final canonical = normalized.replaceAll('-', '_');
  final supportedTags = AppLocalizations.supportedLocales
      .map(
        (locale) => locale.countryCode?.isNotEmpty == true
            ? '${locale.languageCode}_${locale.countryCode}'
            : locale.languageCode,
      )
      .toSet();
  if (supportedTags.contains(canonical)) {
    return canonical;
  }
  final languageCode = canonical.split('_').first;
  if (supportedTags.contains(languageCode)) {
    return languageCode;
  }
  return '';
}

String _homeTitleStyleLabel(BuildContext context, HomeTitleStyle style) {
  final l10n = AppLocalizations.of(context)!;
  return switch (style) {
    HomeTitleStyle.classic => l10n.homeTitleStyleClassicLabel,
    HomeTitleStyle.brand => l10n.homeTitleStyleBrandLabel,
  };
}

String _homeTitleStyleDescription(BuildContext context, HomeTitleStyle style) {
  final l10n = AppLocalizations.of(context)!;
  return switch (style) {
    HomeTitleStyle.classic => l10n.homeTitleStyleClassicDescription,
    HomeTitleStyle.brand => l10n.homeTitleStyleBrandDescription,
  };
}

String _widgetBackgroundStyleLabel(
  BuildContext context,
  WidgetBackgroundStyle style,
) {
  final l10n = AppLocalizations.of(context)!;
  return switch (style) {
    WidgetBackgroundStyle.glass => l10n.widgetBackgroundStyleGlass,
    WidgetBackgroundStyle.solid => l10n.widgetBackgroundStyleSolid,
    WidgetBackgroundStyle.gradient => l10n.widgetBackgroundStyleGradient,
  };
}

String _homeWidgetTargetLabel(
  BuildContext context,
  HomeWidgetPinTarget target,
) {
  final l10n = AppLocalizations.of(context)!;
  return switch (target) {
    HomeWidgetPinTarget.compact22 => l10n.homeWidgetTargetCompact22,
    HomeWidgetPinTarget.miniList22 => l10n.homeWidgetTargetMiniList22,
    HomeWidgetPinTarget.medium24 => l10n.homeWidgetTargetMedium24,
    HomeWidgetPinTarget.large44 => l10n.homeWidgetTargetLarge44,
  };
}

class _HomeTitleStylePreview extends StatelessWidget {
  final HomeTitleStyle style;

  const _HomeTitleStylePreview({required this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget child;
    switch (style) {
      case HomeTitleStyle.classic:
        child = Text(
          AppLocalizations.of(context)!.appTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        );
      case HomeTitleStyle.brand:
        child = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context)!.appTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            Text(
              AppLocalizations.of(context)!.defaultTimetablePreviewName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Align(alignment: Alignment.center, child: child),
    );
  }
}

class _LiveSettingsScreen extends StatefulWidget {
  const _LiveSettingsScreen();

  @override
  State<_LiveSettingsScreen> createState() => _LiveSettingsScreenState();
}

class _LiveSettingsScreenState extends State<_LiveSettingsScreen> {
  late TimetableSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final beforeClassSummary = _liveDisplaySummary(
      context,
      _draft.beforeClassDisplaySettings,
    );
    final duringEndSummary = _draft.liveDuringEndFollowBeforeClass
        ? l10n.followBeforeClassSetting
        : _liveDisplaySummary(context, _draft.duringEndDisplaySettings);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.liveSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                _SettingsEntryTile(
                  icon: Icons.alarm_outlined,
                  title: l10n.liveReminderTimingTitle,
                  subtitle: l10n.liveReminderTimingEntrySubtitle,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LiveReminderTimingScreen(),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _draft = context.read<TimetableProvider>().settings;
                    });
                  },
                ),
                _SettingsEntryTile(
                  icon: Icons.upcoming_outlined,
                  title: l10n.beforeClassDisplaySettingsTitle,
                  subtitle: beforeClassSummary,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveDisplaySettingsScreen(
                          title: l10n.beforeClassDisplaySettingsTitle,
                          forDuringEnd: false,
                        ),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _draft = context.read<TimetableProvider>().settings;
                    });
                  },
                ),
                _SettingsEntryTile(
                  icon: Icons.timelapse_rounded,
                  title: l10n.duringEndDisplaySettingsTitle,
                  subtitle: duringEndSummary,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveDisplaySettingsScreen(
                          title: l10n.duringEndDisplaySettingsTitle,
                          forDuringEnd: true,
                        ),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _draft = context.read<TimetableProvider>().settings;
                    });
                  },
                ),
                _SettingsEntryTile(
                  icon: Icons.shield_outlined,
                  title: l10n.liveKeepAliveTitle,
                  subtitle: l10n.liveKeepAliveEntrySubtitle,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LiveKeepAliveSettingsScreen(),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _draft = context.read<TimetableProvider>().settings;
                    });
                  },
                ),
                _SettingsEntryTile(
                  icon: Icons.science_outlined,
                  title: l10n.liveTestingEntryTitle,
                  subtitle: l10n.liveTestingEntrySubtitle,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _LiveTestingSettingsScreen(),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _draft = context.read<TimetableProvider>().settings;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveTestingSettingsScreen extends StatefulWidget {
  const _LiveTestingSettingsScreen();

  @override
  State<_LiveTestingSettingsScreen> createState() =>
      _LiveTestingSettingsScreenState();
}

class _LiveTestingSettingsScreenState extends State<_LiveTestingSettingsScreen>
    with WidgetsBindingObserver {
  static const Duration _autoRefreshInterval = Duration(seconds: 1);

  final MiuiLiveActivitiesService _liveService = MiuiLiveActivitiesService();
  Map<String, dynamic>? _debugStatus;
  bool _loadingDebugStatus = true;
  bool _exportingDiagnostics = false;
  bool _clearingDiagnostics = false;
  Timer? _autoRefreshTimer;
  bool _refreshInFlight = false;
  bool _isAppResumed = true;
  bool _autoRefreshEnabled = true;
  DateTime? _lastDebugStatusUpdatedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshDebugStatus(showLoading: true));
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (!mounted || !_isAppResumed) {
        return;
      }
      if (!_autoRefreshEnabled) {
        return;
      }
      unawaited(_refreshDebugStatus());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshDebugStatus({bool showLoading = false}) async {
    if (_refreshInFlight) {
      return;
    }
    _refreshInFlight = true;
    if (mounted && showLoading) {
      setState(() {
        _loadingDebugStatus = true;
      });
    }
    try {
      final status = await _liveService.getLiveUpdateDebugStatus();
      if (!mounted) return;
      setState(() {
        _debugStatus = status;
        _loadingDebugStatus = false;
        _lastDebugStatusUpdatedAt = DateTime.now();
      });
    } finally {
      _refreshInFlight = false;
      if (mounted && showLoading) {
        setState(() {
          _loadingDebugStatus = false;
        });
      }
    }
  }

  Future<void> _openLiveDiagnosticsViewer() async {
    final rawLog = await _liveService.readLiveDiagnosticsText();
    if (!mounted) return;
    if (rawLog == null || rawLog.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.liveDiagnosticsUnavailable,
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveDiagnosticsLogViewerScreen(
          title: AppLocalizations.of(context)!.liveDiagnosticsViewerTitle,
          rawLog: rawLog,
        ),
      ),
    );
  }

  Future<void> _exportLiveDiagnostics() async {
    final l10n = AppLocalizations.of(context)!;
    if (_exportingDiagnostics) return;
    setState(() {
      _exportingDiagnostics = true;
    });
    final logPath = await _liveService.exportLiveDiagnosticsFile();
    if (!mounted) return;
    var exportPath = logPath;
    var shareText = l10n.liveDiagnosticsShareText;
    var shareSubject = l10n.liveDiagnosticsShareSubject;
    if ((exportPath == null || exportPath.isEmpty) && _debugStatus != null) {
      exportPath = await _exportCurrentDebugSnapshot();
      shareText = l10n.liveDiagnosticsSnapshotShareText;
      shareSubject = l10n.liveDiagnosticsSnapshotShareSubject;
    }
    if (!mounted) return;
    setState(() {
      _exportingDiagnostics = false;
    });
    if (exportPath == null || exportPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.liveDiagnosticsNothingToExport,
          ),
        ),
      );
      return;
    }
    await Share.shareXFiles(
      [XFile(exportPath)],
      text: shareText,
      subject: shareSubject,
    );
  }

  Future<String?> _exportCurrentDebugSnapshot() async {
    final snapshot = _debugStatus;
    if (snapshot == null) {
      return null;
    }
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}mikcb-live-debug-snapshot-${DateTime.now().millisecondsSinceEpoch}.json',
    );
    final payload = <String, dynamic>{
      'exportedAtMillis': DateTime.now().millisecondsSinceEpoch,
      'source': 'live_testing_screen_snapshot',
      'debugStatus': snapshot,
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    return file.path;
  }

  Future<void> _clearLiveDiagnostics() async {
    if (_clearingDiagnostics) return;
    setState(() {
      _clearingDiagnostics = true;
    });
    final cleared = await _liveService.clearLiveDiagnostics();
    if (!mounted) return;
    setState(() {
      _clearingDiagnostics = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cleared
              ? AppLocalizations.of(context)!.liveDiagnosticsCleared
              : AppLocalizations.of(context)!.liveDiagnosticsClearFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summary = _debugSectionMap(_debugStatus?['summary']);
    final environment = _debugSectionMap(_debugStatus?['environment']);
    final service = _debugSectionMap(_debugStatus?['service']);
    final course = _debugSectionMap(_debugStatus?['course']);
    final timing = _debugSectionMap(_debugStatus?['timing']);
    final switches = _debugSectionMap(_debugStatus?['switches']);
    final display = _debugSectionMap(_debugStatus?['display']);
    final notification = _debugSectionMap(_debugStatus?['notification']);
    final recentDiagnostics = _debugSectionMap(
      _debugStatus?['recentDiagnostics'],
    );

    _debugL10nContext = context;
    final serviceRunning = summary['serviceRunning'] == true;
    final isActuallyPromotable = summary['isActuallyPromotable'] == true;
    final statusText = _debugValueText(summary['statusText']);
    final notIslandReason = _debugValueText(summary['notIslandReason']);
    final rawDebugJson = _debugStatus == null
        ? ''
        : JsonEncoder.withIndent('  ').convert(_debugStatus);
    final refreshedAt = _lastDebugStatusUpdatedAt;
    final refreshedAtText = refreshedAt == null
        ? l10n.liveTestingNotRefreshed
        : '${refreshedAt.hour.toString().padLeft(2, '0')}:${refreshedAt.minute.toString().padLeft(2, '0')}:${refreshedAt.second.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.liveTestingTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSectionCard(
            title: l10n.liveTestingNotificationTitle,
            subtitle: l10n.liveTestingNotificationSubtitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await _showTestOptions(context);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 300),
                    );
                    await _refreshDebugStatus(showLoading: true);
                  },
                  icon: const Icon(Icons.science_outlined),
                  label: Text(l10n.liveTestingSendAction),
                ),
                if (!kReleaseMode) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.liveTestingUmengHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _triggerUmengTestCrash(context),
                        icon: const Icon(Icons.warning_amber_rounded),
                        label: Text(l10n.liveTestingCrashAction),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _triggerUmengTestAnr(context),
                        icon: const Icon(Icons.hourglass_bottom_rounded),
                        label: Text(l10n.liveTestingAnrAction),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSectionCard(
            title: l10n.liveTestingIslandStatusTitle,
            subtitle: l10n.liveTestingIslandStatusSubtitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DebugStatusChip(
                      icon: serviceRunning
                          ? Icons.play_circle_outline_rounded
                          : Icons.stop_circle_outlined,
                      label: serviceRunning
                          ? l10n.liveTestingServiceStatusRunning
                          : l10n.liveTestingServiceStatusStopped,
                      color: serviceRunning
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    _DebugStatusChip(
                      icon: isActuallyPromotable
                          ? Icons.verified_outlined
                          : Icons.warning_amber_rounded,
                      label: statusText,
                      color: isActuallyPromotable
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.liveTestingNoIslandReasonTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  notIslandReason.isEmpty
                      ? l10n.liveTestingNoIslandReasonEmpty
                      : notIslandReason,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _loadingDebugStatus
                                ? null
                                : () => _refreshDebugStatus(showLoading: true),
                            icon: _loadingDebugStatus
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            label: Text(
                              _loadingDebugStatus
                                  ? l10n.liveTestingRefreshing
                                  : l10n.liveTestingRefreshAction,
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _exportingDiagnostics
                                ? null
                                : _exportLiveDiagnostics,
                            icon: _exportingDiagnostics
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.ios_share_rounded),
                            label: Text(
                              _exportingDiagnostics
                                  ? l10n.liveTestingExporting
                                  : l10n.liveTestingExportAction,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _autoRefreshEnabled,
                        onChanged: (value) {
                          setState(() {
                            _autoRefreshEnabled = value;
                          });
                        },
                        title: Text(l10n.liveTestingAutoRefreshTitle),
                        subtitle: Text(
                          _autoRefreshEnabled
                              ? l10n.liveTestingAutoRefreshOn(
                                  _autoRefreshInterval.inSeconds,
                                )
                              : l10n.liveTestingAutoRefreshOff,
                        ),
                      ),
                      Text(
                        l10n.liveTestingRefreshedAt(refreshedAtText),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_debugStatus != null) ...[
            _DebugSectionCard(
              title: l10n.liveTestingSectionEnvironment,
              data: environment,
            ),
            const SizedBox(height: 16),
            _DebugSectionCard(
              title: l10n.liveTestingSectionService,
              data: service,
            ),
            const SizedBox(height: 16),
            _DebugSectionCard(
              title: l10n.liveTestingSectionCourse,
              data: course,
            ),
            const SizedBox(height: 16),
            _DebugSectionCard(
              title: l10n.liveTestingSectionTiming,
              data: timing,
            ),
            const SizedBox(height: 16),
            _DebugSectionCard(
              title: l10n.liveTestingSectionSwitches,
              data: switches,
            ),
            const SizedBox(height: 16),
            _DebugSectionCard(
              title: l10n.liveTestingSectionDisplay,
              data: display,
            ),
            const SizedBox(height: 16),
            _DebugSectionCard(
              title: l10n.liveTestingSectionNotification,
              data: notification,
            ),
            const SizedBox(height: 16),
            _DebugSectionCard(
              title: l10n.liveTestingSectionRecentLogs,
              data: recentDiagnostics,
            ),
            const SizedBox(height: 16),
            _SettingsSectionCard(
              title: l10n.liveTestingRawDataTitle,
              subtitle: l10n.liveTestingRawDataSubtitle,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                title: Text(l10n.liveTestingExpandRawJson),
                subtitle: Text(l10n.liveTestingExpandRawJsonSubtitle),
                children: [
                  SelectableText(
                    rawDebugJson,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _SettingsSectionCard(
            title: l10n.liveTestingLocalLogsTitle,
            subtitle: l10n.liveTestingLocalLogsSubtitle,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _clearingDiagnostics
                      ? null
                      : _clearLiveDiagnostics,
                  icon: _clearingDiagnostics
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    _clearingDiagnostics
                        ? l10n.liveTestingClearingLogs
                        : l10n.liveTestingClearLogsAction,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _openLiveDiagnosticsViewer,
                  icon: const Icon(Icons.article_outlined),
                  label: Text(l10n.liveTestingViewPhoneLogsAction),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                  icon: const Icon(Icons.info_outline_rounded),
                  label: Text(l10n.liveTestingMoreTesterOptionsAction),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

BuildContext? _debugL10nContext;

Map<String, dynamic> _debugSectionMap(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

String _debugValueText(dynamic value) {
  if (value == null) return '';
  if (value is bool) {
    return value
        ? AppLocalizations.of(_debugL10nContext!)!.yesLabel
        : AppLocalizations.of(_debugL10nContext!)!.noLabel;
  }
  return value.toString();
}

class _DebugStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DebugStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugSectionCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;

  const _DebugSectionCard({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionCard(
      title: title,
      subtitle: AppLocalizations.of(
        context,
      )!.liveTestingCurrentNativeFieldsSubtitle,
      child: Column(
        children: data.entries
            .map(
              (entry) => _DebugValueRow(
                label: entry.key,
                value: _debugValueText(entry.value).isEmpty
                    ? '-'
                    : _debugValueText(entry.value),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DebugValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _DebugValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 144,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _triggerUmengTestCrash(BuildContext context) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context)!.liveTestingCrashSoon)),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await UmengAnalyticsService.triggerTestCrash();
}

Future<void> _triggerUmengTestAnr(BuildContext context) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(AppLocalizations.of(context)!.liveTestingAnrSoon),
      duration: Duration(seconds: 4),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await UmengAnalyticsService.triggerTestAnr();
}

Future<void> _showTestOptions(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  const beforeClassLead = Duration(seconds: 8);
  const totalCourseDuration = Duration(minutes: 3);

  String formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  final provider = context.read<TimetableProvider>();
  await provider.initialize();
  final liveService = MiuiLiveActivitiesService();
  await liveService.initialize();
  await liveService.recordDiagnosticEvent(
    'live_update_test_requested',
    'User requested manual live island test notification',
    extras: {'from': 'settings_screen', 'currentWeek': provider.currentWeek},
  );

  final selection = provider.getTestLiveActivityCourseSelection(now: now);
  if (selection == null) {
    await liveService.recordDiagnosticEvent(
      'live_update_test_no_selection',
      'Manual live island test found no eligible course',
      extras: {'weekday': now.weekday},
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.liveTestingNoCourseAvailable,
        ),
      ),
    );
    return;
  }
  final settings = provider.settings;
  final displaySettings = settings.beforeClassDisplaySettings;
  final start = now.add(beforeClassLead);
  final end = start.add(totalCourseDuration);

  final baseCourse = selection.currentCourse;
  final previewNextCourse = selection.nextCourse;
  final resolvedShortName = provider.resolveCourseShortName(baseCourse);
  await liveService.recordDiagnosticEvent(
    'live_update_test_selection_ready',
    'Manual live island test resolved target course',
    extras: {
      'courseName': baseCourse.name,
      'stage': selection.stage.name,
      'hasNextCourse': previewNextCourse != null,
    },
  );

  final testCourse = Course(
    id: 'test_auto_id',
    name: baseCourse.name,
    shortName: resolvedShortName,
    teacher: baseCourse.teacher,
    location: baseCourse.location,
    dayOfWeek: now.weekday,
    startSection: baseCourse.startSection,
    endSection: baseCourse.endSection,
    startWeek: baseCourse.startWeek,
    endWeek: baseCourse.endWeek,
    startTime: formatTime(start),
    endTime: formatTime(end),
    color: baseCourse.color,
    note: l10n.liveTestingTestCourseNote,
  );

  if (!context.mounted) return;

  try {
    provider.suspendLiveActivitySyncFor(
      end.difference(now) + const Duration(seconds: 20),
    );
    await liveService.recordDiagnosticEvent(
      'live_update_test_suspend_sync',
      'Temporarily suspended scheduled live update sync for manual test',
      extras: {
        'untilMillis': end
            .add(const Duration(seconds: 20))
            .millisecondsSinceEpoch,
      },
    );
    await liveService.stopLiveUpdate();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final progressMilestones = provider.buildLiveProgressMilestones(
      baseCourse,
      startAtMillis: start.millisecondsSinceEpoch,
      endAtMillis: end.millisecondsSinceEpoch,
    );
    final progressBreakOffsetsMillis = provider
        .buildLiveProgressBreakOffsetsMillis(
          baseCourse,
          startAtMillis: start.millisecondsSinceEpoch,
          endAtMillis: end.millisecondsSinceEpoch,
        );
    await liveService.recordDiagnosticEvent(
      'live_update_test_starting',
      'Manual live island test is starting native live update',
      extras: {
        'courseName': testCourse.name,
        'startAtMillis': start.millisecondsSinceEpoch,
        'endAtMillis': end.millisecondsSinceEpoch,
        'milestoneCount': progressMilestones.length,
      },
    );
    await liveService.startLiveUpdate(
      testCourse,
      previewNextCourse,
      stage: LiveActivityStage.beforeClass.name,
      beforeClassLeadMillis: beforeClassLead.inMilliseconds,
      startAtMillis: start.millisecondsSinceEpoch,
      endAtMillis: end.millisecondsSinceEpoch,
      endReminderLeadMillis: 0,
      endSecondsCountdownThreshold: settings.liveEndSecondsCountdownThreshold,
      promoteDuringClass: settings.livePromoteDuringClass,
      showNotificationDuringClass: settings.liveShowDuringClassNotification,
      enableBeforeClass: true,
      enableDuringClass: false,
      enableBeforeEnd: false,
      showCountdown: displaySettings.showCountdown,
      countdownTextStyle: displaySettings.countdownTextStyle,
      showStageText: displaySettings.showStageText,
      showCourseNameInIsland: displaySettings.showCourseName,
      showLocationInIsland: displaySettings.showLocation,
      useShortNameInIsland: displaySettings.useShortName,
      hidePrefixText: displaySettings.hidePrefixText,
      duringClassTimeDisplayMode: displaySettings.duringClassTimeDisplayMode,
      enableMiuiIslandLabelImage: displaySettings.enableMiuiIslandLabelImage,
      miuiIslandLabelStyle: displaySettings.miuiIslandLabelStyle,
      miuiIslandLabelContent: displaySettings.miuiIslandLabelContent,
      miuiIslandLabelFontColor: displaySettings.miuiIslandLabelFontColor,
      miuiIslandLabelFontWeight: displaySettings.miuiIslandLabelFontWeight,
      miuiIslandLabelRenderQuality:
          displaySettings.miuiIslandLabelRenderQuality,
      miuiIslandLabelFontSize: displaySettings.miuiIslandLabelFontSize,
      miuiIslandLabelOffsetX: displaySettings.miuiIslandLabelOffsetX,
      miuiIslandLabelOffsetY: displaySettings.miuiIslandLabelOffsetY,
      miuiIslandLabelLogoPath: displaySettings.miuiIslandLabelLogoPath,
      miuiIslandLabelLogoCornerRadius:
          displaySettings.miuiIslandLabelLogoCornerRadius,
      miuiIslandExpandedIconMode: displaySettings.miuiIslandExpandedIconMode,
      miuiIslandExpandedIconPath: displaySettings.miuiIslandExpandedIconPath,
      beforeClassQuickAction: settings.liveBeforeClassQuickAction,
      progressBreakOffsetsMillis: progressBreakOffsetsMillis,
      progressMilestoneLabels: progressMilestones
          .map((milestone) => milestone['label'] as String)
          .toList(),
      progressMilestoneTimeTexts: progressMilestones
          .map((milestone) => milestone['timeText'] as String)
          .toList(),
    );
    await liveService.recordDiagnosticEvent(
      'live_update_test_started',
      'Manual live island test successfully requested native live update',
      extras: {
        'courseName': testCourse.name,
        'stage': LiveActivityStage.beforeClass.name,
      },
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.liveTestingNotificationSent,
        ),
      ),
    );
  } catch (e, stackTrace) {
    await UmengAnalyticsService.reportDiagnostic(
      'live_update_test_failed',
      'Manual live island test failed before native island appeared',
      error: e,
      stackTrace: stackTrace,
      dedupeKey: 'live_update_test_failed',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.sendFailedWithError('$e')),
      ),
    );
  }
}

class _LayoutSettingsScreen extends StatefulWidget {
  const _LayoutSettingsScreen();

  @override
  State<_LayoutSettingsScreen> createState() => _LayoutSettingsScreenState();
}

class _HomeWidgetSettingsScreen extends StatefulWidget {
  const _HomeWidgetSettingsScreen();

  @override
  State<_HomeWidgetSettingsScreen> createState() =>
      _HomeWidgetSettingsScreenState();
}

class _HomeWidgetSettingsScreenState extends State<_HomeWidgetSettingsScreen> {
  static const double _defaultWidgetHeightAdjustment = -11;
  static const double _defaultWidgetCornerRadius = 22;

  final HomeWidgetService _homeWidgetService = HomeWidgetService();
  late TimetableSettings _draft;
  Timer? _autoSaveTimer;
  bool _isPersisting = false;
  bool _isCheckingPinSupport = true;
  bool _canRequestPinWidget = false;
  TimetableSettings? _pendingPersist;
  final Set<HomeWidgetPinTarget> _pinningTargets = <HomeWidgetPinTarget>{};

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
    _loadPinWidgetSupport();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeWidgetSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeWidgetTodayCourseTitle,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.homeWidgetTodayCourseSubtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.homeWidgetQuickAddTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isCheckingPinSupport
                        ? l10n.homeWidgetCheckingPinSupport
                        : (_canRequestPinWidget
                              ? l10n.homeWidgetPinSupported
                              : l10n.homeWidgetPinUnsupported),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildPinWidgetButton(HomeWidgetPinTarget.compact22),
                      _buildPinWidgetButton(HomeWidgetPinTarget.miniList22),
                      _buildPinWidgetButton(HomeWidgetPinTarget.medium24),
                      _buildPinWidgetButton(HomeWidgetPinTarget.large44),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<WidgetBackgroundStyle>(
                    initialValue: _draft.widgetBackgroundStyle,
                    decoration: InputDecoration(
                      labelText: l10n.homeWidgetBackgroundStyleLabel,
                      border: OutlineInputBorder(),
                    ),
                    items: WidgetBackgroundStyle.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              _widgetBackgroundStyleLabel(context, value),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _updateDraft(
                        _draft.copyWith(widgetBackgroundStyle: value),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.homeWidgetShowLocationTitle),
                    subtitle: Text(l10n.homeWidgetShowLocationSubtitle),
                    value: _draft.widgetShowLocation,
                    onChanged: (value) {
                      _updateDraft(_draft.copyWith(widgetShowLocation: value));
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.homeWidgetShowCountdownTitle),
                    subtitle: Text(l10n.homeWidgetShowCountdownSubtitle),
                    value: _draft.widgetShowCountdown,
                    onChanged: (value) {
                      _updateDraft(_draft.copyWith(widgetShowCountdown: value));
                    },
                  ),
                  if (_draft.widgetShowCountdown) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.homeWidgetCountdownLeadTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.homeWidgetCountdownLeadSubtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _draft.widgetCountdownLeadMinutes,
                      items: [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(l10n.homeWidgetCountdownLeadAlways),
                        ),
                        for (final m in const [1, 5, 10, 15, 20, 30, 40, 50, 60])
                          DropdownMenuItem(
                            value: m,
                            child: Text(l10n.homeWidgetCountdownLeadMinutes('$m')),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _updateDraft(
                            _draft.copyWith(widgetCountdownLeadMinutes: value),
                          );
                        }
                      },
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.homeWidgetHideCompletedTitle),
                    subtitle: Text(l10n.homeWidgetHideCompletedSubtitle),
                    value: _draft.widgetHideCompletedCourses,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(widgetHideCompletedCourses: value),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.homeWidgetHeightAdjustTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _draft.widgetHeightAdjustment ==
                            _defaultWidgetHeightAdjustment
                        ? l10n.defaultLabel
                        : (_draft.widgetHeightAdjustment >
                                  _defaultWidgetHeightAdjustment
                              ? l10n.higherByValue(
                                  (_draft.widgetHeightAdjustment -
                                          _defaultWidgetHeightAdjustment)
                                      .toStringAsFixed(0),
                                )
                              : l10n.lowerByValue(
                                  (_defaultWidgetHeightAdjustment -
                                          _draft.widgetHeightAdjustment)
                                      .toStringAsFixed(0),
                                )),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Slider(
                    value:
                        (_draft.widgetHeightAdjustment -
                                _defaultWidgetHeightAdjustment)
                            .clamp(-16, 16)
                            .toDouble(),
                    min: -16,
                    max: 16,
                    divisions: 32,
                    label: _draft.widgetHeightAdjustment.toStringAsFixed(0),
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          widgetHeightAdjustment:
                              _defaultWidgetHeightAdjustment + value,
                        ),
                        debounce: true,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.homeWidgetCornerRadiusTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_draft.widgetCornerRadius.toStringAsFixed(0)}dp',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Slider(
                    value:
                        (_draft.widgetCornerRadius - _defaultWidgetCornerRadius)
                            .clamp(-14, 14)
                            .toDouble(),
                    min: -14,
                    max: 14,
                    divisions: 28,
                    label: _draft.widgetCornerRadius.toStringAsFixed(0),
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(
                          widgetCornerRadius:
                              _defaultWidgetCornerRadius + value,
                        ),
                        debounce: true,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeWidgetDescriptionTitle,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.homeWidgetDescriptionText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() {
      _draft = next;
    });
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
    _pendingPersist = next;
    if (_isPersisting) {
      return;
    }
    _drainPersistQueue();
  }

  Future<void> _drainPersistQueue() async {
    _isPersisting = true;
    try {
      while (_pendingPersist != null) {
        final next = _pendingPersist!;
        _pendingPersist = null;
        await _persistDraft(next);
      }
    } finally {
      _isPersisting = false;
    }
  }

  Future<void> _persistDraft(TimetableSettings next) async {
    final provider = context.read<TimetableProvider>();
    final message = await provider.updateTimetableSettings(next);
    if (!mounted) {
      return;
    }
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _draft = provider.settings;
      });
      return;
    }
  }

  Future<void> _loadPinWidgetSupport() async {
    final supported = await _homeWidgetService.canRequestPinWidget();
    if (!mounted) {
      return;
    }
    setState(() {
      _canRequestPinWidget = supported;
      _isCheckingPinSupport = false;
    });
  }

  Widget _buildPinWidgetButton(HomeWidgetPinTarget target) {
    final isLoading = _pinningTargets.contains(target);
    return OutlinedButton.icon(
      onPressed: isLoading ? null : () => _requestPinWidget(target),
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_box_outlined),
      label: Text(_homeWidgetTargetLabel(context, target)),
    );
  }

  Future<void> _requestPinWidget(HomeWidgetPinTarget target) async {
    setState(() {
      _pinningTargets.add(target);
    });
    final result = await _homeWidgetService.requestPinWidget(target);
    if (!mounted) {
      return;
    }
    setState(() {
      _pinningTargets.remove(target);
    });

    final message = switch (result) {
      HomeWidgetPinRequestResult.requested => AppLocalizations.of(
        context,
      )!.homeWidgetPinRequested(_homeWidgetTargetLabel(context, target)),
      HomeWidgetPinRequestResult.unsupported =>
        AppLocalizations.of(context)!.homeWidgetPinUnsupportedManual(
          _homeWidgetTargetLabel(context, target),
        ),
      HomeWidgetPinRequestResult.invalidWidgetType => AppLocalizations.of(
        context,
      )!.homeWidgetInvalidType,
      HomeWidgetPinRequestResult.failed => AppLocalizations.of(
        context,
      )!.homeWidgetPinFailedManual(_homeWidgetTargetLabel(context, target)),
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LayoutSettingsScreenState extends State<_LayoutSettingsScreen> {
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
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.layoutSettingsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildLayoutPreviewCard(provider),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.layoutDensityTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.layoutAutoFitHeightTitle),
                          subtitle: Text(l10n.layoutAutoFitHeightSubtitle),
                          value: _draft.timetableAutoFitSectionHeight,
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(
                                timetableAutoFitSectionHeight: value,
                              ),
                            );
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.layoutHideWeekendsTitle),
                          subtitle: Text(l10n.layoutHideWeekendsSubtitle),
                          value: _draft.timetableHideWeekends,
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(timetableHideWeekends: value),
                            );
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.layoutEnableHapticsTitle),
                          subtitle: Text(l10n.layoutEnableHapticsSubtitle),
                          value: _draft.enableHaptics,
                          onChanged: (value) {
                            _updateDraft(_draft.copyWith(enableHaptics: value));
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<SectionTimeDisplayMode>(
                          initialValue: _draft.timetableSectionTimeDisplayMode,
                          decoration: InputDecoration(
                            labelText: l10n.layoutTimeColumnDisplayLabel,
                            border: OutlineInputBorder(),
                          ),
                          items: SectionTimeDisplayMode.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            _updateDraft(
                              _draft.copyWith(
                                timetableSectionTimeDisplayMode: value,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<TimetableTimeColumnWidthMode>(
                          initialValue: _draft.timetableTimeColumnWidthMode,
                          decoration: InputDecoration(
                            labelText: l10n.layoutTimeColumnWidthLabel,
                            border: OutlineInputBorder(),
                          ),
                          items: TimetableTimeColumnWidthMode.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            _updateDraft(
                              _draft.copyWith(
                                timetableTimeColumnWidthMode: value,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<BackToCurrentWeekButtonStyle>(
                          initialValue:
                              _draft.timetableBackToCurrentWeekButtonStyle,
                          decoration: InputDecoration(
                            labelText:
                                l10n.layoutBackToCurrentWeekButtonStyleLabel,
                            helperText:
                                l10n.layoutBackToCurrentWeekButtonStyleHelper,
                            border: const OutlineInputBorder(),
                          ),
                          items: BackToCurrentWeekButtonStyle.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                    _backToCurrentWeekButtonStyleLabel(
                                      l10n,
                                      value,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            _updateDraft(
                              _draft.copyWith(
                                timetableBackToCurrentWeekButtonStyle: value,
                              ),
                            );
                          },
                        ),
                        if (_draft.timetableBackToCurrentWeekButtonStyle ==
                            BackToCurrentWeekButtonStyle.floating) ...[
                          const SizedBox(height: 16),
                          Text(
                            l10n.layoutBackToCurrentWeekButtonOpacityLabel(
                              (_draft.timetableFloatingBackToCurrentWeekButtonOpacity *
                                      100)
                                  .round(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.layoutBackToCurrentWeekButtonOpacitySubtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Slider(
                            value: _draft
                                .timetableFloatingBackToCurrentWeekButtonOpacity,
                            min: 0.55,
                            max: 1.0,
                            divisions: 9,
                            label:
                                '${(_draft.timetableFloatingBackToCurrentWeekButtonOpacity * 100).round()}%',
                            onChanged: (value) {
                              _updateDraft(
                                _draft.copyWith(
                                  timetableFloatingBackToCurrentWeekButtonOpacity:
                                      value,
                                ),
                                debounce: true,
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          l10n.layoutCourseCardGapLabel(
                            _draft.timetableCourseCardGap.toStringAsFixed(1),
                          ),
                        ),
                        Slider(
                          value: _draft.timetableCourseCardGap.clamp(0.0, 3.0),
                          min: 0,
                          max: 3,
                          divisions: 12,
                          label: _draft.timetableCourseCardGap.toStringAsFixed(
                            1,
                          ),
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(timetableCourseCardGap: value),
                              debounce: true,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.layoutSectionHeightLabel(
                            _draft.sectionHeight.toStringAsFixed(0),
                          ),
                        ),
                        Slider(
                          value: _draft.sectionHeight,
                          min: 48,
                          max: 92,
                          divisions: 11,
                          label: _draft.sectionHeight.toStringAsFixed(0),
                          onChanged: _draft.timetableAutoFitSectionHeight
                              ? null
                              : (value) {
                                  _updateDraft(
                                    _draft.copyWith(sectionHeight: value),
                                    debounce: true,
                                  );
                                },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.layoutCompactFontSizeLabel(
                            _draft.compactFontSize.toStringAsFixed(1),
                          ),
                        ),
                        Slider(
                          value: _draft.compactFontSize,
                          min: 7,
                          max: 12,
                          divisions: 10,
                          label: _draft.compactFontSize.toStringAsFixed(1),
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(compactFontSize: value),
                              debounce: true,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.layoutCourseCardFontSizeLabel(
                            _draft.courseCardFontSize.toStringAsFixed(1),
                          ),
                        ),
                        Slider(
                          value: _draft.courseCardFontSize,
                          min: 7,
                          max: 12,
                          divisions: 10,
                          label: _draft.courseCardFontSize.toStringAsFixed(1),
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(courseCardFontSize: value),
                              debounce: true,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.layoutCourseCardDisplayTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.layoutCourseCardDisplaySubtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.showCourseNameTitle),
                          value: _draft.courseCardShowName,
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(courseCardShowName: value),
                            );
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.layoutShowTeacherTitle),
                          value: _draft.courseCardShowTeacher,
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(courseCardShowTeacher: value),
                            );
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.layoutShowClassroomTitle),
                          value: _draft.courseCardShowLocation,
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(courseCardShowLocation: value),
                            );
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.layoutShowTimeTitle),
                          value: _draft.courseCardShowTime,
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(courseCardShowTime: value),
                            );
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.layoutShowTimeLabelsTitle),
                          subtitle: Text(l10n.layoutShowTimeLabelsSubtitle),
                          value: _draft.courseCardShowTimeLabels,
                          onChanged: _draft.courseCardShowTime
                              ? (value) {
                                  _updateDraft(
                                    _draft.copyWith(
                                      courseCardShowTimeLabels: value,
                                    ),
                                  );
                                }
                              : null,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.layoutShowWeeksTitle),
                          subtitle: Text(l10n.layoutShowWeeksSubtitle),
                          value: _draft.courseCardShowWeeks,
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(courseCardShowWeeks: value),
                            );
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.layoutShowDescriptionTitle),
                          subtitle: Text(l10n.layoutShowDescriptionSubtitle),
                          value: _draft.courseCardShowDescription,
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(courseCardShowDescription: value),
                            );
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.layoutShowOtherWeeksTitle),
                          subtitle: Text(l10n.layoutShowOtherWeeksSubtitle),
                          value: _draft.timetableShowNonCurrentWeekCourses,
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(
                                timetableShowNonCurrentWeekCourses: value,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<CourseCardVerticalAlign>(
                          initialValue: _draft.courseCardVerticalAlign,
                          decoration: InputDecoration(
                            labelText: l10n.layoutVerticalAlignLabel,
                            border: OutlineInputBorder(),
                          ),
                          items: CourseCardVerticalAlign.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            _updateDraft(
                              _draft.copyWith(courseCardVerticalAlign: value),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<CourseCardHorizontalAlign>(
                          initialValue: _draft.courseCardHorizontalAlign,
                          decoration: InputDecoration(
                            labelText: l10n.layoutHorizontalAlignLabel,
                            border: OutlineInputBorder(),
                          ),
                          items: CourseCardHorizontalAlign.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            _updateDraft(
                              _draft.copyWith(courseCardHorizontalAlign: value),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: SwitchListTile(
                    title: Text(l10n.layoutShowConflictBadgeTitle),
                    subtitle: Text(l10n.layoutShowConflictBadgeSubtitle),
                    value: _draft.showConflictBadgeOnTimetable,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(showConflictBadgeOnTimetable: value),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.layoutConflictOpacityLabel(
                            (_draft.timetableConflictCourseOpacity * 100)
                                .round(),
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.layoutConflictOpacitySubtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: _draft.timetableConflictCourseOpacity,
                          min: 0.2,
                          max: 1.0,
                          divisions: 16,
                          label:
                              '${(_draft.timetableConflictCourseOpacity * 100).round()}%',
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(
                                timetableConflictCourseOpacity: value,
                              ),
                              debounce: true,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.homeWidgetDescriptionTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.layoutTipsText,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutPreviewCard(TimetableProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final preview = _buildLayoutPreviewData(provider);
    final colorScheme = Theme.of(context).colorScheme;
    final sections = provider.settings.sections
        .skip(preview.baseSection - 1)
        .take(4)
        .toList();
    final timeColumnWidth =
        _draft.timetableTimeColumnWidthMode ==
            TimetableTimeColumnWidthMode.narrow
        ? 34.0
        : 40.0;
    final cardInset = _draft.timetableCourseCardGap.clamp(0.0, 3.0);
    final sectionHeight = _draft.sectionHeight;
    final gridHeight = sections.length * sectionHeight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dayWidth =
              (constraints.maxWidth - timeColumnWidth) /
              preview.dayTitles.length;
          final showsFloatingButton =
              _draft.timetableBackToCurrentWeekButtonStyle ==
              BackToCurrentWeekButtonStyle.floating;
          return Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 50,
                    padding: const EdgeInsets.fromLTRB(0, 1, 0, 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: timeColumnWidth,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n.currentWeekCompact(provider.currentWeek),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              if (!showsFloatingButton)
                                Text(
                                  l10n.backToCurrentWeekAction,
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (
                          var dayIndex = 0;
                          dayIndex < preview.dayTitles.length;
                          dayIndex++
                        )
                          SizedBox(
                            width: dayWidth,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  preview.dayTitles[dayIndex],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight:
                                        preview.visibleDayNumbers[dayIndex] ==
                                            DateTime.now().weekday
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color:
                                        preview.visibleDayNumbers[dayIndex] ==
                                            DateTime.now().weekday
                                        ? colorScheme.primary
                                        : colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatPreviewDate(
                                    _previewDateForWeekDay(
                                      _draft,
                                      provider.currentWeek,
                                      preview.visibleDayNumbers[dayIndex],
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    color:
                                        preview.visibleDayNumbers[dayIndex] ==
                                            DateTime.now().weekday
                                        ? colorScheme.primary.withValues(
                                            alpha: 0.78,
                                          )
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: gridHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: timeColumnWidth,
                          child: Column(
                            children: [
                              for (var i = 0; i < sections.length; i++)
                                Container(
                                  height: sectionHeight,
                                  alignment: Alignment.center,
                                  child: _buildPreviewSectionTimeCell(
                                    preview.baseSection + i,
                                    sections[i],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (
                          var dayIndex = 0;
                          dayIndex < preview.dayTitles.length;
                          dayIndex++
                        )
                          SizedBox(
                            width: dayWidth,
                            child: Container(
                              height: gridHeight,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLowest
                                    .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                clipBehavior: Clip.antiAlias,
                                children: [
                                  for (final placement
                                      in preview.placements.where(
                                        (item) => item.dayIndex == dayIndex,
                                      ))
                                    Positioned(
                                      top:
                                          (placement.startSlot - 1) *
                                          sectionHeight,
                                      left: 0,
                                      right: 0,
                                      height:
                                          placement.slotSpan * sectionHeight,
                                      child: CourseCard(
                                        course: placement.course,
                                        isCompact: true,
                                        showName: _draft.courseCardShowName,
                                        showTeacher:
                                            _draft.courseCardShowTeacher,
                                        showLocation:
                                            _draft.courseCardShowLocation,
                                        showTime: _draft.courseCardShowTime,
                                        showTimeLabels:
                                            _draft.courseCardShowTimeLabels,
                                        showWeeks: _draft.courseCardShowWeeks,
                                        showDescription:
                                            _draft.courseCardShowDescription,
                                        verticalAlign:
                                            _draft.courseCardVerticalAlign,
                                        horizontalAlign:
                                            _draft.courseCardHorizontalAlign,
                                        compactTitleFontSize:
                                            _draft.courseCardFontSize,
                                        compactSubtitleFontSize:
                                            (_draft.courseCardFontSize - 1)
                                                .clamp(7.0, 14.0),
                                        compactVerticalPadding: 4,
                                        compactOuterInset: cardInset,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showsFloatingButton)
                Positioned(
                  right: 16,
                  bottom: 18,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh.withValues(
                          alpha: _draft
                              .timetableFloatingBackToCurrentWeekButtonOpacity,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 13,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            l10n.backToCurrentWeekAction,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _backToCurrentWeekButtonStyleLabel(
    AppLocalizations l10n,
    BackToCurrentWeekButtonStyle style,
  ) {
    return switch (style) {
      BackToCurrentWeekButtonStyle.inline =>
        l10n.layoutBackToCurrentWeekButtonStyleInline,
      BackToCurrentWeekButtonStyle.floating =>
        l10n.layoutBackToCurrentWeekButtonStyleFloating,
    };
  }

  _LayoutPreviewData _buildLayoutPreviewData(TimetableProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final weekDays = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];
    final currentWeek = provider.currentWeek;
    final visibleDays = _draft.timetableHideWeekends
        ? const [1, 2, 3, 4, 5]
        : const [1, 2, 3, 4, 5, 6, 7];
    final currentWeekCourses =
        provider.courses
            .where(
              (course) =>
                  course.isInWeek(currentWeek) &&
                  visibleDays.contains(course.dayOfWeek),
            )
            .toList()
          ..sort((left, right) {
            final dayCompare = left.dayOfWeek.compareTo(right.dayOfWeek);
            if (dayCompare != 0) {
              return dayCompare;
            }
            final sectionCompare = left.startSection.compareTo(
              right.startSection,
            );
            if (sectionCompare != 0) {
              return sectionCompare;
            }
            return left.id.compareTo(right.id);
          });

    final dayTitles = visibleDays
        .map((dayOfWeek) => weekDays[dayOfWeek - 1])
        .toList(growable: false);

    if (currentWeekCourses.isNotEmpty) {
      final baseSection = currentWeekCourses
          .map((course) => course.startSection)
          .reduce((left, right) => left < right ? left : right)
          .clamp(1, (provider.settings.sectionCount - 3).clamp(1, 999));
      final endSection = baseSection + 3;
      final placements = <_PreviewPlacement>[];
      for (final course in currentWeekCourses) {
        if (course.endSection < baseSection ||
            course.startSection > endSection) {
          continue;
        }
        final visibleStartSection = course.startSection < baseSection
            ? baseSection
            : course.startSection;
        final visibleEndSection = course.endSection > endSection
            ? endSection
            : course.endSection;
        final relativeStart = visibleStartSection - baseSection + 1;
        final relativeEnd = visibleEndSection - baseSection + 1;
        placements.add(
          _PreviewPlacement(
            dayIndex: visibleDays.indexOf(course.dayOfWeek),
            startSlot: relativeStart,
            slotSpan: relativeEnd - relativeStart + 1,
            course: course.copyWith(
              startSection: relativeStart,
              endSection: relativeEnd,
            ),
          ),
        );
      }
      return _LayoutPreviewData(
        usesRealCourses: true,
        baseSection: baseSection,
        visibleDayNumbers: visibleDays,
        dayTitles: dayTitles,
        placements: placements,
      );
    }

    final samples = [
      Course(
        id: 'layout-preview-1',
        name: l10n.sampleCourseAdvancedMath,
        shortName: l10n.sampleCourseAdvancedMath,
        teacher: l10n.sampleTeacherZhang,
        location: 'A101',
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        endTime: '09:40',
        color: '#2563EB',
      ),
      Course(
        id: 'layout-preview-2',
        name: l10n.sampleCourseEnglish,
        shortName: l10n.sampleCourseEnglish,
        teacher: l10n.sampleTeacherLi,
        location: 'B203',
        dayOfWeek: 2,
        startSection: 2,
        endSection: 3,
        startTime: '08:55',
        endTime: '10:45',
        color: '#10B981',
      ),
    ];

    return _LayoutPreviewData(
      usesRealCourses: false,
      baseSection: 1,
      visibleDayNumbers: visibleDays,
      dayTitles: dayTitles,
      placements: [
        _PreviewPlacement(
          dayIndex: 0,
          startSlot: 1,
          slotSpan: 2,
          course: samples[0],
        ),
        _PreviewPlacement(
          dayIndex: 1,
          startSlot: 2,
          slotSpan: 2,
          course: samples[1],
        ),
      ],
    );
  }

  DateTime? _previewDateForWeekDay(
    TimetableSettings settings,
    int week,
    int dayOfWeek,
  ) {
    final semesterStart = settings.semesterStartDate;
    if (semesterStart == null) {
      return null;
    }

    final normalizedStart = DateTime(
      semesterStart.year,
      semesterStart.month,
      semesterStart.day,
    ).subtract(Duration(days: semesterStart.weekday - 1));

    return normalizedStart.add(Duration(days: (week - 1) * 7 + dayOfWeek - 1));
  }

  String _formatPreviewDate(DateTime? date) {
    if (date == null) {
      return '';
    }
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildPreviewSectionTimeCell(int sectionNumber, SectionTime section) {
    final compactTextStyle = TextStyle(
      fontSize: (_draft.compactFontSize - 2).clamp(6.0, 10.0),
      color: Colors.grey.shade600,
      height: 1.05,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$sectionNumber',
          style: TextStyle(
            fontSize: _draft.compactFontSize.clamp(8.0, 11.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_draft.timetableSectionTimeDisplayMode !=
            SectionTimeDisplayMode.hidden)
          Text(section.startTime, style: compactTextStyle),
        if (_draft.timetableSectionTimeDisplayMode ==
            SectionTimeDisplayMode.startAndEnd)
          Text(section.endTime, style: compactTextStyle),
      ],
    );
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() {
      _draft = next;
    });
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
    final message = await provider.updateTimetableSettings(
      next.copyWith(
        activeTimeSchemeId: provider.settings.activeTimeSchemeId,
        sections: List<SectionTime>.from(provider.settings.sections),
      ),
    );
    if (!mounted) {
      return;
    }
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _draft = provider.settings;
      });
      return;
    }
  }
}

class _SettingsEntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsEntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return colorScheme.primary.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return colorScheme.primary.withValues(alpha: 0.04);
          }
          return Colors.transparent;
        }),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _LayoutPreviewData {
  final bool usesRealCourses;
  final int baseSection;
  final List<int> visibleDayNumbers;
  final List<String> dayTitles;
  final List<_PreviewPlacement> placements;

  const _LayoutPreviewData({
    required this.usesRealCourses,
    required this.baseSection,
    required this.visibleDayNumbers,
    required this.dayTitles,
    required this.placements,
  });
}

class _PreviewPlacement {
  final int dayIndex;
  final int startSlot;
  final int slotSpan;
  final Course course;

  const _PreviewPlacement({
    required this.dayIndex,
    required this.startSlot,
    required this.slotSpan,
    required this.course,
  });
}

class _SettingsSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SettingsSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
            ] else
              const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}

class _SelectableColorChip extends StatelessWidget {
  final String colorHex;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableColorChip({
    required this.colorHex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(colorHex);
    final outlineColor = selected
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).dividerColor.withValues(alpha: 0.72);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: outlineColor, width: selected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white)
            : null,
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;

  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

String _liveDisplaySummary(BuildContext context, LiveDisplaySettings settings) {
  final l10n = AppLocalizations.of(context)!;
  final parts = <String>[];
  if (settings.showCourseName) {
    parts.add(
      settings.useShortName
          ? l10n.liveDisplaySummaryShortName
          : l10n.liveDisplaySummaryCourseName,
    );
  }
  if (settings.showLocation) {
    parts.add(l10n.liveDisplaySummaryLocation);
  }
  if (settings.showCountdown) {
    parts.add(
      l10n.liveDisplaySummaryCountdown(settings.countdownTextStyle.label),
    );
  } else if (settings.showStageText) {
    parts.add(l10n.liveDisplaySummaryStageText);
  }
  if (settings.enableMiuiIslandLabelImage) {
    parts.add(l10n.liveDisplaySummaryLeftLabelImage);
  }
  if (parts.isEmpty) {
    return l10n.liveDisplaySummaryMinimal;
  }
  return parts.join(' / ');
}

Color _colorFromHex(String hexColor) {
  return parseHexColorOrFallback(hexColor, fallback: const Color(0xFF2563EB));
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
