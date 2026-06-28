import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Tracks PIN, bearer token, and idle expiry for a LAN edit session.
class LanEditSession {
  static const Duration idleTimeout = Duration(minutes: 30);
  static const Duration maxDuration = Duration(hours: 2);
  static const int maxPinAttemptsPerIp = 5;
  static const Duration pinAttemptWindow = Duration(minutes: 5);

  final String pin;
  final String token;
  final DateTime createdAt;
  DateTime lastActivityAt;

  final Map<String, _PinAttemptState> _pinAttempts = {};
  final Set<String> _connectedClientIps = {};

  LanEditSession._({
    required this.pin,
    required this.token,
    required this.createdAt,
    required this.lastActivityAt,
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
  }) {
    return LanEditSession._(
      pin: pin,
      token: token,
      createdAt: createdAt,
      lastActivityAt: lastActivityAt,
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

  int get connectedClientCount => _connectedClientIps.length;

  void markClientConnected(String clientIp) {
    final ip = clientIp.trim();
    if (ip.isEmpty) {
      return;
    }
    _connectedClientIps.add(ip);
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
    if (pin == submittedPin.trim()) {
      _pinAttempts.remove(clientIp);
      markClientConnected(clientIp);
      return true;
    }
    final state = _pinAttempts.putIfAbsent(clientIp, _PinAttemptState.new);
    state.recordFailure(DateTime.now());
    return false;
  }

  bool verifyToken(String? bearerToken) {
    if (bearerToken == null || bearerToken.isEmpty) {
      return false;
    }
    if (token != bearerToken) {
      return false;
    }
    if (isExpired) {
      return false;
    }
    touch();
    return true;
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
}
