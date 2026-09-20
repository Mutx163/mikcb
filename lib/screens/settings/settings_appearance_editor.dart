part of '../timetable_settings_screen.dart';

/// 「外观编辑」页：**沉浸式**的一页 —— 整屏暗底，中间一张**真首页缩尺卡**，
/// 顶部一行标题 + 日 / 周切换 + 取消 / 完成，底部一排圆形玻璃入口。
///
/// 用户口径（2026-09-19，六轮）：
/// * 微缩预览是「把整个首页原样缩小」，**直接用首页那份代码**，观感一致、完整
///   展示（顶部底部都不被切）、摆在屏幕中间；卡片里不能误操作；切日 / 周不能
///   改首页真实的浏览状态；
/// * 不要大标题 + 小标题那两行；日 / 周切换按钮放顶部；顶部完成 / 取消；
///   底部「调整壁纸」「材质」两个入口；
/// * 弹窗打开时上下 chrome **保持常显**（第六轮明确，取代最初照参考实现做的
///   「淡出让位」）；
/// * 进页时卡片不得闪跳（玻璃圈/壁纸先偏在一侧再跳正）—— 转场落定后才烤图。
///
/// 预览实现（**方案 A：烤图**，2026-09-19 定案；参考实现 hyper_schedule 的卡片
/// 同款机制 —— 录一帧真实内容树，按比例显示位图）：
///
/// * 真首页本体（[TimetableScreen]）在页面底层按**整屏 1:1** 渲染：不缩放、
///   不另排一套小屏布局，被不透明底衬盖住，只为烤图而活。玻璃采样链、按屏幕
///   摆位的浮动层全部工作在原生尺度上 —— 前三轮「FittedBox 活树直显」在缩放
///   尺度下逐处折算采样坐标的做法（真机三验仍有残留：贴图玻璃透过玻璃看到的
///   内容差一档放大率）整类问题不再存在；
/// * [PreviewBakeBoundary] 在渲染源每次重绘后帧末把整层出成一张图；卡片显示
///   这张图，出图密度**严格等于设备 dpr**（不能乘显示缩放——离屏回放的
///   FragCoord 密度与玻璃着色器的坐标折算必须一致，真机实锤见该类注释），
///   显示时 GPU 等比缩进卡片 —— 卡片观感就是首页渲染结果等比缩小，拖滑杆时
///   一档一图实时跟随；进页转场落定**前不烤图**（[_routeSettled]），落定后
///   整层按落定坐标重录再烤，卡片淡入正确画面 —— 转场帧的脏坐标进不了卡片；
/// * 日 / 周、进页不进回访状态这些外部控制走 [TimetableHomePreviewScope]
///   （首页一侧在预览模式下不写浏览状态、不接截屏监听，见该 scope 的类注释）；
/// * 卡片圆角取**真机屏幕圆角**并按缩放比例收小，所以卡片读起来就是
///   「这台机器的那一屏」。
///
/// 编辑语义：本页与别的设置页一样**即时落盘**（弹窗里改一下预览就变），
/// 「取消」= 用进页时的那份设置回滚，「完成」= 保留并返回。
class _AppearanceEditorScreen extends StatefulWidget {
  const _AppearanceEditorScreen();

  @override
  State<_AppearanceEditorScreen> createState() =>
      _AppearanceEditorScreenState();
}

