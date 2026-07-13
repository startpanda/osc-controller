import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/app_localizations.dart';
import '../models/app_config.dart';
import '../models/osc_models.dart';
import '../services/app_config_scope.dart';
import '../services/osc_service.dart';
import '../services/osc_service_scope.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';
import 'control_card.dart';
import 'osc_dialogs.dart';

enum ReceiverViewMode { graph, log }

class OscReceiver extends StatefulWidget {
  const OscReceiver({super.key});

  @override
  State<OscReceiver> createState() => OscReceiverState();
}

class OscReceiverState extends State<OscReceiver>
    with TickerProviderStateMixin {
  List<ListenerPort> _ports = [];

  final Set<String> _expandedPorts = {};
  ReceiverViewMode _viewMode = ReceiverViewMode.graph;
  List<OscRawLog> _rawLogs = [];

  final _logScrollController = ScrollController();
  final _streamScrollController = ScrollController();
  OscService? _oscService;
  StreamSubscription<ReceivedOscMessage>? _messageSubscription;
  Ticker? _timelineTicker;
  int _timelineNowMs = 0;

  bool _hydrated = false;
  bool _portsRestored = false;

  void _persistReceiver() {
    if (!mounted || !_hydrated) return;
    AppConfigScope.of(context).updateReceiver(
      ReceiverConfig(
        ports: _ports,
        viewMode: _viewMode == ReceiverViewMode.log ? 'log' : 'graph',
        expandedPorts: _expandedPorts.toList(),
      ),
    );
  }

  void persistConfig() => _persistReceiver();

  Future<void> applyConfig(ReceiverConfig receiver) async {
    final service = _oscService;
    if (service != null) {
      await service.stopAllListeners();
    }

    setState(() {
      _ports = List.of(receiver.ports);
      _viewMode = receiver.viewMode == 'log'
          ? ReceiverViewMode.log
          : ReceiverViewMode.graph;
      _expandedPorts
        ..clear()
        ..addAll(receiver.expandedPorts);
      _rawLogs = [];
    });

    _portsRestored = false;
    _syncTimelineTicker();
    _persistReceiver();

    if (_oscService != null) {
      _portsRestored = true;
      await _restoreActivePorts();
    }
  }

  Future<void> _restoreActivePorts() async {
    final service = _oscService;
    if (service == null) return;
    for (final port in _ports.where((entry) => entry.active)) {
      try {
        await service.startListening(port.port);
      } on OscServiceException {
        if (!mounted) return;
        setState(() {
          final index = _ports.indexWhere((entry) => entry.id == port.id);
          if (index >= 0) {
            _ports[index] = _ports[index].copyWith(active: false);
          }
        });
      }
    }
    _persistReceiver();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = OscServiceScope.of(context);
    if (_oscService != service) {
      _messageSubscription?.cancel();
      _oscService?.removeListener(_onServiceChanged);
      _oscService = service;
      _oscService!.addListener(_onServiceChanged);
      _messageSubscription = _oscService!.messages.listen(_onMessageReceived);
    }

    if (!_hydrated) {
      _hydrated = true;
      final receiver = AppConfigScope.of(context).config.receiver;
      setState(() {
        _ports = List.of(receiver.ports);
        _viewMode = receiver.viewMode == 'log'
            ? ReceiverViewMode.log
            : ReceiverViewMode.graph;
        _expandedPorts
          ..clear()
          ..addAll(receiver.expandedPorts);
      });
    }

    if (_hydrated && !_portsRestored && _oscService != null) {
      _portsRestored = true;
      unawaited(_restoreActivePorts());
    }

    _syncTimelineTicker();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _syncTimelineTicker() {
    if (_viewMode != ReceiverViewMode.graph) {
      _timelineTicker?.stop();
      _timelineTicker?.dispose();
      _timelineTicker = null;
      return;
    }

    if (_timelineTicker != null) return;

    _timelineNowMs = DateTime.now().millisecondsSinceEpoch;
    _timelineTicker = createTicker((_) {
      if (!mounted) return;
      setState(() {
        _timelineNowMs = DateTime.now().millisecondsSinceEpoch;
      });
    })..start();
  }

  void _onMessageReceived(ReceivedOscMessage message) {
    setState(() {
      _rawLogs = [
        ..._rawLogs,
        OscRawLog(
          id: message.timestamp.millisecondsSinceEpoch.toString(),
          timestamp: message.timestamp,
          port: message.listenPort,
          sourceAddress: message.sourceAddress,
          sourcePort: message.sourcePort,
          address: message.address,
          args: message.arguments,
        ),
      ];
      if (_rawLogs.length > 500) {
        _rawLogs = _rawLogs.sublist(_rawLogs.length - 500);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.jumpTo(
          _logScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  Map<String, OscStreamData> get _streams => _oscService?.streams ?? const {};

  @override
  void dispose() {
    _persistReceiver();
    _messageSubscription?.cancel();
    _oscService?.removeListener(_onServiceChanged);
    _timelineTicker?.dispose();
    _logScrollController.dispose();
    _streamScrollController.dispose();
    super.dispose();
  }

  Map<String, List<MapEntry<String, OscStreamData>>> _streamsByPort() {
    final grouped = <String, List<MapEntry<String, OscStreamData>>>{};
    for (final entry in _streams.entries) {
      grouped.putIfAbsent(entry.value.port, () => []).add(entry);
    }
    return grouped;
  }

  Future<void> _openPortDialog({ListenerPort? port}) async {
    final result = await showPortDialog(context, port: port);
    if (result == null || !mounted) return;

    final service = OscServiceScope.of(context);
    final l10n = AppLocalizations.of(context);

    if (port != null) {
      final oldPort = port.port;
      if (_ports.any((p) => p.id != port.id && p.port == result.port)) {
        _showAlert(l10n.portAlreadyExists);
        return;
      }

      try {
        if (port.active) {
          await service.stopListening(oldPort);
        }
        if (result.active) {
          await service.startListening(result.port);
        }
      } on OscServiceException catch (error) {
        if (port.active) {
          try {
            await service.startListening(oldPort);
          } catch (_) {}
        }
        _showAlert('${l10n.listenFailed}: ${error.message}');
        return;
      }

      setState(() {
        _ports = _ports
            .map((p) => p.id == port.id ? result : p)
            .toList();
        if (_expandedPorts.contains(oldPort)) {
          _expandedPorts.remove(oldPort);
          _expandedPorts.add(result.port);
        }
      });
      _persistReceiver();
    } else {
      if (_ports.any((p) => p.port == result.port)) {
        _showAlert(l10n.portAlreadyExists);
        return;
      }

      if (result.active) {
        try {
          await service.startListening(result.port);
        } on OscServiceException catch (error) {
          _showAlert('${l10n.listenFailed}: ${error.message}');
          return;
        }
      }

      setState(() {
        _ports = [..._ports, result];
        _expandedPorts.add(result.port);
      });
      _persistReceiver();
    }
  }

  Future<void> _deletePort(String id) async {
    final l10n = AppLocalizations.of(context);
    final portEntry = _ports.firstWhere((p) => p.id == id);
    final portNum = portEntry.port;

    try {
      await OscServiceScope.of(context).stopListening(portNum);
    } on OscServiceException catch (error) {
      _showAlert('${l10n.listenFailed}: ${error.message}');
      return;
    }

    setState(() {
      _ports.removeWhere((p) => p.id == id);
      _expandedPorts.remove(portNum);
    });
    _persistReceiver();
  }

  Future<void> _togglePort(String id) async {
    final l10n = AppLocalizations.of(context);
    final service = OscServiceScope.of(context);
    final index = _ports.indexWhere((p) => p.id == id);
    final port = _ports[index];
    final willActivate = !port.active;

    try {
      if (willActivate) {
        await service.startListening(port.port);
      } else {
        await service.stopListening(port.port);
      }
    } on OscServiceException catch (error) {
      _showAlert('${l10n.listenFailed}: ${error.message}');
      return;
    }

    setState(() {
      _ports[index] = port.copyWith(active: willActivate);
    });
    _persistReceiver();
  }

  void _deleteStream(String key) {
    OscServiceScope.of(context).removeStream(key);
  }

  void _clearAllStreams() {
    OscServiceScope.of(context).clearStreams();
  }

  void _clearCurrentView() {
    if (_viewMode == ReceiverViewMode.graph) {
      _clearAllStreams();
    } else {
      setState(() => _rawLogs.clear());
    }
  }

  void _togglePortExpansion(String port) {
    setState(() {
      if (_expandedPorts.contains(port)) {
        _expandedPorts.remove(port);
      } else {
        _expandedPorts.add(port);
      }
    });
    _persistReceiver();
  }

  void _showAlert(String message) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          DialogConfirmButton(
            label: l10n.ok,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final grouped = _streamsByPort();

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebarWidth =
            AppLayoutMetrics.sidebarWidthFor(constraints.maxWidth);
        return SizedBox.expand(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: sidebarWidth,
                child: ColoredBox(
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      SectionHeader(
                        title: l10n.listenPorts,
                        trailingMinWidth:
                            AppLayoutMetrics.primaryButtonCompactWidth(
                          context,
                          l10n.addPort,
                        ),
                        trailing: PrimaryButton(
                          label: l10n.addPort,
                          icon: Icons.add,
                          compact: true,
                          onPressed: () => _openPortDialog(),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _ports.length,
                          itemBuilder: (context, index) {
                            final port = _ports[index];
                            return _PortCard(
                              port: port,
                              portLabel: l10n.portLabel(port.port),
                              stopLabel: l10n.stopListening,
                              startLabel: l10n.startListening,
                              onEdit: () => _openPortDialog(port: port),
                              onDelete: () => _deletePort(port.id),
                              onToggle: () => _togglePort(port.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1, color: AppColors.gray200),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CardPanel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const minTitleWidth = AppLayoutMetrics.headerMinTitleWidth;
                              const clearGap = 8.0;
                              const streamGap = 12.0;

                              final toggleWidth = _ViewToggle.estimatedWidth(
                                context,
                                l10n.graph,
                                l10n.terminal,
                              );
                              final clearWidth = AppLayoutMetrics.outlineButtonWidth(
                                context,
                                l10n.clearAll,
                              );
                              final streamWidth =
                                  _viewMode == ReceiverViewMode.graph &&
                                          _streams.isNotEmpty
                                      ? AppLayoutMetrics.measureTextWidth(
                                          context,
                                          l10n.streamsCount(_streams.length),
                                          AppTypography.caption,
                                        ) +
                                          streamGap
                                      : 0.0;

                              var extraWidth = constraints.maxWidth -
                                  toggleWidth -
                                  minTitleWidth;
                              final showStream =
                                  streamWidth > 0 && extraWidth >= streamWidth;
                              if (showStream) {
                                extraWidth -= streamWidth;
                              }
                              final showClear =
                                  extraWidth >= clearWidth + clearGap;

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      l10n.liveDataStream,
                                      style: AppTypography.sectionTitle,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (showStream) ...[
                                        Text(
                                          l10n.streamsCount(_streams.length),
                                          style: AppTypography.caption,
                                        ),
                                        const SizedBox(width: streamGap),
                                      ],
                                      if (showClear) ...[
                                        OutlineButton(
                                          label: l10n.clearAll,
                                          icon: Icons.delete_outline,
                                          onPressed: _clearCurrentView,
                                        ),
                                        const SizedBox(width: clearGap),
                                      ],
                                      _ViewToggle(
                                        mode: _viewMode,
                                        graphLabel: l10n.graph,
                                        terminalLabel: l10n.terminal,
                                        onChanged: (mode) {
                                          setState(() => _viewMode = mode);
                                          _syncTimelineTicker();
                                          _persistReceiver();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                  const Divider(height: 1, color: AppColors.gray100),
                  Expanded(
                    child: _viewMode == ReceiverViewMode.log
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: _LogView(
                              logs: _rawLogs,
                              controller: _logScrollController,
                              waitingText: l10n.waitingForOsc,
                            ),
                          )
                        : grouped.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: _EmptyStreamView(
                                  waitingText: l10n.waitingForOsc,
                                  hintText: l10n.startPortToSeeStreams,
                                ),
                              )
                            : Scrollbar(
                                controller: _streamScrollController,
                                thumbVisibility: true,
                                child: ListView(
                                  controller: _streamScrollController,
                                  padding: const EdgeInsets.all(16),
                                  children: grouped.entries.map((entry) {
                                    final port = entry.key;
                                    final streams = entry.value;
                                    final expanded =
                                        _expandedPorts.contains(port);
                                    return Column(
                                      children: [
                                        _PortGroupHeader(
                                          portLabel: l10n.portLabel(port),
                                          countLabel:
                                              l10n.streamsCount(streams.length),
                                          expanded: expanded,
                                          onToggle: () =>
                                              _togglePortExpansion(port),
                                          onClear: () {
                                            for (final item in streams) {
                                              _deleteStream(item.key);
                                            }
                                          },
                                        ),
                                        if (expanded)
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              final count =
                                                  ControlGridLayout.crossAxisCount(
                                                constraints.maxWidth,
                                              );
                                              return GridView.builder(
                                                shrinkWrap: true,
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                gridDelegate:
                                                    ControlGridLayout.delegate(
                                                  count,
                                                ),
                                                itemCount: streams.length,
                                                itemBuilder: (context, index) {
                                                  final item = streams[index];
                                                  return ControlGridLayout.tile(
                                                    child: _StreamCard(
                                                      streamKey: item.key,
                                                      stream: item.value,
                                                      nowMs: _timelineNowMs,
                                                      onDelete: () =>
                                                          _deleteStream(
                                                        item.key,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        const SizedBox(height: 16),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
            ],
          ),
        );
      },
    );
  }
}

class _PortCard extends StatelessWidget {
  const _PortCard({
    required this.port,
    required this.portLabel,
    required this.stopLabel,
    required this.startLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final ListenerPort port;
  final String portLabel;
  final String stopLabel;
  final String startLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: port.active ? const Color(0xFFEFF6FF) : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: port.active ? AppColors.blue200 : AppColors.gray200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: port.active ? AppColors.blue500 : AppColors.gray300,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      portLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Consolas',
                        color: AppColors.gray800,
                      ),
                    ),
                    if (port.active) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.show_chart,
                          size: 12, color: AppColors.blue500),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 14, color: AppColors.blue500),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 14, color: AppColors.red500),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: PressableButton(
              onPressed: onToggle,
              backgroundColor:
                  port.active ? AppColors.red50 : AppColors.blue500,
              hoverBackgroundColor:
                  port.active ? AppColors.red200 : AppColors.blue600,
              pressedBackgroundColor:
                  port.active ? AppColors.red200 : const Color(0xFF1D4ED8),
              foregroundColor:
                  port.active ? AppColors.red600 : AppColors.white,
              borderColor: port.active ? AppColors.red200 : null,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                port.active ? stopLabel : startLabel,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.mode,
    required this.graphLabel,
    required this.terminalLabel,
    required this.onChanged,
  });

  final ReceiverViewMode mode;
  final String graphLabel;
  final String terminalLabel;
  final ValueChanged<ReceiverViewMode> onChanged;

  static const _textStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static double _buttonWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    // padding (20) + inactive border (2) + icon (14) + gap (6) + label
    return 42 + painter.width.ceilToDouble();
  }

  static double estimatedWidth(
    BuildContext context,
    String graphLabel,
    String terminalLabel,
  ) {
    final width = [
      _buttonWidth(context, graphLabel),
      _buttonWidth(context, terminalLabel),
    ].reduce((a, b) => a > b ? a : b);
    return width * 2 + 6;
  }

  double _buttonWidthForLabel(BuildContext context, String label) =>
      _buttonWidth(context, label);

  @override
  Widget build(BuildContext context) {
    final width = [
      _buttonWidthForLabel(context, graphLabel),
      _buttonWidthForLabel(context, terminalLabel),
    ].reduce((a, b) => a > b ? a : b);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleButton(
          label: graphLabel,
          icon: Icons.bar_chart,
          active: mode == ReceiverViewMode.graph,
          width: width,
          onTap: () => onChanged(ReceiverViewMode.graph),
        ),
        const SizedBox(width: 6),
        _ToggleButton(
          label: terminalLabel,
          icon: Icons.terminal,
          active: mode == ReceiverViewMode.log,
          width: width,
          onTap: () => onChanged(ReceiverViewMode.log),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatefulWidget {
  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.width,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final double? width;

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.active ? AppColors.white : AppColors.gray600;
    final bg = widget.active
        ? (_pressed
            ? AppColors.blue600
            : (_hovered ? AppColors.blue600 : AppColors.blue500))
        : (_pressed
            ? AppColors.gray100
            : (_hovered ? AppColors.gray50 : AppColors.surface));

    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
                border: widget.active
                    ? null
                    : Border.all(color: AppColors.gray200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(widget.icon, size: 14, color: fg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStreamView extends StatelessWidget {
  const _EmptyStreamView({
    required this.waitingText,
    required this.hintText,
  });

  final String waitingText;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.show_chart,
                      size: 48,
                      color: AppColors.gray400.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      waitingText,
                      style: AppTypography.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hintText,
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LogView extends StatelessWidget {
  const _LogView({
    required this.logs,
    required this.controller,
    required this.waitingText,
  });

  final List<OscRawLog> logs;
  final ScrollController controller;
  final String waitingText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray950,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.expand(
        child: logs.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Text('\$', style: TextStyle(color: Color(0xFF4ADE80))),
                    const SizedBox(width: 8),
                    Text(
                      waitingText,
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              )
            : ScrollbarTheme(
                data: ScrollbarThemeData(
                  thumbVisibility: WidgetStateProperty.all(true),
                  trackVisibility: WidgetStateProperty.all(true),
                  thickness: WidgetStateProperty.all(8),
                  radius: const Radius.circular(4),
                  crossAxisMargin: 2,
                  thumbColor: WidgetStateProperty.all(
                    AppColors.gray400.withValues(alpha: 0.85),
                  ),
                  trackColor: WidgetStateProperty.all(AppColors.gray800),
                ),
                child: Scrollbar(
                  controller: controller,
                  thumbVisibility: true,
                  interactive: true,
                  child: SelectionArea(
                    child: ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: formatTime(log.timestamp, withMs: true),
                                  style: AppTypography.caption,
                                ),
                                TextSpan(
                                  text: log.sourcePort > 0
                                      ? ' ${log.sourceAddress}:${log.sourcePort}'
                                      : ' ${log.sourceAddress}',
                                  style: const TextStyle(
                                    color: AppColors.purple600,
                                  ),
                                ),
                                TextSpan(
                                  text: ' :${log.port}',
                                  style: const TextStyle(color: AppColors.blue400),
                                ),
                                TextSpan(
                                  text: ' ${log.address}',
                                  style: const TextStyle(color: Color(0xFF4ADE80)),
                                ),
                                TextSpan(
                                  text: ' ${log.args.join(' ')}',
                                  style: const TextStyle(color: Color(0xFFFDBA74)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _PortGroupHeader extends StatelessWidget {
  const _PortGroupHeader({
    required this.portLabel,
    required this.countLabel,
    required this.expanded,
    required this.onToggle,
    required this.onClear,
  });

  final String portLabel;
  final String countLabel;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const chevronWidth = 16.0;
    const clearButtonWidth = 28.0;
    const leadingWidth = chevronWidth + 8 + 8 + 8;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray200),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final countWidth = AppLayoutMetrics.measureTextWidth(
              context,
              countLabel,
              AppTypography.caption,
            );
            final showCount = constraints.maxWidth >=
                leadingWidth + clearButtonWidth + 40 + 8 + countWidth;

            return Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: chevronWidth,
                  color: AppColors.gray500,
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.blue500,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          portLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Consolas',
                            color: AppColors.gray700,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (showCount) ...[
                        const SizedBox(width: 8),
                        Text(
                          countLabel,
                          style: AppTypography.caption,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: AppColors.gray400,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: clearButtonWidth,
                    minHeight: clearButtonWidth,
                  ),
                  onPressed: onClear,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StreamCard extends StatefulWidget {
  const _StreamCard({
    required this.streamKey,
    required this.stream,
    required this.nowMs,
    required this.onDelete,
  });

  final String streamKey;
  final OscStreamData stream;
  final int nowMs;
  final VoidCallback onDelete;

  @override
  State<_StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<_StreamCard> {
  static const _activityTimeoutMs = 200;

  bool _hovered = false;

  OscStreamData get stream => widget.stream;

  bool get _isActive =>
      widget.nowMs - stream.lastUpdate <= _activityTimeoutMs;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _hovered ? AppColors.blue400 : AppColors.gray300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.08 : 0.04),
              blurRadius: _hovered ? 6 : 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isActive
                              ? stream.color
                              : AppColors.gray400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          stream.address,
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: StreamLineChart(
                      data: stream.data,
                      color: stream.color,
                      min: stream.min,
                      max: stream.max,
                      nowMs: widget.nowMs,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stream.lastValue.toStringAsFixed(2),
                      style: AppTypography.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: stream.color,
                        fontFamily: 'Consolas',
                      ),
                    ),
                    Text(
                      '${stream.min.toStringAsFixed(1)} ~ ${stream.max.toStringAsFixed(1)}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ],
            ),
            if (_hovered)
              Positioned(
                top: 0,
                right: 0,
                child: InkWell(
                  onTap: widget.onDelete,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.delete_outline,
                      size: 12,
                      color: AppColors.red500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
