import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../helpers_test_app.dart';

/// Invokes [HyperosListTile.onTap] for rows under overlay headers where hit
/// testing is blocked by the frosted header stack.
Future<void> tapListTileBelowOverlayHeader(
  WidgetTester tester,
  String label,
) async {
  final tileFinder = find.widgetWithText(HyperosListTile, label);
  expect(tileFinder, findsOneWidget);
  final tile = tester.widget<HyperosListTile>(tileFinder);
  expect(tile.onTap, isNotNull);
  tile.onTap!.call();
  await tester.pump();
}

/// Waits for post-route blur settle frames on overlay-header pages.
Future<void> pumpBlurSettleFrames(WidgetTester tester) async {
  // Route settle + _blurSettleFrameCount post-frame callbacks + rebuild.
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('pushing HyperosSubpage over settings home does not throw', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            return HyperosSubpage(
              onBack: () {},
              title: const Text('Settings'),
              child: HyperosListView(
                children: [
                  HyperosListTile(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    onTap: () {
                      HyperosNavigation.push(
                        context,
                        builder: (_) => const _AppearanceStub(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapListTileBelowOverlayHeader(tester, 'Appearance');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Collapsible headers keep the large and small titles mounted together;
    // the small title sits at zero alpha until the large one collapses.
    expect(find.text('Appearance settings'), findsWidgets);
    expect(find.text('Dark mode'), findsOneWidget);

    await pumpBlurSettleFrames(tester);
    await tester.pump();

    // Subpages default to overlay layout for BackdropFilter header blur.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is HyperosBlurredHeaderScope &&
            widget.contentTopInset > 0 &&
            widget.blurEnabled,
      ),
      findsOneWidget,
    );
  });

  testWidgets('subpage body visible immediately after push settles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            return HyperosSubpage(
              onBack: () {},
              title: const Text('Settings'),
              child: HyperosListView(
                children: [
                  HyperosListTile(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    onTap: () {
                      HyperosNavigation.push(
                        context,
                        builder: (_) => const _AppearanceStub(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapListTileBelowOverlayHeader(tester, 'Appearance');
    await tester.pumpAndSettle();

    expect(find.text('Dark mode'), findsOneWidget);
  });

  testWidgets('HyperosListView itemBuilder mode builds lazily', (
    WidgetTester tester,
  ) async {
    var buildCount = 0;

    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpage(
          onBack: () {},
          title: const Text('Lazy list'),
          child: HyperosListView(
            itemCount: 20,
            itemBuilder: (context, index) {
              buildCount++;
              return HyperosListTile(
                icon: Icons.settings_outlined,
                title: 'Item $index',
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Visible window only; blur settle may rebuild the list once after 2 frames.
    expect(buildCount, lessThan(35));
    expect(find.text('Item 0'), findsOneWidget);
    expect(find.text('Item 19'), findsNothing);
  });

  testWidgets('HyperosListView children mode keeps all items mounted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpage(
          onBack: () {},
          title: const Text('Eager list'),
          child: HyperosListView(
            children: [
              for (var index = 0; index < 20; index++)
                HyperosListTile(
                  icon: Icons.settings_outlined,
                  title: 'Item $index',
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // SingleChildScrollView + Column keeps every child mounted off-screen.
    expect(find.text('Item 0', skipOffstage: false), findsOneWidget);
    expect(find.text('Item 19', skipOffstage: false), findsOneWidget);
  });

  testWidgets('HyperosSubpage provides HyperosOverscrollPhysics to ListView', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpage(
          onBack: () {},
          title: const Text('Scroll'),
          child: ListView(
            primary: false,
            children: const [SizedBox(height: 2000)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollableFinder = find.descendant(
      of: find.byType(HyperosSubpage),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollableFinder).position;
    expect(position.physics, isA<HyperosOverscrollPhysics>());
  });

  testWidgets(
    'HyperosSubpage provides HyperosOverscrollPhysics to SingleChildScrollView',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        TestApp(
          home: HyperosSubpage(
            onBack: () {},
            title: const Text('Scroll'),
            child: const SingleChildScrollView(
              primary: false,
              child: SizedBox(height: 2000),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byType(HyperosSubpage),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollableFinder).position;
      expect(position.physics, isA<HyperosOverscrollPhysics>());
    },
  );

  testWidgets('settings home preserves scroll after popping subpage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            return HyperosSubpage(
              onBack: () {},
              title: const Text('Settings'),
              child: HyperosListView(
                pageStorageKey: const PageStorageKey<String>(
                  'timetable-settings-main',
                ),
                itemCount: 40,
                itemBuilder: (context, index) => HyperosListTile(
                  icon: Icons.settings_outlined,
                  title: 'Item $index',
                  onTap: index == 25
                      ? () {
                          HyperosNavigation.push(
                            context,
                            builder: (_) => HyperosSubpage(
                              onBack: () => Navigator.pop(context),
                              title: const Text('Sub settings'),
                              child: const HyperosListView(
                                children: [
                                  HyperosListTile(
                                    icon: Icons.dark_mode_outlined,
                                    title: 'Sub item',
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final homeScrollable = find.descendant(
      of: find.byType(HyperosListView).first,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Item 25'),
      120,
      scrollable: homeScrollable,
    );
    await tester.pumpAndSettle();

    final pixelsBefore = tester
        .state<ScrollableState>(homeScrollable)
        .position
        .pixels;
    expect(pixelsBefore, greaterThan(100));

    await tapListTileBelowOverlayHeader(tester, 'Item 25');
    await tester.pumpAndSettle();
    expect(find.text('Sub item'), findsOneWidget);

    Navigator.of(tester.element(find.text('Sub item'))).pop();
    await tester.pumpAndSettle();
    await pumpBlurSettleFrames(tester);
    await tester.pumpAndSettle();

    final pixelsAfter = tester
        .state<ScrollableState>(homeScrollable)
        .position
        .pixels;
    expect(pixelsAfter, closeTo(pixelsBefore, 1));
  });

  testWidgets('subpage enables backdrop blur after settle on overlay layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            return HyperosSubpage(
              onBack: () {},
              title: const Text('Settings'),
              child: HyperosListView(
                children: [
                  HyperosListTile(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    onTap: () {
                      HyperosNavigation.push(
                        context,
                        builder: (_) => const _AppearanceStub(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapListTileBelowOverlayHeader(tester, 'Appearance');
    await tester.pumpAndSettle();

    await pumpBlurSettleFrames(tester);
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is HyperosBlurredHeaderScope &&
            widget.contentTopInset > 0 &&
            widget.blurEnabled,
      ),
      findsOneWidget,
    );
  });

  testWidgets('modal bottom sheet keeps header backdrop blur on subpage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpage(
          onBack: () {},
          title: const Text('Appearance'),
          child: HyperosListView(
            children: [
              HyperosSelectTile<String>(
                label: 'Theme preset',
                items: const {
                  'Blue': 'blue',
                  'Green': 'green',
                  'Orange': 'orange',
                  'Red': 'red',
                  'Violet': 'violet',
                  'Yellow': 'yellow',
                  'Rose': 'rose',
                  'Slate': 'slate',
                },
                value: 'blue',
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await pumpBlurSettleFrames(tester);
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is HyperosBlurredHeaderScope && widget.blurEnabled,
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Theme preset'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is HyperosBlurredHeaderScope && widget.blurEnabled,
      ),
      findsOneWidget,
    );
  });

  testWidgets('settings home blur restores after popping subpage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            return HyperosSubpage(
              onBack: () {},
              title: const Text('Settings'),
              child: HyperosListView(
                children: [
                  HyperosListTile(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    onTap: () {
                      HyperosNavigation.push(
                        context,
                        builder: (_) => const _AppearanceStub(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await pumpBlurSettleFrames(tester);
    await tester.pump();

    Finder homeBlurScope() {
      return find.ancestor(
        of: find.text('Settings'),
        matching: find.byWidgetPredicate(
          (widget) => widget is HyperosBlurredHeaderScope,
        ),
      );
    }

    // Large + small titles share one scope; the ancestor finder can list it
    // once per matching Text, so take the unique set.
    expect(homeBlurScope().evaluate().map((e) => e.widget).toSet(), hasLength(1));
    expect(
      tester.widgetList<HyperosBlurredHeaderScope>(homeBlurScope()).first.blurEnabled,
      isTrue,
    );

    await tapListTileBelowOverlayHeader(tester, 'Appearance');
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.text('Dark mode'))).pop();
    await tester.pumpAndSettle();

    expect(homeBlurScope().evaluate().map((e) => e.widget).toSet(), hasLength(1));
    expect(
      tester.widgetList<HyperosBlurredHeaderScope>(homeBlurScope()).first.blurEnabled,
      isTrue,
    );
  });

  testWidgets('header frost follows scroll position on overlay pages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpage(
          onBack: () {},
          title: const Text('Settings'),
          child: HyperosListView(
            children: List.generate(
              20,
              (index) => HyperosListTile(
                icon: Icons.settings_outlined,
                title: 'Item $index',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await pumpBlurSettleFrames(tester);
    await tester.pump();

    Finder headerScope() {
      // Collapsible headers render the large and small title together, so
      // text ancestry returns the same scope twice. The page owns one scope;
      // target it directly instead of depending on title multiplicity.
      return find.byType(HyperosBlurredHeaderScope);
    }

    expect(
      tester
          .widget<HyperosBlurredHeaderScope>(headerScope())
          .contentUnderHeader,
      isFalse,
    );

    final scrollable = find.descendant(
      of: find.byType(HyperosListView),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -120));
    await tester.pump();

    expect(
      tester
          .widget<HyperosBlurredHeaderScope>(headerScope())
          .contentUnderHeader,
      isTrue,
    );

    await tester.drag(scrollable, const Offset(0, 120));
    await tester.pump();

    expect(
      tester
          .widget<HyperosBlurredHeaderScope>(headerScope())
          .contentUnderHeader,
      isFalse,
    );
  });

  testWidgets('header blur shell stays mounted across frost flip', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpage(
          onBack: () {},
          title: const Text('Settings'),
          child: HyperosListView(
            children: List.generate(
              20,
              (index) => HyperosListTile(
                icon: Icons.settings_outlined,
                title: 'Item $index',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await pumpBlurSettleFrames(tester);
    await tester.pump();

    // Frost off: the blur shell is already in the tree so the first
    // under-header frame only swaps tint (no Inspire.backdropBlur mount hitch).
    // Desktop test hosts have liveBlurSupported=false so blurEnabled stays
    // false there; only the shell's presence is portable.
    expect(find.byType(FrostedHeaderBackground), findsOneWidget);

    final scrollable = find.descendant(
      of: find.byType(HyperosListView),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -120));
    await tester.pump();

    expect(
      tester
          .widget<HyperosBlurredHeaderScope>(
            find.byType(HyperosBlurredHeaderScope),
          )
          .contentUnderHeader,
      isTrue,
    );
    // Shell stays in the tree across the frost flip — not remounted.
    expect(find.byType(FrostedHeaderBackground), findsOneWidget);
  });

  testWidgets('HyperosSubpage headerExtension shares frosted header shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpage(
          onBack: () {},
          title: const Text('Schools'),
          headerExtension: const HyperosBlurredHeaderExtension(
            child: SizedBox(height: 48, child: Text('Search')),
          ),
          child: const HyperosListView(
            children: [
              HyperosListTile(
                icon: Icons.school_outlined,
                title: 'Example school',
              ),
            ],
          ),
        ),
      ),
    );
    await pumpBlurSettleFrames(tester);
    await tester.pumpAndSettle();

    expect(find.byType(HyperosBlurredHeaderExtension), findsOneWidget);
    expect(find.byType(HyperosBlurredHeaderShell), findsOneWidget);

    final scope = tester.widget<HyperosBlurredHeaderScope>(
      find.byType(HyperosBlurredHeaderScope),
    );
    expect(
      scope.contentTopInset,
      greaterThan(
        HyperosBlurredHeader.contentTopInset(
          tester.element(find.byType(HyperosSubpage)),
        ),
      ),
    );
  });

  testWidgets(
    'rebuilding headerExtension with new instances keeps contentTopInset stable',
    (WidgetTester tester) async {
      var rebuildToken = 0;

      await tester.pumpWidget(
        TestApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return HyperosSubpage(
                onBack: () {},
                title: Text('Guide $rebuildToken'),
                // Fresh widget identity each rebuild (matches UserGuideScreen).
                headerExtension: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('1 / 4 token=$rebuildToken'),
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(value: 0.25),
                    ],
                  ),
                ),
                child: HyperosBlurredBodyInset(
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView(
                          children: const [
                            Center(child: Text('page-a')),
                            Center(child: Text('page-b')),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => rebuildToken++);
                        },
                        child: const Text('bump'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await pumpBlurSettleFrames(tester);
      await tester.pumpAndSettle();

      double insetOf() {
        return tester
            .widget<HyperosBlurredHeaderScope>(
              find.byType(HyperosBlurredHeaderScope),
            )
            .contentTopInset;
      }

      final baselineInset = insetOf();
      expect(baselineInset, greaterThan(0));

      for (var i = 0; i < 6; i++) {
        await tester.tap(find.text('bump'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          insetOf(),
          closeTo(baselineInset, 0.5),
          reason: 'contentTopInset must not jump after rebuild #$i',
        );
      }
    },
  );

  testWidgets(
    'horizontal PageView scroll does not flip contentUnderHeader frost',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        TestApp(
          home: HyperosSubpage(
            onBack: () {},
            title: const Text('Guide'),
            headerExtension: const HyperosBlurredHeaderExtension(
              child: SizedBox(height: 40, child: Text('progress')),
            ),
            child: HyperosBlurredBodyInset(
              child: PageView(
                children: List.generate(
                  3,
                  (index) => ListView(
                    children: [
                      for (var row = 0; row < 8; row++)
                        ListTile(title: Text('page-$index-row-$row')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await pumpBlurSettleFrames(tester);
      await tester.pumpAndSettle();

      HyperosBlurredHeaderScope scope() {
        return tester.widget<HyperosBlurredHeaderScope>(
          find.byType(HyperosBlurredHeaderScope),
        );
      }

      expect(scope().contentUnderHeader, isFalse);

      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        scope().contentUnderHeader,
        isFalse,
        reason: 'horizontal page offset must not frost the header',
      );
    },
  );
  // ── 键盘避让（2026-10-21）────────────────────────────────────────────
  //
  // 表单项露在键盘底下就点不到。原先只有 `resizeToAvoidBottomInset: true`：
  // 它把视口压小，但内容总高不变，`maxScrollExtent` 只涨「视口差」那么多，
  // 恰好被页面自己的底距吃掉——360×800 屏 + 300dp 键盘时只剩 5.4dp，
  // 表单最后一行贴着键盘顶边。
  //
  // 修法是给列表底部内边距加上键盘高度。键盘高度必须从 `Scaffold` **外面**
  // 读：`resizeToAvoidBottomInset: true` 会把子树的 viewInsets 清零，列表里
  // 直接读恒为 0（这条也一并用例钉住，否则后人「简化」回去时测试不会响）。
  group('HyperosListView 键盘避让', () {
    testWidgets('键盘弹出后列表底部内边距等于键盘高度（可滚到遮挡物之外）', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        TestApp(
          home: HyperosSubpage(
            onBack: () {},
            resizeToAvoidBottomInset: true,
            title: const Text('Form'),
            child: HyperosListView(
              itemCount: 1,
              itemBuilder: (context, index) => const SizedBox(height: 200),
            ),
          ),
        ),
      );
      await pumpBlurSettleFrames(tester);

      EdgeInsets paddingOf() {
        // itemCount 模式走 ListView.builder，children 模式走 SingleChildScrollView。
        final scrollView = find.byType(SingleChildScrollView);
        final padding = scrollView.evaluate().isNotEmpty
            ? tester.widget<SingleChildScrollView>(scrollView.first).padding
            : tester.widget<ListView>(find.byType(ListView).first).padding;
        return padding! as EdgeInsets;
      }

      // 无键盘时底部就是常规列表底距。
      tester.view.viewInsets = const FakeViewPadding(bottom: 900); // 300dp
      await tester.pumpAndSettle();

      // 判据直接钉内边距：改成滚动的间接观察会被「视口也被压小」抵消，
      // 差值算不出真实的键盘余量（实测 106 而非 300），也说不清坏在哪。
      expect(
        paddingOf().bottom,
        300,
        reason: '底部内边距必须等于键盘高度，列表才能整体滑到键盘上方',
      );
    });

    testWidgets('Scaffold 内的 viewInsets 被清零，键盘高度只能从 scope 取', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);

      double? insideScaffold;
      double? scopeValue;

      await tester.pumpWidget(
        TestApp(
          home: HyperosSubpage(
            onBack: () {},
            resizeToAvoidBottomInset: true,
            title: const Text('Form'),
            child: HyperosListView(
              itemCount: 1,
              itemBuilder: (context, index) {
                insideScaffold ??= MediaQuery.viewInsetsOf(context).bottom;
                scopeValue ??=
                    HyperosBlurredHeaderScope.keyboardInsetOf(context);
                return const SizedBox(height: 10);
              },
            ),
          ),
        ),
      );
      await pumpBlurSettleFrames(tester);

      expect(
        insideScaffold,
        0,
        reason: 'Scaffold(resizeToAvoidBottomInset: true) 会清零子树 viewInsets',
      );
      expect(
        scopeValue,
        300,
        reason: '键盘高度必须由 scope 从 Scaffold 外层带下来',
      );
    });
  });
}

class _AppearanceStub extends StatelessWidget {
  const _AppearanceStub();

  @override
  Widget build(BuildContext context) {
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: const Text('Appearance settings'),
      child: HyperosListView(
        itemCount: 1,
        itemBuilder: (context, index) => const HyperosListTile(
          icon: Icons.dark_mode_outlined,
          title: 'Dark mode',
        ),
      ),
    );
  }
}