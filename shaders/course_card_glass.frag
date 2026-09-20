#version 460 core
#include <flutter/runtime_effect.glsl>

// 课程卡片「液态玻璃」：在**共享的预模糊壁纸**上做圆角矩形边缘折射 + 染色 + 边缘高光。
//
// 与「高斯模糊」档的分工：
//   * 高斯档只把背景糊掉，卡片读作「磨砂塑料」；
//   * 这里额外按圆角 SDF 把边缘附近的采样点朝卡片外侧推开，形成真实玻璃那种
//     「边缘把背景掰弯」的透镜感，再叠一条**整圈均匀**的边缘高光（2026-09-20
//     与 glass_surface_refraction.frag 同口径：不看法线朝向）。
//
// ── 边光为什么**整圈均匀**、而全局那份多一个「只留转角」的开关 ──
//
// 全局表面（glass_surface_refraction.frag）有 `u_rim_corner_only`：细长条走整圈
// 均匀、方正的大面板**只留转角**（贯屏长直边上的一条高光只会读成描边）。这一份
// 曾经照抄过「只留转角」，2026-09-20 撤掉，真机口径是「四个角有白线，上下左右都
// 没有」。撤掉的理由是**实测那条规则在卡片上一定退化成四个白钩**：判「转角度」的
// 过渡宽度取 1.5 × 圆角半径（r=8 → 12px、r=12 → 18px，与卡片多大无关），而卡片
// 每条直边都短，中点到最近转角的距离远超这个宽度 —— 实算权重（顶边中点 / 左边
// 中点）：
//   * 45×130、r8（周视图一格）  → 0.000 / 0.000，有光的只有离转角 18px 那截；
//   * 51×130、r8                → 0.000 / 0.000；
//   * 340×88、r12（日视图全宽卡）→ 0.000 / 0.000，顶边 158px 的直段全黑；
//   * 49×62、r8（单节课卡）     → 0.000 / 0.000。
// 也就是说「转角外的过渡几乎盖满整条边」这个前提从来不成立，只剩四条互不相连的
// 角上高光。而卡片本来也没有贯屏长直边（周视图 130px、日视图 316px 但只有 88px
// 高、按长短边比就是「细长条」），所以直接取全局那一侧的「整圈均匀」读数。
//
// ⚠️ 将来卡片真出现「又宽又方正」的形态（贯屏宽 + 高到长短边比 ≤1.6）时，
// **把全局那份的 `u_rim_corner_only` 接过来**，由 Dart 侧用
// `liquidGlassRimCornerOnlyForSize` 推，不要在这里另发明一套判据。
//
// 性能口径（这是这个 shader 存在的理由）：输入的 u_texture 是**整屏唯一一份**
// 预模糊壁纸（PreblurredWallpaperCache 出图，全部卡片共用同一张 ui.Image）。
// 每张卡只做「一次矩形绘制 + 一次纹理采样 + 几次 SDF」，没有离屏渲染目标、
// 没有 GPU 回读、没有实时 BackdropFilter。所以卡片数量翻倍也不改变 GPU 工作量级。
//
// 坐标系：FlutterFragCoord() 取的是**本次绘制的局部坐标**——Impeller 的运行时特效
// 顶点着色器直接把顶点 position 传下来（engine/.../impeller/entity/shaders/
// runtime_effect.vert: `_fragCoord = position`），所以先 canvas.translate(卡片原点)
// 再 drawRect(Offset.zero & size)，取到的就是 0..size。miuix OS4 玻璃用的同一套
// 写法（它多减一个 in_pad 把坐标挪回组件原点）。因此所有 uniform 一律用逻辑像素，
// 由 Dart 侧传卡片尺寸、纹理在卡片局部坐标里的位置与绘制尺寸。
//
// 注：AndroidManifest 里 EnableImpeller=true 是硬性前置（实时背景模糊本来就要
// Impeller），所以这里不需要考虑 Skia 后端下 FlutterFragCoord 的差异。

out vec4 frag_color;

// 共享预模糊壁纸（cover 对齐整屏，卡片是它的一个移动窗口）。
uniform sampler2D u_texture;

// 卡片逻辑尺寸。
uniform vec2 u_size;

