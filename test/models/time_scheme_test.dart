import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_settings.dart';

void main() {
  test('time scheme serializes complete state', () {
    final scheme = TimeScheme(
      id: 'summer',
      name: '夏季作息',
      sections: const [
        SectionTime(startTime: '08:00', endTime: '08:45'),
        SectionTime(startTime: '08:55', endTime: '09:40'),
      ],
      createdAt: DateTime(2026, 3, 22, 9),
      updatedAt: DateTime(2026, 3, 22, 10),
    );

    final restored = TimeScheme.fromJson(scheme.toJson());

    expect(restored.id, 'summer');
    expect(restored.name, '夏季作息');
    expect(restored.sectionCount, 2);
    expect(restored.sections.first.displayText, '08:00-08:45');
    expect(restored.createdAt, DateTime(2026, 3, 22, 9));
    expect(restored.updatedAt, DateTime(2026, 3, 22, 10));
  });
}
