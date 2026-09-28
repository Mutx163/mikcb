import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

import 'hyperos_glass_backdrop_host.dart';
import 'hyperos_theme.dart';
import 'os4_glass_backdrop.dart';
import 'os4_glass_popup_surface.dart';

/// 锚定式玻璃菜单里的一项（[HyperosAnchorMenuPopup] 的条目）。
@immutable
class HyperosAnchorMenuEntry {
  const HyperosAnchorMenuEntry({
    required this.label,
    required this.value,
    this.destructive = false,
    this.enabled = true,
    this.icon,
  });

  final String label;

  /// 回传给宿主的值（宿主沿用 `switch` 分发）。
  final Object value;

  /// 删除一类：文案染错误色。
  final bool destructive;

  /// 禁用项：上游把它画成 40% 透明且不响应点按。
  final bool enabled;

  /// 可选前置图标（20~24dp 的 `Icon` 即可，组件会用条目的墨色统一染色）。
  final Widget? icon;
}

/// 锚在按钮上的 OS4 玻璃菜单（上游 `MiuixGlassDropdownPopup`），取代本仓手搓的
/// `showHyperosListPopup`（0.15 倍缩放弹出 + 逐帧重采整页的液态玻璃）。
///
/// 迁移理由见 `hyperos_list_popup.dart` 与 `home_top_menu_popup.dart` 的类注释：
/// 旧路径的弹出观感、玻璃采样（每次打开瞬时分配 100~140MB 离屏目标）与
/// 退出时序都不合 HyperOS 口径，且与首页菜单形成两套手感。
///
/// ## 为什么是 `dropdown` 而不是 `transform`（**别改成 transform**）
///
/// 首页「更多」菜单用的是 `MiuixGlassTransformPopup`（`motion: transform`，
/// 从按钮连续变形长出）。那套动效有两条硬编码，是**为圆球锚点设计**的：
///
/// 1. 面板起始圆角 = 锚点矩形的**短边一半**（`popup_presenter.dart` 的
///    `(_openingAnchorBounds?.shortestSide ?? 48) / 2`）。首页锚点本身是
///    48×48 的玻璃圆球 → 起始圆角 24，「这颗球化成菜单」物理连贯。
/// 2. 弹出期间**真实锚点内容被隐藏**（`_hideAnchor`），改成在浮层上画一份
///    模糊渐隐的 `anchorContent` 副本当形变种子。
///
/// 方形图标按钮（三个点那一类）套上去就成了「图标消失 → 原地冒出一颗玻璃圆珠
/// → 菜单从珠子里长出来」（2026-09-28 真机反馈：不该有圆按钮效果）。
///
/// `dropdown` 动效解决了第一条：起始圆角固定 `lerpDouble(4, cornerRadius, …)`
/// 是微圆角，不会算出圆球；而且它不画 `anchorContent` 形变种子（那段是
/// `isTransform && …` 才走的），所以那颗玻璃圆珠没有了。它也是上游给
/// 「一组操作项」的正解，本仓下拉选择控件（`HyperosSelect` 的 OS4 路径）
/// 已经在用它 —— 材质、宽度口径、遮罩、退出时序全部一致。
///
/// **但它照样会藏锚点图标**：`_hideAnchor` 判的是
/// `motion == transform || motion == dropdown`。所以本组件刻意**不绑
/// `MiuixGlassAnchor`**，改传按钮矩形 [anchorBounds] —— 详见该参数的说明。
///
/// 用法：
/// 1. 宿主持有按钮的 `GlobalKey`，打开菜单那一刻量出它的窗口矩形；
/// 2. 本组件**常驻挂载**，用 [show] 切显隐（条件插拔会让 presenter 的 State
///    重建、入场动画重放），[anchorBounds] 与条目在收起后要**保留**到退场结束
///    （见 `time_scheme_management_screen.dart` 的 `_schemeMenuSession`）。
///
/// 一级面板不需要 `BackdropGroup` 垫底：只有二级面板
/// （`useAncestorGroupCapture: true`）才要去祖先组取共享捕获点。
class HyperosAnchorMenuPopup extends StatefulWidget {
  const HyperosAnchorMenuPopup({
    super.key,
    required this.show,
    required this.anchorBounds,
    required this.entries,
    this.onCollapseRequested,
    this.onDismissRequest,
    this.onSelected,
    this.sizing = os4GlassPopupStandardSizing,
    this.opaqueSurface = false,
  });

