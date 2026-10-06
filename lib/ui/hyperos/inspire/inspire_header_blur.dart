import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:inspire_blur/inspire_blur.dart';

import '../../../models/header_blur_style.dart';
import '../hyperos_blurred_header.dart';

/// 顶栏玻璃带的渐进模糊实现（基于 `inspire_blur`）。
///
/// 与 [FrostedHeaderBackground] 的均匀 `BackdropFilter` 不同，这里用
/// `Inspire.backdropBlur` 的自定义 GPU shader 做**变量**模糊：模糊强度
/// 在玻璃带内按方向连续变化，观感更接近 iOS 系统栏。
///
/// 共享这一份实现的调用点（都经 `FrostedHeaderBackground` 进来）：首页玻璃带
/// （`HomePageChromeGlassFill`）、子页顶栏外壳（`HyperosFrostedHeaderShell`）、
/// 弹窗面板的顶部渐变带（`HyperosSheetBlurTop`）。
///
/// 降级链与既有材质保持一致：系统无障碍 / 降动效 / 高对比度、全局模糊
/// 开关关闭、Web / 桌面（[HyperosBlurredHeader.liveBlurSupported]）、或
/// 设备不支持 shader filter（`ImageFilter.isShaderFilterSupported`）时，
/// 只画 tint 衬底。
class InspireHeaderBlur extends StatelessWidget {
  const InspireHeaderBlur({
    required this.tint,
    required this.child,
    this.blurEnabled = true,
    this.style = HeaderBlurStyle.inspire,
    this.blurSigma = HyperosBlurredHeader.blurSigma,
    this.opaqueAtRest = false,
    this.bottomOverhang = 0,
    this.cornerRampIn = 0,
    this.shapeTopInset = 0,
    this.tintBottomScale = progressiveTintBottomScale,
    super.key,
  });

  /// 玻璃衬底色（与高斯档共用同一套取色逻辑，保证两档观感连续）。
  final Color tint;

  /// 玻璃带内容（标题行等）。
  final Widget child;

  final bool blurEnabled;
  final HeaderBlurStyle style;

  /// 高斯档的模糊强度上限（`InspireBlurConfig` 的 sigma）。
  ///
  /// **只服务 [HeaderBlurStyle.gaussian]**：高斯是基础模糊材质，粗细由全局
  /// 「模糊强度」（`FrostedAppearance.sheetBlurSigma`）决定。渐进档用
  /// [progressiveSigma] 等固定常量，不受此处影响。
  final double blurSigma;

  /// 模糊 / 衬底这条带比内容**再往下多画**的高度。
  ///
  /// 子页顶栏传 [HyperosBlurredHeader.bandBottomOverhang] 的返回值 —— 用户口径
  /// 2026-09-23 要的是「最底下模糊的边界再往下，超过标题底部一个字空间」，
  /// 但版面上只留得出那么多，实际画多少按那里封顶；其他调用方（卡片、菜单井、
  /// 弹窗面板）保持 0，观感逐像素不变。
  ///
  /// 实现是**只把下面这两层撑下去**：Stack 的高度仍由 [child] 决定，所以标题
  /// 位置、以及外壳被测量到的高度都不变 —— 只有"糊到哪儿为止"往下挪。
  final double bottomOverhang;

  /// 无内容压在带下时，是否把衬底铺满整条带（不向下渐隐）。
  ///
  /// 可折叠顶栏的模糊层是常驻挂载的（见 [HyperosFrostedHeaderShell]），
  /// 而 [HeaderBlurStyle.inspire] 的衬底会在底边渐隐到全透明。两者叠加会
  /// 留出一条「透明窗口」：内容还没真正压到带底、`contentUnderHeader`
  /// 仍为 false 时，模糊采样已把即将进入带内的内容糊进这条窗口——于是
  /// 内容先以一层无衬底的虚影出现，衬底随后才整条切进来，读起来就是
  /// 「内容快插到标题栏时顿一下」。顶上这一档后，常驻模糊在无内容时被
  /// 不透明衬底完全盖住，翻转点只剩一次衬底切换。
  final bool opaqueAtRest;

