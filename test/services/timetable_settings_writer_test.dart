import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/timetable_settings_writer.dart';

/// 假端口：设置/课表/作息表放在内存里，四个副作用钩子只记次数。
class _FakePort implements TimetableSettingsWritePort {
  _FakePort({
    required this.settings,
    List<TimetableProfile> profiles = const <TimetableProfile>[],
    this.timeSchemes = const <TimeScheme>[],
  }) : profiles = List<TimetableProfile>.from(profiles);

  @override
  TimetableSettings settings;

  @override
  List<TimetableProfile> profiles;

  @override
  final List<TimeScheme> timeSchemes;

  int persistCalls = 0;
  bool failPersist = false;
  int notifyCalls = 0;
  final List<TimetableSettings> loggedPrevious = <TimetableSettings>[];
  final List<bool> haptics = <bool>[];

  @override
  Future<void> persistActiveProfileState() async {
    persistCalls++;
    if (failPersist) {
      throw StateError('disk down');
    }
  }

  @override
  void notifyStateChanged() => notifyCalls++;

  @override
  void logPerformanceSnapshotIfChanged(TimetableSettings previous) =>
      loggedPrevious.add(previous);

  @override
  void applyEdgeHaptics(bool enabled) => haptics.add(enabled);
}

const SectionTime _eightOClock = SectionTime(
  startTime: '08:00',
  endTime: '08:45',
);

const SectionTime _nineOClock = SectionTime(
  startTime: '09:00',
  endTime: '09:45',
);

TimetableSettings _settings({
  List<SectionTime> sections = const <SectionTime>[_eightOClock],
  bool enableHaptics = true,
  String localeTag = 'zh',
  String? activeTimeSchemeId,
}) {
  final base = TimetableSettings.defaults().copyWith(
    sections: sections,
    enableHaptics: enableHaptics,
    appLocaleTag: localeTag,
  );
  return activeTimeSchemeId == null
      ? base
      : base.copyWith(activeTimeSchemeId: activeTimeSchemeId);
}

TimeScheme _scheme(String id, List<SectionTime> sections) => TimeScheme(
  id: id,
  name: '模板$id',
  sections: sections,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

TimetableProfile _profile(String id, TimetableSettings settings) =>
    TimetableProfile(
      id: id,
      name: '课表$id',
      courses: const <Course>[],
      settings: settings,
      currentWeek: 1,
      createdAt: DateTime(2026),
      lastUsedAt: DateTime(2026),
    );

void main() {
  group('normalize：设置要看到活动作息模板的节次', () {
    test('活动模板不存在时原样返回', () {
      final port = _FakePort(settings: _settings());
      final next = _settings(sections: const <SectionTime>[_nineOClock]);

      final normalized = TimetableSettingsWriter.normalize(port, next);

      expect(identical(normalized, next), isTrue);
    });

    test('节次已经一致时不重建对象', () {
      final port = _FakePort(
        settings: _settings(activeTimeSchemeId: 's1'),
        timeSchemes: <TimeScheme>[
          _scheme('s1', const <SectionTime>[_eightOClock]),
        ],
      );
      final next = _settings(activeTimeSchemeId: 's1');

      final normalized = TimetableSettingsWriter.normalize(port, next);

      expect(identical(normalized, next), isTrue);
    });

    test('节次不一致时用模板覆盖节次与模板 id', () {
      final port = _FakePort(
        settings: _settings(activeTimeSchemeId: 's1'),
        timeSchemes: <TimeScheme>[
          _scheme('s1', const <SectionTime>[_nineOClock]),
        ],
      );

      final normalized = TimetableSettingsWriter.normalize(
        port,
        _settings(activeTimeSchemeId: 's1'),
      );

      expect(normalized.sections.map((section) => section.startTime), <String>[
        '09:00',
      ]);
      expect(normalized.activeTimeSchemeId, 's1');
    });
  });

  group('update：快照 → 归一 → 落盘 → 失败回滚', () {
    test('成功时落盘一次、通知一次、埋点拿旧值、触感跟随新设置', () async {
      final port = _FakePort(settings: _settings());

      await TimetableSettingsWriter.update(
        port,
        _settings(enableHaptics: false, localeTag: 'en'),
      );

      expect(port.persistCalls, 1);
      expect(port.notifyCalls, 1);
      expect(port.haptics, <bool>[false]);
      expect(port.loggedPrevious, hasLength(1));
      expect(port.loggedPrevious.single.appLocaleTag, 'zh');
      expect(port.settings.appLocaleTag, 'en');
    });

    test('落盘失败时退回设置与课表、通知后上抛，且不埋点', () async {
      final original = _settings();
      final port = _FakePort(
        settings: original,
        profiles: <TimetableProfile>[_profile('p1', original)],
      )..failPersist = true;

      await expectLater(
        TimetableSettingsWriter.update(
          port,
          _settings(localeTag: 'en', enableHaptics: false),
        ),
        throwsA(isA<StateError>()),
      );

      expect(port.settings.appLocaleTag, 'zh');
      expect(port.settings.enableHaptics, isTrue);
      expect(port.profiles.map((profile) => profile.id), <String>['p1']);
      // 归一时新设置(触感 false) → 回滚时恢复旧设置(触感 true)。
      expect(port.haptics, <bool>[false, true]);
      expect(port.notifyCalls, 1);
      expect(port.loggedPrevious, isEmpty);
    });
  });

  group('replaceSavedThemes：主题列表写入共用快照/回滚', () {
    test('成功时只通知、不埋点', () async {
      final port = _FakePort(settings: _settings());
      TimetableSettings? seen;

      await TimetableSettingsWriter.replaceSavedThemes(port, (settings) {
        seen = settings;
        return const <SavedTheme>[];
      });

      expect(seen?.appLocaleTag, 'zh');
      expect(port.persistCalls, 1);
      expect(port.notifyCalls, 1);
      expect(port.loggedPrevious, isEmpty);
      expect(port.settings.savedThemes, isEmpty);
    });

    test('落盘失败时设置退回快照并上抛，不通知', () async {
      final original = _settings();
      final port = _FakePort(settings: original)..failPersist = true;

      await expectLater(
        TimetableSettingsWriter.replaceSavedThemes(
          port,
          (settings) => const <SavedTheme>[],
        ),
        throwsA(isA<StateError>()),
      );

      expect(port.settings.appLocaleTag, 'zh');
      expect(port.settings.savedThemes, isEmpty);
      expect(port.notifyCalls, 0);
      expect(port.loggedPrevious, isEmpty);
    });
  });
}
