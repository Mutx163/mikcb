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
/// * 弹窗打开时上下 chrome **保持常显**（第六轮明确，取代最初那版「淡出让位」）；
/// * 进页时卡片不得闪跳（玻璃圈/壁纸先偏在一侧再跳正）—— 转场落定后才烤图。
///
/// 预览实现（**方案 A：烤图**，2026-09-19 定案；机制就是录一帧真实内容树、
/// 按比例显示那张位图）：
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
  const _AppearanceEditorScreen({this.initialMaterialPage});

  /// 深链接：非空时入场转场落定后自动打开材质面板并停在该页
  /// （0 = 通用，1 = 课程卡片）。课程卡片设置页的「卡片外观」跳转牌用。
  final int? initialMaterialPage;

  @override
  State<_AppearanceEditorScreen> createState() =>
      _AppearanceEditorScreenState();
}

class _AppearanceEditorScreenState extends State<_AppearanceEditorScreen>
    with _HomeBackdropFlow<_AppearanceEditorScreen> {
  /// 沉浸式底衬：不透明深底、只有卡片是亮的。**就是缩放转场那半边的
  /// `backdropColor`**（同一个常量，不是碰巧同色）：首页缩进卡片之后由这层暗底
  /// 接管整屏背景，两边只要不是同一个值，接管那一帧就会看到一下轻微提亮/压暗。
  static const _scrimColor = HyperosZoomRoute.backdropColor;

  /// 卡片自带的那圈浮影（终态色，见 [_buildPreviewCard]）。
  ///
  /// 出场时按 [HyperosZoomRoute.growT] 缩放不透明度：影子只有在暗底接管之后
  /// 才看得见，跟着暗底一起长出来才对；跟着卡片"一步到位"会在落点交接
  /// 那一帧凭空多出一圈暗晕。
  static const _cardShadowColor = Color(0x66000000);

  /// 卡片相对可用区的最大宽度比例（剩下的留白保证「在屏幕中间、不顶边」）。
  ///
  /// 2026-09-20：0.82 → 0.86，配合顶部收成一行、底部圆钮下移 —— 用户口径「把内部
  /// 预览区域放大，这样好看」。竖屏手机上**高度**通常才是限制项（卡片按整屏宽高比
  /// 缩放），这个系数只在宽 / 矮的窗口上兜底。
  static const _cardMaxWidthFactor = 0.86;

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
  int _sheetGeneration = 0;

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

  /// 「完成」退出时交给退场动画的自持句柄（见 [hyperosZoomExitSource]）。
  ///
  /// 是 [_previewBake] 当前那张的 `clone()`：烤图边界换新图会把原来的 dispose 掉，
  /// 而退场期间必须有一份句柄活着。本页 dispose（= 退场结束）时帧末释放。
  ui.Image? _exitSourceOwned;

  /// 本页路由是否已落定（进场转场结束）。
  ///
  /// 落定前**不烤图**：转场帧里玻璃着色器与壁纸对齐取的是带转场变换的屏幕
  /// 坐标，烤出来玻璃圈/壁纸整体偏在一侧（真机现象：右上角玻璃圈先在卡片
  /// 左边闪一下才跳回右边、底栏玻璃闪一下）。落定后翻 true，边界整层重画
  /// 一遍按落定坐标重录，第一张烤图就是正的。
  bool _routeSettled = false;

  /// [initialMaterialPage] 的待办：入场转场落定后打开材质面板并停在该页。
  ///
  /// 面板是根覆盖层条目，转场期间页面还带着位移，两者会叠着动 —— 所以
  /// 落定（[_onRouteAnimationStatus]）才开；开过即清，不重复开。
  int? _pendingMaterialPage;

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

  /// 渲染源「内容脏了」的显式信号：喂给 [PreviewBakeBoundary.repaintSignal]。
  ///
  /// 列的就是渲染源的**全部**输入 —— 这不是"多喊几声保险"，是几条输入各自异步：
  ///
  /// 1. 草稿（材质 / 壁纸 / 卡片）：[TimetableSettings.frostedAppearance] 那条路
  ///    是同步的（[FrostedAppearanceScope] 直接吃 `_draft`），走 [_draftRevision]；
  /// 2. **落盘那份设置**：预览源是一棵真首页，它读的是 provider 里**已落盘**的设置，
  ///    而落盘是异步的 —— 壁纸尤其慢：`updateTimetableSettings` 先落盘、再把新壁纸
  ///    **预解码**完，最后才 `notifyListeners`。所以"草稿变了"与"画面真的变了"
  ///    差着好几帧（见 [_onProviderSettingsChanged]）；
  /// 3. **预糊位图**：壁纸 / 卡片磨砂量换了之后，位图要重新解码 + 高斯 + 离屏渲染，
  ///    就绪那一刻没有任何 widget 会重建整个画面（玻璃只在自己那个重绘边界里换图）
  ///    —— 不订阅它，预览就永远停在旧壁纸上（见 [PreblurredWallpaperCache.changes]）。
  ///
  /// 另外两样（预览的日周、看哪一天）是纯同步的 notifier；最后一个进页后不再变，
  /// 但它是渲染源的输入，一并带上。
  ///
  /// **不能指望子树重绘自己传到烤图边界**——玻璃面与壁纸层各自带重绘边界，
  /// 内容变化只在它们内部重绘，烤图边界压根不被标脏（2026-09-22 真机实锤：
  /// 拖材质滑杆上百次、切日视图，烤图边界一次都没重绘，卡片上一直挂着进场
  /// 那张图）。所以这几处都要显式喊。
  late final Listenable _previewSourceDirty;

  /// 「落盘那份设置变了」的信号（第 2 条输入，见 [_previewSourceDirty]）。
  ///
  /// 用自增计数而不是 `ChangeNotifier`：`notifyListeners` 是 protected，从外面
  /// 喊不了（与 `_draftRevision` 同一套做法）。
  final ValueNotifier<int> _persistedSettingsDirty = ValueNotifier<int>(0);

  /// 上一次见到的**已落盘**设置对象；只用来判"这次通知是不是真的换了一份设置"。
  ///
  /// [TimetableSettings] 没有自定义 `==`，所以这里是**身份**比较：写设置的那条路
  /// 一定会换一份新对象，而周次 / 实时快照这类只改别的字段的通知不会 —— 恰好是
  /// 我们想区分的两件事。
  TimetableSettings? _lastPersistedSettings;

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
    _previewSourceDirty = Listenable.merge(<Listenable>[
      _draftRevision,
      _previewDayView,
      _previewDayOfWeekNotifier,
      _persistedSettingsDirty,
      PreblurredWallpaperCache.instance.changes,
    ]);
    _lastPersistedSettings = _timetableProvider.settings;
    _timetableProvider.addListener(_onProviderSettingsChanged);
    _pendingMaterialPage = widget.initialMaterialPage;
    if (_pendingMaterialPage != null) {
      // 首帧落定态在 didChangeDependencies 里已判过：无动画直接开；
      // 还在转场就等 _onRouteAnimationStatus 的 completed。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _routeSettled) {
          _openPendingMaterialSheet();
        }
      });
    }
  }

  /// 执行进页深链接：打开材质面板并停在指定页（只执行一次）。
  void _openPendingMaterialSheet() {
    final page = _pendingMaterialPage;
    if (page == null || !mounted) {
      return;
    }
    _pendingMaterialPage = null;
    _openMaterialSheet(initialPage: page);
  }

  /// 预览源读的是 **provider 里那份已落盘的设置**，所以"落盘完成"就是一次内容变化。
  ///
  /// 为什么不能只看草稿：`updateTimetableSettings` 里落盘、预解码壁纸、`notifyListeners`
  /// 三步是串起来的 —— 换壁纸时草稿早就变了，而画面要等预解码完才可能变（见
  /// [_previewSourceDirty] 第 2 条）。不订阅这里，预览就会停在旧壁纸上。
  ///
  /// 只在**换了一份设置对象**时喊：provider 还会为别的缘由通知（周次、实时课表
  /// 快照），每次都烤一张整屏图是白烧。
  void _onProviderSettingsChanged() {
    final settings = _timetableProvider.settings;
    if (_lastPersistedSettings == settings) return;
    _lastPersistedSettings = settings;
    _persistedSettingsDirty.value++;
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
      // ⚠️ **首帧的 `animation` 不能信**（非 zoom 路径）：进场首帧整条路由是
      // offstage，它的动画代理被换成恒为 1.0/completed 的占位动画（上游
      // `routes.dart` 的 `set offstage`，文档原话：「On the first frame of a
      // route's entrance transition, the route is built Offstage using an
      // animation progress of 1.0」）。
      //
      // 照它判「已落定」= 渲染源在**转场第一帧**就挂载并烤图，而那一刻页面还在
      // 转场位移里 —— 烤出来的是带转场坐标的歪画面（玻璃整块位移、底栏跑到别处），
      // 落定后重烤才跳回正常。用户 2026-09-22 读到的「从设置页入口进来，预览里的
      // 玻璃位置变一下才回正」就是它；从首页菜单进走的是 zoom 路径（那边读控制器、
      // 不受代理影响），所以两条入口表现不同。
      //
      // 判据：占位动画是那个全局常量本身（上游 `set offstage` 里直接赋的就是
      // `kAlwaysCompleteAnimation`）；真控制器、或代理到真控制器的那份都不是它。
      final offstagePlaceholder =
          animation is ProxyAnimation &&
          identical(animation.parent, kAlwaysCompleteAnimation);
      _routeSettled =
          animation == null ||
          (!offstagePlaceholder && animation.status == AnimationStatus.completed);
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
      _openPendingMaterialSheet();
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
    // 退场源要**先摘发布再释放**：退场倒放那一帧可能还画着它（同首页那半边的纪律）。
    _clearExitSource();
    _previewBake.value?.dispose();
    _previewBake.dispose();
    _draftRevision.dispose();
    _timetableProvider.removeListener(_onProviderSettingsChanged);
    _persistedSettingsDirty.dispose();
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
    final previousBackdropKey = homePageBackdropKey(_draft);
    setState(() {
      _draft = next;
    });
    // 自增即"渲染源脏了"（[_previewSourceDirty] 订阅它）→ 重烤预览图。
    _draftRevision.value++;
    if (homePageBackdropKey(next) != previousBackdropKey) {
      // 换壁纸：**立刻**把新壁纸的解码开起来，不等落盘那条链。
      //
      // 预览源读的是 provider 里**已落盘**的设置，而 `updateTimetableSettings` 的
      // 顺序是「写盘 → 预解码新壁纸 → notifyListeners」—— 中间那句是一张整尺寸
      // 照片的解码，几百毫秒起步。不提前解码，用户换完壁纸就要先愣半秒到一秒
      // 才可能看到画面变化（真机反馈「感觉上有一秒延迟」，2026-09-22）。
      //
      // 提前发起的是**同一份**解码（同路径、同 `ResizeImage` 宽度 ⇒ 同一个
      // ImageCache 键），provider 之后那次就是缓存命中、通知随之提前 ——
      // 画面内容一模一样，只是来得早。清掉壁纸（键变 null）时它自己直接返回。
      unawaited(precacheHomePageBackdropImage(next));
      // 再把**两张预糊位图**（首页玻璃带那份 + 卡片那份）与新壁纸的亮度带一起预热：
      // 它们按 `path + sigma` 建缓存，换壁纸就是两个全新条目；不预热的话，退出编辑页
      // 落定之后玻璃面会先素面几帧再变磨砂、墨色也可能闪一下（同一族的"落定后才补上"
      // 现象，见 [hyperosZoomExitSource] 那边的退场源问题）。启动预热器干的正是这组活
      // —— 同一个缓存、同一套 sigma 推导、同一条亮度采样，直接复用。
      unawaited(HomeStartupVisualPrimer.prime(next));
    }
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
    try {
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
        reportSettingsPersistRejected(this, message);
        setState(() {
          _draft = provider.settings;
        });
        _draftRevision.value++;
      }
    } catch (_) {
      // 落盘失败：provider 已回滚内存与课表镜像并 rethrow，不接就没人提示。
      reportSettingsPersistFailure(this, resetDraft: () {
        setState(() {
          _draft = provider.settings;
        });
        _draftRevision.value++;
      });
    }
  }

  /// 完成：保留改动，返回。
  ///
  /// 退出前先把"用户此刻看到的那张整屏图"交给退场动画（[_publishExitSource]）：
  /// 退场倒放默认放的是**进页时**的快照（旧壁纸 / 旧材质），用户会先看到旧画面、
  /// 落定才跳成新的（真机反馈 2026-09-22）。
  void _finish() {
    _publishExitSource();
    Navigator.pop(context);
  }

  /// 取消：把进页时的设置整份写回，再返回。
  ///
  /// 本页所有改动都是即时落盘的（弹窗里改一下，预览立刻变），所以「取消」不是
  /// 什么都不做，而是回滚 —— 否则按钮名与行为不符。回滚后仍走一次正常落盘。
  ///
  /// **不发布退场源**：回滚之后首页要回到的就是进页那张旧观感，退场沿用它正好。
  void _cancel() {
    if (_draft != _openedWith) {
      _updateDraft(_openedWith);
    }
    Navigator.pop(context);
  }

  /// 把当前烤图交给退场动画（见 [hyperosZoomExitSource]）。
  ///
  /// 两个前提，缺一条就退回进页快照（null）：
  /// * **已经烤出过一张**（没烤过时卡片显示的本来就是首页那张旧快照）；
  /// * **缩尺预览的视图与首页当前视图一致** —— 编辑页里切日 / 周只动预览、不动首页的
  ///   浏览状态（见类注释），两边视图不同时拿它去放大，落定处会跳一下。
  ///
  /// `clone()` 是刻意的：本页随后还要用那份烤图（卡片），而烤图边界换新图时会把旧的
  /// `dispose()`；退场期间必须有一份自持的句柄活着，退场结束（本页 dispose）才放。
  void _publishExitSource() {
    _clearExitSource();
    final image = _previewBake.value;
    final matchesHomeView =
        _dayPreview == (_draft.timetableHomeViewMode == TimetableHomeViewMode.day);
    if (image == null || !matchesHomeView) {
      return;
    }
    final owned = image.clone();
    _exitSourceOwned = owned;
    hyperosZoomExitSource.value = owned;
  }

  /// 摘掉退场源并释放自持那份（帧末释放：落定那一帧场景可能还画着它）。
  void _clearExitSource() {
    final owned = _exitSourceOwned;
    if (owned == null) {
      return;
    }
    _exitSourceOwned = null;
    if (identical(hyperosZoomExitSource.value, owned)) {
      hyperosZoomExitSource.value = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => owned.dispose());
  }

  Future<void> _openWallpaperSheet() {
    final l10n = AppLocalizations.of(context)!;
    final generation = ++_sheetGeneration;
    // 上下 chrome（取消 / 完成 / 日周切换 / 圆钮）在弹窗打开期间**保持常显**
    //（2026-09-19 用户口径，取代最初那版「淡出让位」）：barrier
    // 会把它们压暗、点按被弹层接走，但位置与可见性不变。
    final future = showHomeHyperosSheet<void>(
      context: context,
      // 收下收起口子：弹窗里那颗「选择图片」/「调整位置」要推整页（位置编辑页），
      // 必须先收起本弹层再推（理由见 [_sheetClose]）。
      closeRef: (close) {
        if (generation == _sheetGeneration) {
          _sheetClose = close;
        }
      },
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
    );
    return future.whenComplete(() {
      if (generation == _sheetGeneration) {
        _sheetClose = null;
      }
    });
  }

  @override
  MiuixBottomSheetClose? get backdropHostSheetClose => _sheetClose;

  /// 材质面板（「材质」弹窗正文）：**左右两页**（2026-09-22 第九轮改结构）——
  /// 顶上「标题 + 通用 / 课程卡片」同一行，下面一层可左右滑的页面。
  ///
  /// **默认材质三档：实体卡片 / 高斯模糊 / 液态玻璃**（2026-09-23 口径：整机
  /// 只有两种真实材质 —— 高斯模糊与液态玻璃，「实体卡片」是模糊总开关关）。
  /// 锁定件（弹窗家族等恒为液态玻璃标准档的表面）依旧不显示 —— 与设置无关，
  /// 只在末尾只读总览里按用户口径说明。
  ///
  /// * **第一页「通用」**（[_buildGeneralMaterialPage]）：默认材质（三档）、
  ///   首页顶栏玻璃、液态的预设与八根旋钮，末尾「各表面当前材质」只读总览；
  /// * **第二页「课程卡片」**（[_buildCourseCardMaterialPage]）：卡片外观三档 +
  ///   卡片**自己那套**八根旋钮（`TimetableSettings.courseCardGlassTuning`，
  ///   2026-09-21 起卡片有独立配置）+ 总闸关掉时的一行说明。
  ///
  /// **为什么分页**：面板最多半屏（[_materialSheetMaxHeightFactor]），内容高度上限
  /// 真机 393×852 只有约 332px，而一套八根旋钮就是 592px —— 两套旋钮放一页要滚四屏
  /// 多。分页把「一页滚四屏」拆成「每页各滚约两屏」，而且用户只在**自己点进去的那
  /// 一页**里滚。卡片那八根旋钮因此从「课程卡片设置页」搬了回来（那边当初单开一节的
  /// 唯一理由正是"面板塞不下"，见
  /// `.agents/notes/implemented/feature/2026-09-21-course-card-own-glass-tuning.md`）。
  ///
  /// 翻页**必须是面板内联的一层**：面板是根覆盖层自插条目，任何二级弹层 / 路由都会
  /// 被压在背面（见 [_MaterialSegmented]）—— 所以这里不是另开弹窗，而是同一层里的
  /// 横向 [PageView]（[_MaterialSheetBody]）。左右滑也不会和「从把手往下拖关闭」
  /// 打架：那个手势只认把手上的**竖向**拖动（见 `showHomeHyperosSheet`）。
  ///
  /// 行部件与设置列表同源；改动即时落盘：渲染源重绘 → 重烤 → 卡片实时跟随；
  /// 「恢复默认」仍归「课表页面」作用域，面板只管调。
  Future<void> _openMaterialSheet({
    int initialPage = _MaterialSheetBodyState._generalPage,
  }) {
    final l10n = AppLocalizations.of(context)!;
    // chrome 常显口径同 [_openWallpaperSheet]。
    // ⚠️ **最多半屏**（用户口径 2026-09-20）：这块面板改之前会长到 76% 屏高，
    // 把上面那张预览小屏盖掉 —— 而它存在的意义就是「改一处、看预览」。超出的
    // 内容由**每一页自己的内部滚动**承担，不再靠长高来全显示。
    final contentMaxHeight = _materialSheetContentMaxHeight(context);
    return showHomeHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheetFrame(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        maxHeight: contentMaxHeight,
        child: _MaterialSheetBody(
          editor: this,
          l10n: l10n,
          initialPage: initialPage,
        ),
      ),
    );
  }

  /// 「通用」页正文：整机总闸 + 卡片以外的表面。
  ///
  /// 页内顺序沿用「观感明显的在前」（2026-09-19 第七轮）：总闸 → 首页顶栏玻璃 →
  /// 液态预设与八根旋钮 → 只读总览。
  ///
  /// 重画靠订阅草稿版本号：面板里任何一处改动（分段 / 胶囊 / 滑杆 / 开关）都立刻
  /// 反映到面板自己身上。**不要退回「每个控件各喊一声重画」的写法** —— 那样只要
  /// 有一条路径漏喊，就是「拖了滑杆数字不动、但设置已经改了」的半失效状态
  /// （2026-09-20 修的正是这个）。
  Widget _buildGeneralMaterialPage(
    BuildContext sheetContext,
    AppLocalizations l10n,
  ) {
    // 模型里 liquidGlassTuning 可空（存量数据兼容）：面板统一用兜底后的局部量，
    // 滑杆读写都不会踩空。
    final liquidTuning = _draft.liquidGlassTuning ?? LiquidGlassTuning.defaults;
    // 顶部那一格是**默认材质**（三档：实体卡片 / 高斯模糊 / 液态玻璃）——
    // 与下面「高级材质」那一节的开关共用这一个值（单一来源）：上面写着液态
    // 玻璃，下面就一定给液态的设置。
    //
    // 2026-09-22 之前这里只画两格，且显示走"就近归桶"、给不给设置走原始字段，
    // 于是存量柔光档成了「显示液态玻璃、下面什么都没有」；更早的中间档（磨砂）
    // 则是被谎报成「实体卡片」选中。2026-09-23 名字统一后，三档与
    // [glassModeChoiceOf] 一一对应，**不再需要归桶**，两处判据天然同源。
    final displayedChoice = glassModeChoiceOf(_draft);
    return SingleChildScrollView(
      // ⚠️ 面板里第一个 `Scrollable` 是外面那层**横向翻页** —— 测试要按这个 key
      // 指名取本页的滚动视图，别再取 `Scrollable` 的第一个。
      key: const ValueKey('material-page-general'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 总闸：观感最明显的一档，两页都受它支配（见
          // [_buildCourseCardMaterialPage]）。**内联分段控件、不开二级弹层**：
          // 面板本身是根覆盖层自插条目（MiuixWindowBottomSheet），任何嵌套弹层
          // 都会被压在它背面（2026-09-19 真机实锤）──
          HyperosSectionLabel(text: l10n.frostedGlassModeLabel),
          const SizedBox(height: 8),
          // 默认材质三档：不模糊（实体）/ 模糊（高斯）/ 模糊 + 折射（液态）。
          // 这三档就是引导页「视觉效果」那三档（[GlassModeChoice] 是唯一写入口）。
          _MaterialSegmented<GlassModeChoice>(
            items: {
              l10n.frostedGlassModeSolid: GlassModeChoice.solid,
              l10n.frostedGlassModeGaussian: GlassModeChoice.gaussian,
              l10n.frostedGlassModeLiquid: GlassModeChoice.liquidGlass,
            },
            value: displayedChoice,
            onChanged: (value) {
              _updateDraft(applyGlassModeChoice(_draft, value));
            },
          ),
          // 只在实体档出现：这是唯一与直觉不符的档（顺带关掉全 App 模糊）。
          if (displayedChoice == GlassModeChoice.solid) ...[
            const SizedBox(height: 8),
            Text(
              l10n.frostedGlassModeSolidNotice,
              style: HyperosTypography.listDetail(sheetContext).copyWith(
                color: HyperosColors.secondaryText(sheetContext),
              ),
            ),
          ],
          const SizedBox(height: 16),
          HyperosSectionLabel(text: l10n.homeBandGlassMaterialLabel),
          const SizedBox(height: 8),
          // 首页顶栏玻璃：卡片顶部即反馈区。2026-09-23 起三档：「跟随默认」
          // （默认档高斯→磨砂带、液态→液态带、实体→实心带，渲染与只读推导都
          // 走 homeBandGlassMaterialEffective 的生效值）+「实体 / 液态」单独
          // 指定（存量渐进/高斯/柔光在读取时已归到液态，见
          // `TimetableSettings.sanitizeHomeBandGlassMaterial`）。出厂值仍是
          // 单独指定液态，观感与引入「跟随」之前一致。
          _MaterialSegmented<String>(
            items: {
              l10n.homeBandGlassMaterialFollow: 'follow',
              l10n.materialStateSolid: 'solid',
              l10n.frostedGlassModeLiquid: 'liquid',
            },
            value: _draft.homeBandGlassMaterial,
            onChanged: (value) {
              _updateDraft(applyHomeBandGlassMaterial(_draft, value));
            },
          ),
          // ── 靠后：观感细项（跟着上面**显示**的那一档走，见 [displayedChoice]）──
          if (displayedChoice == GlassModeChoice.liquidGlass) ...[
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
                if (_draft.liquidGlassPreset == LiquidGlassPreset.custom) ...[
                  // 浅色档的八根旋钮（与深色档共用同一份渲染）。
                  ..._glassSliderTiles(
                    l10n,
                    tuning: liquidTuning,
                    onUpdate: _updateLiquidTuning,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HyperosButton(
                          label: l10n.liquidGlassResetAction,
                          variant: HyperosButtonVariant.secondary,
                          expand: true,
                          onPressed: () {
                            _updateDraft(
                              _draft.copyWith(
                                liquidGlassPreset: LiquidGlassPreset.standard,
                                liquidGlassTuning: LiquidGlassTuning.defaults,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        // 一句范围说明（2026-09-25 审计采纳）：这颗按钮只动液态
                        // 调参，别让人以为会把整体材质也一起恢复了。
                        Text(
                          l10n.liquidGlassResetScopeNotice,
                          style: HyperosTypography.listDetail(sheetContext)
                              .copyWith(
                                color: HyperosColors.secondaryText(
                                  sheetContext,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // ── 浅/深成对（2026-09-21）。设计见
            // `.agents/notes/proposed/architecture/2026-09-21-liquid-glass-light-dark-pair.md`
            // 两个开关都在**恒常**区（不进 `custom` 门内）：配方作用在预设档的
            // 旋钮上照样成立，只有「调深色档」才需要自定义档。
            HyperosListGroup(
              children: [
                HyperosSwitchTile(
                  title: l10n.liquidGlassDarkBoostLabel,
                  subtitle: l10n.liquidGlassDarkBoostSubtitle,
                  value: _draft.darkGlassBoostEnabled,
                  onChanged: (value) {
                    _updateDraft(
                      _draft.copyWith(darkGlassBoostEnabled: value),
                    );
                  },
                ),
                HyperosSwitchTile(
                  // 开关语义是「独立」，而字段存的是「是否跟随」，所以取反。
                  title: l10n.liquidGlassDarkIndependentLabel,
                  subtitle: l10n.liquidGlassDarkIndependentSubtitle,
                  value: !_draft.linkLiquidGlassTuning,
                  onChanged: (independent) {
                    _updateDraft(
                      _draft.copyWith(
                        linkLiquidGlassTuning: !independent,
                        // 第一次打开、且从没设过深色档 ⇒ 以浅色档为起点。
                        // 配方照旧套在「选中的那一档」上，所以这一按
                        // **不会让画面跳**（跳了就是这里写错了）。
                        liquidGlassTuningDark: independent
                            ? (_draft.liquidGlassTuningDark ?? liquidTuning)
                            : _draft.liquidGlassTuningDark,
                      ),
                    );
                  },
                ),
              ],
            ),
            // 深色档的八根旋钮：与浅色档同构、共用同一个渲染函数
            // （[_glassSliderTiles]）。只在「自定义 + 深色独立」时出现 ——
            // 预设档下旋钮本就不可调，列出来只会误导。
            if (_draft.liquidGlassPreset == LiquidGlassPreset.custom &&
                !_draft.linkLiquidGlassTuning) ...[
              const SizedBox(height: 12),
              HyperosListGroup(
                children: _glassSliderTiles(
                  l10n,
                  tuning: _draft.liquidGlassTuningDark ?? liquidTuning,
                  onUpdate: _updateDarkTuning,
                ),
              ),
            ],
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
          // 子页顶栏 2026-09-23 起锁定渐进模糊，面板里没有任何一节。
          //
          // 「各表面当前材质」地图：与渲染侧门控同口径的只读推导
          // （2026-09-12）。**只列可调表面**（2026-09-25 口径）：锁死的
          // （弹窗家族、子页顶栏）一律不显示——固定的东西不出现，
          // 用户就不会以为它可调。
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
      ),
    );
  }

  /// 「课程卡片」页正文：只管卡片这一档材质。
  ///
  /// 卡片是小格，弹窗 / 顶栏 / 玻璃坞是别的东西 —— 所以从 2026-09-20 起它是**与
  /// 全局材质分开**的一档：这一档写 `TimetableSettings.courseCardSurfaceStyle`，
  /// 渲染门控与墨色规则一律走 `effectiveCourseCardSurfaceStyle`（没有壁纸、或模糊
  /// 总开关关掉时回落实体卡面）。2026-09-22 又把卡片**自己那套八根旋钮**从「课程
  /// 卡片设置页」搬到这里（写 `TimetableSettings.courseCardGlassTuning`）：那边当初
  /// 单开一节的唯一理由是「材质面板塞不下八行滑杆」，分页之后这条理由消失。
  ///
  /// ⚠️ **整机总闸会盖过这一页**：`effectiveCourseCardSurfaceStyle` 在模糊总开关
  /// 关掉（= 整体材质「实体卡片」）时一律回落实体卡片 —— 这里选了液态也不生效。
  /// 总闸在第一页，用户站在这一页看不到它，所以这一页必须把那句话说出来（用户口径
  /// 2026-09-22：「第二页加一行提示」），否则就是「选了液态、画面不动」。
  Widget _buildCourseCardMaterialPage(
    BuildContext sheetContext,
    AppLocalizations l10n,
  ) {
    final cardTuning =
        _draft.courseCardGlassTuning ?? CourseGlassTuning.courseCard;
    // 只在这一档**确实被总闸压住**时提示：用户选的本来就是实体卡片时，没有什么
    // 「不生效」可言，多一行字只会是噪音。
    final maskedByMaster =
        !_draft.frostedBlurEnabled &&
        _draft.courseCardSurfaceStyle != CourseCardSurfaceStyle.solid;
    return SingleChildScrollView(
      key: const ValueKey('material-page-course-card'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 必须是内联胶囊（不用 HyperosSelectTile）：本面板是根覆盖层自插
          // 条目，二级弹层/路由都会被压在背面（见 [_MaterialSegmented]）。
          HyperosSectionLabel(text: l10n.courseCardSurfaceStyleLabel),
          const SizedBox(height: 8),
          _MaterialChoiceChips<CourseCardSurfaceStyle>(
            items: {
              for (final style in CourseCardSurfaceStyle.values)
                courseCardSurfaceStyleLabel(l10n, style): style,
            },
            value: _draft.courseCardSurfaceStyle,
            onChanged: (style) {
              _updateDraft(_draft.copyWith(courseCardSurfaceStyle: style));
            },
          ),
          if (maskedByMaster) ...[
            const SizedBox(height: 8),
            Text(
              l10n.courseCardMaterialMasterOffHint,
              style: HyperosTypography.listDetail(sheetContext).copyWith(
                color: HyperosColors.secondaryText(sheetContext),
              ),
            ),
          ],
          // 卡片自己那套八根旋钮：只在卡片档为液态时出现（实体 / 高斯档没有折射
          // 可调）。建议点位与档位数**沿用它在课程卡片设置页那一套** —— 出厂值
          // 必须落在格点上，否则第一次拖动就把染色 0.32 吸成 0.30 / 0.35。
          if (_draft.courseCardSurfaceStyle ==
              CourseCardSurfaceStyle.liquidGlass) ...[
            const SizedBox(height: 20),
            HyperosSectionLabel(text: l10n.advancedMaterialTitle),
            const SizedBox(height: 8),
            HyperosListGroup(
              children: _glassSliderTiles(
                l10n,
                tuning: cardTuning.toLiquidGlassTuning(),
                showKeyPoints: true,
                tintDivisions: 25,
                // 卡片的磨砂量只喂它那张预糊位图，出图侧夹到 kPreblurMaxSigma：
                // 滑杆上限取同一个常量，0 是有效的「清」档（出原图、不跑高斯）。
                blurSigmaMax: kPreblurMaxSigma,
                // 滑杆改的是「等价全局档」，写回卡片那套要过一趟抄写：两套类型
                // 各自的出厂档与染色语义不同（见 `CourseGlassTuning` 的注释），
                // 不能就地换类型。
                onUpdate: (update) => _updateCardTuning(
                  (base) => CourseGlassTuning.fromLiquidGlassTuning(
                    update(base.toLiquidGlassTuning()),
                  ),
                ),
              ),
            ),
          ],
        ],
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

  /// 深色档的滑杆落地口。取值回落链必须与面板里读的那条一致
  /// （`深色档 ?? 浅色档 ?? 默认`），否则拖杆会从另一档的初值开始跳。
  void _updateDarkTuning(
    LiquidGlassTuning Function(LiquidGlassTuning tuning) update,
  ) {
    _updateDraft(
      _draft.copyWith(
        liquidGlassTuningDark: update(
          _draft.liquidGlassTuningDark ??
              _draft.liquidGlassTuning ??
              LiquidGlassTuning.defaults,
        ),
      ),
      debounce: true,
    );
  }
  String _tuningNum(double value, int digits) => value.toStringAsFixed(digits);
  String _tuningPct(double value) => '${(value * 100).round()}%';

  /// 卡片那套液态参数的滑杆落地口。回落链 = `卡片档 ?? 卡片出厂档`
  /// （模型字段可空，与卡片设置页原实现同口径）。
  void _updateCardTuning(
    CourseGlassTuning Function(CourseGlassTuning tuning) update,
  ) {
    final base = _draft.courseCardGlassTuning ?? CourseGlassTuning.courseCard;
    _updateDraft(
      _draft.copyWith(courseCardGlassTuning: update(base)),
      debounce: true,
    );
  }

  /// 液态玻璃的八根滑杆。**浅色档 / 深色档 / 卡片档共用这一份** —— 三套各写一遍
  /// 迟早会漂，而「同一材质两种观感」正是这个仓库反复吃亏的那类病。
  ///
  /// 滑杆一律关掉「点标题弹数字输入框」：那会开出二级弹层，而本面板是根覆盖层
  /// 自插条目（MiuixWindowBottomSheet），嵌套弹层会被压在背面（2026-09-19 真机实锤）。
  ///
  /// [showKeyPoints] 打开时在四根关键旋钮上画「建议点位」（= 出厂值那一点；轨道上
  /// 画点、划过变亮、经过一次触感）—— 只有卡片档要它（2026-09-21 用户口径：在那几根
  /// 可见性最强的旋钮上给建议值）。
  ///
  /// [tintDivisions] 默认 20；卡片档必须是 25（步长 0.04），否则出厂染色 0.32
  /// 不落在格点上，第一次拖动就会被吸成 0.30 / 0.35。
  ///
  /// [blurSigmaMax] 是按档走的**上限**：全局 / 深色两档是 0~40（那些面走实时模糊，
  /// 量程就是它），卡片档是 0~24 —— 卡片的磨砂量只喂那张预糊位图，而出图侧把它夹在
  /// [kPreblurMaxSigma]（见 `resolveCourseCardPreblurSigma`）。不收的话卡片这根滑杆
  /// 两头都是死区：0~1 全等于 2、25~40 全等于 24。
  List<Widget> _glassSliderTiles(
    AppLocalizations l10n, {
    required LiquidGlassTuning tuning,
    required void Function(LiquidGlassTuning Function(LiquidGlassTuning)) onUpdate,
    bool showKeyPoints = false,
    int tintDivisions = 20,
    double blurSigmaMax = LiquidGlassTuning.maxBlurSigma,
  }) {
    // 存量值可能高于本档上限（旧版卡片那根能拖到 40）：拇指与数字都夹到上限。
    // 出图侧本来就按上限出，显示必须同口径 —— 否则就是「拖了数字不动」那一类半失效。
    final blurSigma = tuning.blurSigma
        .clamp(LiquidGlassTuning.minBlurSigma, blurSigmaMax)
        .toDouble();
    return [
      HyperosSliderTile(
        tapToEdit: false,
        title: l10n.liquidGlassRefractionLabel,
        value: tuning.refraction,
        max: LiquidGlassTuning.maxRefraction,
        divisions: 40,
        valueLabel: _tuningNum(tuning.refraction, 1),
        showKeyPoints: showKeyPoints,
        keyPoints: showKeyPoints
            ? const [CourseGlassTuning.defaultRefraction]
            : null,
        onChanged: (value) => onUpdate((t) => t.copyWith(refraction: value)),
      ),
      HyperosSliderTile(
        tapToEdit: false,
        title: l10n.liquidGlassRefractionBandLabel,
        value: tuning.refractionBand,
        min: LiquidGlassTuning.minRefractionBand,
        max: LiquidGlassTuning.maxRefractionBand,
        divisions: 46,
        valueLabel: _tuningNum(tuning.refractionBand, 1),
        showKeyPoints: showKeyPoints,
        keyPoints: showKeyPoints
            ? const [CourseGlassTuning.defaultRefractionBand]
            : null,
        onChanged: (value) =>
            onUpdate((t) => t.copyWith(refractionBand: value)),
      ),
      HyperosSliderTile(
        tapToEdit: false,
        title: l10n.liquidGlassRefractionEdgePowLabel,
        value: tuning.refractionEdgePow,
        min: LiquidGlassTuning.minRefractionEdgePow,
        max: LiquidGlassTuning.maxRefractionEdgePow,
        divisions: 20,
        valueLabel: _tuningNum(tuning.refractionEdgePow, 2),
        showKeyPoints: showKeyPoints,
        keyPoints: showKeyPoints
            ? const [CourseGlassTuning.defaultRefractionEdgePow]
            : null,
        onChanged: (value) =>
            onUpdate((t) => t.copyWith(refractionEdgePow: value)),
      ),
      HyperosSliderTile(
        tapToEdit: false,
        title: l10n.liquidGlassDispersionLabel,
        value: tuning.dispersion,
        divisions: 20,
        valueLabel: _tuningPct(tuning.dispersion),
        onChanged: (value) => onUpdate((t) => t.copyWith(dispersion: value)),
      ),
      HyperosSliderTile(
        tapToEdit: false,
        title: l10n.liquidGlassRimStrengthLabel,
        value: tuning.rimStrength,
        divisions: 20,
        valueLabel: _tuningPct(tuning.rimStrength),
        onChanged: (value) => onUpdate((t) => t.copyWith(rimStrength: value)),
      ),
      HyperosSliderTile(
        tapToEdit: false,
        title: l10n.liquidGlassRimWidthLabel,
        value: tuning.rimWidth,
        max: LiquidGlassTuning.maxRimWidth,
        // 步长 0.1（3 / 30）：细线口径的取值都在 0.6~1.1 之间，
        // 步长 0.5 会连默认值 0.8 都落不到格点上。
        divisions: 30,
        valueLabel: _tuningNum(tuning.rimWidth, 1),
        onChanged: (value) => onUpdate((t) => t.copyWith(rimWidth: value)),
      ),
      HyperosSliderTile(
        tapToEdit: false,
        title: l10n.liquidGlassBlurSigmaLabel,
        value: blurSigma,
        max: blurSigmaMax,
        // 每格 1：两条量程（0~40 / 0~24）都按 1 递增，档数跟着上限走，别写死 40。
        divisions: blurSigmaMax.round(),
        valueLabel: _tuningNum(blurSigma, 0),
        onChanged: (value) => onUpdate((t) => t.copyWith(blurSigma: value)),
      ),
      HyperosSliderTile(
        tapToEdit: false,
        title: l10n.liquidGlassTintLabel,
        value: tuning.tintAlpha,
        divisions: tintDivisions,
        valueLabel: _tuningPct(tuning.tintAlpha),
        showKeyPoints: showKeyPoints,
        keyPoints: showKeyPoints
            ? const [CourseGlassTuning.defaultTintAlpha]
            : null,
        onChanged: (value) => onUpdate((t) => t.copyWith(tintAlpha: value)),
      ),
    ];
  }

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
                  // 上下给 chrome 留出的净空：顶部是「胶囊 + 日/周分段（同一行）」，
                  // 底部是「一排圆钮 + 名字」。
                  //
                  // 2026-09-20：顶部从两行收成一行（撤标题、分段控件挪进那一行），
                  // 底部那排圆钮往下挪 10dp（26 → 16）—— 两处省下的纵向空间全给
                  // 预览卡（用户口径：把下面的按钮往下调一点、把预览区放大）。
                  final topReserve = topInset + 16 + 40 + 18;
                  final bottomReserve = bottomInset + 24 + 56 + 8 + 18;
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
                  // 圆角跟着缩放走：屏幕圆角 × 缩放比。
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
                                // 内容源变了要显式喊一声（玻璃/壁纸的重绘被
                                // 它们自己的重绘边界挡住，传不到本节点）——
                                // 漏掉就是「整页定格」，见本参数与边界的注释。
                                repaintSignal: _previewSourceDirty,
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
  /// （[_routeSettled]），那之前用首页那张快照顶替（同一张图，落地时逐像素
  /// 无感）。
  ///
  /// ⚠️ 卡片里的图**直接画、不做淡入**，浮影也**跟着暗底一起淡入**（不跟着
  /// 卡片阶跃）。两处都是同一个原因：用户报的「画面缩到最终大小、预览卡片出现
  /// 的同时暗色闪了一下」（2026-09-25）。卡片是**阶跃**出现的那一帧，底下
  /// 两层暗底正从 0% 跳到约 9%：此刻卡片里只要有一点点半透明，底下那片暗就
  /// 会透上来；而浮影若跟着卡片一步到位，卡片四周还会凭空多出一圈 40% 黑 ——
  /// 两者都是"落地之前完全没有、落地那一帧突然有"的暗。
  Widget _buildPreviewCard({required double radius}) {
    return ValueListenableBuilder<double>(
      valueListenable: _zoomProgress,
      // 内页（图片子树）用 child: 透传：每帧只有最外层那个 [DecoratedBox] 重建。
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedBuilder(
          // 图源有两个：本页自己烤的图（[PreviewBakeBoundary]，落定后才开始）
          // 与首页那半边的快照 [hyperosZoomHomeSnapshot]。
          animation: _previewImageSources,
          builder: (context, _) {
            final image = _previewBake.value ?? hyperosZoomHomeSnapshot.value;
            // 曾经这里套了 180ms 的 [AnimatedOpacity]（从暗底淡入）。它与外层
            // 阶跃门叠在一起，正好跨过落点交接那一帧：卡片一出现就是半透明的，
            // 底下的暗底透上来 = "暗一下"。换自家烤图时两边都非空、透明度本来
            // 就不会变，去掉它没有任何损失。
            return image == null
                ? const SizedBox.expand()
                : RawImage(image: image, fit: BoxFit.contain);
          },
        ),
      ),
      builder: (context, progress, child) {
        final grow = HyperosZoomRoute.growT(progress);
        return DecoratedBox(
          // 布局回归钉按这个 key 量卡片的几何：**不要改用 `find.byType(
          // TimetableScreen)`** —— 烤图方案（见文件头「方案 A」）之后卡片里显示的是
          // 快照图，而 TimetableScreen 只剩整屏 1:1 的渲染源、被 Positioned.fill
          // 钉在屏幕顶边，量它等于量渲染源（2026-09-20 修）。
          key: const ValueKey('appearance-editor-preview-card'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: grow <= 0
                ? const <BoxShadow>[]
                : <BoxShadow>[
                    BoxShadow(
                      color: _cardShadowColor.withValues(
                        alpha: _cardShadowColor.a * grow,
                      ),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
          ),
          child: child,
        );
      },
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
          // 一行排完：取消 ｜ 日 / 周切换 ｜ 完成。
          //
          // 2026-09-20：撤掉「外观编辑」标题，把日 / 周切换提到标题原来的位置 ——
          // 标题那行只在说"你在哪"，却占掉一整行；分段控件才是这一页真正要用的
          // 东西。省下的那行（含间隔约 48dp）全部让给预览卡（用户口径：把切换做到
          // 标题的位置、把预览区放大）。
          child: Row(
            children: [
              _capsuleButton(
                label: l10n.cancelAction,
                onTap: _cancel,
                emphasized: false,
              ),
              Expanded(
                child: Center(child: _dayWeekSegmented(l10n)),
              ),
              _capsuleButton(
                label: l10n.appearanceEditorDoneAction,
                onTap: _finish,
                emphasized: true,
              ),
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
      // 键给几何用例用：这条胶囊 2026-09-20 起站在**顶栏正中间**（撤标题腾出来的
      // 位置），「有没有居中」只能靠它的矩形量。
      key: const ValueKey('appearance-editor-day-week'),
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

  /// 底部：一排圆形玻璃入口（调整壁纸 ｜ 材质），居中等距排布。
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
          // 2026-09-20：26 → 16，圆钮往屏幕底边挪 10dp（省下的纵向空间给预览卡）。
          // 与 `bottomReserve` 里的 24（= 16 + 8 余量）必须同步改。
          padding: EdgeInsets.only(bottom: bottomInset + 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleAction(
                icon: Icons.image_outlined,
                label: l10n.appearanceEditorWallpaperAction,
                onTap: _openWallpaperSheet,
              ),
              // 只留等距留白：两个入口之间加一条竖杠是多余的隔断，
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
      // 名字上会毫无反应（名字是本仓加的，就得一起接住）。
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

/// 材质面板的正文：顶上「标题 + 通用 / 课程卡片」一行，下面一层可左右滑的两页。
///
/// 为什么它必须是 StatefulWidget：翻页需要一个**跨重建存活**的 [PageController]，
/// 而面板正文由草稿版本号订阅重画（[_AppearanceEditorScreenState._draftRevision]）——
/// 控制器建在 builder 里的话，用户每改一次设置就换一个，翻页位置随之丢失。
///
/// 两页正文由编辑页那侧的 `_buildGeneralMaterialPage` / `_buildCourseCardMaterialPage`
/// 构造（它们要用编辑页的草稿与写回口子）；这里只管标题行、分段与翻页本身。
class _MaterialSheetBody extends StatefulWidget {
  const _MaterialSheetBody({
    required this.editor,
    required this.l10n,
    this.initialPage = _MaterialSheetBodyState._generalPage,
  });

  final _AppearanceEditorScreenState editor;
  final AppLocalizations l10n;

  /// 初始停留页（0 = 通用，1 = 课程卡片），进页深链接用。
  final int initialPage;

  @override
  State<_MaterialSheetBody> createState() => _MaterialSheetBodyState();
}

class _MaterialSheetBodyState extends State<_MaterialSheetBody> {
  /// 页序：0 = 通用，1 = 课程卡片。与 [PageView] 的 children 顺序一一对应。
  static const int _generalPage = 0;
  static const int _courseCardPage = 1;

  late final PageController _pages;
  int _page = _generalPage;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage == _courseCardPage
        ? _courseCardPage
        : _generalPage;
    _pages = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// 点分段跳页。**用户自己滑**出来的那一页由 [PageView.onPageChanged] 回收索引 ——
  /// 两条路都得走，否则会出现「滑过去一格、分段还亮着原来那格」。
  void _goToPage(int page) {
    if (page == _page) {
      return;
    }
    setState(() => _page = page);
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final l10n = widget.l10n;
    return ValueListenableBuilder<int>(
      valueListenable: editor._draftRevision,
      builder: (sheetContext, _, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题与翻页分段**同一行**（用户口径 2026-09-22）：面板的高度预算只有
            // 约 332px，标题单独占掉一行就是少一行内容。
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.appearanceEditorMaterialAction,
                    style: HyperosTypography.sheetTitle(sheetContext),
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 208),
                  child: _MaterialSegmented<int>(
                    items: {
                      l10n.generalSettingsTitle: _generalPage,
                      l10n.surfaceCourseCard: _courseCardPage,
                    },
                    value: _page,
                    onChanged: _goToPage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 两页等高、各页自己竖向滚动：面板总高由外层 `maxHeight`（半屏上限）
            // 顶住，见 [_AppearanceEditorScreenState._openMaterialSheet]。
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (page) {
                  if (page != _page) {
                    setState(() => _page = page);
                  }
                },
                children: [
                  editor._buildGeneralMaterialPage(sheetContext, l10n),
                  editor._buildCourseCardMaterialPage(sheetContext, l10n),
                ],
              ),
            ),
          ],
        );
      },
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
