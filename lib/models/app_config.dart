import 'osc_models.dart';

class AppConfig {
  const AppConfig({
    this.version = currentVersion,
    this.localeCode = 'zh',
    this.activeTab = 'sender',
    this.sender = const SenderConfig(),
    this.receiver = const ReceiverConfig(),
  });

  static const currentVersion = 1;

  final int version;
  final String localeCode;
  final String activeTab;
  final SenderConfig sender;
  final ReceiverConfig receiver;

  AppConfig copyWith({
    String? localeCode,
    String? activeTab,
    SenderConfig? sender,
    ReceiverConfig? receiver,
  }) {
    return AppConfig(
      version: version,
      localeCode: localeCode ?? this.localeCode,
      activeTab: activeTab ?? this.activeTab,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      version: json['version'] as int? ?? currentVersion,
      localeCode: json['localeCode'] as String? ?? 'zh',
      activeTab: json['activeTab'] as String? ?? 'sender',
      sender: json['sender'] is Map<String, dynamic>
          ? SenderConfig.fromJson(json['sender'] as Map<String, dynamic>)
          : const SenderConfig(),
      receiver: json['receiver'] is Map<String, dynamic>
          ? ReceiverConfig.fromJson(json['receiver'] as Map<String, dynamic>)
          : const ReceiverConfig(),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'localeCode': localeCode,
        'activeTab': activeTab,
        'sender': sender.toJson(),
        'receiver': receiver.toJson(),
      };
}

class SenderConfig {
  const SenderConfig({
    this.targets = const [],
    this.controls = const [],
    this.admObjectChannel = 1,
  });

  final List<OscTarget> targets;
  final List<OscControl> controls;
  final int admObjectChannel;

  SenderConfig copyWith({
    List<OscTarget>? targets,
    List<OscControl>? controls,
    int? admObjectChannel,
  }) {
    return SenderConfig(
      targets: targets ?? this.targets,
      controls: controls ?? this.controls,
      admObjectChannel: admObjectChannel ?? this.admObjectChannel,
    );
  }

