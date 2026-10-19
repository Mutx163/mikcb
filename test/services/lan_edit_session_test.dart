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

  group('会话级 PIN 失败总预算（防伪造源 IP 绕过单 IP 限速）', () {
    test('换着源地址各试一次，达到总预算后整段会话锁死', () {
      final session = LanEditSession.forTest(
        pin: '123456',
        token: 'token',
        createdAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
      );

      // 50 个不同源地址各失败一次：单 IP 限速（5 次/5 分钟）一次都没触发，
      // 128 条的容量上限也没触发——旧实现下这些尝试毫无代价。
      expect(session.isPinLocked, isFalse);
      for (var i = 0; i < LanEditSession.maxPinFailuresPerSession; i++) {
        expect(
          session.verifyPin('000000', '10.0.$i.1'),
          isFalse,
          reason: '第 ${i + 1} 次失败（IP 10.0.$i.1）应只是普通失败',
        );
      }

      expect(session.isPinLocked, isTrue);
      // 锁死后连正确 PIN 也不放行：唯一出路是机主重新开会话。
      expect(session.verifyPin('123456', '10.0.99.9'), isFalse);
      // 锁定对任意 IP 都表现为限速（服务端据此答 429，让客户端停止重试）。
      expect(session.isPinRateLimited('10.0.99.9'), isTrue);
    });

    test('预算内正确 PIN 不受影响，成功不计入失败', () {
      final session = LanEditSession.forTest(
        pin: '123456',
        token: 'token',
        createdAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
      );

      expect(session.verifyPin('000000', '10.0.0.1'), isFalse);
      expect(session.verifyPin('000000', '10.0.0.2'), isFalse);
      expect(session.isPinLocked, isFalse);
      expect(session.verifyPin('123456', '10.0.0.3'), isTrue);
      expect(session.isPinLocked, isFalse);
    });

    test('总预算必须远小于穷举空间（90 万组合）', () {
      // 这条锁住常量的量级：有人把预算调大到「穷举可行」的量级时先红再议。
      expect(LanEditSession.maxPinFailuresPerSession, lessThan(1000));
      expect(
        LanEditSession.maxPinFailuresPerSession,
        greaterThan(LanEditSession.maxPinAttemptsPerIp),
      );
    });
  });
}
