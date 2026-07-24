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
              overlayHeader: true,
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

    expect(find.text('Appearance settings'), findsOneWidget);
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
              overlayHeader: true,
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
            child: SingleChildScrollView(
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
              overlayHeader: true,
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
                              child: HyperosListView(
                                children: const [
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
              overlayHeader: true,
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
          overlayHeader: true,
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
              overlayHeader: true,
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

    expect(homeBlurScope(), findsOneWidget);
    expect(
      tester.widget<HyperosBlurredHeaderScope>(homeBlurScope()).blurEnabled,
      isTrue,
    );

    await tapListTileBelowOverlayHeader(tester, 'Appearance');
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.text('Dark mode'))).pop();
    await tester.pumpAndSettle();

    expect(homeBlurScope(), findsOneWidget);
    expect(
      tester.widget<HyperosBlurredHeaderScope>(homeBlurScope()).blurEnabled,
      isTrue,
    );
  });

  testWidgets('header frost follows scroll position on overlay pages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpage(
          overlayHeader: true,
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
      return find.ancestor(
        of: find.text('Settings'),
        matching: find.byWidgetPredicate(
          (widget) => widget is HyperosBlurredHeaderScope,
        ),
      );
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
          child: HyperosListView(
            children: const [
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
