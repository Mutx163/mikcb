import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logging/app_debug_log.dart';
import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';
import '../providers/weather_provider.dart';
import '../utils/widget_course_accent.dart';
import '../services/home_widget_service.dart';
import '../services/home_widget_binding_service.dart';
import '../services/miui_live_activities_service.dart';
import '../services/screen_capture_service.dart';
import '../services/umeng_analytics_service.dart';
import '../services/webdav_sync_coordinator.dart';
import '../utils/app_toast.dart';
import '../utils/home_page_background.dart';
import '../widgets/home_menu_catalog.dart';
import '../widgets/home_top_menu.dart';
import '../ui/app_fonts.dart';
import '../ui/debug/debug.dart';
import '../ui/hyperos/hyperos.dart';
import '../widgets/semester_week_count_picker_sheet.dart';
import '../widgets/miuix_date_picker_sheet.dart';
import '../widgets/theme_manage_sheets.dart';
import '../widgets/timetable_text_color_settings.dart';
import '../widgets/timetable_week_preview.dart';
import '../widgets/course_recolor_sheet.dart';
import '../widgets/course_template_picker_sheet.dart';
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
import 'settings/settings_shared.dart';
import 'settings/settings_appearance_editor.dart';
import 'settings/settings_home_backdrop_flow.dart';
import 'settings/settings_reset.dart';
import 'settings/settings_weather.dart';
import 'settings/settings_general.dart';
import 'settings/settings_diagnostics.dart';
import 'settings/settings_holiday.dart';

part 'settings/settings_appearance.dart';
part 'settings/settings_home_navigation.dart';
part 'settings/settings_home_menu_editor.dart';
part 'settings/settings_glass_dock_editor.dart';
part 'settings/settings_glass_dock_icon_editor.dart';
part 'settings/settings_course_card.dart';
part 'settings/settings_live.dart';
part 'settings/settings_timetable_page.dart';
part 'settings/settings_home_widget.dart';
/// 鍏鏍肩瓑澶栭儴鍏ュ彛鐩磋揪璁剧疆瀛愰〉鐨勫伐鍘傘€?
///
/// 鍚勫瓙椤电被淇濇寔搴撳唴绉佹湁锛岃繖閲屾寜绋冲畾 id 鏆撮湶锛涙湭鐭?id 杩斿洖 null锛?
/// 鐢辫皟鐢ㄦ柟鍐冲畾鍥為€€琛屼负锛堜緥濡傛墦寮€璁剧疆棣栭〉锛夈€?
Widget? settingsSubpageById(String id) {
  return switch (id) {
    'generalSettings' => const GeneralSettingsScreen(),
    'appearanceSettings' => const _AppearanceSettingsScreen(),
    // 銆屽瑙傜紪杈戙€嶏細鏁撮〉涓€寮犻椤靛井缂╁浘 + 搴曢儴銆岃皟鏁村绾?/ 鏉愯川銆嶄袱棰楁寜閽€?
    'appearanceEditor' => const AppearanceEditorScreen(),
    'timetablePageSettings' => const _TimetablePageSettingsScreen(),
    'courseCardSettings' => const _CourseCardSettingsScreen(),
    'liveSettings' => const _LiveSettingsScreen(),
    'holidaySettings' => const HolidaySettingsScreen(),
    'weatherSettings' => const WeatherSettingsScreen(),
    'homeWidgetSettings' => const _HomeWidgetSettingsScreen(),
    'diagnosticsSettings' => const DiagnosticsScreen(),
    _ => null,
  };
}

class TimetableSettingsScreen extends StatelessWidget {
  /// 鏄惁浠ュ唴宓岄〉锛堢幓鐠冨潪 Tab 鍐呭锛夋柟寮忔樉绀猴細涓嶆覆鏌撹繑鍥為敭銆?
  ///
  /// 鏅€氬叏灞忚烦杞繚鎸侀粯璁?false锛岃涓轰笉鍙樸€?
  const TimetableSettingsScreen({
    super.key,
    this.embedded = false,
    this.bottomInset = 0,
  });

