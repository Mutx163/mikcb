#version 460 core
#include <flutter/runtime_effect.glsl>

// 柔光玻璃折射透镜。
//
// 直译 Hyper-PiliPlus（Deadliner）`GlassRefractionShader`
// （android/app/src/main/kotlin/com/aritxonly/deadliner/ui/material/glass/
//  GlassRefractionShader.kt）的光学位移 + 边缘高光部分：
// 球面透镜剖面 + 圆角矩形法线（混径向厚度）+ 方向性边缘高光 + 边缘色散 + 细颗粒噪声。
// 底色 tint 由 Dart 侧绘制——那里才知道当前是亮壁纸还是暗壁纸。
//
// ── 与上游的两处**有意**差异 ──────────────────────────────────────────
//
// 1. 我们多输出一层形状遮罩（上游不需要：Compose 的 `drawBackdrop(shape)` 已按
//    shape 裁好；而 `ImageFilter.shader` 作用于整屏 backdrop 快照，形状外必须由
//    shader 自己输出透明）。这条差异直接决定了下面几条硬规则的成立。
// 2. 边缘高光只画在 shader 内。上游在 shader 的 rim 高光之外，外层还有一道
//    `opticalGlassEdge` 的 0.5dp 上下渐变描边（= 我们的 `_SoftGlassEdgePainter`），
//    两者**叠加**；我们保持同样分工：shader 出方向性 rim，Dart 出 0.5dp 描边。
//
// ── 坐标契约（照抄本仓库已在用的 liquid_glass_widgets，同一台设备上跑通）──
//
// `ImageFilter.shader` 由引擎喂进来的信息只有两样（见 Impeller
// `runtime_effect_filter_contents.cc`）：
//   1. 首个 vec2 uniform 被写入 **被绑定纹理的尺寸**（`memcpy(uniforms_->data(),
//      &size, sizeof(Size))`）——注意那是 backdrop 快照的尺寸，**不是控件尺寸**；
//   2. 首个 sampler2D 被绑定为滤镜输入。
// 且 shader 的几何是 `FillRectGeometry(input_texture->GetSize())`，所以
// `FlutterFragCoord().xy / u_size` 得到的是**纹理 UV**（在 BackdropFilter 下
// 即屏幕 UV），不是控件局部 UV。控件在这张纹理里的位置必须由 Dart 侧另行
// 传入（u_geom，取全局逻辑坐标 × devicePixelRatio，在 paint 里实测）。
//
// 上游用 `content_origin` / `content_size` 定位控件，语义与这里的 `u_geom` 一致：
// 上游 `position - content_origin` ≡ 我们的 `FlutterFragCoord().xy - u_geom.xy`。
//
// 三条硬规则，缺一条就会渲染成「一块不透明黑」：
//   * 采样 UV 必须 clamp——Impeller 的采样器可能默认 Repeat，越界会绕到对侧
//     像素，产生反向法线与彩虹状撕裂；
//   * 输出必须是**预乘 alpha**，形状外输出透明；绝不能把 alpha 写成 1，否则
//     采样失败处会变成不透明黑块，再被底色一罩就是「白底灰、暗底黑」；
//   * 3.44/3.45 的 GLES 后端纹理自下而上存，采样要翻 y；3.46+ 后端已吸收该
//     差异（宏 IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED 存在），再翻就上下镜像。
//     注意这只影响**纹理采样**，`FlutterFragCoord()` 在所有后端都是 Y 向下。
//
// uniform 索引表（`FragmentShader.setFloat` 按下标写入，声明顺序即下标）：
//   0,  1  → u_size       引擎写入（纹理尺寸），勿设
//   2,  3  → u_geom       控件左上角（物理像素）
//   4,  5  → u_geom       控件尺寸（物理像素）
//   6,  7  → u_lens       折射带宽度 / 最大位移（**绝对物理像素**）
//   8,  9  → u_optics     色散偏移（**绝对物理像素**）/ 噪声系数
//   10, 11 → u_view       视图尺寸（物理像素），仅用于判断纹理是否已裁到控件
//   12     → u_corner     圆角半径（物理像素）
//   13     → u_depth      厚度感：法线里径向分量的权重（上游 depth_effect）
//   14     → u_highlight  rim 高光强度（上游 highlight_alpha，已按明暗折减）
//   15     → u_edgeGray   rim 高光灰度（上游 highlight_gray）
//
// 折射参数一律用**绝对物理像素**：上游 `GlassRefractionSpec` 就是 18dp / 18dp /
// 1dp 这样的绝对值，与控件尺寸无关。早先按「占控件高度的比例」表达（18/54），
// 只对 54dp 药丸成立——同一组比例套到大面板上会算出巨大的透镜，于是当时被迫加了
// 「面板不挂透镜」的尺寸闸门。改成绝对像素后，药丸、圆钮、弹层、面板都能挂同一套
// 透镜，闸门自然撤掉。
//
// 所有取值在 shader 内 clamp，即便 uniform 下标发生错位也不会渲染出灾难性结果。

