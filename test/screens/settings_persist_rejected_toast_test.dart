import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/app_localizations_zh.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// 最小宿主：点一下就把 [reportSettingsPersistRejected] 接到真实 toast 上。
class _RejectHarness extends StatefulWidget {
  const _RejectHarness({required this.message});

  final String message;

  @override
  State<_RejectHarness> createState() => _RejectHarnessState();
}

class _RejectHarnessState extends State<_RejectHarness> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              reportSettingsPersistRejected(this, widget.message),
          child: const Text('reject'),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // TimetableProvider.updateTimetableSettings 在「每天节数低于已有课程用到的
  // 最大节次」时返回的就是这个载荷（见 timetable_provider.dart 的
  // section_count_below_usage 分支）。设置页以前把它原样弹给用户。
  const requiredMaxSection = 12;
  final rejection = encodeServiceMessage('section_count_below_usage', {
    'requiredMaxSection': requiredMaxSection,
  });

  testWidgets('设置被规则拒绝时弹翻译后的文案，不弹内部代码', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _RejectHarness(message: rejection),
      ),
    );

    await tester.tap(find.text('reject'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final expected = AppLocalizationsZh().serviceMsgSectionCountBelowUsage(
      requiredMaxSection,
    );
    expect(find.text(expected), findsOneWidget);
    expect(find.textContaining('section_count_below_usage'), findsNothing);

    hideHyperosToast(animated: false);
    await tester.pump();
  });
}
