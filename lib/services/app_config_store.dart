import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_config.dart';

class AppConfigStore extends ChangeNotifier {
  AppConfig _config = const AppConfig();
  Timer? _saveTimer;
  bool _loaded = false;

  AppConfig get config => _config;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final file = await _configFile();
      if (await file.exists()) {
        final text = await file.readAsString();
        final json = jsonDecode(text);
        if (json is Map<String, dynamic>) {
          _config = AppConfig.fromJson(json);
        }
      }
    } catch (error) {
      debugPrint('Failed to load app config: $error');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _writeConfig();
  }

  void updateLocale(String localeCode) {
    if (_config.localeCode == localeCode) return;
    _config = _config.copyWith(localeCode: localeCode);
    _scheduleSave();
    notifyListeners();
  }

  void updateActiveTab(String activeTab) {
    if (_config.activeTab == activeTab) return;
    _config = _config.copyWith(activeTab: activeTab);
    _scheduleSave();
    notifyListeners();
  }

  void updateSender(SenderConfig sender) {
    _config = _config.copyWith(sender: sender);
    _scheduleSave();
  }

  void updateReceiver(ReceiverConfig receiver) {
    _config = _config.copyWith(receiver: receiver);
    _scheduleSave();
  }

  void replaceConfig(AppConfig config) {
    _config = config;
    _scheduleSave();
    notifyListeners();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_writeConfig());
    });
  }

  Future<File> _configFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'osc_controller_config.json'));
  }

  Future<void> _writeConfig() async {
    try {
      final file = await _configFile();
      await file.parent.create(recursive: true);
      final encoded = const JsonEncoder.withIndent('  ').convert(_config.toJson());
      await file.writeAsString(encoded);
    } catch (error) {
      debugPrint('Failed to save app config: $error');
    }
  }
}
