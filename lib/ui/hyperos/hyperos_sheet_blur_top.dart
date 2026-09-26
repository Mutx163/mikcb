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
/// * 衬底取**嵌在磨砂父面上**那一档淡色水洗（[HyperosBlurredHeader
///   .nestedSurfaceTintColor]），不是顶栏那档浓白 —— 面板自己已经是那层奶白，再叠
///   一层浓白会看出接缝；
/// * **没有滚动态、没有监听**：带是常驻的。模糊恒开，静止时带里没有内容可糊，看起来就
///   只是面板顶部一道很淡的水洗（顶端与面板同色），滚动时才有内容化进去。
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
    final band = SizedBox(
      height: widget.headerHeight,
      child: FrostedHeaderBackground(
        // 渐进档 = 设置页顶栏那一档（子页顶栏已锁死为它，见 subpageHeaderBlurStyleOf）。
        blurStyle: HeaderBlurStyle.inspire,
        blurEnabled: useBlur,
        blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
        // 有模糊：淡色水洗压在糊掉的内容上求可读；无模糊（实体面板 / 技术降级 / 平台
        // 不支持）：改用面板自己的不透明色，带就与面板连成一体、看不出接缝。
        tint: useBlur
            ? HyperosBlurredHeader.nestedSurfaceTintColor(
                context,
                withBlur: true,
              )
            : HyperosBlurredHeader.sheetTintColor(context, withBlur: false),
        // 带没画模糊时没有下沿可谈（见 InspireHeaderBlur.bottomOverhang：模糊关掉还
        // 外推会盖住正文第一行）。
        bottomOverhang: useBlur ? widget.fadeExtent : 0,
        child: widget.header,
      ),
    );

    // 滚动才显形：没显形就整条不画（连模糊层一起）。**不能只淡入 header** —— 模糊带
    // 本体是「压住滚上来的内容」的那一层，它留着就等于内容还在从带底下钻出来，那正是
    // 要消掉的现象。
    final reveal = !widget.revealOnScroll || _revealed;

    return Stack(
      // ⚠️ 必须 `expand`：两个子节点**都是**定位的（`Positioned.fill` + `Positioned`），
      // 而 `Stack` 默认按「最大的非定位子节点」定尺寸 —— 那种情况下唯一的非定位尺寸
      // 来源没有了，整块会塌成最小约束（实测材质面板直接塌到 45px，正文拿到 0 高、
      // 两页内容在树上但一屏都画不出来）。`expand` = 铺满来.constraints。
      fit: StackFit.expand,
      children: <Widget>[
        // 正文在带**底下**：满高铺开，顶部让出「带高 + 渐隐区」，于是滚上去的行从
        // 模糊里穿过去，而不是在面板上沿被切一刀。
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(
              top: widget.headerHeight + widget.fadeExtent,
            ),
            child: widget.body,
          ),
        ),
        // 带压在最上（后画 = 更上）：必须挡住从底下滚上来的内容，所以它排在后面。
        //
        // 「滚动才显形」时没显形就换成等高的空盒：位置照样让给正文（静止时第一行就在
        // 那儿，不能被带压住），但不画模糊也不吃点击。刻意**不用 `Opacity`** 淡入 ——
        // 它会把 `BackdropFilter` 与玻璃材质降级成透明（`hyperos_sheet.dart` 记的
        // 同一条纪律）。
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: reveal
              ? band
              : IgnorePointer(
                  // 没显形时既不画也不吃点击：带的位置要让给正文（静止时第一行就在那儿）。
                  child: SizedBox(height: widget.headerHeight),
                ),
        ),
      ],
    );
  }
}
