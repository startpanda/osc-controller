import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:osc/osc.dart';
import 'package:osc/src/convert.dart' show DataCodec, OSCMessageBuilder;

import '../models/osc_models.dart';

class OscDecodedMessage {
  const OscDecodedMessage({
    required this.address,
    required this.arguments,
  });

  final String address;
  final List<Object?> arguments;
}

class _OscNil {
  const _OscNil();

  @override
  String toString() => 'N';
}

class _OscImpulse {
  const _OscImpulse();

  @override
  String toString() => 'I';
}

const _oscNil = _OscNil();
const _oscImpulse = _OscImpulse();

/// Builds OSC packet bytes and converts between app models and [OSCMessage].
abstract final class OscCodec {
  static List<int> encode(String address, List<OscArgument> arguments) {
    try {
      final builder = OSCMessageBuilder();
      builder.addAddress(address);

      if (arguments.isEmpty) {
        builder.addString(',');
        return builder.toBytes();
      }

      final typeTag = StringBuffer(',');
      final valueArgs = <Object>[];

      for (final arg in arguments) {
        _encodeArgument(arg, typeTag, valueArgs);
      }

      builder.addString(typeTag.toString());
      for (final value in valueArgs) {
        builder.addBytes(DataCodec.forValue(value).encode(value));
      }

      return builder.toBytes();
    } catch (error, stack) {
      debugPrint('OSC encode failed: $error\n$stack');
      return const [];
    }
  }

  static void _encodeArgument(
    OscArgument arg,
    StringBuffer typeTag,
    List<Object> valueArgs,
  ) {
    appendTypeTag(arg, typeTag);
    switch (arg.type) {
      case OscDataType.tTrue:
      case OscDataType.fFalse:
      case OscDataType.n:
      case OscDataType.impulse:
        break;
      case OscDataType.i:
      case OscDataType.h:
        valueArgs.add(_asInt(arg.value));
      case OscDataType.f:
      case OscDataType.d:
        valueArgs.add(_asDouble(arg.value));
      case OscDataType.s:
      case OscDataType.c:
        valueArgs.add(arg.value?.toString() ?? '');
      case OscDataType.b:
        valueArgs.add(_asBlob(arg.value));
      case OscDataType.r:
        final rgba = _asRgba(arg.value);
        valueArgs
          ..add(rgba[0])
          ..add(rgba[1])
          ..add(rgba[2])
          ..add(rgba[3]);
    }
  }

  static void appendTypeTag(OscArgument arg, StringBuffer typeTag) {
    switch (arg.type) {
      case OscDataType.tTrue:
      case OscDataType.fFalse:
      case OscDataType.n:
      case OscDataType.impulse:
        typeTag.write(arg.type.code);
      case OscDataType.i:
      case OscDataType.h:
        typeTag.write('i');
      case OscDataType.f:
      case OscDataType.d:
        typeTag.write('f');
      case OscDataType.s:
      case OscDataType.c:
        typeTag.write('s');
      case OscDataType.b:
        typeTag.write('b');
      case OscDataType.r:
        typeTag.write('iiii');
    }
  }

  static String buildTypeTag(List<OscArgument> arguments) {
    if (arguments.isEmpty) return ',';
    final typeTag = StringBuffer(',');
    for (final arg in arguments) {
      appendTypeTag(arg, typeTag);
    }
    return typeTag.toString();
  }

  /// Parses command-line tokens after the OSC address.
  ///
  /// Supports:
  /// - Standard OSC type tags: `/test ,f 20.3` or `/test , ff 1.0 2.0`
  /// - Compact type hints: `/test f 20.3`
  /// - Auto detection: `/test 1 2.5 hello`
  static List<OscArgument> parseCommandArguments(List<String> tokens) {
    final args = <OscArgument>[];
    var index = 0;

    while (index < tokens.length) {
      final token = tokens[index];

      if (token.startsWith(',')) {
        final typeBody = token.length > 1
            ? token.substring(1)
            : (index + 1 < tokens.length ? tokens[index + 1] : '');
        final typeTagTokens = token.length > 1
            ? 1
            : (index + 1 < tokens.length ? 2 : 1);
        index += typeTagTokens;

        final valueCount = _valueCountForTypeTag(typeBody);
        final end = (index + valueCount).clamp(0, tokens.length);
        final valueTokens = tokens.sublist(index, end);
        args.addAll(_parseFromTypeTag(typeBody, valueTokens));
        index += valueTokens.length;
        continue;
      }

      final explicitType = _tryParseTypeToken(token);
      if (explicitType != null) {
        if (_isValuelessType(explicitType)) {
          args.add(OscArgument(type: explicitType, value: null));
          index += 1;
          continue;
        }

        index += 1;
        if (index >= tokens.length) break;
        args.add(_parseTypedToken(explicitType, tokens[index]));
        index += 1;
        continue;
      }

      args.add(_parseAutoDetectedToken(token));
      index += 1;
    }

    return args;
  }

  static int _valueCountForTypeTag(String typeBody) {
    var count = 0;
    for (var i = 0; i < typeBody.length; i++) {
      final type = _tryParseTypeToken(typeBody[i]);
      if (type != null && !_isValuelessType(type)) {
        count += 1;
      }
    }
    return count;
  }

