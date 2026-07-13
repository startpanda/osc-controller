import 'dart:async';

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'locale/locale_service.dart';
import 'screens/app_shell.dart';
import 'services/app_config_scope.dart';
import 'services/app_config_store.dart';
import 'services/osc_service.dart';
import 'services/osc_service_scope.dart';
import 'theme/app_theme.dart';

final _localeService = LocaleService();
final _oscService = OscService();
late final AppConfigStore _configStore;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configStore = AppConfigStore();
  await _configStore.load();
  _localeService.restoreLocaleCode(_configStore.config.localeCode);
  _localeService.bindConfigStore(_configStore);
  runApp(OscControllerApp(configStore: _configStore));
}

class OscControllerApp extends StatefulWidget {
  const OscControllerApp({super.key, required this.configStore});

  final AppConfigStore configStore;

  @override
  State<OscControllerApp> createState() => _OscControllerAppState();
}

class _OscControllerAppState extends State<OscControllerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.configStore.flush());
    _oscService.dispose();
    widget.configStore.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(widget.configStore.flush());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppConfigScope(
      notifier: widget.configStore,
      child: OscServiceScope(
        notifier: _oscService,
        child: LocaleScope(
          notifier: _localeService,
          child: ListenableBuilder(
            listenable: _localeService,
            builder: (context, _) {
              return MaterialApp(
                title: 'OSC Control Panel',
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(),
                locale: _localeService.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.delegates,
                home: const AppShell(),
              );
            },
          ),
        ),
      ),
    );
  }
}
