import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos_blurred_header.dart';
import 'package:university_timetable/ui/hyperos/hyperos_glass_backdrop_host.dart';
import 'package:university_timetable/ui/hyperos/hyperos_miuix_spec.dart';
import 'package:university_timetable/ui/hyperos/hyperos_theme.dart';
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

    // 外层手势隔离：弹层自带的滚动视图不该继承首页的橡皮筋物理，也不该把滚动
    // 通知冒泡回首页（首页同样有整页滚动监听）。
    return HyperosGlassPopupScrollGuard(
      child: Stack(
        children: [
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
            // 二级展开时一级面板"让位"：缩小 5% + 压暗，收起复原。
            //
            // 手感由 fork 补丁的两个参数定：`stackDuration` 把包内那条
            // 「收敛容差写死、参数不可调」的让位弹簧换成确定性的 200ms
            // fastOutSlowIn（曲线取补丁缺省值；时长与旧实现
            // `hyperos_list_popup.dart` 同值）；
            // `stackPivotBounds` 把支点钉在**被点开的这一行**上（见下）。
            stacked: _secondaryOpen,
            stackDuration: _submenuRevealDuration,
            // 让位支点 = 被点的那一行（`_secondaryBounds` = 「添加」行的窗口矩形，
            // 点开二级那一刻量下）。
            //
            // 为什么不能用「锚点角」(`stackShrinkFromAnchor`)：支点取哪个角，
            // 面板就朝那个角缩，**离角越远的内容挪得越多** —— 而这正是二级面板
            // 顶部那个标题行要钉住的东西（它是一级里这一行的复印件，两份必须
            // 逐像素重合）。「更多」按钮在面板右上，这一行离那个角有一百多像素，
            // 实测 200 宽的面板上它被挪了 9px：同一行字显示成两份、还错着位
            // （2026-09-20 用户反馈「一级菜单同时显示了收缩和未收缩两个状态」）。
            // 把这一行自己的矩形当支点，它的左上角原地不动，复印件与它对齐到
            // 1px 以内；面板则向这一行收拢（顶边 / 右边各内收 7~9px，读起来仍是
            // "整块面板让位退后"）。
            stackPivotBounds: _secondaryBounds,
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
          if (_secondaryBounds != null)
            MiuixGlassSecondaryPopup(
              show: _secondaryOpen,
              anchorBounds: _secondaryBounds,
              // 二级与一级共用同一个锚点（上游 materialAnchor 语义）。注意锚点
              // 一旦绑定到图标按钮，上游 `inherited` 分支会让内置面板改用锚点
              // 的 OS4 surface —— 那条分支已被注入面取代，不再参与渲染。
              materialAnchor: widget.anchor,
              backdrop: backdrop,
              // 与一级面板**同一份**宽度约束，两块才对得齐。
              sizing: _popupSizing,
              // 二级面板**浮在一级玻璃之上**，必须走带垫底的注入面：否则液态档
              // 会采样到一级面板的玻璃输出，玻璃叠玻璃再折射一遍、读感浑浊。
              surfaceBuilder: hyperosGlassPopupSecondarySurface,
              // 只留底边距（顶边 0）：二级面板顶边 = 锚点行（「添加」）顶边，
              // 标题行才能与一级那一行**逐像素同位**（默认顶边 8 会整体下沉）。
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
