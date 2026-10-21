import 'package:flutter/material.dart';

import '../../models/timetable_settings.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../utils/home_page_background.dart';
import '../../widgets/preblurred_wallpaper_glass.dart';

typedef TimetableHomeWrap =
    Widget Function(Widget content, {Widget? dockLayer});

/// 首页与玻璃坞/内嵌页之间的外壳（2026-10-19 从 build 搬出）。
///
/// 负责：预模糊壁纸作用域、玻璃坞内嵌页的 Offstage/TickerMode 保活、内嵌页
/// Scaffold、以及把最终内容交给调用方的顶栏包装回调。是否玻璃坞、内嵌页是谁
/// 都由调用方注入。
class TimetableHomeDockShell extends StatelessWidget {
  final Widget homeStack;
  final bool useHomePreblur;
  final TimetableSettings settings;
  final double homePreblurSigma;
  final double? courseCardPreblurSigma;
  final bool isDayView;
  final PageController weekPageController;
  final PageController Function(TimetableSettings settings)
  ensureDayViewPageController;
  final bool followsWeekPager;
  final Listenable repaint;
  final bool glassDockForm;
  final WidgetBuilder? inlinePageBuilder;
  final double glassDockScrollInset;
  final Widget? dockLayer;
  final TimetableHomeWrap wrapHome;

  const TimetableHomeDockShell({
    super.key,
    required this.homeStack,
    required this.useHomePreblur,
    required this.settings,
    required this.homePreblurSigma,
    required this.courseCardPreblurSigma,
    required this.isDayView,
    required this.weekPageController,
    required this.ensureDayViewPageController,
    required this.followsWeekPager,
    required this.repaint,
    required this.glassDockForm,
    required this.inlinePageBuilder,
    required this.glassDockScrollInset,
    required this.dockLayer,
    required this.wrapHome,
  });

  @override
  Widget build(BuildContext context) {
    final dockContent = useHomePreblur
        ? PreblurredWallpaperScope(
            // Same pre-blur model as the week grid: sample one cached frost
            // bitmap by card screen position. In day view the week pager is
            // locked, so drive repaints from the day agenda pager and treat the
            // wallpaper as screen-fixed (it never follows the day swipe).
            wallpaperPath: homePageBackdropKey(settings),
            blurSigma: homePreblurSigma,
            // 卡片那份位图（只有卡片是液态档才烤）。同一份路径与对齐值，
            // 只有 sigma 不同 —— 所以两张图不会出现取景错位。
            // 卡片那份的 0 是有效值（清档：出原图），只有 null 才是不烤 ——
            // 所以这里不做 `?? 0` 折算，null 必须原样传下去。
            cardBlurSigma: courseCardPreblurSigma,
            // 卡里的位图必须与屏幕上那张真壁纸**同一套 cover 对齐**：用户
            // 在「壁纸位置」里拖过对齐值之后，居中铺图的副本就会与背景错位
            // （卡内外壁纸接不上），所以这两个值随设置一起传。
            wallpaperAlignX: settings.homePageWallpaperAlignX,
            wallpaperAlignY: settings.homePageWallpaperAlignY,
            wallpaperScale: settings.homePageWallpaperScale,
            pageController: isDayView
                ? ensureDayViewPageController(settings)
                : weekPageController,
            followsPager: isDayView ? false : followsWeekPager,
            // 锚点展开/收起与设置页拖动转场期间卡片在移动而壁纸屏幕固定：
            // fill 必须每帧重采样，否则纹理停在旧屏幕位置（卡片半边模糊半边
            // 透明）。合并两个动画统一驱动重采样。
            repaint: repaint,
            child: homeStack,
          )
        : homeStack;
    if (!glassDockForm) {
      return wrapHome(dockContent);
    }
    final inlineBuilder = inlinePageBuilder;
    // 内嵌页整屏盖住首页时，把玻璃钉进**冻结态**（用预糊壁纸位图，不依赖实时
    // 采样）。这与路由转场是同一件事的两种来源，所以喂同一个聚合信号。
    //
    // 不这么做的话：进去时首页停止绘制、球的采样图停在旧画面（当时看不出，
    // 因为画面本来没变）；退出时首页恢复绘制，球却要等下一次回读才更新 ——
    // 那一帧就是用户看到的"闪"（2026-10-21：「切进去不闪，切出来到日视图会闪」）。
    //
    // ⚠️ 必须**帧后**再写：`glassFrozen` 是 `ValueNotifier`，在 build 期间改它
    // 会同步触发订阅者重建 —— 那是"build 期间要求重建"的经典断言
    //（`setState() or markNeedsBuild() called during build`）。
    // 记下目标值，帧末统一落一次，值相同则不发通知（信号自身去重）。
    // 只在**值真的变了**时才排回调：本组件是 StatelessWidget，每次 build 都排
    // 一个 post-frame 回调会让队列无限增长（而 setHomeScreenCovered 内部虽然
    // 去重，回调本身仍然在排队）。
    final covered = inlineBuilder != null;
    if (HyperosGlassBackdropController.homeScreenCovered.value != covered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HyperosGlassBackdropController.setHomeScreenCovered(covered);
      });
    }
    final Widget hostedContent = inlineBuilder == null
        ? dockContent
        : Stack(
            fit: StackFit.expand,
            children: [
              // 内嵌页是**不透明**的整屏 Scaffold，会把首页完全盖住；但 Stack
              // 的两个孩子每帧都会被绘制，于是内嵌态下首页那一整套（满屏壁纸
              // 铺底 + 玻璃带 backdrop 采样 + 课程卡片）一直在白白重画。
              // 用 Visibility(maintainSize) 保留挂载与布局、只去掉绘制（返回
              // 首页仍是闪现直切，几何/滚动位置不受影响），并用 TickerMode
              // 停掉被完全遮挡页面的动画节拍。
              TickerMode(
                enabled: false,
                child: Visibility(
                  visible: false,
                  maintainState: true,
                  maintainSize: true,
                  maintainAnimation: true,
                  child: dockContent,
                ),
              ),
              // 与旧「设置 Tab」一致：点底栏闪现直切，无滑动转场。
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: Scaffold(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    body: HyperosSubpageNoBack(
                      // 玻璃坞满屏悬浮对所有内嵌页生效：注入底部滚动余量
                      // （与日/周课表同口径），列表末尾可整体滑到药丸上方；
                      // HyperosListView 自动消费，新增内嵌页无须逐页适配。
                      child: GlassDockScrollReliefScope(
                        inset: glassDockScrollInset,
                        child: Builder(builder: inlineBuilder),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
    // 系统返回不拦内嵌页：与日/周课表同口径，底栏任意状态按返回都直接退出
    // 应用（根路由 bubble → 系统退出）。收回内嵌页走底栏切换与圆钮再点。
    return wrapHome(hostedContent, dockLayer: dockLayer);
  }
}