uniform vec2 u_size;          // 引擎写入：backdrop 快照纹理尺寸（物理像素）
uniform vec4 u_geom;          // xy = 控件左上角，zw = 控件尺寸（物理像素）
uniform vec2 u_lens;          // x = 折射带宽（物理像素），y = 最大位移（物理像素）
uniform vec2 u_optics;        // x = 色散偏移（物理像素），y = 噪声系数
uniform vec2 u_view;          // 视图尺寸（物理像素）
uniform float u_corner;       // 圆角半径（物理像素）
uniform float u_depth;        // 厚度感：法线径向权重
uniform float u_highlight;    // rim 高光强度
uniform float u_edgeGray;     // rim 高光灰度

uniform sampler2D u_texture;

out vec4 frag_color;

// 圆角矩形有符号距离（与上游 roundedRectSdf 同一写法）。
float roundedRectSdf(vec2 coord, vec2 halfSize, float radius) {
  vec2 corner = abs(coord) - (halfSize - vec2(radius));
  float outside = length(max(corner, vec2(0.0))) - radius;
  float inside = min(max(corner.x, corner.y), 0.0);
  return outside + inside;
}

// 圆角矩形梯度 —— 法线的「边缘分量」。
//
// 直角区直接取归一化的角点向量；直边区退化成轴向（哪条边更近取哪条）。
// 这是上游与「纯径向法线」最大的分野：弹窗是宽矩形，用纯径向时，长边中点的
// 法线几乎是水平的，与真实边缘法线差出 90°，折射方向完全错位。
vec2 roundedRectGradient(vec2 coord, vec2 halfSize, float radius) {
  vec2 corner = abs(coord) - (halfSize - vec2(radius));
  if (corner.x >= 0.0 || corner.y >= 0.0) {
    return sign(coord) * normalize(max(corner, vec2(0.0)) + vec2(0.0001));
  }
  float horizontal = step(corner.y, corner.x);
  return sign(coord) * vec2(horizontal, 1.0 - horizontal);
}

// 球面透镜剖面（上游 circularLens）。
//
// x = 0（带内缘）→ 0；x = 1（贴边）→ 1，且越靠近贴边梯度越陡。
// 千万别用 smoothstep 代替：smoothstep 在半带宽处给 0.5，而球面剖面只给 0.134，
// 两者把同样的 18dp 位移摊成完全不同的形状 —— smoothstep 是弥散的一片，
// 球面剖面是紧贴边缘的一条锐利弯折。弥散版再被 0.675 的底色一罩就没了，
// 这正是「柔光玻璃看着和高斯一模一样」的直接原因。
float circularLens(float x) {
  x = clamp(x, 0.0, 1.0);
  return 1.0 - sqrt(max(1.0 - x * x, 0.0));
}

