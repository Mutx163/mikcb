import 'package:flutter/material.dart';

class AppAnalytics {
  AppAnalytics._();

  static final AppAnalytics instance = AppAnalytics._();

  List<NavigatorObserver> get navigatorObservers => const [];

  Future<void> initialize() async {}

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}

  void logEventLater({
    required String name,
    Map<String, Object>? parameters,
  }) {}
}
