import 'package:flutter/material.dart';

import '../../models/header_blur_style.dart';
import 'hyperos_blurred_header.dart';

/// 弹窗顶部的「渐变模糊」带 —— 与设置页顶栏同一个观感，搬进弹窗里用。
///
/// ## 要解决的问题
///
/// 弹窗正文（材质面板那两页、课程操作单、追课选择…）普遍比面板高，只能内部滚动。
/// 滚上去的行在面板上沿被**硬切**一条边，看起来像内容被削掉一块。设置页没这个问题：
/// 顶栏是浮在列表之上的一条玻璃带，列表从它底下穿过，接触处是渐隐的。弹窗原来
/// 没有这条带，于是少了那层「化进去」的收尾。
///
/// ## 做法
///
/// 复用设置页顶栏**同一个**渐变模糊部件（渐进档：自顶边满强度向下，正好在带底衰减到
/// 0），不是另画一层近似效果：
///
/// * 模糊的**下沿画在带盒之外**（[InspireHeaderBlur.bottomOverhang]），所以它能罩住
///   正文的第一行 —— 正文起点比带底低 [fadeExtent]（这截空白既是渐隐区，也是静止时
///   不糊住第一行的余量；子页顶栏用标题与正文之间那截空白给外推封顶，是同一个道理）；
/// * 衬底与模糊同向衰减（顶浓底清），带底恒为透明，交界处不会切出横向硬边；
/// * 模糊开着时**不画衬底**（`transparent`）：遮住滚上来的内容交给模糊本身（顶边
///   sigma 22，那个强度下文字本就不可读）。衬底那条「顶边满浓度突然出现」的突变在设置页
///   看不见（带贴屏幕顶、上面没东西），搬进弹窗后带上边缘落在面板中间，就是一条亮线
///   （2026-09-26 用户报）。模糊关掉时改用面板自己的**不透明**色 —— 那时没有模糊就
///   必须在带底把内容挡住，且该色与面板同色、本就看不出接缝；
/// * 带上边缘用 [bleedTop] 往上盖过**拖动把手**那条，使「顶边满强度」这一步落在**面板
///   自己的上边缘**、被面板裁掉 —— 顶部于是是一整块渐变，而不是「把手 + 一条亮线」。
///   代价是把手会被糊平（4px 高的浅色小条在 sigma 22 下基本消失），所以带子把把手
///   **再画一遍**在自己上面（见 [echoDragHandle]）；
/// * **没有滚动态、没有监听**：带是常驻的。模糊恒开，静止时带里没有内容可糊，滚动时才有
///   内容化进去。
///
/// ## 两种形态
///
/// * **常驻**（默认，[revealOnScroll] 为假）：带一直画着。适合带上有**常驻内容**的场合
///   （分段、标题），那点内容本来就得一直在。
/// * **滚动才显形**（`revealOnScroll: true`）：带**透明**到内容真的滚上来才画。适合带
///   上是「标题」这类**平时就该藏起来**的场合 —— 静止时浮着一条空带或一个标题都是
///   凭空多出来的东西。非静止那条不能靠带自己判断（带拿不到滚动位置），所以由调用方
///   把 [scrollController] 交给本控件，由它用
///   [HyperosCollapsibleScrollListener] 那种判据（`pixels > 0`）翻转。
///
/// ## 用法
///
/// 放在**有确定高度**的位置（`Expanded` 里，或被 `maxHeight` 夹住的地方）—— 正文要
/// 拿到「带底以下」的剩余高度。`headerHeight` 传带内容那个控件的真实高度（分段就是
/// [MiuixTabRowDefaults.tabRowWithContourHeight] 那个常量，别拍脑袋写 45）：
///
/// ```dart
/// Expanded(
///   child: HyperosSheetBlurTop(
///     headerHeight: MiuixTabRowDefaults.tabRowWithContourHeight,
///     header: mySegmented,
///     body: myScrollingBody,
///   ),
/// )
/// ```
///
/// 带高由本控件**自己夹死**（[SizedBox]），正文让位也用同一个数，所以两边不可能对不上
/// —— 唯一要防的是把 `headerHeight` 写小于 header 真实高度（那会把它压扁），写在
/// debug 下 assert 出来。
class HyperosSheetBlurTop extends StatefulWidget {
  const HyperosSheetBlurTop({
    required this.headerHeight,
    required this.header,
    required this.body,
    this.fadeExtent = 20,
    this.revealOnScroll = false,
    this.scrollController,
    this.bleed = 0,
    this.bleedTop = 0,
    this.echoDragHandleHeight = 0,
    super.key,
  });