  final bool embedded;

  /// 鍐呭祵妯″紡涓嬪垪琛ㄥ簳閮ㄧ殑閬胯楂樺害锛堢幓鐠冨潪搴曢儴瀵艰埅鍗犱綅锛夈€?
  final double bottomInset;

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

        void openHomeNavigation() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/home-navigation'),
            builder: (_) => const _HomeNavigationSettingsScreen(),
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

        void openWeatherSettings() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/weather'),
            builder: (_) => const WeatherSettingsScreen(),
          );
        }

        void openGeneralSettings() {
          HyperosNavigation.push(
            context,
            settings: const RouteSettings(name: '/settings/general'),
            builder: (_) => const GeneralSettingsScreen(),
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
            builder: (_) => const HolidaySettingsScreen(),
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
            builder: (_) => const DiagnosticsScreen(),
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

        // Settings home: same HyperosSubpage shell as every subpage 鈥?
        // unified collapsible large title + frosted/liquid-glass chrome.
        // (The old bespoke _MiuixSettingsHomeShell painted the bar with an
        // opaque background OVER its frost layer, so blur never showed.)
        final settingsList = HyperosListView(
          blockVerticalScrollBubbling: false,
          // 鐜荤拑鍧炲唴宓屾椂搴曢儴閬胯浣滀负銆屾粴鍔ㄥ唴瀹?padding銆嶈€屼笉鏄垪琛ㄥ閮?
          // 鍘嬬缉瑙嗗彛锛氬唴瀹瑰彲浠ユ粴鍒版偓娴幓鐠冨潪鍚庨潰锛堥€忚繃鐜荤拑鍙锛夛紝鍒板簳鏃?
          // 鏈€鍚庝竴椤逛粛鍋滃湪鐜荤拑鍧炰笂鏂广€傚叏灞忓舰鎬?bottomInset=0 鏃犲奖鍝嶃€?
          padding: embedded
              ? HyperosTokens.listPadding.copyWith(
                  bottom: HyperosTokens.listPadding.bottom + bottomInset,
                )
              : null,
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
            openWeatherSettings: openWeatherSettings,
            openHomeNavigation: openHomeNavigation,
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
        );

        // 鐜荤拑鍧炲唴宓屽舰鎬侊細瀹屾暣 HyperosSubpage 鍏ㄥ睆澹筹紙鏃犺繑鍥為敭锛夛紝
        // 澶栬涓庢甯告墦寮€璁剧疆椤典竴鑷达紝婊戝潡鐢卞灞傛偓娴彔鍔犮€?
        return HyperosSubpage(
          title: Text(l10n.settingsTitle),
          onBack: embedded ? null : () => Navigator.pop(context),
          child: settingsList,
        );
      },
    );
  }

  /// Lazy section builder for the settings home list.
  ///
  /// 鎵撳紑鏃堕棿妯℃澘绠＄悊椤碉紙鏃у悕 QuickSwitcher 鍚嶄笉鍓疄锛氬紑鐨勬槸瀹屾暣绠＄悊
  /// 椤碉級銆俬ub 涓庛€岃琛ㄩ〉闈€嶄袱澶勫叆鍙ｅ叡鐢ㄦ湰鏂规硶锛屾寚鍚戝悓涓€璺敱銆?
  void _openTimeSchemeManagement(BuildContext context) {
    HyperosNavigation.push(
      context,
      settings: const RouteSettings(name: '/settings/time-schemes'),
      builder: (_) => const TimeSchemeManagementScreen(),
    );
  }

  /// Sections: 0 summary 路 1 timetable 路 2 display 路 3 reminder/desktop
  /// 路 4 app (appearance / home navigation / general) 路 5 data/share
  /// 路 6 about 路 7 developer tools.
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
    required VoidCallback openWeatherSettings,
    required VoidCallback openHomeNavigation,
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
    // 澶╂皵鍏ュ彛琛岃鏄剧ず褰撳墠鍩庡競锛涚敤鍙┖绫诲瀷鏌ワ紝澶╂皵 provider 缂哄け鏃舵暣琛岀収甯?
    // 鏄剧ず锛堝€间负銆屾湭璁剧疆銆嶏級锛岃€屼笉鏄璁剧疆棣栭〉宕╂帀銆?
    final weather = context.watch<WeatherProvider?>();
    return switch (index) {
      // 0 鈥?Summary card (semester overview).
      0 => HyperosSummaryCard(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(HyperosSummaryCard.leadingRadius),
          child: const BundledAssetImage(
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
      // 1 鈥?Timetable management.
      1 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.settingsTimetableSectionTitle),
          HyperosListGroup(
            children: [
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
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
              // 鏃堕棿妯℃澘锛氶珮棰戦厤缃紙寮€瀛﹀墠鍑犱箮蹇呭姩锛夛紝鎸夌敤鎴峰弽棣堜繚鐣欏湪
              // hub 涓€绾т綅锛涖€岃琛ㄩ〉闈€嶅唴鐨勫悓鍚嶅叆鍙ｅ苟瀛橈紝鎸囧悜鍚屼竴椤甸潰銆?
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
                  MiuixIcons.extended.byName('timer')!,
                  HyperosIconColors.teal,
                ),
                title: l10n.timeSchemeEntryTitle,
                endActions: [
                  Text(
                    provider.activeTimeScheme?.name ??
                        l10n.timeSchemeEntryNotSelected,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
                onClick: () => _openTimeSchemeManagement(context),
              ),
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
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
      // 2 鈥?Display & appearance (course card / timetable page).
      2 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.settingsDisplayAppearanceSectionTitle),
          HyperosListGroup(
            children: [
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
                  MiuixIcons.extended.byName('gridView')!,
                  HyperosIconColors.purple,
                ),
                title: l10n.courseCardSettingsTitle,
                onClick: openCourseCardSettings,
              ),
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
                  MiuixIcons.extended.byName('months')!,
                  HyperosIconColors.orange,
                ),
                title: l10n.timetablePageSettingsTitle,
                onClick: openTimetablePageSettings,
              ),
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
                  MiuixIcons.extended.byName('cloudFill')!,
                  HyperosIconColors.blue,
                ),
                title: l10n.weatherSettingsEntryTitle,
                endActions: [
                  Text(
                    weather?.location?.name ?? l10n.weatherCityNotSet,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
                onClick: openWeatherSettings,
              ),
            ],
          ),
        ],
      ),
      // 3 鈥?Reminder & desktop (live island / home widget).
      //
      // 銆岄椤典笌瀵艰埅銆嶄笉鍐嶅崟鐙垚缁勶細鍗曟潯鐩粍鐨勭粍鍚嶄細涓庤鍚嶅畬鍏ㄧ浉鍚岋紝杩濆弽
      // IA 瑙勮寖 搂3銆屼笉璁哥粍鍚?= 缁勫唴鍞竴椤瑰悕銆嶏紱鍏跺叆鍙ｈ宸插苟鍏ヤ笅鏂广€屽簲鐢ㄣ€嶇粍锛?
      // 瀛愰〉鏈韩锛堝簳鏍忓舰鎬?鑿滃崟/棣栭〉鏍囬锛変笉鍙樸€?
      3 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.settingsReminderDesktopSectionTitle),
          HyperosListGroup(
            children: [
              _LiveEntryTile(onTap: openLiveSettings),
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
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
      // 4 鈥?App-level (appearance / home navigation / general).
      // 銆岄椤典笌瀵艰埅銆嶈嚜鐙珛缁勫苟鍏ユ澶勶紙IA 搂3 缁勫悕=鍞竴椤瑰悕绂佷护锛夛紱
      // 鍥炬爣 sidebar/teal 娌跨敤鍘熷叆鍙ｃ€?
      4 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.settingsAppSectionTitle),
          HyperosListGroup(
            children: [
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
                  MiuixIcons.extended.byName('theme')!,
                  HyperosIconColors.blue,
                ),
                title: l10n.appearanceEntryTitle,
                onClick: openAppearance,
              ),
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
                  MiuixIcons.extended.byName('sidebar')!,
                  HyperosIconColors.teal,
                ),
                title: l10n.homeNavigationTitle,
                onClick: openHomeNavigation,
              ),
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
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
      // 5 鈥?Data & sharing.
      5 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.settingsDataShareSectionTitle),
          HyperosListGroup(
            children: [
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
                  MiuixIcons.extended.byName('convertFile')!,
                  HyperosIconColors.green,
                ),
                title: l10n.dataTransferEntryTitle,
                onClick: openDataTransfer,
              ),
              _CloudSyncEntryTile(onTap: openCloudSync),
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
                  MiuixIcons.extended.byName('link')!,
                  HyperosIconColors.indigo,
                ),
                title: l10n.lanEditEntryTitle,
                onClick: openLanEdit,
              ),
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
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
      // 6 鈥?About & help.
      6 => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.settingsAboutSectionTitle),
          HyperosListGroup(
            children: [
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
                  MiuixIcons.extended.byName('info')!,
                  HyperosIconColors.blue,
                ),
                title: l10n.aboutEntryTitle,
                onClick: openAbout,
              ),
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
                  MiuixIcons.extended.byName('notes')!,
                  HyperosIconColors.cyan,
                ),
                title: l10n.userGuideEntryTitle,
                onClick: openUserGuide,
              ),
              MiuixSettingsPreference(
                startAction: settingsIconBadge(
                  MiuixIcons.extended.byName('report')!,
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
      // 7 鈥?Developer tools + trailing gap.
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

/// 瀛︽湡璁剧疆锛氬紑瀛︽棩鏈?/ 瀛︽湡鍛ㄦ暟 / 鍚屾褰撳墠鍛ㄣ€?
///
/// 浠庤缃椤垫暣缁勭Щ鍏ワ紝鐢遍椤垫憳瑕佸崱鎵胯浇鍏ュ彛鈥斺€旀憳瑕佸崱鏈氨鏄剧ず鍛ㄦ涓庡紑瀛︽棩鏈燂紝
/// 璁╁畠鍚屾椂鎴愪负缂栬緫鍏ュ彛锛屾瘮鍐嶅垪涓€缁勫悓涔夋潯鐩洿鐭€?
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
                  MiuixSettingsPreference(
                    startAction: settingsIconBadge(
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
                  MiuixSettingsPreference(
                    startAction: settingsIconBadge(
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
                  // 绾犲亸鍔ㄤ綔鏀剧粍鏈紝閬垮厤涓庛€屽紑瀛︽棩鏈?/ 鍛ㄦ暟銆嶉厤缃悓鏉冦€?
                  MiuixSettingsPreference(
                    startAction: settingsIconBadge(
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

    final String? message;
    try {
      message = await provider.updateTimetableSettings(
        provider.settings.copyWith(semesterStartDate: selected),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    // 鏀瑰紑瀛︽棩鍚庢寜鏂版棩鏈熷榻愬綋鍓嶅懆锛岄伩鍏嶃€屾棩鏈熷凡鏀广€佸懆娆′粛鏃с€嶃€?
    if (context.mounted) {
      await provider.syncCurrentWeekWithSemesterStart();
    }
    if (!context.mounted) {
      return;
    }
    if (message != null) {
      showAppToast(context, message: localizeServiceMessage(l10n, message));
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

    // 杩斿洖鍊肩鏍￠獙澶辫触锛堝銆岃妭娆℃暟浣庝簬璇捐〃瀹為檯鐢ㄩ噺銆嶏級锛屽啓鍏ュけ璐ヨ蛋 rethrow锛?
    // 涓ゆ潯閮借鏈夊嚭鍙?鈥斺€?鍚﹀垯鍛ㄦ暟鏀逛簡娌″瓨涓娿€佺晫闈㈢収甯告樉绀烘柊鍊硷紝閲嶅惎鍚庡彉鍥炲幓銆?
    final String? message;
    try {
      message = await provider.updateTimetableSettings(
        provider.settings.copyWith(semesterWeekCount: selected),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: AppLocalizations.of(context)!.saveFailed,
        kind: AppToastKind.error,
      );
      return;
    }
    if (message != null) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: localizeServiceMessage(AppLocalizations.of(context)!, message),
      );
      return;
    }

    if (provider.currentWeek > selected) {
      await provider.setCurrentWeek(selected);
    }
  }
}

/// 瓒呯骇宀涘叆鍙ｏ紝甯﹂€氱煡鏉冮檺鐘舵€併€?
///
/// 銆岃秴绾у矝涓嶆樉绀恒€嶅嚑涔庢€绘槸閫氱煡鏉冮檺娌″紑銆傛潈闄愮姸鎬佸湪鍘熺敓渚э紝寮傛璇讳竴娆″嵆鍙紝
/// 椤甸潰鎭㈠鏃跺啀鏌ヤ竴娆♀€斺€旂敤鎴峰幓绯荤粺璁剧疆寮€瀹屾潈闄愬洖鏉ワ紝杩欓噷瑕佺珛鍒诲弽鏄犲嚭鏉ャ€?
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
    // 鏉冮檺缂哄け浼樺厛锛涘凡鎺堟潈鏃跺睍绀哄紑/鍏虫€侊紝閬垮厤鍏ュ彛鍙充晶绌虹櫧銆?
    final detailsText = _hasPermission == false
        ? l10n.liveNotificationPermissionMissing
        : _hasPermission == true
        ? (liveReminderEnabled
              ? l10n.liveIslandLabelEntryEnabled
              : l10n.liveIslandLabelEntryDisabled)
        : null;
    return MiuixSettingsPreference(
      key: const ValueKey<String>('settings-live-entry'),
      startAction: settingsIconBadge(
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

/// 浜戝悓姝ュ叆鍙ｏ紝甯﹂厤缃姸鎬併€?
///
/// 銆屼簯鍚屾涓嶅伐浣溿€嶇殑绗竴鍥犳槸鏍规湰娌￠厤 WebDAV锛圛A 瑙勮寖 搂6 瑕佹眰鎶婅鐘舵€?
/// 鍓嶇疆鍒板叆鍙ｈ灏撅級銆傞厤缃瓨浜?SharedPreferences锛氬紓姝ヨ涓€娆″苟缂撳瓨 Future
/// 锛堜笉鍦?build 閲屽彂璧?I/O锛夛紝App 鎭㈠鍓嶅彴鏃堕噸璇讳竴娆♀€斺€旂敤鎴峰幓浜戝悓姝ラ〉
/// 寮€瀹屽紑鍏冲洖鏉ヨ绔嬪埢鍙嶆槧銆傚悓姝ヤ腑鐨勫姩鎬佺姸鎬佺敱 coordinator 鐨?
/// ChangeNotifier 渚涚粰锛孡istenableBuilder 鐩存帴璺熼殢銆?
class _CloudSyncEntryTile extends StatefulWidget {
  const _CloudSyncEntryTile({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CloudSyncEntryTile> createState() => _CloudSyncEntryTileState();
}

class _CloudSyncEntryTileState extends State<_CloudSyncEntryTile>
    with WidgetsBindingObserver {
  Future<bool>? _enabledFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enabledFuture = _loadEnabled();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _enabledFuture = _loadEnabled();
      });
    }
  }

  Future<bool> _loadEnabled() async {
    final config = await WebdavSyncCoordinator.instance().syncService
        .loadConfig();
    return config.enabled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: WebdavSyncCoordinator.instance(),
      builder: (context, _) => FutureBuilder<bool>(
        future: _enabledFuture,
        builder: (context, snapshot) {
          // 閰嶇疆鏈瀹屽墠琛屽熬鐣欑櫧锛岄伩鍏嶅厛闂竴甯ч敊璇殑銆屾湭寮€鍚€嶃€?
          final detailsText = snapshot.connectionState != ConnectionState.done
              ? null
              : !(snapshot.data ?? false)
              ? l10n.cloudSyncEntryDisabled
              : WebdavSyncCoordinator.instance().status.isSyncing
              ? l10n.cloudSyncEntrySyncing
              : WebdavSyncCoordinator.instance().status.lastError != null
              ? l10n.cloudSyncEntryError
              : l10n.cloudSyncEntryEnabled;
          return MiuixSettingsPreference(
            key: const ValueKey<String>('settings-cloud-sync-entry'),
            startAction: settingsIconBadge(
              MiuixIcons.extended.byName('backup')!,
              HyperosIconColors.cyan,
            ),
            title: l10n.cloudSyncEntryTitle,
            endActions: detailsText == null
                ? null
                : [
                    Text(
                      detailsText,
                      style: HyperosTypography.listDetail(context),
                    ),
                  ],
            onClick: widget.onTap,
          );
        },
      ),
    );
  }
}

/// 璁剧疆椤佃剼鐨勫紑鍙戣€呭伐鍏风粍锛氬唴瀛樼洃娴?/ 涓存椂娴嬭瘯璇剧▼ / UI 缁勪欢搴?/ 璋冭瘯鎮诞绐椼€?
///
/// 鍐呭瓨鐩戞祴銆佷复鏃舵祴璇曡绋嬫寜鍖呭悕闂ㄦ帶锛坄.debug` / `.profile`锛夛紝涓嶄緷璧栫紪璇戞ā寮忥紝
/// 閬垮厤姝ｅ紡 release 浜х墿璇紑鍏ュ彛锛涘悓鏃剁紦瀛?Future锛岄伩鍏?rebuild 閲嶅璇诲寘淇℃伅銆?
/// 杩欎簺椤逛笉闈㈠悜鏅€氱敤鎴凤紝鍥犳鐙珛鎴愮粍銆佷笉涓庛€屽叧浜?/ 浣跨敤寮曞銆嶅悓鍗°€?
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
                  MiuixSettingsPreference(
                    startAction: settingsIconBadge(
                      MiuixIcons.extended.byName('background')!,
                      HyperosIconColors.orange,
                    ),
                    title: l10n.memoryStatsEntryTitle,
                    onClick: widget.onOpenMemoryStats,
                  ),
                if (showDiagnosticsTools)
                  MiuixSettingsPreference(
                    startAction: settingsIconBadge(
                      MiuixIcons.extended.byName('stopwatch')!,
                      HyperosIconColors.indigo,
                    ),
                    title: l10n.liveTestingFixtureEntryTitle,
                    onClick: widget.onOpenLiveTestingFixture,
                  ),
                if (!kReleaseMode) ...[
                  MiuixSettingsPreference(
                    startAction: settingsIconBadge(
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
                  MiuixSettingsPreference(
                    startAction: settingsIconBadge(
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
                    builder: (context, _) => MiuixSettingsSwitchPreference(
                      startAction: settingsIconBadge(
                        MiuixIcons.extended.byName('show')!,
                        HyperosIconColors.red,
                      ),
                      title: l10n.debugUiOverlayToggleTitle,
                      value: BlackBoxOverlayPreferences.instance.visible,
                      onChanged: BlackBoxOverlayPreferences.instance.setVisible,
                    ),
                  ),
                  MiuixSettingsPreference(
                    startAction: settingsIconBadge(
                      MiuixIcons.extended.byName('notes')!,
                      HyperosIconColors.orange,
                    ),
                    title: l10n.debugUiOverlayOpenPanelTitle,
                    onClick: openBlackBoxPanel,
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

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
