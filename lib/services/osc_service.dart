import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/osc_models.dart';
import '../theme/app_theme.dart';
import 'osc_codec.dart';

class ReceivedOscMessage {
  ReceivedOscMessage({
    required this.listenPort,
    required this.address,
    required this.arguments,
    required this.timestamp,
    required this.sourceAddress,
    required this.sourcePort,
  });

  final String listenPort;
  final String address;
  final List<dynamic> arguments;
  final DateTime timestamp;
  final String sourceAddress;
  final int sourcePort;
}

class OscService extends ChangeNotifier {
  static const _streamRetentionMs = 90000;

  RawDatagramSocket? _sendSocket;
  final Map<String, _ListenBinding> _listeners = {};
  final StreamController<ReceivedOscMessage> _messageController =
      StreamController<ReceivedOscMessage>.broadcast();

  int _streamColorIndex = 0;
  final Map<String, OscStreamData> _streams = {};

  Stream<ReceivedOscMessage> get messages => _messageController.stream;

  Map<String, OscStreamData> get streams => Map.unmodifiable(_streams);

  bool get hasActiveListeners => _listeners.isNotEmpty;

  Future<List<String>> sendToTargets({
    required List<OscTarget> targets,
    required String address,
    required List<OscArgument> args,
  }) async {
    final enabledTargets = targets.where((target) => target.enabled).toList();

    String endpoint(OscTarget target) =>
        '${target.ip.trim()}:${target.port.trim()}';

    try {
      await _ensureSendSocket();
    } catch (_) {
      return enabledTargets.map(endpoint).toList();
    }

    final packet = OscCodec.encode(address, args);
    if (packet.isEmpty) {
      return enabledTargets.map(endpoint).toList();
    }

    final failures = <String>[];

    for (final target in enabledTargets) {
      final portNumber = int.tryParse(target.port.trim());
      if (portNumber == null || portNumber < 1 || portNumber > 65535) {
        failures.add(endpoint(target));
        continue;
      }

      final internetAddress = await _resolveSendAddress(target.ip);
      if (internetAddress == null) {
        failures.add(endpoint(target));
        continue;
      }

      final sent = _sendSocket!.send(packet, internetAddress, portNumber);
      if (sent != packet.length) {
        failures.add(endpoint(target));
      }
    }

    return failures;
  }

  /// Resolves a send target to IPv4 for the outbound UDP socket.
  Future<InternetAddress?> _resolveSendAddress(String ip) async {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
    if (lower == 'localhost' || lower == '127.0.0.1' || lower == '::1') {
      return InternetAddress.loopbackIPv4;
    }

    final parsed = InternetAddress.tryParse(trimmed);
    if (parsed != null) {
      if (parsed.type == InternetAddressType.IPv4) {
        return parsed;
      }
      if (parsed.isLoopback) {
        return InternetAddress.loopbackIPv4;
      }
      return null;
    }

    try {
      final results = await InternetAddress.lookup(
        trimmed,
        type: InternetAddressType.IPv4,
      );
      return results.isNotEmpty ? results.first : null;
    } on SocketException {
      return null;
    }
  }

  Future<void> startListening(String port) async {
    if (_listeners.containsKey(port)) return;

    final portNumber = int.tryParse(port);
    if (portNumber == null) {
      throw OscServiceException('Invalid port: $port');
    }

    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        portNumber,
      );
      final subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? datagram;
        while ((datagram = socket.receive()) != null) {
          _handleReceivedDatagram(
            listenPort: port,
            datagram: datagram!,
          );
        }
      });

      _listeners[port] = _ListenBinding(
        port: port,
        socket: socket,
        subscription: subscription,
      );
      notifyListeners();
    } on SocketException catch (error) {
      throw OscServiceException('Failed to bind port $port: ${error.message}');
    }
  }

  void _handleReceivedDatagram({
    required String listenPort,
    required Datagram datagram,
  }) {
    try {
      final decoded = OscCodec.decodeBytes(datagram.data);
      if (decoded == null) return;

      final args = OscCodec.displayArguments(decoded.arguments);
      final received = ReceivedOscMessage(
        listenPort: listenPort,
        address: decoded.address,
        arguments: args,
        timestamp: DateTime.now(),
        sourceAddress: datagram.address.address,
        sourcePort: datagram.port,
      );
      _updateStream(received);
      _messageController.add(received);
      notifyListeners();
    } catch (error, stack) {
      debugPrint('OSC receive failed: $error\n$stack');
    }
  }

  Future<void> stopListening(String port) async {
    final binding = _listeners.remove(port);
    binding?.dispose();
    _streams.removeWhere((key, _) => key.startsWith('$port:'));
    notifyListeners();
  }

  Future<void> stopAllListeners() async {
    for (final binding in _listeners.values.toList()) {
      binding.dispose();
    }
    _listeners.clear();
    _streams.clear();
    _streamColorIndex = 0;
    notifyListeners();
  }

  void removeStream(String streamKey) {
    _streams.remove(streamKey);
    notifyListeners();
  }

  void clearStreams() {
    _streams.clear();
    _streamColorIndex = 0;
    notifyListeners();
  }

  void clearStreamsForPort(String port) {
    _streams.removeWhere((key, _) => key.startsWith('$port:'));
    notifyListeners();
  }

  @override
  void dispose() {
    stopAllListeners();
    _sendSocket?.close();
    _sendSocket = null;
    _messageController.close();
    super.dispose();
  }

  Future<void> _ensureSendSocket() async {
    _sendSocket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  }

  void _updateStream(ReceivedOscMessage message) {
    final numeric = OscCodec.firstNumericValue(
      message.arguments.cast<Object>(),
    );
    if (numeric == null) return;

    final key = '${message.listenPort}:${message.address}';
    final now = message.timestamp.millisecondsSinceEpoch;
    final current = _streams[key];

    if (current != null) {
      final data = [
        ...current.data,
        StreamDataPoint(timestamp: now, value: numeric),
      ];
      final cutoff = now - _streamRetentionMs;
      data.removeWhere((point) => point.timestamp < cutoff);
      _streams[key] = current.copyWith(
        data: data,
        lastValue: numeric,
        lastUpdate: now,
        min: numeric < current.min ? numeric : current.min,
        max: numeric > current.max ? numeric : current.max,
      );
      return;
    }

    _streams[key] = OscStreamData(
      address: message.address,
      port: message.listenPort,
      data: [StreamDataPoint(timestamp: now, value: numeric)],
      lastValue: numeric,
      lastUpdate: now,
      color: AppColors.streamColors[
          _streamColorIndex % AppColors.streamColors.length],
      min: numeric,
      max: numeric,
    );
    _streamColorIndex++;
  }
}

class _ListenBinding {
  _ListenBinding({
    required this.port,
    required this.socket,
    required this.subscription,
  });

  final String port;
  final RawDatagramSocket socket;
  final StreamSubscription<RawSocketEvent> subscription;

  void dispose() {
    subscription.cancel();
    socket.close();
  }
}

class OscServiceException implements Exception {
  OscServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