  /// 带内容（`header`）的高度。带高按它夹死，正文让位也用它。
  final double headerHeight;

  /// 带上的固定内容（分段 / 标题行）。
  final Widget header;

  /// 弹窗正文。从「带底 + [fadeExtent]」起，滚上去时从带**底下**穿过（因此带不吃它
  /// 的点击 —— 带下没有 header 部件的地方照常点得动）。
  final Widget body;

  /// 模糊下沿往下探出带盒多少（= 正文起点比带底低多少）。
  ///
  /// 默认与子页顶栏外推上限 [HyperosBlurredHeader.subpageBandBottomOverhang] 同值
  /// （≈ 一个字高）：用户口径是「最底下模糊的边界要盖过标题底部一个字空间」。
  final double fadeExtent;

  /// 带是否**滚动才显形**（见类注释两种形态）。
  ///
  /// 为真时必须给 [scrollController]（带自己拿不到滚动位置）。
  final bool revealOnScroll;

  /// [revealOnScroll] 为真时必填：正文那个滚动视图的控制器。
  final ScrollController? scrollController;

  /// 模糊带往左右各外扩多少，用来**盖住面板内容的左右内缩**、铺满整个面板宽。
  ///
  /// 为什么要它：面板内容的左右内缩是**外层**加的（上游底部弹窗的 `insideMargin`，
  /// 见 `hyperosMiuixBottomSheetInsideMargin`），不在本控件的盒里。不外扩的话带子
  /// 只在中间一段有模糊、两侧各留一条没糊的边 —— 读起来是「浮在面板里的一个方框」，
  /// 而不是「面板顶部的渐变」（这正是 2026-09-26 用户报的现象）。
  ///
  /// 传**外层那个内缩的真实值**，别拍脑袋。带上那个控件会按同一个数横向内缩回去，
  /// 所以控件仍与正文对齐，只有模糊层是满宽的。
  final double bleed;

  /// 模糊带往上盖过面板顶部那一截 chrome 多少（内容上边缘 → 面板上边缘）。
  ///
  /// 为什么要它：渐进档是「顶边满强度」，而带子上边缘若停在面板**中间**（把手下面），
  /// 这条突变就落在面板中间 → 一条亮线（2026-09-26 用户报「顶部不够整体」）。往上盖过
  /// 那一整截之后，突变被面板自己的上边缘裁掉，顶部成一整块渐变。
  ///
  /// 传**那一整截**的真实高度，不是只传把手条：底部弹窗在把手与内容之间还插了一截
  /// 空占位（本仓是 `hyperosMiuixBottomSheetTopChromeHeight` = 42 = 把手条 24 + 空占位
  /// 18，见该常量注释），只传 24 会让带子上移不到位 → 替身把手与上游那颗差 18px →
  /// **两根杆子**（同一个问题的第二个症状，2026-09-26 用户报）。
  final double bleedTop;

  /// 在 [bleedTop] 那一截里，**紧贴面板上边缘**的那段有多高 —— 拖动把手就在这里，
  /// 本控件在这一段里画一颗**替身**。传 0 = 不画替身。
  ///
  /// 这颗替身是给 [bleedTop] 盖住把手那个场景准备的 ——
  /// 把手是 45×4、alpha 0.2 的浅色小条，模糊强度 22 之下会被糊得基本消失，而它是这个
  /// 弹窗**唯一**的拖动提示（上游只让把手可拖、不能整面板拖），糊没了等于删了一条
  /// 可用性提示。
  ///
  /// 画它时**必须**同时给承载壳传 `coverDragHandle: true`（见 [showMiuixBottomSheet]）把
  /// 上游那颗画成透明，否则两颗都在屏幕上 = **两根杆子**（2026-09-26 用户报）。可见的
  /// 只有这一颗；上游那颗 24px 的条仍在原位接拖动手势（只是透明），所以「看到的」与
  /// 「能拖的」仍是同一块区域。
  ///
  /// 这颗替身**包在 `IgnorePointer` 里**：点不到、也不吃拖动，全交给下面上游那颗。代价
  /// 是丢了上游按压时「变宽 + 加深」那点反馈（复制它需要接管上游的私有控制器，而替身
  /// 本来就不该参与命中）。
  final double echoDragHandleHeight;

