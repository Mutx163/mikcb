import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/app_dialogs.dart';

import '../../helpers_test_app.dart';

/// 回归：只传 [HyperosTextField.hint] 的输入框（占位模式）里，灰色占位提示不能
/// 压在实际输入的文字上。
///
/// 病灶是「不重建」而不是「画错」：Miuix 只在标签动画控制器动时重画标签，而占位
/// 模式下文本变非空并不动它。`autofocus: true` 的弹窗输入框打开即聚焦，没有任何
/// 别的重建来源，于是每敲一个字都留着灰字（新建课表 / 重命名课表弹窗）。
void main() {
  const hint = '例如：大二下';

  Widget wrap(Widget child) => TestApp(
    home: Scaffold(
      body: Center(child: Padding(padding: const EdgeInsets.all(16), child: child)),
    ),
  );

  testWidgets('autofocused hint field drops the placeholder once text is typed', (
    tester,
  ) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      wrap(
        HyperosTextField(
          controller: controller,
          hint: hint,
          autofocus: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 空文本：占位提示可见，且输入框已经聚焦（复现的关键前提）。
    expect(find.text(hint), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );

    await tester.enterText(find.byType(TextField), '大三上');
    await tester.pumpAndSettle();

    // 输入后占位提示必须让位，不能压在文字上。
    expect(controller.text, '大三上');
    expect(find.text(hint), findsNothing);
  });

  testWidgets('placeholder comes back after the text is cleared', (
    tester,
  ) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      wrap(HyperosTextField(controller: controller, hint: hint, autofocus: true)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '大三上');
    await tester.pumpAndSettle();
    expect(find.text(hint), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);
  });

  testWidgets('hint-only field without an external controller still yields', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const HyperosTextField(hint: hint, autofocus: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);

    await tester.enterText(find.byType(TextField), '大三上');
    await tester.pumpAndSettle();
    expect(find.text(hint), findsNothing);
  });

  testWidgets('floating-label field keeps the label visible above the text', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const HyperosTextField(label: '课表名称', autofocus: true)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '大三上');
    await tester.pumpAndSettle();

    final fieldRect = tester.getRect(find.byType(TextField));
    final labelRect = tester.getRect(find.text('课表名称'));
    expect(find.text('课表名称'), findsOneWidget);
    expect(
      labelRect.overlaps(fieldRect),
      isFalse,
      reason: '浮动标签应浮到输入文字上方，而不是盖在文字上',
    );
  });

  testWidgets('new-timetable sheet stops overlapping hint and typed name', (
    tester,
  ) async {
    // 真机口径：新建课表弹窗（课表管理页右上角 +）用的就是这条路径。
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  final l10n = AppLocalizations.of(context)!;
                  showAppTextInputDialog(
                    context,
                    title: l10n.createTimetableTitle,
                    confirmLabel: l10n.createAction,
                    bodyBuilder: (controller) => HyperosTextField(
                      controller: controller,
                      hint: l10n.timetableNameHint,
                      autofocus: true,
                    ),
                    validate: (value) => value.isNotEmpty,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('例如：大二下'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '大三上');
    await tester.pumpAndSettle();

    expect(find.text('例如：大二下'), findsNothing);
  });
}
