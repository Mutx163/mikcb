import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/widgets/home_menu_catalog.dart';
import 'package:university_timetable/widgets/home_top_menu.dart';

import '../helpers_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('grid menu renders default eight tiles without tasks entry', (
    tester,
  ) async {
    final anchorKey = GlobalKey();
    late Future<String?> menuResult;

    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                key: anchorKey,
                onPressed: () {
                  menuResult = showHomeTopGridMenuSheet(
                    context,
                    hasAvailableUpdate: false,
                    entries: resolveHomeGridMenuEntries(
                      TimetableSettings.defaults(),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // v2.0.5.5 默认排列：8 个瓷贴，任务清单不在其中（列表菜单独有）。
    for (final title in const [
      '软件更新',
      '课程总览',
      '课程统计',
      '添加',
      '考试安排',
      '导入课程',
      '课表设置',
      '请喝咖啡',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('任务清单'), findsNothing);
    expect(find.byIcon(Icons.system_update_alt_rounded), findsOneWidget);

    await tester.tap(find.text('课程总览'));
    await tester.pumpAndSettle();

    expect(await menuResult, 'overview');
  });

  testWidgets('grid menu honors custom order and update badge', (tester) async {
    final anchorKey = GlobalKey();
    late Future<String?> menuResult;

    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                key: anchorKey,
                onPressed: () {
                  menuResult = showHomeTopGridMenuSheet(
                    context,
                    hasAvailableUpdate: true,
                    entries: resolveHomeGridMenuEntries(
                      TimetableSettings.defaults().copyWith(
                        homeMenuStyle: HomeMenuStyle.grid,
                        // copyWith 会钉住 settings，这里断言的是自定义
                        // 排列顺序本身，settings 在尾部不影响本例。
                        homeGridMenuActions: ['tasks', 'support'],
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // 自定义排列只渲染用户选择的入口，顺序与持久化一致。
    expect(find.text('任务清单'), findsOneWidget);
    expect(find.text('请喝咖啡'), findsOneWidget);
    expect(find.text('软件更新'), findsNothing);

    // 更新角标跟随 hasAvailableUpdate（本例没有更新瓷贴，因此无角标文本）。
    expect(find.text('更新'), findsNothing);

    await tester.tap(find.text('任务清单'));
    await tester.pumpAndSettle();

    expect(await menuResult, 'tasks');
  });

  testWidgets('grid menu tile icons follow the theme seed color', (
    tester,
  ) async {
    final anchorKey = GlobalKey();

    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                key: anchorKey,
                onPressed: () {
                  showHomeTopGridMenuSheet(
                    context,
                    hasAvailableUpdate: false,
                    entries: resolveHomeGridMenuEntries(
                      TimetableSettings.defaults(),
                    ),
                    themeSeedHex: '#1447E6',
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // 可读的主题 seed 直接作为瓷贴图标色（默认蓝）。
    expect(
      tester.widget<Icon>(find.byIcon(Icons.system_update_alt_rounded)).color,
      const Color(0xFF1447E6),
    );
  });

  testWidgets('grid menu tile icons keep the bright seed as-is (所见即所得)', (
    tester,
  ) async {
    final anchorKey = GlobalKey();

    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                key: anchorKey,
                onPressed: () {
                  showHomeTopGridMenuSheet(
                    context,
                    hasAvailableUpdate: false,
                    entries: resolveHomeGridMenuEntries(
                      TimetableSettings.defaults(),
                    ),
                    // 用户选了亮黄主题就要看到亮黄：不做浅色可读回落。
                    themeSeedHex: '#FCC800',
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Icon>(find.byIcon(Icons.system_update_alt_rounded)).color,
      const Color(0xFFFCC800),
    );
  });
}
