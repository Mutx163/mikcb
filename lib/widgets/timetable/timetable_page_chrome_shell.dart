import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/timetable_settings.dart';
import '../../providers/timetable_provider.dart';
import '../../ui/home/home_chrome_spec.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../utils/home_page_background.dart';
import '../home_menu_catalog.dart';
import '../home_page_region_blur.dart';
import '../home_top_menu.dart';
import '../home_top_menu_popup.dart' show kHomeMenuCollapseBudget;
import '../preblurred_wallpaper_glass.dart';
import 'about_update_navigation.dart';
import 'timetable_add_course_sheet.dart';
import 'timetable_form_pages.dart';
import 'timetable_home_action_page_button.dart';
import 'timetable_home_header.dart';
import 'timetable_title_bar.dart';
import 'timetable_profile_switch_flow.dart';
import 'timetable_profile_switcher_trigger.dart';
import 'timetable_top_menu_shell.dart';

/// 独立页面的「壁纸 + 连续玻璃带 + 顶栏软件名字 + 右上角菜单」外壳
/// （2026-10-20 立，月视图首个消费者）。
///
/// ## 它解决什么
///
/// 周视图与日视图长在首页那条栈里（`TimetableHomeStack` + `TimetableHomePageAssembly`）：
/// 壁纸层、`BackdropGroup`、连续玻璃带、常驻玻璃球、顶栏菜单全由首页 State 铺好。
/// **月视图**这类从八宫格 / 底栏打开的独立页面拿不到那套 Stack —— 它要么自己搭，
/// 要么就只能长成一团浮在纯色上的卡片（首版就是这样）。
///
/// ## 首版为什么「像设置页」
///
/// 月视图首版写的是
/// `homePageBackgroundLayer(visual: resolveHomePageRegionBackground(…))`，
/// 以为这就是「铺壁纸」。实际那两条在本仓**从不画图**：
/// `resolveHomePageRegionBackground` 的三个返回点只有 `color`（全仓没有任何一处
/// 给 `HomePageBackgroundVisual` 传 `imageProvider`），有壁纸时它返回
/// `transparent`，于是 `homePageBackgroundLayer` 直接 `return child` ——
/// **一个像素都没铺**，透出来的是 `Scaffold.backgroundColor` 那层纯色。
/// 真壁纸只有 [homePageBackdropLayer] 会画（首页与设置页预览都走它）。
///
/// ## 为什么这页滑动卡
///
/// 42 个格子每格一张 [CourseSurface] 玻璃卡。玻璃档（高斯 / 液态）在
/// `CourseSurface` 里是 `BackdropFilter.grouped`。Flutter 的 backdrop **共享是
/// opt-in**：`grouped` 只在祖先有 `BackdropGroup` 时才拿到非空 `BackdropKey`
/// （SDK `widgets/basic.dart` 的 `_getBackdropGroupKey`），否则**每个 filter 各自
/// 抓一份全屏 backdrop**。月视图既没有 `BackdropGroup` 也没有
/// `PreblurredWallpaperScope`（拿不到预糊位图那条便宜路径），于是翻月 / 滚动时
/// 每帧 42 次全屏抓取。
///
/// 本外壳一次补齐三样：**真壁纸** + **一个 `BackdropGroup`** + **预糊位图作用域**
/// （卡片改走「贴一张糊好的位图」，而不是各自实时模糊）。
///
/// ## 四条不能动的纪律（每条都有真机事故背书）
///
/// 1. **壁纸必须用 [homePageBackdropLayer]**（原因见上）。
/// 2. **`BackdropGroup` 必须包住壁纸 + 正文 + 组捕获**，否则玻璃卡各抓一份全屏。
/// 3. **玻璃带画在正文之下**：[HomePageContinuousChromeFrostedOverlay] 必须是
///    正文那个 `Positioned.fill` 的**前**一个孩子 —— 与首页那条栈同一位次
///    （`TimetableHomeStack` 里它是 `HyperosRootPage` 的前一个孩子）。带子只
///    负责「把这块壁纸换成玻璃」，标题与工具行的文字必须在它之上，否则字会被
///    那层磨砂 / 染色盖住，读起来发灰。
/// 4. **玻璃球不许长在组捕获里**：它自己的输出会被烘进下一次采样，打开菜单再关，
///    球会「变一次材质」（真机 2026-09-14）。[TimetableHomeTopMenuShell] 已经把
///    球与坞摆在宿主之外，本外壳只把壁纸与正文交给它。
class TimetablePageChromeShell extends StatefulWidget {
  const TimetablePageChromeShell({
    required this.toolbarHeight,
    required this.body,
    required this.topLuminance,
    required this.bodyLuminance,
    this.toolbar,
    this.pagingRepaint,
    super.key,
  });

