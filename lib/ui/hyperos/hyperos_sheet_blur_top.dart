import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/header_blur_style.dart';
import 'hyperos_blurred_header.dart';
import 'miuix_bottom_sheet.dart';

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
/// * 带上边缘只往上盖面板顶部那截**空占位**（[bleedTop]），**不碰把手条**。盖空占位是为了
///   收掉「把手与带之间那段空档」（用户报「拉杆区看起来有三个拉杆区那么高」）；盖把手条会
///   把它那颗唯一的拖动提示糊平，补画替身又变两根杆子 —— 同一处返工三次都是这条边界；
/// * **没有滚动态、没有监听**（常驻形态）：带一直画着。静止时带里没有内容可糊，滚动时才有
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
/// ## 什么时候**不该**用（2026-09-27 用户报出来的账）
///
/// **弹窗没有顶部标题行，就不要套本控件。** 面板上沿往下本来就有 28px 死区（上游把手条 24 +
/// 空占位 18，减去把手小条只占的 10~14），任何弹窗都有、拆不掉；而正文要让出「化开区」才能
/// 保住第一行可读，于是：
///
/// ```
/// 顶部空档 = 28（上游死区） + 化开区长度
/// ```
///
/// * **带里有东西**（材质面板的胶囊行）：那截高度被内容撑着，看着不空 —— 套上划算。
/// * **带里是空的**：整截都是凭空多出来的空档。一段看得见的化开至少 16 → 顶部空档 44，比
///   不套还多 16，换来的只是滚到顶时 16px 的渐隐。**不值**。
///
/// 课程操作单（首页点课卡那个）就是这样：它第一块就是课程卡，没有标题行，2026-09-27 把带子
/// 拆了，顶部从 50 回到 28（拆不掉的死区）。滚到顶时内容在面板上沿硬切一刀 —— 而这正是所有
/// 「无标题行」弹窗本来的样子。
///
/// ## 用法
///
/// 放在**有确定高度**的位置（`Expanded` 里，或被 `maxHeight` 夹住的地方）—— 正文要
/// 拿到「带底以下」的剩余高度。`headerHeight` 传带内容那个控件的真实高度，别拍脑袋写数：
///
/// ```dart
/// Expanded(
///   child: HyperosSheetBlurTop(
///     headerHeight: myHeaderHeight, // 例如折叠顶栏那一行的高度
///     header: myHeader,
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
    super.key,
  });

  /// 让开面板**两个上角**的横向让位区（逻辑 px）= 面板上角的圆角半径。
  ///
  /// ## 第六版定稿（2026-09-28）：内缩只缩模糊 + 渐隐接活 + 白纱满宽 + 竖直顶浓底清
  ///
  /// 本控件的带子**从面板上沿起**，带子的模糊材料矩形原本满宽铺到面板两边，两个上角
  /// 的圆弧正压在矩形的两个**方角**上。三件事同时成立才不出问题（缺一件都会复现
  /// 前面某一次的返工，完整版本表见
  /// `.agents/notes/implemented/bug-fix/2026-09-28-sheet-top-band-corner-ramp.md`）：
  ///
  /// 1. **模糊层矩形左右各内缩本值**（= 半径 28，与圆弧相切）：圆角区域里没有模糊
  ///    材料 —— 材料不再压轮廓的方角，着色器取样范围也整体落在面板内，「模糊跨弧
  ///    把外面的东西拖进来」（用户：「渐变模糊跑到了圆角外面」）从机制上断掉。
  /// 2. **横向渐隐的爬升宽度取同一个数**（`InspireHeaderBlur.sideTaperFractionFor`
  ///    的 `taperIn = cornerRampIn`）：内缩边强度从 0 爬进场，不切竖直接缝，弧线
  ///    相切点上强度也是 0。第三版内缩开着、渐隐却是死代码（参数没接进
  ///    `distribution`），硬缝 + 相切角满强度就是那版真机失败的账。
  /// 3. **白纱（衬底）不内缩**：满宽铺，方角交面板 `ClipRRect` 裁，两端一分料不少
  ///    —— 「每端 56px 无料、深色壁纸读成透明」缩的是白纱，不是模糊。
  ///
  /// ## 竖直曲线不许动：顶浓底清 = 设置页顶栏同一份观感
  ///
  /// 上沿满强度（滚上去的行在那儿化开，09-26 定；09-27「拉杆底下不能没有模糊」那条
  /// 的正解），向下一路衰减到带底 0。曾给上沿加过一道「0 → 满」的竖直爬升
  /// （`topRampIn`，治「角被读成平铺」），约束断线修通、真的生效之后，真机复验是
  /// **三段式**（上面透明、中间浓、下面透明）+ 拉杆区透明 —— 用户 2026-09-28 打回：
  /// 「渐变模糊应该是顶部浓，下面透明」。该参数已删，圆角的账全部归上面三条。
  static const double cornerRampIn = hyperosMiuixBottomSheetCornerRadius;

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

  /// 带子往上盖住面板顶部那截**空占位**多少（内容上边缘 → 面板上边缘）。
  ///
  /// 底部弹窗在把手条与内容之间还插了一截空占位（上游 `_titleRow` 在没有标题时照样插的
  /// `SizedBox(height: 18)`，见 `hyperosMiuixBottomSheetEmptyTitleRowHeight`），它把把手
  /// 和内容隔开 42px，于是带子与把手之间会空出一大段（2026-09-27 用户报「拉杆区看起来
  /// 有三个拉杆区那么高，拉杆只在最顶上」）。盖住这截空占位后那段空档缩到 10px。
  ///
  /// 盖它安全（里面什么都没有，糊一片空白等于没糊）；**绝不能往上盖把手条** —— 里面那颗
  /// 浅色小条会被糊平，而它是这个弹窗唯一的拖动提示，补画替身又变成两根杆子。同一处先后
  /// 返工三次就是这个原因，所以这个参数只允许填「空占位」那截的高度。
  final double bleedTop;

  /// 正文（**滚动内容本身**）要自己留的顶部让位：带高 + 渐隐区 − [bleedTop]。
  ///
  /// ⚠️ **`bleedTop` 是减项**：带子整体**往上移**了那么多，带盒的**下沿并没有跟着下移**
  /// （盒高仍是 [headerHeight]，只是位置高了），所以正文要让位的量不因上移而变大、反而变小。
  /// 2026-09-27 我在这里误把它当加项，正文多让了 18px，控件与内容之间空出一大片
  /// （用户报「切换按钮和下面的内容区域之间间隔那么大空白」）。
  ///
  /// 必须加在滚动内容的 `padding` 上，不能加在本控件的 body 外面 —— 加在外面会把
  /// 滚动视口整体下移，内容在带底就被裁掉、永远进不了模糊区（见 `_buildBanded` 里
  /// 那条注释）。调用方这样用：
  ///
  /// ```dart
  /// HyperosSheetBlurTop(
  ///   headerHeight: 40,
  ///   bleedTop: hyperosMiuixBottomSheetEmptyTitleRowHeight,
  ///   header: myHeader,
  ///   body: SingleChildScrollView(
  ///     // ↑ 让位在这里，不是在外面
  ///     padding: EdgeInsets.only(
  ///       top: HyperosSheetBlurTop.topInsetFor(
  ///         headerHeight: 40,
  ///         bleedTop: hyperosMiuixBottomSheetEmptyTitleRowHeight,
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
      math.max(0, headerHeight + fadeExtent - bleedTop);

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
      'revealOnScroll needs the body scroll view\'s ScrollController — the '
      'band sits above the body and cannot track scroll position itself',
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
      'headerHeight must be the real height of the band content; the band '
      'height is clamped to it',
    );
    // 高度契约在 LayoutBuilder 里查得到真凭据（约束而不是猜），报错也说得出是哪一层
    // 没夹住 —— 这是最容易被后来者踩的一条（放进 Column 的非 Expanded 位置就中招）。
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedHeight,
          'HyperosSheetBlurTop must be placed where its height is bounded '
          '(Expanded, or clamped by maxHeight) — the body derives the remaining '
          'height below the band bottom, and an unbounded height leaves nothing '
          'to compute. A non-Expanded slot inside a Column hits this assert',
        );
        return _buildBanded(context);
      },
    );
  }

  Widget _buildBanded(BuildContext context) {
    final useBlur = HyperosBlurredHeader.backdropBlurEnabled(context);
    // 带盒 = 盖住的那截空占位（[bleedTop]）+ 带上内容那一段。带子整体**上移**
    // [bleedTop]，把把手与带之间那段空档收掉。
    //
    // ⚠️ [bleedTop] **只允许填「空占位」那截**（上游无标题时插的 18），绝不能填把手条那
    // 24px：那一截里有那颗 45×4 的浅色把手，被糊平就没了唯一的拖动提示；补画替身则变成
    // 两根杆子。同一处先后返工三次（黑底黑字 / 纯色 / 两根杆子）都是这个边界没守住。
    //
    // 另外那一截背后**没有内容**（底部弹窗只允许拖把手，而把手是内容区**上方**的兄弟
    // 节点、内容画在它前面，滚动视口到不了那儿），所以别指望在那里糊到内容 —— 糊空白等于
    // 没糊，衬底也不画（见 `_mainBand`），静止时与面板看不出变化。
    //
    // ⚠️ 带盒高度就是 [headerHeight]，**不要**为了上移而把它加高 [bleedTop]：盒子往上
    // 移、控件占满整盒，则带盒**下沿不动**（内容-y 仍是 headerHeight），控件底下不会多出
    // 一截空带。2026-09-27 我把盒高写成 `bleedTop + headerHeight`、控件又贴在盒顶，于是
    // 控件底下凭空空出 18px。
    final bandBoxHeight = widget.headerHeight;
    final band = _mainBand(context, useBlur: useBlur);
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
      children: _stackChildren(band, bandBoxHeight),
    );
  }

  /// 带子的衬底。
  ///
  /// * 模糊关掉 → 面板自己的**不透明**色。没有模糊就必须在带底把滚上来的内容挡住，而该色
  ///   与面板同色、本就看不出接缝。
  /// * 模糊开着 → 共享的那份磨砂衬底（`HyperosBlurredHeader.sheetTintColor`），**明暗
  ///   都给**。这与设置页顶栏是**同一份材料**（用户口径 2026-09-27：「最底下的模糊不是我
  ///   原本设置页面那种柔和的过渡了」—— 要的就是设置页那一份）。
  ///
  /// ## 为什么必须有（2026-09-27 一次返工）
  ///
  /// 带子覆盖的那一段（带上边缘 → 带底 + 渐隐区）**一行内容都没有**：正文第一行在带底之下
  /// 才开始，那一截是滚动视口里的空白。于是：
  ///
  /// * 只有模糊、没有衬底 → 模糊糊的是一片**均匀的面板玻璃**，等于没糊（用户报「拉杆区域
  ///   的模糊效果不显示」）；浅色下衬底全透明时那一截直接读成**一块透明片**（同一个投诉）。
  /// * 渐隐区里同样没有内容可糊 → 从「什么都没有」到「下面第一行清晰内容」是**硬过渡**，
  ///   底边能看出一条线（用户报「渐变模糊底部变成强硬模糊…能看出来一条线」）。
  ///
  /// 有衬底之后这三件事一起消掉：渐隐区成了一条真正在渐隐的磨砂带，底边自然柔和。
  ///
  /// ## 为什么不再怕「带顶一条亮线」（2026-09-26 那笔的教训）
  ///
  /// 当年去掉衬底是因为它在面板**中间**满浓度突然出现（带子上边缘落在把手下面 24px），
  /// 那条突变在面板中间切出一条亮线。现在带上边缘就在**面板顶边**，紧挨玻璃自己的边光，
  /// 而且衬底是向下渐隐到 0 的（`InspireHeaderBlur` 的渐进档），面板中间不再有突变。
  Color _bandTint(BuildContext context, {required bool useBlur}) {
    return HyperosBlurredHeader.sheetTintColor(context, withBlur: useBlur);
  }

  /// 主带：真正有内容从底下穿过的那一段，渐进档（顶边满强度、向下衰减到 0）。
  Widget _mainBand(BuildContext context, {required bool useBlur}) {
    return FrostedHeaderBackground(
        // 渐进档 = 设置页顶栏那一档（子页顶栏已锁死为它，见 subpageHeaderBlurStyleOf）。
        blurStyle: HeaderBlurStyle.inspire,
        blurEnabled: useBlur,
        blurSigma: HyperosBlurredHeader.blurSigmaOf(context),
        // 衬底：模糊开着时是共享的那份磨砂色（与设置页顶栏同一份材料），模糊关掉时是面板
        // 自己的**不透明**色。为什么开着模糊也必须有衬底、以及为什么现在才不会有「带顶一条
        // 亮线」，见 [_bandTint]。
        tint: _bandTint(context, useBlur: useBlur),
        // 带没画模糊时没有下沿可谈（见 InspireHeaderBlur.bottomOverhang：模糊关掉还
        // 外推会盖住正文第一行）。
        bottomOverhang: useBlur ? widget.fadeExtent : 0,
        // 圆角的账一条链走完（第六版，见 [HyperosSheetBlurTop.cornerRampIn]）：
        // 模糊层矩形左右内缩本值（与圆弧相切）+ 横向渐隐爬升宽度取同一个数 +
        // 白纱满宽不缩 + 竖直曲线就是渐进档原样（顶浓底清，设置页同一份观感）。
        cornerRampIn: HyperosSheetBlurTop.cornerRampIn,
        // 白纱自绘圆角的弧要落在面板上沿：带盒整体上移了 [bleedTop]，白纱
        // 盒顶在面板上沿之上，圆弧基准线随之下沉这段（2026-09-29 探针定案：
        // 有内容滚到带下时白纱越出面板圆弧、角外留下满浓度填充，白纱的形状
        // 从此自绘、不依赖引擎裁剪）。
        shapeTopInset: widget.bleedTop,
        // 白纱浓度与设置页顶栏**完全一致**（tintBottomScale 保持出厂 0）。
        // 2026-09-29 曾按「三段式透底」口径补浓 0.4，用户打回：本带的观感
        // 本来就是跟踪设置页做的，不许差异化。参数保留作卧底旋钮。
        // 带上那个控件要**跟正文对齐** —— 带满宽、控件不跟着变宽，否则控件会比底下
        // 正文宽出去 [bleed]×2，两边对不齐。所以横向让位加在这里，不加在带盒上。
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.bleed),
          child: SizedBox(height: widget.headerHeight, child: widget.header),
        ),
      );
  }

  /// Stack 的两个子节点：正文（定尺寸）+ 带（浮在上面）。
  List<Widget> _stackChildren(Widget band, double bandBoxHeight) {
    // 滚动才显形：没显形就整条不画（连模糊层一起）。**不能只淡入 header** —— 模糊带
    // 本体是「压住滚上来的内容」的那一层，它留着就等于内容还在从带底下钻出来，那正是
    // 要消掉的现象。
    final reveal = !widget.revealOnScroll || _revealed;

    return <Widget>[
      // 正文**满高铺开**（不套顶部 padding）—— 让位必须由调用方加在**滚动内容里面**
      // （[topInsetFor]），不能在这里加。
      //
      // ⚠️ 2026-09-26 修掉的一个真 bug：让位加在 body **外面**时，滚动视口被整体下移，
      // 于是内容在**带底就被裁掉**、从来没进过模糊区 —— 带子一直在糊「面板自己的均匀
      // 玻璃」，糊了等于没糊，只剩一条满浓度的白衬底在带顶突兀出现（用户报「切换按钮
      // 顶部一条明显的横线」）。让位进了滚动内容之后，内容才会真的从带**底下**穿过去。
      //
      // `minHeight` 只保「正文至少和带一样高」（否则带会比正文还长、糊到正文外面），
      // 不再参与内容的位置。
      ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: math.max(
            0,
            widget.headerHeight + widget.fadeExtent - widget.bleedTop,
          ),
        ),
        child: widget.body,
      ),
      // 带压在最上（定位子节点恒在非定位之上）：必须挡住从底下滚上来的内容。
      //
      // `left/right: -bleed` 是**满宽**的关键：面板内容的左右内缩是**外层**加的
      // （上游底部弹窗的 `insideMargin`，16），不在本控件的盒里 —— 不外扩的话带子就只
      // 在中间一段有模糊，两侧各留一条没糊的边，读起来是「浮在面板里的方框」而不是
      // 「面板顶部的渐变」。
      //
      // 「滚动才显形」时没显形就换成等高的空盒：位置照样让给正文（静止时第一行就在那儿），
      // 但不画模糊也不吃点击。刻意**不用 `Opacity`** 淡入 —— 它会把 `BackdropFilter`
      // 与玻璃材质降级成透明（`hyperos_sheet.dart` 记的同一条纪律）。
      Positioned(
        top: -widget.bleedTop,
        left: -widget.bleed,
        right: -widget.bleed,
        // 显式给 `height` = 带盒高：`RenderStack` 对只有 `top` 的定位子节点给的是
        // **高度无界**约束（`positionedChildConstraints` 里 `tightFor(height: null)`），
        // 带子内容靠自己的 SizedBox 量回同高只是巧合，钉死之后带盒与 `headerHeight`
        // 不可能漂（带高由 `_mainBand` 的 `SizedBox` 按 `headerHeight` 夹死）。
        // 历史上这还是治过一处真 bug：竖直爬升靠 `LayoutBuilder` 拿高度算比例，无界
        // 约束让 `topRampFractionFor` 恒 0、爬升成死代码（2026-09-28 实测；爬升本身
        // 后来被用户打回删除，但「约束必须有界」这条教训留着）。
        height: bandBoxHeight,
        child: reveal
            ? band
            : IgnorePointer(
                // 没显形时既不画也不吃点击：带的位置要让给正文。
                child: SizedBox(height: bandBoxHeight),
              ),
      ),
    ];
  }
}
