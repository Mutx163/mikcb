import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/timetable_settings.dart';
import '../../ui/home/home_chrome_spec.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../utils/home_page_background.dart';
import '../../widgets/home_page_region_blur.dart';
import 'timetable_home_pull_indicator.dart';
import 'timetable_weekday_header.dart';

/// 首页「壁纸 + 玻璃带 + 顶栏 + 内容」的一整棵栈（2026-10-19 从 build 搬出）。
///
/// 只负责位次与外观：背景随周滑动、状态栏遮罩、连续玻璃带、HyperosRootPage
/// 顶栏、内容 Stack；周课表本体、悬浮按钮与下拉药丸都由调用方注入。
class TimetableHomeStack extends StatelessWidget {
  final TimetableSettings settings;
  final AppLocalizations l10n;
  final HomeChromeSpec chrome;
  final PageController weekPageController;
  final Widget title;
  final List<Widget> suffixes;
  final Widget weekSurface;
  final bool isPullRunning;
  final double pullDragDistance;
  final double pullTriggerDistance;
  final VoidCallback onPullCancel;
  final Widget? backToCurrentWeek;
  final Widget? backToToday;
  final bool isDayView;
  final bool glassDockForm;
  final bool isLoading;

  const TimetableHomeStack({
    super.key,
    required this.settings,
    required this.l10n,
    required this.chrome,
    required this.weekPageController,
    required this.title,
    required this.suffixes,
    required this.weekSurface,
    required this.isPullRunning,
    required this.pullDragDistance,
    required this.pullTriggerDistance,
    required this.onPullCancel,
    this.backToCurrentWeek,
    this.backToToday,
    required this.isDayView,
    required this.glassDockForm,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropGroup(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (chrome.hasBackdrop)
                  // 背景随周次滑动时，克隆多页共用同一张壁纸。
                  chrome.followsWeekPager
                      ? HomePageSlidingBackdropLayer(
                          controller: weekPageController,
                          pageCount: settings.semesterWeekCount,
                          settings: settings,
                        )
                      : homePageBackdropLayer(settings: settings),
                if (chrome.hasBackdrop && !chrome.statusBarShowsBackdrop)
                  HomePageStatusBarBackdropMask(
                    color: chrome.pageBackgroundColor,
                  ),
                if (chrome.continuousChromeBlur) const HomeChromeGroupCapture(),
              ],
            ),
          ),
          // Single continuous glass for title + weekday (no time-column blur).
          // Stays fixed above the sliding wallpaper so chrome text stays sharp
          // while the photo moves as one continuous sheet.
          if (chrome.chromeBandPaints)
            HomePageContinuousChromeFrostedOverlay(
              headerBlurEnabled: settings.homePageHeaderBlurEnabled,
              weekdayBarBlurEnabled: settings.homePageWeekdayBarBlurEnabled,
              includeStatusBar: chrome.statusBarShowsBackdrop,
              weekdayBarHeight: TimetableWeekdayHeader.height,
              // 实体档那条实心条要与标题行同一个底色来源（页面底色）。
              solidColor: chrome.pageBackgroundColor,
            ),
          HyperosRootPage(
            overlayHeader: false,
            backgroundColor: chrome.scaffoldBackgroundColor,
            headerDecoration: BoxDecoration(color: chrome.headerBarColor),
            headerPadding: EdgeInsets.fromLTRB(
              8,
              0,
              8,
              chrome.headerUsesFrostedChrome ? 0.0 : 2.0,
            ),
            systemOverlayStyle: HyperosColors.systemOverlayForBackground(
              chrome.systemOverlayBackground,
            ),
            title: title,
            suffixes: suffixes,
            child: Padding(
              padding: EdgeInsets.only(
                // 日课表的列表视口保持全屏：避让改为列表自身的滚动 padding。
                bottom: glassDockForm && !isDayView ? 0.0 : 0.0,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: isLoading
                    // Single-stage: system splash already covers loading;
                    // render matching background to avoid spinner flash
                    // if provider momentarily reports loading post-splash.
                    ? ColoredBox(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF121212)
                            : Colors.white,
                      )
                    : MediaQuery.removeViewInsets(
                        context: context,
                        removeBottom: true,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            weekSurface,
                            if (isPullRunning || pullDragDistance > 0)
                              TimetableHomePullQuickImportIndicator(
                                dragDistance: pullDragDistance,
                                triggerDistance: pullTriggerDistance,
                                isRunning: isPullRunning,
                                hasBackdrop: chrome.hasBackdrop,
                                onCancel: onPullCancel,
                                l10n: l10n,
                              ),
                            ?backToCurrentWeek,
                            ?backToToday,
                          ],
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
