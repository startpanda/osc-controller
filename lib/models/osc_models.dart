import 'dart:ui';

int _oscEntityIdSeq = 0;

/// Generates a unique id for persisted OSC entities (targets, controls, ports).
String newOscEntityId() {
  _oscEntityIdSeq += 1;
  return '${DateTime.now().microsecondsSinceEpoch}_$_oscEntityIdSeq';
}

enum OscDataType {
  i,
  f,
  s,
  b,
  h,
  d,
  tTrue,
  fFalse,
  n,
  impulse,
  c,
  r,
}

extension OscDataTypeExt on OscDataType {
  String get code => switch (this) {
        OscDataType.i => 'i',
        OscDataType.f => 'f',
        OscDataType.s => 's',
        OscDataType.b => 'b',
        OscDataType.h => 'h',
        OscDataType.d => 'd',
        OscDataType.tTrue => 'T',
        OscDataType.fFalse => 'F',
        OscDataType.n => 'N',
        OscDataType.impulse => 'I',
        OscDataType.c => 'c',
        OscDataType.r => 'r',
      };

  String get label => switch (this) {
        OscDataType.i => 'i - int32',
        OscDataType.f => 'f - float32',
        OscDataType.s => 's - string',
        OscDataType.tTrue => 'T - True',
        OscDataType.fFalse => 'F - False',
        OscDataType.d => 'd - double',
        OscDataType.h => 'h - int64',
        OscDataType.c => 'c - char',
        OscDataType.r => 'r - rgba',
        OscDataType.n => 'N - Nil',
        OscDataType.impulse => 'I - Impulse',
        OscDataType.b => 'b - blob',
      };

  static OscDataType fromCode(String code) => switch (code) {
        'i' => OscDataType.i,
        'f' => OscDataType.f,
        's' => OscDataType.s,
        'b' => OscDataType.b,
        'h' => OscDataType.h,
        'd' => OscDataType.d,
        'T' => OscDataType.tTrue,
        'F' => OscDataType.fFalse,
        'N' => OscDataType.n,
        'I' => OscDataType.impulse,
        'c' => OscDataType.c,
        'r' => OscDataType.r,
        _ => OscDataType.f,
      };
}

enum ControlType { slider, toggle, button, xyPad, input, color, admXyz, admYpr, admAed }

class OscArgument {
  const OscArgument({required this.type, required this.value});

  final OscDataType type;
  final dynamic value;

  OscArgument copyWith({OscDataType? type, dynamic value}) {
    return OscArgument(type: type ?? this.type, value: value ?? this.value);
  }
}

/// Ensures every target has a unique non-empty id (fixes legacy duplicate ids).
List<OscTarget> normalizeTargetIds(List<OscTarget> targets) {
  final seen = <String>{};
  final result = <OscTarget>[];

  for (final target in targets) {
    if (target.id.isEmpty || seen.contains(target.id)) {
      result.add(
        OscTarget(
          id: newOscEntityId(),
          ip: target.ip,
          port: target.port,
          enabled: target.enabled,
          label: target.label,
        ),
      );
    } else {
      seen.add(target.id);
      result.add(target);
    }
  }

  return result;
}

class OscTarget {
  OscTarget({
    required this.id,
    required this.ip,
    required this.port,
    required this.enabled,
    required this.label,
  });

  final String id;
  final String ip;
  final String port;
  final bool enabled;
  final String label;

  OscTarget copyWith({
    String? ip,
    String? port,
    bool? enabled,
    String? label,
  }) {
    return OscTarget(
      id: id,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
    );
  }
}

class OscLogEntry {
  OscLogEntry({
    required this.id,
    required this.timestamp,
    required this.targets,
    required this.address,
    required this.arguments,
    required this.typeTag,
    this.failedTargets = const [],
  });

  final String id;
  final DateTime timestamp;
  final List<String> targets;
  final List<String> failedTargets;
  final String address;
  final List<OscArgument> arguments;
  final String typeTag;
}

