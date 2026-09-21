#version 460 core
#include <flutter/runtime_effect.glsl>

// 全局「液态玻璃」表面：在**实时背景**上做圆角矩形边缘折射 + 染色 + 均匀边缘高光。
//
// 与 course_card_glass.frag 的关系：折射数学（圆角 SDF、有限差分法线、边缘推力、
// 均匀边缘高光、预乘输出）逐字同源，差别只在**输入来源与坐标系**：
//   * 卡片吃的是「共享的预模糊壁纸位图」，卡片是它的一个移动窗口（u_tex_origin 映射）；
//   * 这里吃的是引擎给的**实时背景快照**（BackdropFilter 的滤镜输入），全屏对齐，
//     所以不需要窗口映射。
// 两条路共用同一套数学，是为了守住「同一个材质只有一种观感」这条硬规则：任何表面
// 都不得自带一套折射参数（历史教训见
// lib/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart 顶部注释）。
//
// ── 边缘高光（2026-09-20 一天内改了四轮，别再走回去） ──
// 原先按 `dot(法线, 光来向)` 加权，让玻璃读成「受光」而不是「描边」。代价是同一块
// 玻璃的不同边亮度差到 2.9:1（上沿 0.87、下沿 0.35，光来向固定左上）：这点差在圆角
// 上读作立体感，在**通栏长直边**上却是一条贯通的亮线（用户口径「顶部区域有浅色
// 线条」）。均匀口径的边光 alpha 只按「离边多远」算、与方向无关，圆件也靠折射而非
// 方向性高光撑厚度。故此处改为均匀：长直边与圆角天然一致，厚度感全部交给折射。
//
// 同批删掉的还有 `u_light_dir` 与 `u_top_run_fade`。后者是为「抹掉上沿直段那条线」
// 而加的（只在着色里按横向位置把受光高光与折射淡出），方向性没了之后它没有存在
// 理由 —— 留着反而会把上沿直段的边缘观感切掉一截，在切点处留下接缝。
//
// 同一天的第二轮：均匀还不够，**截面形状**也得改。原来是「贴边最亮、往里二次衰减」，
// 而贴边那一格正是抗锯齿的半像素过渡带 —— 亮线的亮度跟着边界相位跳变，圆角上就是
// 锯齿。改成峰在带内的鼓包（见 `main()` 里那段说明），带宽同时从 0.8 回到 1.5 逻辑 px
// （0.8 不到一个逻辑像素，本身就是一根发丝，圆角上必毛）。
//
// 同一天的第三轮：前两轮改的都是「这一圈亮多少、截面什么形状」，而真机口径
// （「圆角异常，上面和左右异常浅色条」）说明病根在**它出现在一条贯屏长直边上** ——
// 同一条高光，落在圆角上读作玻璃的反光边，落在长直段上就读成一条亮线；长度一变，
// 反光就成了描边。所以这一轮不再动亮度，改成按**边界曲率**加权：圆角满档、长直段
// 归零（判据与过渡宽度见 `main()` 里那段说明）。
//
// 这条规则是**材质级**的、不看表面是谁：右上角菜单弹窗、底栏药丸、首页玻璃带一起走
// 同一套 —— 用户要的是「和右上角卡片观感一致」，而不是给底部弹窗单开一个口子。
//
// 同一批的下一轮（`.agents/notes/.../2026-09-18-liquid-glass-surface.md` 里记作第五轮，
// 那篇还记了别的轮次，编号别互相对照）：第三轮那条规则**误伤了细长条**。真机口径
// 「底栏高光只剩左右」，
// 回读确认药丸的上沿只有左右各约 35 逻辑 px 亮着、中间 220px 全黑（底部弹窗的上沿
// 读数与它几乎一样：都是三百多像素的长直边、圆角都是 27/28）。也就是说**只按曲率判，
// 分不开「药丸的上沿」与「弹窗的上沿」** —— 它们几何上是同一个东西。真正能分开的是
// **这块面整体是细条还是方正的板**：药丸 380×54、玻璃带 360×百来像素，而底部弹窗
// 与弹窗家族都是方正的大面。
//
// 所以补一个 `u_rim_corner_only`（0 = 整圈均匀、1 = 只留转角），由 Dart 侧按长短边比
// 推导（`liquidGlassRimCornerOnlyForSize`）。它是**几何适配**、与 `u_dome` /
// `maxRefraction` 同一性质：表面自己没有通道把它传进来，也不开放调参。
//
// 后来（2026-09-21）又补了一条尺寸线：**短边 ≤ 52dp 的小件一律整圈均匀**。真机口径
// 「四周的白边不均匀，顶部看起来是黑的，四个角是正常白边」来自 60×36 的悬浮按钮 ——
// 它按长短边比推会得到 0.93（几乎全收），顶上那条 28px 的直段只剩四成亮，而四角仍满档。
// 长直边之所以读成描边靠的是**长度**，28px 显然不够长；小件的整条边都该读作"按钮的
// 上沿反光"。判据仍由 Dart 侧算（同一个推导函数），着色器这一份不动。
//
// ⚠️ 只有**全局表面**这一份需要它：课程卡片那一份（course_card_glass.frag）的卡片
// 永远是方正的小格（长短边比 ≤ 1.6），按同一条推导本来就落在「只留转角」，而它的直边
// 只有 50 多像素、转角外的过渡几乎盖满整条边 —— 观感与「整圈均匀」无异，所以那边
// **不加**这个 uniform，别为了对称硬塞一个恒为 1 的旋钮。
//
// ── 折射截面（2026-09-19 起为圆弧） ──
// 位移沿深度的分布从幂函数换成**圆弧截面** `circleMap(e) = 1 - sqrt(1 - e²)`
// （Kyant0 Backdrop / iOS 26 液态玻璃同款）：它等价于「厚玻璃板倒了一圈的圆角
// 截面」，在贴边处斜率无穷大，高光与折射自然聚在最外 1~2px。旧的
// u_edge_pow 滑杆保留，语义不变（越大越集中在最外圈），但作为**圆弧之上的
// 陡缓指数**参与：`pow(circleMap(e), u_edge_pow / 2.5)` —— 默认 2.5 恰好是
// 纯圆弧（指数 1），老用户拖过的值仍在其原意方向上生效。课程卡那份用同一公式。
//
// ── 色散（chromatic dispersion） ──
// 折射带内把红、蓝两个采样点沿折射方向再错开 `push × u_dispersion`（绿不动），
// 读作玻璃边缘的彩虹镶边。u_dispersion = 0 时走单采样分支，与加色散前逐像素一致。
// 只在作用带内生效（push = 0 的内部恒走单采样），整屏成本不变。
//
// ── 穹顶（depth effect） ──
// u_dome > 0 时把折射方向往「从中心指向本像素」的径向偏，小圆件（常驻球、坞内
// 圆钮）的边缘读成凸面穹顶而不是平边。方向混合同 Kyant0：normalize(法线 + dome×径向)。
//
// ── 手指高光（press glow） ──
// u_pointer_glow ∈ [0,1] 为按压进度：以 u_pointer（屏幕物理 px）为中心的白色
// 柔光（半径 u_pointer_radius）+ 一层全面微亮，叠加在玻璃底色上、内容之下
// —— 强度写死在此文件里，不开放调参（「一种观感」铁律；可调的只有「有没有按着」）。
//
// ── 坐标系（三个事实，均有现场依据，勿凭直觉改） ──
// 1. FlutterFragCoord() 在**所有后端**都是「backdrop 层坐标系、y 向下、物理像素」，
//    也就是**屏幕物理像素**。依据：liquid_glass_widgets 0.30.2 的
//    shaders/gles_compat.glsl 末段明写「FlutterFragCoord() has always reported
//    Y-down fragment positions on every backend」，且 progressive_blur.frag 用
//    `FlutterFragCoord().xy - uRegionOriginPx` 取表面局部坐标，其 Dart 侧传的正是
//    `localToGlobal(Offset.zero) × dpr`；本仓每帧在跑的 inspire_blur 同口径
//    （inspire_backdrop_blur.dart 传 globalBounds × dpr）。
// 2. u_size 由**引擎自动填**（必须是第一个 vec2 uniform），值 = **绑定纹理**的尺寸
//    = 整个 backdrop（屏幕）的物理像素尺寸，不是本表面的尺寸。
// 3. 因此「表面局部物理像素」= FlutterFragCoord().xy - u_area_origin；
//    本文件所有长度 uniform（圆角、折射位移、作用带、高光带宽）一律是**物理像素**，
//    由 Dart 侧把逻辑值乘 dpr 传进来。
//
// ── 唯一需要 y 翻转的地方：采样背景纹理 ──
// Flutter < 3.46 的 GLES 后端把 render-to-texture 内容按左下原点存放（Metal/Vulkan
// 一直是左上），采样时要手动翻；3.46 起统一改为左上（flutter PR #186556），届时
// impellerc 会定义 IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED（PR #187316）宣告「已经翻过，
// 不要再翻」。本仓锁定 Flutter 3.44.8（.fvmrc），属于前者，所以保留翻转。
// 注意：这只影响**纹理采样**，不影响 FlutterFragCoord 的几何坐标（见上面第 1 条）。