  static List<OscArgument> _parseFromTypeTag(
    String typeBody,
    List<String> valueTokens,
  ) {
    final args = <OscArgument>[];
    var valueIndex = 0;

    for (var i = 0; i < typeBody.length; i++) {
      final type = _tryParseTypeToken(typeBody[i]);
      if (type == null) continue;

      if (_isValuelessType(type)) {
        args.add(OscArgument(type: type, value: null));
        continue;
      }

      if (valueIndex >= valueTokens.length) break;
      args.add(_parseTypedToken(type, valueTokens[valueIndex]));
      valueIndex += 1;
    }

    return args;
  }

  static OscDataType? _tryParseTypeToken(String token) {
    return switch (token) {
      'i' => OscDataType.i,
      'f' => OscDataType.f,
      's' => OscDataType.s,
      'b' => OscDataType.b,
      'h' => OscDataType.h,
      'd' => OscDataType.d,
      'c' => OscDataType.c,
      'r' => OscDataType.r,
      'T' => OscDataType.tTrue,
      'F' => OscDataType.fFalse,
      'N' => OscDataType.n,
      'I' => OscDataType.impulse,
      _ => null,
    };
  }

  static bool _isValuelessType(OscDataType type) {
    return switch (type) {
      OscDataType.tTrue ||
      OscDataType.fFalse ||
      OscDataType.n ||
      OscDataType.impulse =>
        true,
      _ => false,
    };
  }

  static OscArgument _parseTypedToken(OscDataType type, String value) {
    switch (type) {
      case OscDataType.tTrue:
      case OscDataType.fFalse:
      case OscDataType.n:
      case OscDataType.impulse:
        return OscArgument(type: type, value: null);
      case OscDataType.i:
      case OscDataType.h:
        return OscArgument(type: type, value: _asInt(value));
      case OscDataType.f:
      case OscDataType.d:
        return OscArgument(type: type, value: _asDouble(value));
      case OscDataType.s:
      case OscDataType.c:
        return OscArgument(type: type, value: value);
      case OscDataType.b:
        return OscArgument(type: type, value: _asBlob(value));
      case OscDataType.r:
        if (value.startsWith('#')) {
          return OscArgument(type: type, value: value);
        }
        final parts = value.split(',');
        if (parts.length >= 3) {
          return OscArgument(
            type: type,
            value: {
              'r': _asInt(parts[0]),
              'g': _asInt(parts[1]),
              'b': _asInt(parts[2]),
              'a': parts.length > 3 ? _asInt(parts[3]) : 255,
            },
          );
        }
        return OscArgument(type: type, value: value);
    }
  }

  static OscArgument _parseAutoDetectedToken(String token) {
    if (token == 'true') {
      return const OscArgument(type: OscDataType.tTrue, value: true);
    }
    if (token == 'false') {
      return const OscArgument(type: OscDataType.fFalse, value: false);
    }
    if (token == 'nil' || token == 'null') {
      return const OscArgument(type: OscDataType.n, value: null);
    }
    if (double.tryParse(token) != null) {
      if (token.contains('.')) {
        return OscArgument(type: OscDataType.f, value: double.parse(token));
      }
      return OscArgument(type: OscDataType.i, value: int.parse(token));
    }
    return OscArgument(type: OscDataType.s, value: token);
  }

  static String formatArgument(OscArgument arg) {
    switch (arg.type) {
      case OscDataType.tTrue:
        return 'T';
      case OscDataType.fFalse:
        return 'F';
      case OscDataType.n:
        return 'N';
      case OscDataType.impulse:
        return 'I';
      case OscDataType.i:
      case OscDataType.h:
        return 'i(${_asInt(arg.value)})';
      case OscDataType.f:
      case OscDataType.d:
        return 'f(${_formatNumber(_asDouble(arg.value))})';
      case OscDataType.s:
        return 's("${arg.value}")';
      case OscDataType.c:
        return 'c("${arg.value}")';
      case OscDataType.b:
        final blob = _asBlob(arg.value);
        return 'b[${blob.length}]';
      case OscDataType.r:
        final rgba = _asRgba(arg.value);
        return 'r(${rgba[0]}, ${rgba[1]}, ${rgba[2]}, ${rgba[3]})';
    }
  }

  static String formatMessage(String address, List<OscArgument> arguments) {
    final buffer = StringBuffer(address);
    buffer.write(' ${buildTypeTag(arguments)}');
    for (final arg in arguments) {
      buffer.write(' ${formatArgument(arg)}');
    }
    return buffer.toString();
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }

  static OSCMessage decodeMessage(List<int> bytes) {
    final decoded = decodeBytes(bytes);
    if (decoded == null) {
      throw FormatException('Invalid OSC packet');
    }
    return OSCMessage(
      decoded.address,
      arguments: decoded.arguments.whereType<Object>().toList(),
    );
  }