  factory SenderConfig.fromJson(Map<String, dynamic> json) {
    return SenderConfig(
      targets: _readList(json['targets'], OscTargetJson.fromJson),
      controls: _readList(json['controls'], OscControlJson.fromJson),
      admObjectChannel: json['admObjectChannel'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'targets': targets.map(OscTargetJson.toJson).toList(),
        'controls': controls.map(OscControlJson.toJson).toList(),
        'admObjectChannel': admObjectChannel,
      };
}

class ReceiverConfig {
  const ReceiverConfig({
    this.ports = const [],
    this.viewMode = 'graph',
    this.expandedPorts = const [],
  });

  final List<ListenerPort> ports;
  final String viewMode;
  final List<String> expandedPorts;

  ReceiverConfig copyWith({
    List<ListenerPort>? ports,
    String? viewMode,
    List<String>? expandedPorts,
  }) {
    return ReceiverConfig(
      ports: ports ?? this.ports,
      viewMode: viewMode ?? this.viewMode,
      expandedPorts: expandedPorts ?? this.expandedPorts,
    );
  }

  factory ReceiverConfig.fromJson(Map<String, dynamic> json) {
    return ReceiverConfig(
      ports: _readList(json['ports'], ListenerPortJson.fromJson),
      viewMode: json['viewMode'] as String? ?? 'graph',
      expandedPorts: _readStringList(json['expandedPorts']),
    );
  }

  Map<String, dynamic> toJson() => {
        'ports': ports.map(ListenerPortJson.toJson).toList(),
        'viewMode': viewMode,
        'expandedPorts': expandedPorts,
      };
}

List<T> _readList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

List<String> _readStringList(dynamic value) {
  if (value is! List) return [];
  return value.map((item) => item.toString()).toList();
}

abstract final class OscTargetJson {
  static OscTarget fromJson(Map<String, dynamic> json) {
    return OscTarget(
      id: json['id'] as String? ?? '',
      ip: json['ip'] as String? ?? '',
      port: json['port'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      label: json['label'] as String? ?? '',
    );
  }

  static Map<String, dynamic> toJson(OscTarget target) => {
        'id': target.id,
        'ip': target.ip,
        'port': target.port,
        'enabled': target.enabled,
        'label': target.label,
      };
}

abstract final class ListenerPortJson {
  static ListenerPort fromJson(Map<String, dynamic> json) {
    return ListenerPort(
      id: json['id'] as String? ?? '',
      port: json['port'] as String? ?? '',
      active: json['active'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> toJson(ListenerPort port) => {
        'id': port.id,
        'port': port.port,
        'active': port.active,
      };
}

abstract final class OscControlJson {
  static OscControl fromJson(Map<String, dynamic> json) {
    return OscControl(
      id: json['id'] as String? ?? '',
      type: _controlTypeFrom(json['type'] as String?),
      label: json['label'] as String? ?? '',
      address: json['address'] as String? ?? '/control',
      min: (json['min'] as num?)?.toDouble() ?? 0,
      max: (json['max'] as num?)?.toDouble() ?? 1,
      step: (json['step'] as num?)?.toDouble() ?? 0.01,
      value: _decodeValue(json['value']),
      dataType: OscDataTypeExt.fromCode(json['dataType'] as String? ?? 'f'),
      args: _readList(json['args'], OscArgumentJson.fromJson),
      isAdmOsc: json['isAdmOsc'] as bool? ?? false,
      admUsesObjectChannel: json['admUsesObjectChannel'] as bool? ?? false,
      admObjectSuffix: json['admObjectSuffix'] as String?,
      admIsQuery: json['admIsQuery'] as bool? ?? false,
      toggleOnValue: _decodeValue(json['toggleOnValue']),
      toggleOffValue: _decodeValue(json['toggleOffValue']),
    );
  }

  static Map<String, dynamic> toJson(OscControl control) => {
        'id': control.id,
        'type': control.type.name,
        'label': control.label,
        'address': control.address,
        'min': control.min,
        'max': control.max,
        'step': control.step,
        'value': _encodeValue(control.value),
        'dataType': control.dataType.code,
        'args': control.args.map(OscArgumentJson.toJson).toList(),
        'isAdmOsc': control.isAdmOsc,
        'admUsesObjectChannel': control.admUsesObjectChannel,
        'admObjectSuffix': control.admObjectSuffix,
        'admIsQuery': control.admIsQuery,
        if (control.toggleOnValue != null)
          'toggleOnValue': _encodeValue(control.toggleOnValue),
        if (control.toggleOffValue != null)
          'toggleOffValue': _encodeValue(control.toggleOffValue),
      };

  static ControlType _controlTypeFrom(String? name) {
    if (name == null) return ControlType.slider;
    for (final type in ControlType.values) {
      if (type.name == name) return type;
    }
    return ControlType.slider;
  }
}

abstract final class OscArgumentJson {
  static OscArgument fromJson(Map<String, dynamic> json) {
    return OscArgument(
      type: OscDataTypeExt.fromCode(json['type'] as String? ?? 'f'),
      value: _decodeValue(json['value']),
    );
  }

  static Map<String, dynamic> toJson(OscArgument arg) => {
        'type': arg.type.code,
        'value': _encodeValue(arg.value),
      };
}

dynamic _encodeValue(dynamic value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), _encodeValue(item)),
    );
  }
  return value.toString();
}

dynamic _decodeValue(dynamic value) {
  if (value == null || value is bool || value is String) return value;
  if (value is int) return value;
  if (value is double) return value;
  if (value is num) {
    final asDouble = value.toDouble();
    return asDouble == value.roundToDouble() ? value.round() : asDouble;
  }
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), _decodeValue(item)),
    );
  }
  return value;
}
