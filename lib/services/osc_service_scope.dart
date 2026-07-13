import 'package:flutter/material.dart';

import 'osc_service.dart';

class OscServiceScope extends InheritedNotifier<OscService> {
  const OscServiceScope({
    super.key,
    required OscService super.notifier,
    required super.child,
  });

  static OscService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<OscServiceScope>();
    assert(scope != null, 'OscServiceScope not found');
    return scope!.notifier!;
  }
}
