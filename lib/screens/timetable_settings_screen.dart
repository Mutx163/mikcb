import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/holiday_log_localizer.dart';
import 'package:university_timetable/l10n/holiday_name_localizer.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

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
import '../widgets/wallpaper_position_picker_sheet.dart';
import '../widgets/preblurred_wallpaper_glass.dart';
import '../ui/app_fonts.dart';
import '../ui/debug/debug.dart';
import '../widgets/frosted_sheet_settings_preview.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/semester_week_count_picker_sheet.dart';
import '../widgets/miuix_date_picker_sheet.dart';
import '../widgets/theme_manage_sheets.dart';
import '../widgets/timetable_text_color_settings.dart';
import '../widgets/timetable_week_preview.dart';
import '../widgets/course_field_picker_sheet.dart';
import '../services/bundled_assets.dart';
import '../services/live_testing_trigger.dart';
import '../widgets/bundled_asset_image.dart';
import '../services/memory_stats_service.dart';
import 'about_screen.dart';
import 'couple_timetable_settings_screen.dart';
import 'data_transfer_screen.dart';
import 'cloud_sync_screen.dart';
import 'lan_edit_screen.dart';
import 'memory_stats_screen.dart';
import 'live_settings_subpages.dart';
import 'log_viewer_entry.dart';
import 'live_testing_fixture_screen.dart';
import 'time_scheme_management_screen.dart';
import 'timetable_profiles_screen.dart';
import 'hyperos_showcase_screen.dart';
import 'miuix_showcase_screen.dart';
import 'user_guide_screen.dart';
import 'advanced_material_settings_screen.dart';

part 'settings/settings_appearance.dart';
part 'settings/settings_reset.dart';
part 'settings/settings_diagnostics.dart';
part 'settings/settings_course_card.dart';
part 'settings/settings_general.dart';
part 'settings/settings_live.dart';
part 'settings/settings_timetable_page.dart';
part 'settings/settings_home_widget.dart';
part 'settings/settings_holiday.dart';

String formatLiveTimeCorrection(AppLocalizations l10n, int seconds) {
  if (seconds == 0) {
    return l10n.liveTimeCorrectionNone;
  }
  if (seconds > 0) {
    return l10n.liveTimeCorrectionDelay(seconds);
  }
  return l10n.liveTimeCorrectionAdvance(seconds.abs());
}