  /// Parses incoming OSC packets, including valueless type tags (T/F/I/N).
  static OscDecodedMessage? decodeBytes(List<int> input) {
    if (input.isEmpty) return null;

    try {
      final bytes = input is Uint8List ? input : Uint8List.fromList(input);
      var index = 0;

      final addressEnd = bytes.indexOf(0, index);
      if (addressEnd < index) return null;
      final address = utf8.decode(bytes.sublist(index, addressEnd));
      index = _alignIndex(addressEnd + 1);

      if (index >= bytes.length) {
        return OscDecodedMessage(address: address, arguments: const []);
      }

      if (bytes[index] != 0x2c) {
        return OscDecodedMessage(address: address, arguments: const []);
      }
      index++;

      final typeTagEnd = bytes.indexOf(0, index);
      if (typeTagEnd < index) {
        return OscDecodedMessage(address: address, arguments: const []);
      }
      final typeTags = utf8.decode(bytes.sublist(index, typeTagEnd));
      index = _alignIndex(typeTagEnd + 1);

      final args = <Object?>[];
      for (var i = 0; i < typeTags.length; i++) {
        final tag = typeTags[i];
        switch (tag) {
          case 'T':
            args.add(true);
          case 'F':
            args.add(false);
          case 'I':
            args.add(_oscImpulse);
          case 'N':
            args.add(_oscNil);
          case 'i':
            if (index + 4 > bytes.length) return null;
            args.add(_readInt32(bytes, index));
            index += 4;
          case 'f':
            if (index + 4 > bytes.length) return null;
            args.add(_readFloat32(bytes, index));
            index += 4;
          case 's':
          case 'S':
            final strEnd = bytes.indexOf(0, index);
            if (strEnd < index) return null;
            args.add(utf8.decode(bytes.sublist(index, strEnd)));
            index = _alignIndex(strEnd + 1);
          case 'b':
            if (index + 4 > bytes.length) return null;
            final size = _readInt32(bytes, index);
            index += 4;
            if (index + size > bytes.length) return null;
            args.add(Uint8List.sublistView(bytes, index, index + size));
            index = _alignIndex(index + size);
          case 'h':
            if (index + 8 > bytes.length) return null;
            args.add(_readInt64(bytes, index));
            index += 8;
          case 'd':
            if (index + 8 > bytes.length) return null;
            args.add(_readFloat64(bytes, index));
            index += 8;
          case 'c':
            if (index + 4 > bytes.length) return null;
            final charEnd = bytes.indexOf(0, index);
            if (charEnd > index) {
              args.add(utf8.decode(bytes.sublist(index, charEnd)));
            } else {
              args.add(String.fromCharCode(bytes[index]));
            }
            index += 4;
          case 'r':
            if (index + 4 > bytes.length) return null;
            args.add(<String, int>{
              'r': bytes[index],
              'g': bytes[index + 1],
              'b': bytes[index + 2],
              'a': bytes[index + 3],
            });
            index += 4;
          default:
            debugPrint('Unsupported OSC type tag: $tag');
            return null;
        }
      }

      return OscDecodedMessage(address: address, arguments: args);
    } catch (error, stack) {
      debugPrint('OSC decode failed: $error\n$stack');
      return null;
    }
  }

  static int _alignIndex(int index) => index + ((4 - index % 4) % 4);

  static int _readInt32(Uint8List bytes, int offset) {
    return ByteData.sublistView(bytes, offset, offset + 4).getInt32(0, Endian.big);
  }

  static int _readInt64(Uint8List bytes, int offset) {
    return ByteData.sublistView(bytes, offset, offset + 8).getInt64(0, Endian.big);
  }

  static double _readFloat32(Uint8List bytes, int offset) {
    return ByteData.sublistView(bytes, offset, offset + 4)
        .getFloat32(0, Endian.big);
  }

  static double _readFloat64(Uint8List bytes, int offset) {
    return ByteData.sublistView(bytes, offset, offset + 8)
        .getFloat64(0, Endian.big);
  }

  static List<dynamic> displayArguments(List<Object?> arguments) {
    return arguments.map(_displayValue).toList();
  }

  static dynamic _displayValue(Object? value) {
    if (value == null) return 'null';
    if (value is Uint8List) {
      return 'blob(${value.length})';
    }
    if (value is Map) {
      return value.entries.map((e) => '${e.key}:${e.value}').join(',');
    }
    return value;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Uint8List _asBlob(dynamic value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return Uint8List.fromList(value?.toString().codeUnits ?? const []);
  }

  static List<int> _asRgba(dynamic value) {
    if (value is Map) {
      return [
        _asInt(value['r']),
        _asInt(value['g']),
        _asInt(value['b']),
        _asInt(value['a'] ?? 255),
      ];
    }
    if (value is String && value.startsWith('#') && value.length >= 7) {
      final hex = value.substring(1);
      return [
        int.parse(hex.substring(0, 2), radix: 16),
        int.parse(hex.substring(2, 4), radix: 16),
        int.parse(hex.substring(4, 6), radix: 16),
        255,
      ];
    }
    return [0, 0, 0, 255];
  }

  static double? firstNumericValue(List<Object> arguments) {
    for (final arg in arguments) {
      if (arg is int) return arg.toDouble();
      if (arg is double) return arg;
    }
    return null;
  }
}
