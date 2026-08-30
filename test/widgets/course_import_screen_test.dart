import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/course_import_screen.dart';
import 'package:university_timetable/services/warehouse_import_preferences_service.dart';
import '../helpers_test_app.dart';

void main() {
  group('shouldPromptRememberedLoginAutofill', () {
    const remembered = WarehouseRememberedLogin(
      username: 'saved-user',
      password: 'saved-password',
    );

    test('prompts when username is prefilled but password is empty', () {
      const candidate = WarehouseRememberedLogin(
        username: 'prefilled-user',
        password: '',
      );

      expect(
        shouldPromptRememberedLoginAutofill(
          hasPasswordField: true,
          rememberedLogin: remembered,
          candidate: candidate,
          hasPromptedAutofill: false,
          isPromptShowing: false,
        ),
        isTrue,
      );
    });

    test('does not prompt without password field or remembered login', () {
      const candidate = WarehouseRememberedLogin(username: '', password: '');

      expect(
        shouldPromptRememberedLoginAutofill(
          hasPasswordField: false,
          rememberedLogin: remembered,
          candidate: candidate,
          hasPromptedAutofill: false,
          isPromptShowing: false,
        ),
        isFalse,
      );
      expect(
        shouldPromptRememberedLoginAutofill(
          hasPasswordField: true,
          rememberedLogin: null,
          candidate: candidate,
          hasPromptedAutofill: false,
          isPromptShowing: false,
        ),
        isFalse,
      );
    });

    test(
      'does not prompt when password is already filled or prompt is blocked',
      () {
        const filledPassword = WarehouseRememberedLogin(
          username: 'user',
          password: 'typed-password',
        );
        const emptyPassword = WarehouseRememberedLogin(
          username: 'user',
          password: '',
        );

        expect(
          shouldPromptRememberedLoginAutofill(
            hasPasswordField: true,
            rememberedLogin: remembered,
            candidate: filledPassword,
            hasPromptedAutofill: false,
            isPromptShowing: false,
          ),
          isFalse,
        );
        expect(
          shouldPromptRememberedLoginAutofill(
            hasPasswordField: true,
            rememberedLogin: remembered,
            candidate: emptyPassword,
            hasPromptedAutofill: true,
            isPromptShowing: false,
          ),
          isFalse,
        );
        expect(
          shouldPromptRememberedLoginAutofill(
            hasPasswordField: true,
            rememberedLogin: remembered,
            candidate: emptyPassword,
            hasPromptedAutofill: false,
            isPromptShowing: true,
          ),
          isFalse,
        );
      },
    );
  });

  group('shouldPromptRememberedLoginSave', () {
    const completeRemembered = WarehouseRememberedLogin(
      username: 'saved-user',
      password: 'saved-password',
    );
    // 密码丢失后遗留的「只有用户名」残缺条目（僵尸条目）。
    const usernameOnlyRemembered = WarehouseRememberedLogin(
      username: 'saved-user',
      password: '',
    );

    test('prompts when nothing is remembered yet', () {
      expect(
        shouldPromptRememberedLoginSave(
          rememberedLogin: null,
          hasPromptedSave: false,
          isPromptShowing: false,
          candidateUsername: 'typed-user',
          candidatePassword: 'typed-password',
        ),
        isTrue,
      );
    });

    test('prompts again when remembered entry has empty password', () {
      // 回归用例：残缺条目曾把保存提示永久堵死，凭据丢密码后无法补录。
      expect(
        shouldPromptRememberedLoginSave(
          rememberedLogin: usernameOnlyRemembered,
          hasPromptedSave: false,
          isPromptShowing: false,
          candidateUsername: 'typed-user',
          candidatePassword: 'typed-password',
        ),
        isTrue,
      );
    });

    test('does not prompt when a complete login is already remembered', () {
      expect(
        shouldPromptRememberedLoginSave(
          rememberedLogin: completeRemembered,
          hasPromptedSave: false,
          isPromptShowing: false,
          candidateUsername: 'typed-user',
          candidatePassword: 'typed-password',
        ),
        isFalse,
      );
    });

    test('does not prompt without a full typed candidate', () {
      expect(
        shouldPromptRememberedLoginSave(
          rememberedLogin: null,
          hasPromptedSave: false,
          isPromptShowing: false,
          candidateUsername: 'typed-user',
          candidatePassword: '',
        ),
        isFalse,
      );
      expect(
        shouldPromptRememberedLoginSave(
          rememberedLogin: null,
          hasPromptedSave: false,
          isPromptShowing: false,
          candidateUsername: '',
          candidatePassword: 'typed-password',
        ),
        isFalse,
      );
    });

    test('does not prompt twice or while a prompt is showing', () {
      expect(
        shouldPromptRememberedLoginSave(
          rememberedLogin: null,
          hasPromptedSave: true,
          isPromptShowing: false,
          candidateUsername: 'typed-user',
          candidatePassword: 'typed-password',
        ),
        isFalse,
      );
      expect(
        shouldPromptRememberedLoginSave(
          rememberedLogin: null,
          hasPromptedSave: false,
          isPromptShowing: true,
          candidateUsername: 'typed-user',
          candidatePassword: 'typed-password',
        ),
        isFalse,
      );
    });
  });

  group('shouldAutoRecordWarehouseImport', () {
    test('auto-records first ordinary import when no macro exists', () {
      expect(
        shouldAutoRecordWarehouseImport(
          forceRecord: false,
          hasExistingMacro: false,
        ),
        isTrue,
      );
    });

    test('skips auto-record when a macro already exists', () {
      expect(
        shouldAutoRecordWarehouseImport(
          forceRecord: false,
          hasExistingMacro: true,
        ),
        isFalse,
      );
    });

    test('always records when user explicitly chooses record import', () {
      expect(
        shouldAutoRecordWarehouseImport(
          forceRecord: true,
          hasExistingMacro: true,
        ),
        isTrue,
      );
      expect(
        shouldAutoRecordWarehouseImport(
          forceRecord: true,
          hasExistingMacro: false,
        ),
        isTrue,
      );
    });
  });

  group('shouldOverrideLocalColorsOnImport', () {
    // 回归锁定：颜色更新只允许发生在覆盖导入。更新/下拉快捷导入必须保留
    // 本地颜色，否则每次同步都会把整张课表的颜色重新洗一遍。
    test('overrides only when overwriting with random colors enabled', () {
      expect(
        shouldOverrideLocalColorsOnImport(
          replaceExisting: true,
          randomColorsEnabled: true,
        ),
        isTrue,
      );
    });

    test('never overrides on update paths regardless of random colors', () {
      expect(
        shouldOverrideLocalColorsOnImport(
          replaceExisting: false,
          randomColorsEnabled: true,
        ),
        isFalse,
      );
      expect(
        shouldOverrideLocalColorsOnImport(
          replaceExisting: false,
          randomColorsEnabled: false,
        ),
        isFalse,
      );
    });

    test('keeps local colors when overwriting without random colors', () {
      expect(
        shouldOverrideLocalColorsOnImport(
          replaceExisting: true,
          randomColorsEnabled: false,
        ),
        isFalse,
      );
    });
  });

  testWidgets('ai import screen keeps keyboard-aware resizing enabled', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: AiImageCourseImportScreen()));
    await tester.pumpAndSettle();

    // The screen's own Scaffold (inside HyperosSubpage), not the TestApp
    // builder's outer Scaffold which pins resizeToAvoidBottomInset to false.
    final scaffold = tester.widget<Scaffold>(
      find
          .descendant(
            of: find.byType(AiImageCourseImportScreen),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(scaffold.resizeToAvoidBottomInset, isTrue);
  });
}
