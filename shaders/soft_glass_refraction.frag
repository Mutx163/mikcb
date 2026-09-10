#version 460 core
#include <flutter/runtime_effect.glsl>

// 柔光玻璃折射透镜。
//
// 直译 Hyper-PiliPlus（Deadliner）`GlassRefractionShader` 的光学位移部分：
// 向内折射位移 + 边缘色散 + 细颗粒噪声。底色 tint 与镜面边缘高光由 Dart 侧
// 绘制——那里才知道当前是亮壁纸还是暗壁纸。
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
//   6,  7  → u_lens       折射带宽度 / 最大位移，均按控件高度取比例
//   8,  9  → u_optics     色散偏移比例 / 噪声系数
//   10, 11 → u_view       视图尺寸（物理像素），仅用于判断纹理是否已裁到控件
//
// 之所以把折射参数表达成「占高比例」而不是像素：本 shader 只在 54dp 药丸与
// 56dp 圆钮这类小尺寸表面启用，几何全部可由 u_geom 推出，无需传入 dpr。
// 所有取值在 shader 内 clamp，即便 uniform 下标发生错位也不会渲染出灾难性结果。

uniform vec2 u_size;   // 引擎写入：backdrop 快照纹理尺寸（物理像素）
uniform vec4 u_geom;   // xy = 控件左上角，zw = 控件尺寸（物理像素）
uniform vec2 u_lens;   // x = 折射带宽占高比例，y = 最大位移占高比例
uniform vec2 u_optics; // x = 色散偏移占高比例，y = 噪声系数
uniform vec2 u_view;   // 视图尺寸（物理像素）

uniform sampler2D u_texture;

out vec4 frag_color;

float sdRoundRect(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + vec2(radius);
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
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
  vec2 p = local - halfSize;

  // 柔光玻璃面在 UI 上一律是胶囊/圆角形，几何按胶囊处理：半径取短边一半。
  float radius = min(halfSize.x, halfSize.y);
  float edgeDistance = -sdRoundRect(p, halfSize, radius);

  // 形状遮罩，1 物理像素抗锯齿。形状外直接输出透明——不是黑。
  float mask = clamp(edgeDistance + 0.5, 0.0, 1.0);
  if (mask <= 0.0) {
    frag_color = vec4(0.0);
    return;
  }

  float band = clamp(u_lens.x, 0.0, 0.5) * size.y;
  float amount = clamp(u_lens.y, 0.0, 0.5) * size.y;
  float chroma = clamp(u_optics.x, 0.0, 0.05) * size.y;
  float noise = clamp(u_optics.y, 0.0, 0.2);

  // 0 = 远离边缘，1 = 贴住边缘。smoothstep 化让折弯集中在近边一带。
  float lens = band > 0.0 ? clamp(1.0 - edgeDistance / band, 0.0, 1.0) : 0.0;
  lens = lens * lens * (3.0 - 2.0 * lens);

  // 位移方向取「由中心指向外」的反向 = 向内部取样。
  // 单向取样是刻意的：向外取样只会拿到控件外的像素，在贴边处拖出长条伪影。
  vec2 direction = normalize(p + vec2(0.0001, 0.0001));
  vec2 shift = -direction * (amount * lens);
  vec2 chromaShift = direction * (chroma * lens);

  vec2 basePx = local + shift;
  vec3 color;
  color.r = sampleGlass(basePx + chromaShift).r;
  color.g = sampleGlass(basePx).g;
  color.b = sampleGlass(basePx - chromaShift).b;

  // 细颗粒：原版 noiseCoefficient 0.095，作用是给玻璃面一点「实体感」，
  // 不至于像一块干净的塑料。系数很小，肉眼是极细的砂感。
  float grain = fract(sin(dot(frag, vec2(12.9898, 78.233))) * 43758.5453);
  color += (grain - 0.5) * noise * 0.6;

  color = clamp(color, 0.0, 1.0);
  frag_color = vec4(color * mask, mask);
}