  /// 让开宿主**两个上角**的横向让位区（逻辑 px）。**默认 0 = 逐字旧行为**（子页顶栏 /
  /// 首页玻璃带走这支）。**现在只有弹窗面板的顶部渐变带开 = 面板圆角半径 28。**
  ///
  /// ## ⚠️ 第九轮定案（2026-09-29）：本参数现在**只管白纱的自绘圆角**
  ///
  /// 第六版曾让它同时管三件事：模糊层矩形左右内缩、横向渐隐宽度、白纱形状。
  /// 真机探针 + 日志定位后，它的两个防护对象都被真正的根因修复取代：
  /// 采样退化（fork 补丁 3，`u_size` 从未设置）、白纱越出圆弧（白纱自绘圆角，
  /// 见 [shapeTopInset]）。按用户口径「不是应该是上下渐变吗」，模糊层回到满宽
  /// 纯竖直（横向渐隐机制保留但休眠，见 [sideTaperFractionFor]），本参数只剩
  /// 白纱自绘圆角这一个职责（[_veilRadius]）。历史版本表见
  /// `.agents/notes/implemented/bug-fix/2026-09-28-sheet-top-band-corner-ramp.md`。
  ///
  /// ## 一个旋钮管两件事（2026-09-28 第六版定稿）
  ///
  /// 1. **几何**：**模糊层**（`Inspire.backdropBlur` 那层）的矩形左右各内缩这么多。
  ///    内缩后的矩形与面板上沿圆弧**相切**（矩形两个上角正好落在弧线与直边的交点），
  ///    两个圆角区域里没有模糊材料：材料不再压着轮廓的方角，着色器取样范围
  ///    （`u_area` = 部件矩形 ← `InspireBlurWrapper.globalBounds`）也整体落在面板内 ——
  ///    「矩形与圆弧相交的那两块采到空样本、模糊跨弧把外面的东西拖进来」
  ///    （用户：「渐变模糊跑到了圆角外面」）这条路径**从机制上不存在**。
  /// 2. **强度**：横向渐隐（[sideTaperFractionFor]）的爬升宽度取**同一个数**。矩形
  ///    内缩后若不渐隐，材料会在离边 [cornerRampIn] 处齐刷刷断掉，切出一条竖直接缝
  ///    （仓里有过「顶栏一条 1px 竖线」的投诉）；渐隐让强度在矩形边缘正好归零，
  ///    接缝与「矩形自己的方角」一起消失，弧线交界处（相切点）强度也是 0。
  ///
  /// ## ⚠️ 只缩模糊，**白纱（衬底）不缩**（第六版的关键分家）
  ///
  /// 白纱走**满宽**的 `Positioned`：它的方角是普通绘图，交由面板的 `ClipRRect` 裁
  /// （这条路可靠），圆角处白纱边界跟着弧线走，两端一分料都不少。第三版（09-28 上午）
  /// 把白纱一起缩了，两端各空一截、深色壁纸上读成「透明」被真机打回 —— 那笔账缩的是
  /// 白纱，不是模糊；白纱满宽之后「每端 56px 无料」这条反对理由不再成立。
  ///
  /// ## 竖直方向：**上沿满强度，一点不压**
  ///
  /// 上沿必须满强度（滚上去的行在那儿化开，09-26 定、09-27「拉杆底下不能没有模糊」
  /// 那条的正解），竖直曲线就是渐进档原样：自顶边满 → 带底 0（设置页顶栏同一份观感，
  /// 用户口径「设置页面顶部的渐变模糊视觉效果是非常好的，不要去改动导致他坏掉」）。
  /// 曾试过在上沿加一道「0 → 满」的竖直爬升（`topRampIn`，治「角被读成平铺」），
  /// 接通生效后真机复验是**三段式**（上面透明、中间浓、下面透明）+ 拉杆区透明，
  /// 用户打回 —— 圆角的账归本参数的几何 + 横向渐隐管，竖直曲线不许再动。
  ///
  /// ## 历史账（版本表见 `.agents/notes/implemented/bug-fix/2026-09-28-sheet-top-band-corner-ramp.md`）
  ///
  /// 这个旋钮三启三废，每次废掉的原因都不是「内缩本身错了」：第三版内缩开，但当时
  /// 横向渐隐是死代码（`configFor` 收下参数没接进 `distribution`）⇒ 内缩边切硬缝 +
  /// 相切角满强度，真机仍报圆角异常，随后连内缩一起归零；第四版误信「ClipRRect 恒赢、
  /// 带子画不到圆角外」全靠裁剪 —— 圆角问题一直在。第六版 = 内缩只缩模糊 + 渐隐接活 +
  /// 白纱满宽 + 竖直顶浓底清，四件同时成立才是完整解。
  final double cornerRampIn;

