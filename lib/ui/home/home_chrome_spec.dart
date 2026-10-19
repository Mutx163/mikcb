import 'package:flutter/material.dart';

import '../../models/liquid_glass_tuning.dart';
import '../../models/timetable_settings.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../utils/home_page_background.dart';
import '../../widgets/home_page_region_blur.dart';
import '../../widgets/preblurred_wallpaper_glass.dart';

/// 首页构建期需要的一整份「外观解析结果」。
///
/// 2026-10-19 从 `timetable_screen` 的 build 里搬出：背景色、状态栏极性、顶栏/
/// 星期栏玻璃、卡片预模糊与墨色全部在这里一次算完。纯输入（settings / 主题 /
/// 壁纸亮度）→ 纯输出，不读 State、不写状态，方便单测与后续复用。
class HomeChromeSpec {
  final bool glassDockForm;
  final bool hasBackdrop;
  final bool statusBarShowsBackdrop;
  final bool timetableShowsBackdrop;
  final Color pageBackgroundColor;
  final HomePageBackgroundVisual timetableBackground;
  final bool headerShowsBackdrop;
  final bool backdropBlurOn;
  final bool headerUsesFrostedChrome;
  final HomePageBackgroundVisual headerBackground;
  final Color headerBarColor;
  final bool chromeBandPaints;
  final Color scaffoldBackgroundColor;
  final Color systemOverlayBackground;
  final Color chromeForeground;
  final Color chromeMutedForeground;
  final Color chromeDotBorderColor;
  final bool followsWeekPager;
  final bool continuousChromeBlur;
  final CourseCardSurfaceStyle cardStyle;
  final bool useCoursePreblur;
  final bool useHomePreblur;
  final double homePreblurSigma;
  final double? courseCardPreblurSigma;

  const HomeChromeSpec({
    required this.glassDockForm,
    required this.hasBackdrop,
    required this.statusBarShowsBackdrop,
    required this.timetableShowsBackdrop,
    required this.pageBackgroundColor,
    required this.timetableBackground,
    required this.headerShowsBackdrop,
    required this.backdropBlurOn,
    required this.headerUsesFrostedChrome,
    required this.headerBackground,
    required this.headerBarColor,
    required this.chromeBandPaints,
    required this.scaffoldBackgroundColor,
    required this.systemOverlayBackground,
    required this.chromeForeground,
    required this.chromeMutedForeground,
    required this.chromeDotBorderColor,
    required this.followsWeekPager,
    required this.continuousChromeBlur,
    required this.cardStyle,
    required this.useCoursePreblur,
    required this.useHomePreblur,
    required this.homePreblurSigma,
    required this.courseCardPreblurSigma,
  });
}

