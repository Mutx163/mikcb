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

    await tester.pump(const Duration(milliseconds: 350));
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

    expect(buildCount, lessThan(20));
    expect(find.text('Item 0'), findsOneWidget);
  });

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
    await tester.pump(const Duration(milliseconds: 350));
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

    await tester.pump(const Duration(milliseconds: 350));
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
    await tester.pump(const Duration(milliseconds: 350));
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
