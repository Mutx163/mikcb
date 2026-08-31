import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/lan_edit_session.dart';

void main() {
  group('LanEditSession expiry', () {
    test('expires after idle timeout', () {
      final base = DateTime(2026, 6, 27, 12);
      final session = LanEditSession.forTest(
        pin: '123456',
        token: 'token',
        createdAt: base,
        lastActivityAt: base,
      );

      expect(
        session.isExpiredAt(base.add(LanEditSession.idleTimeout)),
        isFalse,
      );
      expect(
        session.isExpiredAt(
          base.add(LanEditSession.idleTimeout + const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('expires after hard cap even with recent activity', () {
      final base = DateTime(2026, 6, 27, 12);
      final session = LanEditSession.forTest(
        pin: '123456',
        token: 'token',
        createdAt: base,
        lastActivityAt: base.add(LanEditSession.maxDuration),
      );

      expect(
        session.isExpiredAt(base.add(LanEditSession.maxDuration)),
        isFalse,
      );
      expect(
        session.isExpiredAt(
          base.add(LanEditSession.maxDuration + const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });
  });

  group('LanEditSession PIN rate limiting', () {
    test('blocks after five failures from same IP', () {
      final session = LanEditSession.forTest(
        pin: '123456',
        token: 'token',
        createdAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
      );
      const clientIp = '10.0.0.8';

      for (var i = 0; i < LanEditSession.maxPinAttemptsPerIp; i++) {
        expect(session.verifyPin('000000', clientIp), isFalse);
      }

      expect(session.isPinRateLimited(clientIp), isTrue);
      expect(session.verifyPin('123456', clientIp), isFalse);
    });

    test('tracks connected clients after successful PIN', () {
      final session = LanEditSession.forTest(
        pin: '123456',
        token: 'token',
        createdAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
      );

      expect(session.connectedClientCount, 0);
      expect(session.verifyPin('123456', '192.168.1.5'), isTrue);
      expect(session.connectedClientCount, 1);
      expect(session.verifyTokenForRequest('token', '192.168.1.6'), isTrue);
      expect(session.connectedClientCount, 2);
    });
  });
}