class TimetableSettingsScreen extends StatelessWidget {
  const TimetableSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final l10n = AppLocalizations.of(context)!;
        final settings = provider.settings;
        void openSemesterSettings() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/semester'),
            builder: (_) => const _SemesterSettingsScreen(),
          );
        }

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

        void openCourseCardSettings() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/course-card'),
            builder: (_) => const _CourseCardSettingsScreen(),
          );
        }

        void openTimetablePageSettings() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/timetable-page'),
            builder: (_) => const _TimetablePageSettingsScreen(),
          );
        }

        void openGeneralSettings() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/general'),
            builder: (_) => const _GeneralSettingsScreen(),
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
            // Canonical name; deep link also accepts `/settings/couple`.
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

        void openDiagnostics() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/diagnostics'),
            builder: (_) => const _DiagnosticsScreen(),
          );
        }

        void openHyperosShowcase() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/hyperos-showcase'),
            builder: (_) => const HyperosShowcaseScreen(),
          );
        }

        void openMiuixShowcase() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/miuix-showcase'),
            builder: (_) => const MiuixShowcaseScreen(),
          );
        }

        void openMemoryStats() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/memory-stats'),
            builder: (_) => const MemoryStatsScreen(),
          );
        }

        void openLiveTestingFixture() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(
              name: '/settings/live-testing-fixture',
            ),
            builder: (_) => const LiveTestingFixtureScreen(),
          );
        }

        void openProfiles() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/profiles'),
            builder: (_) => const TimetableProfilesScreen(),
          );
        }

        // Settings home: same HyperosSubpage shell as every subpage —
        // unified collapsible large title + frosted/liquid-glass chrome.
        // (The old bespoke _MiuixSettingsHomeShell painted the bar with an
        // opaque background OVER its frost layer, so blur never showed.)
        return HyperosSubpage(
          title: Text(l10n.settingsTitle),
          onBack: () => Navigator.pop(context),
          child: HyperosListView(
            // Inset lives inside the scrollable (like HyperosSubpage) so
            // rows can pass under the frosted/liquid-glass top bar.
            includeHeaderInset: true,
            blockVerticalScrollBubbling: false,
            pageStorageKey: const PageStorageKey<String>(
              'timetable-settings-main',
            ),
            // Lazy builder: only visible sections are mounted, reducing
            // per-frame composite cost vs the old SingleChildScrollView.
            itemCount: 8,
            itemBuilder: (context, index) => _buildSettingsHomeSection(
              context,
              index,
              provider: provider,
              settings: settings,
              l10n: l10n,
              openSemesterSettings: openSemesterSettings,
              openProfiles: openProfiles,
              openHolidaySettings: openHolidaySettings,
              openCourseCardSettings: openCourseCardSettings,
              openTimetablePageSettings: openTimetablePageSettings,
              openLiveSettings: openLiveSettings,
              openHomeWidgetSettings: openHomeWidgetSettings,
              openAppearance: openAppearance,
              openGeneralSettings: openGeneralSettings,
              openDataTransfer: openDataTransfer,
              openCloudSync: openCloudSync,
              openLanEdit: openLanEdit,
              openCoupleTimetable: openCoupleTimetable,
              openAbout: openAbout,
              openUserGuide: openUserGuide,
              openDiagnostics: openDiagnostics,
              openMemoryStats: openMemoryStats,
              openLiveTestingFixture: openLiveTestingFixture,
              openHyperosShowcase: openHyperosShowcase,
              openMiuixShowcase: openMiuixShowcase,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTimeSchemeQuickSwitcher(BuildContext context) async {
    await HyperosNavigation.push(
      context,
      settings: const RouteSettings(name: '/settings/time-schemes'),
      builder: (_) => const TimeSchemeManagementScreen(),
    );
  }

  /// Lazy section builder for the settings home list.
  ///
  /// Sections: 0 summary · 1 timetable · 2 display · 3 reminder/desktop
  /// · 4 app · 5 data/share · 6 about · 7 developer tools.
  Widget _buildSettingsHomeSection(
    BuildContext context,
    int index, {
    required TimetableProvider provider,
    required TimetableSettings settings,
    required AppLocalizations l10n,
    required VoidCallback openSemesterSettings,
    required VoidCallback openProfiles,
    required VoidCallback openHolidaySettings,
    required VoidCallback openCourseCardSettings,
    required VoidCallback openTimetablePageSettings,
    required VoidCallback openLiveSettings,
    required VoidCallback openHomeWidgetSettings,
    required VoidCallback openAppearance,
    required VoidCallback openGeneralSettings,
    required VoidCallback openDataTransfer,
    required VoidCallback openCloudSync,
    required VoidCallback openLanEdit,
    required VoidCallback openCoupleTimetable,
    required VoidCallback openAbout,
    required VoidCallback openUserGuide,
    required VoidCallback openDiagnostics,
    required VoidCallback openMemoryStats,
    required VoidCallback openLiveTestingFixture,
    required VoidCallback openHyperosShowcase,
    required VoidCallback openMiuixShowcase,
  }) {
    return switch (index) {
      // 0 — Summary card (semester overview).
      0 => HyperosSummaryCard(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(HyperosSummaryCard.leadingRadius),
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
            : l10n.semesterStartSet(_formatDate(settings.semesterStartDate!)),
        onTap: openSemesterSettings,
      ),
      // 1 — Timetable management.
      1 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.settingsTimetableSectionTitle),
          HyperosListGroup(
            children: [
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('layers')!,
                  HyperosIconColors.blue,
                ),
                title: l10n.timetableManagement,
                endActions: provider.activeProfile?.name != null
                    ? [
                        Text(
                          provider.activeProfile!.name,
                          style: HyperosTypography.listDetail(context),
                        ),
                      ]
                    : null,
                onClick: openProfiles,
              ),
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('weeks')!,
                  HyperosIconColors.teal,
                ),
                title: l10n.timeSchemeEntryTitle,
                endActions: provider.activeTimeScheme?.name != null
                    ? [
                        Text(
                          provider.activeTimeScheme!.name,
                          style: HyperosTypography.listDetail(context),
                        ),
                      ]
                    : null,
                onClick: () => _openTimeSchemeQuickSwitcher(context),
              ),
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('favorites')!,
                  HyperosIconColors.yellow,
                ),
                title: l10n.holidaySettingsEntryTitle,
                endActions: [
                  Text(
                    settings.enableHolidayMarking
                        ? l10n.liveIslandLabelEntryEnabled
                        : l10n.liveIslandLabelEntryDisabled,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
                onClick: openHolidaySettings,
              ),
            ],
          ),
        ],
      ),
      // 2 — Display & appearance (course card / timetable page).
      2 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.settingsDisplayAppearanceSectionTitle),
          HyperosListGroup(
            children: [
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('gridView')!,
                  HyperosIconColors.purple,
                ),
                title: l10n.courseCardSettingsTitle,
                onClick: openCourseCardSettings,
              ),
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('months')!,
                  HyperosIconColors.orange,
                ),
                title: l10n.timetablePageSettingsTitle,
                onClick: openTimetablePageSettings,
              ),
            ],
          ),
        ],
      ),
      // 3 — Reminder & desktop (live island / home widget).
      3 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.settingsReminderDesktopSectionTitle),
          HyperosListGroup(
            children: [
              _LiveEntryTile(onTap: openLiveSettings),
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('home')!,
                  HyperosIconColors.green,
                ),
                title: l10n.homeWidgetEntryTitle,
                onClick: openHomeWidgetSettings,
              ),
            ],
          ),
        ],
      ),
      // 4 — App-level (appearance / general).
      4 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.settingsAppSectionTitle),
          HyperosListGroup(
            children: [
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('theme')!,
                  HyperosIconColors.blue,
                ),
                title: l10n.appearanceEntryTitle,
                onClick: openAppearance,
              ),
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('tune')!,
                  HyperosIconColors.indigo,
                ),
                title: l10n.generalSettingsTitle,
                onClick: openGeneralSettings,
              ),
            ],
          ),
        ],
      ),
      // 5 — Data & sharing.
      5 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.settingsDataShareSectionTitle),
          HyperosListGroup(
            children: [
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('convertFile')!,
                  HyperosIconColors.green,
                ),
                title: l10n.dataTransferEntryTitle,
                onClick: openDataTransfer,
              ),
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('backup')!,
                  HyperosIconColors.cyan,
                ),
                title: l10n.cloudSyncEntryTitle,
                onClick: openCloudSync,
              ),
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('link')!,
                  HyperosIconColors.indigo,
                ),
                title: l10n.lanEditEntryTitle,
                onClick: openLanEdit,
              ),
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('favoritesFill')!,
                  HyperosIconColors.purple,
                ),
                title: l10n.coupleTimetableEntryTitle,
                endActions: [
                  Text(
                    provider.hasPartnerBinding
                        ? l10n.coupleTimetableEntryBound
                        : l10n.coupleTimetableEntryUnboundLabel,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
                onClick: openCoupleTimetable,
              ),
            ],
          ),
        ],
      ),
      // 6 — About & help.
      6 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.settingsAboutSectionTitle),
          HyperosListGroup(
            children: [
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('info')!,
                  HyperosIconColors.blue,
                ),
                title: l10n.aboutEntryTitle,
                onClick: openAbout,
              ),
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('notes')!,
                  HyperosIconColors.cyan,
                ),
                title: l10n.userGuideEntryTitle,
                onClick: openUserGuide,
              ),
              _MiuixSettingsPreference(
                startAction: _settingsIconBadge(
                  MiuixIcons.extended.byName('help')!,
                  HyperosIconColors.teal,
                ),
                title: l10n.diagnosticsEntryTitle,
                endActions: [
                  Text(
                    l10n.diagnosticsEntrySubtitle,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
                onClick: openDiagnostics,
              ),
            ],
          ),
        ],
      ),
      // 7 — Developer tools + trailing gap.
      _ => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsDeveloperListGroup(
            onOpenMemoryStats: openMemoryStats,
            onOpenLiveTestingFixture: openLiveTestingFixture,
            onOpenHyperosShowcase: openHyperosShowcase,
            onOpenMiuixShowcase: openMiuixShowcase,
          ),
          const HyperosSectionGap(),
        ],
      ),
    };
  }
}

