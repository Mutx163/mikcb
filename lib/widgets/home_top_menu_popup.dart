import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/widgets/home_top_menu.dart';

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
    required this.backdrop,
    required this.anchor,
    required this.anchorContent,
    required this.entries,
    required this.hasAvailableUpdate,
    required this.onDismissRequest,
    required this.onSelected,
  });

  /// 是否展开一级菜单。
  final bool show;

  /// 材质取样的捕获容器，由宿主创建并持有（上游约定：调用方创建并 dispose）。
  final MiuixLayerBackdrop backdrop;

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
  /// 二级面板的锚点：绑在「添加」那一行上（上游 `MiuixGlassAnchor` 用法）。
  final MiuixGlassPopupAnchor _addRowAnchor = MiuixGlassPopupAnchor();

  /// 二级面板的锚定矩形（点开那一刻从 [_addRowAnchor] 取窗口坐标）。
  Rect? _secondaryBounds;
  bool _secondaryOpen = false;

  @override
  void dispose() {
    _addRowAnchor.dispose();
    super.dispose();
  }

  /// 收起二级并关掉一级菜单；点遮罩关闭也走这里。
  void _close() {
    if (_secondaryOpen) {
      setState(() => _secondaryOpen = false);
    }
    widget.onDismissRequest();
  }

  void _closeSecondary() {
    if (_secondaryOpen) {
      setState(() => _secondaryOpen = false);
    }
  }

  void _select(String id) {
    _close();
    widget.onSelected(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = widget.entries;

    return Stack(
      children: [
        MiuixGlassTransformPopup(
          show: widget.show,
          anchor: widget.anchor,
          anchorContent: widget.anchorContent,
          backdrop: widget.backdrop,
          // 宽度：换实现后菜单明显变宽。核对过两边公式——`minWidth` 其实一样
          //（旧实现 `132 + popupExtraLeadingWidth` 恰好 = 上游默认 200），所以
          // 差别出在**上限与行内容**：上游默认 `maxWidth: 288`，而新条目
          //（`MiuixGlassPopupItem` 的文字样式 + 箭头/内边距）本身比旧条目宽，
          // 于是面板被顶到接近上限。这里把上限收到 240（旧实现的实际观感宽度
          // 落在 200~240 这一段），标签都是 4~6 字，不会被截断。
          sizing: const MiuixGlassPopupSizing(maxWidth: 240),
          // 刻意**不用** `stacked`：它的语义是"二级展开时一级面板收缩/变暗"，
          // 收起时要靠包内 `MiuixGlassMotion.secondaryPopup(false)` 弹簧把一级
          // 弹回原位 —— 那条回弹在真机上读起来就是"圈/描边回收很慢"，而这组
          // 弹簧与 `transformMaterial(80ms)+delay(50ms)+threshold(.0015)` 都在包内、
          // **没有对外参数**可调。故保持 stacked=false：二级直接浮出/收起，
          // 一级面板全程不移动，也就没有需要回收的形变。
          //（想要包内那套"一级让位"观感时，把这一行放开即可。）
          // stacked: _secondaryOpen,
          onDismissRequest: _close,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                if (index > 0 &&
                    entries[index].category != entries[index - 1].category)
                  const SizedBox(height: 8),
                _row(entries[index], l10n),
              ],
            ],
          ),
        ),
        if (_secondaryBounds != null)
          MiuixGlassSecondaryPopup(
            show: _secondaryOpen,
            anchorBounds: _secondaryBounds,
            // 二级共享一级菜单的材质（上游 materialAnchor 语义）。
            materialAnchor: widget.anchor,
            backdrop: widget.backdrop,
            onDismissRequest: _closeSecondary,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final child in kAddCourseSubmenu(l10n))
                  MiuixGlassPopupItem(
                    text: child.label,
                    onPressed: () => _select(child.value),
                  ),
              ],
            ),
          ),
      ],
    );
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
              // LTR 展开箭头取 -90（上游约定）。
              arrowRotation: _secondaryOpen ? 0 : -90,
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
        : MiuixGlassPopupItem(
            text: label,
            onPressed: () => _select(entry.id),
          );

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
