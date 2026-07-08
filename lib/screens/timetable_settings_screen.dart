import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/holiday_log_localizer.dart';
import 'package:university_timetable/l10n/holiday_name_localizer.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logging/app_log_messages.dart';
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
import '../utils/home_page_background.dart';
import '../utils/managed_image_storage.dart';
import '../ui/debug/debug.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/semester_week_count_picker_sheet.dart';
import '../widgets/theme_manage_sheets.dart';
import '../widgets/timetable_text_color_settings.dart';
import '../widgets/timetable_week_preview.dart';
import '../services/android_animation_scale_service.dart';
import '../services/bundled_assets.dart';
import '../services/live_testing_fixture_service.dart';
import '../services/live_testing_trigger.dart';
import '../widgets/bundled_asset_image.dart';
import 'about_screen.dart';
import 'course_overview_screen.dart';
import 'couple_timetable_settings_screen.dart';
import 'data_transfer_screen.dart';
import 'cloud_sync_screen.dart';
import 'lan_edit_screen.dart';
import 'feedback_screen.dart';
import 'live_settings_subpages.dart';
import 'live_diagnostics_log_viewer_screen.dart';
import 'time_scheme_management_screen.dart';
import 'timetable_profiles_screen.dart';
import 'hyperos_showcase_screen.dart';
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
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/appearance'),
            builder: (_) => const _AppearanceSettingsScreen(),
          );
        }

        void openLiveSettings() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/live'),
            builder: (_) => const _LiveSettingsScreen(),
          );
        }

        void openLayoutSettings() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/layout'),
            builder: (_) => const _LayoutSettingsScreen(),
          );
        }

        void openHomeWidgetSettings() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/home-widget'),
            builder: (_) => const _HomeWidgetSettingsScreen(),
          );
        }

        void openHolidaySettings() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/holiday'),
            builder: (_) => const _HolidaySettingsScreen(),
          );
        }

        void openDataTransfer() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/data-transfer'),
            builder: (_) => const DataTransferScreen(),
          );
        }

        void openCoupleTimetable() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/couple-timetable'),
            builder: (_) => const CoupleTimetableSettingsScreen(),
          );
        }

        void openCloudSync() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/cloud-sync'),
            builder: (_) => const CloudSyncScreen(),
          );
        }

        void openLanEdit() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/lan-edit'),
            builder: (_) => const LanEditScreen(),
          );
        }

        void openUserGuide() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/user-guide'),
            builder: (_) => const UserGuideScreen(),
          );
        }

        void openAbout() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/about'),
            builder: (_) => const AboutScreen(),
          );
        }

        void openHyperosShowcase() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/hyperos-showcase'),
            builder: (_) => const HyperosShowcaseScreen(),
          );
        }

        void openFeedback() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/feedback'),
            builder: (_) => const FeedbackScreen(),
          );
        }

        void openProfiles() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/profiles'),
            builder: (_) => const TimetableProfilesScreen(),
          );
        }

        void openCourseOverview() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/course-overview'),
            builder: (_) => const CourseOverviewScreen(),
          );
        }

        return ListenableBuilder(
          listenable: HyperosLayoutTuningController.instance,
          builder: (context, _) {
            return HyperosSubpage(
              overlayHeader: true,
              onBack: () => Navigator.pop(context),
              title: Text(l10n.settingsTitle),
              child: HyperosListView(
                pageStorageKey: const PageStorageKey<String>(
                  'timetable-settings-main',
                ),
                children: [
                  HyperosSummaryCard(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        HyperosSummaryCard.leadingRadius,
                      ),
                      child: BundledAssetImage(
                        assetPath: BundledAssets.launcherIcon,
                        width: HyperosSummaryCard.leadingSize,
                        height: HyperosSummaryCard.leadingSize,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: l10n.semesterOverviewCurrentWeek(
                      provider.currentWeek,
                      settings.semesterWeekCount,
                    ),
                    subtitle: settings.semesterStartDate == null
                        ? l10n.semesterStartUnset
                        : l10n.semesterStartSet(
                            _formatDate(settings.semesterStartDate!),
                          ),
                  ),
                  const HyperosSectionGap(),
                  HyperosListGroup(
                    children: [
                      HyperosListTile(
                        icon: Icons.event_outlined,
                        iconAccent: HyperosIconColors.blue,
                        title: settings.semesterStartDate == null
                            ? l10n.setSemesterStartDateAction
                            : l10n.semesterStartDateAction,
                        details: settings.semesterStartDate == null
                            ? null
                            : _formatDate(settings.semesterStartDate!),
                        onTap: () => _pickSemesterStartDate(context),
                      ),
                      HyperosListTile(
                        icon: Icons.sync_outlined,
                        iconAccent: HyperosIconColors.teal,
                        title: l10n.syncCurrentWeekAction,
                        onTap: settings.semesterStartDate == null
                            ? null
                            : () => _syncCurrentWeek(context),
                      ),
                      HyperosListTile(
                        icon: Icons.view_week_outlined,
                        iconAccent: HyperosIconColors.indigo,
                        title: l10n.selectSemesterWeekCountTitle,
                        details: l10n.semesterWeekCountAction(
                          settings.semesterWeekCount,
                        ),
                        onTap: () => _pickSemesterWeekCount(context),
                      ),
                    ],
                  ),
                  const HyperosSectionGap(),
                  HyperosListGroup(
                    children: [
                      HyperosListTile(
                        icon: Icons.palette_outlined,
                        iconAccent: HyperosIconColors.blue,
                        title: l10n.appearanceEntryTitle,
                        onTap: openAppearance,
                      ),
                      HyperosListTile(
                        icon: Icons.style_outlined,
                        iconAccent: HyperosIconColors.purple,
                        title: l10n.themeManageTitle,
                        onTap: () {
                          HyperosNavigation.push(
                            context,
                            settings: const RouteSettings(
                              name: '/settings/theme',
                            ),
                            builder: (_) => const _ThemeManageScreen(),
                          );
                        },
                      ),
                      HyperosListTile(
                        icon: Icons.view_week_outlined,
                        iconAccent: HyperosIconColors.orange,
                        title: l10n.layoutSectionEntryTitle,
                        onTap: openLayoutSettings,
                      ),
                      HyperosListTile(
                        icon: Icons.widgets_outlined,
                        iconAccent: HyperosIconColors.green,
                        title: l10n.homeWidgetEntryTitle,
                        details: widgetBackgroundStyleLabel(
                          l10n,
                          settings.widgetBackgroundStyle,
                        ),
                        onTap: openHomeWidgetSettings,
                      ),
                      HyperosListTile(
                        icon: Icons.celebration_outlined,
                        iconAccent: HyperosIconColors.yellow,
                        title: l10n.holidaySettingsEntryTitle,
                        onTap: openHolidaySettings,
                      ),
                    ],
                  ),
                  const HyperosSectionGap(),
                  HyperosListGroup(
                    children: [
                      HyperosListTile(
                        icon: Icons.notifications_active_outlined,
                        iconAccent: HyperosIconColors.orange,
                        title: l10n.liveSettingsTitle,
                        onTap: openLiveSettings,
                      ),
                      HyperosListTile(
                        icon: Icons.menu_book_outlined,
                        iconAccent: HyperosIconColors.cyan,
                        title: l10n.userGuideEntryTitle,
                        onTap: openUserGuide,
                      ),
                    ],
                  ),
                  const HyperosSectionGap(),
                  HyperosListGroup(
                    children: [
                      HyperosListTile(
                        icon: Icons.layers_outlined,
                        iconAccent: HyperosIconColors.blue,
                        title: l10n.timetableManagement,
                        onTap: openProfiles,
                      ),
                      HyperosListTile(
                        icon: Icons.dashboard_customize_rounded,
                        iconAccent: HyperosIconColors.purple,
                        title: l10n.courseOverviewTitle,
                        onTap: openCourseOverview,
                      ),
                      HyperosListTile(
                        icon: Icons.schedule_rounded,
                        iconAccent: HyperosIconColors.teal,
                        title: l10n.timeSchemeEntryTitle,
                        details: settings.activeTimeSchemeId == null
                            ? null
                            : provider.activeTimeScheme?.name,
                        onTap: () => _openTimeSchemeQuickSwitcher(context),
                      ),
                      HyperosListTile(
                        icon: Icons.favorite_outline_rounded,
                        iconAccent: HyperosIconColors.purple,
                        title: l10n.coupleTimetableEntryTitle,
                        details: provider.hasPartnerBinding
                            ? l10n.coupleTimetableEntryBound
                            : null,
                        onTap: openCoupleTimetable,
                      ),
                      HyperosListTile(
                        icon: Icons.swap_horiz_rounded,
                        iconAccent: HyperosIconColors.green,
                        title: l10n.dataTransferEntryTitle,
                        onTap: openDataTransfer,
                      ),
                      HyperosListTile(
                        icon: Icons.cloud_sync_rounded,
                        iconAccent: HyperosIconColors.cyan,
                        title: l10n.cloudSyncEntryTitle,
                        onTap: openCloudSync,
                      ),
                      HyperosListTile(
                        icon: Icons.lan_rounded,
                        iconAccent: HyperosIconColors.indigo,
                        title: l10n.lanEditEntryTitle,
                        onTap: openLanEdit,
                      ),
                    ],
                  ),
                  const HyperosSectionGap(),
                  HyperosListGroup(
                    children: [
                      HyperosListTile(
                        icon: Icons.chat_bubble_outline_rounded,
                        iconAccent: HyperosIconColors.green,
                        title: l10n.feedbackEntryTitle,
                        onTap: openFeedback,
                      ),
                      HyperosListTile(
                        icon: Icons.info_outline_rounded,
                        iconAccent: HyperosIconColors.blue,
                        title: l10n.aboutEntryTitle,
                        onTap: openAbout,
                      ),
                      if (!kReleaseMode) ...[
                        HyperosListTile(
                          icon: Icons.view_quilt_outlined,
                          iconAccent: HyperosIconColors.purple,
                          title: '澎湃 UI 组件库',
                          details: '视觉验收',
                          onTap: openHyperosShowcase,
                        ),
                        ListenableBuilder(
                          listenable: DebugTuningPreferences.instance,
                          builder: (context, _) => HyperosSwitchTile(
                            icon: Icons.tune_outlined,
                            iconAccent: HyperosIconColors.purple,
                            title: '显示 UI 调试浮窗',
                            value: DebugTuningPreferences.instance.visible,
                            onChanged:
                                DebugTuningPreferences.instance.setVisible,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const HyperosSectionGap(),
                ],
              ),
            );
          },
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
    await HyperosNavigation.push(
      context,
      settings: const RouteSettings(name: '/settings/time-schemes'),
      builder: (_) => const TimeSchemeManagementScreen(),
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
  static const _appearanceSectionCount = 11;

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

    return FrostedAppearanceScope(
      appearance: FrostedAppearance.fromSettings(_draft),
      child: HyperosSubpage(
        onBack: () => Navigator.pop(context),
        title: Text(l10n.appearanceTitle),
        child: HyperosListView(
          itemCount: _appearanceSectionCount,
          itemBuilder: _buildAppearanceSection,
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final previewCardColor = _draft.timetableUseUnifiedCardColor
        ? _draft.timetableUnifiedCardColor
        : _draft.themeSeedColor;

    final Widget section = switch (index) {
      0 => HyperosCard(
        padding: EdgeInsets.zero,
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
      ),
      1 => HyperosSettingsBlock(
        title: l10n.displayModeTitle,
        child: HyperosListGroup(
          children: [
            HyperosSelectTile<AppThemeMode>(
              label: l10n.themeModeLabel,
              subtitle: l10n.displayModeSubtitle,
              items: {
                for (final v in AppThemeMode.values)
                  appThemeModeLabel(l10n, v): v,
              },
              value: _draft.appThemeMode,
              onChanged: (value) {
                _updateDraft(_draft.copyWith(appThemeMode: value));
              },
            ),
          ],
        ),
      ),
      2 => HyperosSettingsBlock(
        title: l10n.fontSectionTitle,
        child: HyperosListGroup(
          children: [
            HyperosSelectTile<AppFontMode>(
              label: l10n.fontModeLabel,
              sheetDescription: l10n.fontSectionFootnote,
              useSheetForPopup: true,
              items: {
                for (final v in AppFontMode.values)
                  appFontModeLabel(l10n, v): v,
              },
              value: _draft.appFontMode,
              onChanged: (value) {
                _updateDraft(_draft.copyWith(appFontMode: value));
              },
            ),
          ],
        ),
      ),
      3 => HyperosSettingsBlock(
        title: l10n.languageSectionTitle,
        child: HyperosListGroup(
          children: [
            HyperosSelectTile<String>(
              label: l10n.languageModeLabel,
              subtitle: l10n.languageSectionSubtitle,
              items: buildLocaleMenuMap(context),
              value: normalizeLocaleTagForDropdown(_draft.appLocaleTag),
              onChanged: (value) {
                _updateDraft(_draft.copyWith(appLocaleTag: value));
              },
            ),
          ],
        ),
      ),
      4 => HyperosSettingsBlock(
        title: l10n.homeTitleSectionTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            HyperosListGroup(
              children: [
                HyperosSelectTile<HomeTitleStyle>(
                  label: l10n.homeTitleStyleLabel,
                  subtitle: l10n.homeTitleSectionSubtitle,
                  items: {
                    for (final v in HomeTitleStyle.values)
                      homeTitleStyleLabel(l10n, v): v,
                  },
                  value: _draft.homeTitleStyle,
                  onChanged: (value) {
                    _updateDraft(_draft.copyWith(homeTitleStyle: value));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            HyperosControlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeTitleStylePreview(style: _draft.homeTitleStyle),
                  const SizedBox(height: 8),
                  Text(
                    homeTitleStyleDescription(l10n, _draft.homeTitleStyle),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      5 => HyperosSettingsBlock(
        title: l10n.themeSeedSectionTitle,
        child: HyperosListGroup(
          children: [
            HyperosSelectTile<ForuiTheme>(
              label: l10n.themePreset,
              subtitle: l10n.themeSeedSectionSubtitle,
              items: {
                for (final v in ForuiTheme.values) _foruiThemeLabel(v): v,
              },
              value: _draft.foruiTheme,
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(
                    foruiTheme: value,
                    themeSeedColor: value.seedHex,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      6 => HyperosSettingsBlock(
        title: l10n.timetableBackgroundColorSectionTitle,
        child: HyperosListGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HyperosHexColorChipGroup(
                    colorHexes: _backgroundColors,
                    selectedHex: _draft.timetablePageBackgroundColor,
                    colorParser: _colorFromHex,
                    onSelectedHex: (color) {
                      _updateDraft(
                        _draft.copyWith(timetablePageBackgroundColor: color),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.timetableBackgroundColorSectionSubtitle,
                    style: HyperosTypography.sectionDescription(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      7 => HyperosSettingsBlock(
        title: l10n.frostedSheetSectionTitle,
        child: HyperosListGroup(
          children: [
            HyperosSwitchTile(
              title: l10n.frostedBlurEnabledTitle,
              subtitle: l10n.frostedBlurEnabledSubtitle,
              value: _draft.frostedBlurEnabled,
              onChanged: (value) {
                _updateDraft(_draft.copyWith(frostedBlurEnabled: value));
              },
            ),
            HyperosInsetDivider(indent: HyperosTokens.listTileDividerIndent),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FrostedSheetSettingsPreview(
                    provider: provider,
                    settings: _draft,
                    week: provider.currentWeek,
                    blurSigma: _draft.frostedSheetBlurSigma,
                    tintAlpha: _draft.frostedSheetTintAlpha,
                    barrierAlpha: _draft.frostedSheetBarrierAlpha,
                    blurEnabled: _draft.frostedBlurEnabled,
                    onOpenDemoSheet: () =>
                        showFrostedSheetSettingsDemo(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.frostedSheetSectionSubtitle,
                    style: HyperosTypography.sectionDescription(context),
                  ),
                ],
              ),
            ),
            HyperosSliderTile(
              title: l10n.frostedSheetBlurLabel,
              value: _draft.frostedSheetBlurSigma,
              min: 0,
              max: 24,
              divisions: 24,
              valueLabel: _draft.frostedSheetBlurSigma.toStringAsFixed(0),
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(frostedSheetBlurSigma: value),
                  debounce: true,
                );
              },
            ),
            const SizedBox(height: 8),
            HyperosSliderTile(
              title: l10n.frostedSheetTintLabel,
              value: _draft.frostedSheetTintAlpha,
              min: 0,
              max: 0.75,
              divisions: 75,
              valueLabel: '${(_draft.frostedSheetTintAlpha * 100).round()}%',
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(frostedSheetTintAlpha: value),
                  debounce: true,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      8 => HyperosListGroup(
        children: [
          HyperosSwitchTile(
            title: l10n.unifiedCourseCardColorTitle,
            subtitle: l10n.unifiedCourseCardColorSubtitle,
            value: _draft.timetableUseUnifiedCardColor,
            onChanged: (value) {
              _updateDraft(
                _draft.copyWith(timetableUseUnifiedCardColor: value),
              );
            },
          ),
          if (_draft.timetableUseUnifiedCardColor) ...[
            HyperosInsetDivider(indent: HyperosTokens.listTileDividerIndent),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: HyperosHexColorChipGroup(
                colorHexes: _cardColors,
                selectedHex: _draft.timetableUnifiedCardColor,
                colorParser: _colorFromHex,
                onSelectedHex: (color) {
                  _updateDraft(
                    _draft.copyWith(timetableUnifiedCardColor: color),
                  );
                },
              ),
            ),
          ],
        ],
      ),
      9 => HyperosSettingsBlock(
        title: l10n.homePageBackgroundScopeTitle,
        child: HyperosListGroup(
          children: [
            _buildHomePageImageTile(
              context,
              l10n: l10n,
              title: l10n.homePageWallpaperTitle,
              subtitle: l10n.homePageWallpaperSubtitle,
              path: resolveHomePageBackdropImagePath(_draft),
              onPick: _pickHomePageBackdropImage,
              onClear: () {
                evictHomePageImageCache(
                  resolveHomePageBackdropImagePath(_draft),
                );
                _updateDraft(
                  _draft.copyWith(
                    clearHomePageWallpaperPath: true,
                    clearHomePageBackgroundImagePath: true,
                  ),
                );
              },
            ),
            HyperosInsetDivider(indent: HyperosTokens.listTileDividerIndent),
            HyperosSwitchTile(
              title: l10n.homePageBackdropFollowsWeekPagerTitle,
              subtitle: l10n.homePageBackdropFollowsWeekPagerSubtitle,
              value: _draft.homePageBackdropFollowsWeekPager,
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(homePageBackdropFollowsWeekPager: value),
                );
              },
            ),
            HyperosInsetDivider(indent: HyperosTokens.listTileDividerIndent),
            HyperosSwitchTile(
              title: l10n.homePageBackgroundScopeStatusBar,
              value: HomePageBackgroundScope.includes(
                _draft.homePageBackgroundScope,
                HomePageBackgroundScope.statusBar,
              ),
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(
                    homePageBackgroundScope: HomePageBackgroundScope.toggle(
                      _draft.homePageBackgroundScope,
                      HomePageBackgroundScope.statusBar,
                      enabled: value,
                    ),
                  ),
                );
              },
            ),
            HyperosSwitchTile(
              title: l10n.homePageBackgroundScopeHeader,
              value: HomePageBackgroundScope.includes(
                _draft.homePageBackgroundScope,
                HomePageBackgroundScope.header,
              ),
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(
                    homePageBackgroundScope: HomePageBackgroundScope.toggle(
                      _draft.homePageBackgroundScope,
                      HomePageBackgroundScope.header,
                      enabled: value,
                    ),
                  ),
                );
              },
            ),
            HyperosSwitchTile(
              title: l10n.homePageBackgroundScopeWeekdayBar,
              value: HomePageBackgroundScope.includes(
                _draft.homePageBackgroundScope,
                HomePageBackgroundScope.weekdayBar,
              ),
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(
                    homePageBackgroundScope: HomePageBackgroundScope.toggle(
                      _draft.homePageBackgroundScope,
                      HomePageBackgroundScope.weekdayBar,
                      enabled: value,
                    ),
                  ),
                );
              },
            ),
            HyperosSwitchTile(
              title: l10n.homePageBackgroundScopeTimetable,
              value: HomePageBackgroundScope.includes(
                _draft.homePageBackgroundScope,
                HomePageBackgroundScope.timetable,
              ),
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(
                    homePageBackgroundScope: HomePageBackgroundScope.toggle(
                      _draft.homePageBackgroundScope,
                      HomePageBackgroundScope.timetable,
                      enabled: value,
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                l10n.homePageBackgroundScopeSubtitle,
                style: HyperosTypography.sectionDescription(context),
              ),
            ),
            HyperosSwitchTile(
              title: l10n.homePageHeaderBlurTitle,
              subtitle: l10n.homePageHeaderBlurSubtitle,
              value: _draft.homePageHeaderBlurEnabled,
              onChanged: (value) {
                _updateDraft(_draft.copyWith(homePageHeaderBlurEnabled: value));
              },
            ),
            HyperosSwitchTile(
              title: l10n.homePageWeekdayBarBlurTitle,
              subtitle: l10n.homePageWeekdayBarBlurSubtitle,
              value: _draft.homePageWeekdayBarBlurEnabled,
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(homePageWeekdayBarBlurEnabled: value),
                );
              },
            ),
            HyperosSwitchTile(
              title: l10n.homePageTimeColumnBlurTitle,
              subtitle: l10n.homePageTimeColumnBlurSubtitle,
              value: _draft.homePageTimeColumnBlurEnabled,
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(homePageTimeColumnBlurEnabled: value),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                l10n.homePageRegionBlurSectionSubtitle,
                style: HyperosTypography.sectionDescription(context),
              ),
            ),
          ],
        ),
      ),
      10 => TimetableTextColorSettings(
        settings: _draft,
        onChanged: (next) => _updateDraft(next),
      ),
      _ => const SizedBox.shrink(),
    };

    if (index == 0) {
      return section;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [const HyperosSectionGap(), section],
    );
  }

  Widget _buildHomePageImageTile(
    BuildContext context, {
    required AppLocalizations l10n,
    required String title,
    required String subtitle,
    required String? path,
    required Future<void> Function() onPick,
    required VoidCallback onClear,
  }) {
    final fileName = path == null || path.isEmpty
        ? l10n.homePageImageNotSelected
        : path.split(Platform.pathSeparator).last;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: HyperosTypography.sectionDescription(context)),
          const SizedBox(height: 12),
          Text(fileName, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: l10n.homePagePickImageAction,
                  onPressed: () => unawaited(onPick()),
                ),
              ),
              if (path != null && path.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: HyperosButton(
                    label: l10n.homePageClearImageAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: onClear,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickHomePageBackdropImage() async {
    final targetPath = await pickAndStoreManagedImage(
      directoryName: 'home_page_wallpaper',
      filePrefix: 'wallpaper',
    );
    if (!mounted || targetPath == null) {
      return;
    }
    evictHomePageImageCache(resolveHomePageBackdropImagePath(_draft));
    _updateDraft(
      _draft.copyWith(
        homePageWallpaperPath: targetPath,
        clearHomePageBackgroundImagePath: true,
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

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.themeManageTitle),
      child: HyperosListView(
        itemCount: _themeSectionCount,
        itemBuilder: _buildThemeSection,
      ),
    );
  }

  static const _themeSectionCount = 4;

  Widget _buildThemeSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    return switch (index) {
      0 => Consumer<TimetableProvider>(
        builder: (context, provider, child) {
          final settings = provider.settings;
          final checkpointName = settings.themeCheckpointName;
          final hasModifications = settings.hasThemeModifications;

          if (checkpointName == null) return const SizedBox.shrink();

          return HyperosControlCard(
            title: l10n.themeCurrentTheme,
            subtitle: hasModifications
                ? l10n.themeBasedOnModified(checkpointName)
                : checkpointName,
            child: hasModifications
                ? HyperosControlCardInset(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        HyperosButton(
                          label: l10n.themeResetToPreset,
                          variant: HyperosButtonVariant.secondary,
                          onPressed: () {
                            if (settings.themeCheckpointConfig != null) {
                              _applyThemeWithUndo(
                                context,
                                settings.themeCheckpointConfig!,
                                themeName: checkpointName,
                              );
                            }
                          },
                        ),
                        HyperosButton(
                          label: l10n.themeSaveCurrent,
                          variant: HyperosButtonVariant.secondary,
                          onPressed: () => _showSaveThemeDialog(context),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
      1 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.themeManageSubtitle),
          HyperosChoiceGroup(
            children: [
              HyperosActionTile(
                icon: Icons.ios_share_outlined,
                title: l10n.themeExport,
                onTap: () => _exportTheme(context),
                showDivider: true,
              ),
              HyperosActionTile(
                icon: Icons.download_outlined,
                title: l10n.themeImport,
                onTap: () => _importTheme(context),
                showDivider: true,
              ),
              HyperosActionTile(
                icon: Icons.bookmark_add_outlined,
                title: l10n.themeSaveCurrent,
                onTap: () => _showSaveThemeDialog(context),
              ),
            ],
          ),
        ],
      ),
      2 => Consumer<TimetableProvider>(
        builder: (context, provider, child) {
          final current = provider.settings.foruiTheme;
          final themes = ForuiTheme.values;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.themePreset),
              HyperosChoiceGroup(
                children: [
                  for (var i = 0; i < themes.length; i++)
                    HyperosChoiceTile(
                      prefix: HyperosColorDot(
                        color: _colorFromHex(themes[i].seedHex),
                      ),
                      title: _foruiThemeLabel(themes[i]),
                      selected: current == themes[i],
                      showDivider: i < themes.length - 1,
                      onTap: () => _applyForuiTheme(context, themes[i]),
                    ),
                ],
              ),
            ],
          );
        },
      ),
      3 => Consumer<TimetableProvider>(
        builder: (context, provider, child) {
          final savedThemes = provider.settings.savedThemes;
          if (savedThemes.isEmpty) return const SizedBox.shrink();
          final settings = provider.settings;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.themeSaved),
              HyperosChoiceGroup(
                children: [
                  for (var i = 0; i < savedThemes.length; i++)
                    HyperosChoiceTile(
                      prefix: HyperosColorDot(
                        color: _colorFromHex(savedThemeSeedHex(savedThemes[i])),
                      ),
                      title: savedThemes[i].name,
                      subtitle: ThemePreviewDots(
                        colors: savedThemes[i].config.previewColors,
                      ),
                      selected: isSavedThemeSelected(settings, savedThemes[i]),
                      trailing: IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: HyperosColors.secondaryText(context),
                        ),
                        tooltip: l10n.themeMoreActions,
                        onPressed: () =>
                            _showSavedThemeActions(context, savedThemes[i]),
                      ),
                      showDivider: i < savedThemes.length - 1,
                      dividerIndent: 44,
                      onTap: () =>
                          _showSavedThemePreview(context, savedThemes[i]),
                    ),
                ],
              ),
            ],
          );
        },
      ),
      _ => const SizedBox.shrink(),
    };
  }

  // --- theme actions below ---

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
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.liveSettingsTitle),
      child: HyperosListView(
        itemCount: 1,
        itemBuilder: _buildLiveSettingsSection,
      ),
    );
  }

  Widget _buildLiveSettingsSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    final beforeClassSummary = _liveDisplaySummary(
      context,
      _draft.beforeClassDisplaySettings,
    );
    final duringEndSummary = _draft.liveDuringEndFollowBeforeClass
        ? l10n.followBeforeClassSetting
        : _liveDisplaySummary(context, _draft.duringEndDisplaySettings);
    return HyperosListGroup(
      children: [
        HyperosListTile(
          icon: Icons.alarm_outlined,
          title: l10n.liveReminderTimingTitle,
          onTap: () async {
            await HyperosNavigation.push(
              context,
              builder: (_) => const LiveReminderTimingScreen(),
            );
            if (!mounted) return;
            setState(() {
              _draft = context.read<TimetableProvider>().settings;
            });
          },
        ),
        HyperosListTile(
          icon: Icons.upcoming_outlined,
          title: l10n.beforeClassDisplaySettingsTitle,
          details: beforeClassSummary,
          onTap: () async {
            await HyperosNavigation.push(
              context,
              builder: (_) => LiveDisplaySettingsScreen(
                title: l10n.beforeClassDisplaySettingsTitle,
                forDuringEnd: false,
              ),
            );
            if (!mounted) return;
            setState(() {
              _draft = context.read<TimetableProvider>().settings;
            });
          },
        ),
        HyperosListTile(
          icon: Icons.timelapse_rounded,
          title: l10n.duringEndDisplaySettingsTitle,
          details: duringEndSummary,
          onTap: () async {
            await HyperosNavigation.push(
              context,
              builder: (_) => LiveDisplaySettingsScreen(
                title: l10n.duringEndDisplaySettingsTitle,
                forDuringEnd: true,
              ),
            );
            if (!mounted) return;
            setState(() {
              _draft = context.read<TimetableProvider>().settings;
            });
          },
        ),
        HyperosListTile(
          icon: Icons.shield_outlined,
          title: l10n.liveKeepAliveTitle,
          onTap: () async {
            await HyperosNavigation.push(
              context,
              builder: (_) => const LiveKeepAliveSettingsScreen(),
            );
            if (!mounted) return;
            setState(() {
              _draft = context.read<TimetableProvider>().settings;
            });
          },
        ),
        HyperosListTile(
          icon: Icons.science_outlined,
          title: l10n.liveTestingEntryTitle,
          onTap: () async {
            await HyperosNavigation.push(
              context,
              builder: (_) => const _LiveTestingSettingsScreen(),
            );
            if (!mounted) return;
            setState(() {
              _draft = context.read<TimetableProvider>().settings;
            });
          },
        ),
      ],
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
  int _fixtureLeadMinutes = 1;
  bool _installingFixtureGrid = false;
  bool _clearingFixtureGrid = false;

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
      await HyperosNavigation.push(
        context,
        builder: (context) => LiveDiagnosticsLogViewerScreen(
          title: l10n.liveDiagnosticsViewerTitle,
          watchRawLog: () => _liveService.watchLiveDiagnosticsText(),
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
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(exportPath)],
        text: shareText,
        subject: shareSubject,
      ),
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

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.liveTestingTitle),
      child: HyperosListView(
        itemCount: _liveTestingSections().length,
        itemBuilder: (context, index) => _buildLiveTestingSection(
          context,
          _liveTestingSections()[index],
          l10n: l10n,
          summary: summary,
          environment: environment,
          service: service,
          course: course,
          timing: timing,
          switches: switches,
          display: display,
          notification: notification,
          recentDiagnostics: recentDiagnostics,
          serviceRunning: serviceRunning,
          isActuallyPromotable: isActuallyPromotable,
          statusText: statusText,
          notIslandReason: notIslandReason,
          rawDebugJson: rawDebugJson,
          refreshedAtText: refreshedAtText,
        ),
      ),
    );
  }

  List<_LiveTestingSection> _liveTestingSections() => [
    if (!kReleaseMode) _LiveTestingSection.holidayOverride,
    if (!kReleaseMode) _LiveTestingSection.quickFixtures,
    _LiveTestingSection.notification,
    _LiveTestingSection.islandStatus,
    if (_debugStatus != null) ...[
      _LiveTestingSection.debugEnvironment,
      _LiveTestingSection.debugService,
      _LiveTestingSection.debugCourse,
      _LiveTestingSection.debugTiming,
      _LiveTestingSection.debugSwitches,
      _LiveTestingSection.debugDisplay,
      _LiveTestingSection.debugNotification,
      _LiveTestingSection.debugRecentLogs,
      _LiveTestingSection.rawJson,
    ],
    _LiveTestingSection.localLogs,
  ];

  Widget _buildLiveTestingSection(
    BuildContext context,
    _LiveTestingSection section, {
    required AppLocalizations l10n,
    required Map<String, dynamic> summary,
    required Map<String, dynamic> environment,
    required Map<String, dynamic> service,
    required Map<String, dynamic> course,
    required Map<String, dynamic> timing,
    required Map<String, dynamic> switches,
    required Map<String, dynamic> display,
    required Map<String, dynamic> notification,
    required Map<String, dynamic> recentDiagnostics,
    required bool serviceRunning,
    required bool isActuallyPromotable,
    required String statusText,
    required String notIslandReason,
    required String rawDebugJson,
    required String refreshedAtText,
  }) {
    return switch (section) {
      _LiveTestingSection.holidayOverride => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          HyperosSectionLabel(text: l10n.liveTestingHolidayOverride),
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                value: _holidayOverrideEnabled,
                onChanged: (value) {
                  setState(() {
                    _holidayOverrideEnabled = value;
                  });
                  final provider = context.read<TimetableProvider>();
                  provider.updateTimetableSettings(
                    provider.settings.copyWith(holidayOverrideEnabled: value),
                  );
                  provider.refreshLiveActivityNow(forceSnapshotSync: true);
                },
                title: _holidayOverrideEnabled
                    ? l10n.liveTestingHolidayModeEnabled
                    : l10n.liveTestingHolidayModeDisabled,
                subtitle: _holidayOverrideEnabled
                    ? l10n.liveTestingHolidayModeEnabledDesc
                    : l10n.liveTestingHolidayOverrideSubtitle,
              ),
            ],
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.quickFixtures => _buildQuickFixtureSection(context, l10n),
      _LiveTestingSection.notification => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HyperosControlCard(
            title: l10n.liveTestingNotificationTitle,
            subtitle: l10n.liveTestingNotificationSubtitle,
            child: HyperosControlCardInset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HyperosButton(
                    label: l10n.liveTestingSendAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: () async {
                      await _showTestOptions(context);
                      await Future<void>.delayed(
                        const Duration(milliseconds: 300),
                      );
                      await _refreshDebugStatus(showLoading: true);
                    },
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
                        HyperosButton(
                          label: l10n.liveTestingCrashAction,
                          variant: HyperosButtonVariant.secondary,
                          onPressed: () => _triggerUmengTestCrash(context),
                        ),
                        HyperosButton(
                          label: l10n.liveTestingAnrAction,
                          variant: HyperosButtonVariant.secondary,
                          onPressed: () => _triggerUmengTestAnr(context),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.islandStatus => Builder(
        builder: (context) {
          final semesterUnset =
              context.watch<TimetableProvider>().settings.semesterStartDate ==
              null;
          return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HyperosControlCard(
            title: l10n.liveTestingIslandStatusTitle,
            subtitle: l10n.liveTestingIslandStatusSubtitle,
            child: HyperosControlCardInset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (semesterUnset) ...[
                    Text(
                      l10n.pleaseSetSemesterStartDate,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                            HyperosButton(
                              label: _loadingDebugStatus
                                  ? l10n.liveTestingRefreshing
                                  : l10n.liveTestingRefreshAction,
                              variant: HyperosButtonVariant.secondary,
                              loading: _loadingDebugStatus,
                              onPressed: _loadingDebugStatus
                                  ? null
                                  : () =>
                                        _refreshDebugStatus(showLoading: true),
                            ),
                            HyperosButton(
                              label: _exportingDiagnostics
                                  ? l10n.liveTestingExporting
                                  : l10n.liveTestingExportAction,
                              variant: HyperosButtonVariant.secondary,
                              loading: _exportingDiagnostics,
                              onPressed: _exportingDiagnostics
                                  ? null
                                  : _exportLiveDiagnostics,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        HyperosSwitchTile(
                          value: _autoRefreshEnabled,
                          onChanged: (value) {
                            setState(() {
                              _autoRefreshEnabled = value;
                            });
                          },
                          title: l10n.liveTestingAutoRefreshTitle,
                          subtitle: _autoRefreshEnabled
                              ? l10n.liveTestingAutoRefreshOn(
                                  _autoRefreshInterval.inSeconds,
                                )
                              : l10n.liveTestingAutoRefreshOff,
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
          ),
          const HyperosSectionGap(),
        ],
          );
        },
      ),
      _LiveTestingSection.debugEnvironment => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(
            title: l10n.liveTestingSectionEnvironment,
            data: environment,
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugService => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(
            title: l10n.liveTestingSectionService,
            data: service,
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugCourse => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(title: l10n.liveTestingSectionCourse, data: course),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugTiming => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(title: l10n.liveTestingSectionTiming, data: timing),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugSwitches => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(
            title: l10n.liveTestingSectionSwitches,
            data: switches,
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugDisplay => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(
            title: l10n.liveTestingSectionDisplay,
            data: display,
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugNotification => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(
            title: l10n.liveTestingSectionNotification,
            data: notification,
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.debugRecentLogs => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DebugSectionCard(
            title: l10n.liveTestingSectionRecentLogs,
            data: recentDiagnostics,
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.rawJson => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HyperosControlCard(
            title: l10n.liveTestingRawDataTitle,
            subtitle: l10n.liveTestingRawDataSubtitle,
            child: HyperosControlCardInset(
              child: HyperosAccordion(
                items: [
                  HyperosAccordionItem(
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
                    child: Text(
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
          ),
          const HyperosSectionGap(),
        ],
      ),
      _LiveTestingSection.localLogs => HyperosControlCard(
        title: l10n.liveTestingLocalLogsTitle,
        subtitle: l10n.liveTestingLocalLogsSubtitle,
        child: HyperosControlCardInset(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              HyperosButton(
                label: _clearingDiagnostics
                    ? l10n.liveTestingClearingLogs
                    : l10n.liveTestingClearLogsAction,
                variant: HyperosButtonVariant.secondary,
                loading: _clearingDiagnostics,
                onPressed: _clearingDiagnostics ? null : _clearLiveDiagnostics,
              ),
              HyperosButton(
                label: l10n.liveTestingViewPhoneLogsAction,
                variant: HyperosButtonVariant.secondary,
                onPressed: _openLiveDiagnosticsViewer,
              ),
              HyperosButton(
                label: l10n.liveTestingMoreTesterOptionsAction,
                variant: HyperosButtonVariant.secondary,
                onPressed: () {
                  HyperosNavigation.push(
                    context,
                    builder: (_) => const AboutScreen(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    };
  }

  Widget _buildQuickFixtureSection(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final provider = context.watch<TimetableProvider>();
    final now = DateTime.now();
    final currentHour = LiveTestingFixtureService.hourSlotFor(now);
    final nextHour = LiveTestingFixtureService.nextHourSlotFor(now);
    final fixtureCount = provider.courses
        .where(LiveTestingFixtureService.isFixtureCourse)
        .length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HyperosControlCard(
          title: '快捷测试课表',
          subtitle:
              '仅调试版可用。会创建「${LiveTestingFixtureService.timeSchemeName}」时间模板（24 个节次），并在今天生成 00:00–23:00 各一门测试课；测试课 ID 以 ${LiveTestingFixtureService.courseIdPrefix} 开头，可一键清除。',
          child: HyperosControlCardInset(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '课前提醒：$fixtureCount/24 个测试时段已安装',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text('多少分钟后上课', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final minutes
                        in LiveTestingFixtureService.supportedLeadMinutes)
                      ChoiceChip(
                        label: Text('$minutes 分钟'),
                        selected: _fixtureLeadMinutes == minutes,
                        onSelected: (selected) {
                          if (!selected) return;
                          setState(() => _fixtureLeadMinutes = minutes);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    HyperosButton(
                      label:
                          _installingFixtureGrid ? '安装中…' : '安装 24 小时测试课表',
                      variant: HyperosButtonVariant.secondary,
                      onPressed: _installingFixtureGrid
                          ? null
                          : () => _installQuickFixtureGrid(context),
                    ),
                    HyperosButton(
                      label: _clearingFixtureGrid ? '清除中…' : '清除测试课表',
                      variant: HyperosButtonVariant.secondary,
                      onPressed: _clearingFixtureGrid || fixtureCount == 0
                          ? null
                          : () => _clearQuickFixtureGrid(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    HyperosButton(
                      label:
                          '当前时段（${currentHour.toString().padLeft(2, '0')}:00）',
                      variant: HyperosButtonVariant.primary,
                      onPressed: () => _triggerQuickFixtureSlot(
                        context,
                        hour: currentHour,
                        source: 'quick_fixture_current_slot',
                      ),
                    ),
                    HyperosButton(
                      label:
                          '下一时段（${nextHour.toString().padLeft(2, '0')}:00）',
                      variant: HyperosButtonVariant.secondary,
                      onPressed: () => _triggerQuickFixtureSlot(
                        context,
                        hour: nextHour,
                        source: 'quick_fixture_next_slot',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '点选时段：把该时段测试课设为 $_fixtureLeadMinutes 分钟后上课并发送超级岛测试',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 24,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.8,
                  ),
                  itemBuilder: (context, index) {
                    final installed =
                        LiveTestingFixtureService.findFixtureForHour(
                          provider,
                          index,
                        ) !=
                        null;
                    final isCurrent = index == currentHour;
                    final color = tryParseHexColor(
                      LiveTestingFixtureService.colorForHour(index),
                    );
                    return Material(
                      color: (color ?? theme.colorScheme.primaryContainer)
                          .withValues(alpha: isCurrent ? 0.95 : 0.55),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _triggerQuickFixtureSlot(
                          context,
                          hour: index,
                          source: 'quick_fixture_grid',
                        ),
                        child: Center(
                          child: Text(
                            '${index.toString().padLeft(2, '0')}:00'
                            '${installed ? '\n已装' : ''}'
                            '${isCurrent ? '\n现在' : ''}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const HyperosSectionGap(),
      ],
    );
  }

  Future<void> _installQuickFixtureGrid(BuildContext context) async {
    if (_installingFixtureGrid) return;
    setState(() => _installingFixtureGrid = true);
    try {
      final provider = context.read<TimetableProvider>();
      final count = await LiveTestingFixtureService.installTwentyFourHourGrid(
        provider,
      );
      if (!context.mounted) return;
      showAppToast(
        context,
        message: '已安装 $count 个测试时段（今天星期${DateTime.now().weekday}）',
        kind: AppToastKind.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppToast(
        context,
        message: '安装测试课表失败：$e',
        kind: AppToastKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _installingFixtureGrid = false);
      }
    }
  }

  Future<void> _clearQuickFixtureGrid(BuildContext context) async {
    if (_clearingFixtureGrid) return;
    setState(() => _clearingFixtureGrid = true);
    try {
      final provider = context.read<TimetableProvider>();
      final count = await LiveTestingFixtureService.removeAllFixtureCourses(
        provider,
      );
      if (!context.mounted) return;
      showAppToast(
        context,
        message: '已清除 $count 门测试课',
        kind: AppToastKind.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppToast(
        context,
        message: '清除测试课表失败：$e',
        kind: AppToastKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _clearingFixtureGrid = false);
      }
    }
  }

  Future<void> _triggerQuickFixtureSlot(
    BuildContext context, {
    required int hour,
    required String source,
  }) async {
    final provider = context.read<TimetableProvider>();
    final lead = Duration(minutes: _fixtureLeadMinutes);
    final result = await triggerLiveUpdateTestForHourSlot(
      context: context,
      provider: provider,
      hour: hour,
      lead: lead,
      source: source,
    );
    if (!context.mounted) return;
    _showLiveTestingTriggerResult(context, result);
    if (result.status == LiveTestingTriggerStatus.success) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!context.mounted) return;
      await _refreshDebugStatus(showLoading: true);
    }
  }
}

enum _LiveTestingSection {
  holidayOverride,
  quickFixtures,
  notification,
  islandStatus,
  debugEnvironment,
  debugService,
  debugCourse,
  debugTiming,
  debugSwitches,
  debugDisplay,
  debugNotification,
  debugRecentLogs,
  rawJson,
  localLogs,
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
    return HyperosControlCard(
      title: title,
      subtitle: AppLocalizations.of(
        context,
      )!.liveTestingCurrentNativeFieldsSubtitle,
      child: HyperosControlCardInset(
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
            child: Text(
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

void _showLiveTestingTriggerResult(
  BuildContext context,
  LiveTestingTriggerResult result,
) {
  if (result.message == null) return;
  showAppToast(
    context,
    message: result.message!,
    kind: switch (result.status) {
      LiveTestingTriggerStatus.success => AppToastKind.success,
      LiveTestingTriggerStatus.inFlight => AppToastKind.warning,
      LiveTestingTriggerStatus.error => AppToastKind.error,
    },
  );
}

Future<void> _showTestOptions(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  const beforeClassLead = Duration(seconds: 8);

  final provider = context.read<TimetableProvider>();
  await provider.initialize();
  final liveService = MiuiLiveActivitiesService();
  await liveService.initialize();

  final selection = provider.getTestLiveActivityCourseSelection(now: now);
  if (selection == null) {
    await liveService.recordDiagnosticEvent(
      'live_update_test_no_selection',
      AppLogMessages.liveUpdateTestNoSelection,
      extras: {'weekday': now.weekday},
    );
    if (!context.mounted) return;
    showAppToast(
      context,
      message: l10n.liveTestingNoCourseAvailable,
      kind: AppToastKind.warning,
    );
    return;
  }

  final baseCourse = selection.currentCourse;
  final previewNextCourse = selection.nextCourse;
  final resolvedShortName = provider.resolveCourseShortName(baseCourse);
  await liveService.recordDiagnosticEvent(
    'live_update_test_selection_ready',
    AppLogMessages.liveUpdateTestSelectionReady,
    extras: {
      'courseName': baseCourse.name,
      'stage': selection.stage.name,
      'hasNextCourse': previewNextCourse != null,
    },
  );

  final start = now.add(beforeClassLead);
  final end = start.add(LiveTestingFixtureService.defaultCourseDuration);
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
    startTime: LiveTestingFixtureService.formatClock(start),
    endTime: LiveTestingFixtureService.formatClock(end),
    color: baseCourse.color,
    note: l10n.liveTestingTestCourseNote,
  );

  if (!context.mounted) return;

  final result = await triggerLiveUpdateTest(
    context: context,
    provider: provider,
    testCourse: testCourse,
    previewNextCourse: previewNextCourse,
    beforeClassLead: beforeClassLead,
    source: 'settings_screen',
  );
  if (!context.mounted) return;
  _showLiveTestingTriggerResult(context, result);
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
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.homeWidgetSettingsTitle),
      child: HyperosListView(
        itemCount: _homeWidgetSectionCount,
        itemBuilder: _buildHomeWidgetSection,
      ),
    );
  }

  int get _homeWidgetSectionCount => _draft.widgetShowCountdown ? 6 : 5;

  Widget _buildHomeWidgetSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    var section = index;
    if (!_draft.widgetShowCountdown && section >= 3) {
      section += 1;
    }

    final Widget content = switch (section) {
      0 => HyperosControlCard(
        title: l10n.homeWidgetQuickAddTitle,
        subtitle: _isCheckingPinSupport
            ? l10n.homeWidgetCheckingPinSupport
            : (_canRequestPinWidget
                  ? l10n.homeWidgetPinSupported
                  : l10n.homeWidgetPinUnsupported),
        child: HyperosControlCardInset(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPinWidgetButton(HomeWidgetPinTarget.compact22),
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
                    child: _buildPinWidgetButton(HomeWidgetPinTarget.medium24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPinWidgetButton(HomeWidgetPinTarget.large44),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      1 => HyperosControlCard(
        title: l10n.homeWidgetTodayCourseTitle,
        subtitle: l10n.homeWidgetTodayCourseSubtitle,
        edgeToEdge: true,
        child: HyperosControlCardRowScope(
          isFirst: true,
          isLast: false,
          child: HyperosSelectTile<WidgetBackgroundStyle>(
            label: l10n.homeWidgetBackgroundStyleLabel,
            items: {
              for (final v in WidgetBackgroundStyle.values)
                widgetBackgroundStyleLabel(l10n, v): v,
            },
            value: _draft.widgetBackgroundStyle,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(widgetBackgroundStyle: value));
            },
          ),
        ),
      ),
      2 => HyperosListGroup(
        children: [
          HyperosSwitchTile(
            title: l10n.homeWidgetShowLocationTitle,
            subtitle: l10n.homeWidgetShowLocationSubtitle,
            value: _draft.widgetShowLocation,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(widgetShowLocation: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.homeWidgetShowCountdownTitle,
            subtitle: l10n.homeWidgetShowCountdownSubtitle,
            value: _draft.widgetShowCountdown,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(widgetShowCountdown: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.homeWidgetHideCompletedTitle,
            subtitle: l10n.homeWidgetHideCompletedSubtitle,
            value: _draft.widgetHideCompletedCourses,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(widgetHideCompletedCourses: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.homeWidgetShowTomorrowTitle,
            subtitle: l10n.homeWidgetShowTomorrowSubtitle,
            value: _draft.widgetShowTomorrowCourses,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(widgetShowTomorrowCourses: value));
            },
          ),
        ],
      ),
      3 => HyperosControlCard(
        title: l10n.homeWidgetCountdownLeadTitle,
        subtitle: l10n.homeWidgetCountdownLeadSubtitle,
        edgeToEdge: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            HyperosSelectTile<int>(
              label: l10n.homeWidgetCountdownLeadTitle,
              items: {
                l10n.homeWidgetCountdownLeadAlways: 0,
                for (final m in const [1, 5, 10, 15, 20, 30, 40, 50, 60])
                  l10n.beforeClassMinutesOption(m): m,
              },
              value: _draft.widgetCountdownLeadMinutes,
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(widgetCountdownLeadMinutes: value),
                );
              },
            ),
            HyperosSelectTile<LiveCountdownTextStyle>(
              label: l10n.widgetCountdownStyleTitle,
              items: {
                for (final v in LiveCountdownTextStyle.values)
                  liveCountdownTextStyleLabel(l10n, v): v,
              },
              value: _draft.widgetCountdownTextStyle,
              onChanged: (value) {
                _updateDraft(_draft.copyWith(widgetCountdownTextStyle: value));
              },
            ),
          ],
        ),
      ),
      4 => HyperosControlCard(
        title: l10n.homeWidgetHeightAdjustTitle,
        child: HyperosControlCardInset(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              HyperosSliderTile(
                title: _widgetHeightAdjustmentLabel(l10n),
                value: _draft.widgetHeightAdjustment,
                min: _defaultWidgetHeightAdjustment - 16,
                max: _defaultWidgetHeightAdjustment + 16,
                divisions: 32,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(widgetHeightAdjustment: value),
                  debounce: true,
                ),
              ),
              const SizedBox(height: 12),
              HyperosSliderTile(
                title: l10n.homeWidgetCornerRadiusTitle,
                valueLabel: '${_draft.widgetCornerRadius.toStringAsFixed(0)}dp',
                value: _draft.widgetCornerRadius,
                min: _defaultWidgetCornerRadius - 14,
                max: _defaultWidgetCornerRadius + 14,
                divisions: 28,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(widgetCornerRadius: value),
                  debounce: true,
                ),
              ),
            ],
          ),
        ),
      ),
      _ => const SizedBox.shrink(),
    };

    if (index == 0) {
      return content;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [const HyperosSectionGap(), content],
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
      child: HyperosButton(
        label: _homeWidgetTargetLabel(context, target),
        variant: HyperosButtonVariant.secondary,
        expand: true,
        loading: isLoading,
        onPressed: isLoading ? null : () => _requestPinWidget(target),
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
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.layoutSettingsTitle),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey<String>('layout-settings-preview'),
              child: HyperosBlurredBodyInset(
                child: TimetableWeekPreview(
                  provider: provider,
                  settings: _draft,
                  week: provider.currentWeek,
                  maxVisibleSections: _draft.sectionCount,
                ),
              ),
            ),
          ),
          Expanded(
            child: HyperosListView(
              includeHeaderInset: false,
              pageStorageKey: const PageStorageKey<String>(
                'layout-settings-editor',
              ),
              itemCount: _layoutSectionCount,
              itemBuilder: _buildLayoutSection,
            ),
          ),
        ],
      ),
    );
  }

  static const _layoutSectionCount = 14;

  Widget _buildLayoutSection(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    return switch (index) {
      0 => HyperosListGroup(
        children: [
          HyperosSwitchTile(
            title: l10n.layoutAutoFitHeightTitle,
            value: _draft.timetableAutoFitSectionHeight,
            onChanged: (value) {
              _updateDraft(
                _draft.copyWith(timetableAutoFitSectionHeight: value),
              );
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutHideWeekendsTitle,
            value: _draft.timetableHideWeekends,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(timetableHideWeekends: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutEnableHapticsTitle,
            value: _draft.enableHaptics,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(enableHaptics: value));
            },
          ),
        ],
      ),
      1 => HyperosControlCard(
        subtitle: l10n.pageTransitionSpeedSubtitle,
        edgeToEdge: true,
        child: HyperosSliderTile(
          title: l10n.pageTransitionSpeedLabel(
            _draft.pageTransitionSpeed.toStringAsFixed(1),
          ),
          value: _draft.pageTransitionSpeed,
          min: TimetableSettings.minPageTransitionSpeed,
          max: TimetableSettings.maxPageTransitionSpeed,
          divisions: 20,
          valueLabel: l10n.pageTransitionSpeedDurationHint(
            AndroidAnimationScaleService.scaledDuration(
              HyperosMiuixNavigation.transitionDurationMs,
            ).inMilliseconds,
          ),
          onChanged: (value) {
            HyperosNavigation.applyUserTransitionSpeed(value);
            _updateDraft(
              _draft.copyWith(pageTransitionSpeed: value),
              debounce: true,
            );
          },
        ),
      ),
      2 => const HyperosSectionGap(),
      3 => HyperosControlCard(
        subtitle: l10n.layoutEntrySubtitle,
        edgeToEdge: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HyperosSelectTile<SectionTimeDisplayMode>(
              label: l10n.layoutTimeColumnDisplayLabel,
              items: {
                for (final v in SectionTimeDisplayMode.values)
                  sectionTimeDisplayModeLabel(l10n, v): v,
              },
              value: _draft.timetableSectionTimeDisplayMode,
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(timetableSectionTimeDisplayMode: value),
                );
              },
            ),
            const SizedBox(height: 12),
            HyperosSelectTile<TimetableTimeColumnWidthMode>(
              label: l10n.layoutTimeColumnWidthLabel,
              items: {
                for (final v in TimetableTimeColumnWidthMode.values)
                  timetableTimeColumnWidthModeLabel(l10n, v): v,
              },
              value: _draft.timetableTimeColumnWidthMode,
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(timetableTimeColumnWidthMode: value),
                );
              },
            ),
            const SizedBox(height: 12),
            HyperosSelectTile<BackToCurrentWeekButtonStyle>(
              label: l10n.layoutBackToCurrentWeekButtonStyleLabel,
              items: {
                for (final v in BackToCurrentWeekButtonStyle.values)
                  _backToCurrentWeekButtonStyleLabel(l10n, v): v,
              },
              value: _draft.timetableBackToCurrentWeekButtonStyle,
              onChanged: (value) {
                _updateDraft(
                  _draft.copyWith(timetableBackToCurrentWeekButtonStyle: value),
                );
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HyperosControlCardScope.defaultHorizontalPadding,
              ),
              child: Text(
                l10n.layoutBackToCurrentWeekButtonStyleHelper,
                style: HyperosTypography.sectionDescription(context),
                softWrap: true,
              ),
            ),
            if (_draft.timetableBackToCurrentWeekButtonStyle ==
                BackToCurrentWeekButtonStyle.floating) ...[
              const SizedBox(height: 12),
              HyperosSliderTile(
                title: l10n.layoutBackToCurrentWeekButtonOpacityLabel(
                  (_draft.timetableFloatingBackToCurrentWeekButtonOpacity * 100)
                      .round(),
                ),
                value: _draft.timetableFloatingBackToCurrentWeekButtonOpacity,
                min: 0.55,
                max: 1.0,
                divisions: 9,
                onChanged: (value) => _updateDraft(
                  _draft.copyWith(
                    timetableFloatingBackToCurrentWeekButtonOpacity: value,
                  ),
                  debounce: true,
                ),
              ),
            ],
            const SizedBox(height: 12),
            HyperosSliderTile(
              title: l10n.layoutCourseCardGapLabel(
                _draft.timetableCourseCardGap.toStringAsFixed(1),
              ),
              value: _draft.timetableCourseCardGap,
              min: 0,
              max: 3,
              divisions: 12,
              onChanged: (value) => _updateDraft(
                _draft.copyWith(timetableCourseCardGap: value),
                debounce: true,
              ),
            ),
            const SizedBox(height: 12),
            HyperosSliderTile(
              title: l10n.layoutSectionHeightLabel(
                _draft.sectionHeight.toStringAsFixed(0),
              ),
              value: _draft.sectionHeight,
              min: 48,
              max: 92,
              divisions: 11,
              enabled: !_draft.timetableAutoFitSectionHeight,
              onChanged: !_draft.timetableAutoFitSectionHeight
                  ? (value) => _updateDraft(
                      _draft.copyWith(sectionHeight: value),
                      debounce: true,
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            HyperosSliderTile(
              title: l10n.layoutCompactFontSizeLabel(
                _draft.compactFontSize.toStringAsFixed(1),
              ),
              value: _draft.compactFontSize,
              min: 7,
              max: 12,
              divisions: 10,
              onChanged: (value) => _updateDraft(
                _draft.copyWith(compactFontSize: value),
                debounce: true,
              ),
            ),
            const SizedBox(height: 12),
            HyperosSliderTile(
              title: l10n.layoutCourseCardFontSizeLabel(
                _draft.courseCardFontSize.toStringAsFixed(1),
              ),
              value: _draft.courseCardFontSize,
              min: 7,
              max: 12,
              divisions: 10,
              onChanged: (value) => _updateDraft(
                _draft.copyWith(courseCardFontSize: value),
                debounce: true,
              ),
            ),
          ],
        ),
      ),
      4 => const HyperosSectionGap(),
      5 => HyperosSectionLabel(text: l10n.layoutCourseCardDisplayTitle),
      6 => HyperosListGroup(
        children: [
          HyperosSwitchTile(
            title: l10n.showCourseNameTitle,
            value: _draft.courseCardShowName,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(courseCardShowName: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowTeacherTitle,
            value: _draft.courseCardShowTeacher,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(courseCardShowTeacher: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowClassroomTitle,
            value: _draft.courseCardShowLocation,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(courseCardShowLocation: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowTimeTitle,
            value: _draft.courseCardShowTime,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(courseCardShowTime: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowTimeLabelsTitle,
            value: _draft.courseCardShowTimeLabels,
            onChanged: _draft.courseCardShowTime
                ? (value) {
                    _updateDraft(
                      _draft.copyWith(courseCardShowTimeLabels: value),
                    );
                  }
                : null,
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowWeeksTitle,
            value: _draft.courseCardShowWeeks,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(courseCardShowWeeks: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowDescriptionTitle,
            value: _draft.courseCardShowDescription,
            onChanged: (value) {
              _updateDraft(_draft.copyWith(courseCardShowDescription: value));
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowOtherWeeksTitle,
            value: _draft.timetableShowNonCurrentWeekCourses,
            onChanged: (value) {
              _updateDraft(
                _draft.copyWith(timetableShowNonCurrentWeekCourses: value),
              );
            },
          ),
          HyperosSwitchTile(
            title: l10n.layoutShowConflictBadgeTitle,
            value: _draft.showConflictBadgeOnTimetable,
            onChanged: (value) {
              _updateDraft(
                _draft.copyWith(showConflictBadgeOnTimetable: value),
              );
            },
          ),
        ],
      ),
      7 => HyperosSectionDescription(
        text: l10n.layoutCourseCardDisplaySubtitle,
      ),
      8 => const HyperosSectionGap(),
      9 => HyperosControlCard(
        edgeToEdge: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HyperosSelectTile<CourseCardVerticalAlign>(
              label: l10n.layoutVerticalAlignLabel,
              items: {
                for (final v in CourseCardVerticalAlign.values)
                  courseCardVerticalAlignLabel(l10n, v): v,
              },
              value: _draft.courseCardVerticalAlign,
              onChanged: (value) {
                _updateDraft(_draft.copyWith(courseCardVerticalAlign: value));
              },
            ),
            const SizedBox(height: 12),
            HyperosSelectTile<CourseCardHorizontalAlign>(
              label: l10n.layoutHorizontalAlignLabel,
              items: {
                for (final v in CourseCardHorizontalAlign.values)
                  courseCardHorizontalAlignLabel(l10n, v): v,
              },
              value: _draft.courseCardHorizontalAlign,
              onChanged: (value) {
                _updateDraft(_draft.copyWith(courseCardHorizontalAlign: value));
              },
            ),
          ],
        ),
      ),
      10 => const HyperosSectionGap(),
      11 => HyperosControlCard(
        title: l10n.layoutConflictOpacityLabel(
          (_draft.timetableConflictCourseOpacity * 100).round(),
        ),
        subtitle: l10n.layoutConflictOpacitySubtitle,
        child: HyperosSliderTile(
          value: _draft.timetableConflictCourseOpacity,
          min: 0.2,
          max: 1.0,
          divisions: 16,
          onChanged: (value) => _updateDraft(
            _draft.copyWith(timetableConflictCourseOpacity: value),
            debounce: true,
          ),
        ),
      ),
      12 => const HyperosSectionGap(),
      13 => HyperosControlCard(
        title: l10n.textColorTitle,
        subtitle: l10n.textColorSubtitle,
        edgeToEdge: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HyperosSwitchTile(
              title: l10n.textColorIndependentDetail,
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
                  _updateDraft(_draft.copyWith(linkCourseCardColors: false));
                }
              },
            ),
            HyperosControlCardInset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                          _draft.copyWith(courseCardTitleColorLight: color),
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
                    defaultAccentColor:
                        TimetableSettings.defaultWeekdayBarAccentColorLight,
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
                          _draft.copyWith(courseCardTitleColorDark: color),
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
                    defaultAccentColor:
                        TimetableSettings.defaultWeekdayBarAccentColorDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _ => const SizedBox.shrink(),
    };
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

    showHyperosDialog<void>(
      context: context,
      title: l10n.textColorSelectColor,
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
      actions: [
        if (defaultValue != null &&
            defaultValue.toLowerCase() != currentColor.toLowerCase())
          HyperosDialogAction(
            label: l10n.resetDefaultAction,
            onPressed: () {
              onColorSelected(defaultValue);
              Navigator.pop(context);
            },
          ),
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context),
        ),
        HyperosDialogAction(
          label: l10n.confirmAction,
          isPrimary: true,
          onPressed: () {
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
            if (bgColorForContrast != null) {
              _checkContrastAndWarn(context, selectedHex, bgColorForContrast);
            }
          },
        ),
      ],
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
    parts.add(l10n.liveDisplaySummaryCountdownShort);
  } else if (settings.showStageText) {
    parts.add(l10n.liveDisplaySummaryStageText);
  }
  if (settings.enableMiuiIslandLabelImage) {
    parts.add(l10n.liveDisplaySummaryLeftLabelImage);
  }
  if (parts.isEmpty) {
    return l10n.liveDisplaySummaryMinimal;
  }
  if (parts.length <= 2) {
    return parts.join('·');
  }
  return l10n.liveDisplaySummaryMore(parts.first, parts.length);
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

    final result = await showHyperosSheet<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return HyperosSheetFrame(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing != null
                          ? l10n.customHolidayEdit
                          : l10n.customHolidayAdd,
                      style: HyperosTypography.sheetTitle(ctx),
                    ),
                    const SizedBox(height: 12),
                    HyperosTextField(
                      controller: nameController,
                      label: l10n.customHolidayNameLabel,
                    ),
                    const SizedBox(height: 12),
                    HyperosListGroup(
                      children: [
                        HyperosChoiceTile(
                          prefix: Icon(
                            Icons.date_range,
                            size: 18,
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                          title:
                              '${l10n.customHolidayStartDate} / ${l10n.customHolidayEndDate}',
                          subtitle: Text(
                            startDate != null && endDate != null
                                ? '${startDate!.month}/${startDate!.day} — ${endDate!.month}/${endDate!.day}'
                                : '--',
                          ),
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.customHolidayType,
                      style: HyperosTypography.sectionLabel(ctx),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: HyperosSegmentedControl(
                        tabs: [
                          l10n.customHolidayTypeVacation,
                          l10n.customHolidayTypeWorkday,
                        ],
                        selectedIndex: selectedType == HolidayType.vacation
                            ? 0
                            : 1,
                        onChanged: (index) {
                          setDialogState(() {
                            selectedType = index == 0
                                ? HolidayType.vacation
                                : HolidayType.adjustedWorkday;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: HyperosFrostedSheetButton(
                            label: MaterialLocalizations.of(
                              ctx,
                            ).cancelButtonLabel,
                            expand: true,
                            bordered: true,
                            onPressed: () => Navigator.pop(ctx, false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: HyperosButton(
                            label: MaterialLocalizations.of(ctx).okButtonLabel,
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
                              Navigator.pop(ctx, true);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
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
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.customHolidayDelete,
      message: l10n.customHolidayDeleteConfirm,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      confirmLabel: l10n.customHolidayDelete,
      destructive: true,
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
      child: HyperosListView(
        itemCount: _holidaySectionCount,
        itemBuilder: (context, index) => _buildHolidaySection(
          context,
          index,
          l10n: l10n,
          provider: provider,
          holidayData: holidayData,
          officialHolidays: officialHolidays,
        ),
      ),
    );
  }

  static const _holidaySectionCount = 4;

  Widget _buildHolidaySection(
    BuildContext context,
    int index, {
    required AppLocalizations l10n,
    required TimetableProvider provider,
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
        children: [
          HyperosCard(
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    HyperosButton(
                      label: l10n.customHolidayAdd,
                      variant: HyperosButtonVariant.secondary,
                      onPressed: () => _showCustomHolidayDialog(),
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          color: Theme.of(context).colorScheme.errorContainer,
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
                        child: HyperosChoiceTile(
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
                          title: group.name,
                          subtitle: Text(
                            _formatHolidayRange(
                              group.startDate,
                              group.endDate,
                              l10n,
                            ),
                          ),
                          trailing: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Theme.of(context).colorScheme.error,
                          ),
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
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          const HyperosSectionGap(),
        ],
      ),
      2 => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HyperosCard(
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
          const HyperosSectionGap(),
        ],
      ),
      _ => HyperosCard(
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (provider.holidayLogs.isNotEmpty)
                  Text(
                    l10n.holidayUpdateLogCount(provider.holidayLogs.length),
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.zero,
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
                              HolidayLogLocalizer.localize(l10n, log.message),
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
