import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../models/app_config.dart';

class ConfigImportException implements Exception {
  ConfigImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class ConfigFileService {
  static const defaultFileName = 'osc-controller-config.json';

  static Future<bool> exportConfig(
    AppConfig config, {
    String? dialogTitle,
  }) async {
    final path = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return false;

    final filePath = path.toLowerCase().endsWith('.json') ? path : '$path.json';
    final encoded =
        const JsonEncoder.withIndent('  ').convert(config.toJson());
    await File(filePath).writeAsString(encoded);
    return true;
  }

  static Future<AppConfig> importConfig({String? dialogTitle}) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) {
      throw ConfigImportException('cancelled');
    }

    final path = result.files.single.path;
    if (path == null) {
      throw ConfigImportException('cancelled');
    }

    try {
      final text = await File(path).readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw ConfigImportException('invalid');
      }
      return AppConfig.fromJson(decoded);
    } on ConfigImportException {
      rethrow;
    } on Object {
      throw ConfigImportException('invalid');
    }
  }
}
