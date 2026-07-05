import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/course.dart';
import '../models/holiday_entry.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../utils/locale_utils.dart';
import '../services/home_widget_service.dart';
import '../services/miui_live_activities_service.dart';
import '../services/umeng_analytics_service.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';
import '../widgets/semester_week_count_picker_sheet.dart';
import '../widgets/settings_section_widgets.dart';
import '../widgets/theme_manage_sheets.dart';
import '../widgets/timetable_week_preview.dart';
import '../services/bundled_assets.dart';
import '../widgets/bundled_asset_image.dart';
import 'about_screen.dart';
import 'data_transfer_screen.dart';
import 'lan_edit_screen.dart';
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

        void openHolidaySettings() {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/settings/holiday'),
              builder: (_) => const _HolidaySettingsScreen(),
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

        void openLanEdit() {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/settings/lan-edit'),
              builder: (_) => const LanEditScreen(),
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

        return FScaffold(
          header: FHeader.nested(
            prefixes: [
              FHeaderAction.back(onPress: () => Navigator.pop(context)),
            ],
            title: Text(l10n.settingsTitle),
          ),
          childPad: false,
          child: Material(
            type: MaterialType.transparency,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SemesterOverviewCard(
                  currentWeek: provider.currentWeek,
                  semesterWeekCount: settings.semesterWeekCount,
                  semesterStartDate: settings.semesterStartDate,
                ),
                const SizedBox(height: 12),
                FTileGroup(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    FTile(
                      prefix: const Icon(Icons.event_outlined),
                      title: Text(
                        settings.semesterStartDate == null
                            ? l10n.setSemesterStartDateAction
                            : l10n.semesterStartDateAction,
                      ),
                      details: settings.semesterStartDate == null
                          ? null
                          : Text(_formatDate(settings.semesterStartDate!)),
                      suffix: const Icon(Icons.chevron_right_rounded),
                      onPress: () => _pickSemesterStartDate(context),
                    ),
                    FTile(
                      prefix: const Icon(Icons.sync_outlined),
                      title: Text(l10n.syncCurrentWeekAction),
                      suffix: const Icon(Icons.chevron_right_rounded),
                      onPress: settings.semesterStartDate == null
                          ? null
                          : () => _syncCurrentWeek(context),
                    ),
                    FTile(
                      prefix: const Icon(Icons.view_week_outlined),
                      title: Text(l10n.selectSemesterWeekCountTitle),
                      details: Text(
                        l10n.semesterWeekCountAction(
                          settings.semesterWeekCount,
                        ),
                      ),
                      suffix: const Icon(Icons.chevron_right_rounded),
                      onPress: () => _pickSemesterWeekCount(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FTileGroup(
                  label: Text(l10n.dailyUsageSectionTitle),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SettingsEntryTile(
                      icon: Icons.palette_outlined,
                      title: l10n.appearanceEntryTitle,
                      trailing: _ColorDot(
                        color: _colorFromHex(settings.themeSeedColor),
                      ),
                      onTap: openAppearance,
                    ),
                    SettingsEntryTile(
                      icon: Icons.style_outlined,
                      title: l10n.themeManageTitle,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(
                              name: '/settings/theme',
                            ),
                            builder: (_) => const _ThemeManageScreen(),
                          ),
                        );
                      },
                    ),
                    SettingsEntryTile(
                      icon: Icons.view_week_outlined,
                      title: l10n.layoutSectionEntryTitle,
                      onTap: openLayoutSettings,
                    ),
                    SettingsEntryTile(
                      icon: Icons.widgets_outlined,
                      title: l10n.homeWidgetEntryTitle,
                      details: settings.widgetBackgroundStyle.label,
                      onTap: openHomeWidgetSettings,
                    ),
                    SettingsEntryTile(
                      icon: Icons.celebration_outlined,
                      title: l10n.holidaySettingsEntryTitle,
                      trailing: settings.enableHolidayMarking
                          ? Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: openHolidaySettings,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FTileGroup(
                  label: Text(l10n.reminderNotificationSectionTitle),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SettingsEntryTile(
                      icon: Icons.notifications_active_outlined,
                      title: l10n.liveSettingsTitle,
                      onTap: openLiveSettings,
                    ),
                    SettingsEntryTile(
                      icon: Icons.menu_book_outlined,
                      title: l10n.userGuideEntryTitle,
                      onTap: openUserGuide,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FTileGroup(
                  label: Text(l10n.timetableManagementSectionTitle),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SettingsEntryTile(
                      icon: Icons.layers_outlined,
                      title: l10n.timetableManagement,
                      onTap: openProfiles,
                    ),
                    SettingsEntryTile(
                      icon: Icons.schedule_rounded,
                      title: l10n.timeSchemeEntryTitle,
                      details: settings.activeTimeSchemeId == null
                          ? null
                          : provider.activeTimeScheme?.name,
                      onTap: () => _openTimeSchemeQuickSwitcher(context),
                    ),
                    SettingsEntryTile(
                      icon: Icons.swap_horiz_rounded,
                      title: l10n.dataTransferEntryTitle,
                      onTap: openDataTransfer,
                    ),
                    SettingsEntryTile(
                      icon: Icons.lan_rounded,
                      title: l10n.lanEditEntryTitle,
                      onTap: openLanEdit,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FTileGroup(
                  label: Text(l10n.aboutSupportSectionTitle),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SettingsEntryTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: l10n.feedbackEntryTitle,
                      onTap: openFeedback,
                    ),
                    SettingsEntryTile(
                      icon: Icons.info_outline_rounded,
                      title: l10n.aboutEntryTitle,
                      onTap: openAbout,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
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
    showAppToast(context, message: message);
  }

  Future<void> _syncCurrentWeek(BuildContext context) async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    await provider.syncCurrentWeekWithSemesterStart();
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.currentWeekBullet(provider.currentWeek),
      kind: AppToastKind.success,
    );
  }

  Future<void> _pickSemesterWeekCount(BuildContext context) async {
    final provider = context.read<TimetableProvider>();
    final currentWeekCount = provider.settings.semesterWeekCount;
    final selected = await showSemesterWeekCountPickerSheet(
      context,
      currentValue: currentWeekCount,
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
      showAppToast(context, message: message);
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

  const _SemesterOverviewCard({
    required this.currentWeek,
    required this.semesterWeekCount,
    required this.semesterStartDate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    return FCard.raw(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BundledAssetImage(
                assetPath: BundledAssets.launcherIcon,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.semesterOverviewCurrentWeek(
                      currentWeek,
                      semesterWeekCount,
                    ),
                    style: typo.sm.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    semesterStartDate == null
                        ? l10n.semesterStartUnset
                        : l10n.semesterStartSet(
                            _formatDate(semesterStartDate!),
                          ),
                    style: typo.xs.copyWith(color: colors.mutedForeground),
                  ),
                ],
              ),
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

    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(l10n.appearanceTitle),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FCard.raw(
              child: ColoredBox(
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer
                              .withValues(alpha: 0.82),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: l10n.displayModeTitle,
              subtitle: l10n.displayModeSubtitle,
              child: FSelect<AppThemeMode>(
                hint: l10n.themeModeLabel,
                items: {
                  for (final v in AppThemeMode.values)
                    _themeModeLabel(context, v): v,
                },
                control: FSelectControl.lifted(
                  value: _draft.appThemeMode,
                  onChange: (value) {
                    if (value == null) return;
                    _updateDraft(_draft.copyWith(appThemeMode: value));
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: l10n.fontSectionTitle,
              subtitle: l10n.fontSectionSubtitle,
              child: FSelect<AppFontMode>(
                hint: l10n.fontModeLabel,
                items: {
                  for (final v in AppFontMode.values)
                    _fontModeLabel(context, v): v,
                },
                control: FSelectControl.lifted(
                  value: _draft.appFontMode,
                  onChange: (value) {
                    if (value == null) return;
                    _updateDraft(_draft.copyWith(appFontMode: value));
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: l10n.languageSectionTitle,
              subtitle: l10n.languageSectionSubtitle,
              child: FSelect<String>(
                hint: l10n.languageModeLabel,
                items: buildLocaleMenuMap(context),
                control: FSelectControl.lifted(
                  value: normalizeLocaleTagForDropdown(_draft.appLocaleTag),
                  onChange: (value) {
                    if (value == null) return;
                    _updateDraft(_draft.copyWith(appLocaleTag: value));
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: l10n.homeTitleSectionTitle,
              subtitle: l10n.homeTitleSectionSubtitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FSelect<HomeTitleStyle>(
                    hint: l10n.homeTitleStyleLabel,
                    items: {
                      for (final v in HomeTitleStyle.values)
                        _homeTitleStyleLabel(context, v): v,
                    },
                    control: FSelectControl.lifted(
                      value: _draft.homeTitleStyle,
                      onChange: (value) {
                        if (value == null) return;
                        _updateDraft(_draft.copyWith(homeTitleStyle: value));
                      },
                    ),
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
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: l10n.themeSeedSectionTitle,
              subtitle: l10n.themeSeedSectionSubtitle,
              child: FSelect<ForuiTheme>(
                hint: l10n.themeSeedSectionTitle,
                items: {
                  for (final v in ForuiTheme.values) _foruiThemeLabel(v): v,
                },
                control: FSelectControl.lifted(
                  value: _draft.foruiTheme,
                  onChange: (value) {
                    if (value == null) return;
                    _updateDraft(
                      _draft.copyWith(
                        foruiTheme: value,
                        themeSeedColor: value.seedHex,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
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
                            _draft.copyWith(
                              timetablePageBackgroundColor: color,
                            ),
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            FCard.raw(
              child: Column(
                children: [
                  SettingSwitchTile(
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
                    const FDivider(),
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
      showAppToast(context, message: message);
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

String _foruiThemeLabel(ForuiTheme theme) {
  final name = theme.name;
  return name[0].toUpperCase() + name.substring(1);
}

Map<String, String> buildLocaleMenuMap(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final seen = <String>{''};
  final map = <String, String>{l10n.languageModeSystem: ''};
  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.countryCode?.isNotEmpty == true
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    if (!seen.add(tag)) {
      continue;
    }
    map[nativeNameFor(locale)] = tag;
  }
  return map;
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

class _ThemeManageScreen extends StatefulWidget {
  const _ThemeManageScreen();

  @override
  State<_ThemeManageScreen> createState() => _ThemeManageScreenState();
}

class _ThemeManageScreenState extends State<_ThemeManageScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(l10n.themeManageTitle),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 当前主题状态
            Consumer<TimetableProvider>(
              builder: (context, provider, child) {
                final settings = provider.settings;
                final checkpointName = settings.themeCheckpointName;
                final hasModifications = settings.hasThemeModifications;

                if (checkpointName == null) return const SizedBox.shrink();

                return SettingsSectionCard(
                  title: l10n.themeCurrentTheme,
                  subtitle: hasModifications
                      ? l10n.themeBasedOnModified(checkpointName)
                      : checkpointName,
                  plainTitle: true,
                  child: hasModifications
                      ? Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FButton(
                              variant: FButtonVariant.secondary,
                              onPress: () {
                                if (settings.themeCheckpointConfig != null) {
                                  _applyThemeWithUndo(
                                    context,
                                    settings.themeCheckpointConfig!,
                                    themeName: checkpointName,
                                  );
                                }
                              },
                              prefix: const Icon(
                                Icons.restart_alt_rounded,
                                size: 18,
                              ),
                              child: Text(l10n.themeResetToPreset),
                            ),
                            FButton(
                              variant: FButtonVariant.secondary,
                              onPress: () => _showSaveThemeDialog(context),
                              prefix: const Icon(Icons.save_outlined, size: 18),
                              child: Text(l10n.themeSaveCurrent),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
            const SizedBox(height: 12),
            // 导入导出 + 保存
            FTileGroup(
              label: Text(l10n.themeManageSubtitle),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                FTile(
                  prefix: const Icon(Icons.ios_share_outlined),
                  title: Text(l10n.themeExport),
                  onPress: () => _exportTheme(context),
                ),
                FTile(
                  prefix: const Icon(Icons.download_outlined),
                  title: Text(l10n.themeImport),
                  onPress: () => _importTheme(context),
                ),
                FTile(
                  prefix: const Icon(Icons.bookmark_add_outlined),
                  title: Text(l10n.themeSaveCurrent),
                  onPress: () => _showSaveThemeDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 统一主题列表（预设 + 保存/导入的）
            // 预设主题（forui 内置）
            Consumer<TimetableProvider>(
              builder: (context, provider, child) {
                final current = provider.settings.foruiTheme;
                return FTileGroup(
                  label: Text(l10n.themePreset),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final theme in ForuiTheme.values)
                      FTile(
                        prefix: _ColorDot(color: _colorFromHex(theme.seedHex)),
                        title: Text(_foruiThemeLabel(theme)),
                        suffix: current == theme
                            ? Icon(
                                Icons.check_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              )
                            : null,
                        onPress: () => _applyForuiTheme(context, theme),
                      ),
                  ],
                );
              },
            ),
            // 保存/导入的主题
            Consumer<TimetableProvider>(
              builder: (context, provider, child) {
                final savedThemes = provider.settings.savedThemes;
                if (savedThemes.isEmpty) return const SizedBox.shrink();
                final settings = provider.settings;
                final colorScheme = Theme.of(context).colorScheme;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    FTileGroup(
                      label: Text(l10n.themeSaved),
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final theme in savedThemes)
                          FTile(
                            prefix: _ColorDot(
                              color: _colorFromHex(savedThemeSeedHex(theme)),
                            ),
                            title: Text(theme.name),
                            subtitle: ThemePreviewDots(
                              colors: theme.config.previewColors,
                            ),
                            suffix: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSavedThemeSelected(settings, theme))
                                  Icon(
                                    Icons.check_rounded,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  icon: Icon(
                                    Icons.more_horiz_rounded,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  tooltip: l10n.themeMoreActions,
                                  onPressed: () =>
                                      _showSavedThemeActions(context, theme),
                                ),
                              ],
                            ),
                            onPress: () =>
                                _showSavedThemePreview(context, theme),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSavedThemePreview(BuildContext context, SavedTheme theme) {
    return showSavedThemePreviewSheet(
      context,
      name: theme.name,
      config: theme.config,
      onApply: () => _applySavedTheme(context, theme),
    );
  }

  Future<void> _showSavedThemeActions(BuildContext context, SavedTheme theme) {
    return showSavedThemeActionSheet(
      context,
      theme: theme,
      onRename: () => _showRenameDialog(context, theme),
      onDuplicate: () => _duplicateTheme(context, theme),
      onDelete: () => _deleteSavedTheme(context, theme),
    );
  }

  Future<bool> _applySavedTheme(BuildContext context, SavedTheme theme) async {
    final canApply = await confirmApplyThemeWithUnsavedCheck(
      context,
      onSaveRequested: () => _showSaveThemeDialog(context),
    );
    if (!canApply || !context.mounted) {
      return false;
    }
    _applyThemeWithUndo(context, theme.config, themeName: theme.name);
    return true;
  }

  Future<void> _deleteSavedTheme(BuildContext context, SavedTheme theme) async {
    final confirmed = await showThemeDeleteConfirmDialog(
      context,
      name: theme.name,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    context.read<TimetableProvider>().deleteTheme(theme.id);
  }

  void _applyThemeWithUndo(
    BuildContext context,
    ThemeConfig config, {
    String? themeName,
  }) {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    final newSettings = config.applyToSettings(provider.settings);
    provider.applyThemeWithUndo(
      newSettings.copyWith(
        themeCheckpointName: themeName,
        themeCheckpointConfig: config,
      ),
      themeName: themeName,
    );

    showThemeFeedbackToast(
      context,
      message: l10n.themeChanged(themeName ?? l10n.themeManageTitle),
      onUndo: provider.undoThemeChange,
    );
  }

  void _applyForuiTheme(BuildContext context, ForuiTheme theme) {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final name = _foruiThemeLabel(theme);
    provider.applyThemeWithUndo(
      provider.settings.copyWith(
        foruiTheme: theme,
        themeSeedColor: theme.seedHex,
        clearThemeCheckpoint: true,
      ),
      themeName: name,
    );
    showThemeFeedbackToast(
      context,
      message: l10n.themeChanged(name),
      onUndo: provider.undoThemeChange,
    );
  }

  void _showSaveThemeDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showThemeNameDialog(
      context,
      title: l10n.themeSaveCurrent,
      initialName: '',
      onSubmit: (name) {
        final provider = Provider.of<TimetableProvider>(context, listen: false);
        final themeConfig = ThemeConfig.fromSettings(provider.settings);
        provider.saveTheme(name, themeConfig.toJson());
      },
    );
  }

  void _showRenameDialog(BuildContext context, SavedTheme theme) {
    final l10n = AppLocalizations.of(context)!;
    showThemeNameDialog(
      context,
      title: l10n.themeRename,
      initialName: theme.name,
      onSubmit: (newName) {
        context.read<TimetableProvider>().renameTheme(theme.id, newName);
      },
    );
  }

  void _duplicateTheme(BuildContext context, SavedTheme theme) {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    provider.saveTheme(
      l10n.themeDuplicateCopyName(theme.name),
      theme.themeData,
    );
  }

  void _exportTheme(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    final themeConfig = ThemeConfig.fromSettings(provider.settings);
    Clipboard.setData(ClipboardData(text: jsonEncode(themeConfig.toJson())));
    showThemeFeedbackToast(
      context,
      message: l10n.themeExportSuccess,
      kind: AppToastKind.success,
    );
  }

  void _importTheme(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final data = await Clipboard.getData('text/plain');
    if (!context.mounted) return;
    if (data?.text == null) {
      showThemeFeedbackToast(
        context,
        message: l10n.themeImportFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    try {
      final json = jsonDecode(data!.text!) as Map<String, dynamic>;
      final config = ThemeConfig.fromJson(json);

      if (config.version == 2 &&
          (config.seedColor == null ||
              config.courseCardTitleColorLight == null)) {
        throw FormatException('missing required fields');
      }

      _applyThemeWithUndo(context, config, themeName: l10n.themeImport);
    } catch (_) {
      if (context.mounted) {
        showThemeFeedbackToast(
          context,
          message: l10n.themeImportFailed,
          kind: AppToastKind.error,
        );
      }
    }
  }
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
    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(l10n.liveSettingsTitle),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FTileGroup(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                SettingsEntryTile(
                  icon: Icons.alarm_outlined,
                  title: l10n.liveReminderTimingTitle,
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
                SettingsEntryTile(
                  icon: Icons.upcoming_outlined,
                  title: l10n.beforeClassDisplaySettingsTitle,
                  details: beforeClassSummary,
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
                SettingsEntryTile(
                  icon: Icons.timelapse_rounded,
                  title: l10n.duringEndDisplaySettingsTitle,
                  details: duringEndSummary,
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
                SettingsEntryTile(
                  icon: Icons.shield_outlined,
                  title: l10n.liveKeepAliveTitle,
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
                SettingsEntryTile(
                  icon: Icons.science_outlined,
                  title: l10n.liveTestingEntryTitle,
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
          ],
        ),
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
  bool _openingDiagnosticsViewer = false;
  Timer? _autoRefreshTimer;
  bool _refreshInFlight = false;
  bool _isAppResumed = true;
  bool _autoRefreshEnabled = true;
  DateTime? _lastDebugStatusUpdatedAt;
  bool _holidayOverrideEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final provider = context.read<TimetableProvider>();
    _holidayOverrideEnabled = provider.settings.holidayOverrideEnabled;
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
    if (_openingDiagnosticsViewer) {
      return;
    }
    _openingDiagnosticsViewer = true;
    final l10n = AppLocalizations.of(context)!;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LiveDiagnosticsLogViewerScreen(
            title: l10n.liveDiagnosticsViewerTitle,
            loadRawLog: () async {
              return await _liveService.readLiveDiagnosticsText() ?? '';
            },
            onLoadEmpty: () {
              if (!context.mounted) {
                return;
              }
              showAppToast(
                context,
                message: l10n.liveDiagnosticsUnavailable,
                kind: AppToastKind.warning,
              );
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    } finally {
      _openingDiagnosticsViewer = false;
    }
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
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.liveDiagnosticsNothingToExport,
        kind: AppToastKind.warning,
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
    showAppToast(
      context,
      message: cleared
          ? AppLocalizations.of(context)!.liveDiagnosticsCleared
          : AppLocalizations.of(context)!.liveDiagnosticsClearFailed,
      kind: cleared ? AppToastKind.success : AppToastKind.error,
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

    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(l10n.liveTestingTitle),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!kReleaseMode) ...[
              FTileGroup(
                label: Text(l10n.liveTestingHolidayOverride),
                description: Text(l10n.liveTestingHolidayOverrideSubtitle),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  SettingSwitchTile(
                    value: _holidayOverrideEnabled,
                    onChanged: (value) {
                      setState(() {
                        _holidayOverrideEnabled = value;
                      });
                      final provider = context.read<TimetableProvider>();
                      provider.updateTimetableSettings(
                        provider.settings.copyWith(
                          holidayOverrideEnabled: value,
                        ),
                      );
                      provider.refreshLiveActivityNow(forceSnapshotSync: true);
                    },
                    title: Text(
                      _holidayOverrideEnabled
                          ? l10n.liveTestingHolidayModeEnabled
                          : l10n.liveTestingHolidayModeDisabled,
                    ),
                    subtitle: Text(
                      _holidayOverrideEnabled
                          ? l10n.liveTestingHolidayModeEnabledDesc
                          : l10n.liveTestingHolidayModeDisabledDesc,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            SettingsSectionCard(
              title: l10n.liveTestingNotificationTitle,
              subtitle: l10n.liveTestingNotificationSubtitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FButton(
                    variant: FButtonVariant.secondary,
                    onPress: () async {
                      await _showTestOptions(context);
                      await Future<void>.delayed(
                        const Duration(milliseconds: 300),
                      );
                      await _refreshDebugStatus(showLoading: true);
                    },
                    prefix: const Icon(Icons.science_outlined),
                    child: Text(l10n.liveTestingSendAction),
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
                        FButton(
                          variant: FButtonVariant.secondary,
                          onPress: () => _triggerUmengTestCrash(context),
                          prefix: const Icon(Icons.warning_amber_rounded),
                          child: Text(l10n.liveTestingCrashAction),
                        ),
                        FButton(
                          variant: FButtonVariant.secondary,
                          onPress: () => _triggerUmengTestAnr(context),
                          prefix: const Icon(Icons.hourglass_bottom_rounded),
                          child: Text(l10n.liveTestingAnrAction),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
                            FButton(
                              variant: FButtonVariant.secondary,
                              onPress: _loadingDebugStatus
                                  ? null
                                  : () =>
                                        _refreshDebugStatus(showLoading: true),
                              prefix: _loadingDebugStatus
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: FCircularProgress(
                                        size: FCircularProgressSizeVariant.xs,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                              child: Text(
                                _loadingDebugStatus
                                    ? l10n.liveTestingRefreshing
                                    : l10n.liveTestingRefreshAction,
                              ),
                            ),
                            FButton(
                              variant: FButtonVariant.secondary,
                              onPress: _exportingDiagnostics
                                  ? null
                                  : _exportLiveDiagnostics,
                              prefix: _exportingDiagnostics
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: FCircularProgress(
                                        size: FCircularProgressSizeVariant.xs,
                                      ),
                                    )
                                  : const Icon(Icons.ios_share_rounded),
                              child: Text(
                                _exportingDiagnostics
                                    ? l10n.liveTestingExporting
                                    : l10n.liveTestingExportAction,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SettingSwitchTile(
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
            const SizedBox(height: 12),
            if (_debugStatus != null) ...[
              _DebugSectionCard(
                title: l10n.liveTestingSectionEnvironment,
                data: environment,
              ),
              const SizedBox(height: 12),
              _DebugSectionCard(
                title: l10n.liveTestingSectionService,
                data: service,
              ),
              const SizedBox(height: 12),
              _DebugSectionCard(
                title: l10n.liveTestingSectionCourse,
                data: course,
              ),
              const SizedBox(height: 12),
              _DebugSectionCard(
                title: l10n.liveTestingSectionTiming,
                data: timing,
              ),
              const SizedBox(height: 12),
              _DebugSectionCard(
                title: l10n.liveTestingSectionSwitches,
                data: switches,
              ),
              const SizedBox(height: 12),
              _DebugSectionCard(
                title: l10n.liveTestingSectionDisplay,
                data: display,
              ),
              const SizedBox(height: 12),
              _DebugSectionCard(
                title: l10n.liveTestingSectionNotification,
                data: notification,
              ),
              const SizedBox(height: 12),
              _DebugSectionCard(
                title: l10n.liveTestingSectionRecentLogs,
                data: recentDiagnostics,
              ),
              const SizedBox(height: 12),
              SettingsSectionCard(
                title: l10n.liveTestingRawDataTitle,
                subtitle: l10n.liveTestingRawDataSubtitle,
                child: FAccordion(
                  children: [
                    FAccordionItem(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.liveTestingExpandRawJson),
                          Text(
                            l10n.liveTestingExpandRawJsonSubtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      child: SelectableText(
                        rawDebugJson,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.4,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SettingsSectionCard(
              title: l10n.liveTestingLocalLogsTitle,
              subtitle: l10n.liveTestingLocalLogsSubtitle,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FButton(
                    variant: FButtonVariant.secondary,
                    onPress: _clearingDiagnostics
                        ? null
                        : _clearLiveDiagnostics,
                    prefix: _clearingDiagnostics
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: FCircularProgress(
                              size: FCircularProgressSizeVariant.xs,
                            ),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    child: Text(
                      _clearingDiagnostics
                          ? l10n.liveTestingClearingLogs
                          : l10n.liveTestingClearLogsAction,
                    ),
                  ),
                  FButton(
                    variant: FButtonVariant.secondary,
                    onPress: _openLiveDiagnosticsViewer,
                    prefix: const Icon(Icons.article_outlined),
                    child: Text(l10n.liveTestingViewPhoneLogsAction),
                  ),
                  FButton(
                    variant: FButtonVariant.secondary,
                    onPress: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                    prefix: const Icon(Icons.info_outline_rounded),
                    child: Text(l10n.liveTestingMoreTesterOptionsAction),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    return SettingsSectionCard(
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
  showAppToast(
    context,
    message: AppLocalizations.of(context)!.liveTestingCrashSoon,
    kind: AppToastKind.warning,
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await UmengAnalyticsService.triggerTestCrash();
}

Future<void> _triggerUmengTestAnr(BuildContext context) async {
  if (!context.mounted) return;
  showAppToast(
    context,
    message: AppLocalizations.of(context)!.liveTestingAnrSoon,
    kind: AppToastKind.warning,
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
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.liveTestingNoCourseAvailable,
      kind: AppToastKind.warning,
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
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.liveTestingNotificationSent,
      kind: AppToastKind.success,
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
    showAppToast(
      context,
      message: AppLocalizations.of(context)!.sendFailedWithError('$e'),
      kind: AppToastKind.error,
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
    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(l10n.homeWidgetSettingsTitle),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SettingsSectionCard(
              title: l10n.homeWidgetQuickAddTitle,
              subtitle: _isCheckingPinSupport
                  ? l10n.homeWidgetCheckingPinSupport
                  : (_canRequestPinWidget
                        ? l10n.homeWidgetPinSupported
                        : l10n.homeWidgetPinUnsupported),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.compact22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.miniList22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.medium24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPinWidgetButton(
                          HomeWidgetPinTarget.large44,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: l10n.homeWidgetTodayCourseTitle,
              subtitle: l10n.homeWidgetTodayCourseSubtitle,
              child: FSelect<WidgetBackgroundStyle>(
                hint: l10n.homeWidgetBackgroundStyleLabel,
                items: {
                  for (final v in WidgetBackgroundStyle.values)
                    _widgetBackgroundStyleLabel(context, v): v,
                },
                control: FSelectControl.lifted(
                  value: _draft.widgetBackgroundStyle,
                  onChange: (value) {
                    if (value == null) return;
                    _updateDraft(_draft.copyWith(widgetBackgroundStyle: value));
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            FTileGroup(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                SettingSwitchTile(
                  title: Text(l10n.homeWidgetShowLocationTitle),
                  value: _draft.widgetShowLocation,
                  onChanged: (value) {
                    _updateDraft(_draft.copyWith(widgetShowLocation: value));
                  },
                ),
                SettingSwitchTile(
                  title: Text(l10n.homeWidgetShowCountdownTitle),
                  value: _draft.widgetShowCountdown,
                  onChanged: (value) {
                    _updateDraft(_draft.copyWith(widgetShowCountdown: value));
                  },
                ),
                SettingSwitchTile(
                  title: Text(l10n.homeWidgetHideCompletedTitle),
                  value: _draft.widgetHideCompletedCourses,
                  onChanged: (value) {
                    _updateDraft(
                      _draft.copyWith(widgetHideCompletedCourses: value),
                    );
                  },
                ),
                SettingSwitchTile(
                  title: Text(l10n.homeWidgetShowTomorrowTitle),
                  value: _draft.widgetShowTomorrowCourses,
                  onChanged: (value) {
                    _updateDraft(
                      _draft.copyWith(widgetShowTomorrowCourses: value),
                    );
                  },
                ),
              ],
            ),
            if (_draft.widgetShowCountdown) ...[
              const SizedBox(height: 12),
              SettingsSectionCard(
                title: l10n.homeWidgetCountdownLeadTitle,
                subtitle: l10n.homeWidgetCountdownLeadSubtitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FSelect<int>(
                      hint: l10n.homeWidgetCountdownLeadTitle,
                      items: {
                        l10n.homeWidgetCountdownLeadAlways: 0,
                        for (final m in const [
                          1,
                          5,
                          10,
                          15,
                          20,
                          30,
                          40,
                          50,
                          60,
                        ])
                          l10n.beforeClassMinutesOption(m): m,
                      },
                      control: FSelectControl.lifted(
                        value: _draft.widgetCountdownLeadMinutes,
                        onChange: (value) {
                          if (value == null) return;
                          _updateDraft(
                            _draft.copyWith(widgetCountdownLeadMinutes: value),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    FSelect<LiveCountdownTextStyle>(
                      hint: l10n.widgetCountdownStyleTitle,
                      items: {
                        for (final v in LiveCountdownTextStyle.values)
                          v.label: v,
                      },
                      control: FSelectControl.lifted(
                        value: _draft.widgetCountdownTextStyle,
                        onChange: (value) {
                          if (value == null) return;
                          _updateDraft(
                            _draft.copyWith(widgetCountdownTextStyle: value),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: l10n.homeWidgetHeightAdjustTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _widgetHeightAdjustmentLabel(l10n),
                    style: context.theme.typography.body.sm,
                  ),
                  FSlider(
                    tooltipControls: kSettingsSliderTooltipControls,
                    control: FSliderControl.managedDiscrete(
                      initial: FSliderValue(
                        max:
                            ((_draft.widgetHeightAdjustment -
                                        _defaultWidgetHeightAdjustment)
                                    .clamp(-16, 16)
                                    .toDouble() +
                                16) /
                            32,
                      ),
                      onChange: (sv) => _updateDraft(
                        _draft.copyWith(
                          widgetHeightAdjustment:
                              _defaultWidgetHeightAdjustment - 16 + sv.max * 32,
                        ),
                        debounce: true,
                      ),
                    ),
                    marks: [
                      for (var i = 0; i <= 32; i++) FSliderMark(value: i / 32),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${l10n.homeWidgetCornerRadiusTitle} · ${_draft.widgetCornerRadius.toStringAsFixed(0)}dp',
                    style: context.theme.typography.body.sm,
                  ),
                  FSlider(
                    tooltipControls: kSettingsSliderTooltipControls,
                    control: FSliderControl.managedDiscrete(
                      initial: FSliderValue(
                        max:
                            ((_draft.widgetCornerRadius -
                                        _defaultWidgetCornerRadius)
                                    .clamp(-14, 14)
                                    .toDouble() +
                                14) /
                            28,
                      ),
                      onChange: (sv) => _updateDraft(
                        _draft.copyWith(
                          widgetCornerRadius:
                              _defaultWidgetCornerRadius - 14 + sv.max * 28,
                        ),
                        debounce: true,
                      ),
                    ),
                    marks: [
                      for (var i = 0; i <= 28; i++) FSliderMark(value: i / 28),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: l10n.homeWidgetDescriptionTitle,
              subtitle: l10n.homeWidgetDescriptionText,
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  String _widgetHeightAdjustmentLabel(AppLocalizations l10n) {
    if (_draft.widgetHeightAdjustment == _defaultWidgetHeightAdjustment) {
      return l10n.defaultLabel;
    }
    if (_draft.widgetHeightAdjustment > _defaultWidgetHeightAdjustment) {
      return l10n.higherByValue(
        (_draft.widgetHeightAdjustment - _defaultWidgetHeightAdjustment)
            .toStringAsFixed(0),
      );
    }
    return l10n.lowerByValue(
      (_defaultWidgetHeightAdjustment - _draft.widgetHeightAdjustment)
          .toStringAsFixed(0),
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
      showAppToast(context, message: message);
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
    return SizedBox(
      width: double.infinity,
      child: FButton(
        variant: FButtonVariant.outline,
        onPress: isLoading ? null : () => _requestPinWidget(target),
        prefix: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: FCircularProgress(size: FCircularProgressSizeVariant.xs),
              )
            : const Icon(Icons.add_box_outlined, size: 18),
        child: Text(
          _homeWidgetTargetLabel(context, target),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
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
    showAppToast(context, message: message);
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
    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(l10n.layoutSettingsTitle),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            TimetableWeekPreview(
              provider: provider,
              settings: _draft,
              week: provider.currentWeek,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FTileGroup(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      SettingSwitchTile(
                        title: Text(l10n.layoutAutoFitHeightTitle),
                        value: _draft.timetableAutoFitSectionHeight,
                        onChanged: (value) {
                          _updateDraft(
                            _draft.copyWith(
                              timetableAutoFitSectionHeight: value,
                            ),
                          );
                        },
                      ),
                      SettingSwitchTile(
                        title: Text(l10n.layoutHideWeekendsTitle),
                        value: _draft.timetableHideWeekends,
                        onChanged: (value) {
                          _updateDraft(
                            _draft.copyWith(timetableHideWeekends: value),
                          );
                        },
                      ),
                      SettingSwitchTile(
                        title: Text(l10n.layoutEnableHapticsTitle),
                        value: _draft.enableHaptics,
                        onChanged: (value) {
                          _updateDraft(_draft.copyWith(enableHaptics: value));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SettingsSectionCard(
                    subtitle: l10n.layoutEntrySubtitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FSelect<SectionTimeDisplayMode>(
                          hint: l10n.layoutTimeColumnDisplayLabel,
                          items: {
                            for (final v in SectionTimeDisplayMode.values)
                              v.label: v,
                          },
                          control: FSelectControl.lifted(
                            value: _draft.timetableSectionTimeDisplayMode,
                            onChange: (value) {
                              if (value == null) return;
                              _updateDraft(
                                _draft.copyWith(
                                  timetableSectionTimeDisplayMode: value,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        FSelect<TimetableTimeColumnWidthMode>(
                          hint: l10n.layoutTimeColumnWidthLabel,
                          items: {
                            for (final v in TimetableTimeColumnWidthMode.values)
                              v.label: v,
                          },
                          control: FSelectControl.lifted(
                            value: _draft.timetableTimeColumnWidthMode,
                            onChange: (value) {
                              if (value == null) return;
                              _updateDraft(
                                _draft.copyWith(
                                  timetableTimeColumnWidthMode: value,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        FSelect<BackToCurrentWeekButtonStyle>(
                          hint: l10n.layoutBackToCurrentWeekButtonStyleLabel,
                          items: {
                            for (final v in BackToCurrentWeekButtonStyle.values)
                              _backToCurrentWeekButtonStyleLabel(l10n, v): v,
                          },
                          control: FSelectControl.lifted(
                            value: _draft.timetableBackToCurrentWeekButtonStyle,
                            onChange: (value) {
                              if (value == null) return;
                              _updateDraft(
                                _draft.copyWith(
                                  timetableBackToCurrentWeekButtonStyle: value,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.layoutBackToCurrentWeekButtonStyleHelper,
                          style: context.theme.typography.body.xs.copyWith(
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                        if (_draft.timetableBackToCurrentWeekButtonStyle ==
                            BackToCurrentWeekButtonStyle.floating) ...[
                          const SizedBox(height: 12),
                          Text(
                            l10n.layoutBackToCurrentWeekButtonOpacityLabel(
                              (_draft.timetableFloatingBackToCurrentWeekButtonOpacity *
                                      100)
                                  .round(),
                            ),
                            style: context.theme.typography.body.sm,
                          ),
                          const SizedBox(height: 8),
                          FSlider(
                            tooltipControls: kSettingsSliderTooltipControls,
                            control: FSliderControl.managedDiscrete(
                              initial: FSliderValue(
                                max:
                                    ((_draft.timetableFloatingBackToCurrentWeekButtonOpacity -
                                                0.55) /
                                            0.45)
                                        .clamp(0.0, 1.0),
                              ),
                              onChange: (sv) => _updateDraft(
                                _draft.copyWith(
                                  timetableFloatingBackToCurrentWeekButtonOpacity:
                                      0.55 + sv.max * 0.45,
                                ),
                                debounce: true,
                              ),
                            ),
                            marks: [
                              for (var i = 0; i <= 9; i++)
                                FSliderMark(value: i / 9),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          l10n.layoutCourseCardGapLabel(
                            _draft.timetableCourseCardGap.toStringAsFixed(1),
                          ),
                          style: context.theme.typography.body.sm,
                        ),
                        FSlider(
                          tooltipControls: kSettingsSliderTooltipControls,
                          control: FSliderControl.managedDiscrete(
                            initial: FSliderValue(
                              max:
                                  (_draft.timetableCourseCardGap.clamp(
                                            0.0,
                                            3.0,
                                          ) /
                                          3)
                                      .clamp(0.0, 1.0),
                            ),
                            onChange: (sv) => _updateDraft(
                              _draft.copyWith(
                                timetableCourseCardGap: sv.max * 3,
                              ),
                              debounce: true,
                            ),
                          ),
                          marks: [
                            for (var i = 0; i <= 12; i++)
                              FSliderMark(value: i / 12),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.layoutSectionHeightLabel(
                            _draft.sectionHeight.toStringAsFixed(0),
                          ),
                          style: context.theme.typography.body.sm,
                        ),
                        FSlider(
                          tooltipControls: kSettingsSliderTooltipControls,
                          control: FSliderControl.managedDiscrete(
                            initial: FSliderValue(
                              max: ((_draft.sectionHeight - 48) / 44).clamp(
                                0.0,
                                1.0,
                              ),
                            ),
                            onChange: !_draft.timetableAutoFitSectionHeight
                                ? (sv) => _updateDraft(
                                    _draft.copyWith(
                                      sectionHeight: 48 + sv.max * 44,
                                    ),
                                    debounce: true,
                                  )
                                : null,
                          ),
                          enabled: !_draft.timetableAutoFitSectionHeight,
                          marks: [
                            for (var i = 0; i <= 11; i++)
                              FSliderMark(value: i / 11),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.layoutCompactFontSizeLabel(
                            _draft.compactFontSize.toStringAsFixed(1),
                          ),
                          style: context.theme.typography.body.sm,
                        ),
                        FSlider(
                          tooltipControls: kSettingsSliderTooltipControls,
                          control: FSliderControl.managedDiscrete(
                            initial: FSliderValue(
                              max: ((_draft.compactFontSize - 7) / 5).clamp(
                                0.0,
                                1.0,
                              ),
                            ),
                            onChange: (sv) => _updateDraft(
                              _draft.copyWith(compactFontSize: 7 + sv.max * 5),
                              debounce: true,
                            ),
                          ),
                          marks: [
                            for (var i = 0; i <= 10; i++)
                              FSliderMark(value: i / 10),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.layoutCourseCardFontSizeLabel(
                            _draft.courseCardFontSize.toStringAsFixed(1),
                          ),
                          style: context.theme.typography.body.sm,
                        ),
                        FSlider(
                          tooltipControls: kSettingsSliderTooltipControls,
                          control: FSliderControl.managedDiscrete(
                            initial: FSliderValue(
                              max: ((_draft.courseCardFontSize - 7) / 5).clamp(
                                0.0,
                                1.0,
                              ),
                            ),
                            onChange: (sv) => _updateDraft(
                              _draft.copyWith(
                                courseCardFontSize: 7 + sv.max * 5,
                              ),
                              debounce: true,
                            ),
                          ),
                          marks: [
                            for (var i = 0; i <= 10; i++)
                              FSliderMark(value: i / 10),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FTileGroup(
                    label: Text(l10n.layoutCourseCardDisplayTitle),
                    description: Text(l10n.layoutCourseCardDisplaySubtitle),
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      SettingSwitchTile(
                        title: Text(l10n.showCourseNameTitle),
                        value: _draft.courseCardShowName,
                        onChanged: (value) {
                          _updateDraft(
                            _draft.copyWith(courseCardShowName: value),
                          );
                        },
                      ),
                      SettingSwitchTile(
                        title: Text(l10n.layoutShowTeacherTitle),
                        value: _draft.courseCardShowTeacher,
                        onChanged: (value) {
                          _updateDraft(
                            _draft.copyWith(courseCardShowTeacher: value),
                          );
                        },
                      ),
                      SettingSwitchTile(
                        title: Text(l10n.layoutShowClassroomTitle),
                        value: _draft.courseCardShowLocation,
                        onChanged: (value) {
                          _updateDraft(
                            _draft.copyWith(courseCardShowLocation: value),
                          );
                        },
                      ),
                      SettingSwitchTile(
                        title: Text(l10n.layoutShowTimeTitle),
                        value: _draft.courseCardShowTime,
                        onChanged: (value) {
                          _updateDraft(
                            _draft.copyWith(courseCardShowTime: value),
                          );
                        },
                      ),
                      SettingSwitchTile(
                        title: Text(l10n.layoutShowTimeLabelsTitle),
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
                      SettingSwitchTile(
                        title: Text(l10n.layoutShowWeeksTitle),
                        value: _draft.courseCardShowWeeks,
                        onChanged: (value) {
                          _updateDraft(
                            _draft.copyWith(courseCardShowWeeks: value),
                          );
                        },
                      ),
                      SettingSwitchTile(
                        title: Text(l10n.layoutShowDescriptionTitle),
                        value: _draft.courseCardShowDescription,
                        onChanged: (value) {
                          _updateDraft(
                            _draft.copyWith(courseCardShowDescription: value),
                          );
                        },
                      ),
                      SettingSwitchTile(
                        title: Text(l10n.layoutShowOtherWeeksTitle),
                        value: _draft.timetableShowNonCurrentWeekCourses,
                        onChanged: (value) {
                          _updateDraft(
                            _draft.copyWith(
                              timetableShowNonCurrentWeekCourses: value,
                            ),
                          );
                        },
                      ),
                      SettingSwitchTile(
                        title: Text(l10n.layoutShowConflictBadgeTitle),
                        value: _draft.showConflictBadgeOnTimetable,
                        onChanged: (value) {
                          _updateDraft(
                            _draft.copyWith(
                              showConflictBadgeOnTimetable: value,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SettingsSectionCard(
                    title: l10n.layoutVerticalAlignLabel,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FSelect<CourseCardVerticalAlign>(
                          hint: l10n.layoutVerticalAlignLabel,
                          items: {
                            for (final v in CourseCardVerticalAlign.values)
                              v.label: v,
                          },
                          control: FSelectControl.lifted(
                            value: _draft.courseCardVerticalAlign,
                            onChange: (value) {
                              if (value == null) return;
                              _updateDraft(
                                _draft.copyWith(courseCardVerticalAlign: value),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        FSelect<CourseCardHorizontalAlign>(
                          hint: l10n.layoutHorizontalAlignLabel,
                          items: {
                            for (final v in CourseCardHorizontalAlign.values)
                              v.label: v,
                          },
                          control: FSelectControl.lifted(
                            value: _draft.courseCardHorizontalAlign,
                            onChange: (value) {
                              if (value == null) return;
                              _updateDraft(
                                _draft.copyWith(
                                  courseCardHorizontalAlign: value,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsSectionCard(
                    title: l10n.layoutConflictOpacityLabel(
                      (_draft.timetableConflictCourseOpacity * 100).round(),
                    ),
                    subtitle: l10n.layoutConflictOpacitySubtitle,
                    child: FSlider(
                      tooltipControls: kSettingsSliderTooltipControls,
                      control: FSliderControl.managedDiscrete(
                        initial: FSliderValue(
                          max:
                              ((_draft.timetableConflictCourseOpacity - 0.2) /
                                      0.8)
                                  .clamp(0.0, 1.0),
                        ),
                        onChange: (sv) => _updateDraft(
                          _draft.copyWith(
                            timetableConflictCourseOpacity: 0.2 + sv.max * 0.8,
                          ),
                          debounce: true,
                        ),
                      ),
                      marks: [
                        for (var i = 0; i <= 16; i++)
                          FSliderMark(value: i / 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsSectionCard(
                    title: l10n.textColorTitle,
                    subtitle: l10n.textColorSubtitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SettingSwitchTile(
                          title: Text(l10n.textColorIndependentDetail),
                          value: !_draft.linkCourseCardColors,
                          onChanged: (value) {
                            if (!value) {
                              _updateDraft(
                                _draft.copyWith(
                                  linkCourseCardColors: true,
                                  courseCardDetailColorLight:
                                      _draft.courseCardTitleColorLight,
                                  courseCardDetailColorDark:
                                      _draft.courseCardTitleColorDark,
                                ),
                              );
                            } else {
                              _updateDraft(
                                _draft.copyWith(linkCourseCardColors: false),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        // 浅色模式颜色设置
                        _buildModeColorSettings(
                          context,
                          l10n: l10n,
                          modeLabel: l10n.themeModeLight,
                          containerColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          titleColor: _draft.courseCardTitleColorLight,
                          detailColor: _draft.courseCardDetailColorLight,
                          weekdayColor: _draft.weekdayBarFontColorLight,
                          timeAxisColor: _draft.timeAxisFontColorLight,
                          accentColor: _draft.weekdayBarAccentColorLight,
                          onTitleColorChanged: (color) {
                            if (_draft.linkCourseCardColors) {
                              _updateDraft(
                                _draft.copyWith(
                                  courseCardTitleColorLight: color,
                                  courseCardDetailColorLight: color,
                                ),
                              );
                            } else {
                              _updateDraft(
                                _draft.copyWith(
                                  courseCardTitleColorLight: color,
                                ),
                              );
                            }
                          },
                          onDetailColorChanged: (color) => _updateDraft(
                            _draft.copyWith(courseCardDetailColorLight: color),
                          ),
                          onWeekdayColorChanged: (color) => _updateDraft(
                            _draft.copyWith(weekdayBarFontColorLight: color),
                          ),
                          onTimeAxisColorChanged: (color) => _updateDraft(
                            _draft.copyWith(timeAxisFontColorLight: color),
                          ),
                          onAccentColorChanged: (color) => _updateDraft(
                            _draft.copyWith(weekdayBarAccentColorLight: color),
                          ),
                          defaultTitleColor:
                              TimetableSettings.defaultCourseCardTitleColor,
                          defaultDetailColor:
                              TimetableSettings.defaultCourseCardDetailColor,
                          defaultWeekdayColor:
                              TimetableSettings.defaultWeekdayBarFontColorLight,
                          defaultTimeAxisColor:
                              TimetableSettings.defaultTimeAxisFontColorLight,
                          defaultAccentColor: TimetableSettings
                              .defaultWeekdayBarAccentColorLight,
                        ),
                        const SizedBox(height: 12),
                        // 深色模式颜色设置
                        _buildModeColorSettings(
                          context,
                          l10n: l10n,
                          modeLabel: l10n.themeModeDark,
                          containerColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          titleColor: _draft.courseCardTitleColorDark,
                          detailColor: _draft.courseCardDetailColorDark,
                          weekdayColor: _draft.weekdayBarFontColorDark,
                          timeAxisColor: _draft.timeAxisFontColorDark,
                          accentColor: _draft.weekdayBarAccentColorDark,
                          onTitleColorChanged: (color) {
                            if (_draft.linkCourseCardColors) {
                              _updateDraft(
                                _draft.copyWith(
                                  courseCardTitleColorDark: color,
                                  courseCardDetailColorDark: color,
                                ),
                              );
                            } else {
                              _updateDraft(
                                _draft.copyWith(
                                  courseCardTitleColorDark: color,
                                ),
                              );
                            }
                          },
                          onDetailColorChanged: (color) => _updateDraft(
                            _draft.copyWith(courseCardDetailColorDark: color),
                          ),
                          onWeekdayColorChanged: (color) => _updateDraft(
                            _draft.copyWith(weekdayBarFontColorDark: color),
                          ),
                          onTimeAxisColorChanged: (color) => _updateDraft(
                            _draft.copyWith(timeAxisFontColorDark: color),
                          ),
                          onAccentColorChanged: (color) => _updateDraft(
                            _draft.copyWith(weekdayBarAccentColorDark: color),
                          ),
                          defaultTitleColor:
                              TimetableSettings.defaultCourseCardTitleColor,
                          defaultDetailColor:
                              TimetableSettings.defaultCourseCardDetailColor,
                          defaultWeekdayColor:
                              TimetableSettings.defaultWeekdayBarFontColorDark,
                          defaultTimeAxisColor:
                              TimetableSettings.defaultTimeAxisFontColorDark,
                          defaultAccentColor: TimetableSettings
                              .defaultWeekdayBarAccentColorDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      showAppToast(context, message: message);
      setState(() {
        _draft = provider.settings;
      });
      return;
    }
  }

  Widget _buildModeColorSettings(
    BuildContext context, {
    required AppLocalizations l10n,
    required String modeLabel,
    required Color containerColor,
    required String titleColor,
    required String detailColor,
    required String weekdayColor,
    required String timeAxisColor,
    required String accentColor,
    required ValueChanged<String> onTitleColorChanged,
    required ValueChanged<String> onDetailColorChanged,
    required ValueChanged<String> onWeekdayColorChanged,
    required ValueChanged<String> onTimeAxisColorChanged,
    required ValueChanged<String> onAccentColorChanged,
    required String defaultTitleColor,
    required String defaultDetailColor,
    required String defaultWeekdayColor,
    required String defaultTimeAxisColor,
    required String defaultAccentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              modeLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          _buildColorSettingRow(
            context,
            label: l10n.textColorCourseCardTitle,
            currentColor: titleColor,
            defaultValue: defaultTitleColor,
            onColorSelected: onTitleColorChanged,
            bgColorForContrast: _draft.timetableUseUnifiedCardColor
                ? _draft.timetableUnifiedCardColor
                : _draft.themeSeedColor,
          ),
          _buildColorSettingRow(
            context,
            label: l10n.textColorCourseCardDetail,
            currentColor: detailColor,
            defaultValue: defaultDetailColor,
            enabled: !_draft.linkCourseCardColors,
            onColorSelected: onDetailColorChanged,
            bgColorForContrast: _draft.timetableUseUnifiedCardColor
                ? _draft.timetableUnifiedCardColor
                : _draft.themeSeedColor,
          ),
          _buildColorSettingRow(
            context,
            label: l10n.textColorWeekdayBar,
            currentColor: weekdayColor,
            defaultValue: defaultWeekdayColor,
            onColorSelected: onWeekdayColorChanged,
            bgColorForContrast: _draft.timetablePageBackgroundColor,
          ),
          _buildColorSettingRow(
            context,
            label: l10n.textColorWeekdayBarAccent,
            currentColor: accentColor,
            defaultValue: defaultAccentColor,
            onColorSelected: onAccentColorChanged,
            bgColorForContrast: _draft.timetablePageBackgroundColor,
          ),
          _buildColorSettingRow(
            context,
            label: l10n.textColorTimeAxis,
            currentColor: timeAxisColor,
            defaultValue: defaultTimeAxisColor,
            onColorSelected: onTimeAxisColorChanged,
            bgColorForContrast: _draft.timetablePageBackgroundColor,
          ),
        ],
      ),
    );
  }

  Widget _buildColorSettingRow(
    BuildContext context, {
    required String label,
    required String currentColor,
    required ValueChanged<String> onColorSelected,
    String? defaultValue,
    bool enabled = true,
    String? bgColorForContrast,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          GestureDetector(
            onTap: enabled
                ? () {
                    _showColorPicker(
                      context,
                      currentColor: currentColor,
                      onColorSelected: onColorSelected,
                      defaultValue: defaultValue,
                      bgColorForContrast: bgColorForContrast,
                    );
                  }
                : null,
            child: Semantics(
              label: '${l10n.textColorCurrentColor}: $currentColor',
              button: true,
              child: Tooltip(
                message: currentColor,
                child: Opacity(
                  opacity: enabled ? 1.0 : 0.4,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _colorFromHex(currentColor),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
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

  void _showColorPicker(
    BuildContext context, {
    required String currentColor,
    required ValueChanged<String> onColorSelected,
    String? defaultValue,
    String? bgColorForContrast,
  }) {
    final l10n = AppLocalizations.of(context)!;
    Color pickerColor = _colorFromHex(currentColor);

    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: Text(l10n.textColorSelectColor),
        body: SingleChildScrollView(
          child: ColorPicker(
            color: pickerColor,
            onColorChanged: (Color color) {
              pickerColor = color;
            },
            width: 40,
            height: 40,
            borderRadius: 4,
            spacing: 5,
            runSpacing: 5,
            wheelDiameter: 260,
            wheelWidth: 26,
            enableOpacity: false,
            showColorCode: true,
            showColorName: false,
            showMaterialName: false,
            copyPasteBehavior: const ColorPickerCopyPasteBehavior(
              copyButton: true,
              pasteButton: true,
              longPressMenu: true,
            ),
            colorCodeTextStyle: Theme.of(context).textTheme.bodyMedium,
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.both: false,
              ColorPickerType.primary: true,
              ColorPickerType.accent: false,
              ColorPickerType.bw: true,
              ColorPickerType.custom: false,
              ColorPickerType.wheel: true,
            },
          ),
        ),
        actions: <Widget>[
          if (defaultValue != null &&
              defaultValue.toLowerCase() != currentColor.toLowerCase())
            FButton(
              variant: FButtonVariant.ghost,
              onPress: () {
                onColorSelected(defaultValue);
                Navigator.pop(context);
              },
              child: Text(l10n.resetDefaultAction),
            ),
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(context),
            child: Text(l10n.cancelAction),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () {
              final r = ((pickerColor.r * 255.0).round() & 0xff)
                  .toRadixString(16)
                  .padLeft(2, '0');
              final g = ((pickerColor.g * 255.0).round() & 0xff)
                  .toRadixString(16)
                  .padLeft(2, '0');
              final b = ((pickerColor.b * 255.0).round() & 0xff)
                  .toRadixString(16)
                  .padLeft(2, '0');
              final selectedHex = '#$r$g$b';
              onColorSelected(selectedHex);
              Navigator.pop(context);
              // 检查对比度
              if (bgColorForContrast != null) {
                _checkContrastAndWarn(context, selectedHex, bgColorForContrast);
              }
            },
            child: Text(l10n.confirmAction),
          ),
        ],
      ),
    );
  }

  Color _colorFromHex(String hexColor, [Color? fallback]) {
    return parseHexColorOrFallback(
      hexColor,
      fallback: fallback ?? const Color(0xFF2563EB),
    );
  }

  /// 计算颜色的相对亮度（WCAG 2.1）
  double _relativeLuminance(Color color) {
    final r = color.r;
    final g = color.g;
    final b = color.b;
    final rLinear = r <= 0.03928 ? r / 12.92 : ((r + 0.055) / 1.055) * 2.4;
    final gLinear = g <= 0.03928 ? g / 12.92 : ((g + 0.055) / 1.055) * 2.4;
    final bLinear = b <= 0.03928 ? b / 12.92 : ((b + 0.055) / 1.055) * 2.4;
    return 0.2126 * rLinear + 0.7152 * gLinear + 0.0722 * bLinear;
  }

  /// 计算两个颜色之间的对比度（WCAG 2.1）
  double _contrastRatio(Color color1, Color color2) {
    final l1 = _relativeLuminance(color1);
    final l2 = _relativeLuminance(color2);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 检查颜色对比度并在不足时显示警告
  void _checkContrastAndWarn(
    BuildContext context,
    String textColorHex,
    String bgColorHex,
  ) {
    final textColor = _colorFromHex(textColorHex);
    final bgColor = _colorFromHex(bgColorHex);
    final ratio = _contrastRatio(textColor, bgColor);

    if (ratio < 3.0) {
      final l10n = AppLocalizations.of(context)!;
      showAppToast(
        context,
        message: l10n.textColorLowContrastWarning,
        kind: AppToastKind.warning,
      );
    }
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

class _HolidaySettingsScreen extends StatefulWidget {
  const _HolidaySettingsScreen();

  @override
  State<_HolidaySettingsScreen> createState() => _HolidaySettingsScreenState();
}

class _HolidaySettingsScreenState extends State<_HolidaySettingsScreen> {
  late TimetableSettings _draft;
  Future<void> _saveQueue = Future<void>.value();
  List<HolidayEntry> _customHolidays = [];

  @override
  void initState() {
    super.initState();
    _draft = context.read<TimetableProvider>().settings;
    _loadCustomHolidays();
  }

  Future<void> _loadCustomHolidays() async {
    final provider = context.read<TimetableProvider>();
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
    final provider = context.read<TimetableProvider>();
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

    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24 + MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existing != null
                            ? l10n.customHolidayEdit
                            : l10n.customHolidayAdd,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FTextField(
                        control: FTextFieldControl.managed(
                          controller: nameController,
                        ),
                        label: Text(l10n.customHolidayNameLabel),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final now = DateTime.now();
                          final picked = await showDateRangePicker(
                            context: ctx,
                            initialDateRange:
                                startDate != null && endDate != null
                                ? DateTimeRange(
                                    start: startDate!,
                                    end: endDate!,
                                  )
                                : null,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 2),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              startDate = picked.start;
                              endDate = picked.end;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText:
                                '${l10n.customHolidayStartDate} / ${l10n.customHolidayEndDate}',
                            border: const OutlineInputBorder(),
                            suffixIcon: const Icon(Icons.date_range, size: 18),
                          ),
                          child: Text(
                            startDate != null && endDate != null
                                ? '${startDate!.month}/${startDate!.day} — ${endDate!.month}/${endDate!.day}'
                                : '--',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.customHolidayType,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          children: [
                            Expanded(
                              child: FButton(
                                variant: selectedType == HolidayType.vacation
                                    ? FButtonVariant.primary
                                    : FButtonVariant.outline,
                                onPress: () => setDialogState(
                                  () => selectedType = HolidayType.vacation,
                                ),
                                child: Text(l10n.customHolidayTypeVacation),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FButton(
                                variant:
                                    selectedType == HolidayType.adjustedWorkday
                                    ? FButtonVariant.primary
                                    : FButtonVariant.outline,
                                onPress: () => setDialogState(
                                  () => selectedType =
                                      HolidayType.adjustedWorkday,
                                ),
                                child: Text(l10n.customHolidayTypeWorkday),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: FButton(
                              variant: FButtonVariant.outline,
                              onPress: () => Navigator.pop(ctx, false),
                              child: Text(
                                MaterialLocalizations.of(ctx).cancelButtonLabel,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FButton(
                              variant: FButtonVariant.primary,
                              onPress: () {
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
                                Navigator.pop(ctx, true);
                              },
                              child: Text(
                                MaterialLocalizations.of(ctx).okButtonLabel,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true || startDate == null || endDate == null) return;
    if (!mounted) return;
    final name = nameController.text.trim();
    final groupId =
        existing?.groupId ?? 'custom-${DateTime.now().millisecondsSinceEpoch}';
    final provider = context.read<TimetableProvider>();

    // Build entries for each day in range
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

    // Batch save: load existing → add/update → save once (avoid race condition)
    if (existing != null) {
      await provider.updateCustomHoliday(groupId, entries);
    } else {
      await provider.addCustomHolidays(entries);
    }
    await _loadCustomHolidays();
  }

  Future<void> _confirmDeleteCustomHoliday(String groupId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, animation) => FDialog(
        body: Text(l10n.customHolidayDeleteConfirm),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => Navigator.pop(ctx, true),
            child: Text(l10n.customHolidayDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final provider = context.read<TimetableProvider>();
      await provider.removeCustomHoliday(groupId);
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
              name: representative.first.name,
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

    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        suffixes: [
          FHeaderAction(
            icon: const Icon(Icons.refresh),
            semanticsLabel: l10n.holidayCheckUpdate,
            onPress: () async {
              await provider.refreshHolidayData();
              if (context.mounted) {
                showAppToast(
                  context,
                  message: l10n.holidayCheckUpdate,
                  kind: AppToastKind.success,
                );
              }
            },
          ),
        ],
        title: Text(l10n.holidaySettingsTitle),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FCard.raw(
              child: Column(
                children: [
                  SettingSwitchTile(
                    title: Text(l10n.holidayEnableTitle),
                    subtitle: Text(l10n.holidayEnableSubtitle),
                    value: _draft.enableHolidayMarking,
                    onChanged: (value) {
                      _updateDraft(
                        _draft.copyWith(enableHolidayMarking: value),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // ---- 自定义假期 ----
            FCard.raw(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit_note,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l10n.customHolidayTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        FButton(
                          variant: FButtonVariant.ghost,
                          onPress: () => _showCustomHolidayDialog(),
                          prefix: const Icon(Icons.add, size: 18),
                          child: Text(l10n.customHolidayAdd),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_customHolidays.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            l10n.customHolidayEmpty,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._groupCustomHolidays().map((group) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Dismissible(
                            key: ValueKey(group.groupId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              child: Icon(
                                Icons.delete_outline,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                              ),
                            ),
                            confirmDismiss: (_) async {
                              await _confirmDeleteCustomHoliday(group.groupId);
                              return false;
                            },
                            child: FTile(
                              prefix: Container(
                                width: 4,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: group.type == HolidayType.vacation
                                      ? Colors.orange
                                      : Colors.blue,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              title: Text(
                                group.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                _formatHolidayRange(
                                  group.startDate,
                                  group.endDate,
                                  l10n,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              suffix: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              onPress: () {
                                // Reconstruct entries for editing
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
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ---- 法定节假日 ----
            FCard.raw(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.celebration_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l10n.holidayDataYearLabel(holidayData?.year ?? ''),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (officialHolidays.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            l10n.holidayNoUpcoming,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      ...officialHolidays.map(
                        (h) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Opacity(
                            opacity: h.isPast ? 0.4 : 1.0,
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: h.type == HolidayType.vacation
                                        ? Colors.orange
                                        : Colors.blue,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        h.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        _formatHolidayRange(
                                          h.startDate,
                                          h.endDate,
                                          l10n,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ---- 更新日志 ----
            FCard.raw(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l10n.holidayUpdateLog,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (provider.holidayLogs.isNotEmpty)
                          Text(
                            l10n.holidayUpdateLogCount(
                              provider.holidayLogs.length,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (provider.holidayLogs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '暂无日志',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          itemCount: provider.holidayLogs.length,
                          itemBuilder: (_, i) {
                            final log = provider.holidayLogs[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.timeString,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      log.message,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
