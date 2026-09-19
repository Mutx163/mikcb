#version 460 core
#include <flutter/runtime_effect.glsl>

// 全局「液态玻璃」表面：在**实时背景**上做圆角矩形边缘折射 + 染色 + 受光边缘高光。
//
// 与 course_card_glass.frag 的关系：折射数学（圆角 SDF、有限差分法线、边缘推力、
// 方向性高光、预乘输出）逐字同源，差别只在**输入来源与坐标系**：
//   * 卡片吃的是「共享的预模糊壁纸位图」，卡片是它的一个移动窗口（u_tex_origin 映射）；
//   * 这里吃的是引擎给的**实时背景快照**（BackdropFilter 的滤镜输入），全屏对齐，
//     所以不需要窗口映射。
// 两条路共用同一套数学，是为了守住「同一个材质只有一种观感」这条硬规则：任何表面
// 都不得自带一套折射参数（历史教训见
// lib/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart 顶部注释）。
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

// 圆角半径（物理 px）。必须与外面裁剪用的圆角一致，否则 SDF 与裁剪对不上。
uniform float u_radius;

// 染色：直通 alpha。
uniform vec4 u_tint;

// 折射：u_band 是作用带宽度，u_refract 是边缘处的最大位移，
// u_edge_pow 控制位移沿边缘上升的陡缓（越大越集中在最外圈）。
uniform float u_refract;
uniform float u_band;
uniform float u_edge_pow;

// 边缘高光：颜色 + 强度 + 带宽 + 光来向（屏幕坐标，y 向下）。
uniform vec3 u_rim_color;
uniform float u_rim;
uniform float u_rim_width;
uniform vec2 u_light_dir;

// 圆角矩形有符号距离场：内部为负、边界为 0、外部为正。
float roundedBoxSDF(vec2 p, vec2 halfSize, float r) {
  r = min(r, min(halfSize.x, halfSize.y));
  vec2 q = abs(p) - halfSize + r;
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

// ⚠️ 临时探针开关（2026-09-19，量完即撤；切换前先看 `lib/ui/debug/liquid_glass_uv_probe.dart`）。
// 置 1 时不着色，改成输出一张「能读出坐标」的图：
//   * 红：FlutterFragCoord 的 x 或 y 小于 8 —— 标记**绑定纹理的原点**在哪；
//   * 绿：fract(FlutterFragCoord().y / 128) —— 从相位反推纹理原点相对屏幕的偏移。
uniform float u_probe;

void main() {
  if (u_probe > 0.5) {
    vec2 fc = FlutterFragCoord().xy;
    float marker = (fc.x < 8.0 || fc.y < 8.0) ? 1.0 : 0.0;
    frag_color = vec4(marker, fract(fc.y / 128.0), 0.0, 1.0);
    return;
  }

  // 屏幕物理像素 → 表面局部物理像素（见文件头第 1、3 条）。
  vec2 screenPx = FlutterFragCoord().xy;
  vec2 local = screenPx - u_area_origin;

  vec2 halfSize = u_area_size * 0.5;
  vec2 centered = local - halfSize;

  float sd = roundedBoxSDF(centered, halfSize, u_radius);

  // 抗锯齿：SDF 在边界 1px 内线性过渡。完全在形状外输出全透明——因为这是
  // backdrop filter，alpha 0 处会**透出未经滤镜的背景**，圆角就是这样出来的，
  // 不需要额外 ClipRRect 去裁滤镜层。
  float coverage = clamp(0.5 - sd, 0.0, 1.0);
  if (coverage <= 0.0) {
    frag_color = vec4(0.0);
    return;
  }

  // SDF 梯度 = 外法线。用有限差分算，角上自然过渡，不用分支。
  vec2 grad = vec2(
    roundedBoxSDF(centered + vec2(1.0, 0.0), halfSize, u_radius) - sd,
    roundedBoxSDF(centered + vec2(0.0, 1.0), halfSize, u_radius) - sd
  );
  float gradLen = length(grad);
  vec2 normal = gradLen > 1e-5 ? grad / gradLen : vec2(0.0, -1.0);

  // 距边缘的深度（形状内部为正），越靠边越小。
  float depth = max(-sd, 0.0);

  // 折射位移：只在 u_band 以内生效，向外推开采样点 = 把表面外更远处的内容
  // 拉到边缘，读作凸透镜边缘的放大。
  float band = max(u_band, 1e-3);
  float edge = clamp(1.0 - depth / band, 0.0, 1.0);
  float push = u_refract * pow(edge, max(u_edge_pow, 1e-3));

  // 采样背景：位置同样用屏幕物理像素表达，除以绑定纹理尺寸即得 uv。
  vec2 sampleScreen = screenPx + normal * push;
  vec2 uv = sampleScreen / max(u_size, vec2(1e-3));
#if defined(IMPELLER_TARGET_OPENGLES) && \
    !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
  uv.y = 1.0 - uv.y;
#endif
  uv = clamp(uv, vec2(0.0), vec2(1.0));

  vec3 base = texture(u_texture, uv).rgb;

  // 染色（先混色再加高光，高光才不会被 tint 压掉）。
  vec3 tinted = mix(base, u_tint.rgb, clamp(u_tint.a, 0.0, 1.0));

  // 边缘高光：按法线与光来向的夹角加权，左上亮、右下暗，
  // 这样玻璃才有「受光方向」而不是一圈均匀描边。
  float rimBand = clamp(1.0 - depth / max(u_rim_width, 1e-3), 0.0, 1.0);
  float facing = clamp(dot(normal, normalize(u_light_dir)), 0.0, 1.0);
  float rim = u_rim * rimBand * rimBand * mix(0.35, 1.0, facing);
  vec3 lit = tinted + u_rim_color * rim;

  // 预乘 alpha 输出。
  frag_color = vec4(lit * coverage, coverage);
}