// 把「控件局部像素」换算成纹理 UV 并采样。
//
// origin 的判定：引擎给的是整屏快照（3.44 Impeller 的实际行为，也是
// liquid_glass_widgets 的前提）时，纹理原点在屏幕左上角，控件位置要减掉
// u_geom.xy；若某个后端把快照裁到了控件范围，则纹理原点就是控件原点，
// u_geom.xy 必须视为 0。后者等价于「纹理比视图小」，用一条比较即可分辨，
// 从而两种约定都能正确渲染。
vec4 sampleGlass(vec2 localPx) {
  vec2 origin = u_geom.xy;
  if (u_size.x < u_view.x - 1.0 || u_size.y < u_view.y - 1.0) {
    origin = vec2(0.0);
  }
  vec2 uv = (origin + localPx) / max(u_size, vec2(1.0));
#if defined(IMPELLER_TARGET_OPENGLES) && \
    !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
  uv.y = 1.0 - uv.y;
#endif
  return texture(u_texture, clamp(uv, vec2(0.001), vec2(0.999)));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;

  vec2 size = max(u_geom.zw, vec2(1.0));
  vec2 halfSize = size * 0.5;
  vec2 local = frag - u_geom.xy;
  vec2 centered = local - halfSize;

  // 圆角半径由 Dart 侧按实际形状传入（胶囊给短边一半，面板给它的 borderRadius），
  // 这里再夹一次：半径超过短边一半会让 SDF 翻转。
  float radius = clamp(u_corner, 0.0, min(halfSize.x, halfSize.y));
  float signedDistance = roundedRectSdf(centered, halfSize, radius);
  float innerDepth = max(-signedDistance, 0.0);

  // 形状遮罩，1 物理像素抗锯齿。形状外直接输出透明——不是黑。
  float mask = clamp(innerDepth + 0.5, 0.0, 1.0);
  if (mask <= 0.0) {
    frag_color = vec4(0.0);
    return;
  }

  // 绝对物理像素；clamp 只是防御（带/位移不该超过短边一半，色散不该超过 32px）。
  float limit = min(halfSize.x, halfSize.y);
  float band = clamp(u_lens.x, 0.0, max(limit, 0.001));
  float amount = clamp(u_lens.y, 0.0, limit);
  float chroma = clamp(u_optics.x, 0.0, 32.0);
  float noise = clamp(u_optics.y, 0.0, 0.2);
  float depth = clamp(u_depth, 0.0, 1.0);

  // 1 = 贴住边缘，0 = 离边缘一个带宽以外。球面剖面把位移压在贴边一小条上。
  float lensProgress = 1.0 - innerDepth / max(band, 0.001);
  float lens = circularLens(lensProgress);

  // 法线 = 边缘法线 + 径向 × 厚度权重，再归一化。
  //
  // 用 1.5 倍圆角算梯度是上游的做法：让法线在圆角外的直边段也平滑过渡，
  // 否则直边中点的梯度会在「水平/垂直」之间跳变，折射出现横向接缝。
  float gradientRadius = min(radius * 1.5, limit);
  vec2 normal = roundedRectGradient(centered, halfSize, gradientRadius);
  vec2 radial = centered / max(length(centered), 0.001);
  normal = normalize(normal + radial * depth + vec2(0.0001));

  // 位移方向取「由中心指向外」的反向 = 向内部取样。
  // 单向取样是刻意的：向外取样只会拿到控件外的像素，在贴边处拖出长条伪影。
  // 采样点再夹回控件范围（上游 sampleMin/sampleMax）——玻璃里只应看到玻璃内的内容，
  // 否则贴边的位移会把控件外的页面像素卷进来，边缘出现一圈「不属于这块玻璃」的颜色。
  vec2 refracted = clamp(local - normal * amount * lens, vec2(0.5), size - vec2(0.5));
  vec2 dispersion = normal * chroma * lens;

  vec3 color;
  color.r = sampleGlass(refracted - dispersion).r;
  color.g = sampleGlass(refracted).g;
  color.b = sampleGlass(refracted + dispersion).b;

  // 边缘方向性高光：rim 只覆盖贴边 12% 带宽，强度按法线与光照方向的夹角
  // 四次方加权（左上为光源）。左上/右下因此一亮一暗，这才是「玻璃边缘」的样子。
  // 等强度的整圈描边读作塑料壳——这与 Dart 侧那道 0.5dp 上下渐变描边是两回事，
  // 两者叠加才等于上游的完整边缘。
  float edgeWidth = max(1.0, band * 0.12);
  float rim = 1.0 - smoothstep(0.0, edgeWidth, innerDepth);
  vec2 lightDirection = normalize(vec2(-0.58, -0.82));
  float directional = pow(abs(dot(normal, lightDirection)), 4.0);
  float edgeLight = clamp(u_highlight, 0.0, 1.0) * rim * (0.30 + directional * 0.70);
  color = mix(color, vec3(clamp(u_edgeGray, 0.0, 1.0)), edgeLight);

  // 细颗粒：原版 noiseCoefficient 0.095，作用是给玻璃面一点「实体感」，
  // 不至于像一块干净的塑料。系数很小，肉眼是极细的砂感。
  float grain = fract(sin(dot(frag, vec2(12.9898, 78.233))) * 43758.5453);
  color += (grain - 0.5) * noise * 0.6;

  color = clamp(color, 0.0, 1.0);
  frag_color = vec4(color * mask, mask);
}