out vec4 frag_color;

// 引擎自动填：绑定纹理尺寸（物理像素）。必须是本文件第一个 vec2 uniform。
uniform vec2 u_size;

// 引擎自动绑：滤镜输入 = 背景。必须是本文件第一个 sampler2D。
uniform sampler2D u_texture;

// 本表面在屏幕上的物理像素矩形。Dart 侧必须在 **paint 期**用
// localToGlobal(Offset.zero) × dpr 取值——build 期取到的偏移在拖动/滚动过程中
// 会一直过期（sheet 被拖、列表滚动都只触发重绘不触发重建）。
uniform vec2 u_area_origin;
uniform vec2 u_area_size;

// 视口（屏幕）的物理像素尺寸，由 Dart 侧传（MediaQuery.size × dpr）。
//
// 用途只有一条：**把采样点铰在屏幕内**。`compose` 内层的高斯模糊会把它的输出
// 按 3σ **往外扩边**（Skia/Impeller 的模糊滤波器都会 inflate 输出边界），
// 于是引擎填的 `u_size` 比屏幕大一圈，多出来的那圈**没有内容**。而着色器在玻璃
// 边缘恰恰是**往外**推着采样的：贴着屏幕边的玻璃（右上角那颗球离右边缘只有
// 9dp）往外一推，`uv` 还没到 1 就落进了那圈空区域 —— 读出来是空的，压在暗底上
// 就是一条黑边。模糊越大扩得越宽，所以「模糊调到 0 就没了」。
//
// 真机实测（回读像素）确认：扩边**不改变** FlutterFragCoord 与屏幕坐标的对应
// 关系（红标记落在 x<8/y<8、fract(y/128) 在两端都对得上），所以这里只铰采样，
// **不碰几何**——形状仍是 `local = FlutterFragCoord - u_area_origin`。
uniform vec2 u_view_size;