// 纹理 (0,0) 在卡片局部坐标里的位置，以及纹理被绘制出来的逻辑尺寸。
// uv = (局部采样点 - u_tex_origin) / u_tex_dest_size
uniform vec2 u_tex_origin;
uniform vec2 u_tex_dest_size;

// 圆角半径（逻辑 px）。必须与 Dart 侧给卡片的圆角一致，否则 SDF 与裁剪对不上。
uniform float u_radius;

// 染色：直通 alpha 的课程色，a 已含 conflict/holiday 的 opacityScale。
uniform vec4 u_tint;

// 折射：u_band 是作用带宽度，u_refract 是边缘处的最大位移，
// u_edge_pow 是圆弧截面之上的陡缓指数（÷2.5 后参与，2.5 = 纯圆弧）。
uniform float u_refract;
uniform float u_band;
uniform float u_edge_pow;

// 边缘高光：颜色 + 强度 + 带宽。**一圈均匀**，不看法线朝向（与 glass_surface_refraction.frag
// 同口径：2026-09-20 去掉方向性，长直边与圆角天然一致）。
uniform vec3 u_rim_color;
uniform float u_rim;
uniform float u_rim_width;

// 圆角矩形有符号距离场：内部为负、边界为 0、外部为正。
float roundedBoxSDF(vec2 p, vec2 halfSize, float r) {
  r = min(r, min(halfSize.x, halfSize.y));
  vec2 q = abs(p) - halfSize + r;
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 halfSize = u_size * 0.5;
  vec2 centered = p - halfSize;

  float sd = roundedBoxSDF(centered, halfSize, u_radius);

  // 抗锯齿：SDF 在边界 1px 内线性过渡。完全在形状外直接丢弃。
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

  // 折射位移：只在 u_band 以内生效，向外推开采样点 = 把卡片外更远处的内容
  // 拉到边缘，读作凸透镜边缘的放大。截面是**圆弧** `circleMap(e) = 1-√(1-e²)`
  // （Kyant0 Backdrop / iOS 26 同款，厚玻璃板倒圆角的截面），与全局液态玻璃
  // 表面那份逐字同源——u_edge_pow 除以默认值 2.5 后作为圆弧之上的陡缓指数，
  // 默认档恰好是纯圆弧。改截面必须两份 .frag 同步改，否则两边观感分叉。
  float band = max(u_band, 1e-3);
  float edge = clamp(1.0 - depth / band, 0.0, 1.0);
  float profile = 1.0 - sqrt(max(1.0 - edge * edge, 0.0));
  float push = u_refract * pow(profile, max(u_edge_pow, 1e-3) * 0.4);

  vec2 sampleLocal = p + normal * push;
  vec2 uv = (sampleLocal - u_tex_origin) /
      max(u_tex_dest_size, vec2(1e-3, 1e-3));
  uv = clamp(uv, vec2(0.0), vec2(1.0));

  vec3 base = texture(u_texture, uv).rgb;

  // 染色（先混色再加高光，高光才不会被 tint 压掉）。
  vec3 tinted = mix(base, u_tint.rgb, clamp(u_tint.a, 0.0, 1.0));

  // 边缘高光：**整圈均匀**，不看这一段的边界是不是圆弧（与
  // glass_surface_refraction.frag 的「细长条」那一侧同口径）。
  //
  // 截面是「峰在带内」的鼓包：贴边那一格落在抗锯齿的半像素过渡带里（coverage 从 0.5
  // 起算），峰值压在那里会让亮线的亮度随边界相位跳变 —— 直边看不出来，斜着的圆角上
  // 就是一排锯齿。峰值内移到 0.35 × 带宽处之后，整条高光都落在 coverage = 1 的实心
  // 区里；贴边处亮度归零，也不会在边界上描出一条硬线。
  float rimT = clamp(depth / max(u_rim_width, 1e-3), 0.0, 1.0);
  float rimBand =
      smoothstep(0.0, 0.35, rimT) * (1.0 - smoothstep(0.35, 1.0, rimT));
  float rim = u_rim * rimBand;
  vec3 lit = tinted + u_rim_color * rim;

  // 预乘 alpha 输出。
  frag_color = vec4(lit * coverage, coverage);
}