  /// 白纱自绘圆角的**圆弧基准线**距本部件盒顶的距离（逻辑 px）。
  ///
  /// 带盒整体上移了宿主的顶部空占位（弹窗渐变带的 `bleedTop` = 18），白纱盒顶
  /// 落在面板上沿**之上**；白纱自绘圆角（见下）的弧要对准面板轮廓，就得先下沉
  /// 这段。默认 0 = 盒顶即形状边（子页顶栏 / 首页玻璃带，逐字不变）。
  ///
  /// ## 为什么白纱要**自己**画圆角（2026-09-29 探针定案）
  ///
  /// 带子里有 BackdropFilter，引擎对其**兄弟内容**的圆角裁剪并不总是可靠：
  /// 真机探针（白纱染绿）证实，有内容滚到带下时白纱越出面板 `ClipRRect` 的
  /// 圆弧，在两个角外的方形区域留下满浓度填充（用户口径「圆角外面会出现
  /// 东西」），滚动到带下无内容时又恢复正常；而直边一侧（面板上沿以上）始终
  /// 守得住。与其赌引擎裁剪状态，白纱直接把形状画出来——普通绘制的圆角矩形，
  /// 不经过任何裁剪。见 `2026-09-28-sheet-top-band-corner-ramp.md` 第八轮。
  final double shapeTopInset;

  /// 白纱中下段的**补浓系数**（0 = 出厂的两段形 [满, 透明]）。
  ///
  /// 弹窗渐变带浮在屏幕中部、上下都有内容对比，半透明雾底下的**内容空隙**
  /// （卡片之间的深色间隔）会透过雾读成「透明」，整条带被内容切成三段观感
  /// （用户口径 2026-09-29「顶部透明、中间模糊、往下又变透明」）。补浓后中段
  /// （75% 高度处）的雾 = 满浓度 × 本系数，带底仍恒为透明、不切横向硬边。
  /// 默认 = [progressiveTintBottomScale]（= 0，子页顶栏 / 首页玻璃带逐字不变）。
  final double tintBottomScale;

  /// 设备是否支持 shader filter（Inspire Blur 的兜底条件）。
  static bool get _shaderFilterSupported => ImageFilter.isShaderFilterSupported;

  /// 是否允许在给定 context 下使用渐进模糊。
  static bool canRender(BuildContext context) {
    if (!_shaderFilterSupported) {
      return false;
    }
    return HyperosBlurredHeader.backdropBlurEnabled(context);
  }

  /// 渐进档的**固定**参数（2026-09-23 用户口径：浓淡只要一个档位）。
  ///
  /// 这三个数不是随手取的，与
  /// [HyperosBlurredHeader.subpageBandBottomOverhang] 是一组：
  ///
  /// * [progressiveSigma] = 22（原来 15）：顶部更糊。抬到 22 是因为带子下半段
  ///   被 overhang 拉长之后，同样的 sigma 在视觉上会显得更薄。
  /// * [progressiveExtent] = 1：模糊自顶边满强度向下、**正好在带底**衰减到 0。
  ///   带底已经被 overhang 推到标题下方，所以"最底下那条模糊边界"落在标题底部
  ///   之下；而 extent = 1 保证边界处没有残留模糊，不会和下方清晰内容硬切。
  /// * [progressiveTintBottomScale] = 0：不加下部衬底（真机上衬底在带底留过
  ///   一条横向硬边，见 [tintGradient]）。
  static const progressiveSigma = 22.0;
  static const progressiveExtent = 1.0;
  static const progressiveTintBottomScale = 0.0;