// 圆角半径（物理 px）。必须与外面裁剪用的圆角一致，否则 SDF 与裁剪对不上。
uniform float u_radius;

// 染色：直通 alpha。
uniform vec4 u_tint;

// 折射：u_band 是作用带宽度，u_refract 是边缘处的最大位移，
// u_edge_pow 是圆弧截面之上的陡缓指数（÷2.5 后参与，2.5 = 纯圆弧）。
uniform float u_refract;
uniform float u_band;
uniform float u_edge_pow;

// 色散强度（0..1）：红/蓝采样点沿折射方向错开 push × u_dispersion。
uniform float u_dispersion;

// 穹顶强度（0..1）：折射方向往「中心指向本像素」的径向偏转的比例。
uniform float u_dome;

// 手指高光：指针位置（屏幕物理 px）、按压进度（0..1）、光斑半径（物理 px）。
uniform vec2 u_pointer;
uniform float u_pointer_glow;
uniform float u_pointer_radius;

// 边缘高光：颜色 + 强度 + 带宽。**不看法线朝向**（见文件头）。
uniform vec3 u_rim_color;
uniform float u_rim;
uniform float u_rim_width;

// 边光的**作用范围**（0..1，见文件头第四轮）：
//   0 = 整圈均匀（细长条：底栏药丸、首页玻璃带 —— 它们的长边就是主体）；
//   1 = 只留转角（方正的大面板：底部弹窗、弹窗家族 —— 贯屏长直边上的高光只会
//       读成一条描边）。
// 由 Dart 侧按表面的长短边比推导（`liquidGlassRimCornerOnlyForSize`），是**几何
// 适配**、不是材质参数：表面自己没有通道把它传进来。
uniform float u_rim_corner_only;