class OscControl {
  OscControl({
    required this.id,
    required this.type,
    required this.label,
    required this.address,
    required this.dataType,
    required this.args,
    this.min = 0,
    this.max = 1,
    this.step = 0.01,
    this.value,
    this.isAdmOsc = false,
    this.admUsesObjectChannel = false,
    this.admObjectSuffix,
    this.admIsQuery = false,
    this.toggleOnValue,
    this.toggleOffValue,
  });

  final String id;
  final ControlType type;
  final String label;
  final String address;
  final double min;
  final double max;
  final double step;
  final dynamic value;
  final OscDataType dataType;
  final List<OscArgument> args;
  final bool isAdmOsc;
  final bool admUsesObjectChannel;
  final String? admObjectSuffix;
  final bool admIsQuery;
  final dynamic toggleOnValue;
  final dynamic toggleOffValue;

  bool get usesToggleTypeTags =>
      type == ControlType.toggle &&
      toggleOnValue == null &&
      toggleOffValue == null &&
      (dataType == OscDataType.tTrue || dataType == OscDataType.fFalse);

  OscControl copyWith({
    ControlType? type,
    String? label,
    String? address,
    double? min,
    double? max,
    double? step,
    dynamic value,
    OscDataType? dataType,
    List<OscArgument>? args,
    bool? isAdmOsc,
    bool? admUsesObjectChannel,
    String? admObjectSuffix,
    bool? admIsQuery,
    dynamic toggleOnValue,
    dynamic toggleOffValue,
    bool clearToggleOnValue = false,
    bool clearToggleOffValue = false,
  }) {
    return OscControl(
      id: id,
      type: type ?? this.type,
      label: label ?? this.label,
      address: address ?? this.address,
      min: min ?? this.min,
      max: max ?? this.max,
      step: step ?? this.step,
      value: value ?? this.value,
      dataType: dataType ?? this.dataType,
      args: args ?? this.args,
      isAdmOsc: isAdmOsc ?? this.isAdmOsc,
      admUsesObjectChannel:
          admUsesObjectChannel ?? this.admUsesObjectChannel,
      admObjectSuffix: admObjectSuffix ?? this.admObjectSuffix,
      admIsQuery: admIsQuery ?? this.admIsQuery,
      toggleOnValue:
          clearToggleOnValue ? null : (toggleOnValue ?? this.toggleOnValue),
      toggleOffValue:
          clearToggleOffValue ? null : (toggleOffValue ?? this.toggleOffValue),
    );
  }
}

class ListenerPort {
  ListenerPort({
    required this.id,
    required this.port,
    required this.active,
  });

  final String id;
  final String port;
  final bool active;

  ListenerPort copyWith({String? port, bool? active}) {
    return ListenerPort(
      id: id,
      port: port ?? this.port,
      active: active ?? this.active,
    );
  }
}

class OscRawLog {
  OscRawLog({
    required this.id,
    required this.timestamp,
    required this.port,
    required this.sourceAddress,
    required this.sourcePort,
    required this.address,
    required this.args,
  });

  final String id;
  final DateTime timestamp;
  final String port;
  final String sourceAddress;
  final int sourcePort;
  final String address;
  final List<dynamic> args;
}

class StreamDataPoint {
  const StreamDataPoint({required this.timestamp, required this.value});

  final int timestamp;
  final double value;
}

class OscStreamData {
  OscStreamData({
    required this.address,
    required this.port,
    required this.data,
    required this.lastValue,
    required this.lastUpdate,
    required this.color,
    required this.min,
    required this.max,
  });

  final String address;
  final String port;
  final List<StreamDataPoint> data;
  final double lastValue;
  final int lastUpdate;
  final Color color;
  final double min;
  final double max;

  OscStreamData copyWith({
    List<StreamDataPoint>? data,
    double? lastValue,
    int? lastUpdate,
    double? min,
    double? max,
  }) {
    return OscStreamData(
      address: address,
      port: port,
      data: data ?? this.data,
      lastValue: lastValue ?? this.lastValue,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      color: color,
      min: min ?? this.min,
      max: max ?? this.max,
    );
  }
}