HomeChromeSpec resolveHomeChromeSpec({
  required BuildContext context,
  required TimetableSettings settings,
  required bool isDark,
  required Color darkFallback,
  required double? wallpaperTopLuminance,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final foruiTheme = context.theme;
  final glassDockForm =
      settings.homeNavigationForm == HomeNavigationForm.glassDock;
  final hasBackdrop = hasHomePageBackdrop(settings);
  final statusBarShowsBackdrop = homePageRegionShowsBackdrop(
    settings,
    HomePageBackgroundScope.statusBar,
  );
  final timetableShowsBackdrop = homePageRegionShowsBackdrop(
    settings,
    HomePageBackgroundScope.timetable,
  );
  final pageBackgroundColor = resolveHomePageBackgroundColor(
    settings: settings,
    isDark: isDark,
    darkFallback: darkFallback,
  );
  final timetableBackground = resolveHomePageRegionBackground(
    settings: settings,
    isDark: isDark,
    darkFallback: darkFallback,
    region: HomePageBackgroundScope.timetable,
  );
  final headerShowsBackdrop = homePageRegionShowsBackdrop(
    settings,
    HomePageBackgroundScope.header,
  );
  // 模糊管线总闸（用户「实体卡片」档关掉总开关 / 系统降级 / 平台不支持）。
  final backdropBlurOn =
      hasBackdrop && HyperosBlurredHeader.backdropBlurEnabled(context);
  final headerUsesFrostedChrome = homePageHeaderUsesFrostedChrome(
    settings: settings,
    hasBackdrop: hasBackdrop,
    headerShowsBackdrop: headerShowsBackdrop,
    blurPipelineOn: backdropBlurOn,
  );
  final headerBackground = resolveHomePageHeaderBackground(
    settings: settings,
    hasBackdrop: hasBackdrop,
    headerShowsBackdrop: headerShowsBackdrop,
    blurPipelineOn: backdropBlurOn,
    isDark: isDark,
    darkFallback: darkFallback,
  );
  final headerBarColor = headerBackground.color;
  final chromeBandPaints = homePageChromeBandPaints(
    settings,
    hasBackdrop: hasBackdrop,
  );
  final scaffoldBackgroundColor = timetableShowsBackdrop
      ? Colors.transparent
      : timetableBackground.color;
  final systemOverlayBackground = resolveHomePageStatusBarBackground(
    pageBackground: pageBackgroundColor,
    statusBarShowsBackdrop: homePageStatusBarOverWallpaper(
      settings: settings,
      statusBarShowsBackdrop: statusBarShowsBackdrop,
      bandPaints: chromeBandPaints,
      blurPipelineOn: backdropBlurOn,
    ),
    hasBackdrop: hasBackdrop,
    isDark: isDark,
    usesFrostedChrome: headerUsesFrostedChrome,
    wallpaperTopLuminance: wallpaperTopLuminance,
  );
  final chromeForeground = headerUsesFrostedChrome
      ? homePageChromeForegroundForLuminance(
          wallpaperTopLuminance,
          fallback: foruiTheme.colors.foreground,
        )
      : foruiTheme.colors.foreground;
  final chromeMutedForeground = hasBackdrop
      ? homePageChromeMutedForeground(chromeForeground)
      : foruiTheme.colors.mutedForeground;
  final chromeDotBorderColor = headerBarColor.a == 0
      ? colorScheme.surface
      : headerBarColor;
  final followsWeekPager =
      hasBackdrop && settings.homePageBackdropFollowsWeekPager;
  final continuousChromeBlur = homePageHasAnyChromeBlur(
    settings,
    hasBackdrop: hasBackdrop,
  );
  final cardStyle = effectiveCourseCardSurfaceStyle(
    settings,
    gaussianBlurAvailable: backdropBlurOn,
  );
  final useCoursePreblur = backdropBlurOn && cardStyle.isGlass;
  final useHomePreblur =
      useCoursePreblur || (backdropBlurOn && continuousChromeBlur);
  final dockAppearance = FrostedAppearanceScope.of(context);
  final homePreblurSigma = resolveHomePreblurSigma(
    gaussianCardsDrive: backdropBlurOn && cardStyle.isGlass,
    liquidGlassChrome: dockAppearance.homeBandGlassMaterial == 'liquid',
    sheetBlurSigma: HyperosBlurredHeader.blurSigmaOf(context),
    liquidGlassTunedBlur:
        (dockAppearance.liquidGlassTuning ?? LiquidGlassTuning.defaults)
            .blurSigma,
  );
  final courseCardPreblurSigma = resolveCourseCardPreblurSigma(
    cardStyle: cardStyle,
    cardTuning: settings.courseCardGlassTuning,
  );
  return HomeChromeSpec(
    glassDockForm: glassDockForm,
    hasBackdrop: hasBackdrop,
    statusBarShowsBackdrop: statusBarShowsBackdrop,
    timetableShowsBackdrop: timetableShowsBackdrop,
    pageBackgroundColor: pageBackgroundColor,
    timetableBackground: timetableBackground,
    headerShowsBackdrop: headerShowsBackdrop,
    backdropBlurOn: backdropBlurOn,
    headerUsesFrostedChrome: headerUsesFrostedChrome,
    headerBackground: headerBackground,
    headerBarColor: headerBarColor,
    chromeBandPaints: chromeBandPaints,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    systemOverlayBackground: systemOverlayBackground,
    chromeForeground: chromeForeground,
    chromeMutedForeground: chromeMutedForeground,
    chromeDotBorderColor: chromeDotBorderColor,
    followsWeekPager: followsWeekPager,
    continuousChromeBlur: continuousChromeBlur,
    cardStyle: cardStyle,
    useCoursePreblur: useCoursePreblur,
    useHomePreblur: useHomePreblur,
    homePreblurSigma: homePreblurSigma,
    courseCardPreblurSigma: courseCardPreblurSigma,
  );
}
