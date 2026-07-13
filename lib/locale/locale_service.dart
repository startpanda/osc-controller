import 'package:flutter/material.dart';

import '../services/app_config_store.dart';

class LocaleService extends ChangeNotifier {
  Locale _locale = const Locale('zh');
  AppConfigStore? _configStore;

  Locale get locale => _locale;

  bool get isChinese => _locale.languageCode == 'zh';

  void bindConfigStore(AppConfigStore store) {
    _configStore = store;
  }

  void restoreLocaleCode(String code) {
    _locale = Locale(code);
  }

  void setChinese() => setLocale(const Locale('zh'));

  void setEnglish() => setLocale(const Locale('en'));

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    _configStore?.updateLocale(locale.languageCode);
    notifyListeners();
  }

  void syncLocaleCode(String code) {
    final locale = Locale(code);
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }
}

class LocaleScope extends InheritedNotifier<LocaleService> {
  const LocaleScope({
    super.key,
    required LocaleService super.notifier,
    required super.child,
  });

  static LocaleService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'LocaleScope not found');
    return scope!.notifier!;
  }
}