  final bool show;

  /// 锚点按钮的**窗口坐标**（打开瞬间量一次，冻结住）。
  ///
  /// **不要**改成绑 `MiuixGlassAnchor` + 传 `anchor` 对象：上游 presenter 在
  /// `_hideAnchor`（`transform` **与** `dropdown` 两种动效都为真）下会把锚点
  /// 控件设成 `contentHidden`，`MiuixGlassAnchor` 随即把按钮内容 `Opacity(0)`；
  /// 而复位的时机是 `_finish()` —— 退场动画**全部播完**（两条弹簧收敛，实测
  /// ≈670ms）才把图标放回来。用户读到的就是「关弹窗 → 三个点消失 → 过半秒
  /// 才回来」（2026-09-28 真机反馈）。
  ///
  /// 传矩形 + 不绑锚点，图标全程可见、也没有这个延迟；这与 `HyperosSelect`
  /// 的 OS4 路径（`hyperos_select.dart` 传 `anchorBounds`）同一套做法。
  ///
  /// 可空是为了「还没打开过任何菜单」时不至于崩；本组件会兜底成 `Rect.zero`
  /// （presenter 构造时断言必须有锚点或矩形）。
  final Rect? anchorBounds;

  final List<HyperosAnchorMenuEntry> entries;

  /// 点了某一项：**先把 [show] 置 false**（宿主在这里收起菜单）。
  ///
  /// [onSelected] 不会紧跟着来 —— 等退场动画走完一截才回调，见状态类里的
  /// [_kCollapseBudget]。宿主不该在 [onCollapseRequested] 里同步做动作。
  final VoidCallback? onCollapseRequested;

  final VoidCallback? onDismissRequest;

  /// 菜单收完后回传被点的那个 [HyperosAnchorMenuEntry.value]。
  ///
  /// **已经内置了「等菜单收完」的延迟**，直接在这里做动作（推页面 / 弹对话框 /
  /// 拉起系统分享）即可。不要宿主自己再 `Future.delayed` —— 等多久只有这一份
  /// 口径。
  final ValueChanged<Object>? onSelected;

  /// 面板宽度。**默认就是全软件统一口径**（[os4GlassPopupStandardSizing]，
  /// 200），别为单个菜单私开数字 —— 同一个 App 里菜单宽窄不一是最刺眼的不一致。
  final MiuixGlassPopupSizing sizing;

  /// 弹层悬在 Android 平台视图（WebView）上方时必须开：玻璃采样读不到平台视图
  /// 的纹理，面板会渲染成黑块。改用实底面板。
  final bool opaqueSurface;

  @override
  State<HyperosAnchorMenuPopup> createState() =>
      _HyperosAnchorMenuPopupState();
}

class _HyperosAnchorMenuPopupState extends State<HyperosAnchorMenuPopup> {
  /// 本次展开期间持有的屏级采样源（展开时 acquire，关闭时 release）。
  ///
  /// 与首页菜单同一份口径：只 `holdRecording()`，不 `acquire()`（后者会在整个
  /// 开合动画期间每帧录一张全屏，而这块面板只读采样区、整层图没人读）。
  HyperosGlassBackdropController? _captureHold;

  /// 「菜单视觉收完」的上限：点条目后先收菜单，到点才回调 [HyperosAnchorMenuPopup.onSelected]。
  ///
  /// 为什么要等：本弹层常驻挂在宿主页子树里，「点条目 → 推新页面」发生时本路由
  /// 会被压到新路由下面，Overlay 给被盖住但仍 maintainState 的那层整层关掉
  /// TickerMode，退场动画当场静音、卡在半透明（首页菜单 2026-09-15 真机踩过）。
  ///
  /// 240ms 的口径与首页 `kHomeMenuCollapseBudget` 相同：面板按进度单调收缩，实测
  /// ≈240ms 就收完；上游的 `onDismissFinished` 挂在弹簧收敛容差 0.0015 上，要
  /// ≈670ms 才来，等它等于凭空加半秒空档。
  static const _kCollapseBudget = Duration(milliseconds: 240);

  Timer? _collapseTimer;

  /// 已点中某项、等退场走完再回传值。为真期间再点别项直接忽略。
  bool _awaitingSelection = false;