  /// 高斯档：整带均匀强度。
  ///
  /// ⚠️ 必须用 [UniformDistribution]：包的 `extent` 语义是「模糊从顶边衰减
  /// 到 0 的位置（占带宽比例）」，不是「底边收边宽度」——曾把 0.12 当收边
  /// 区传入，结果整条带只有顶部 12% 有模糊、下面全清晰（2026-09-12 真机
  /// 「全局柔光 + 子页高斯 = 顶栏全透明」的根因）。渐隐收边如需保留，应改
  /// 用带自定义 stops 的渐变分布，而不是缩 extent。
  ///
  /// 纯函数便于测试：渐进档的 sigma / extent 全部来自上面的固定常量，
  /// 高斯档用 [gaussianSigma]（全局「模糊强度」）并整带均匀。
  ///
  /// [sideTaperFraction] 是**横向**渐变的爬升段占材料盒宽度的比例（0..1，见
  /// [InspireHeaderBlur.cornerRampIn]）。0 = 旧行为（只有竖直那一份，逐字不变）。
  /// 大于 0 时渐进档的分布变成「竖直渐变 × 横向渐变」：**上沿仍是满强度**（滚上去
  /// 的行照旧化开），而材料盒左右两端在 [sideTaperFraction] 之内从 0 爬到满
  /// （内缩出来的那条竖边因此是渐隐的）。
  ///
  /// 竖直那份**逐字复用** [InspireBlurConfig.topToBottom] 的分布，不另写一套值 ——
  /// `progressiveExtent` 那条「带底恒为 0」是这块带子的地基，改常量时两边必须一起走。
  /// 高斯档是均匀分布、没有方向可乘，忽略该参数。
  static InspireBlurConfig configFor(
    HeaderBlurStyle style, {
    required double gaussianSigma,
    double sideTaperFraction = 0,
    double topCornerRadius = 0,
  }) {
    final taper = sideTaperFraction.clamp(0.0, 1.0);
    return switch (style) {
      // 渐进档：形状 = 竖直那份 × 横向那份，见 [_inspireDistribution]。
      HeaderBlurStyle.inspire => InspireBlurConfig(
          sigma: progressiveSigma,
          distribution: _inspireDistribution(taper: taper),
          // mikcb 补丁 5：材料形状两个上角按面板圆角走弧（0 = 关）。
          topCornerRadius: topCornerRadius,
        ),
      // 高斯档：整带均匀模糊，粗走全局模糊强度（两个方向渐变都忽略）。
      HeaderBlurStyle.gaussian => InspireBlurConfig(
        distribution: const UniformDistribution(),
        sigma: gaussianSigma,
        topCornerRadius: topCornerRadius,
      ),
    };
  }

  /// 渐进档的**分布形状**：竖直那份 [vertical] × 横向那份 [taper] 的乘积
  /// （[ProductDistribution] = `first(u,v) × second(u,v)`，本仓 fork 补丁 2）。
  ///
  /// ## 两份各自的形状
  ///
  /// * **竖直**：恒为 [verticalProgressiveProfile]（= `topToBottom` 那份，模糊自顶边
  ///   满强度、按 extent 衰减到 0；`extent` 写死 1.0 是「完全清晰正好落在**带底**
  ///   （已含 overhang），与下方内容衔接处无残留模糊切边」这条契约本身）。**上沿就是
  ///   满强度，不许再加竖直爬升** —— 曾试过「上沿 0 → 往下爬满」（`topRampFraction`），
  ///   接通生效后真机是三段式（上透明 / 中间浓 / 下透明）+ 拉杆区透明，用户打回，
  ///   参数已删（历史见 [cornerRampIn] 与 09-28 笔记的版本表）。
  /// * **横向**（`taper` > 0）：材料盒两端 0 → [cornerRampIn] 段满，见 [sideTaperProfile]
  ///   —— 治的是「模糊矩形内缩后在边上断出一条竖直接缝」，也让相切点强度归零。
  ///   `taper` = 0（子页顶栏 / 首页玻璃带）时直接返回竖直那一份，与改动前逐字一致。
  ///
  /// ## 为什么在这里乘，而不是只给衬底加横向渐隐
  ///
  /// ⚠️ 2026-09-28 踩过：`configFor` 收下了 `sideTaperFraction` 却没把它接进
  /// `distribution`，于是**模糊那侧的横向渐隐静默消失** —— 第三版（内缩开着）真机
  /// 仍报「圆角外面有奇怪的东西」就是这笔（内缩边硬缝 + 相切角满强度）。测试
  /// `sheet_top_band_corner_ramp_test.dart` 的「分布 = 竖直 × 横向」钉的就是这条。
  /// 上游每个分布只能表达**一个方向**的形状，说不了「沿这条轴满强度、沿那条轴渐隐」
  /// —— [ProductDistribution] 就是干这个的。
  static BlurDistribution _inspireDistribution({required double taper}) {
    final vertical = verticalProgressiveProfile;
    if (taper <= 0) {
      return vertical;
    }
    return ProductDistribution(
      first: vertical,
      second: sideTaperProfile(taper),
    );
  }

  /// 渐进档的**竖直**那一份渐变（上沿满 → 带底 0）。
  ///
  /// 抽出来是因为 [configFor] 与测试都要用同一份：模糊与衬底是两层独立绘制，
  /// 各自重写一遍值迟早漂。
  @visibleForTesting
  static DirectionalDistribution get verticalProgressiveProfile =>
      InspireBlurConfig.topToBottom(
        sigma: progressiveSigma,
        // ignore: avoid_redundant_argument_values
        extent: progressiveExtent,
      ).distribution as DirectionalDistribution;