  /// 正文（**滚动内容本身**）要自己留的顶部让位：把手让位 + 带高 + 渐隐区。
  ///
  /// 必须加在滚动内容的 `padding` 上，不能加在本控件的 body 外面 —— 加在外面会把
  /// 滚动视口整体下移，内容在带底就被裁掉、永远进不了模糊区（见 `_buildBanded` 里
  /// 那条注释）。调用方这样用：
  ///
  /// ```dart
  /// HyperosSheetBlurTop(
  ///   headerHeight: 45,
  ///   bleedTop: hyperosMiuixBottomSheetDragHandleStripHeight,
  ///   header: myHeader,
  ///   body: SingleChildScrollView(
  ///     // ↑ 让位在这里，不是在外面
  ///     padding: EdgeInsets.only(
  ///       top: HyperosSheetBlurTop.topInsetFor(
  ///         headerHeight: 45,
  ///         bleedTop: hyperosMiuixBottomSheetDragHandleStripHeight,
  ///       ),
  ///     ),
  ///     child: content,
  ///   ),
  /// )
  /// ```
  static double topInsetFor({
    required double headerHeight,
    double bleedTop = 0,
    double fadeExtent = 20,
  }) =>
      bleedTop + headerHeight + fadeExtent;

  @override
  State<HyperosSheetBlurTop> createState() => _HyperosSheetBlurTopState();
}

class _HyperosSheetBlurTopState extends State<HyperosSheetBlurTop> {
  /// 带是否已显形（仅 [HyperosSheetBlurTop.revealOnScroll] 用）。
  bool _revealed = false;

