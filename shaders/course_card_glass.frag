#version 460 core
#include <flutter/runtime_effect.glsl>

// 课程卡片「液态玻璃」：在**共享的预模糊壁纸**上做圆角矩形边缘折射 + 染色 + 边缘高光。
//
// 与「高斯模糊」档的分工：
//   * 高斯档只把背景糊掉，卡片读作「磨砂塑料」；
//   * 这里额外按圆角 SDF 把边缘附近的采样点朝卡片外侧推开，形成真实玻璃那种
//     「边缘把背景掰弯」的透镜感，再叠一条带方向的边缘高光。
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
// u_edge_pow 控制位移沿边缘上升的陡缓（越大越集中在最外圈）。
uniform float u_refract;
uniform float u_band;
uniform float u_edge_pow;

// 边缘高光：颜色 + 强度 + 带宽 + 光来向（卡片局部坐标，y 向下）。
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
  // 拉到边缘，读作凸透镜边缘的放大。
  float band = max(u_band, 1e-3);
  float edge = clamp(1.0 - depth / band, 0.0, 1.0);
  float push = u_refract * pow(edge, max(u_edge_pow, 1e-3));

  vec2 sampleLocal = p + normal * push;
  vec2 uv = (sampleLocal - u_tex_origin) /
      max(u_tex_dest_size, vec2(1e-3, 1e-3));
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
