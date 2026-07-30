import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
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
import '../ui/app_fonts.dart';
import '../ui/debug/debug.dart';
import '../widgets/frosted_sheet_settings_preview.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/semester_week_count_picker_sheet.dart';
import '../widgets/theme_manage_sheets.dart';
import '../widgets/timetable_text_color_settings.dart';
import '../widgets/timetable_week_preview.dart';
import '../widgets/course_field_picker_sheet.dart';
import '../services/bundled_assets.dart';
import '../services/live_testing_trigger.dart';
import '../widgets/bundled_asset_image.dart';
import '../services/memory_stats_service.dart';
import 'about_screen.dart';
import 'course_overview_screen.dart';
import 'couple_timetable_settings_screen.dart';
import 'data_transfer_screen.dart';
import 'cloud_sync_screen.dart';
import 'lan_edit_screen.dart';
import 'feedback_screen.dart';
import 'memory_stats_screen.dart';
import 'live_settings_subpages.dart';
import 'live_testing_fixture_screen.dart';
import 'time_scheme_management_screen.dart';
import 'timetable_profiles_screen.dart';
import 'hyperos_showcase_screen.dart';
import 'miuix_showcase_screen.dart';
import 'user_guide_screen.dart';
import 'advanced_material_settings_screen.dart';
import 'log_viewer_entry.dart';
import 'package:university_timetable/l10n/app_localizations_extensions.dart';
import '../widgets/preblurred_wallpaper_glass.dart';
import '../widgets/miuix_date_picker_sheet.dart';
part 'settings/settings_appearance.dart';
part 'settings/settings_course_card.dart';
part 'settings/settings_diagnostics.dart';
part 'settings/settings_general.dart';
part 'settings/settings_holiday.dart';
part 'settings/settings_home_widget.dart';
part 'settings/settings_live.dart';
part 'settings/settings_reset.dart';
part 'settings/settings_timetable_page.dart';

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
            builder: (_) => const _TimetablePageSettingsScreen(),
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
                  // 反馈 / 关于在最下方；内存监测仅诊断包可见，且在「澎湃 UI 组件库」之上。
                  _SettingsFooterListGroup(
                    feedbackTitle: l10n.feedbackEntryTitle,
                    aboutTitle: l10n.aboutEntryTitle,
                    onOpenFeedback: openFeedback,
                    onOpenAbout: openAbout,
                    onOpenMemoryStats: openMemoryStats,
                    onOpenLiveTestingFixture: openLiveTestingFixture,
                    onOpenHyperosShowcase: openHyperosShowcase,
                    onOpenMiuixShowcase: openMiuixShowcase,
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

  Future<void> _openTimeSchemeQuickSwitcher(BuildContext context) async {
    await HyperosNavigation.push(
      context,
      settings: const RouteSettings(name: '/settings/time-schemes'),
      builder: (_) => const TimeSchemeManagementScreen(),
    );
  }
}

/// 课表设置页底部列表：反馈 / 关于 / 内存监测 / 开发验收入口。
///
/// 内存监测、临时测试课程按包名门控（`.debug` / `.profile`），不依赖编译模式，
/// 避免正式 release 产物误开入口；同时缓存 Future，避免 rebuild 重复读包信息。
class _SettingsFooterListGroup extends StatefulWidget {
  const _SettingsFooterListGroup({
    required this.feedbackTitle,
    required this.aboutTitle,
    required this.onOpenFeedback,
    required this.onOpenAbout,
    required this.onOpenMemoryStats,
    required this.onOpenLiveTestingFixture,
    required this.onOpenHyperosShowcase,
    required this.onOpenMiuixShowcase,
  });

  final String feedbackTitle;
  final String aboutTitle;
  final VoidCallback onOpenFeedback;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenMemoryStats;
  final VoidCallback onOpenLiveTestingFixture;
  final VoidCallback onOpenHyperosShowcase;
  final VoidCallback onOpenMiuixShowcase;

  @override
  State<_SettingsFooterListGroup> createState() =>
      _SettingsFooterListGroupState();
}

class _SettingsFooterListGroupState extends State<_SettingsFooterListGroup> {
  late final Future<bool> _diagnosticsBuildFuture =
      MemoryStatsService.isDiagnosticsBuild();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _diagnosticsBuildFuture,
      builder: (context, snapshot) {
        final showDiagnosticsTools = snapshot.data == true;
        return HyperosListGroup(
          children: [
            HyperosListTile(
              icon: Icons.chat_bubble_outline_rounded,
              iconAccent: HyperosIconColors.green,
              title: widget.feedbackTitle,
              onTap: widget.onOpenFeedback,
            ),
            HyperosListTile(
              icon: Icons.info_outline_rounded,
              iconAccent: HyperosIconColors.blue,
              title: widget.aboutTitle,
              onTap: widget.onOpenAbout,
            ),
            if (showDiagnosticsTools)
              HyperosListTile(
                icon: Icons.memory_outlined,
                iconAccent: HyperosIconColors.orange,
                title: '内存监测',
                onTap: widget.onOpenMemoryStats,
              ),
            if (showDiagnosticsTools)
              HyperosListTile(
                icon: Icons.event_available_outlined,
                iconAccent: HyperosIconColors.indigo,
                title: '临时测试课程',
                onTap: widget.onOpenLiveTestingFixture,
              ),
            if (!kReleaseMode) ...[
              HyperosListTile(
                icon: Icons.view_quilt_outlined,
                iconAccent: HyperosIconColors.purple,
                title: '澎湃 UI 组件库',
                details: '视觉验收',
                onTap: widget.onOpenHyperosShowcase,
              ),
              HyperosListTile(
                icon: Icons.widgets_outlined,
                iconAccent: HyperosIconColors.purple,
                title: 'Miuix \u7ec4\u4ef6\u5e93',
                details: '\u89c6\u89c9\u9a8c\u6536',
                onTap: widget.onOpenMiuixShowcase,
              ),
              ListenableBuilder(
                listenable: DebugTuningPreferences.instance,
                builder: (context, _) => HyperosSwitchTile(
                  icon: Icons.tune_outlined,
                  iconAccent: HyperosIconColors.purple,
                  title: '显示 UI 调试浮窗',
                  value: DebugTuningPreferences.instance.visible,
                  onChanged: DebugTuningPreferences.instance.setVisible,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
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

/// Public factory for debug deep-link navigation (debug builds only).

/// Public factory for debug deep-link navigation (debug builds only).

Map<String, dynamic> _debugSectionMap(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
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
  final provider = context.read<TimetableProvider>();
  await provider.initialize();
  if (!context.mounted) return;
  final result = await triggerLiveUpdateTest(
    context: context,
    provider: provider,
    source: 'settings_screen',
  );
  if (!context.mounted) return;
  _showLiveTestingTriggerResult(context, result);
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

/// Advanced holiday tools: manual refresh + update log (hidden from casual users).

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
