import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/holiday_log_localizer.dart';
import 'package:university_timetable/l10n/holiday_name_localizer.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:university_timetable/l10n/app_localizations_extensions.dart';
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

        return ListenableBuilder(
          listenable: HyperosLayoutTuningController.instance,
          builder: (context, _) {
            // Settings home: HyperOS collapsible large title + frosted chrome.
            return _MiuixSettingsHomeShell(
              title: l10n.settingsTitle,
              onBack: () => Navigator.pop(context),
              child: HyperosListView(
                // Inset lives inside the scrollable (like HyperosSubpage) so
                // rows can pass under the frosted/liquid-glass top bar.
                includeHeaderInset: true,
                blockVerticalScrollBubbling: false,
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
                      // 摘要卡即学期设置入口：它承载「开学日期未设置」这类待办态，
                      // 不可点等于把首屏最大的目标浪费掉。
                      onTap: openSemesterSettings,
                    ),
                    const HyperosSectionGap(),
                    HyperosSectionLabel(
                      text: l10n.settingsTimetableSectionTitle,
                    ),
                    HyperosListGroup(
                      children: [
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.layers_outlined,
                            HyperosIconColors.blue,
                          ),
                          title: l10n.timetableManagement,
                          endActions: provider.activeProfile?.name != null
                              ? [
                                  Text(
                                    provider.activeProfile!.name,
                                    style: HyperosTypography.listDetail(
                                      context,
                                    ),
                                  ),
                                ]
                              : null,
                          onClick: openProfiles,
                        ),
                        // 「课程总览」是内容操作而非偏好，入口只保留在首页顶部菜单。
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.schedule_rounded,
                            HyperosIconColors.teal,
                          ),
                          title: l10n.timeSchemeEntryTitle,
                          endActions: provider.activeTimeScheme?.name != null
                              ? [
                                  Text(
                                    provider.activeTimeScheme!.name,
                                    style: HyperosTypography.listDetail(
                                      context,
                                    ),
                                  ),
                                ]
                              : null,
                          onClick: () => _openTimeSchemeQuickSwitcher(context),
                        ),
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.celebration_outlined,
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
                    const HyperosSectionGap(),
                    // 显示组只装「课表里怎么画」：课卡 → 课表页。
                    // 超级岛 / 小组件是系统表面，单独进「提醒与桌面」，避免和「外观」撞名。
                    HyperosSectionLabel(
                      text: l10n.settingsDisplayAppearanceSectionTitle,
                    ),
                    HyperosListGroup(
                      children: [
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.dashboard_customize_rounded,
                            HyperosIconColors.purple,
                          ),
                          title: l10n.courseCardSettingsTitle,
                          onClick: openCourseCardSettings,
                        ),
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.view_week_outlined,
                            HyperosIconColors.orange,
                          ),
                          title: l10n.timetablePageSettingsTitle,
                          onClick: openTimetablePageSettings,
                        ),
                      ],
                    ),
                    const HyperosSectionGap(),
                    HyperosSectionLabel(
                      text: l10n.settingsReminderDesktopSectionTitle,
                    ),
                    HyperosListGroup(
                      children: [
                        // 通知权限没开时超级岛不会显示，这是最常见的求助场景。
                        // 把状态前置到入口上，用户不用进两层才发现问题。
                        _LiveEntryTile(onTap: openLiveSettings),
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.widgets_outlined,
                            HyperosIconColors.green,
                          ),
                          title: l10n.homeWidgetEntryTitle,
                          onClick: openHomeWidgetSettings,
                        ),
                      ],
                    ),
                    const HyperosSectionGap(),
                    // 应用级：外观管「长什么样」，通用管「怎么交互」，都不限于课表。
                    HyperosSectionLabel(text: l10n.settingsAppSectionTitle),
                    HyperosListGroup(
                      children: [
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.palette_outlined,
                            HyperosIconColors.blue,
                          ),
                          title: l10n.appearanceEntryTitle,
                          onClick: openAppearance,
                        ),
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.tune_rounded,
                            HyperosIconColors.indigo,
                          ),
                          title: l10n.generalSettingsTitle,
                          onClick: openGeneralSettings,
                        ),
                      ],
                    ),
                    const HyperosSectionGap(),
                    // 情侣课表并入本组：单项无名分组无法被预判归属，是首页唯一的孤岛。
                    HyperosSectionLabel(
                      text: l10n.settingsDataShareSectionTitle,
                    ),
                    HyperosListGroup(
                      children: [
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.swap_horiz_rounded,
                            HyperosIconColors.green,
                          ),
                          title: l10n.dataTransferEntryTitle,
                          onClick: openDataTransfer,
                        ),
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.cloud_sync_rounded,
                            HyperosIconColors.cyan,
                          ),
                          title: l10n.cloudSyncEntryTitle,
                          onClick: openCloudSync,
                        ),
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.lan_rounded,
                            HyperosIconColors.indigo,
                          ),
                          title: l10n.lanEditEntryTitle,
                          onClick: openLanEdit,
                        ),
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.favorite_outline_rounded,
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
                    const HyperosSectionGap(),
                    HyperosSectionLabel(text: l10n.settingsAboutSectionTitle),
                    HyperosListGroup(
                      children: [
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.info_outline_rounded,
                            HyperosIconColors.blue,
                          ),
                          title: l10n.aboutEntryTitle,
                          onClick: openAbout,
                        ),
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.menu_book_outlined,
                            HyperosIconColors.cyan,
                          ),
                          title: l10n.userGuideEntryTitle,
                          onClick: openUserGuide,
                        ),
                        // 排障工具的唯一正门：日志、自检、内存监测都在这后面。
                        _MiuixSettingsPreference(
                          startAction: _settingsIconBadge(
                            Icons.health_and_safety_outlined,
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
                    // 开发者工具单独成组：门控项不与「关于 / 使用引导」同权同卡。
                    _SettingsDeveloperListGroup(
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

  Future<void> _openTimeSchemeQuickSwitcher(BuildContext context) async {
    await HyperosNavigation.push(
      context,
      settings: const RouteSettings(name: '/settings/time-schemes'),
      builder: (_) => const TimeSchemeManagementScreen(),
    );
  }
}

/// Settings home chrome: HyperOS collapsible large title + frosted overlay.
///
/// Uses the in-house [HyperosCollapsibleTopAppBar] (Miuix algorithm port) so
/// title ink stays pinned after style lerp — flutter_miuix TopAppBar was
/// black/white flashing on every collapse frame via TextStyle.lerp.
class _MiuixSettingsHomeShell extends StatefulWidget {
  const _MiuixSettingsHomeShell({
    required this.title,
    required this.onBack,
    required this.child,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  State<_MiuixSettingsHomeShell> createState() =>
      _MiuixSettingsHomeShellState();
}

class _MiuixSettingsHomeShellState extends State<_MiuixSettingsHomeShell> {
  final _scrollBehavior = HyperosExitUntilCollapsedScrollBehavior(
    requireOuterScrollable: false,
  );

  /// False while the list is at rest under the large title (solid page bg).
  /// True once rows scroll under the bar (frosted / liquid glass).
  ///
  /// Held in a [ValueNotifier] so only the backdrop rebuilds — never the
  /// collapsible title bar (avoids mid-expand flash).
  final ValueNotifier<bool> _contentUnderHeader = ValueNotifier<bool>(false);

  static const Duration _headerFrostFadeDuration = Duration(milliseconds: 180);

  @override
  void dispose() {
    _contentUnderHeader.dispose();
    super.dispose();
  }

  bool _onBodyScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification.metrics.axisDirection == AxisDirection.left ||
        notification.metrics.axisDirection == AxisDirection.right) {
      return false;
    }
    if (notification is! ScrollUpdateNotification &&
        notification is! OverscrollNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    _scrollBehavior.handleScroll(notification);

    // Don't toggle frost during snap animation or its 800ms cooldown — pixels
    // oscillate around the endpoint and would flip _contentUnderHeader → flash.
    if (_scrollBehavior.isSnapInProgress || _scrollBehavior.isSnapCooldown) {
      return false;
    }

    final pixels = notification.metrics.pixels;
    // Frost only after the large title is fully collapsed (small title settled).
    // During the large-title tuck / small-title reveal the bar stays solid page
    // color — no gaussian/liquid glass while the title is still transitioning.
    final expansion = -_scrollBehavior.state.heightOffsetLimit;
    final fullyCollapsed =
        expansion.isFinite && expansion > 0 && pixels >= expansion - 1.0;
    final underHeader = fullyCollapsed;
    if (_contentUnderHeader.value != underHeader) {
      _contentUnderHeader.value = underHeader;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final pageBackground = HyperosColors.scaffoldBackground(context);
    final chromeInk = HyperosColors.primaryText(context);
    final fixedExpandedTopInset =
        HyperosBlurredHeader.contentTopInsetCollapsible(context);

    return ColoredBox(
      color: pageBackground,
      child: HyperosBlurredHeaderScope(
        contentTopInset: fixedExpandedTopInset,
        headerBackgroundColor: pageBackground,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                color: pageBackground,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onBodyScrollNotification,
                  child: widget.child,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  // Frost only after fully collapsed (small title settled).
                  Positioned.fill(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _contentUnderHeader,
                      builder: (context, contentUnderHeader, _) {
                        return IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: contentUnderHeader ? 1.0 : 0.0,
                            duration: _headerFrostFadeDuration,
                            curve: Curves.easeOut,
                            child: HyperosBlurredHeaderScope(
                              contentTopInset: 0,
                              contentUnderHeader: true,
                              headerBackgroundColor: pageBackground,
                              child: const HyperosBlurredHeaderShell(
                                child: SizedBox.expand(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Dual-title collapsible bar (solid bg; no extra ColoredBox).
                  HyperosCollapsibleTopAppBar(
                    title: widget.title,
                    color: pageBackground,
                    titleColor: chromeInk,
                    largeTitleColor: chromeInk,
                    blurred: false,
                    scrollBehavior: _scrollBehavior,
                    navigationIcon: HyperosIconButton(
                      icon: Icons.arrow_back,
                      color: chromeInk,
                      onPressed: widget.onBack,
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
                      Icons.event_outlined,
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
                      Icons.view_week_outlined,
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
                      Icons.sync_outlined,
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
      startAction: _settingsIconBadge(
        Icons.notifications_active_outlined,
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
                      Icons.memory_outlined,
                      HyperosIconColors.orange,
                    ),
                    title: l10n.memoryStatsEntryTitle,
                    onClick: widget.onOpenMemoryStats,
                  ),
                if (showDiagnosticsTools)
                  _MiuixSettingsPreference(
                    startAction: _settingsIconBadge(
                      Icons.event_available_outlined,
                      HyperosIconColors.indigo,
                    ),
                    title: l10n.liveTestingFixtureEntryTitle,
                    onClick: widget.onOpenLiveTestingFixture,
                  ),
                if (!kReleaseMode) ...[
                  _MiuixSettingsPreference(
                    startAction: _settingsIconBadge(
                      Icons.view_quilt_outlined,
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
                      Icons.widgets_outlined,
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
                    listenable: DebugTuningPreferences.instance,
                    builder: (context, _) => MiuixSwitchPreference(
                      startAction: _settingsIconBadge(
                        Icons.tune_outlined,
                        HyperosIconColors.purple,
                      ),
                      title: l10n.debugUiOverlayToggleTitle,
                      value: DebugTuningPreferences.instance.visible,
                      onChanged: DebugTuningPreferences.instance.setVisible,
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

/// 设置首页图标 Badge：彩色圆角背景 + 白色图标（与 HyperosIconBadge 一致）。
Widget _settingsIconBadge(IconData icon, Color accent) {
  return Container(
    width: HyperosTokens.iconBadgeSize,
    height: HyperosTokens.iconBadgeSize,
    decoration: BoxDecoration(
      color: accent,
      borderRadius: BorderRadius.circular(HyperosTokens.iconBadgeRadius),
    ),
    alignment: Alignment.center,
    child: Icon(icon, size: HyperosTokens.iconGlyphSize, color: Colors.white),
  );
}

/// 带正确按压反馈的 Miuix 设置行。
///
/// 外层 [HyperosPressableRow] 处理按压高亮（根据 isFirst/isLast 裁剪圆角），
/// 内层 [MiuixArrowPreference] 只负责显示。
class _MiuixSettingsPreference extends StatelessWidget {
  const _MiuixSettingsPreference({
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
        endActions: endActions,
        // 禁用内层点击和按压，由外层 HyperosPressableRow 处理
        onClick: null,
        enabled: onClick != null,
      ),
    );
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
