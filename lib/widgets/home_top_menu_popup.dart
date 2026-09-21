import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/frosted/liquid_glass_degradation.dart';
import 'package:university_timetable/ui/hyperos/hyperos_blurred_header.dart';
import 'package:university_timetable/ui/hyperos/hyperos_glass_backdrop_host.dart';
import 'package:university_timetable/ui/hyperos/hyperos_miuix_spec.dart';
import 'package:university_timetable/ui/hyperos/hyperos_theme.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart'
    show UndimmedBackdropCapture;
import 'package:university_timetable/ui/hyperos/os4_glass_popup_surface.dart';
import 'package:university_timetable/ui/hyperos/os4_glass_backdrop.dart';
import 'package:university_timetable/utils/frame_perf_probe.dart';
import 'package:university_timetable/widgets/home_top_menu.dart';

/// 主 / 二级面板共用的尺寸约束。
///
/// 上游默认是 `MiuixGlassPopupSizing(maxWidth: 288)`，而新条目
///（`MiuixGlassPopupItem` 的文字样式 + 箭头 + 内边距）比旧实现的手搓条目宽，
/// 面板会被顶到接近上限 —— 真机上就是"菜单比换实现前胖了一圈"。
///
/// 收到 **200** 即回到旧实现的**下界原宽**：旧公式
/// `132 + HyperosMiuixDropdown.popupExtraLeadingWidth` 恰好 = 200，而旧条目更窄、
/// 实际宽度一直停在这个下界。
///
/// ⚠️ **两块面板必须传同一份**：`sizing` 是各自独立的入参，只给一级会让
/// 主面板 200、二级默认 288，两块宽度对不齐。
const _popupSizing = MiuixGlassPopupSizing(maxWidth: 200);

/// 二级展开 / 收起的时长：一级让位缩放、两侧箭头旋转共用同一长度。
///
/// 200ms + `Curves.fastOutSlowIn` 抄的是旧实现（`hyperos_list_popup.dart`
/// 的 `_submenuRevealDuration`）—— 同一套交互在两处必须同手感。
const _submenuRevealDuration = Duration(milliseconds: 200);

/// 首页右上角「更多」菜单的**列表形态**——改用上游 flutter_miuix 1.2.0 的
/// HyperOS 4 玻璃弹层实现（`MiuixGlassTransformPopup` + `MiuixGlassSecondaryPopup`），
/// 取代本仓库手搓的 `lib/ui/hyperos/hyperos_list_popup.dart` 那条路径。
///
/// 为什么换：
/// - 上游这套与旧实现同源（都移植自 Kotlin `compose-miuix-ui/miuix`），但一级
///   菜单走 `motion: transform`——**从触发按钮连续变形成菜单**（HyperOS 4 的
///   形变动效），二级面板走 `motion: secondary` 并可 `materialAnchor` 共享一级材质。
/// - 新实现用运行时片元着色器（`miuix_os4_*.frag`）取材质，**没有旧实现那套
///   「共享组捕获、合成器逐帧刷新」**：旧实现在弹簧动画期间每帧重采整页，
///   真机实测每次打开瞬时分配 100~140MB 离屏目标、快速连开时 RSS 峰值 1.01GB。
///
/// 上游弹层是「常驻挂载 + 切换 show」的声明式组件（内部用 OverlayPortal 挂到
/// 调用处主题之下），所以本组件由宿主常驻，[show] 控制显隐；条目点击经
/// [onSelected] 回传入口 id，由宿主沿用既有的 `switch` 分发。
class HomeTopMenuPopup extends StatefulWidget {
  const HomeTopMenuPopup({
    super.key,
    required this.show,
    this.backdrop,
    required this.anchor,
    required this.anchorContent,
    required this.entries,
    required this.hasAvailableUpdate,
    required this.onDismissRequest,
    required this.onSelected,
  });

  /// 是否展开一级菜单。
  final bool show;

  /// 材质取样源覆盖。默认按所在屏自动解析（屏级作用域 → 注册表栈顶 → 全局），
  /// 与 [HyperosSelectPopup] 同一套规则；测试可显式传入。
  final MiuixLayerBackdrop? backdrop;