  ScrollController? _observed;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(HyperosSheetBlurTop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController ||
        oldWidget.revealOnScroll != widget.revealOnScroll) {
      _detach();
      _attach();
    }
  }

  void _attach() {
    if (!widget.revealOnScroll) {
      return;
    }
    assert(
      widget.scrollController != null,
      'revealOnScroll 需要正文那个滚动视图的 ScrollController —— 带在正文之上，'
      '拿不到滚动位置',
    );
    final controller = widget.scrollController;
    _observed = controller;
    controller?.addListener(_onScroll);
    // 首帧可能已经滚了一段（弹窗带着上次的滚动位置重建），补判一次。
    _onScroll();
  }

  void _detach() {
    _observed?.removeListener(_onScroll);
    _observed = null;
  }

  void _onScroll() {
    final controller = _observed;
    if (controller == null || !controller.hasClients) {
      return;
    }
    // 判据只要「内容有没有离开原位」：顶部还贴着第一行时（pixels <= 0，含回弹的负值）
    // 带保持透明，滚上去一像素就整条切进来。
    final revealed = controller.position.pixels > 0;
    if (revealed != _revealed) {
      setState(() => _revealed = revealed);
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.headerHeight > 0,
      'headerHeight 必须是带内容的真实高度，带高按它夹死',
    );
    // 高度契约在 LayoutBuilder 里查得到真凭据（约束而不是猜），报错也说得出是哪一层
    // 没夹住 —— 这是最容易被后来者踩的一条（放进 Column 的非 Expanded 位置就中招）。
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedHeight,
          'HyperosSheetBlurTop 要放在有确定高度的位置（Expanded 或被 maxHeight 夹住）'
          '—— 正文要拿「带底以下」的剩余高度，高度不定就无从谈起；'
          '放进 Column 的非 Expanded 位置就会踩到这条',
        );
        return _buildBanded(context);
      },
    );
  }

  Widget _buildBanded(BuildContext context) {
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    // 带盒 = 把手那条 + 带上内容。带子整体**上移** [HyperosSheetBlurTop.bleedTop]
    // 盖过把手，于是「顶边满强度」那一步落在面板自己的上边缘、被面板裁掉。
    final bandBoxHeight = widget.bleedTop + widget.headerHeight;
    final band = SizedBox(
      height: bandBoxHeight,
      child: FrostedHeaderBackground(
        // 渐进档 = 设置页顶栏那一档（子页顶栏已锁死为它，见 subpageHeaderBlurStyleOf）。
        blurStyle: HeaderBlurStyle.inspire,
        blurEnabled: useBlur,
        blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
        // 衬底：模糊开着时**不画**（`transparent`），遮住滚上来的内容交给模糊本身 ——
        // 渐进档顶边 sigma 22，文字在那个强度下本就不可读。
        //
        // 为什么非得去掉（2026-09-26 用户报「切换按钮顶部一条明显的横线」）：这条衬底
        // 在带顶是**满浓度突然出现**（浅色下是白 @ 45%~72%，见
        // `nestedSurfaceTintColor`）。设置页那条带贴在**屏幕最顶**，上面没有东西，
        // 「从无到有」的突变看不见；搬进弹窗后带上边缘落在**面板中间**（把手下面 24px），
        // 这个突变就成了一条亮线。模糊那边同样是顶边满强度，但糊的是均匀背景时几乎
        // 看不出突变 —— 看得见的是这条白衬底。
        //
        // 带上那个控件（分段）自带不透明轨道，不靠这条衬底撑可读性。
        //
        // 模糊关掉时（实体面板 / 技术降级 / 平台不支持）仍用面板自己的**不透明**色 ——
        // 那时带子与面板同色、看不出接缝，而且没有模糊就必须在带底把内容挡住。
        tint: useBlur
            ? Colors.transparent
            : HyperosBlurredHeader.sheetTintColor(context, withBlur: false),
        // 带没画模糊时没有下沿可谈（见 InspireHeaderBlur.bottomOverhang：模糊关掉还
        // 外推会盖住正文第一行）。
        bottomOverhang: useBlur ? widget.fadeExtent : 0,
        // 模糊层与衬底都是 `Positioned.fill`（铺满整条带 = 满宽），而带上那个控件
        // 要**跟正文对齐** —— 带满宽、控件不跟着变宽，否则控件会比底下正文宽出去
        // [bleed]×2，两边对不齐。所以横向让位加在这里，不加在带盒上。
        //
        // 纵向同理：控件贴在带盒**底部**（`Alignment.bottomCenter`），上面那截
        // [bleedTop] 空着当把手区 —— 控件因此仍在把手下面那个位置，不会往上爬。
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.bleed),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: widget.headerHeight,
              child: widget.header,
            ),
          ),
        ),
      ),
    );

    // 滚动才显形：没显形就整条不画（连模糊层一起）。**不能只淡入 header** —— 模糊带
    // 本体是「压住滚上来的内容」的那一层，它留着就等于内容还在从带底下钻出来，那正是
    // 要消掉的现象。
    final reveal = !widget.revealOnScroll || _revealed;

    return Stack(
      // ⚠️ **不能** `expand`：那会让 Stack 直接取 `constraints.biggest` = 高度上限，
      // 于是「内容不满一屏的弹窗」被硬撑到上限（实测课程弹窗从按内容收缩变成恒 80%
      // 屏高，面板顶边被推到屏幕 20% 处，模糊带看着像在弹窗中段）。
      //
      // 正确形状是**正文非定位**（它决定 Stack 尺寸，按内容收缩、上限由外层
      // `ConstrainedBox(maxHeight)` 封；`fit` 保持默认 `loose`，别写 `expand`）+ **带
      // 定位**（`RenderStack` 一律把定位子节点画在非定位子节点**之上**，不必靠 child
      // 顺序）。这样「内容短 → 面板短、带贴着面板顶边」，「内容长 → 顶到上限」。
      alignment: Alignment.topLeft,
      // 带要往左右**外扩** `bleed` 才能满宽（见 [bleed]），所以不能裁。
      clipBehavior: Clip.none,
      children: <Widget>[
        // 正文**满高铺开**（不套顶部 padding）—— 让位必须由调用方加在**滚动内容里面**
        // （[topInsetFor]），不能在这里加。
        //
        // ⚠️ 这里是 2026-09-26 修掉的一个真 bug：让位加在 body **外面**时，滚动视口
        // 被整体下移，于是内容在**带底就被裁掉**、从来没进过模糊区 —— 带子一直在糊
        // 「面板自己的均匀玻璃」，糊了等于没糊，只剩一条满浓度的白衬底在带顶突兀出现
        // （用户报「切换按钮顶部一条明显的横线」）。让位进了滚动内容之后，内容才会
        // 真的从带**底下**穿过去被糊掉。
        //
        // `minHeight` 只保「正文至少和带一样高」（否则带会比正文还长、糊到正文外面），
        // 不再参与内容的位置。
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: widget.bleedTop + widget.headerHeight + widget.fadeExtent,
          ),
          child: widget.body,
        ),
        // 带压在最上（定位子节点恒在非定位之上）：必须挡住从底下滚上来的内容。
        //
        // `left/right: -bleed` 是**满宽**的关键：面板内容的左右内缩是**外层**加的
        // （上游底部弹窗的 `insideMargin`，16），不在本控件的盒里 —— 不外扩的话带子
        // 就只在中间一段有模糊，两侧各留一条没糊的边，读起来是「浮在面板里的一个方框」
        // 而不是「面板顶部的渐变」。
        //
        // 「滚动才显形」时没显形就换成等高的空盒：位置照样让给正文（静止时第一行就在
        // 那儿），但不画模糊也不吃点击。刻意**不用 `Opacity`** 淡入 —— 它会把
        // `BackdropFilter` 与玻璃材质降级成透明（`hyperos_sheet.dart` 记的同一条纪律）。
        Positioned(
          top: -widget.bleedTop,
          left: -widget.bleed,
          right: -widget.bleed,
          child: reveal
              ? band
              : IgnorePointer(
                  // 没显形时既不画也不吃点击：带的位置要让给正文（静止时第一行就在那儿）。
                  child: SizedBox(height: bandBoxHeight),
                ),
        ),
        // 把手**替身**画在带上面（不参与命中，拖动仍由它下面上游那颗接手；那颗已被承载壳
        // 画成透明，见 `showMiuixBottomSheet` 的 `coverDragHandle`，所以屏幕上只有这一颗）。
        //
        // 位置是 `[top: -bleedTop]`（面板上边缘）起、往下 [echoDragHandleHeight] 那一段 ——
        // 把手就在紧贴面板上边缘的那段里（底下还有一截空占位，见 [bleedTop]）。
        if (reveal && widget.echoDragHandleHeight > 0)
          Positioned(
            top: -widget.bleedTop,
            left: 0,
            right: 0,
            height: widget.echoDragHandleHeight,
            child: const IgnorePointer(child: _SheetDragHandleEcho()),
          ),
      ],
    );
  }
}

/// 弹窗拖动把手的**替身**：上游那颗被模糊带盖住、糊平了，这里照它的样子重画一颗。
///
/// 尺寸 / 圆角 / 透明度照抄上游 `MiuixWindowBottomSheet._dragHandle`（一条
/// `SizedBox(height: 24)` 里居中的 45×4、radius 2 胶囊；上游把持手色做成
/// `dragHandleColor` + 0.2 alpha，本仓承载壳传的是 `colorScheme.onSurfaceVariant`，
/// 这里必须跟着用同一个色，否则深色模式下会偏亮）。**刻意不复制按压动画**（变宽 +
/// 加深）：那需要接管上游的私有控制器，而重画这颗本来就不该参与命中
/// （`IgnorePointer`）—— 拖动手势与按压反馈都仍由它下面上游那颗负责。
class _SheetDragHandleEcho extends StatelessWidget {
  const _SheetDragHandleEcho();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 45,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
