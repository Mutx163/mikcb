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

    test('客户端静默超过 idleTimeout 后不再计入已连接设备', () {
      // 用真实当前时间做基准：markClientConnected 内部记的就是 DateTime.now()，
      // 而 verifyToken 还要按真实时间判会话是否过期。
      final now = DateTime.now();
      final session = LanEditSession.forTest(
        pin: '123456',
        token: 'token',
        createdAt: now,
        lastActivityAt: now,
      );

      expect(session.verifyPin('123456', '192.168.1.5'), isTrue);
      expect(session.verifyTokenForRequest('token', '192.168.1.6'), isTrue);
      expect(session.connectedClientCountAt(now), 2);

      // 还在活动窗口内：仍算在线。
      expect(
        session.connectedClientCountAt(
          now.add(LanEditSession.idleTimeout - const Duration(minutes: 1)),
        ),
        2,
      );
      // 关掉标签页/离开局域网不会有断开回调，只有「多久没再请求」能判离线；
      // 只 add 不清零的写法会让机主一直看到历史累计的设备数。
      expect(
        session.connectedClientCountAt(
          now.add(LanEditSession.idleTimeout + const Duration(seconds: 1)),
        ),
        0,
      );
      // 被判离线的客户端再授权一次会重新计入，且不会带回旧 IP。
      expect(session.verifyTokenForRequest('token', '192.168.1.9'), isTrue);
      expect(session.connectedClientCountAt(DateTime.now()), 1);
    });
  });
}
