import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

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

    // 柔光档下必须真的是那块柔光玻璃（而不是平涂色）。
    expect(
      find.descendant(
        of: find.byType(HyperosSelectPopupGlass),
        matching: find.byType(SoftGlassSurface),
      ),
      findsOneWidget,
      reason: '球要跟弹窗一样按全局档位分派材质',
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

  testWidgets('纯色背景（没壁纸）下小球必须看得见：描边 + 阴影 + 淡洗色', (
    tester,
  ) async {
    // 回归点：球的材质（磨砂 / 柔光 / 液态 / 实底）都是从"背后那条窄带"采样
    // 的，没壁纸时背后就是一片纯色 —— 磨砂分支模糊一个纯色仍是同一个纯色，
    // 且页面背景与球的实底色**是同一个色标**（浅色都是 #FFFFFF、深色都是
    // #242424），圆会整颗融进页面（真机反馈：没设壁纸时右上角小球在浅色和
    // 深色下都几乎看不见）。
    //
    // 上游同款组件 `MiuixGlassIconButton` 从来都画描边 + 阴影 —— 这两样与背景
    // 无关，是可见性下限。这里把这条钉住。
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
                  overFlatBackdrop: true,
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

      // 垫底那层：淡洗色 + 外阴影（没壁纸时给一点与页面的分离感）。
      final base = decorations.firstWhere(
        (d) => d.boxShadow?.isNotEmpty ?? false,
      );
      expect(
        base.color,
        isNot(Colors.transparent),
        reason: '$brightness：没壁纸时球要垫一层淡洗色才读得出是个面',
      );
      expect(base.shape, BoxShape.circle);

      // 压在最上面那圈描边：描边色必须**不是**页面底色，否则等于没画。
      final ring = decorations.firstWhere((d) => d.border != null);
      final ringColor = (ring.border! as Border).top.color;
      final pageBackground = brightness == Brightness.dark
          ? const Color(0xFF242424)
          : const Color(0xFFFFFFFF);
      expect(
        ringColor,
        isNot(pageBackground),
        reason: '$brightness：描边色不能和页面底色相同',
      );
      expect(ringColor.a, 1.0, reason: '描边必须是不透明的轮廓线');
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
}