  /// 绑在「更多」按钮上的锚点，由宿主创建并持有。
  final MiuixGlassPopupAnchor anchor;

  /// 「更多」按钮内容的副本（形变动效要它从按钮位置长出来）。上游要求传入
  /// **不含 GlobalKey** 的图标副本，避免与真实按钮抢同一个 key。
  final Widget anchorContent;

  /// 菜单条目（与八宫格共享同一份自定义排列）。
  final List<HomeMenuEntry> entries;

  /// 是否有待更新；为真时「更新」条目带点状角标。
  final bool hasAvailableUpdate;

  final VoidCallback onDismissRequest;

  /// 被点条目 id（含二级子项 id）。
  final ValueChanged<String> onSelected;

  @override
  State<HomeTopMenuPopup> createState() => _HomeTopMenuPopupState();
}

class _HomeTopMenuPopupState extends State<HomeTopMenuPopup> {
  /// 一级面板那摞行的 key：遮罩点击要靠它量出"一级面板的矩形"，才能区分
  /// 「点在一级面板里（二级之外）」与「点在两个面板之外」（见 [_handleScrimTap]）。
  final GlobalKey _rowsKey = GlobalKey();

  /// 二级面板的锚点：绑在「添加」那一行上（上游 `MiuixGlassAnchor` 用法）。
  final MiuixGlassPopupAnchor _addRowAnchor = MiuixGlassPopupAnchor();

  /// 二级面板的锚定矩形（点开那一刻从 [_addRowAnchor] 取窗口坐标）。
  Rect? _secondaryBounds;
  bool _secondaryOpen = false;

  /// 本次展开期间持有的屏级采样源（展开时 acquire，关闭时 release）。
  HyperosGlassBackdropController? _captureHold;

  @override
  void dispose() {
    // 必须与 [_syncCaptureHold] 取持有的方法配对：这里持有的是
    // `holdRecording()`，归还只能用 `releaseRecording()`。
    // `release()` 是给 `acquire()` 用的（那条路要整层快照），它只递减
    // `_plainConsumers`，对本弹层的 `_recordingHolds` 无效 —— 漏一次归还，
    // 宿主页的 `capturing` 就再也回不到 false，页面一直白录帧。
    _captureHold?.releaseRecording();
    _captureHold = null;
    _addRowAnchor.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HomeTopMenuPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.show != widget.show) {
      // 诊断标记：与 popup 出场/收起动画同一帧，用来把 `[frame-perf]` 的卡顿段
      // 归因到菜单开合（临时件，见 frame_perf_probe.dart）。
      FramePerfProbe.mark(widget.show ? 'homeMenu:open' : 'homeMenu:close');
      if (oldWidget.show && !widget.show) {
        // 宿主若绕过 [_close] 直接把菜单收起来（切页、路由变化等），二级状态
        // 必须跟着复位：否则下次打开时 `stacked` 还是 true、让位进度停在 1，
        // 面板会"开局就是缩小的"，还得再点一次才回正常。
        _secondaryOpen = false;
        _secondaryBounds = null;
      }
      _syncCaptureHold();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCaptureHold();
  }

  /// 菜单展开期间请求所在屏录帧（关闭即归还，页面没玻璃时不空转）。
  ///
  /// 只持有"继续录帧"（`holdRecording`），不请求整层快照：本弹层两块面板都走
  /// 注入面（读采样区），整层图没人读 —— 而它会在开合动画期间每帧录一张全屏。
  void _syncCaptureHold() {
    final next = widget.show && widget.backdrop == null
        ? HyperosGlassBackdropRegistry.resolve(context)
        : null;
    if (identical(next, _captureHold)) {
      return;
    }
    _captureHold?.releaseRecording();
    _captureHold = next;
    next?.holdRecording();
  }

  /// 收起二级并关掉一级菜单；点遮罩关闭也走这里。
  void _close() {
    if (_secondaryOpen) {
      setState(() => _secondaryOpen = false);
    }
    widget.onDismissRequest();
  }

