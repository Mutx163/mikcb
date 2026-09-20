import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_shader.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';
import 'package:university_timetable/widgets/course_glass_shader.dart';

/// 模拟的「屏幕」尺寸 = 绑定纹理尺寸 = 着色器里的 `u_size`。
const Size _screenSize = Size(200, 200);

/// 本表面在屏幕上的位置与尺寸 = `u_area_origin` / `u_area_size`。
const Offset _surfaceOrigin = Offset(50, 50);
const Size _surfaceSize = Size(100, 100);

const LiquidGlassStyle _style = LiquidGlassStyle(
  borderRadius: 20,
  tint: Color(0x00000000),
);

void main() {
  group('液态玻璃表面着色器契约', () {
    test('资产已声明且文件存在', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec.contains('- shaders/glass_surface_refraction.frag'),
        isTrue,
        reason: '着色器没在 pubspec 的 flutter.shaders 里声明，运行时取不到资产',
      );
      expect(
        File(LiquidGlassSurfaceShader.instance.assetKey).existsSync(),
        isTrue,
        reason: '声明的资产键必须对应一个真实文件',
      );
    });

    test('着色器能编译，且 Dart 侧解析的每个 uniform 名字都存在', () async {
      await LiquidGlassSurfaceShader.instance.ensureLoaded();
      expect(
        LiquidGlassSurfaceShader.instance.isLoaded,
        isTrue,
        reason: '着色器编译失败（语法错误 / 缺 uniform 声明）会静默降级成基础材质，'
            '这里必须红',
      );
      final shader = LiquidGlassSurfaceShader.instance.newShader();
      expect(shader, isNotNull);
      // 名字错一个就抛 ArgumentError —— 这是「改 .frag 忘了改 Dart」的唯一
      // 自动化拦截点（绘制期才炸，真机上才看得见）。
      debugValidateLiquidGlassUniforms(shader!);
      shader.dispose();
    });

    test('与卡片那份是两个独立程序，资产键不同', () {
      expect(
        LiquidGlassSurfaceShader.instance.assetKey,
        isNot(CourseCardGlassShader.instance.assetKey),
        reason: '卡片吃预模糊位图、按局部坐标画；这一份吃实时背景、按屏幕坐标画，'
            '两个程序不能互相顶替',
      );
    });
  });

  group('LiquidGlassStyle', () {
    test('同值相等，可作为 RenderObject 的更新判据', () {
      const a = LiquidGlassStyle(borderRadius: 12, tint: Color(0x552196F3));
      const b = LiquidGlassStyle(borderRadius: 12, tint: Color(0x552196F3));
      const c = LiquidGlassStyle(borderRadius: 8, tint: Color(0x552196F3));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    test('逻辑长度按 dpr 换算成物理像素', () {
      const style = LiquidGlassStyle(
        borderRadius: 12,
        tint: Color(0xFF000000),
      );
      final at2 = style.scaledLengths(2);
      expect(at2.radius, 24);
      expect(at2.refract, 16);
      expect(at2.band, 14);
      expect(at2.rimWidth, 3);
      // dpr 为 1 时换算必须是恒等，否则桌面/低密度设备上玻璃会整体缩水。
      final at1 = style.scaledLengths(1);
      expect(at1.radius, 12);
      expect(at1.refract, 8);
      expect(at1.band, 7);
      expect(at1.rimWidth, 1.5);
      // 祖先缩放（入场变形动画）也要一起乘：着色器里的坐标是屏幕物理像素，表面被
      // 缩放时它在屏幕上占的范围也缩了，长度不跟着缩就会出现「形状满尺寸、面板
      // 已经缩到很小」——面板角落落在形状外，透出下面的压暗蒙层（开合时发黑）。
      final shrunk = style.scaledLengths(2, scale: 0.25);
      expect(shrunk.radius, 6);
      expect(shrunk.refract, 4);
      expect(shrunk.band, 3.5);
      expect(shrunk.rimWidth, 0.75);
    });

    test('折射旋钮的默认值与课程卡片液态玻璃档逐字段一致', () {
      // 「同一个材质只有一种观感」：全局液态玻璃与卡片液态玻璃出厂必须长得一样，
      // 否则用户会在两个页面看到两种玻璃。任何一边改默认值都必须同步另一边。
      const card = CourseGlassStyle(borderRadius: 12, tint: Color(0xFF000000));
      expect(_style.refraction, card.refraction);
      expect(_style.refractionBand, card.refractionBand);
      expect(_style.refractionEdgePow, card.refractionEdgePow);
      expect(_style.rimStrength, card.rimStrength);
      expect(_style.rimWidth, card.rimWidth);
      expect(_style.rimColor, card.rimColor);
    });
  });

  // ── 绘制结果 ─────────────────────────────────────────────────────────────
  //
  // 上面几组只证明「uniform 名字对得上、参数换算对」，不证明「画出来是对的」。
  // 这一组把着色器真画进位图再读像素。
  //
  // 场景刻意与真机同构：绑定纹理是**整屏**（200x200），本表面只是它上面
  // 100x100 的一块（origin 50,50）—— 这正是 `BackdropFilter` 的形态，也是这一份
  // 着色器与卡片那份最大的口径差别（卡片按局部坐标画、自己映射纹理窗口）。
  //
  // 所有坐标推算都按「像素中心在 +0.5」来（Impeller 与本地测试后端同一口径）。
  group('液态玻璃表面着色器绘制结果', () {
    test('玻璃只落在 u_area_origin 指定的屏幕矩形里，圆角外全透明', () async {
      final texture = await _screenTexture(
        (canvas) => canvas.drawRect(
          Rect.fromLTWH(0, 0, _screenSize.width, _screenSize.height),
          ui.Paint()..color = const Color(0xFF3366AA),
        ),
      );
      addTearDown(texture.dispose);

      final bytes = await _renderSurface(texture: texture);

      // 表面中心：不透明且就是背景。
      expect(_pixel(bytes, 100, 100), const Color(0xFF3366AA));
      // 半径 20 的圆角把 (51,51) 切在形状外。
      expect(_pixel(bytes, 51, 51).a, 0);
      // 表面矩形之外（左上角、右侧、下方）一律透明 —— 说明 SDF 是相对
      // u_area_origin/u_area_size 算的，而不是相对这次绘制的矩形算的。
      expect(_pixel(bytes, 10, 10).a, 0);
      expect(_pixel(bytes, 195, 100).a, 0);
      expect(_pixel(bytes, 100, 195).a, 0);
    });

    test('贴着屏幕边缘时，折射采样被铰回屏内（不读进模糊扩出来的空区）', () async {
      // 真机机制：`compose` 内层模糊把绑定纹理按 3σ 往外扩一圈，扩出来那圈
      // **没有内容**；而玻璃在边缘是把采样点往外推的。贴着屏幕边的玻璃（首页右上
      // 角那颗球离右边缘只有 9dp）往外一推就落进那圈空区，读出来是空的 —— 压在暗
      // 底上就是一条黑边；模糊归零、不扩边，它就消失。
      //
      // 真机回读已确认：扩边**不改变** FlutterFragCoord 与屏幕坐标的对应，所以这里
      // 只铰采样、不碰几何。测试把那个形态摆出来：纹理比视口大 2×pad，「内容」只铺
      // 在视口那块（绿），多出来的扩边区涂红当标记。表面贴到视口右缘并开折射 ——
      // 采样若不被铰住就会读到红，铰住之后必须还是绿。
      const pad = 12.0;
      final expandedSize = Size(
        _screenSize.width + pad * 2,
        _screenSize.height + pad * 2,
      );
      final texture = await _screenTexture(
        (canvas) {
          // 先铺满红（= 扩边那圈没有内容），再把内容区盖成绿。
          canvas.drawRect(
            Offset.zero & expandedSize,
            ui.Paint()..color = const Color(0xFFFF0000),
          );
          canvas.drawRect(
            Offset.zero & _screenSize,
            ui.Paint()..color = const Color(0xFF00FF00),
          );
        },
        size: expandedSize,
      );
      addTearDown(texture.dispose);

      final bytes = await _renderSurface(
        texture: texture,
        expand: pad,
        viewSize: _screenSize,
        // 表面贴到视口右缘：x ∈ [100, 200)。
        surfaceOrigin: const Offset(100, 50),
        surfaceSize: const Size(100, 100),
        refract: 8,
      );

      final stride = expandedSize.width.round();
      // 表面右缘那一列：折射把它往外推几像素（越出视口）。铰住 → 仍是屏内的绿。
      expect(
        _pixel(bytes, 199, 100, width: stride),
        const Color(0xFF00FF00),
        reason: '贴着屏幕边缘的折射采样必须铰回屏内，不能读进模糊扩出来的空区',
      );
      // 对照：表面内部不参与折射，本来就读到绿。
      expect(
        _pixel(bytes, 150, 100, width: stride),
        const Color(0xFF00FF00),
      );
    });

    test('表面是整屏纹理的一个窗口，不是把纹理拉伸铺满自己', () async {
      // 纹理 x<50 红、[50,175) 绿、≥175 蓝。表面窗口落在 x∈[50,150]，
      // 所以表面内几乎全是绿。若哪天 u_area_origin 被漏掉（退化成
      // uv = 表面内坐标 / 表面尺寸），表面右部会读到蓝。
      final texture = await _screenTexture(_stripedScreen);
      addTearDown(texture.dispose);

      final bytes = await _renderSurface(texture: texture);

      expect(_pixel(bytes, 60, 100), const Color(0xFF00FF00));
      expect(_pixel(bytes, 100, 100), const Color(0xFF00FF00));
      expect(_pixel(bytes, 148, 100), const Color(0xFF00FF00));
    });

    test('折射把表面外的内容拉进边缘，且只在作用带内生效', () async {
      // 同上纹理。左缘（屏幕 x=50）往左推几 px 就会越过红/绿分界 ——
      // 正是「边缘把背景掰弯」在像素上的样子。
      final texture = await _screenTexture(_stripedScreen);
      addTearDown(texture.dispose);

      final off = await _renderSurface(texture: texture);
      final on = await _renderSurface(texture: texture, refract: 8);

      expect(_pixel(off, 51, 100), const Color(0xFF00FF00));
      expect(
        _pixel(on, 51, 100),
        const Color(0xFFFF0000),
        reason: '关折射读表面内的绿，开折射该读到表面外的红',
      );
      // 作用带只有 7px：表面中心与更靠里处必须逐位一致，否则就是整块在位移。
      expect(_pixel(on, 100, 100), _pixel(off, 100, 100));
      expect(_pixel(on, 140, 100), _pixel(off, 140, 100));
    });

    test('染色按 sRGB 分量直通，不做色彩空间转换', () async {
      // u_tint 直接吃 Color.r/g/b（sRGB 编码值）。若引擎把着色器输出当线性值
      // 再编码一次，颜色会整体变亮（0.5 灰会从 128 变 188）。
      final texture = await _screenTexture(
        (canvas) => canvas.drawRect(
          Rect.fromLTWH(0, 0, _screenSize.width, _screenSize.height),
          ui.Paint()..color = const Color(0xFF000000),
        ),
      );
      addTearDown(texture.dispose);

      final bytes = await _renderSurface(
        texture: texture,
        tint: const Color(0xFF2196F3),
      );

      final pixel = _pixel(bytes, 100, 100);
      expect((pixel.r * 255).round(), closeTo(0x21, 1));
      expect((pixel.g * 255).round(), closeTo(0x96, 1));
      expect((pixel.b * 255).round(), closeTo(0xF3, 1));
      expect(pixel.a, 1.0);
    });

    test('色散把红/蓝采样沿折射方向错开，绿通道始终取中档', () async {
      // 左半屏品红（r=1,b=1）、右半屏纯绿（g=1）。探针 (51,100) 开折射后中档
      // 采样落左半屏（品红）；色散开满时红档再往外（仍是品红）、蓝档往回收进
      // 绿区（b=0）——基色从品红 (1,0,1) 变成红 (1,0,0)。
      final texture = await _screenTexture(
        (canvas) {
          canvas.drawRect(
            const Rect.fromLTWH(0, 0, 50, 200),
            ui.Paint()..color = const Color(0xFFFF00FF),
          );
          canvas.drawRect(
            const Rect.fromLTWH(50, 0, 150, 200),
            ui.Paint()..color = const Color(0xFF00FF00),
          );
        },
      );
      addTearDown(texture.dispose);

      final off = await _renderSurface(texture: texture, refract: 8);
      final on = await _renderSurface(
        texture: texture,
        refract: 8,
        dispersion: 1,
      );

      final offPixel = _pixel(off, 51, 100);
      expect((offPixel.r * 255).round(), 255);
      expect(
        (offPixel.b * 255).round(),
        255,
        reason: '关色散时该点读品红',
      );
      final onPixel = _pixel(on, 51, 100);
      expect((onPixel.r * 255).round(), 255);
      expect(
        (onPixel.b * 255).round(),
        0,
        reason: '开色散后蓝档采进绿区，蓝通道必须归零',
      );
      expect(
        (onPixel.g * 255).round(),
        0,
        reason: '绿通道取中档采样（品红），不得被色散污染',
      );
    });

    test('手指高光在玻璃底色上叠白斑，进度归零时逐位还原', () async {
      final texture = await _screenTexture(
        (canvas) => canvas.drawRect(
          Rect.fromLTWH(0, 0, _screenSize.width, _screenSize.height),
          ui.Paint()..color = const Color(0xFF000000),
        ),
      );
      addTearDown(texture.dispose);

      final idle = await _renderSurface(texture: texture);
      final lit = await _renderSurface(
        texture: texture,
        pointer: const Offset(100, 100),
        pointerGlow: 1,
        pointerRadius: 60,
      );

      // 未按压：不加任何光。
      expect(_pixel(idle, 90, 100), const Color(0xFF000000));
      // 指针近旁（距离 10 < 内沿 30）：满档 = 0.15 光斑 + 0.06 全面微亮。
      final near = _pixel(lit, 90, 100);
      expect(near.a, 1.0);
      expect((near.r * 255).round(), closeTo(54, 2));
      expect(near.g, near.r, reason: '高光是纯白，三通道必须相等');
      expect(near.b, near.r);
      // 光斑边缘（距离 40，介于内沿 30 与外沿 60 之间）：比中心暗但不为零。
      final mid = _pixel(lit, 60, 100);
      expect((mid.r * 255).round(), closeTo(44, 3));
      expect(mid.r, lessThan(near.r));
    });

    test('边光只交代转角：圆角上满档，贯屏长直段归零，四角两两一致', () async {
      // 2026-09-20 的真机口径「圆角异常，上面和左右异常浅色条」把前两轮的结论顶翻了：
      // 边光"一圈均匀"解决的是**方向性**（上沿比下沿亮 2.9 倍），但真机上那块通栏底部
      // 弹窗的上沿与左右仍然读成亮线 —— 因为一条**不随内容变化**的高光落在贯屏长直边上，
      // 无论多暗多细都只能读成"描边"；同一条高光落在圆角上才读作玻璃的反光边。
      //
      // 所以权重改成按**边界曲率**：SDF 中间量 q 的较小者（`min(q.x, q.y)`）在圆角弧上
      // 为正、在长直段上越来越负，`smoothstep(-w, 0, 它)` 就是"转角度"—— 圆角满档、
      // 长直段归零，中间 w 内平滑过渡。
      //
      // 这条规则**只对方正的面板成立**（默认表面 100×100 ⇒ `u_rim_corner_only` 为 1）。
      // 细长条走整圈均匀，见下面「细长条（药丸）」那条用例 —— 真机上只按曲率判会把
      // 药丸的上沿一起收掉。
      //
      // 底用**纯黑**、rim 传 1（满档）：底色为 0 时像素值直接就是边光本身，
      // 读数不受染色与背景影响。带宽给 3（滑杆上限，峰在 depth 1.05）—— 带宽太窄
      // 时采样点落不到峰值那一格上。
      final texture = await _screenTexture(
        (canvas) => canvas.drawRect(
          Rect.fromLTWH(0, 0, _screenSize.width, _screenSize.height),
          ui.Paint()..color = const Color(0xFF000000),
        ),
      );
      addTearDown(texture.dispose);

      final lit = await _renderSurface(texture: texture, rim: 1, rimWidth: 3);

      // 表面 (50,50) 100×100、半径 20 ⇒ 直段是 x/y ∈ [70,130]，圆角在四角。
      // 取**最外一行往里一格**（像素中心 depth = 1.5，正是峰值附近那一格）。
      final straightTop = _pixel(lit, 100, 51).r;
      final straightLeft = _pixel(lit, 51, 100).r;
      final straightBottom = _pixel(lit, 100, 148).r;
      final straightRight = _pixel(lit, 148, 100).r;

      // 四个圆角弧上的同深度点：屏幕 (56,56) 的**像素中心**在表面局部 (6.5,6.5)，
      // 到左上角圆心 (20,20) 的距离 19.09 ⇒ depth 0.91，正落在峰值附近。
      final cornerTopLeft = _pixel(lit, 56, 56).r;
      final cornerTopRight = _pixel(lit, 143, 56).r;
      final cornerBottomLeft = _pixel(lit, 56, 143).r;
      final cornerBottomRight = _pixel(lit, 143, 143).r;

      // 先确认高光真的还在（否则下面"直段归零"也可能只是整体没画）。
      expect(
        cornerTopLeft,
        greaterThan(0.5),
        reason: '圆角上那圈反光边是用户认的观感，不能被一起收掉',
      );
      for (final straight in [
        straightTop,
        straightLeft,
        straightBottom,
        straightRight,
      ]) {
        expect(
          straight,
          lessThan(0.02),
          reason: '贯屏长直段上不许有边光 —— 那正是"上面和左右异常浅色条"的来源',
        );
      }
      // 四角两两一致：方向性（`mix(0.35, 1.0, facing)` 那一类加权）没有偷偷回来。
      expect(cornerTopLeft, closeTo(cornerTopRight, 0.004), reason: '上沿左右角不一致');
      expect(
        cornerTopLeft,
        closeTo(cornerBottomLeft, 0.004),
        reason: '上下角不一致 = 方向性又回来了',
      );
      expect(cornerTopLeft, closeTo(cornerBottomRight, 0.004));
    });

    test('细长条（药丸）：同一条上沿，整圈均匀档亮着、只留转角档归零', () async {
      // 2026-09-20 真机口径「底栏高光只剩左右」把上一条用例的适用范围顶出来了：
      // 只按边界曲率判，**药丸的上沿和底部弹窗的上沿读数一样**（都是三百多像素的
      // 长直边、圆角 27/28），于是药丸中间 220px 全黑。能分开两者的只有「这块面
      // 整体是细条还是方正的板」，也就是 `u_rim_corner_only`（由
      // [liquidGlassRimCornerOnlyForSize] 按长短边比推）。
      //
      // 这条用例把**同一份几何**喂给两档，证明差别确实只来自那个系数：
      // 药丸 190×54、圆角 27（长短边比 3.5，按推导属于细条 ⇒ 整圈均匀）。
      // 底用纯黑、rim 传 1，读数直接就是边光本身。
      final texture = await _screenTexture(
        (canvas) => canvas.drawRect(
          Rect.fromLTWH(0, 0, _screenSize.width, _screenSize.height),
          ui.Paint()..color = const Color(0xFF000000),
        ),
      );
      addTearDown(texture.dispose);

      const pill = Offset(5, 60);
      const pillSize = Size(190, 54);
      Future<double> probeAt(int x, int y, double cornerOnly) async {
        final bytes = await _renderSurface(
          texture: texture,
          radius: 27,
          rim: 1,
          rimWidth: 3,
          rimCornerOnly: cornerOnly,
          surfaceOrigin: pill,
          surfaceSize: pillSize,
        );
        return _pixel(bytes, x, y).r;
      }

      // 上沿正中（像素中心 depth 1.5，带宽 3 时峰在带内）。
      final uniformTop = await probeAt(100, 61, 0);
      final cornerOnlyTop = await probeAt(100, 61, 1);
      expect(
        uniformTop,
        greaterThan(0.5),
        reason: '细条走整圈均匀时，上沿正中必须亮着 —— 归零就是真机报的「只剩左右」',
      );
      expect(
        cornerOnlyTop,
        lessThan(0.02),
        reason: '只留转角档必须把长直段收干净，否则「贯屏浅色条」会回来',
      );

      // 对照：药丸左端的半圆在两档下都亮着（形状没被一起收掉）。
      final uniformEnd = await probeAt(5, 87, 0);
      final cornerOnlyEnd = await probeAt(5, 87, 1);
      expect(uniformEnd, greaterThan(0.3));
      expect(
        cornerOnlyEnd,
        closeTo(uniformEnd, 0.004),
        reason: '两端半圆在「只留转角」档下也是满档，两档读数必须一致',
      );
    });

    test('边光峰值落在带内，不压在抗锯齿那一格上（圆角锯齿的成因）', () async {
      // 抗锯齿只作用在贴边的**半像素过渡带**里（`coverage = clamp(0.5 - sd, 0, 1)`，
      // 也就是 depth < 0.5 的那一圈）。高光峰值若压在那里，亮线的亮度就会随边界的
      // 亚像素相位跳变：直边像素对齐看不出来，斜着的圆角上相邻像素一亮一暗交替 ——
      // 真机口径「圆角有锯齿」。所以峰值必须内移到 depth ≥ 1 的实心区里。
      //
      // 探针只能摆在**边光允许出现的地方**：长直段现在被"只交代转角"那条规则收成 0
      // （见上一条用例），所以这里把表面换成半径 = 半边的**圆**（`q` 两个分量恒非负
      // ⇒ 整圈满档），沿圆心正上方那一列往下读三格。
      //
      // 带宽给到 3（滑杆上限）：峰在 0.35 × 3 = 1.05，正好落在 depth 1.5 那一行；
      // 贴边那行（depth 0.5）与更里面那行（depth 2.5）都该更暗。
      //
      // 底用**纯黑**：rim 传 1（满档）时高光叠到 0.5 灰底上会饱和到 1.0，三行全是 1.0，
      // 大小关系就比不出来了 —— 这组要的正是大小关系。
      final texture = await _screenTexture(
        (canvas) => canvas.drawRect(
          Rect.fromLTWH(0, 0, _screenSize.width, _screenSize.height),
          ui.Paint()..color = const Color(0xFF000000),
        ),
      );
      addTearDown(texture.dispose);

      final lit = await _renderSurface(
        texture: texture,
        radius: 50,
        rim: 1,
        rimWidth: 3,
      );

      final edgeRow = _pixel(lit, 100, 50).r; // depth 0.5：抗锯齿那一格
      final peakRow = _pixel(lit, 100, 51).r; // depth 1.5：实心区，峰在这里
      final innerRow = _pixel(lit, 100, 52).r; // depth 2.5：带的内侧
      final body = _pixel(lit, 100, 100).r;

      expect(peakRow, greaterThan(edgeRow + 0.05), reason: '峰值贴边 = 锯齿的成因又回来了');
      expect(peakRow, greaterThan(innerRow + 0.05), reason: '峰值该在带内，不是单调衰减');
      expect(body, lessThan(innerRow), reason: '带外不该有高光');
      expect(peakRow, lessThan(1.0), reason: '取纯黑底就是为了让高光不饱和，饱和了上面三条断言全都比不出大小');
    });
  });

  group('穹顶推导（liquidGlassDomeForSize）', () {
    test('接近方形的小件满档，短边越大越弱，96 归零', () {
      expect(liquidGlassDomeForSize(const Size(40, 40)), 1.0);
      expect(
        liquidGlassDomeForSize(const Size(64, 64)),
        closeTo((96 - 64) / (96 - 48), 0.001),
      );
      expect(liquidGlassDomeForSize(const Size(96, 96)), 0.0);
      expect(liquidGlassDomeForSize(const Size(200, 200)), 0.0);
    });

    test('细长条不穹顶：玻璃带与药丸不参与', () {
      // 首页玻璃带 / 底栏药丸都是宽扁条，边缘折射朝中心偏会读成扭曲。
      expect(liquidGlassDomeForSize(const Size(360, 64)), 0.0);
      expect(liquidGlassDomeForSize(const Size(200, 48)), 0.0);
    });
  });

  group('边光作用范围推导（liquidGlassRimCornerOnlyForSize）', () {
    test('细长条整圈均匀，方正的大面板只留转角', () {
      // 真机尺寸（逻辑 px）。这一组是「药丸只剩左右亮着」那条回归的护栏：
      // 药丸与玻璃带必须落在 0（整圈均匀），底部弹窗与弹窗家族必须落在 1（只留转角）。
      expect(
        liquidGlassRimCornerOnlyForSize(const Size(380, 54)),
        0.0,
        reason: '底栏药丸 380×54：细条，必须整圈均匀',
      );
      expect(
        liquidGlassRimCornerOnlyForSize(const Size(360, 64)),
        0.0,
        reason: '首页玻璃带：细条，必须整圈均匀',
      );
      expect(
        liquidGlassRimCornerOnlyForSize(const Size(360, 400)),
        1.0,
        reason: '底部弹窗：方正面板，必须只留转角（上沿那条浅色线就是这里治的）',
      );
      expect(
        liquidGlassRimCornerOnlyForSize(const Size(300, 200)),
        1.0,
        reason: '弹窗家族的面板：与底部弹窗同档，两边观感才一致',
      );
      expect(
        liquidGlassRimCornerOnlyForSize(const Size(56, 56)),
        1.0,
        reason: '圆钮：推到只留转角也无所谓 —— 圆形的 SDF 中间量两个分量恒非负',
      );
    });

    test('中间一段是过渡，不是硬切', () {
      final mid = liquidGlassRimCornerOnlyForSize(const Size(240, 120));
      expect(mid, greaterThan(0.0));
      expect(mid, lessThan(1.0));
      // 单调：越长越接近「整圈均匀」。
      expect(
        liquidGlassRimCornerOnlyForSize(const Size(240, 110)),
        lessThan(mid),
      );
    });
  });

  group('窄件折射位移上限推导（narrowSurfaceMaxRefraction）', () {
    test('窄件按短边折算：38dp 悬浮钮 / 31dp 回本周钮 / 40dp 星期条都被压', () {
      // 上下两条折射带会连成一整圈的比例正是这里要压掉的：作用带 14.5dp 在
      // 38dp 上占 38%、在 31dp 上占 47%。
      expect(narrowSurfaceMaxRefraction(38), closeTo(10.64, 1e-9));
      expect(narrowSurfaceMaxRefraction(31), closeTo(8.68, 1e-9));
      expect(narrowSurfaceMaxRefraction(40), closeTo(11.2, 1e-9));
    });

    test('上界不与「默认折射 8」打架：下限就是 8', () {
      // 折射量程 0~20、默认档 8 —— 折算结果掉到 8 以下会把默认档也压掉。
      expect(narrowSurfaceMaxRefraction(10), 8.0);
      expect(narrowSurfaceMaxRefraction(20), 8.0);
      // 上限 14：52dp 时 14.56 被夹回 14。
      expect(narrowSurfaceMaxRefraction(52), 14.0);
    });

    test('短边超过阈值返回 null（不压，用材质里那一份位移）', () {
      expect(narrowSurfaceMaxRefraction(53), isNull);
      // 组合带（约 84dp）与首页那条带、底栏药丸 / 圆钮（56dp）都不该被压。
      expect(narrowSurfaceMaxRefraction(56), isNull);
      expect(narrowSurfaceMaxRefraction(84), isNull);
    });

    test('单调不减，且在阈值处不跳变', () {
      var previous = 0.0;
      for (var side = 1.0; side <= 52.0; side += 1) {
        final value = narrowSurfaceMaxRefraction(side)!;
        expect(value, greaterThanOrEqualTo(previous));
        previous = value;
      }
      expect(narrowSurfaceMaxRefraction(52), 14.0);
      expect(narrowSurfaceMaxRefraction(53), isNull);
    });
  });

  group('LiquidGlassSurface 降级', () {
    testWidgets('测试环境没有 shader filter 后端：返回 fallback，不建玻璃层', (
      tester,
    ) async {
      // `flutter test` 跑的是软件后端，`ImageFilter.isShaderFilterSupported` 恒为
      // false —— 也就是真机上「引擎不支持实时折射」那一档。所以这里能验的正是
      // 最要紧的降级行为：不抛异常、不留半透明空壳、内容由调用方的基础材质接管。
      expect(
        ui.ImageFilter.isShaderFilterSupported,
        isFalse,
        reason: '这条路径在测试环境跑不到，本组只能验降级',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => LiquidGlassSurface(
                borderRadius: _style.borderRadius,
                fallbackBuilder: (context) =>
                    const ColoredBox(key: Key('fallback'), color: Color(0xFF112233)),
                child: const ColoredBox(
                  key: Key('glass-child'),
                  color: Color(0xFF445566),
                ),
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(Scaffold));
      expect(LiquidGlassSurface.isAvailable(context), isFalse);
      expect(find.byKey(const Key('fallback')), findsOneWidget);
      expect(
        find.byKey(const Key('glass-child')),
        findsNothing,
        reason: '不可用时不能把内容画上去 —— 那样会得到一块没有背景模糊的空壳',
      );
    });

    test('未加载时 newShader 返回 null（绘制侧据此走基础材质）', () {
      final loader = LiquidGlassSurfaceShader.instance;
      final wasLoaded = loader.isLoaded;
      loader.resetForTesting();
      expect(loader.isLoaded, isFalse);
      expect(loader.newShader(), isNull);
      // 还原，避免影响同进程内的其他用例。
      if (wasLoaded) {
        return loader.ensureLoaded();
      }
      return Future<void>.value();
    });
  });
}

void _stripedScreen(ui.Canvas canvas) {
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 50, 200),
    ui.Paint()..color = const Color(0xFFFF0000),
  );
  canvas.drawRect(
    const Rect.fromLTWH(50, 0, 125, 200),
    ui.Paint()..color = const Color(0xFF00FF00),
  );
  canvas.drawRect(
    const Rect.fromLTWH(175, 0, 25, 200),
    ui.Paint()..color = const Color(0xFF0000FF),
  );
}