/// 学期设置：开学日期 / 学期周数 / 同步当前周。
///
/// 从设置首页整组移入，由首页摘要卡承载入口——摘要卡本就显示周次与开学日期，
/// 让它同时成为编辑入口，比再列一组同义条目更短。
class _SemesterSettingsScreen extends StatelessWidget {
  const _SemesterSettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final l10n = AppLocalizations.of(context)!;
        final settings = provider.settings;
        return HyperosSubpage(
          onBack: () => Navigator.pop(context),
          title: Text(l10n.settingsSemesterScreenTitle),
          child: HyperosListView(
            pageStorageKey: const PageStorageKey<String>('settings-semester'),
            children: [
              HyperosListGroup(
                children: [
                  _MiuixSettingsPreference(
                    startAction: _settingsIconBadge(
                      MiuixIcons.extended.byName('months')!,
                      HyperosIconColors.blue,
                    ),
                    title: settings.semesterStartDate == null
                        ? l10n.setSemesterStartDateAction
                        : l10n.semesterStartDateAction,
                    endActions: settings.semesterStartDate != null
                        ? [
                            Text(
                              _formatDate(settings.semesterStartDate!),
                              style: HyperosTypography.listDetail(context),
                            ),
                          ]
                        : null,
                    onClick: () => _pickSemesterStartDate(context),
                  ),
                  _MiuixSettingsPreference(
                    startAction: _settingsIconBadge(
                      MiuixIcons.extended.byName('weeks')!,
                      HyperosIconColors.indigo,
                    ),
                    title: l10n.selectSemesterWeekCountTitle,
                    endActions: [
                      Text(
                        l10n.semesterWeekCountAction(
                          settings.semesterWeekCount,
                        ),
                        style: HyperosTypography.listDetail(context),
                      ),
                    ],
                    onClick: () => _pickSemesterWeekCount(context),
                  ),
                  // 纠偏动作放组末，避免与「开学日期 / 周数」配置同权。
                  _MiuixSettingsPreference(
                    startAction: _settingsIconBadge(
                      MiuixIcons.extended.byName('refresh')!,
                      HyperosIconColors.teal,
                    ),
                    title: l10n.syncCurrentWeekAction,
                    endActions: settings.semesterStartDate == null
                        ? [
                            Text(
                              l10n.syncCurrentWeekNeedsStartDate,
                              style: HyperosTypography.listDetail(context),
                            ),
                          ]
                        : null,
                    onClick: settings.semesterStartDate == null
                        ? null
                        : () => _syncCurrentWeek(context),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickSemesterStartDate(BuildContext context) async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    final selected = await showMiuixDatePickerSheet(
      context,
      title: l10n.semesterStartDateLabel,
      initialDate: provider.settings.semesterStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );
    if (selected == null || !context.mounted) {
      return;
    }

    final message = await provider.updateTimetableSettings(
      provider.settings.copyWith(semesterStartDate: selected),
    );
    // 改开学日后按新日期对齐当前周，避免「日期已改、周次仍旧」。
    if (context.mounted) {
      await provider.syncCurrentWeekWithSemesterStart();
    }
    if (!context.mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: message);
      return;
    }
    showAppLightTip(
      context,
      message: l10n.syncedCurrentWeekMessage(provider.currentWeek),
    );
  }

  Future<void> _syncCurrentWeek(BuildContext context) async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    await provider.syncCurrentWeekWithSemesterStart();
    if (!context.mounted) {
      return;
    }
    showAppLightTip(
      context,
      message: l10n.syncedCurrentWeekMessage(provider.currentWeek),
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
}

/// 超级岛入口，带通知权限状态。
///
/// 「超级岛不显示」几乎总是通知权限没开。权限状态在原生侧，异步读一次即可，
/// 页面恢复时再查一次——用户去系统设置开完权限回来，这里要立刻反映出来。
class _LiveEntryTile extends StatefulWidget {
  const _LiveEntryTile({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_LiveEntryTile> createState() => _LiveEntryTileState();
}

class _LiveEntryTileState extends State<_LiveEntryTile>
    with WidgetsBindingObserver {
  bool? _hasPermission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPermission());
    }
  }

  Future<void> _refreshPermission() async {
    final granted = await MiuiLiveActivitiesService()
        .checkNotificationPermission();
    if (!mounted) {
      return;
    }
    setState(() => _hasPermission = granted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final liveSettings = context.watch<TimetableProvider>().settings;
    final liveReminderEnabled =
        liveSettings.liveEnableBeforeClass ||
        liveSettings.liveEnableDuringClass ||
        liveSettings.liveEnableBeforeEnd;
    // 权限缺失优先；已授权时展示开/关态，避免入口右侧空白。
    final detailsText = _hasPermission == false
        ? l10n.liveNotificationPermissionMissing
        : _hasPermission == true
        ? (liveReminderEnabled
              ? l10n.liveIslandLabelEntryEnabled
              : l10n.liveIslandLabelEntryDisabled)
        : null;
    return _MiuixSettingsPreference(
      key: const ValueKey<String>('settings-live-entry'),
      startAction: _settingsIconBadge(
        MiuixIcons.extended.byName('alarm')!,
        HyperosIconColors.orange,
      ),
      title: l10n.liveSettingsTitle,
      endActions: detailsText != null
          ? [Text(detailsText, style: HyperosTypography.listDetail(context))]
          : null,
      onClick: widget.onTap,
    );
  }
}

/// 设置页脚的开发者工具组：内存监测 / 临时测试课程 / UI 组件库 / 调试悬浮窗。
///
/// 内存监测、临时测试课程按包名门控（`.debug` / `.profile`），不依赖编译模式，
/// 避免正式 release 产物误开入口；同时缓存 Future，避免 rebuild 重复读包信息。
/// 这些项不面向普通用户，因此独立成组、不与「关于 / 使用引导」同卡。
class _SettingsDeveloperListGroup extends StatefulWidget {
  const _SettingsDeveloperListGroup({
    required this.onOpenMemoryStats,
    required this.onOpenLiveTestingFixture,
    required this.onOpenHyperosShowcase,
    required this.onOpenMiuixShowcase,
  });

  final VoidCallback onOpenMemoryStats;
  final VoidCallback onOpenLiveTestingFixture;
  final VoidCallback onOpenHyperosShowcase;
  final VoidCallback onOpenMiuixShowcase;

  @override
  State<_SettingsDeveloperListGroup> createState() =>
      _SettingsDeveloperListGroupState();
}

class _SettingsDeveloperListGroupState
    extends State<_SettingsDeveloperListGroup> {
  late final Future<bool> _diagnosticsBuildFuture =
      MemoryStatsService.isDiagnosticsBuild();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _diagnosticsBuildFuture,
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context)!;
        final showDiagnosticsTools = snapshot.data == true;
        if (!showDiagnosticsTools && kReleaseMode) {
          return const SizedBox.shrink();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HyperosSectionGap(),
            HyperosSectionLabel(text: l10n.developerSectionTitle),
            HyperosListGroup(
              children: [
                if (showDiagnosticsTools)
                  _MiuixSettingsPreference(
                    startAction: _settingsIconBadge(
                      MiuixIcons.extended.byName('background')!,
                      HyperosIconColors.orange,
                    ),
                    title: l10n.memoryStatsEntryTitle,
                    onClick: widget.onOpenMemoryStats,
                  ),
                if (showDiagnosticsTools)
                  _MiuixSettingsPreference(
                    startAction: _settingsIconBadge(
                      MiuixIcons.extended.byName('stopwatch')!,
                      HyperosIconColors.indigo,
                    ),
                    title: l10n.liveTestingFixtureEntryTitle,
                    onClick: widget.onOpenLiveTestingFixture,
                  ),
                if (!kReleaseMode) ...[
                  _MiuixSettingsPreference(
                    startAction: _settingsIconBadge(
                      MiuixIcons.extended.byName('all')!,
                      HyperosIconColors.purple,
                    ),
                    title: l10n.hyperosShowcaseEntryTitle,
                    endActions: [
                      Text(
                        l10n.hyperosShowcaseEntrySubtitle,
                        style: HyperosTypography.listDetail(context),
                      ),
                    ],
                    onClick: widget.onOpenHyperosShowcase,
                  ),
                  _MiuixSettingsPreference(
                    startAction: _settingsIconBadge(
                      MiuixIcons.extended.byName('listView')!,
                      HyperosIconColors.cyan,
                    ),
                    title: l10n.miuixShowcaseEntryTitle,
                    endActions: [
                      Text(
                        l10n.miuixShowcaseEntrySubtitle,
                        style: HyperosTypography.listDetail(context),
                      ),
                    ],
                    onClick: widget.onOpenMiuixShowcase,
                  ),
                  ListenableBuilder(
                    listenable: BlackBoxOverlayPreferences.instance,
                    builder: (context, _) => _MiuixSettingsSwitchPreference(
                      startAction: _settingsIconBadge(
                        MiuixIcons.extended.byName('show')!,
                        HyperosIconColors.purple,
                      ),
                      title: l10n.debugUiOverlayToggleTitle,
                      value: BlackBoxOverlayPreferences.instance.visible,
                      onChanged: BlackBoxOverlayPreferences.instance.setVisible,
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

/// 开发者区开关行，与导航行共享标题字重和按压反馈。
class _MiuixSettingsSwitchPreference extends StatelessWidget {
  const _MiuixSettingsSwitchPreference({
    required this.startAction,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final Widget startAction;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return HyperosPressableRow(
      onTap: () => onChanged(!value),
      holdHighlightThroughTransition: true,
      child: MiuixBasicComponent(
        title: title,
        titleFontWeight: FontWeight.w400,
        startAction: startAction,
        endActions: [MiuixSwitch(value: value, onChanged: onChanged)],
        role: MiuixBasicComponentRole.switchControl,
        // The outer row owns tap semantics and press feedback.
        onClick: null,
      ),
    );
  }
}

/// 设置首页图标 Badge：彩色圆角背景 + 白色图标（与 HyperosIconBadge 一致）。
Widget _settingsIconBadge(MiuixVectorIcon icon, Color accent) {
  return Container(
    width: HyperosTokens.iconBadgeSize,
    height: HyperosTokens.iconBadgeSize,
    decoration: BoxDecoration(
      color: accent,
      borderRadius: BorderRadius.circular(HyperosTokens.iconBadgeRadius),
    ),
    alignment: Alignment.center,
    child: MiuixIcon(
      vector: icon,
      size: HyperosTokens.iconGlyphSize,
      tint: Colors.white,
    ),
  );
}

/// 带正确按压反馈的 Miuix 设置行。
///
/// 外层 [HyperosPressableRow] 处理按压高亮（根据 isFirst/isLast 裁剪圆角），
/// 内层 [MiuixArrowPreference] 只负责显示。
class _MiuixSettingsPreference extends StatelessWidget {
  const _MiuixSettingsPreference({
    super.key,
    required this.startAction,
    required this.title,
    this.endActions,
    required this.onClick,
  });

  final Widget startAction;
  final String title;
  final List<Widget>? endActions;
  final VoidCallback? onClick;

  @override
  Widget build(BuildContext context) {
    return HyperosPressableRow(
      onTap: onClick,
      holdHighlightThroughTransition: true,
      child: MiuixArrowPreference(
        startAction: startAction,
        title: title,
        // 上游 MiuixBasicComponent 标题硬编码 Medium(w500)，比全 App 其余设置行
        // 所用的 HyperosTypography.title(w400) 重一档。这里下调到 w400 与之统一
        // （仍会随系统字重经 MiuixText 分级平移）。
        titleFontWeight: FontWeight.w400,
        // MiuixArrowPreference 会把 endActions 放进 mainAxisSize.min 的 Row，
        // 里面的 Text 拿到的是无界宽度，值过长时会溢出而不是省略。
        // 逐个包 Flexible 让它们服从右侧受限宽度，并默认单行省略。
        endActions: _constrainEndActions(endActions),
        // 禁用内层点击和按压，由外层 HyperosPressableRow 处理
        onClick: null,
        enabled: onClick != null,
      ),
    );
  }

  /// 把每个末尾操作包成可收缩的 [Flexible]，并让其中的 [Text] 默认单行省略，
  /// 避免超长详情值撑破 [MiuixArrowPreference] 的末尾槽位。
  List<Widget>? _constrainEndActions(List<Widget>? actions) {
    if (actions == null || actions.isEmpty) {
      return actions;
    }
    return [
      for (final action in actions)
        Flexible(
          fit: FlexFit.loose,
          child: DefaultTextStyle.merge(
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            child: action,
          ),
        ),
    ];
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

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