  /// 遮罩被点（带全局坐标）：**关整窗只作用在两个面板之外**。
  ///
  /// - 点在一级面板的矩形内（二级之外的那部分）：只收起二级、回到一级 ——
  ///   一级面板在二级展开期间是不可交互的（上游 `stacked`），所以这一下必然
  ///   落在二级的全屏遮罩上，只能由遮罩按坐标判断归属。
  /// - 点在两个面板之外：关掉整个菜单。
  void _handleScrimTap(Offset globalPosition) {
    final rows = _rowsKey.currentContext?.findRenderObject();
    if (rows is RenderBox && rows.hasSize) {
      final rect = rows.localToGlobal(Offset.zero) & rows.size;
      if (rect.contains(globalPosition)) {
        _closeSecondary();
        return;
      }
    }
    _close();
  }

  void _closeSecondary() {
    if (_secondaryOpen) {
      setState(() => _secondaryOpen = false);
    }
  }

  /// 菜单项被选中：**不在这里收菜单**，收菜单的时机交给宿主。
  ///
  /// 列表态菜单的条目几乎都是"跳页面/弹层"：先收菜单、再推路由，中间会有一两帧
  /// 「菜单已经收了、新页面还没盖满」，底下的圆形按钮与爱心球就在这两帧里冒出来
  /// 闪一下（真机 2026-09-15 反馈："点击进入页面的时候菜单闪一下、后面的圆按钮
  /// 爱心按钮跟着闪现"）。宿主知道新路由什么时候盖满屏幕，由它决定何时收
  /// （见 `timetable_screen.dart` 的 `_requestCloseHomeMenu`）。
  ///
  /// 遮罩点击 / 返回键那条路不走这里，仍是立刻收；宿主若绕过本回调直接收菜单
  /// （切页、路由变化），[didUpdateWidget] 会把二级状态复位。
  void _select(String id) {
    widget.onSelected(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = widget.entries;
    final backdrop =
        widget.backdrop ??
        HyperosGlassBackdropRegistry.resolve(context)?.backdrop ??
        os4GlassBackdrop;
    // 二级面板的锚定矩形（窗口坐标，点开那一刻从 [_addRowAnchor] 取）。
    //
    // 取一份局部变量只为类型提升（`_secondaryBounds` 是可空字段）：它既是二级
    // 面板的锚定矩形，也是「二级要不要挂」的判据。
    final secondaryBounds = _secondaryBounds;
    // 要不要给两块面板垫一层共享组捕获（见下面 `BackdropGroup` 那段）。
    //
    // 只在二级面板真的会挂出来时才**真的垫**（`_secondaryBounds` 一旦点开就留到菜单
    // 关闭，二级收起动画期间那块玻璃还在读组捕获）；玻璃画不出来时也不垫 —— 降级
    // 实底不采背景，那层全屏 pass 白付。`_secondaryBounds` 是 state，这里读它是为了
    // 让垫底与二级面板**同帧**进出：晚一帧的话，二级面板第一帧的共享捕获点会落在
    // 它自己身上（它排在一级面板之后），又会采到一级玻璃。
    final needsGroupCapture =
        secondaryBounds != null &&
        !LiquidGlassDegradation.shouldDegrade(context);

    // 外层手势隔离：弹层自带的滚动视图不该继承首页的橡皮筋物理，也不该把滚动
    // 通知冒泡回首页（首页同样有整页滚动监听）。
    //
    // ⚠️ 两块面板必须**同处一个共享捕获组**（[BackdropGroup] + 组内首个分组滤镜
    // 垫底）。这是本仓弹层的统一结构 —— 列表弹窗、选择弹窗、底部弹窗、设置页
    // 预览各有一份；首页菜单从上游 OS4 弹层迁过来时漏了这一层，二级面板的
    // `useAncestorGroupCapture` 一直是空转的（见下面垫底的说明）。
    return HyperosGlassPopupScrollGuard(
      child: BackdropGroup(
        child: Stack(
          children: [
            // 组内**第一个**分组滤镜：在面板之前把共享捕获点钉在「还没画上一级
            // 面板」的页面上。二级面板的液态面（`grouped: true`）采的就是它。
            //
            // 为什么非有不可：`grouped` 只是「去祖先 BackdropGroup 取共享捕获
            // 点」，**组里没有别的滤镜时它什么也取不到**，引擎于是退回「按绘制
            // 顺序采自己下面那一层」——而二级面板下面正是**一级面板的玻璃**。
            // 玻璃叠玻璃再折射一遍，一级那张卡片会以折射后的样子在二级卡片里
            // 重影出来，用户读到的就是「同时显示了收缩和未收缩的两个一级卡片，
            // 缩放后的显示在上面」（2026-09-20 反馈）。
            //
            // 只在二级真的会挂出来、且玻璃画得出来时才真的垫上（那层是全屏合成器
            // 捕获）；否则这格是 `SizedBox.shrink`，一分钱不付。开关口径与列表弹窗
            // 的 `_hasSubmenu` 那段同款。
            //
            // ⚠️ 这一格**常驻**（不垫时是 `SizedBox.shrink`），不要改成条件插拔：
            // 位置一变，下面那两块面板在 Stack 里的下标跟着变，Flutter 的无 key
            // 复用会判成「换了个 widget」而把整棵子树重建 —— 一级面板的
            // `GlassPopupPresenter` State 一重建，`_stack` 让位动画就永远停在 0
            // （二级展开时一级面板不缩了），而且入场形变动画会重放一遍。
            // 2026-09-20 实测：条件插拔时 `panelScale` 停在 0.9998 而不是 0.95。
            Positioned.fill(
              child: needsGroupCapture
                  ? const UndimmedBackdropCapture()
                  : const SizedBox.shrink(),
            ),
            MiuixGlassTransformPopup(
              show: widget.show,
              anchor: widget.anchor,
              anchorContent: widget.anchorContent,
              backdrop: backdrop,
              // 宽度见 [_popupSizing]（收到旧实现的下界原宽 200）。
              sizing: _popupSizing,
              // 面板材质交给全局档位分派（液态 / 柔光 / 高斯 / 实底）——
              // **形变动效与几何仍由上游 presenter 负责，一行不动**。
              // 不再传 `visuals`：注入面已取代上游内置面板，上游那 7 个 OS4 材质
              // 字段不再参与渲染（见 os4_glass_popup_surface.dart）。
              surfaceBuilder: hyperosGlassPopupSurface,
              // ── 二级展开时一级面板「让位」：整张卡朝右收，被点那一行不动 ──
              //
              // 手感由 fork 补丁的一个参数定：`stackDuration` 把包内那条
              // 「收敛容差写死、参数不可调」的让位弹簧换成确定性的 200ms
              // fastOutSlowIn（曲线取补丁缺省值；时长与旧实现
              // `hyperos_list_popup.dart` 同值）。
              stacked: _secondaryOpen,
              stackDuration: _submenuRevealDuration,
              // 支点 = **被点那一行的右端**（2026-09-21 用户第二轮回话）。
              //
              // 用户口径：「卡片要他妈的缩小」「一级只缩小了一部分」「不是像右上角
              // 缩放，是向右边缩放」「被点的那一行不变」「二级一定不要缩小」。
              //
              // 取面板的锚点角（`stackShrinkFromAnchor: true`）时，面板的**上边缘与
              // 右边缘被钉死**，只有左边缘往右收、下边缘往上收 —— 真机读起来正是
              // 「卡片只缩了一部分」。改把支点钉在**被点那一行的右端**（那一行横跨
              // 面板全宽，它的右端就落在面板右边缘上）：面板照样朝右收，但现在是
              // **整张缩** —— 上边缘跟着往下、下边缘往上、左边缘往右，三个方向一起
              // 收；又因为固定点就在那一行上，**被点那一行在屏幕上不动**（实测偏差
              // ≤0.5px），二级面板顶部那份「父行复印件」照样与它对得上。
              //
              // 传法：`stackPivotBounds` 取矩形**左上角**，传零尺寸矩形 = 钉到一个点；
              // `_secondaryBounds` 就是点开二级那一刻量下的父行窗口矩形（与二级面板
              // 的锚定矩形同一份），`right/top` 正是它的右上角。
              //
              // ⚠️ **卡片要整张缩，不要只缩内容**（2026-09-20 试过又回退）：为了让
              // 一级卡轮廓与「不参与让位的二级卡」对齐，一度传过
              // `stackScalesPanel: false`（只缩内容、卡片轮廓原地不动）。用户当场
              // 否掉 ——「为什么他妈的卡片没缩，内容缩放了」。**卡片本身缩下去才是
              // 这个让位的本体**，内容跟着缩是理所当然的。
              //
              // ⚠️ **二级面板不参与让位**（2026-09-21 用户口径）：一级缩 5% 后左边缘
              // 比二级多收 5% 板宽（200 宽上是 10px），接缝就在两块卡的左边缘。用户
              // 明确选择接受这条缝 —— 代价是固定的，别再拿「二级也缩」「只缩内容」去
              // 消它：前者会让二级的字一起小 5%、被点那一行跟着挪（用户否），后者已被
              // 否过（见 `rejected/bug-fix/2026-09-20-home-menu-stack-scales-content-only.md`）。
              stackShrinkFromAnchor: true, // 兜底：只在 stackPivotBounds 为空时才会用到
              stackPivotBounds: secondaryBounds == null
                  ? null
                  : Rect.fromLTWH(secondaryBounds.right, secondaryBounds.top, 0, 0),
              // 让位期间的压暗色：上游默认是「暗色主题黑罩 / 亮色主题**白罩**」，
              // 于是亮色主题下二级展开时一级面板反而**变亮**（真机反馈）。
              // 改用与列表弹层同一份——模态遮罩色（黑）× 同一倍率 0.5。
              maskColor: HyperosBlurredHeader.modalBarrierColor(context)
                  .withValues(
                    alpha:
                        HyperosBlurredHeader.modalBarrierColor(context).a * 0.5,
                  ),
              onDismissRequest: _close,
              child: KeyedSubtree(
                key: _rowsKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < entries.length; index++) ...[
                      if (index > 0 &&
                          entries[index].category !=
                              entries[index - 1].category)
                        const SizedBox(height: 8),
                      _row(entries[index], l10n),
                    ],
                  ],
                ),
              ),
            ),
            if (secondaryBounds != null)
              MiuixGlassSecondaryPopup(
                show: _secondaryOpen,
                anchorBounds: secondaryBounds,
                // 二级与一级共用同一个锚点（上游 materialAnchor 语义）。注意锚点
                // 一旦绑定到图标按钮，上游 `inherited` 分支会让内置面板改用锚点
                // 的 OS4 surface —— 那条分支已被注入面取代，不再参与渲染。
                materialAnchor: widget.anchor,
                backdrop: backdrop,
                // 与一级面板**同一份**宽度约束，两块才对得齐。
                sizing: _popupSizing,
                // 二级面板**浮在一级玻璃之上**，必须走带垫底的注入面：否则液态档
                // 会采样到一级面板的玻璃输出，玻璃叠玻璃再折射一遍、读感浑浊。
                // ⚠️ 这个垫底（`grouped: true`）要靠上面那个 `BackdropGroup` 才
                // 真的生效 —— 组里没有垫底滤镜时它什么也取不到，见那段说明。
                surfaceBuilder: hyperosGlassPopupSecondarySurface,
                // ── 二级**不参与**让位（2026-09-21 用户口径）──
                //
                // 上游只让一级参与让位、二级原地不动；本仓一度给二级补了整族让位
                // 参数（`stacked` + `stackPivotBounds` + `stackLocksInput`）让它跟
                // 一级绕同一点一起缩，把两块卡的左边缘缝归零。用户否掉：「二级
                // 弹出时被点的那一行不能变，只向下展开，只有一级向右缩一点」——
                // 二级跟着缩会让它的行文字一起小 5%（三级亮度里最亮的那层缩下去
                // 最显眼），而且被点那一行的**复印件**就是二级的标题行（它按
                // [secondaryBounds] 固定定位、本身不跟着一级的让位动），二级一缩
                // 反而是「被点的按钮在缩放、在挪」。所以这里一个让位参数都不传：
                // 二级保持原字号、原位置，只有一级缩。
                //
                // 代价是接缝回来：一级左边缘比二级多收 5% 板宽（200 宽上 10px），
                // 用户已在同一轮明确选择接受（见一级面板 `stackPivotBounds` 那段
                // 注释）。
                //
                // 只留底边距（顶边 0）：二级面板顶边 = 锚点行（「添加」）顶边，
                // 标题行才落在被点那一行的**原位**上（默认顶边 8 会整体下沉）。
                // 二级自己不让位，所以它这份是屏幕上唯一可见的「添加」—— 一级里
                // 那份缩过、退到它背后，读起来就是「那一行没动，下面分出一截」。
                contentPadding: const EdgeInsets.only(bottom: 8),
                // 遮罩点击带坐标 → 由 [_handleScrimTap] 区分"点一级面板内"还是
                // "点两个面板之外"；返回键仍走 onDismissRequest（先收二级、
                // 再按才关窗），两条路径分工与旧实现一致。
                onScrimTap: _handleScrimTap,
                onDismissRequest: _closeSecondary,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _secondaryTitleRow(l10n),
                    for (final child in kAddCourseSubmenu(l10n))
                      MiuixGlassPopupItem(
                        text: child.label,
                        onPressed: () => _select(child.value),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 二级面板顶部重复出来的**父行（标题行）**。
  ///
  /// 口径同旧实现（`hyperos_list_popup.dart` 的「父行在卡内原位重复」）：与其它
  /// 行同款条目 + 下方一条 hairline；差别只在箭头朝上（展开态）且**点它只收起
  /// 二级、不关菜单**。二级面板顶边 = 锚点行顶边（见 `contentPadding`），所以这
  /// 一行与一级里那一行在屏幕上同位，读起来是"同一行分出了下面一截"。
  Widget _secondaryTitleRow(AppLocalizations l10n) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      MiuixGlassPopupItem(
        text: _submenuParentLabel(l10n),
        showArrow: true,
        arrowRotation: -90,
        arrowRotationDuration: _submenuRevealDuration,
        onPressed: _closeSecondary,
      ),
      // 父行 → 子项的分隔线：数值与旧实现同一份（水平内边距与行文字对齐、
      // 细线 0.75、墨色 15%）。
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HyperosMiuixDropdown.insideHorizontalPadding,
          vertical: 4,
        ),
        child: Container(
          height: HyperosMiuixDivider.thickness,
          color: HyperosColors.onSurface(
            context,
          ).withValues(alpha: 0.15),
        ),
      ),
    ],
  );

  /// 「添加」那一行的标题（二级面板的标题行与一级用同一份文案）。
  ///
  /// 用循环而不是 `firstWhere`：`entries` 为空（部分测试就这么挂）时不能抛。
  String _submenuParentLabel(AppLocalizations l10n) {
    for (final entry in widget.entries) {
      if (entry.id == kAddCourseSubmenuParentId) {
        return entry.title(l10n);
      }
    }
    return '';
  }

  Widget _row(HomeMenuEntry entry, AppLocalizations l10n) {
    final label = entry.title(l10n);
    final isAdd = entry.id == kAddCourseSubmenuParentId;

    final item = isAdd
        // 「添加」是展开开关：点它不关菜单，只浮出二级面板（与旧实现的
        // 二级列表同一组目的地，宿主按子项 id 直开对应页面）。
        ? MiuixGlassAnchor(
            anchor: _addRowAnchor,
            child: MiuixGlassPopupItem(
              text: label,
              showArrow: true,
              // 收起朝右（0）、展开朝上（-90）；LTR 的上箭头取 -90（上游约定）。
              arrowRotation: _secondaryOpen ? -90 : 0,
              arrowRotationDuration: _submenuRevealDuration,
              onPressed: () {
                final bounds = _addRowAnchor.bounds;
                if (bounds == null) {
                  return;
                }
                setState(() {
                  _secondaryBounds = bounds;
                  _secondaryOpen = true;
                });
              },
            ),
          )
        : MiuixGlassPopupItem(text: label, onPressed: () => _select(entry.id));

    if (entry.id != kUpdateEntryId || !widget.hasAvailableUpdate) {
      return item;
    }
    // 「更新」条目的点状角标：上游 PopupItem 没有末尾槽位，用 Stack 叠在
    // 行尾（与旧实现 trailing 角标同一位置/语义）。
    return Stack(
      children: [
        item,
        const PositionedDirectional(
          end: 16,
          top: 0,
          bottom: 0,
          child: Center(child: MiuixBadge()),
        ),
      ],
    );
  }
}