class _AppearanceEditorScreenState extends State<_AppearanceEditorScreen>
    with _HomeBackdropFlow<_AppearanceEditorScreen> {
  /// 沉浸式底衬：与参考实现同色（不透明深底，只有卡片是亮的）。
  /// 沉浸暗底。**就是缩放转场那半边的 `backdropColor`**（同一个常量，不是
  /// 碰巧同色）：首页缩进卡片之后由这层暗底接管整屏背景，两边只要不是同一个
  /// 值，接管那一帧就会看到一下轻微提亮/压暗。
  static const _scrimColor = HyperosZoomRoute.backdropColor;

  /// 卡片相对可用区的最大宽度比例（剩下的留白保证「在屏幕中间、不顶边」）。
  static const _cardMaxWidthFactor = 0.82;

  /// 材质面板**整体**最多占屏幕的比例（用户口径 2026-09-20）。
  ///
  /// 全屏（改之前实测占 76%）会把它上面那张预览小屏盖掉 —— 而这块面板存在的
  /// 意义就是「改一处、看预览」。超出这一高度的内容在面板内部滚动。
  static const _materialSheetMaxHeightFactor = 0.5;

  /// 当前打开的弹层（壁纸 / 材质）的「请求收起」口子；没有弹层时 null。
  ///
  /// 壁纸流程要推整页（位置编辑页）时必须先调它 —— 弹层面板是插进**根覆盖层**的
  /// 条目，`OverlayState.rearrange` 把非路由条目排在所有路由**之上**，弹层开着时
  /// 推的页面会落在面板下面、被它的全屏透明屏障挡住点击（用户口径：「调整页面出来
  /// 的时候在弹窗背后，什么东西都点不到」）。机制详见 `showHomeHyperosSheet` 的注释。
  MiuixBottomSheetClose? _sheetClose;

  /// 面板里**内容之外**、在内容上方的那一圈（上沿把手栏）。
  ///
  /// 实测值：同一套真机视口下，面板顶到内容顶差 42.0（把手 + 面板自己的上内边距）。
  /// 内容的高度上限要把它（以及下方的安全区 + 呼吸）扣掉，**面板整体**才是
  /// [_materialSheetMaxHeightFactor]。这个数是量出来的，改承载壳的把手要重新量
  /// （`appearance_editor_layout_test` 里那条面板高度用例会跟着红）。
  static const _materialSheetTopChromeHeight = 42.0;

  /// 材质面板内容的高度上限（面板整体 = 内容 + 上把手栏 + 底部安全区 + 呼吸）。
  static double _materialSheetContentMaxHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.size.height * _materialSheetMaxHeightFactor -
        _materialSheetTopChromeHeight -
        media.padding.bottom -
        hyperosMiuixBottomSheetContentBottomGap;
  }

  /// 本页自己的玻璃采样源。
  ///
  /// 为什么必须有：卡片里那份真首页自带一个采样宿主，但它套在本页里 ——
  /// 每个宿主只在「自己上面没有别的屏级作用域」时才登记到全局注册表（见
  /// HyperosGlassBackdropHost._syncRegistration）。本页先立一层作用域，卡片里那层
  /// 就成了「屏内嵌屏」，不会去顶掉注册表；而本页打开的弹窗（壁纸 / 材质）按注册表
  /// 取源，拿到的就是这一层 = 整屏画面，而不是卡片里那一小块。
  final HyperosGlassBackdropController _pageGlass =
      HyperosGlassBackdropController();

  late final TimetableProvider _timetableProvider;
  late TimetableSettings _draft;

  /// 进页时的快照：只服务「取消」回滚。
  late final TimetableSettings _openedWith;

  Timer? _autoSaveTimer;
  Future<void> _saveQueue = Future<void>.value();

  /// 草稿版本号：每次草稿变化自增。
  ///
  /// 只有**底部弹层里的正文**需要它：弹层是独立路由（不在本页 widget 树下），
  /// 本页 `setState` 带不动它们里面的内容，于是「弹窗里改一下，弹窗自己还显示
  /// 旧值」——真机表现是材质面板拖滑杆数字不动、壁纸弹窗清除后那行仍写着原
  /// 文件名（2026-09-20 修）。两处弹层正文都订阅它重画，不再各自维护重画开关。
  final ValueNotifier<int> _draftRevision = ValueNotifier<int>(0);

  /// 预览看日课表还是周课表（只影响这份缩尺首页，不动真实浏览位置 —— 首页侧
  /// 在预览模式下不写回访状态，见 [TimetableHomePreviewScope]）。
  ///
  /// **跟首页当前的视图走**，与 [_previewDayView] 同一个来源（首页自己恢复
  /// 视图用的那份持久化状态）：用户在日视图里进编辑页，卡片、预览与顶部分段
  /// 按钮就都停在「日」，三者从第一帧起一致。反过来（预览固定从周视图起步）
  /// 会出现「卡片先显示首页快照的日视图、转场一结束跳成周视图」的闪跳
  /// （用户 2026-09-20 反馈的「闪现到周视图」）。
  bool _dayPreview = false;

  /// 驱动嵌进来的那份真首页开合日视图（它的日视图状态在它自己的 State 里）。
  late final ValueNotifier<bool> _previewDayView;

  /// 日视图预览看哪一天（1 = 周一 … 7 = 周日）：与首页底栏「日课表」Tab 同源，
  /// 取持久化的「上次看到的那一天」（不取今天 —— 首页日视图也看的是它）。
  late final ValueNotifier<int> _previewDayOfWeekNotifier;

  /// 渲染源烤出来的整页快照（卡片显示的就是它）。
  ///
  /// 由 [PreviewBakeBoundary] 写入（每次渲染源重绘后帧末一张，旧图随之释放）；
  /// 最后一张在本页 dispose 时释放。
  final ValueNotifier<ui.Image?> _previewBake = ValueNotifier<ui.Image?>(null);

  /// 本页路由是否已落定（进场转场结束）。
  ///
  /// 落定前**不烤图**：转场帧里玻璃着色器与壁纸对齐取的是带转场变换的屏幕
  /// 坐标，烤出来玻璃圈/壁纸整体偏在一侧（真机现象：右上角玻璃圈先在卡片
  /// 左边闪一下才跳回右边、底栏玻璃闪一下）。落定后翻 true，边界整层重画
  /// 一遍按落定坐标重录，第一张烤图就是正的。
  bool _routeSettled = false;

  /// 本页路由的入场动画：落定时刻从这里来（见 [_onRouteAnimationStatus]）。
  Animation<double>? _routeAnimation;

  /// 本页是否走「首页缩进预览小屏」那条缩放转场（[HyperosZoomPageRoute]）。
  ///
  /// 只有它才有"按进度分层出场"这回事；万一本页将来被别的路由类型推起来
  /// （普通推页 / 直接 pump 进测试），一律按**已落定**处理（进度恒为 1），
  /// 否则页面会在普通侧滑的头半程整片隐形。
  bool _zoomDriven = false;

  /// 缩放转场的总进度（0→1）。页面按它分层出场：
  ///
  /// * 暗底与"不透明底衬"用 [HyperosZoomRoute.growT] —— 首页缩进卡片之后，
  ///   编辑页的暗底才接管背景（它与首页那半边的 `backdropColor` 同值，所以
  ///   接管这一下看不见）；
  /// * chrome（顶部胶囊 / 底部按钮）更晚，用 [HyperosZoomRoute.chromeT] ——
  ///   用户 2026-09-20 口径：「缩放结束以后，才显示页面上的按钮」。
  ///
  /// 用 notifier 而不是 `setState`：每帧只有那几个薄薄的出场层跟着重建，
  /// 页面里最贵的渲染源与卡片不跟着走。
  final ValueNotifier<double> _zoomProgress = ValueNotifier<double>(1);

  /// 卡片图源的两路监听（合并成一条 Listenable，避免每帧新建对象换监听）。
  late final Listenable _previewImageSources = Listenable.merge(<Listenable>[
    _previewBake,
    hyperosZoomHomeSnapshot,
  ]);

  // —— _HomeBackdropFlow 的宿主适配：壁纸流程本体在
  // settings_home_backdrop_flow.dart，本页只提供草稿读写与课表列表。

  @override
  TimetableSettings get backdropDraft => _draft;

  @override
  void applyBackdropDraft(TimetableSettings next) => _updateDraft(next);

  @override
  TimetableProvider get backdropProvider => _timetableProvider;

  @override
  void initState() {
    super.initState();
    _timetableProvider = context.read<TimetableProvider>();
    _draft = _timetableProvider.settings;
    _openedWith = _draft;
    // 预览的日 / 周与「看哪一天」照首页那份持久化状态起步（见字段注释）：
    // 三者一致才不会在进页那一帧闪跳。
    _dayPreview = _draft.timetableHomeViewMode == TimetableHomeViewMode.day;
    _previewDayView = ValueNotifier<bool>(_dayPreview);
    _previewDayOfWeekNotifier = ValueNotifier<int>(
      _draft.timetableLastViewedDayOfWeek,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRouteAnimationListener();
  }

  /// 跟踪本页路由的入场动画：初始落定态在这里判（无动画 = 已落定），
  /// 之后只在动画对象换人时换监听。
  ///
  /// ⚠️ 走缩放转场时必须用路由放出的 [HyperosZoomPageRoute.progressSource]
  /// （= 控制器），不能用 `ModalRoute.animation`：后者是代理动画，**进场第一帧**
  /// 整条路由是 offstage，代理被换成恒为 1.0/completed 的占位动画（理由与逐帧
  /// 证据见 `hyperos_zoom_route.dart` 的 `_progressSourceOf`）。照它判"落定"会在
  /// **首帧就放行烤图**（烤到的是带转场坐标的歪画面，正是 [_routeSettled] 要挡的
  /// 东西），照它推出场会让按钮在第一帧就全亮。
  void _syncRouteAnimationListener() {
    final route = ModalRoute.of(context);
    final zoomRoute = route is HyperosZoomPageRoute ? route : null;
    _zoomDriven = zoomRoute != null;
    final animation = zoomRoute?.progressSource ?? route?.animation;
    if (!_routeSettled) {
      _routeSettled = animation == null ||
          animation.status == AnimationStatus.completed;
    }
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _routeAnimation?.removeListener(_onRouteAnimationTick);
    _routeAnimation = animation;
    _routeAnimation?.addStatusListener(_onRouteAnimationStatus);
    _routeAnimation?.addListener(_onRouteAnimationTick);
    _onRouteAnimationTick();
  }

  /// 转场逐帧：把进度递给出场层（见 [_zoomProgress]）。
  ///
  /// 不走本页路由的缩放转场时恒为 1（整页立即可见）。
  void _onRouteAnimationTick() {
    final animation = _routeAnimation;
    if (!_zoomDriven || animation == null) {
      _zoomProgress.value = 1;
      return;
    }
    _zoomProgress.value = HyperosZoomRoute.progress(animation.value);
  }

  /// 入场转场落定：放行烤图；退场开始：立刻撤掉渲染源。
  ///
  /// 转场期间页面带着位移/缩放，渲染源第一帧画的玻璃/壁纸取的是转场坐标，
  /// 那期间烤图必是歪的（真机现象见 [_routeSettled] 注释）；落定后边界整层
  /// 重画一遍再烤，卡片淡入的就是正确画面。
  ///
  /// ⚠️ **退场一开始就必须卸掉渲染源**（用户 2026-09-20 反馈「退出应该是反过来
  /// 的放大效果」）：渲染源是**整屏 1:1 的一份首页**，平时藏在"不透明底衬"后面。
  /// 退场时底衬随出场进度淡出，渲染源就会在首页开始长回全屏**之前**先整屏露出来
  /// —— 观感变成"编辑页淡掉、首页已经满屏在那儿了"，那 180ms 真正的"从小屏长回
  /// 全屏"被它盖住，用户看不到。（逐帧实测：退场前 15 帧快照停在小屏位置不动，
  /// 而渲染源全程在树上。）
  void _onRouteAnimationStatus(AnimationStatus status) {
    if (!mounted) {
      return;
    }
    if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      if (_routeSettled) {
        setState(() => _routeSettled = false);
      }
      _onRouteAnimationTick();
      return;
    }
    if (status == AnimationStatus.completed && !_routeSettled) {
      setState(() => _routeSettled = true);
    }
    _onRouteAnimationTick();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _routeAnimation?.removeListener(_onRouteAnimationTick);
    _zoomProgress.dispose();
    _pageGlass.dispose();
    _previewDayView.dispose();
    _previewDayOfWeekNotifier.dispose();
    _previewBake.value?.dispose();
    _previewBake.dispose();
    _draftRevision.dispose();
    // 滑块 debounce 未到期时若直接返回，只 cancel 会丢最后一档草稿。
    if (_autoSaveTimer?.isActive ?? false) {
      _autoSaveTimer?.cancel();
      _enqueuePersist(_draft);
    } else {
      _autoSaveTimer?.cancel();
    }
    super.dispose();
  }

  void _updateDraft(TimetableSettings next, {bool debounce = false}) {
    setState(() {
      _draft = next;
    });
    _draftRevision.value++;
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
    final provider = _timetableProvider;
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
      _draftRevision.value++;
    }
  }

  /// 完成：保留改动，返回。
  void _finish() {
    Navigator.pop(context);
  }

  /// 取消：把进页时的设置整份写回，再返回。
  ///
  /// 本页所有改动都是即时落盘的（弹窗里改一下，预览立刻变），所以「取消」不是
  /// 什么都不做，而是回滚 —— 否则按钮名与行为不符。回滚后仍走一次正常落盘。
  void _cancel() {
    if (_draft != _openedWith) {
      _updateDraft(_openedWith);
    }
    Navigator.pop(context);
  }

  Future<void> _openWallpaperSheet() {
    final l10n = AppLocalizations.of(context)!;
    // 上下 chrome（取消 / 完成 / 日周切换 / 圆钮）在弹窗打开期间**保持常显**
    //（2026-09-19 用户口径，取代最初照参考实现做的「淡出让位」）：barrier
    // 会把它们压暗、点按被弹层接走，但位置与可见性不变。
    return showHomeHyperosSheet<void>(
      context: context,
      // 收下收起口子：弹窗里那颗「选择图片」/「调整位置」要推整页（位置编辑页），
      // 必须先收起本弹层再推（理由见 [_sheetClose]）。
      closeRef: (close) => _sheetClose = close,
      builder: (_) => HyperosSheetFrame(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: SingleChildScrollView(
          // 订阅草稿版本号：选图 / 清除 / 切「最近使用」之后，弹窗里这两行
          // 立刻跟着变（弹层正文不在本页 widget 树下，页面 setState 带不动它）。
          child: ValueListenableBuilder<int>(
            valueListenable: _draftRevision,
            builder: (sheetContext, _, _) =>
                buildWallpaperSheetBody(sheetContext, l10n: l10n),
          ),
        ),
      ),
    ).whenComplete(() => _sheetClose = null);
  }

  @override
  MiuixBottomSheetClose? get backdropHostSheetClose => _sheetClose;

  /// 材质面板（「材质」弹窗正文）：2026-09-19 第七轮按最新产品口径重排 ——
  /// **整机只有「实体卡片」与「液态玻璃」两种材质**。
  ///
  /// * **锁定件不再显示**：弹窗家族等「恒为液态玻璃标准档」的表面与设置无关，
  ///   已从材质地图摘除（显示也没用）；
  /// * **可调的直接显示**：液态玻璃的预设与调参滑杆从「高级材质」页直接搬进
  ///   面板，不再入口跳转；质感方案（两材质下与模式开关重复）与高斯滑杆
  ///  （高斯档不再提供）一并撤下；
  /// * **观感明显的在前**：整体材质（实体 ↔ 液态）与首页顶栏玻璃置顶；
  ///   调参细项、子页顶栏（卡片里看不见）、各表面地图依次靠后；
  /// * 存量中间档显示按就近归桶（非液态系 → 实体、液态系 → 液态），只有
  ///   用户点选才真正落盘；
  /// * 行部件与设置列表同源；改动即时落盘：渲染源重绘 → 重烤 → 卡片实时
  ///   跟随；「恢复默认」仍归「课表页面」作用域，面板只管调。
  Future<void> _openMaterialSheet() {
    final l10n = AppLocalizations.of(context)!;
    // chrome 常显口径同 [_openWallpaperSheet]。
    // ⚠️ **最多半屏**（用户口径 2026-09-20）：这块面板改之前会长到 76% 屏高，
    // 把上面那张预览小屏盖掉 —— 而它存在的意义就是「改一处、看预览」。超出
    // 上限的内容由它自己的 SingleChildScrollView 内部滚动，不再靠长高来全显示。
    final contentMaxHeight = _materialSheetContentMaxHeight(context);
    return showHomeHyperosSheet<void>(
        context: context,
        builder: (sheetContext) => HyperosSheetFrame(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          maxHeight: contentMaxHeight,
          child: SingleChildScrollView(
            // 订阅草稿版本号：面板里任何一处改动（分段 / 胶囊 / 滑杆 / 开关 /
            // 恢复默认）都立刻反映到面板自己身上。**不要退回「每个控件各喊一声
            // 重画」的写法** —— 那样只要有一条路径漏喊，就是「拖了滑杆数字不动
            // 但设置已经改了」的半失效状态（2026-09-20 修的正是这个）。
            child: ValueListenableBuilder<int>(
              valueListenable: _draftRevision,
              builder: (sheetContext, _, _) {
                // 模型里 liquidGlassTuning 可空（存量数据兼容）：面板统一用
                // 兜底后的局部量，滑杆读写都不会踩空。
                final liquidTuning =
                    _draft.liquidGlassTuning ?? LiquidGlassTuning.defaults;
                return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.appearanceEditorMaterialAction,
                    style: HyperosTypography.sheetTitle(sheetContext),
                  ),
                  const SizedBox(height: 16),
                  // ── 顶部：观感最明显的两个开关。**内联分段控件、不开二级
                  // 弹层**：面板本身是根覆盖层自插条目（MiuixWindowBottomSheet），
                  // 任何嵌套弹层都会被它压在背面（2026-09-19 真机实锤）──
                  HyperosSectionLabel(text: l10n.frostedGlassModeLabel),
                  const SizedBox(height: 8),
                  // 整体材质：实体 ↔ 液态。两材质口径下中间档不再提供；
                  // 存量档显示就近归桶，落盘只在点选时发生。
                  _MaterialSegmented<GlassModeChoice>(
                    items: {
                      l10n.frostedGlassModeSolid: GlassModeChoice.solid,
                      l10n.frostedGlassModeLiquid: GlassModeChoice.liquidGlass,
                    },
                    value: switch (glassModeChoiceOf(_draft)) {
                      GlassModeChoice.liquidGlass ||
                      GlassModeChoice.softGlass => GlassModeChoice.liquidGlass,
                      _ => GlassModeChoice.solid,
                    },
                    onChanged: (value) {
                      _updateDraft(applyGlassModeChoice(_draft, value));
                    },
                  ),
                  const SizedBox(height: 16),
                  HyperosSectionLabel(text: l10n.homeBandGlassMaterialLabel),
                  const SizedBox(height: 8),
                  // 首页顶栏玻璃：卡片顶部即反馈区。2026-09-20 起这个字段的口径
                  // 就是下面这两个选项本身（存量渐进/高斯/柔光在读取时已归到
                  // 液态，见 `TimetableSettings.sanitizeHomeBandGlassMaterial`），
                  // 所以这里**直接显示存下来的值** —— 不再需要"就近归桶"，
                  // 也就不会再出现「界面显示液态、实际渲染渐进磨砂」那种错位。
                  _MaterialSegmented<String>(
                    items: {
                      l10n.materialStateSolid: 'solid',
                      l10n.frostedGlassModeLiquid: 'liquid',
                    },
                    value: _draft.homeBandGlassMaterial,
                    onChanged: (value) {
                      _updateDraft(applyHomeBandGlassMaterial(_draft, value));
                    },
                  ),
                  // ── 靠后：观感细项（仅液态档可调）──
                  if (_draft.frostedGlassMode ==
                      FrostedGlassMode.liquidGlass) ...[
                    const SizedBox(height: 20),
                    HyperosSectionLabel(text: l10n.advancedMaterialTitle),
                    const SizedBox(height: 8),
                    // 液态预设：快捷档位胶囊（内联，不开二级弹层）；自定义
                    // 时展开 8 项调参滑杆（从「高级材质」页直接搬入）。
                    _MaterialChoiceChips<LiquidGlassPreset>(
                      items: {
                        for (final preset in LiquidGlassPreset.values)
                          liquidGlassPresetLabel(l10n, preset): preset,
                      },
                      value: _draft.liquidGlassPreset,
                      onChanged: (preset) {
                        if (preset == LiquidGlassPreset.custom) {
                          _updateDraft(
                            _draft.copyWith(
                              liquidGlassPreset: LiquidGlassPreset.custom,
                            ),
                          );
                          return;
                        }
                        _updateDraft(
                          _draft.copyWith(
                            liquidGlassPreset: preset,
                            liquidGlassTuning: preset.recommendedTuning,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    HyperosListGroup(
                      children: [
                        if (_draft.liquidGlassPreset ==
                            LiquidGlassPreset.custom) ...[
                          // 滑杆一律关掉「点标题弹数字输入框」：那会开出二级弹层，
                          // 而本面板是根覆盖层自插条目，嵌套弹层会被压在背面
                          // （2026-09-19 真机实锤，见 [_MaterialSegmented] 的说明）。
                          // 面板里的可调项必须全是内联控件。
                          HyperosSliderTile(
                            tapToEdit: false,
                            title: l10n.liquidGlassRefractionLabel,
                            value: liquidTuning.refraction,
                            max: LiquidGlassTuning.maxRefraction,
                            divisions: 40,
                            valueLabel: _tuningNum(
                              liquidTuning.refraction,
                              1,
                            ),
                            onChanged: (value) => _updateLiquidTuning(
                              (t) => t.copyWith(refraction: value),
                            ),
                          ),
                          HyperosSliderTile(
                            tapToEdit: false,
                            title: l10n.liquidGlassRefractionBandLabel,
                            value: liquidTuning.refractionBand,
                            min: LiquidGlassTuning.minRefractionBand,
                            max: LiquidGlassTuning.maxRefractionBand,
                            divisions: 46,
                            valueLabel: _tuningNum(
                              liquidTuning.refractionBand,
                              1,
                            ),
                            onChanged: (value) => _updateLiquidTuning(
                              (t) => t.copyWith(refractionBand: value),
                            ),
                          ),
                          HyperosSliderTile(
                            tapToEdit: false,
                            title: l10n.liquidGlassRefractionEdgePowLabel,
                            value: liquidTuning.refractionEdgePow,
                            min: LiquidGlassTuning.minRefractionEdgePow,
                            max: LiquidGlassTuning.maxRefractionEdgePow,
                            divisions: 20,
                            valueLabel: _tuningNum(
                              liquidTuning.refractionEdgePow,
                              2,
                            ),
                            onChanged: (value) => _updateLiquidTuning(
                              (t) => t.copyWith(refractionEdgePow: value),
                            ),
                          ),
                          HyperosSliderTile(
                            tapToEdit: false,
                            title: l10n.liquidGlassDispersionLabel,
                            value: liquidTuning.dispersion,
                            divisions: 20,
                            valueLabel: _tuningPct(
                              liquidTuning.dispersion,
                            ),
                            onChanged: (value) => _updateLiquidTuning(
                              (t) => t.copyWith(dispersion: value),
                            ),
                          ),
                          HyperosSliderTile(
                            tapToEdit: false,
                            title: l10n.liquidGlassRimStrengthLabel,
                            value: liquidTuning.rimStrength,
                            divisions: 20,
                            valueLabel: _tuningPct(
                              liquidTuning.rimStrength,
                            ),
                            onChanged: (value) => _updateLiquidTuning(
                              (t) => t.copyWith(rimStrength: value),
                            ),
                          ),
                          HyperosSliderTile(
                            tapToEdit: false,
                            title: l10n.liquidGlassRimWidthLabel,
                            value: liquidTuning.rimWidth,
                            max: LiquidGlassTuning.maxRimWidth,
                            // 步长 0.1（3 / 30）：细线口径的取值都在 0.6~1.1 之间，
                            // 步长 0.5 会连默认值 0.8 都落不到格点上。
                            divisions: 30,
                            valueLabel: _tuningNum(
                              liquidTuning.rimWidth,
                              1,
                            ),
                            onChanged: (value) => _updateLiquidTuning(
                              (t) => t.copyWith(rimWidth: value),
                            ),
                          ),
                          HyperosSliderTile(
                            tapToEdit: false,
                            title: l10n.liquidGlassBlurSigmaLabel,
                            value: liquidTuning.blurSigma,
                            max: LiquidGlassTuning.maxBlurSigma,
                            divisions: 40,
                            valueLabel: _tuningNum(
                              liquidTuning.blurSigma,
                              0,
                            ),
                            onChanged: (value) => _updateLiquidTuning(
                              (t) => t.copyWith(blurSigma: value),
                            ),
                          ),
                          HyperosSliderTile(
                            tapToEdit: false,
                            title: l10n.liquidGlassTintLabel,
                            value: liquidTuning.tintAlpha,
                            divisions: 20,
                            valueLabel: _tuningPct(
                              liquidTuning.tintAlpha,
                            ),
                            onChanged: (value) => _updateLiquidTuning(
                              (t) => t.copyWith(tintAlpha: value),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            child: HyperosButton(
                              label: l10n.liquidGlassResetAction,
                              variant: HyperosButtonVariant.secondary,
                              expand: true,
                              onPressed: () {
                                _updateDraft(
                                  _draft.copyWith(
                                    liquidGlassPreset:
                                        LiquidGlassPreset.standard,
                                    liquidGlassTuning:
                                        LiquidGlassTuning.defaults,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    HyperosListGroup(
                      children: [
                        // 作用范围 → 玻璃坞：液态档下坞是否跟随液态（弹窗家族
                        // 已锁标准档，无开关可调，不再显示）。
                        HyperosSwitchTile(
                          title: l10n.liquidGlassScopeDockTitle,
                          subtitle: l10n.liquidGlassScopeDockSubtitle,
                          value: _draft.liquidGlassDockEnabled,
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(liquidGlassDockEnabled: value),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  // 子页顶栏（设置等页）：卡片里看不见，归入靠后分区。
                  HyperosSectionLabel(text: l10n.subpageHeaderBlurStyleLabel),
                  const SizedBox(height: 8),
                  _MaterialSegmented<HeaderBlurStyle>(
                    items: {
                      l10n.headerBlurStyleInspire: HeaderBlurStyle.inspire,
                      l10n.headerBlurStyleGaussian: HeaderBlurStyle.gaussian,
                    },
                    value: _draft.subpageHeaderBlurStyle,
                    onChanged: (value) {
                      _updateDraft(applySubpageChromeBlurStyle(_draft, value));
                    },
                  ),
                  const SizedBox(height: 20),
                  // 「各表面当前材质」地图：与渲染侧门控同口径的只读推导
                  // （2026-09-12）。**锁定的表面不显示**（2026-09-19 第七轮）：
                  // 弹窗家族四件（底部弹窗 / 选择面板 / 下拉小弹窗 / 选点按钮）
                  // 恒为液态玻璃标准档、与设置无关，显示也没用，已摘除。
                  Text(
                    l10n.surfaceMaterialSectionTitle,
                    style: HyperosTypography.sectionLabel(sheetContext),
                  ),
                  const SizedBox(height: 8),
                  HyperosListGroup(
                    children: [
                      _surfaceMaterialTile(
                        sheetContext,
                        l10n.liquidGlassScopeHomeChromeTitle,
                        homeBandSurfaceMaterial(_draft),
                      ),
                      _surfaceMaterialTile(
                        sheetContext,
                        l10n.surfaceSubpageHeader,
                        subpageHeaderSurfaceMaterial(_draft),
                      ),
                      _surfaceMaterialTile(
                        sheetContext,
                        l10n.liquidGlassScopeDockTitle,
                        dockSurfaceMaterial(_draft),
                      ),
                      _surfaceMaterialTile(
                        sheetContext,
                        l10n.surfaceCourseCard,
                        courseCardSurfaceMaterial(_draft),
                      ),
                    ],
                  ),
                ],
                );
              },
            ),
          ),
        ),
      );
  }

  /// 「各表面当前材质」地图的只读行：左表面名（主题墨色）、右材质值（次级
  /// 墨色）。不用 [HyperosListTile]——它的 details 只在可点行渲染，纯展示
  /// 行会把标题打到 45% 透明度且不画值（2026-09-12 真机灰色卡回归）。
  /// [rowContext] 传弹层的（样式读弹层主题）。
  Widget _surfaceMaterialTile(
    BuildContext rowContext,
    String title,
    SurfaceMaterial material,
  ) {
    final l10n = AppLocalizations.of(rowContext)!;
    return hyperosListRowShell(
      padding: hyperosRowPadding(rowContext),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: HyperosTypography.listTitle(rowContext),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: HyperosTokens.rowContentGap),
          Text(
            _surfaceMaterialLabel(l10n, material),
            style: HyperosTypography.listDetail(rowContext).copyWith(
              color: HyperosColors.secondaryText(rowContext),
            ),
          ),
        ],
      ),
    );
  }

  /// 液态玻璃调参写回：滑杆拖动 debounce 落盘，渲染源重绘 → 重烤 → 卡片
  /// 实时跟随（与「高级材质」页同一套模型字段；模型字段可空，写回用兜底值）。
  void _updateLiquidTuning(
    LiquidGlassTuning Function(LiquidGlassTuning tuning) update,
  ) {
    _updateDraft(
      _draft.copyWith(
        liquidGlassTuning: update(
          _draft.liquidGlassTuning ?? LiquidGlassTuning.defaults,
        ),
      ),
      debounce: true,
    );
  }

  String _tuningNum(double value, int digits) => value.toStringAsFixed(digits);
  String _tuningPct(double value) => '${(value * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    // 虚拟屏：真首页按**整屏尺寸**排版（它读的是环境 MediaQuery，与卡片尺寸
    // 无关），卡片把它整体缩进去 —— 「原样缩小」而不是「另排一套小屏布局」。
    final virtualScreen = media.size;
    final topInset = media.padding.top;
    final bottomInset = media.padding.bottom;

    return PopScope(
      // 系统返回 = 取消（与左上角那颗胶囊同义）。
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _cancel();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // 沉浸式暗底：状态栏图标走浅色。
        value: SystemUiOverlayStyle.light,
        child: FrostedAppearanceScope(
          // 预览必须读**本页草稿**的外观，否则弹窗里刚改的材质不会反映到卡片上
          // （FrostedAppearanceScope.of 会静默回落到默认值）。
          appearance: _draft.frostedAppearance,
          // 本页的采样源：卡片里那份真首页会自带一层内嵌宿主，套在这里之后它不会去
          // 顶掉全局注册表（见 [_pageGlass]），而本页打开的弹窗按注册表取源时拿到的
          // 是这一层 = 整屏画面。
          child: HyperosGlassBackdropHost(
            controller: _pageGlass,
            // 沉浸暗底按出场进度淡入（见 [_zoomProgress]）：转场期间它是透明的
            // ——让首页那半边缩进来的快照露出来；缩到位之后它与首页那半边的
            // `backdropColor` 同值，接管这一下看不出换人。
            child: _ZoomRevealBackground(
              progress: _zoomProgress,
              color: _scrimColor,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 上下给 chrome 留出的净空：顶部是「胶囊那一行 + 日/周分段」，
                  // 底部是「一排圆钮 + 名字」。
                  final topReserve = topInset + 16 + 40 + 12 + 36 + 18;
                  final bottomReserve = bottomInset + 34 + 56 + 8 + 18;
                  final availableHeight =
                      (constraints.maxHeight - topReserve - bottomReserve)
                          .clamp(120.0, double.infinity);
                  final availableWidth =
                      constraints.maxWidth * _cardMaxWidthFactor;
                  // 保持整屏宽高比，完整放下（不裁切）。
                  final scale = math.min(
                    availableWidth / virtualScreen.width,
                    availableHeight / virtualScreen.height,
                  );
                  final cardWidth = virtualScreen.width * scale;
                  final cardHeight = virtualScreen.height * scale;
                  // 圆角跟着缩放走（参考实现是 screenRadiusDp * cardScale）。
                  final cardRadius = math.min(
                    HyperosMotionPlatform.displayCornerRadiusDp * scale,
                    cardHeight / 2,
                  );
                  // 卡片居中于「上下 chrome 之间」这条带子，不做任何手工偏移：
                  // 之前那版按上下净空差加了个「视觉重心」修正，结果卡片被推得压到
                  // 底部按钮的净空里（真机量化出来偏 2px），反而更容易被读成没对齐。
                  // 卡片自带浮影，几何居中看起来就是居中。
                  final cardCenterY = topReserve + availableHeight / 2;
                  final double cardLeft =
                      (constraints.maxWidth - cardWidth) / 2;
                  final double cardTop = cardCenterY - cardHeight / 2;

                  // 上报落点：首页那半边照这个矩形把整页缩进来（见
                  // [HyperosZoomLanding]）。本页不位移，所以页面局部坐标就是
                  // 屏幕坐标。**这里是唯一真源**——两端各算一份公式迟早漂移，
                  // 而落地时两者必须逐像素重合。
                  final landing = HyperosZoomLanding(
                    rect: Rect.fromLTWH(
                      cardLeft,
                      cardTop,
                      cardWidth,
                      cardHeight,
                    ),
                    radius: cardRadius,
                  );
                  final current = hyperosZoomLanding.value;
                  if (current?.rect != landing.rect ||
                      current?.radius != landing.radius) {
                    // ⚠️ 是在 build 里写全局 notifier：目前没有任何监听者会在
                    // 通知里 markNeedsBuild（首页那半边是每帧直接读 `.value`），
                    // 所以不会踩"build 期间 setState"。将来若给它加监听，必须
                    // 改成帧末写。
                    hyperosZoomLanding.value = landing;
                  }

                  return Stack(
                    children: [
                      // 渲染源：真首页整屏 1:1，被下一层不透明底衬盖住，
                      // 只为烤图而活（见 _buildPreviewSource）。
                      // 整棵渲染源跟烤图同一个门进：首页子树（壁纸层 / 玻璃
                      // 捕获 / 坞层）是本页最贵的构建，挂在进场转场帧上会把
                      // 头几帧拖出可见卡顿（用户 2026-09-19 反馈「进来的缩放
                      // 动画不够连贯」的主因）。落定后才挂载，烤图晚一帧无
                      // 观感差 —— 卡片本来就是落定后才淡入正图。
                      Positioned.fill(
                        child: _routeSettled
                            ? PreviewBakeBoundary(
                                bakes: _previewBake,
                                // ⚠️ 必须是 dpr 本身：离屏回放按这个密度重新执行整层，
                                // 玻璃着色器的几何 uniform 按 dpr 折算，两者必须一致
                                // （乘显示缩放会让玻璃整体位移/缩放出画面，真机实锤）。
                                pixelRatio: MediaQuery.devicePixelRatioOf(context),
                                enabled: _routeSettled,
                                child: SizedBox(
                                  width: virtualScreen.width,
                                  height: virtualScreen.height,
                                  child: _buildPreviewSource(),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      // 不透明底衬：渲染源只进快照不进画面，卡片显示烤出来的图。
                      // 与暗底同一个出场进度 —— 它不透明时渲染源刚好才挂载
                      // （两者都由路由落定驱动），所以半透明期间下面没有活画面
                      // 会透出来。
                      Positioned.fill(
                        child: ValueListenableBuilder<double>(
                          valueListenable: _zoomProgress,
                          builder: (context, progress, _) => ColoredBox(
                            color: _scrimColor.withValues(
                              alpha: HyperosZoomRoute.growT(progress),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: cardLeft,
                        top: cardTop,
                        width: cardWidth,
                        height: cardHeight,
                        child: ValueListenableBuilder<double>(
                          valueListenable: _zoomProgress,
                          child: _buildPreviewCard(radius: cardRadius),
                          // ⚠️ 卡片**要等首页落到它身上那一刻**才画出来。
                          // 用户的复现（2026-09-20）：「缩放过程中，中间那一块小屏
                          // 持续存在」—— 卡片的图源就是首页那张快照，所以它从第一帧
                          // 起就在中间画着，于是屏幕上同时有一张静止的小屏和一张正在
                          // 缩进去的首页，变成"两个首页"。
                          //
                          // 用**阶跃**而不是淡入：切换的那一帧，卡片的图与首页那半边
                          // 的快照是同一张、位置也已经逐像素重合（`shrinkT` 在
                          // [HyperosZoomRoute.swapPoint] 就走到 1），所以切过来看不
                          // 出任何变化；淡入反而会让暗底在图上叠出一段"暗一下"。
                          builder: (context, progress, child) => Opacity(
                            opacity: HyperosZoomRoute.growT(progress) > 0 ? 1 : 0,
                            child: child,
                          ),
                        ),
                      ),
                      _buildTopChrome(context, l10n, topInset),
                      _buildBottomChrome(context, l10n, bottomInset),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 渲染源：真首页**本体** + 预览作用域 + 吞手势。
  ///
  /// 按**整屏逻辑尺寸 1:1** 渲染（外层 SizedBox 给的是整屏尺寸），不做任何
  /// 缩放 —— 玻璃的采样链、底栏 / 玻璃球这类按屏幕摆位的浮动层，在这个尺度上
  /// 与真实首页逐字一致，烤出来的图才等于首页自己画出来的画面。
  ///
  /// 点按一律吞掉：这是「看外观」的渲染源，不是第二个可操作首页（误触会加课、
  /// 翻周、改真实浏览位置）。预览不查更新、不跑秒级刷新：那是首页自己的事。
  Widget _buildPreviewSource() {
    return TimetableHomePreviewScope(
      dayView: _previewDayView,
      dayOfWeek: _previewDayOfWeekNotifier,
      child: const IgnorePointer(
        child: TimetableScreen(
          enableUpdateCheck: false,
          enableProgressTimer: false,
        ),
      ),
    );
  }

  /// 中间那张卡：显示渲染源烤出来的**整页快照图** + 屏幕圆角 + 描边浮影。
  ///
  /// 烤图按**原生密度 dpr** 出（与玻璃着色器的坐标折算一致，见
  /// [PreviewBakeBoundary] 类注释的警告），这里 `BoxFit.contain` GPU 等比缩进
  /// 卡片 —— 卡片观感与首页渲染结果一致。烤图要等进场转场落定
  /// （[_routeSettled]），第一张图到位时从暗底**淡入**（转场一结束就换正图，
  /// 避免转场帧的歪画面闪现）。
  Widget _buildPreviewCard({required double radius}) {
    return DecoratedBox(
      // 布局回归钉按这个 key 量卡片的几何：**不要改用 `find.byType(
      // TimetableScreen)`** —— 烤图方案（见文件头「方案 A」）之后卡片里显示的是
      // 快照图，而 TimetableScreen 只剩整屏 1:1 的渲染源、被 Positioned.fill
      // 钉在屏幕顶边，量它等于量渲染源（2026-09-20 修）。
      key: const ValueKey('appearance-editor-preview-card'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 32, spreadRadius: 2),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedBuilder(
          // 图源有两个：本页自己烤的图（[PreviewBakeBoundary]，落定后才开始）
          // 与首页那半边的快照 [hyperosZoomHomeSnapshot]。
          animation: _previewImageSources,
          builder: (context, _) {
            final image = _previewBake.value ?? hyperosZoomHomeSnapshot.value;
            return AnimatedOpacity(
              // 两个图源至少有一个就显示（首张烤图到位前用首页快照顶替）；
              // 此后重烤换图不再有淡入动画。
              opacity: image == null ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: image == null
                  ? const SizedBox.expand()
                  : RawImage(image: image, fit: BoxFit.contain),
            );
          },
        ),
      ),
    );
  }

  /// 顶部：居中标题 + 日 / 周分段 + 左上取消 / 右上完成。
  Widget _buildTopChrome(
    BuildContext context,
    AppLocalizations l10n,
    double topInset,
  ) {
    // chrome 在**缩放转场结束后**才出场（用户 2026-09-20 口径：把主页缩进预览
    // 小屏、页面上的按钮最后才显示；早先是"恒常显示"，那会让按钮跟着转场一起
    // 缩放）。弹层打开期间仍是"位置与可见性不变"（2026-09-19 口径），只有转场
    // 那一段是透明的。
    // 用透明度而不是从树上移除：布局必须保持（几何回归用例按位置量它们），
    // 而且消失期间要顺手挡掉点击（见 [_ZoomChromeReveal]）。
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: _ZoomChromeReveal(
        progress: _zoomProgress,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _capsuleButton(
                  label: l10n.cancelAction,
                  onTap: _cancel,
                  emphasized: false,
                ),
                Expanded(
                  child: Text(
                    l10n.appearanceEditorTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _capsuleButton(
                  label: l10n.appearanceEditorDoneAction,
                  onTap: _finish,
                  emphasized: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 日 / 周切换：用户要求「按钮放顶部」，放在标题下面一行。
            _dayWeekSegmented(l10n),
          ],
          ),
        ),
      ),
    );
  }

  /// 顶部胶囊按钮：两枚**形状、尺寸、配色完全一致**（84×40、同一底色与描边），
  /// 只有「完成」字重更重一点。
  ///
  /// 之前给「完成」用纯白实心、「取消」用半透明深色，视觉重量差一截，真机上看就是
  /// 「右边那颗跟左边不等大、像是错位了」—— 同形同色后不会再有这个错觉。
  Widget _capsuleButton({
    required String label,
    required VoidCallback onTap,
    required bool emphasized,
  }) {
    return SizedBox(
      width: 84,
      height: 40,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 日 / 周分段：暗底上的一枚玻璃胶囊，选中段是白底深字。
  Widget _dayWeekSegmented(AppLocalizations l10n) {
    Widget segment(String label, bool selected, VoidCallback onTap) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.92)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF1A1A1A) : Colors.white,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(l10n.glassDockTabDay, _dayPreview, () {
            setState(() => _dayPreview = true);
            _previewDayView.value = true;
          }),
          segment(l10n.glassDockTabWeek, !_dayPreview, () {
            setState(() => _dayPreview = false);
            _previewDayView.value = false;
          }),
        ],
      ),
    );
  }

  /// 底部：一排圆形玻璃入口（调整壁纸 ｜ 材质），与参考实现同款排布。
  Widget _buildBottomChrome(
    BuildContext context,
    AppLocalizations l10n,
    double bottomInset,
  ) {
    // 与 [_buildTopChrome] 同一条出场口径：转场结束后才出现。
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: _ZoomChromeReveal(
        progress: _zoomProgress,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset + 26),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleAction(
                icon: Icons.image_outlined,
                label: l10n.appearanceEditorWallpaperAction,
                onTap: _openWallpaperSheet,
              ),
              // 只留等距留白：参考实现那条竖杠在只有两个入口时是多余的隔断，
              // 真机上读起来就是「这一排散着」（用户反馈「底栏按钮乱七八糟」）。
              const SizedBox(width: 40),
              _circleAction(
                icon: Icons.auto_awesome_outlined,
                label: l10n.appearanceEditorMaterialAction,
                onTap: _openMaterialSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      // 圆钮与它下面那行名字**同属一个点击区**：只让圆钮可点的话，用户按到
      // 名字上会毫无反应（参考实现那行没有名字，本仓加了名字就得一起接住）。
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Material(
              color: Colors.white.withValues(alpha: 0.14),
              shape: CircleBorder(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Icon(icon, size: 26, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// 材质面板的两档内联分段选择：HyperOS 分段控制器的观感 —— 浅轨道、
/// 选中段浮卡 + 主墨、未选中段次级墨。
///
/// **必须是内联控件**：面板本身是根覆盖层自插条目（MiuixWindowBottomSheet），
/// 任何二级弹层（路由、锚定气泡、覆盖层条目）都会被它压在背面
/// （2026-09-19 真机实锤）—— 所以面板里的可调项一律内联，不开弹层。
class _MaterialSegmented<T> extends StatelessWidget {
  const _MaterialSegmented({
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final Map<String, T> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: HyperosColors.rowHighlight(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final entry in items.entries)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(entry.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: entry.value == value
                        ? HyperosColors.card(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HyperosTypography.listTitle(context).copyWith(
                        fontSize: 14,
                        color: entry.value == value
                            ? HyperosColors.primaryText(context)
                            : HyperosColors.secondaryText(context),
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
}

/// 材质面板的多选项内联胶囊（液态预设等）：选中 = 主题蓝描边 + 主墨，
/// 未选中 = 次级墨。同样内联、不开二级弹层（同 [_MaterialSegmented]）。
class _MaterialChoiceChips<T> extends StatelessWidget {
  const _MaterialChoiceChips({
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final Map<String, T> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in items.entries)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(entry.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: HyperosColors.card(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  width: entry.value == value ? 1.4 : 1,
                  color: entry.value == value
                      ? Theme.of(context).colorScheme.primary
                      : HyperosColors.rowHighlight(context),
                ),
              ),
              child: Text(
                entry.key,
                style: HyperosTypography.listTitle(context).copyWith(
                  fontSize: 14,
                  color: entry.value == value
                      ? HyperosColors.primaryText(context)
                      : HyperosColors.secondaryText(context),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 按缩放转场进度淡入的**背景**层（[HyperosZoomRoute.growT]）。
///
/// 用 `child:` 透传而不是 `builder` 里重建：每帧只有最外层那个 [ColoredBox]
/// 重建，内页子树（渲染源 / 卡片 / chrome）不跟着走 —— 转场期间它们是本页最贵的部分。
class _ZoomRevealBackground extends StatelessWidget {
  const _ZoomRevealBackground({
    required this.progress,
    required this.color,
    required this.child,
  });

  final ValueListenable<double> progress;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      child: child,
      builder: (context, p, child) => ColoredBox(
        color: color.withValues(alpha: HyperosZoomRoute.growT(p)),
        child: child,
      ),
    );
  }
}

/// 按缩放转场进度出场的 **chrome**（顶部胶囊 / 底部按钮，[HyperosZoomRoute.chromeT]）。
///
/// 三条纪律：
/// * **保留在树上**（只用透明度），布局必须原样 —— 几何回归用例按位置量它们，
///   而且删掉再挂回来会连带重建设备状态；
/// * **出场中（0 < t < 1）不挡点击**：chrome 在转场末段就淡入可见了，而它的
///   位置全程就是终态位置，此刻点它和落定后点它完全等价 —— 挡着只会变成
///   「看得见、点不动」（用户 2026-09-20 反馈：转场里点日 / 周没反应，转场一
///   结束预览又自己跳回周视图，读起来就是「切不过去」）；
/// * **只有完全没出场（t == 0）才挡**：`Opacity(0)` 的子树照样参与命中测试，
///   不挡就会点到一张完全看不见的按钮。
class _ZoomChromeReveal extends StatelessWidget {
  const _ZoomChromeReveal({required this.progress, required this.child});

  final ValueListenable<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      child: child,
      builder: (context, p, child) {
        final t = HyperosZoomRoute.chromeT(p);
        return Opacity(
          opacity: t,
          child: IgnorePointer(ignoring: t <= 0, child: child),
        );
      },
    );
  }
}
