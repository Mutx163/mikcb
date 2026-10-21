import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../l10n/app_localizations.dart';
import '../ui/hyperos/hyperos.dart';
import '../ui/hyperos/hyperos_motion.dart';
import 'more_features_screen.dart';

/// 宿主请求收起搜索浮层的句柄。
///
/// 为什么需要它：返回键与左上角返回键的拦截挂在**宿主页**（见
/// `more_features_screen.dart` 的 `PopScope`），但退场动画归浮层自己管。
/// 宿主拿到这个句柄就能「请求收起」，浮层跑完动画再回调 `onDismissed` 交还
/// 宿主摘除 —— 职责不串味：谁说「收」，谁执行「收」，谁负责「摘」。
class MoreFeaturesSearchController {
  VoidCallback? _dismiss;

  /// 请求收起（跑退场动画）。浮层没挂载时是无操作。
  void dismiss() => _dismiss?.call();

  bool get isAttached => _dismiss != null;

  void _attach(VoidCallback dismiss) => _dismiss = dismiss;

  void _detach() => _dismiss = null;
}

/// 「全部功能」页的**全屏搜索层**（官方示例的移动端形态）。
///
/// ## 为什么是浮层
///
/// 官方 `MiuixSearchBar` 组件本身只负责三件事：胶囊输入框、右侧「取消」、下方
/// `content` 槽。它**不管**「搜索框跑到页面顶部」和「把页面其它内容清掉」——
/// 那两件事是使用方的版面决定，不是组件的职责。
///
/// 官方示例 App（`flutter_miuix/example/lib/main.dart`）给的移动端答案就是本
/// 文件这套：`OverlayEntry` 铺一层全屏浮层，搜索框**从它原来的位置**连续滑到
/// 状态栏下方，页面底色淡入把原内容整片盖住，下方只剩结果列表。桌面端（宽屏）
/// 才用 `MiuixSearchBar` 的页内展开形态。
///
/// 这一页走过三种做法，结论记在这里：
///
/// 1. **推独立搜索页**（`ac0f7ffd` 之前）：返回键死锁，且用户丢掉「还在这页」
///    的空间感。已否决。
/// 2. **页内展开**（`8f775bc7`）：胶囊原地变成输入框、右侧滑出「取消」，但页面
///    其它内容原封不动留在下面。用户要的是「搜索框上去、别的内容清掉、下面只
///    留结果」——页内展开做不到，因为原列表必须整片让位给结果区。
/// 3. **全屏浮层（本文件）**：原页面保持原状（只是被淡入的底色盖住），搜索框
///    从原位置滑上去、退场滑回原位。没有第二条路由，也就没有「返回该退哪一层」
///    的歧义。
///
/// ## 两条硬约束（都踩过）
///
/// * **本层不许放 `PopScope`**。`PopScope` 靠 `ModalRoute.of(context)` 找所属
///   路由去登记拦截器，而本浮层是插在 Overlay 里的 entry —— Overlay 在所有
///   路由之上，浮层子树里没有 `ModalRoute` 祖先，`ModalRoute.of` 返回 null，
///   登记直接落空。真机表现：「按返回键，底下页面退了、浮层还留在屏幕上」。
///   拦截器因此挂在宿主页（它在路由里），本层只提供
///   [MoreFeaturesSearchController] 让宿主请求收起。
/// * **生命周期归宿主**。`OverlayEntry.remove()` 只能用它自己的引用，浮层内部的
///   `context` 拿不到那个引用（Flutter 没公开「我在哪个 entry 里」的查询）。
///   所以宿主持有 entry，两条退场路径都回调给宿主：`onDismissed`（动画归零后
///   摘）与 `onOpenEntry`（点了结果，立刻摘再跳页）。
class MoreFeaturesSearchOverlay extends StatefulWidget {
  const MoreFeaturesSearchOverlay({
    super.key,
    required this.anchorRect,
    required this.groups,
    required this.controller,
    required this.onDismissed,
    required this.onOpenEntry,
  });

  /// 折叠态搜索胶囊在**屏幕坐标**里的矩形：浮层用它做「从原位滑到顶部」的起点
  /// 和左右内边距的起点。为 null 时退回「顶部安全区下方、左右 16」直接开始
  /// （少一段滑动行程，但不会跳）。
  final Rect? anchorRect;

  /// 全量分组（搜索的数据源，不是筛选结果——筛选在浮层内做）。
  final List<MoreFeatureGroup> groups;

  /// 宿主用来请求收起的句柄。
  final MoreFeaturesSearchController controller;

  /// 退场动画结束、可以摘掉本浮层了。
  final VoidCallback onDismissed;

  /// 点了结果：宿主摘掉浮层，再用**自己的 context**（仍有效）打开那一页。
  final ValueChanged<MoreFeatureItem> onOpenEntry;

  @override
  State<MoreFeaturesSearchOverlay> createState() =>
      _MoreFeaturesSearchOverlayState();
}