  void _handleItemPressed(Object value) {
    if (_awaitingSelection) {
      return;
    }
    _awaitingSelection = true;
    widget.onCollapseRequested?.call();
    _collapseTimer?.cancel();
    _collapseTimer = Timer(_kCollapseBudget, () {
      _collapseTimer = null;
      if (!mounted) {
        return;
      }
      _awaitingSelection = false;
      widget.onSelected?.call(value);
    });
  }

  /// 遮罩点击 / 系统返回：放弃这次待执行的选择（用户改主意了）。
  void _handleDismissRequest() {
    _cancelPendingSelection();
    widget.onDismissRequest?.call();
  }

  void _cancelPendingSelection() {
    _collapseTimer?.cancel();
    _collapseTimer = null;
    _awaitingSelection = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCaptureHold();
  }

  @override
  void didUpdateWidget(HyperosAnchorMenuPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.show != widget.show) {
      _syncCaptureHold();
      // 菜单被收起但我们没发起（宿主自己切的，如路由变化）→ 没有待执行的
      // 选择。发起方是我们自己时 [show] 也会变 false，**不能**在这里取消 ——
      // 那正是待执行选择要等的退场。
      if (!widget.show && !_awaitingSelection) {
        _collapseTimer?.cancel();
        _collapseTimer = null;
      }
    }
  }

  @override
  void dispose() {
    // 必须与 [_syncCaptureHold] 取持有的方法配对：这里持有的是
    // `holdRecording()`，归还只能用 `releaseRecording()`。
    _captureHold?.releaseRecording();
    _captureHold = null;
    _collapseTimer?.cancel();
    _collapseTimer = null;
    super.dispose();
  }

  void _syncCaptureHold() {
    final next = widget.show
        ? HyperosGlassBackdropRegistry.resolve(context)
        : null;
    if (identical(next, _captureHold)) {
      return;
    }
    _captureHold?.releaseRecording();
    _captureHold = next;
    next?.holdRecording();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ 显式放开 TickerMode：`Overlay` 会给「被不透明路由盖住、但仍
    // maintainState」的那一层整层加 `TickerMode(enabled: false)`，而本弹层是
    // 常驻挂在页面子树里的 —— 「点条目 → 推新页面」发生时退场动画会被当场
    // 静音、卡在半透明（首页菜单 2026-09-15 真机踩过，timetable_screen.dart
    // 的 `_homeMenuOpen` 那处同样显式放开）。弹层是浮层级的瞬时动画，不该
    // 受宿主页是否在前台影响。
    return TickerMode(
      enabled: true,
      child: HyperosGlassPopupScrollGuard(
        child: MiuixGlassDropdownPopup(
          show: widget.show,
          // 兜底 `Rect.zero`：presenter 构造时断言
          // `motion == dialog || anchor != null || anchorBounds != null`，
          // 传 null 会当场 `_AssertionError`、连页面都进不去。收起态不显示，
          // 兜底值读不到。
          anchorBounds: widget.anchorBounds ?? Rect.zero,
          backdrop:
              HyperosGlassBackdropRegistry.resolve(context)?.backdrop ??
              os4GlassBackdrop,
          sizing: widget.sizing,
          // 面板材质交给全局档位分派（液态 / 柔光 / 高斯 / 实底）——几何与
          // 展开动效仍由上游 presenter 负责，一行不动。悬在平台视图上方时
          // 换成实底注入面（见 [HyperosAnchorMenuPopup.opaqueSurface]）。
          surfaceBuilder: widget.opaqueSurface
              ? hyperosGlassPopupOpaqueSurface
              : hyperosGlassPopupSurface,
          // ⚠️ 这里**不要**传 `maskColor`：`MiuixGlassDropdownPopup` 没这个
          // 参数（只有 `MiuixGlassTransformPopup` 有），传了整个 App 编译不过。
          // 遮罩用上游 presenter 的内建值，与 `HyperosSelect` 的 OS4 路径一致。
          //
          // 上游这里要求非空回调；宿主没给就退化成空实现（弹层仍会自己收起，
          // 宿主只是拿不到「用户点了遮罩 / 按了返回」的通知）。
          onDismissRequest: _handleDismissRequest,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in widget.entries)
                MiuixGlassPopupItem(
                  text: entry.label,
                  icon: entry.icon,
                  enabled: entry.enabled,
                  contentColor: entry.destructive
                      ? HyperosColors.error(context)
                      : null,
                  onPressed: entry.enabled
                      ? () => _handleItemPressed(entry.value)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
