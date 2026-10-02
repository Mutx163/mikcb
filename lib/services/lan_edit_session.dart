import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Tracks PIN, bearer token, and idle expiry for a LAN edit session.
class LanEditSession {
  static const Duration idleTimeout = Duration(minutes: 30);
  static const Duration maxDuration = Duration(hours: 2);
  static const int maxPinAttemptsPerIp = 5;
  static const Duration pinAttemptWindow = Duration(minutes: 5);

  /// 限流表与已连接客户端集合的容量上限。
  ///
  /// 此前两张表只增不减：`prune` 只在**同一个 IP 再来一次**时执行，也没有总量
  /// 上限。同网段里大量不同源地址（或伪造地址）各试一次错 PIN，就能在会话的
  /// 2 小时内攒出无上限的 `String -> List<DateTime>` 条目。上限取到远大于正常
  /// 使用（一个房间里不会有 128 台设备配对），触发时先丢过期项、再按插入序丢最旧。
  static const int maxTrackedClients = 128;

  final String pin;
  final String token;
  final DateTime createdAt;
  DateTime lastActivityAt;

  /// Profile id the LAN client is editing; required for write authorization.
  String? boundProfileId;

  final Map<String, _PinAttemptState> _pinAttempts = {};

  /// 客户端 IP → 最近一次成功授权的时间。
  final Map<String, DateTime> _connectedClientSeenAt = {};

  LanEditSession._({
    required this.pin,
    required this.token,
    required this.createdAt,
    required this.lastActivityAt,
    this.boundProfileId,
  });

  factory LanEditSession.create({Random? random}) {
    final rng = random ?? Random.secure();
    final pin = (100000 + rng.nextInt(900000)).toString();
    final now = DateTime.now();
    return LanEditSession._(
      pin: pin,
      token: const Uuid().v4(),
      createdAt: now,
      lastActivityAt: now,
    );
  }

  @visibleForTesting
  factory LanEditSession.forTest({
    required String pin,
    required String token,
    required DateTime createdAt,
    required DateTime lastActivityAt,
    String? boundProfileId,
  }) {
    return LanEditSession._(
      pin: pin,
      token: token,
      createdAt: createdAt,
      lastActivityAt: lastActivityAt,
      boundProfileId: boundProfileId,
    );
  }

  void touch() {
    lastActivityAt = DateTime.now();
  }

  bool get isExpired => isExpiredAt(DateTime.now());

  bool isExpiredAt(DateTime now) {
    if (now.difference(createdAt) > maxDuration) {
      return true;
    }
    return now.difference(lastActivityAt) > idleTimeout;
  }

  int get connectedClientCount => connectedClientCountAt(DateTime.now());

  /// 只 add 不清的计数会把「已连接 N 台」变成**历史累计**：浏览器关标签页、
  /// 手机走出宿舍，都不会有任何断开回调（HTTP 没有连接生命周期可依赖），
  /// 机主看到的数字只增不减，无法据此判断此刻是否还有人正在编辑课表。
  ///
  /// 「离线」判据沿用会话自己的 [idleTimeout]：超过它没再请求的客户端
  /// 已经拿不到写授权（`verifyToken` 会因 [isExpiredAt] 为真而拒），
  /// 因此它不该再被算作在线。
  int connectedClientCountAt(DateTime now) {
    _connectedClientSeenAt.removeWhere(
      (_, seenAt) => now.difference(seenAt) > idleTimeout,
    );
    return _connectedClientSeenAt.length;
  }

  void markClientConnected(String clientIp) {
    final ip = clientIp.trim();
    if (ip.isEmpty) {
      return;
    }
    _connectedClientSeenAt[ip] = DateTime.now();
    touch();
  }

  bool isPinRateLimited(String clientIp) {
    final state = _pinAttempts[clientIp];
    if (state == null) {
      return false;
    }
    state.prune(pinAttemptWindow);
    return state.failures.length >= maxPinAttemptsPerIp;
  }

  bool verifyPin(String submittedPin, String clientIp) {
    if (isPinRateLimited(clientIp)) {
      return false;
    }
    if (_constantTimeEquals(pin, submittedPin.trim())) {
      _pinAttempts.remove(clientIp);
      markClientConnected(clientIp);
      return true;
    }
    final state = _pinAttempts.putIfAbsent(clientIp, _PinAttemptState.new);
    state.recordFailure(DateTime.now());
    _trimClientBookkeeping();
    return false;
  }

  bool verifyToken(String? bearerToken) {
    if (bearerToken == null || bearerToken.isEmpty) {
      return false;
    }
    // 局域网内的逐字符计时探测需要数千次低抖动往返，实际不可行；但既然这里比较的
    // 是唯一的写授权凭据，就用与 app_update_service 校验 APK 摘要同一套写法。
    if (!_constantTimeEquals(token, bearerToken)) {
      return false;
    }
    if (isExpired) {
      return false;
    }
    touch();
    return true;
  }

  /// 长度不等直接拒（只泄露定长凭据的长度），逐字符用异或累积，避免短路比较
  /// 让命中前缀数被计时差读出来。
  static bool _constantTimeEquals(String expected, String actual) {
    if (expected.length != actual.length) {
      return false;
    }
    var diff = 0;
    for (var index = 0; index < expected.length; index++) {
      diff |= expected.codeUnitAt(index) ^ actual.codeUnitAt(index);
    }
    return diff == 0;
  }

  void _trimClientBookkeeping() {
    if (_pinAttempts.length <= maxTrackedClients &&
        _connectedClientSeenAt.length <= maxTrackedClients) {
      return;
    }
    _pinAttempts.removeWhere((_, state) => state.isIdleFor(pinAttemptWindow));
    while (_pinAttempts.length > maxTrackedClients) {
      _pinAttempts.remove(_pinAttempts.keys.first);
    }
    while (_connectedClientSeenAt.length > maxTrackedClients) {
      _connectedClientSeenAt.remove(_connectedClientSeenAt.keys.first);
    }
  }

  bool verifyTokenForRequest(String? bearerToken, String clientIp) {
    if (!verifyToken(bearerToken)) {
      return false;
    }
    markClientConnected(clientIp);
    return true;
  }

  DateTime get expiresAt {
    final idleExpiry = lastActivityAt.add(idleTimeout);
    final hardExpiry = createdAt.add(maxDuration);
    return idleExpiry.isBefore(hardExpiry) ? idleExpiry : hardExpiry;
  }
}

class _PinAttemptState {
  final List<DateTime> failures = [];

  void recordFailure(DateTime time) {
    failures.add(time);
    prune(LanEditSession.pinAttemptWindow);
  }

  void prune(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    failures.removeWhere((time) => time.isBefore(cutoff));
  }

  /// 窗口内已无可计数的失败记录，可以整条回收。
  bool isIdleFor(Duration window) {
    prune(window);
    return failures.isEmpty;
  }
}