  /// 标题行下面的工具行（月视图的「返回 + 上月 / 年月 / 下月 + 回本月」）。
  /// null = 没有工具行，玻璃带只到标题行为止。
  final Widget? toolbar;

  /// 工具行高度（逻辑 px）。**必须与 [toolbar] 自己占的高度同值** ——
  /// 玻璃带几何按它算，写歪了带底与工具行错开几像素，读成一条横贯屏幕的缝
  /// （真机 2026-09-20「星期栏底边一条黑线」同族）。没有工具行时传 0。
  final double toolbarHeight;

  /// 正文。
  final Widget body;

  /// 壁纸**顶部带**（状态栏 + 标题行）亮度，用于判顶栏墨色极性。
  /// null = 还没采到 / 没有壁纸，回落主题墨色。
  final double? topLuminance;

  /// 壁纸**主体带**（正文 / 卡片区）亮度，用于判卡面墨色。
  final double? bodyLuminance;

  /// 卡片**相对屏幕移动**时驱动预糊位图重采样的 Listenable。
  ///
  /// 预糊填充画在各自的 `RepaintBoundary` 里：卡片一移动，纹理就会被**整块搬走**
  /// 而不是按新屏幕位置重新取景 —— 玻璃里那层背景跟着卡片走、看着像"背景不动"
  /// （用户 2026-10-21 口径：「玻璃左右滑动是正常的，上下滑动是玻璃内部背景不动
  /// 的」）。
  ///
  /// 横向翻页与纵向收缩是**两条不同的运动源**，必须都接上：
  /// - 翻月：`PageController`（横向位移）；
  /// - 收起 / 展开网格：那个 `AnimationController`（卡片纵向位移，没有滚动发生）。
  ///
  /// 页面应当传 `Listenable.merge([翻页控制器, 展开控制器])`。只传前者就是这次
  /// 的 bug：左右滑正常、上下收放时玻璃内部背景纹丝不动。
  final Listenable? pagingRepaint;

  /// 标题行高度：与 `HyperosRootHeader.minHeight` /
  /// `homePageHeaderContentHeight` 同值。不许另取整数 —— 玻璃带几何、状态栏遮罩、
  /// 正文顶边距全按它推。
  static const double titleRowHeight = homePageHeaderContentHeight;

  /// 玻璃带下沿与正文之间那条缝隙（与首页同一个 token）。带子会把这段一起盖住，
  /// 正文因此不会被切出一条「没有玻璃」的边。
  static const double bandSeam = homePageFrostedRegionSeamOverlap;

  @override
  State<TimetablePageChromeShell> createState() =>
      _TimetablePageChromeShellState();
}

class _TimetablePageChromeShellState extends State<TimetablePageChromeShell> {
  /// 本屏玻璃采样源。必须自持并交给 [TimetableHomeTopMenuShell]：画在宿主之外的
  /// 球与弹层要按**本屏**画面采样，而不是「注册表栈顶」（栈顶会随 push / pop
  /// 换人 —— 真机：「进设置再回来，爱心变一半透明一半实底」）。
  final HyperosGlassBackdropController _glass =
      HyperosGlassBackdropController();

  /// 「更多」菜单的形变锚点（扣在真实按钮上）。
  final MiuixGlassPopupAnchor _anchor = MiuixGlassPopupAnchor();

  /// 常驻玻璃球与真实按钮之间的跟随锚。
  final LayerLink _moreBallLink = LayerLink();