class _MoreFeaturesSearchOverlayState extends State<MoreFeaturesSearchOverlay>
    with SingleTickerProviderStateMixin {
  /// 进场 / 退场共用一条控制器：0 = 收起（浮层不可见），1 = 完全展开。
  /// 走 [HyperosMotionPlatform.bindController]，跟随「页面转场速度」设置
  /// （长命控制器须登记，否则用户中途改速度后要杀进程才生效）。
  late final AnimationController _anim = HyperosMotionPlatform.bindController(
    AnimationController(vsync: this),
    _kBaseMs,
  );

  static const int _kBaseMs = 300;

  /// 搜索框离状态栏的呼吸间距。
  static const double _kTopBreath = 8;

  /// 与页面列表同一口径的左右内边距（`HyperosMiuixSpec.listPadding` 左侧 16）。
  static const double _kSidePadding = 16;

  final FocusNode _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.controller._attach(_dismiss);
    _anim.addStatusListener(_onAnimStatus);
    _anim.forward();
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) {
      // 交还宿主摘除：本层自己删不掉承载自己的那个 entry。
      widget.onDismissed();
    }
  }

  /// 收浮层：先收键盘（别让键盘比浮层活得久），再倒放动画。
  /// 动画归零后由 [_onAnimStatus] 交还宿主摘除。
  void _dismiss() {
    if (!mounted) {
      return;
    }
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    if (_anim.status == AnimationStatus.dismissed) {
      // 连点两下「取消」：已经在收，直接让宿主摘，不空转。
      widget.onDismissed();
      return;
    }
    _anim.reverse();
  }

  @override
  void dispose() {
    widget.controller._detach();
    _anim.removeStatusListener(_onAnimStatus);
    _anim.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pageBackground = HyperosColors.scaffoldBackground(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final anchor = widget.anchorRect;
    // 起点 y：胶囊离状态栏下方那个位置的屏幕 y。两个例外都退回「顶部直接
    // 开始」——① 拿不到矩形；② 胶囊被列表滚出了顶栏（top 小于安全区），
    // 此时从它那个位置起飞会先往下跳一段，很难看。
    final rawStartY = anchor?.top ?? (topInset + _kTopBreath);
    final startY = rawStartY < topInset ? topInset + _kTopBreath : rawStartY;
    final startSide = anchor == null
        ? _kSidePadding
        : anchor.left.clamp(0.0, _kSidePadding);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_anim.value.clamp(0.0, 1.0));
        // 搜索框从原位置连续滑到状态栏下方：两端都是屏幕坐标，不会跳。
        final contentTop = startY + (topInset + _kTopBreath - startY) * t;
        // 底色比滑动先到位一点，尽早盖住底层页面，避免两页文字叠着可读。
        final fade = (t * 1.35).clamp(0.0, 1.0);
        // 左右内边距从胶囊的真实左边界收到 16，终点与页面列表左右对齐
        // （用户点名过「搜索框左右比内容卡窄一圈」）。
        final horizontal = startSide + (_kSidePadding - startSide) * t;

        final visible = filterMoreFeatureGroups(widget.groups, _query, l10n);

        return Stack(
          children: [
            // 底色：淡入 + 吃掉点击，浮层外的空白不许透传到底层页面。
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: ColoredBox(
                  color: pageBackground.withValues(alpha: fade),
                ),
              ),
            ),
            Positioned(
              top: contentTop,
              left: 0,
              right: 0,
              bottom: 0,
              // TextField 需要 Material 祖先；底色由上方 ColoredBox 提供，
              // 这层不再上色。
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontal),
                      child: _buildBar(l10n, fade),
                    ),
                    // 结果区与页面列表同一套分区样式：展开/收起时版式不跳。
                    Expanded(
                      child: Opacity(
                        opacity: fade,
                        child: IgnorePointer(
                          // 动画没落定前不接点击：否则会误点到正在飞行的行。
                          ignoring: fade < 0.9,
                          child: _buildResults(l10n, visible),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 输入框 + 右侧「取消」。这里是**唯一真正持有焦点**的输入框：
  /// 页面上的胶囊折叠态被 `IgnorePointer` 屏蔽，不会抢焦点、不会弹键盘。
  Widget _buildBar(AppLocalizations l10n, double fade) {
    return Row(
      children: [
        Expanded(
          child: MiuixInputField(
            query: _query,
            onQueryChange: (value) => setState(() => _query = value),
            onSearch: (_) {},
            expanded: true,
            onExpandedChange: (_) {},
            focusNode: _focusNode,
            label: l10n.homeMenuMoreSearchHint,
          ),
        ),
        // 「取消」随展开宽度渐入（官方示例同一形态：ClipRect + Align widthFactor）。
        ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: _anim.value.clamp(0.0, 1.0),
            child: Opacity(
              opacity: fade,
              child: GestureDetector(
                onTap: _dismiss,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    l10n.cancelAction,
                    style: HyperosTypography.listDetail(
                      context,
                    ).copyWith(color: MiuixTheme.of(context).colors.primary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults(AppLocalizations l10n, List<MoreFeatureGroup> visible) {
    if (visible.isEmpty) {
      return SingleChildScrollView(
        child: HyperosEmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.homeMenuMoreSearchEmptyTitle,
          subtitle: l10n.homeMenuMoreSearchEmptyHint,
        ),
      );
    }
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return ListView(
      // 键盘弹起时最后一行要能滚到键盘之上。
      padding: EdgeInsets.fromLTRB(
        _kSidePadding,
        12,
        _kSidePadding,
        24 + keyboard,
      ),
      children: [
        for (final group in visible) ...[
          const HyperosSectionGap(),
          HyperosSettingsBlock(
            title: group.title,
            child: HyperosListGroup(
              children: [
                for (final item in group.items)
                  _OverlayResultRow(
                    item: item,
                    onTap: () => widget.onOpenEntry(item),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 浮层里的一行结果。跳页由宿主执行：本行只把「点了哪一条」交出去。
class _OverlayResultRow extends StatelessWidget {
  const _OverlayResultRow({required this.item, required this.onTap});

  final MoreFeatureItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HyperosListTile(
      icon: item.entry.icon,
      title: item.entry.title(AppLocalizations.of(context)!),
      subtitle: item.subtitle,
      onTap: onTap,
    );
  }
}
