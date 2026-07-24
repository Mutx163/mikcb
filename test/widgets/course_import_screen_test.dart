import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
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

  testWidgets('ai import screen keeps keyboard-aware resizing enabled', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: AiImageCourseImportScreen()));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<FScaffold>(find.byType(FScaffold).first);
    expect(scaffold.resizeToAvoidBottomInset, isTrue);
  });
}