  /// 爱心球的跟随锚。独立页面**不显示**爱心（情侣覆盖层是首页专属），
  /// 但布局函数要求传一个锚，这里给一个不挂 target 的空锚：对应控件不在树上，
  /// 跟随层没有 leader 就不会画（ 的入参门禁）。
  final LayerLink _heartLink = LayerLink();

  /// 「更多」透明点击区的 key（八宫格形态要在原位置弹弹层时用）。
  final GlobalKey _moreButtonKey = GlobalKey();

  bool _menuOpen = false;

  @override
  void dispose() {
    _anchor.dispose();
    _glass.dispose();
    super.dispose();
  }

  /// 「按下即预热」：采样区快照在帧末录制，早一拍才能保证菜单首帧有玻璃。
  ///
  /// 用 `holdRecording` 而不是 `acquire()`：本仓弹层都走注入面（读「玻璃背后
  /// 那条带」），整层图没人读，而 `acquire()` 会在整个开合动画期间每帧录一张
  /// 全屏（按 dpr 约 6.7MB/帧）。
  void _prewarmGlass() => _glass.holdRecording();

  /// 抬手后帧末再判要不要归还。
  ///
  /// 不能在抬手当场归还：`onPointerUp` 早于 `onPress`，而 `_menuOpen` 是在
  /// `onPress` 里才置真的 —— 当场归还就会 arm → release → arm 走一遍，中间那次
  /// 让正文白重录一次（首页同款时序，见 `HomeMenuController.releaseGlassAfterTap`）。
  void _releaseGlass() {
    if (_menuOpen) {
      return;
    }
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_menuOpen) {
        _glass.releaseRecording();
      }
    });
  }

  Future<void> _showMenu() async {
    final settings = context.read<TimetableProvider>().settings;
    if (settings.homeMenuStyle == HomeMenuStyle.grid) {
      // 八宫格是底部弹层，不吃本屏采样源：抬手即归还。
      _glass.releaseRecording();
      final selectedId = await showHomeTopGridMenuSheet(
        context,
        hasAvailableUpdate: false,
        entries: resolveHomeGridMenuEntries(settings),
        themeSeedHex: settings.themeSeedColor,
      );
      if (!mounted || selectedId == null) {
        return;
      }
      await _dispatch(selectedId);
      return;
    }
    // 列表形态：常驻玻璃弹层，与首页同一个组件、同一条预热时序。
    _prewarmGlass();
    setState(() => _menuOpen = true);
  }

  void _closeMenu() {
    if (_menuOpen) {
      setState(() => _menuOpen = false);
    }
    _glass.releaseRecording();
  }

  /// 菜单项分发。**时序与首页一致**：菜单先收完，再执行选中项。
  ///
  /// 首页专属的六条启动路径（带当前可见周 / 日视图选中日）在这里按 provider 的
  /// 当前周与今天兜底 —— 与八宫格从别的入口点进来时的既有口径一致
  /// （见 `home_menu_catalog.dart` 的 `shareTimetable` 条目注释）。
  Future<void> _dispatch(String selectedId) async {
    final provider = context.read<TimetableProvider>();
    final settings = provider.settings;
    if (settings.enableHaptics) {
      HapticFeedback.selectionClick();
    }
    final wasOpen = _menuOpen;
    _closeMenu();
    if (wasOpen) {
      await Future<void>.delayed(kHomeMenuCollapseBudget);
      if (!mounted) {
        return;
      }
      // 锚点那颗球的图标上游要等退场动画彻底结束才交还（≈670ms），比这里的
      // 280ms 预算晚得多 —— 此刻交还，顶栏才不会留下一个空球。
      if (_anchor.contentHidden) {
        _anchor.contentHidden = false;
      }
    }
    if (!mounted) {
      return;
    }
    await dispatchTimetableTopMenuSelection(
      context,
      selectedId,
      TimetableTopMenuLaunchers(
        openAddCoursePicker: () => showTimetableAddCourseSheet(
          context: context,
          initialWeek: provider.currentWeek,
          initialDayOfWeek: DateTime.now().weekday,
          initialScheduleDate: DateTime.now(),
        ),
        openCourseForm: () => Navigator.of(context).push<void>(
          HyperosPageRoute<void>(
            builder: (_) => timetableFormPages.courseForm(
              initialWeek: provider.currentWeek,
              initialDayOfWeek: DateTime.now().weekday,
            ),
          ),
        ),
        openScheduleForm: () => Navigator.of(context).push<void>(
          HyperosPageRoute<void>(
            builder: (_) => timetableFormPages.scheduleItemForm(
              initialDate: DateTime.now(),
            ),
          ),
        ),
        openExamForm: () => Navigator.of(context).push<void>(
          HyperosPageRoute<void>(builder: (_) => timetableFormPages.examForm()),
        ),
        openUpdate: () => openTimetableAboutUpdatePage(context),
        // 分享**走目录条目自己的 open**，不直接调分享服务：
        // 独立页面没有「当前可见周 / 日视图选中日」，而那条目录条目的 open 本来
        // 就是「从别的入口点进来时分享当前周」的兜底实现（见
        // `home_menu_catalog.dart` 的 `shareTimetable` 注释）。这样这里也不必
        // 跟着分享服务的签名变化走。
        shareTimetable: () async {
          final entry = homeMenuEntryById('shareTimetable');
          if (entry != null) {
            await entry.open(context);
          }
        },
      ),
    );
  }

  /// 点标题 → 切换配置档（与首页同一个弹层、同一个去处）。
  ///
  /// 「配置档管理页」走八宫格路由目录取页（`timetableProfilesPage`），不另立
  /// 一条注入通道：那张表已经是「id → 页面构造」的唯一真源。
  Future<void> _openProfileSwitcher() {
    final provider = context.read<TimetableProvider>();
    return showTimetableProfileQuickSwitchFlow(
      context,
      provider: provider,
      popupSourceRect: popupActionSourceRect,
      openManagePage: (hostContext, sourceRect) => openTimetablePopupActionPage(
        hostContext,
        pageBuilder: (_) => homePage('timetableProfilesPage'),
        sourceRect: sourceRect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final settings = provider.settings;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    // 与首页**同一个**解析函数：背景色、墨色极性、玻璃带开关、预糊 sigma 全在
    // 这里一次算完。独立页面只多提供一份壁纸亮度（首页那份住在首页 State）。
    final chrome = resolveHomeChromeSpec(
      context: context,
      settings: settings,
      isDark: isDark,
      darkFallback: colorScheme.surface,
      wallpaperTopLuminance: widget.topLuminance,
    );
    final hasToolbar = widget.toolbar != null && widget.toolbarHeight > 0;

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: _wallpaperLayer(chrome)),
        if (chrome.hasBackdrop && !chrome.statusBarShowsBackdrop)
          HomePageStatusBarBackdropMask(color: chrome.pageBackgroundColor),
        if (chrome.continuousChromeBlur) const HomeChromeGroupCapture(),
        // 连续玻璃带：**在正文之下画**（与首页那条栈同一位次 ——
        // `TimetableHomeStack` 里它是 `HyperosRootPage` 的前一个孩子）。
        // 带子只负责「壁纸换成玻璃」，标题与工具行的文字必须在它**之上**，
        // 否则字会被那层磨砂 / 染色盖住，读起来发灰发糊。
        if (chrome.chromeBandPaints)
          HomePageContinuousChromeFrostedOverlay(
            headerBlurEnabled: settings.homePageHeaderBlurEnabled,
            weekdayBarBlurEnabled:
                hasToolbar && settings.homePageWeekdayBarBlurEnabled,
            includeStatusBar: chrome.statusBarShowsBackdrop,
            weekdayBarHeight: hasToolbar ? widget.toolbarHeight : 0,
            solidColor: chrome.pageBackgroundColor,
          ),
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            // Material 在树上但**不画任何东西**：工具行里的 `IconButton` 需要
            // 一个 Material 祖先才肯画水波纹（`debugCheckHasMaterial` 断言）。
            // 页面正文自己不带 Scaffold（铺壁纸的那层就是本外壳），所以这里补。
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: TimetablePageChromeShell.titleRowHeight,
                    child: _buildTitleRow(
                      l10n: l10n,
                      settings: settings,
                      provider: provider,
                      chrome: chrome,
                    ),
                  ),
                  if (hasToolbar)
                    SizedBox(
                      height: widget.toolbarHeight,
                      child: HomePageChromeInk(
                        foreground: chrome.chromeForeground,
                        mutedForeground: chrome.chromeMutedForeground,
                        child: widget.toolbar!,
                      ),
                    ),
                  // 与首页同一条缝隙 token：带子把这段一起盖住，正文首行不会被
                  // 切在「有玻璃」与「没玻璃」的交界上。
                  if (hasToolbar && chrome.chromeBandPaints)
                    const SizedBox(height: TimetablePageChromeShell.bandSeam),
                  Expanded(child: widget.body),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    // 预糊位图作用域在最外：卡片按屏幕坐标从同一张位图取自己那一块，走「贴图」
    // 而不是「实时模糊」。两张图（首页那份 / 卡片那份）与首页同参，首页已经
    // 烤好的会直接命中缓存，不多花显存。
    final scoped = chrome.useHomePreblur || chrome.useCoursePreblur
        ? PreblurredWallpaperScope(
            wallpaperPath: homePageBackdropKey(settings),
            blurSigma: chrome.homePreblurSigma,
            cardBlurSigma: chrome.useCoursePreblur
                ? chrome.courseCardPreblurSigma
                : null,
            wallpaperAlignX: settings.homePageWallpaperAlignX,
            wallpaperAlignY: settings.homePageWallpaperAlignY,
            wallpaperScale: settings.homePageWallpaperScale,
            // 卡片一动（横向翻页 / 纵向收放）壁纸都钉在屏幕上：必须每帧重取景，
            // 否则磨砂纹理被整块搬走 —— 玻璃里的背景跟着卡片走，
            // 读起来就是"上下滑动时玻璃内部背景不动"。
            repaint: widget.pagingRepaint,
            child: stack,
          )
        : stack;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: HyperosColors.systemOverlayForBackground(
        chrome.systemOverlayBackground,
      ),
      child: TimetableHomeTopMenuShell(
        // 组必须包住壁纸 + 正文 + 组捕获（纪律 2）；球与坞由外壳摆在宿主之外。
        content: BackdropGroup(child: scoped),
        glassController: _glass,
        showMenu: _menuOpen,
        anchor: _anchor,
        anchorContent: HomeMoreActionIcon(
          ink: context.theme.colors.foreground,
          dotBorderColor: chrome.chromeDotBorderColor,
          // 更新红点住在首页 State 的检查结果里。独立页面不另起一份检查，
          // 也不画这个点 —— 宁可少一个点，也不要两处口径不同步。
          showUpdateDot: false,
        ),
        entries: resolveHomeGridMenuEntries(settings),
        hasAvailableUpdate: false,
        onDismissRequest: _closeMenu,
        onSelected: _dispatch,
        onDismissFinished: () {
          // 弹层退场真正走完（面板已摘除、锚点图标已交还）。此处只负责把
          // 「等退场」的那条路径提前放行；常态是 280ms 预算先到。
          if (mounted && !_menuOpen && _anchor.contentHidden) {
            _anchor.contentHidden = false;
          }
        },
        chromeBalls: buildTimetableHomeChromeBalls(
          homeMenuAnchor: _anchor,
          moreLink: _moreBallLink,
          heartLink: _heartLink,
          // 情侣覆盖层是首页专属的叠加态，独立页面不接。
          hasPartnerBinding: false,
          coupleOverlayActive: false,
          moreIcon: HomeMoreActionIcon(
            ink: context.theme.colors.foreground,
            dotBorderColor: chrome.chromeDotBorderColor,
            showUpdateDot: false,
          ),
          chromeActionBallInk: context.theme.colors.foreground,
        ),
      ),
    );
  }

  /// 标题行：**与首页同一套**——软件名字在左、右上角是玻璃球「更多」。
  ///
  /// 标题直接用首页那个触发器（[TimetableProfileSwitcherTrigger]），不自己写
  /// `Text`：首页两套标题样式（classic / brand）的字号、字重、行高、副行都不一样，
  /// 手抄一份迟早漂开。点击行为也照首页接「切换配置档」，位置与观感才真的同源。
  Widget _buildTitleRow({
    required AppLocalizations l10n,
    required TimetableSettings settings,
    required TimetableProvider provider,
    required HomeChromeSpec chrome,
  }) {
    return HomePageChromeInk(
      foreground: chrome.chromeForeground,
      mutedForeground: chrome.chromeMutedForeground,
      // ⚠️ 这一行**不再在这里拼装**：首页与独立页面曾各写一份，漂了两处
      // （底部内边距一处 0 一处 2 ⇒ 标题整体下移 1px；右侧按钮取法也不同）。
      // 现在两边都走 [TimetableTitleBar]，差异只能改一处。
      //
      // 返回箭头只在「推入路由」这条路上出现：坞内嵌页没有「上一页」语义
      // （切换走底栏、系统返回直接退应用）—— 与 `HyperosSubpageNoBack` 同一套
      // 门禁，这里读同一个作用域。
      child: TimetableTitleBar(
        settings: settings,
        activeProfileName: provider.activeProfile?.name.trim(),
        onProfileTap: _openProfileSwitcher,
        foreground: chrome.chromeForeground,
        mutedForeground: chrome.chromeMutedForeground,
        heartLink: _heartLink,
        moreLink: _moreBallLink,
        menuAnchor: _anchor,
        moreButtonKey: _moreButtonKey,
        onPrewarmGlass: _prewarmGlass,
        onReleaseGlass: _releaseGlass,
        onShowTopActions: _showMenu,
        // 独立页面不接情侣覆盖层（那是首页专属的叠加态），所以爱心整颗不出现
        // —— 布局函数按 `hasPartnerBinding` 门控。两者都用默认值 false，
        // 不再显式传（传了也只是同一件事写两遍）。
        showBackButton: !HyperosSubpageNoBack.of(context),
        // 底部内边距的判据必须来自 chrome spec（综合壁纸 / 管线 / 设置），
        // 不能用单个设置项顶替 —— 判错就又回到"差 1px"。
        headerUsesFrostedChrome: chrome.headerUsesFrostedChrome,
      ),
    );
  }

  /// 壁纸层（纪律 1：必须用 [homePageBackdropLayer]）。
  Widget _wallpaperLayer(HomeChromeSpec chrome) {
    if (!chrome.hasBackdrop) {
      return ColoredBox(color: chrome.pageBackgroundColor);
    }
    return homePageBackdropLayer(
      settings: context.read<TimetableProvider>().settings,
    );
  }
}