// 圆角矩形有符号距离场：内部为负、边界为 0、外部为正。
//
// `q` 是中间量（`abs(p) - halfSize + r`）：边光的"转角度"要读它（见 `main()`），
// 所以一并交出去，别让两处各算一遍（改一处忘一处）。
float roundedBoxSDF(vec2 p, vec2 halfSize, float r, out vec2 q) {
  r = min(r, min(halfSize.x, halfSize.y));
  q = abs(p) - halfSize + r;
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

// 屏幕物理像素 → 背景 uv（含视口铰取与 GLES y 翻转）。
// 色散一次要采三个点，抽成函数避免三处各写一遍铰取/翻转。
vec2 backdropUv(vec2 sampleScreen) {
  if (u_view_size.x > 1.0 && u_view_size.y > 1.0) {
    sampleScreen = clamp(sampleScreen, vec2(0.0), u_view_size - 1.0);
  }
  vec2 uv = sampleScreen / max(u_size, vec2(1e-3));
#if defined(IMPELLER_TARGET_OPENGLES) && \
    !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
  uv.y = 1.0 - uv.y;
#endif
  return clamp(uv, vec2(0.0), vec2(1.0));
}

void main() {
  // 屏幕物理像素 → 表面局部物理像素（见文件头第 1、3 条）。
  vec2 screenPx = FlutterFragCoord().xy;
  vec2 local = screenPx - u_area_origin;

  vec2 halfSize = u_area_size * 0.5;
  vec2 centered = local - halfSize;

  // q 交给下面的边光判"这一段边界是不是圆弧"（见边光那段）。
  vec2 q;
  float sd = roundedBoxSDF(centered, halfSize, u_radius, q);

  // 抗锯齿：SDF 在边界 1px 内线性过渡。完全在形状外输出全透明——因为这是
  // backdrop filter，alpha 0 处会**透出未经滤镜的背景**，圆角就是这样出来的，
  // 不需要额外 ClipRRect 去裁滤镜层。
  float coverage = clamp(0.5 - sd, 0.0, 1.0);
  if (coverage <= 0.0) {
    frag_color = vec4(0.0);
    return;
  }

  // SDF 梯度 = 外法线。用有限差分算，角上自然过渡，不用分支。
  vec2 qGrad;
  vec2 grad = vec2(
    roundedBoxSDF(centered + vec2(1.0, 0.0), halfSize, u_radius, qGrad) - sd,
    roundedBoxSDF(centered + vec2(0.0, 1.0), halfSize, u_radius, qGrad) - sd
  );
  float gradLen = length(grad);
  vec2 normal = gradLen > 1e-5 ? grad / gradLen : vec2(0.0, -1.0);

  // 距边缘的深度（形状内部为正），越靠边越小。
  float depth = max(-sd, 0.0);

  // 折射位移：只在 u_band 以内生效，向外推开采样点 = 把表面外更远处的内容
  // 拉到边缘，读作凸透镜边缘的放大。截面是圆弧（见文件头）：
  // circleMap(1) = 1（贴边满位移）、circleMap(0) = 0（带内界归零）。
  float band = max(u_band, 1e-3);
  float edge = clamp(1.0 - depth / band, 0.0, 1.0);
  float profile = 1.0 - sqrt(max(1.0 - edge * edge, 0.0));
  float push = u_refract * pow(profile, max(u_edge_pow, 1e-3) * 0.4);

  // 折射方向：默认沿法线；开穹顶时往「中心 → 本像素」的径向混（见文件头）。
  // centered 在正中心长度为 0，除法用 max(..., 1e-3) 兜底防 NaN。
  vec2 dir = normal;
  if (u_dome > 1e-3) {
    vec2 radial = centered / max(length(centered), 1e-3);
    dir = normalize(normal + u_dome * radial);
  }

  // 采样背景：位置同样用屏幕物理像素表达，除以绑定纹理尺寸即得 uv。
  vec2 sampleScreen = screenPx + dir * push;
  vec3 base;
  {
    vec3 mid = texture(u_texture, backdropUv(sampleScreen)).rgb;
    // 色散：红沿折射方向多错开一点、蓝少错开一点（红在外蓝在内，与 Kyant0
    // 一致）。只在作用带内多付两次采样；内部 push = 0 恒走单采样。
    if (u_dispersion > 1e-3 && push > 1e-3) {
      vec2 spread = dir * push * u_dispersion;
      float r = texture(u_texture, backdropUv(sampleScreen + spread)).r;
      float b = texture(u_texture, backdropUv(sampleScreen - spread)).b;
      base = vec3(r, mid.g, b);
    } else {
      base = mid;
    }
  }

  // 染色（先混色再加高光，高光才不会被 tint 压掉）。
  vec3 tinted = mix(base, u_tint.rgb, clamp(u_tint.a, 0.0, 1.0));

  // 边缘高光：**只在 u_rim_corner_only 允许的地方出现**（见文件头第三、四轮）。
  //
  // 截面是**峰在带内**的鼓包，不是「贴边最亮、往里单调衰减」：贴边那一格正落在抗
  // 锯齿的半像素过渡带里（coverage 在那里从 0.5 起算），峰值压在那里时，这条亮线的
  // 亮度会随边界的亚像素相位跳变 —— 直边像素对齐、看不出来，斜着的圆角上相邻像素
  // 一亮一暗交替，就是一排锯齿。峰值内移到 0.35 × 带宽处之后，整条高光都落在
  // coverage = 1 的实心区里；贴边处亮度归零，也不会在边界上描出一条硬线。
  //
  // 权重按 SDF 的中间量 q 算：`q = abs(p) - halfSize + r` 的**较小者**就是「离最近
  // 那条切线的距离」—— 圆角弧上它是正的（两个分量同时为正），长直段上它随离开转角
  // 的距离越来越负。于是
  //     smoothstep(-w, 0, min(q.x, q.y))
  // 恰好是「转角度」：圆角满档、直段归零，中间 w 内平滑过渡（不留切点硬边）。
  //   * 圆 / 球：halfSize = r ⇒ q 两个分量恒非负 ⇒ 整圈满档，小圆件观感不变；
  //   * 药丸：**两端半圆与上下两条直边都满档** —— 见下面 u_rim_corner_only。
  // w 取 1.5 × 圆角半径：跟着半径缩放，不新增调参口子。
  //
  // 为什么还要按形状分档（真机口径「底栏高光只剩左右」）：药丸的上沿与
  // 底部弹窗的上沿**几何上是同一个东西** —— 都是三百多像素的长直边、圆角都是
  // 27/28。只按曲率判，任何一条规则都不可能让弹窗的上沿暗、同时让药丸的上沿亮；
  // 真机上量到的是两边都只剩左右各约 35px 亮着，药丸中间 220px 全黑。能分开它们
  // 的只有**这块面整体是细条还是方正的板**，所以加一个由 Dart 侧按长短边比推的
  // 系数，把「转角度」这条规则按形状淡入淡出。
  float rimT = clamp(depth / max(u_rim_width, 1e-3), 0.0, 1.0);
  float rimBand =
      smoothstep(0.0, 0.35, rimT) * (1.0 - smoothstep(0.35, 1.0, rimT));
  float cornerW = max(u_radius * 1.5, 2.0);
  float cornerness = smoothstep(-cornerW, 0.0, min(q.x, q.y));
  float rimWeight = mix(1.0, cornerness, u_rim_corner_only);
  float rim = u_rim * rimBand * rimWeight;
  vec3 lit = tinted + u_rim_color * rim;

  // 手指高光（见文件头）：中心白斑 + 全面微亮，都乘按压进度。
  // smoothstep 的两个 edge 必须递增（GLSL 规范：edge0 ≥ edge1 未定义），
  // 所以用 1 - smoothstep(内沿, 外沿) 表达「越近越亮」。
  if (u_pointer_glow > 1e-3) {
    float dist = length(screenPx - u_pointer);
    float glow = 1.0 - smoothstep(u_pointer_radius * 0.5, u_pointer_radius, dist);
    lit += vec3((glow * 0.15 + 0.06) * u_pointer_glow);
  }

  // 预乘 alpha 输出。
  frag_color = vec4(lit * coverage, coverage);
}