  /// **横向**那一份渐变：材料盒左端 0 → [fraction] 处满 → 右对称 → 右端 0。
  ///
  /// [fraction] 是爬升段占盒宽的比例。纯函数便于测试：与衬底那份 [tintSideTaper]
  /// 的 stops 必须是同一组数（模糊与衬底是同一块材料）。
  @visibleForTesting
  static DirectionalDistribution sideTaperProfile(double fraction) {
    final f = fraction.clamp(0.0, 1.0);
    return DirectionalDistribution(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      values: const <double>[0, 1, 1, 0],
      stops: <double>[0, f, 1 - f, 1],
    );
  }

  /// 渐进档衬底的**竖直**渐变：顶边满浓度，沿方向衰减，**带底恒为全透明**。
  ///
  /// 带底必须是 0：玻璃带外面是清晰内容，衬底只要在交界处还不是透明，就会
  /// 切出一条横向硬边（真机口径「最浓状态下底部出现一条横向」）。所以
  /// [progressiveTintBottomScale] 只抬高下半段的浓度（多一个中间 stop），
  /// 末段一律收敛到 0——任何取值都只在带内加雾，不带边。
  ///
  /// [bottomScale] = 0（默认）时退化成 [top, 透明] 两段，与接入调参前的观感
  /// 逐像素一致。
  ///
  /// ⚠️ **上沿就是满浓度，不许再加「上沿 0 → 往下爬满」的竖直爬升**（曾以
  /// `topRampFraction` 四段渐变的形式存在，真机复验是三段式 + 拉杆区透明，用户
  /// 打回后参数已删）。圆角的账归 [cornerRampIn] 的几何 + 横向渐隐管。
  ///
  /// 形状**只有竖直这一份**。横向那一份由 [tintSideTaper] 以 `ShaderMask` 的
  /// `dstIn` 叠上去（两段相乘），而不是在这里写多段 —— 见 [cornerRampIn]。
  @visibleForTesting
  static LinearGradient tintGradient(Color top, double bottomScale) {
    final transparent = top.withValues(alpha: 0);
    if (bottomScale <= 0) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, transparent],
      );
    }
    final mid = top.withValues(alpha: top.a * bottomScale);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, mid, transparent],
      stops: const [0, 0.75, 1],
    );
  }

  /// 衬底那份**横向**渐变：与 [sideTaperProfile] 的 stops 必须是同一组数
  /// （模糊与衬底是同一块材料，两处各写一遍必然漂）。
  ///
  /// 抽出来是因为它被 `ShaderMask` 用：把竖直渐变按它裁一次 = 两段相乘，而**不**
  /// 需要给 `BackdropFilter` 套离屏层（本仓的硬纪律，见 [cornerRampIn]）。
  @visibleForTesting
  static LinearGradient tintSideTaper(double fraction) {
    final f = fraction.clamp(0.0, 1.0);
    // 方向就是 `LinearGradient` 的默认（centerLeft → centerRight，即横向）。
    return LinearGradient(
      colors: const <Color>[
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: <double>[0, f, 1 - f, 1],
    );
  }

  /// 渐进档衬底：随方向上浓下淡，与模糊强度梯度对齐；带底恒为透明。
  ///
  /// 高斯档保持均匀 [tint]。渐进档若继续盖一层整幅半透明色，观感会退化
  /// 成「一致的半透明条」，完全看不出 iOS 式的顶浓底清。
  ///
  /// [sideTaperFraction] > 0 时再叠一层**横向**渐变（`ShaderMask` 的 `dstIn`），
  /// 于是白纱与模糊拿到**同一个**两段相乘的形状（stops 与 [sideTaperProfile] 逐字
  /// 同源）。**当前唯一调用方传 0**：白纱不横向收，只留竖直那一份（见
  /// [sideTaperFractionFor] 的分家说明）。这层留着是为了将来要「两层同形」时
  /// 有个不踩离屏层的写法可抄 —— 千万别把它套到 `BackdropFilter` 外面。
  Widget _tintLayer({required double sideTaperFraction}) {
    final useGradient = style == HeaderBlurStyle.inspire && !opaqueAtRest;
    if (!useGradient) {
      // ⚠️ 白纱走**满宽**定位（`insetCorners: false`）：只有模糊层左右让开
      // [cornerRampIn]，白纱跟着缩两端就会空掉一截料（第三版真机打回的账）。
      // 未开让位的宿主保持逐字不变的 ColoredBox；开了让位的用带圆角的
      // DecoratedBox（白纱自绘形状，不依赖裁剪）。
      return _bandLayer(
        insetCorners: false,
        child: _veilRadius == null
            ? ColoredBox(color: tint)
            : _veilTop(DecoratedBox(
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: _veilRadius,
                ),
              )),
      );
    }
    final vertical = _veilTop(DecoratedBox(
      decoration: BoxDecoration(
        gradient: tintGradient(tint, tintBottomScale),
        borderRadius: _veilRadius,
      ),
    ));
    if (sideTaperFraction <= 0) {
      return _bandLayer(insetCorners: false, child: vertical);
    }
    final mask = tintSideTaper(sideTaperFraction);
    return _bandLayer(
      insetCorners: false,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: mask.createShader,
        // ⚠️ 这个 `ShaderMask` **只**包住上面那个纯渐变的衬底层。千万别把它扩到
        // `BackdropFilter` 那层：本仓记过「给模糊套离屏层会把模糊降级成透明」，
        // 那正是这里要绕开的坑（模糊的横向淡出由 `InspireBlurConfig.product` 做）。
        child: vertical,
      ),
    );
  }

  /// 白纱的**自绘圆角**形状（2026-09-29 探针定案，见 [shapeTopInset] 的说明）。
  ///
  /// 开了让位的宿主，白纱的弧必须与面板轮廓同一条：圆角半径取 [cornerRampIn]
  /// （= 面板圆角半径），弧顶下沉 [shapeTopInset]（带盒上移的那段）。未开让位
  /// 的宿主返回 null，盒子方角、逐字不变。
  BorderRadius? get _veilRadius => cornerRampIn > 0
      ? BorderRadius.vertical(top: Radius.circular(cornerRampIn))
      : null;

  /// 白纱盒顶下沉 [shapeTopInset]：圆弧要落在面板上沿（宿主形状边）上。
  Widget _veilTop(Widget box) => shapeTopInset > 0
      ? Padding(padding: EdgeInsets.only(top: shapeTopInset), child: box)
      : box;

  /// 把一层铺满整条带（[insetCorners] 时左右各让开 [cornerRampIn]、下沿外推
  /// [bottomOverhang]）。
  ///
  /// Stack 的高度由非定位的 [child] 决定，所以下沿撑出去的部分**不参与布局**
  /// —— 下沿能往下走，标题与外壳高度都不动。
  ///
  /// [insetCorners] **只有模糊层传 `true`**（见 [cornerRampIn] 的第六版分家）：
  /// 模糊的取样范围是本部件自己的矩形（着色器 `u_area_origin/u_area_size` ←
  /// `InspireBlurWrapper.globalBounds`），矩形还压着宿主的圆弧时，相交的那两块
  /// 着色器以为采得到、引擎按裁剪区掐过之后其实没有 ⇒ 模糊跨弧把外面的东西拖进来
  /// （症状「渐变模糊跑到了圆角外面」）。内缩让矩形与弧相切，这条路径从机制上断掉；
  /// 竖直方向**一点不动**：上沿仍贴着宿主上沿，化开不减。
  ///
  /// 白纱传 `false`：普通绘图的裁剪可靠，满宽白纱的方角由宿主 `ClipRRect` 交代，
  /// 两端的料一分不少。
  ///
  /// ⚠️ 内缩后**必须**有横向渐隐（`build` 里 `sideTaperFractionFor` 的 `taperIn` 取
  /// 同一个 [cornerRampIn]），否则材料在边上齐刷刷断掉、切出竖直接缝 —— 第三版的
  /// 渐隐当时是死代码，这笔账就是那么欠下的。
  Widget _bandLayer({
    required Widget child,
    required bool insetCorners,
    double topInset = 0,
  }) {
    final inset = insetCorners ? cornerRampIn : 0.0;
    if (inset <= 0 && bottomOverhang <= 0 && topInset <= 0) {
      return Positioned.fill(child: child);
    }
    // ⚠️ `left` 与 `right` **必须同号**（都是 `+inset` = 左右各往内缩）。
    // 曾经写成 `right: -cornerRampIn`，于是「左边缩进去、右边伸出来」，材料盒整体
    // 往右偏了一个 cornerRampIn：左上角那截没人画 → 透出后面的壁纸（读成透明），
    // 右上角反而多盖到面板外 → 模糊跨过圆角弧、把圆角盖成平的。
    // 三种现象是同一个符号错误，与「渐变模糊偏向右边」是同一件事。
    // 宽度的账也要跟着这条：`left+right` 同号才是「窄 2×inset」，
    // `build` 里 `constraints.maxWidth - cornerRampIn * 2` 就是按这个契约算材料盒宽的。
    return Positioned(
      left: inset,
      right: inset,
      top: topInset,
      bottom: -bottomOverhang,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final useBlur = blurEnabled && canRender(context);
    // ⚠️ 第九轮定案（2026-09-29，用户口径「不是应该是上下渐变吗」）：模糊层回到
    // **满宽 + 纯竖直渐变**。第六版的「左右内缩 + 横向渐隐」是为防圆角越界加的
    // 保护，但它防的两笔（`u_size` 采样退化 = fork 补丁 3、白纱越出圆弧 = 白纱
    // 自绘圆角）都已真正修掉，保护成了多余的观感负担，按口径撤除。横向渐隐的
    // 机制（[sideTaperFractionFor] / [sideTaperProfile]）保留但休眠，见
    // `_buildBand`。`cornerRampIn` 现在只喂白纱的自绘圆角（[_veilRadius]）。
    return _buildBand(context, useBlur: useBlur, sideTaperFraction: 0);
  }

  /// **横向**渐变的爬升段占材料盒宽度的比例 —— [sideTaperFraction] 的推导，纯函数。
  ///
  /// 爬升段的**物理宽度就等于 [taperIn]**，所以分母必须是**实际画的那个材料盒**宽
  /// （调用点传 `constraints.maxWidth - 2 × cornerRampIn`：`_bandLayer` 的 `Positioned`
  /// 左右各让开 [cornerRampIn]，让出来的那一截要正好被渐隐吃掉，两处同一个数）。
  /// 现网弹窗带 `taperIn = cornerRampIn`；未开让位的宿主不进这条推导。
  ///
  /// ⚠️ 分母曾写成 `width + cornerRampIn * 2`，与这份契约正好相反：算出来的爬升段
  /// 只有 21px 而不是 28px（393 宽的屏），即渐隐比让位区**先**收尾、末尾留了一条满
  /// 强度的窄边。观感只差一点点所以真机看不出来，但代码与注释已经对不上，且没有
  /// 任何用例覆盖这个推导 —— 现在抽成纯函数并由
  /// `sheet_top_band_corner_ramp_test.dart` 钉住。
  ///
  /// [taperIn] ≤ 0 或材料盒不剩正宽度时返回 0：横向渐变无处可爬，退回
  /// 「只有竖直那一份」= 逐字旧行为。
  ///
  /// ## 这份横向渐隐**只喂给模糊**（2026-09-28 分家）
  ///
  /// 白纱不横向渐隐、也不随矩形内缩（满宽）：一旦跟着收，两端就只剩玻璃、深色壁纸上
  /// 读成「透明」（第三版真机打回的账）。**只有模糊收** —— 圆角那两块的取样不跨过
  /// 弧线，两端的白纱一分不少。
  @visibleForTesting
  static double sideTaperFractionFor({
    required double materialWidth,
    required double taperIn,
  }) {
    if (taperIn <= 0) return 0;
    if (materialWidth <= 0) return 0;
    return (taperIn / materialWidth).clamp(0.0, 1.0);
  }

  Widget _buildBand(
    BuildContext context, {
    required bool useBlur,
    required double sideTaperFraction,
  }) {
    final band = Stack(
      fit: StackFit.passthrough,
      // Positioned bottom=-overhang 的模糊/衬底层要越过原始带高；
      // 内层 Stack 默认会在自身尺寸处裁掉那一截，外层扩展裁剪框也救不回来。
      clipBehavior: Clip.none,
      children: [
        if (useBlur)
          // 模糊层：**满宽**（第九轮定案，见 build 的说明）——第六版的内缩让位
          // 随真实根因修掉而撤除；`insetCorners` 参数保留但休眠。
          //
          // ⚠️ `topInset: shapeTopInset`（2026-09-29 定案）：带盒整体上移了
          // [shapeTopInset]，模糊矩形若也从盒顶起，它的两个上角方区就压在面板
          // 圆角**之外**——引擎对 BackdropFilter 的圆角裁剪不总可靠（真机探针
          // 实锤：模糊层一关角外就干净），角外的方形区就是从这儿漏出来的。
          // 下沉到面板上沿起画后，矩形顶边与白纱的弧线基准同一条线；配合
          // fork 补丁 5 的 `topCornerRadius`（着色器按面板半径在上角走弧、
          // 弧外一律不画），材料形状与面板轮廓严丝合缝。
          //
          // ⚠️ 弹窗带（cornerRampIn > 0 的唯一宿主）外面套
          // [_SheetEntranceReregister]：开窗动画期间第一次进场的滤镜在引擎侧
          // 登记坏损，事后原地重登记能修（2026-09-29 探针实锤，见该类注释）。
          if (cornerRampIn > 0)
            _SheetEntranceReregister(
              builder: () => _buildBlurLayer(
                sideTaperFraction: sideTaperFraction,
              ),
            )
          else
            _buildBlurLayer(sideTaperFraction: sideTaperFraction),
        // 衬底画在模糊之上：模糊负责「糊」，衬底负责可读对比度。
        //
        // ⚠️ 白纱**不吃**横向渐隐、也**不左右内缩**（满宽）：2026-09-28 分家，理由
        // 见 [sideTaperFractionFor] / [_bandLayer] —— 白纱一旦跟着收，两端就只剩
        // 玻璃、深色壁纸上读成「透明」，第三版就是这么被打回的。
        // ⚠️ 白纱**自己带圆角**（`_veilTop` / `_veilRadius`）：带子里有
        // BackdropFilter 时，引擎对兄弟内容的圆角裁剪不总可靠（2026-09-29 真机
        // 探针实锤：有内容滚到带下时白纱越出面板圆弧、角外留下满浓度填充），
        // 白纱的形状从此不依赖任何裁剪。
        _tintLayer(sideTaperFraction: 0),
        child,
      ],
    );

    if (bottomOverhang <= 0) {
      return ClipRect(child: band);
    }
    // 默认 ClipRect 按自身尺寸裁剪，会把下沿那一截切掉 —— 这里把裁剪框往下
    // 放到带底（左右与上方仍是原框），其余行为不变。
    return ClipRect(clipper: _BandOverhangClipper(bottomOverhang), child: band);
  }
  /// 模糊层本体（满宽 + 纯竖直分布 + 顶角圆弧，见 [build] 里的说明）。
  ///
  /// 抽出来是因为 [_SheetEntranceReregister] 每次「重登记」都要**重新构造**
  /// 这棵子树（新 widget 实例才会触发引擎重登记），不能复用同一个实例。
  Widget _buildBlurLayer({required double sideTaperFraction}) {
    return _bandLayer(
      insetCorners: false,
      topInset: shapeTopInset,
      child: IgnorePointer(
        child: Inspire.backdropBlur(
          config: configFor(
            style,
            gaussianSigma: blurSigma,
            sideTaperFraction: sideTaperFraction,
            topCornerRadius: cornerRampIn,
          ),
          // 顶栏不参与手势，无需截获指针；自身已经裁剪在带内。
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// 把裁剪框按 [overhang] 往下扩一截的裁剪器（见 [InspireHeaderBlur.bottomOverhang]）。
class _BandOverhangClipper extends CustomClipper<Rect> {
  const _BandOverhangClipper(this.overhang);

  final double overhang;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height + overhang);

  @override
  bool shouldReclip(_BandOverhangClipper oldClipper) =>
      oldClipper.overhang != overhang;
}

/// 弹窗顶部渐变带的**开窗重登记**（2026-09-29 真机定案的引擎层绕行）。
///
/// ## 病根（真机日志 + 延迟重录探针两轮实锤）
///
/// 开窗动画期间第一次进场的 [BackdropFilter]，引擎对它的**背景绑定**是坏的：
/// Dart 侧一切参数正确（着色器已装载、取景框 = 面板终位、sigma/强度图/圆角
/// 全对），但之后每帧都沿用坏绑定——内容滚到带下也不出模糊；任何一次原地
/// 重建（重跑 builder 生成新的模糊层实例 → `didUpdateWidget` → 新的
/// `ImageFilter` 实例 → 引擎重新登记）立刻恢复。探针验证：开窗后延迟一次
/// 原地重建，不切页签模糊即活。
///
/// ## 做法
///
/// 挂载后 **700ms / 1600ms** 各把子树原地重建一次（重跑 [builder]）。开窗时
/// 列表在顶部、带子底下没有内容，重登记零观感代价；两次是兜底开窗动画被
/// 卡顿拖长的情形（动画约 620ms）。只在弹窗带启用（`cornerRampIn > 0` 的
/// 唯一宿主）——子页顶栏/首页玻璃带走路由转场进场，无此症状，不碰。
class _SheetEntranceReregister extends StatefulWidget {
  const _SheetEntranceReregister({required this.builder});

  /// 每次重登记都要**重新构造**子树（新 widget 实例才会触发引擎重登记）。
  final Widget Function() builder;

  @override
  State<_SheetEntranceReregister> createState() =>
      _SheetEntranceReregisterState();
}

class _SheetEntranceReregisterState extends State<_SheetEntranceReregister> {
  static const _delays = <Duration>[Duration(milliseconds: 700), Duration(milliseconds: 1600)];

  @override
  void initState() {
    super.initState();
    // 测试环境不排期（pending Timer 会挂住 testWidgets）。
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    for (final delay in _delays) {
      Future<void>.delayed(delay, () {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder();
}