/// 顶栏墨色作用域：把「按壁纸亮度判好的墨色」下发给标题与工具行。
///
/// 为什么下发而不是各自算：判据（壁纸亮度 + 玻璃带是否真的透出壁纸）只有外壳
/// 那一处算得准（它手里有 [HomeChromeSpec]）。页面自己再调一次
/// `homePageChromeForegroundForLuminance` 可能拿到不同亮度，出现「标题黑了、
/// 旁边的按钮还是白的」。
class HomePageChromeInk extends InheritedWidget {
  const HomePageChromeInk({
    required this.foreground,
    required this.mutedForeground,
    required super.child,
    super.key,
  });

  /// 顶栏文字正文墨色。
  final Color foreground;

  /// 顶栏次要文字墨色（副标题 / 提示）。
  final Color mutedForeground;

  /// 顶栏墨色；不在本外壳内时返回 null（调用方回落主题色）。
  static Color? foregroundOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<HomePageChromeInk>()
      ?.foreground;

  /// 次要墨色；不在本外壳内时回落主题色。
  static Color mutedOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<HomePageChromeInk>()
          ?.mutedForeground ??
      Theme.of(context).colorScheme.onSurfaceVariant;

  @override
  bool updateShouldNotify(covariant HomePageChromeInk oldWidget) =>
      oldWidget.foreground != foreground ||
      oldWidget.mutedForeground != mutedForeground;
}
