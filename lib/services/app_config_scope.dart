import 'package:flutter/material.dart';

import 'app_config_store.dart';

class AppConfigScope extends InheritedNotifier<AppConfigStore> {
  const AppConfigScope({
    super.key,
    required AppConfigStore super.notifier,
    required super.child,
  });

  static AppConfigStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppConfigScope>();
    assert(scope != null, 'AppConfigScope not found');
    return scope!.notifier!;
  }
}
