import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/debug_deep_link_service.dart';

void main() {
  test('parses path and query from native payload', () {
    final command = DebugDeepLinkCommand.tryParse({
      'path': 'action/seed-soon',
      'query': {'minutes': '15'},
    });

    expect(command, isNotNull);
    expect(command!.path, 'action/seed-soon');
    expect(command.queryInt('minutes'), 15);
  });

  test('normalizes leading slash in path', () {
    final command = DebugDeepLinkCommand.tryParse({
      'path': '/settings/live',
      'query': <String, String>{},
    });

    expect(command?.path, 'settings/live');
  });

  test('returns null for empty path', () {
    expect(DebugDeepLinkCommand.tryParse({'path': '  '}), isNull);
    expect(DebugDeepLinkCommand.tryParse(null), isNull);
  });
}