Future<ui.Image> _screenTexture(
  void Function(ui.Canvas canvas) paint, {
  /// 位图尺寸，默认 [_screenSize]；扩边形态下要显式给更大的。
  Size? size,
}) async {
  final target = size ?? _screenSize;
  final recorder = ui.PictureRecorder();
  paint(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    target.width.round(),
    target.height.round(),
  );
  picture.dispose();
  return image;
}

/// 把液态玻璃表面着色器按给定参数画进 [_screenSize] 的位图，返回 rawRgba 像素。
///
/// 这里直接摆 uniform，而不是走 [LiquidGlassSurface]：那条路要求
/// `ImageFilter.isShaderFilterSupported` 为真，测试环境恒为假。所以「Dart 侧接线」
/// 由上面那组降级用例负责，这里只管着色器算得对不对。
///
/// 默认值刻意与 [LiquidGlassStyle] 的默认参数一致（band 7 / edgePow 2.5 /
/// rimWidth 1.5），于是这组同时钉住了默认参数下的观感。
Future<Uint8List> _renderSurface({
  required ui.Image texture,
  double radius = 20,
  Color tint = const Color(0x00000000),
  double refract = 0,
  double rim = 0,
  /// 边缘高光带宽（u_rim_width）；默认与 [LiquidGlassStyle] 的默认值一致。
  double rimWidth = 1.5,
  /// 边光作用范围（u_rim_corner_only）：0 = 整圈均匀、1 = 只留转角。
  ///
  /// 默认 1 —— 默认表面是 100×100 的方正面（长短边比 1），按
  /// [liquidGlassRimCornerOnlyForSize] 推导正是「只留转角」。细长条的用例显式传 0。
  double rimCornerOnly = 1,
  /// 色散强度（u_dispersion）；默认 0 = 关。
  double dispersion = 0,
  /// 穹顶强度（u_dome）；默认 0 = 关。
  double dome = 0,
  /// 手指高光：指针的屏幕物理位置；glow 为 0 时整组不生效。
  Offset? pointer,
  double pointerGlow = 0,
  double pointerRadius = 150,
  /// 表面在屏幕上的位置/尺寸，默认用 [_surfaceOrigin] / [_surfaceSize]。
  Offset? surfaceOrigin,
  Size? surfaceSize,
  /// 视口（屏幕）物理尺寸，默认等于绑定纹理尺寸。
  ///
  /// 真机上 `compose` 内层模糊会把绑定纹理往外扩，那时 `u_size` 比视口大——
  /// 用 [`expand`] 复现那个形态，这里显式给视口尺寸。
  Size? viewSize,
  /// 模拟模糊把绑定纹理往外扩的边（物理 px）：画布与纹理一起放大 2×expand。
  double expand = 0,
}) async {
  final shader = LiquidGlassSurfaceShader.instance.newShader()!;
  shader.setImageSampler(0, texture);
  // 真机上这两项由引擎填/绑（第一个 vec2 / 第一个 sampler2D）。u_size 是**绑定
  // 纹理**尺寸（叠了 compose 的模糊时会比视口大 2×expand）。
  final bound = Size(
    _screenSize.width + expand * 2,
    _screenSize.height + expand * 2,
  );
  shader.getUniformVec2('u_size').set(bound.width, bound.height);
  final view = viewSize ?? bound;
  shader.getUniformVec2('u_view_size').set(view.width, view.height);
  final origin = surfaceOrigin ?? _surfaceOrigin;
  final surfaceExtent = surfaceSize ?? _surfaceSize;
  shader.getUniformVec2('u_area_origin').set(origin.dx, origin.dy);
  shader.getUniformVec2('u_area_size').set(surfaceExtent.width, surfaceExtent.height);
  shader.getUniformFloat('u_radius').set(radius);
  shader.getUniformVec4('u_tint').set(tint.r, tint.g, tint.b, tint.a);
  shader.getUniformFloat('u_refract').set(refract);
  shader.getUniformFloat('u_band').set(7);
  shader.getUniformFloat('u_edge_pow').set(2.5);
  shader.getUniformFloat('u_dispersion').set(dispersion);
  shader.getUniformFloat('u_dome').set(dome);
  if (pointer != null) {
    shader.getUniformVec2('u_pointer').set(pointer.dx, pointer.dy);
  }
  shader.getUniformFloat('u_pointer_glow').set(pointerGlow);
  shader.getUniformFloat('u_pointer_radius').set(pointerRadius);
  shader.getUniformVec3('u_rim_color').set(1, 1, 1);
  shader.getUniformFloat('u_rim').set(rim);
  shader.getUniformFloat('u_rim_width').set(rimWidth);
  shader.getUniformFloat('u_rim_corner_only').set(rimCornerOnly);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(Offset.zero & bound, ui.Paint()..shader = shader);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    bound.width.round(),
    bound.height.round(),
  );
  picture.dispose();
  // toByteData 默认就是 rawRgba。
  final data = await image.toByteData();
  image.dispose();
  shader.dispose();
  return data!.buffer.asUint8List();
}

/// rawRgba 是预乘的；下面只读 alpha 为 255 的像素，所以直接当直通值用。
///
/// [width] 是位图行宽，默认 [_screenSize]；扩边形态下位图更大，必须显式给。
Color _pixel(Uint8List bytes, int x, int y, {int? width}) {
  final stride = width ?? _screenSize.width.round();
  final i = (y * stride + x) * 4;
  return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
}
