import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';

import '../../helpers_test_app.dart';

/// 首页顶栏「更多」「爱心」那颗**常驻玻璃球**的契约。
///
/// 球必须与首页菜单弹窗的形变终点同源：弹窗在 progress=0 时把面板摆成
/// 「锚点矩形、圆角 = 短边/2」，画它的是 `hyperosGlassPopupSurface` →
/// [HyperosSelectPopupGlass]。所以 [FHeaderActionBall] 用**同一个组件、
/// 同一个半径** —— 一旦退回 `MiuixIconButton(backgroundColor:)`（平涂色）或
/// 把半径改成别的值，打开/关闭菜单的交接瞬间就会露馅。
///
/// 更要命的是**位置**：球必须画在采样宿主（[HyperosLayerBackdropCapture]）
/// 之外。页内玻璃的采样快照录自捕获节点的图层，球若长在捕获子树里，它自己的
/// 输出会被烘进下一次采样 —— 打开菜单时按钮被上游隐藏、快照是干净的，关闭后
/// 按钮重绘即触发重采样，球就"变一次材质"并稳定在烘过自己一层的样子
/// （2026-09-14 真机现象：关掉菜单一秒后顶栏按钮材质变了）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget scope({required Widget child}) => TestApp(
    home: FrostedAppearanceScope(
      appearance: const FrostedAppearance(
        sheetBlurSigma: 15,
        sheetTintAlpha: 0.70,
        sheetBarrierAlpha: 0.20,
        glassMode: FrostedGlassMode.softGlass,
      ),
      child: child,
    ),
  );

  testWidgets('球用与弹窗同一组件、同一半径，走真玻璃材质', (tester) async {
    final link = LayerLink();
    await tester.pumpWidget(
      scope(
        child: Scaffold(
          body: Center(
            child: FHeaderActionBall(
              link: link,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final ball = tester.widget<HyperosSelectPopupGlass>(
      find.byType(HyperosSelectPopupGlass),
    );
    // 半径 = 图标按钮的最小边长 / 2 = 正圆，与弹窗「锚点短边 / 2」同口径。
    expect(ball.cornerRadius, MiuixIconButtonDefaults.minWidth / 2);

    // 盒子必须正好是那个最小边长：弹窗那颗球的半径是按**锚点短边**算的，
    // 锚点就是这颗按钮的矩形 —— 盒子一变，两边的圆角就对不上。
    expect(
      tester.getSize(find.byType(HyperosSelectPopupGlass)),
      const Size(
        MiuixIconButtonDefaults.minWidth,
        MiuixIconButtonDefaults.minHeight,
      ),
    );

    // 材质自 2026-09-19 起锁成「永远液态玻璃的标准档」（用户口径：不允许用户调整
    // 这些的材质）：不再按全局档位分派 —— 这里跑在柔光档下，球照样是液态玻璃面。
    // 测试环境没有 shader filter 后端，所以实际画出来的是它的回落面
    // （[StableFrostedSurface]），但 widget 本身必须是 [LiquidGlassSurface]。
    expect(
      find.descendant(
        of: find.byType(HyperosSelectPopupGlass),
        matching: find.byType(LiquidGlassSurface),
      ),
      findsOneWidget,
      reason: '球是固定小件：永远液态玻璃，不跟全局档位走',
    );
  });

  testWidgets('「更多」图标在紧约束下仍居中、红点仍贴图标右上角', (tester) async {
    // 弹窗形变起点那份副本是按 `BoxConstraints.tight(锚点矩形)` (40×40) 布局的。
    // 若把 Stack 直接暴露出去，它会被撑成 40×40：默认对齐把图标推到左上角、
    // Positioned 到 Stack 右上角的红点落到右上角 —— 收起动画里就是"三个点和
    // 红点跑到圈圈左上/右上，过一会才归位"。这里用 tight 40×40 复现该约束。
    await tester.pumpWidget(
      const TestApp(
        home: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: HomeMoreActionIcon(
              ink: Color(0xFF1A1A1A),
              dotBorderColor: Color(0xFFFFFFFF),
              showUpdateDot: true,
            ),
          ),
        ),
      ),
    );

    final boxTopLeft = tester.getTopLeft(find.byType(HomeMoreActionIcon));
    final boxCenter = tester.getCenter(find.byType(HomeMoreActionIcon));
    final iconCenter = tester.getCenter(find.byIcon(Icons.more_vert_rounded));
    expect(iconCenter.dx, closeTo(boxCenter.dx, 0.01), reason: '图标必须居中');
    expect(iconCenter.dy, closeTo(boxCenter.dy, 0.01), reason: '图标必须居中');

    // 红点：贴 **24×24 基准框**的右上角（right/top = -1，边长 9）→ 相对基准框
    // 左上角 = (24 + 1 - 4.5, -1 + 4.5) = (20.5, 3.5)；基准框在 40×40 里居中
    // ⇒ 再各加 8 的留白 = (28.5, 11.5)。
    final dotCenter = tester.getCenter(
      find.descendant(
        of: find.byType(HomeMoreActionIcon),
        matching: find.byType(Container),
      ),
    );
    expect(dotCenter.dx - boxTopLeft.dx, closeTo(28.5, 0.5));
    expect(dotCenter.dy - boxTopLeft.dy, closeTo(11.5, 0.5));
  });

  testWidgets('leader 缺席时不画（不能退化成画在左上角）', (tester) async {
    // 这颗球用 [CompositedTransformFollower] 跟随真实按钮。leader 不在树上时
    // （首页切到内嵌页如任务清单，首页内容整块被替换）follower 默认会画在
    // **自己的布局位置** —— 也就是 Stack 左上角，屏幕上就是"左上角冒出一颗
    // 爱心球"。所以必须 showWhenUnlinked: false（2026-09-14 真机反馈）。
    final link = LayerLink();
    await tester.pumpWidget(
      scope(
        child: Scaffold(
          body: Center(
            child: FHeaderActionBall(
              link: link,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<CompositedTransformFollower>(
            find.byType(CompositedTransformFollower),
          )
          .showWhenUnlinked,
      isFalse,
      reason: '没有 leader 时不能画在布局位置（Stack 左上角）',
    );
  });

  testWidgets('visible: false 时留着但不画（让位给弹窗的球）', (tester) async {
    final link = LayerLink();
    await tester.pumpWidget(
      scope(
        child: Scaffold(
          body: Center(
            child: FHeaderActionBall(
              link: link,
              visible: false,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // ⚠️ 玻璃面必须**仍在树上**，只是不画：摘掉会连带销毁采样区登记，关闭
    // 菜单重新挂载时区里还没有快照，玻璃面只能先画一帧兜底实底 —— 真机上
    // 就是"关掉菜单时圆按钮闪一下"。所以这里断言「在树上 + visible: false」，
    // 而不是断言它不存在。
    expect(find.byType(HyperosSelectPopupGlass), findsOneWidget);
    expect(
      tester
          .widget<Visibility>(
            find.ancestor(
              of: find.byType(HyperosSelectPopupGlass),
              matching: find.byType(Visibility),
            ),
          )
          .visible,
      isFalse,
      reason: '不画（Opacity 0），但布局与采样区保持有效',
    );
  });

  testWidgets('球绘制在采样宿主之外（不自采样）', (tester) async {
    final controller = HyperosGlassBackdropController();
    addTearDown(controller.dispose);
    final link = LayerLink();

    // 与首页同构：捕获节点包住"玻璃之下的内容"（真实按钮），球是 Host 的
    // Stack 兄弟层 —— 不在捕获子树里。
    await tester.pumpWidget(
      scope(
        child: Stack(
          children: [
            HyperosGlassBackdropHost(
              controller: controller,
              child: CompositedTransformTarget(
                link: link,
                child: const FHeaderAction(
                  icon: SizedBox(width: 24, height: 24),
                  semanticsLabel: '更多',
                ),
              ),
            ),
            FHeaderActionBall(
              link: link,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 球不在捕获节点的子树里 —— 这是"不自采样"的结构保证。
    // （页内玻璃的采样快照录自捕获节点的图层；球若长在捕获子树里，它自己的
    // 输出会被烘进下一次采样，关菜单后球就会变一次材质。）
    final captureRo = tester.renderObject<RenderObject>(
      find.byType(HyperosLayerBackdropCapture),
    );
    final ballRo = tester.renderObject<RenderObject>(
      find.byType(HyperosSelectPopupGlass),
    );
    for (RenderObject? ro = ballRo; ro != null; ro = ro.parent) {
      expect(
        identical(ro, captureRo),
        isFalse,
        reason: '球不能长在捕获子树里：它自己的输出会被烘进下一次采样',
      );
    }
  });

  testWidgets('纯色背景（没壁纸）下小球必须看得见：描边 + 阴影（与弹层侧同源）', (
    tester,
  ) async {
    // 回归点一：球的材质（磨砂 / 柔光 / 液态 / 实底）都是从"背后那条窄带"采样
    // 的，没壁纸时背后就是一片纯色 —— 磨砂分支模糊一个纯色仍是同一个纯色，
    // 且页面背景与球的实底色**是同一个色标**（浅色都是 #FFFFFF、深色都是
    // #242424），圆会整颗融进页面（真机反馈：没设壁纸时右上角小球在浅色和
    // 深色下都几乎看不见）。上游同款组件 `MiuixGlassIconButton` 从来都画描边 +
    // 阴影 —— 这两样与背景无关，是可见性下限。
    //
    // 回归点二：这两层必须与弹层侧同源。菜单收起时那颗球是"弹窗先画、再交接给
    // 常驻球"的，两侧不一致就会在交接瞬间现形（真机反馈：阴影在弹窗收回后一秒
    // 突然出现）。所以这里同时钉住"用了 [HyperosGlassShadow] 的值"。
    for (final brightness in Brightness.values) {
      final link = LayerLink();
      await tester.pumpWidget(
        scope(
          child: Theme(
            data: ThemeData(brightness: brightness),
            child: Scaffold(
              body: Center(
                child: FHeaderActionBall(
                  link: link,
                  icon: const Icon(Icons.more_vert_rounded),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(FHeaderActionBall),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((b) => b.decoration as BoxDecoration);

      // 垫底那层：外浮影（球的分离感靠它，材质本身在纯色背景上等于没画）。
      // **不要**再往这里加洗色之类弹层侧没有的层：交接面多一层，跳变就换一种
      // 形式回来。
      final base = decorations.firstWhere(
        (d) => d.boxShadow?.isNotEmpty ?? false,
      );
      expect(
        base.color,
        anyOf(isNull, Colors.transparent),
        reason: '$brightness：与弹层侧同源，球不额外垫洗色',
      );
      expect(base.shape, BoxShape.circle);

      // 2026-09-19 起组件**不再给球叠描边**（用户口径「去掉，靠玻璃设置」）：
      // 球的边界交给玻璃材质自己交代。谁要是把描边加回来，这条会红。
      expect(
        decorations.where((d) => d.border != null),
        isEmpty,
        reason: '$brightness：组件不再叠描边，边界由玻璃材质交代',
      );
      expect(
        base.boxShadow!.first,
        HyperosGlassShadow.shadow,
        reason: '球与弹层侧必须用同一处定义的浮影',
      );
    }
  });

  testWidgets('球的子树随明暗切换换身份（底图快照不跟着主题变）', (tester) async {
    // 回归点：玻璃面的底图是"背后那条窄带"的快照，快照不跟着主题变 —— 切到
    // 深色再切回浅色，球会一直停在深色那张底图上（真机反馈："球还是黑的"）。
    // Key 里带 brightness ⇒ 每次切换整块换掉，重新登记采样区、重新录帧。
    final link = LayerLink();
    await tester.pumpWidget(
      scope(
        child: Theme(
          data: ThemeData(brightness: Brightness.light),
          child: Scaffold(
            body: Center(
              child: FHeaderActionBall(
                link: link,
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    Key? ballSubtreeKey() => tester
        .widget<KeyedSubtree>(
          find.descendant(
            of: find.byType(FHeaderActionBall),
            matching: find.byType(KeyedSubtree),
          ),
        )
        .key;
    final lightKey = ballSubtreeKey();

    await tester.pumpWidget(
      scope(
        child: Theme(
          data: ThemeData(brightness: Brightness.dark),
          child: Scaffold(
            body: Center(
              child: FHeaderActionBall(
                link: link,
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(ballSubtreeKey(), isNot(lightKey), reason: '明暗切换后必须换一棵子树重新录帧');
  });

  testWidgets('球不再有上游那层材质（那圈「加法白」高光的根）', (tester) async {
    // 真机反馈：柔光档 + 壁纸时，右上角那颗球的白边特别重。那圈白**不是**本仓补的
    // 轮廓线，而是柔光档独有的上游描边（贴边白 10% + 两处方向高光 50% / 30%，以加法
    // 混合画上去）；球内部本就被三层白提亮到接近纯白，加法一叠直接钳到 1.0。
    //
    // 2026-09-19 起球锁成「永远液态玻璃的标准档」，柔光分支在球上不存在了 ——
    // 上游那层材质（`MiuixGlass`）整块都不再出现在球的子树里，这圈白自然也没有了。
    final link = LayerLink();
    await tester.pumpWidget(
      scope(
        child: Scaffold(
          body: Center(
            child: FHeaderActionBall(
              link: link,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(HyperosSelectPopupGlass),
        matching: find.byType(MiuixGlass),
      ),
      findsNothing,
      reason: '球不再走上游材质：柔光那圈加法白高光的根被拔掉了',
    );
    expect(
      find.descendant(
        of: find.byType(HyperosSelectPopupGlass),
        matching: find.byType(LiquidGlassSurface),
      ),
      findsOneWidget,
    );
  });

  testWidgets('弹层与球同一条规矩：也没有上游那层材质', (tester) async {
    // 2026-09-19 之前这里钉的是「面板保留上游高光、只有球关掉」。现在弹窗家族与球
    // 一起锁成「永远液态玻璃的标准档」，上游材质在两边都不再出现 —— 这条翻成
    // 同一个方向的断言，防止谁把上游面板又塞回来。
    await tester.pumpWidget(
      scope(
        child: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              height: 120,
              child: HyperosSelectPopupGlass(
                cornerRadius: 24,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byType(MiuixGlass),
      findsNothing,
      reason: '弹层不再走上游材质（面板同样锁标准档液态玻璃）',
    );
    expect(find.byType(LiquidGlassSurface), findsOneWidget);
  });
}
