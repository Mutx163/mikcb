import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/couple_webdav_config.dart';
import 'package:university_timetable/services/couple_webdav_service.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/app_dialogs.dart';
import 'package:university_timetable/widgets/couple_webdav_connect_sheet.dart';
import 'package:university_timetable/widgets/course_note_sheet.dart';

import '../helpers_test_app.dart';

/// 回归钉（2026-10-02 审查第 6 轮，弹层的「点了没反应」与静默失败）：
///
/// 1. `showAppTextInputDialog` 的 `_submit` 在校验失败时 `return`：确认按钮既
///    不置灰也不给原因。课表档改名 / 新建档、作息模板新建 / 改名、主题命名都
///    走它（`timetable_profiles_screen.dart:134`、
///    `time_scheme_management_screen.dart:454/481`、
///    `theme_manage_sheets.dart:308` 传的都是 `value.isNotEmpty`）——
///    名字留空点「创建」，界面一动不动，用户只能反复点或以为 app 卡死。
/// 2. 情侣课表 WebDAV 连接弹层同理：用户名或密码为空时 `_testConnection`
///    直接 `return false`，`_confirmConnect` 收到 false 就 return，
///    既不测也不连更不提示。
/// 3. 课程备注弹层 `_save` 的 `catch (_)` 只把按钮的转圈停下：
///    `provider.updateCourse` 会 rethrow 落库失败（本仓的写盘收口形状），
///    用户写完作业记录点了「保存」，没有任何失败提示就划走弹层，备注丢了。
///
/// 修法沿用本仓既有形状：输入不全 → 按钮 `onPressed: null`（与
/// `course_followup_sheets.dart:524` 的 `onPressed: _hasChanges ? … : null`
/// 同形）；写入失败 → `showAppToast(l10n.saveFailed, kind: error)`。
class _FailingStorage extends StorageService {
  _FailingStorage() : super.forTesting();

  int profileFailures = 0;

  @override
  Future<void> saveProfiles(List<TimetableProfile> profiles) {
    if (profileFailures > 0) {
      profileFailures--;
      return Future<void>.error(StateError('test_profile_write_failed'));
    }
    return super.saveProfiles(profiles);
  }
}

HyperosButton buttonLabeled(WidgetTester tester, String label) =>
    tester.widget<HyperosButton>(
      find.byWidgetPredicate(
        (widget) => widget is HyperosButton && widget.label == label,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('文本输入弹层的校验不再静默吞掉点击', () {
    Future<void> openDialog(
      WidgetTester tester, {
      bool Function(String)? validate,
    }) async {
      await tester.pumpWidget(
        TestApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppTextInputDialog(
                context,
                title: '新建课表',
                confirmLabel: '创建',
                validate: validate,
                bodyBuilder: (controller) => TextField(controller: controller),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('必填输入为空时确认按钮是禁用的', (tester) async {
      await openDialog(tester, validate: (value) => value.isNotEmpty);

      expect(buttonLabeled(tester, '创建').onPressed, isNull);

      await tester.enterText(find.byType(TextField), '新课表');
      await tester.pump();

      expect(buttonLabeled(tester, '创建').onPressed, isNotNull);
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('没有校验时仍允许提交空值（不改变既有调用方）', (tester) async {
      await openDialog(tester);

      expect(buttonLabeled(tester, '创建').onPressed, isNotNull);
    });
  });

  group('情侣 WebDAV 连接弹层', () {
    Future<void> openSheet(
      WidgetTester tester, {
      String username = '',
    }) async {
      await tester.pumpWidget(
        TestApp(
          home: CoupleWebdavConnectSheet(
            service: CoupleWebdavService(),
            config: CoupleWebdavConfig(username: username),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('凭据没填齐时两个动作按钮都禁用', (tester) async {
      await openSheet(tester);

      expect(buttonLabeled(tester, '测试连接').onPressed, isNull);
      expect(buttonLabeled(tester, '连接并拉取').onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'me@example.com');
      await tester.pump();
      // 密码仍为空 —— 还是不该能点。
      expect(buttonLabeled(tester, '测试连接').onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'secret');
      await tester.pump();
      expect(buttonLabeled(tester, '测试连接').onPressed, isNotNull);
      expect(buttonLabeled(tester, '连接并拉取').onPressed, isNotNull);
    });

    testWidgets('已存过用户名、密码为空时依然禁用', (tester) async {
      await openSheet(tester, username: 'stored@example.com');

      expect(buttonLabeled(tester, '测试连接').onPressed, isNull);
    });
  });

  group('课程备注弹层', () {
    late _FailingStorage storage;
    late TimetableProvider provider;

    Future<TimetableProvider> boot() async {
      SharedPreferences.setMockInitialValues({});
      storage = _FailingStorage();
      final created = TimetableProvider(
        storageService: storage,
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await created.initialize();
      return created;
    }

    Course course() => Course(
      id: 'note-course',
      name: '高等数学',
      teacher: '张老师',
      location: 'A101',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:40',
    );

    tearDown(() {
      provider.dispose();
    });

    testWidgets('落库失败时给出「保存失败」提示，不再只停掉转圈', (tester) async {
      provider = await boot();
      await provider.addCourse(course());
      storage.profileFailures = 1;

      await tester.pumpWidget(
        TestApp(
          home: ChangeNotifierProvider.value(
            value: provider,
            child: CourseNoteSheetBody(course: course(), week: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '这周要交论文');
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump();

      expect(find.text('保存失败'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // 弹层必须还开着：内容没落盘，收起就等于丢数据。
      expect(find.text('保存'), findsWidgets);
      // 注意：本条**不**断言内存已回滚。`updateCourse` 目前是「改内存 → await
      // 落库 → rethrow」而没有 catch 回滚（timetable_provider.dart:2619 起，
      // deleteCourse 同形），与主题族 / 作息 / 地点分组 / 删档已经统一的收口
      // 形状不一致 —— 那是另一条更大的改动（要连带回滚同名课程的共享字段扇出
      // 与作业同步），留给后续单独一轮。这里的提示至少不再让用户以为已保存。
    });

    // 成功路径没有留 widget 测试：`updateCourse` 成功之后会走同步通知与
    // `_updateLiveActivity`，在 testWidgets 的 FakeAsync 里那条 Future 挂住不收，
    // 弹层测试跑不出结论（试过的 pump / pumpAndSettle 两种写法都会挂死）。
    // 写入成功本身由 test/providers/ 下的 provider 测试覆盖；「成功时不该弹
    // 失败提示」由代码形状保证（toast 只在 catch 分支里）。
  });
}
