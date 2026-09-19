part of '../timetable_settings_screen.dart';

/// 「外观编辑」页：**沉浸式**的一页 —— 整屏暗底，中间一张**真首页缩尺卡**，
/// 顶部一行标题 + 日 / 周切换 + 取消 / 完成，底部一排圆形玻璃入口。
///
/// 用户口径（2026-09-19，三轮）：
/// * 微缩预览是「把整个首页原样缩小」，**直接用首页那份代码、让那个页面缩小**，
///   保证观感一致；要完整展示（顶部底部都不能被切），缩小后摆在屏幕中间；
/// * 不要大标题 + 小标题那两行；
/// * 可日 / 周视图切换，按钮放顶部；
/// * 顶部完成 / 取消；底部「调整壁纸」「材质」两个入口；
/// * 页面结构照参考实现（Nexio 课程表 `CustomizeScheduleScreen.kt` 的「课表外观」
///   页）：沉浸式暗底 + 圆角卡片 + 顶部胶囊按钮 + 底部一排圆钮 + 弹窗打开时上下
///   chrome 淡出。
///
/// 落实方式：
/// * [TimetableScreen] **本体**按整屏逻辑尺寸渲染，`FittedBox` 缩进卡片里 ——
///   不是另写一套小屏布局，也不是「用预览替身近似」；
/// * 卡片圆角取**真机屏幕圆角**并按缩放比例收小（与参考实现
///   `screenRadiusDp * cardScale` 同一口径），所以卡片读起来就是「这台机器的那一屏」；
/// * 日 / 周、进页不进回访状态这些外部控制走 [TimetableHomePreviewScope]
///   （首页一侧在预览模式下不写浏览状态、不接截屏监听，见该 scope 的类注释）；
/// * 卡片支持**双指缩放并回弹**（参考实现同款手势），缩放只作用在卡片内容上、
///   不会传给嵌进来的首页。
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
  static const _scrimColor = Color(0xFF1A1A1A);

  /// 卡片相对可用区的最大宽度比例（剩下的留白保证「在屏幕中间、不顶边」）。
  static const _cardMaxWidthFactor = 0.82;

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

  /// 预览看日课表还是周课表（只影响这份缩尺首页，不动真实浏览位置 —— 首页侧
  /// 在预览模式下不写回访状态，见 [TimetableHomePreviewScope]）。
  bool _dayPreview = false;

  /// 驱动嵌进来的那份真首页开合日视图（它的日视图状态在它自己的 State 里）。
  final ValueNotifier<bool> _previewDayView = ValueNotifier<bool>(false);

  /// 日视图预览看哪一天（1 = 周一 … 7 = 周日）；进页时取今天。
  final ValueNotifier<int> _previewDayOfWeekNotifier = ValueNotifier<int>(
    DateTime.now().weekday,
  );

  /// 弹窗打开期间把上下 chrome 淡出（参考实现同款：让位给内容与弹窗）。
  bool _chromeVisible = true;

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
  }

  @override
  void dispose() {
    _pageGlass.dispose();
    _previewDayView.dispose();
    _previewDayOfWeekNotifier.dispose();
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

  /// 弹窗打开期间淡出上下 chrome（等弹窗关掉再淡回来）。
  Future<void> _withChromeHidden(Future<void> Function() action) async {
    setState(() => _chromeVisible = false);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _chromeVisible = true);
      }
    }
  }

  Future<void> _openWallpaperSheet() {
    final l10n = AppLocalizations.of(context)!;
    return _withChromeHidden(
      () => showHomeHyperosSheet<void>(
        context: context,
        builder: (sheetContext) => HyperosSheetFrame(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: SingleChildScrollView(
            child: buildWallpaperSheetBody(sheetContext, l10n: l10n),
          ),
        ),
      ),
    );
  }

  Future<void> _openMaterialSheet() {
    final l10n = AppLocalizations.of(context)!;
    return _withChromeHidden(
      () => showHomeHyperosSheet<void>(
        context: context,
        builder: (sheetContext) => HyperosSheetFrame(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.appearanceEditorMaterialAction,
                  style: HyperosTypography.sheetTitle(sheetContext),
                ),
                const SizedBox(height: 16),
                HyperosListGroup(
                  children: [
                    // 质感方案：一键写穿一组推荐的材质搭配。
                    HyperosSelectTile<TexturePreset?>(
                      label: l10n.texturePresetLabel,
                      subtitle: l10n.texturePresetSubtitle,
                      items: {
                        l10n.texturePresetClassicFrost:
                            TexturePreset.classicFrost,
                        l10n.texturePresetFullLiquid: TexturePreset.fullLiquid,
                        l10n.texturePresetSoftMist: TexturePreset.softMist,
                        l10n.texturePresetMinimalSolid:
                            TexturePreset.minimalSolid,
                        l10n.texturePresetCustom: null,
                      },
                      value: texturePresetOf(_draft),
                      onChanged: (preset) async {
                        if (preset == null) return;
                        final applied = await _confirmTexturePreset(preset);
                        if (!applied || !mounted) return;
                        setSheetState(() {});
                      },
                    ),
                    // 玻璃模式四档：与「课表页面」设置里那行同一映射。
                    HyperosSelectTile<GlassModeChoice>(
                      label: l10n.frostedGlassModeLabel,
                      items: {
                        l10n.frostedGlassModeSolid: GlassModeChoice.solid,
                        l10n.frostedGlassModeGaussian: GlassModeChoice.gaussian,
                        l10n.frostedGlassModeSoft: GlassModeChoice.softGlass,
                        l10n.frostedGlassModeLiquid:
                            GlassModeChoice.liquidGlass,
                      },
                      value: glassModeChoiceOf(_draft),
                      onChanged: (value) {
                        _updateDraft(applyGlassModeChoice(_draft, value));
                        setSheetState(() {});
                      },
                    ),
                    // 高级材质（柔光 / 液态）才需要进一步调校：档位与滑杆都在那页。
                    if (isAdvancedGlassMode(_draft.frostedGlassMode))
                      HyperosListTile(
                        title: l10n.advancedMaterialTitle,
                        details: l10n.advancedMaterialEntrySubtitle,
                        onTap: () async {
                          await HyperosNavigation.push(
                            context,
                            settings: const RouteSettings(
                              name: '/settings/advanced-material',
                            ),
                            builder: (_) =>
                                const AdvancedMaterialSettingsScreen(),
                          );
                          if (!mounted) return;
                          setState(() {
                            _draft = context.read<TimetableProvider>().settings;
                          });
                          setSheetState(() {});
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 与「课表页面」那行同一个确认口径（写穿范围先讲清楚），返回是否应用。
  Future<bool> _confirmTexturePreset(TexturePreset preset) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showHyperosConfirmDialog(
      context: context,
      title: l10n.texturePresetApplyTitle,
      message: l10n.texturePresetApplyBody,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.confirmAction,
    );
    if (confirmed != true || !mounted) {
      return false;
    }
    _updateDraft(applyTexturePreset(_draft, preset));
    return true;
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
            child: ColoredBox(
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

                  return Stack(
                    children: [
                      Positioned(
                        left: (constraints.maxWidth - cardWidth) / 2,
                        top: cardCenterY - cardHeight / 2,
                        width: cardWidth,
                        height: cardHeight,
                        child: _buildPreviewCard(
                          virtualScreen: virtualScreen,
                          radius: cardRadius,
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

  /// 中间那张卡：真首页**整页一起缩**进来 + 屏幕圆角 + 描边浮影。
  ///
  /// 两条硬约束（都是真机试出来的，别再回头）：
  ///
  /// 1. **必须整页一起缩**（这里是 `FittedBox` 缩一份整屏尺寸的真首页）。
  ///    曾经改成「按卡片尺寸重新排一遍 + 缩字号」，真机上只有文字缩了，写死
  ///    尺寸的部件（玻璃坞药丸、玻璃球、玻璃带高度、图标）全都不缩 —— 底栏
  ///    跟首页一样大。整页一起缩则一切同比。
  /// 2. **玻璃的采样比例要按缩放折算**，否则玻璃读歪（真机现象：玻璃带发白
  ///    死板、或一条条横线）。这件事由采样宿主自己处理 —— 见
  ///    `HyperosGlassBackdropCapture.paint` 里按祖先缩放折算的采样比例，
  ///    这里不需要做别的。
  Widget _buildPreviewCard({
    required Size virtualScreen,
    required double radius,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 32, spreadRadius: 2),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: FittedBox(
          // 默认就是 contain：整页等比缩进卡片，不变形、不裁切。
          child: SizedBox(
            width: virtualScreen.width,
            height: virtualScreen.height,
            child: TimetableHomePreviewScope(
              dayView: _previewDayView,
              dayOfWeek: _previewDayOfWeekNotifier,
              // 预览里点按一律吞掉：这是「看外观」的缩略图，不是第二个
              // 可操作首页（误触会加课、翻周、改真实浏览位置）。
              child: const IgnorePointer(
                child: TimetableScreen(
                  // 预览不查更新、不跑秒级刷新：那是首页自己的事。
                  enableUpdateCheck: false,
                  enableProgressTimer: false,
                ),
              ),
            ),
          ),
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
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
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
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
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
