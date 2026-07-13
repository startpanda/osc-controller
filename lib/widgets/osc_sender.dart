import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/adm_osc_presets.dart';
import '../models/app_config.dart';
import '../models/osc_models.dart';
import '../services/app_config_scope.dart';
import '../services/osc_codec.dart';
import '../services/osc_service_scope.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';
import 'control_card.dart';
import 'osc_dialogs.dart';

class OscSender extends StatefulWidget {
  const OscSender({super.key});

  @override
  State<OscSender> createState() => OscSenderState();
}

class OscSenderState extends State<OscSender> {
  static const _commandControlHeight = 32.0;
  static const _commandBorderRadius = 6.0;
  static const _commandInputPadding = EdgeInsets.symmetric(horizontal: 12);
  static const _commandTextStyle = TextStyle(
    fontFamily: 'Consolas',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  final _commandController = TextEditingController();
  final _commandFocusNode = FocusNode();
  final _logScrollController = ScrollController();
  final _controlsScrollController = ScrollController();

  List<OscTarget> _targets = [];

  List<OscControl> _controls = [];

  List<OscLogEntry> _logs = [];

  int _admObjectChannel = 1;

  bool _hydrated = false;
  bool _commandFocused = false;

  @override
  void initState() {
    super.initState();
    _commandFocusNode.addListener(_handleCommandFocusChange);
  }

  void _handleCommandFocusChange() {
    final focused = _commandFocusNode.hasFocus;
    if (_commandFocused != focused) {
      setState(() => _commandFocused = focused);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    _hydrated = true;
    final sender = AppConfigScope.of(context).config.sender;
    if (sender.targets.isNotEmpty ||
        sender.controls.isNotEmpty ||
        sender.admObjectChannel != 1) {
      final loaded = List.of(sender.targets);
      final normalized = normalizeTargetIds(loaded);
      setState(() {
        _targets = normalized;
        _controls = List.of(sender.controls);
        _admObjectChannel = sender.admObjectChannel;
      });
      if (_hasDuplicateTargetIds(loaded)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _persistSender());
      }
    }
  }

  void _persistSender() {
    if (!mounted || !_hydrated) return;
    AppConfigScope.of(context).updateSender(
      SenderConfig(
        targets: _targets,
        controls: _controls,
        admObjectChannel: _admObjectChannel,
      ),
    );
  }

  void persistConfig() => _persistSender();

  void applyConfig(SenderConfig sender) {
    setState(() {
      _targets = normalizeTargetIds(List.of(sender.targets));
      _controls = List.of(sender.controls);
      _admObjectChannel = sender.admObjectChannel;
    });
    _persistSender();
  }

  @override
  void dispose() {
    _persistSender();
    _commandFocusNode.removeListener(_handleCommandFocusChange);
    _commandFocusNode.dispose();
    _commandController.dispose();
    _logScrollController.dispose();
    _controlsScrollController.dispose();
    super.dispose();
  }

  List<OscTarget> get _enabledTargets =>
      _targets.where((target) => target.enabled).toList();

  static bool _hasDuplicateTargetIds(List<OscTarget> targets) {
    final seen = <String>{};
    for (final target in targets) {
      if (target.id.isEmpty || !seen.add(target.id)) return true;
    }
    return false;
  }

  bool get _hasAdmObjectControls =>
      _controls.any((c) => c.isAdmOsc && c.admUsesObjectChannel);

  void addAdmOscControls() {
    final updated = AdmOscPresets.completeMissing(_controls, _admObjectChannel);
    if (updated.length == _controls.length) return;
    setState(() => _controls = updated);
    _persistSender();
  }

  void _setAdmObjectChannel(int channel) {
    if (channel < 1) return;
    setState(() {
      _admObjectChannel = channel;
      _controls = _controls
          .map((c) => AdmOscPresets.withObjectChannel(c, channel))
          .toList();
    });
    _persistSender();
  }

  void _scrollLogsToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_logScrollController.hasClients) return;
        _logScrollController.jumpTo(
          _logScrollController.position.maxScrollExtent,
        );
      });
    });
  }

  void _logMessage(
    String address,
    List<OscArgument> args, {
    List<String> failedTargets = const [],
  }) {
    setState(() {
      _logs = [
        ..._logs,
        OscLogEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now(),
          targets: _enabledTargets
              .map((t) => '${t.ip.trim()}:${t.port.trim()}')
              .toList(),
          failedTargets: failedTargets,
          address: address,
          arguments: args,
          typeTag: OscCodec.buildTypeTag(args),
        ),
      ];
      if (_logs.length > 500) {
        _logs = _logs.sublist(_logs.length - 500);
      }
    });
    _scrollLogsToBottom();
  }

  Future<void> _sendCommand() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final text = _commandController.text.trim();
    final parts = text.split(RegExp(r'\s+'));
    if (parts.isEmpty || !parts.first.startsWith('/')) {
      _showAlert(l10n.oscAddressMustStartWithSlash);
      return;
    }
    if (_enabledTargets.isEmpty) return;

    final address = parts.first;
    try {
      final args = OscCodec.parseCommandArguments(parts.skip(1).toList());
      final failedTargets = await OscServiceScope.of(context).sendToTargets(
        targets: _enabledTargets,
        address: address,
        args: args,
      );
      if (!mounted) return;
      _logMessage(address, args, failedTargets: failedTargets);
    } catch (error, stack) {
      debugPrint('OSC command send failed: $error\n$stack');
    }
  }

  Future<void> _sendControl(OscControl control) async {
    if (!mounted || _enabledTargets.isEmpty) return;

    try {
      final current = _controls.firstWhere(
        (c) => c.id == control.id,
        orElse: () => control,
      );
      final args = current.admIsQuery ? <OscArgument>[] : current.args;

      final failedTargets = await OscServiceScope.of(context).sendToTargets(
        targets: _enabledTargets,
        address: current.address,
        args: args,
      );
      if (!mounted) return;
      _logMessage(current.address, args, failedTargets: failedTargets);
    } catch (error, stack) {
      debugPrint('OSC control send failed: $error\n$stack');
    }
  }

  void _updateControl(String id, OscControl updated) {
    setState(() {
      _controls = _controls.map((c) => c.id == id ? updated : c).toList();
    });
    _persistSender();
  }

  void _deleteControl(String id) {
    setState(() => _controls.removeWhere((c) => c.id == id));
    _persistSender();
  }

  Future<void> _openTargetDialog({OscTarget? target, int? targetIndex}) async {
    final result = await showTargetDialog(context, target: target);
    if (result == null) return;
    setState(() {
      if (target != null && targetIndex != null) {
        final updated = [..._targets];
        updated[targetIndex] = result;
        _targets = updated;
      } else if (target != null) {
        final index = _targets.indexWhere((t) => t.id == target.id);
        if (index >= 0) {
          final updated = [..._targets];
          updated[index] = result;
          _targets = updated;
        }
      } else {
        _targets = [..._targets, result];
      }
    });
    _persistSender();
  }

  Future<void> _openControlDialog({OscControl? control, int? controlIndex}) async {
    final result = await showControlDialog(context, control: control);
    if (result == null) return;
    setState(() {
      if (control != null && controlIndex != null) {
        final updated = [..._controls];
        updated[controlIndex] = result;
        _controls = updated;
      } else if (control != null) {
        final index = _controls.indexWhere((c) => c.id == control.id);
        if (index >= 0) {
          final updated = [..._controls];
          updated[index] = result;
          _controls = updated;
        }
      } else {
        _controls = [..._controls, result];
      }
    });
    _persistSender();
  }

  void _showAlert(String message) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.alert),
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
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            SectionHeader(
                              title: l10n.sendTargets,
                              trailingMinWidth:
                                  AppLayoutMetrics.primaryButtonCompactWidth(
                                context,
                                l10n.add,
                              ),
                              trailing: PrimaryButton(
                                label: l10n.add,
                                icon: Icons.add,
                                compact: true,
                                onPressed: () => _openTargetDialog(),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _targets.length,
                                itemBuilder: (context, index) {
                                  final target = _targets[index];
                                  return _TargetCard(
                                    key: ValueKey('target_${target.id}_$index'),
                                    target: target,
                                    enabledLabel: l10n.enabled,
                                    disabledLabel: l10n.disabled,
                                    onEdit: () => _openTargetDialog(
                                      target: target,
                                      targetIndex: index,
                                    ),
                                    onDelete: () {
                                      setState(() => _targets.removeAt(index));
                                      _persistSender();
                                    },
                                    onToggle: (enabled) {
                                      setState(() {
                                        _targets[index] = _targets[index]
                                            .copyWith(enabled: enabled);
                                      });
                                      _persistSender();
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.gray200),
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            SectionHeader(
                              title: l10n.sendLog,
                              trailing: _logs.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: AppColors.red500,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      tooltip: l10n.clear,
                                      onPressed: () =>
                                          setState(() => _logs.clear()),
                                    ),
                            ),
                            Expanded(
                              child: _logs.isEmpty
                                  ? Center(
                                      child: Text(
                                        l10n.noSendRecords,
                                        style: AppTypography.caption,
                                      ),
                                    )
                                  : Scrollbar(
                                      controller: _logScrollController,
                                      thumbVisibility: true,
                                      child: ListView.builder(
                                        controller: _logScrollController,
                                        padding: const EdgeInsets.all(12),
                                        itemCount: _logs.length,
                                        itemBuilder: (context, index) {
                                          final log = _logs[index];
                                          return _LogCard(
                                            log: log,
                                            targetsLabel: l10n.logTargets(
                                              log.targets.length,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1, color: AppColors.gray200),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 150;
                    final outerPadding = compact ? 8.0 : 16.0;
                    final panelGap = compact ? 8.0 : 16.0;
                    final panelPadding = compact ? 10.0 : 16.0;
                    final headerGap = compact ? 8.0 : 12.0;
                    final controlHeaderGap = compact ? 8.0 : 16.0;

                    return Padding(
                      padding: EdgeInsets.all(outerPadding),
                      child: Column(
                        children: [
                          CardPanel(
                            padding: EdgeInsets.all(panelPadding),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!compact)
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final targetsText = l10n.targetsEnabled(
                                        _enabledTargets.length,
                                      );
                                      const gap = 8.0;
                                      final targetsWidth =
                                          AppLayoutMetrics.measureTextWidth(
                                        context,
                                        targetsText,
                                        AppTypography.caption,
                                      );
                                      final showTargets =
                                          constraints.maxWidth >=
                                              AppLayoutMetrics
                                                      .headerMinTitleWidth +
                                                  gap +
                                                  targetsWidth;

                                      return Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              l10n.commandSend,
                                              style:
                                                  AppTypography.sectionTitle,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          if (showTargets) ...[
                                            const SizedBox(width: gap),
                                            Text(
                                              targetsText,
                                              style: AppTypography.caption,
                                              maxLines: 1,
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                                if (!compact) SizedBox(height: headerGap),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: _commandControlHeight,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: AppColors.white,
                                            borderRadius:
                                                BorderRadius.circular(
                                              _commandBorderRadius,
                                            ),
                                            border: Border.all(
                                              color: _commandFocused
                                                  ? AppColors.blue500
                                                  : AppColors.gray200,
                                              width: _commandFocused ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: _commandInputPadding,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: TextField(
                                                controller: _commandController,
                                                focusNode: _commandFocusNode,
                                                maxLines: 1,
                                                style: _commandTextStyle
                                                    .copyWith(
                                                  color: AppColors.gray700,
                                                ),
                                                decoration: InputDecoration(
                                                  isCollapsed: true,
                                                  hintText: l10n.commandHint,
                                                  hintStyle: _commandTextStyle
                                                      .copyWith(
                                                    color: AppColors.gray500,
                                                  ),
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  border: InputBorder.none,
                                                  enabledBorder:
                                                      InputBorder.none,
                                                  focusedBorder:
                                                      InputBorder.none,
                                                  disabledBorder:
                                                      InputBorder.none,
                                                  errorBorder: InputBorder.none,
                                                  focusedErrorBorder:
                                                      InputBorder.none,
                                                ),
                                                onSubmitted: (_) =>
                                                    _sendCommand(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    PrimaryButton(
                                      label: l10n.send,
                                      icon: Icons.send,
                                      compact: true,
                                      height: _commandControlHeight,
                                      borderRadius: _commandBorderRadius,
                                      onPressed: _sendCommand,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: panelGap),
                          Expanded(
                            child: CardPanel(
                              padding: EdgeInsets.zero,
                              child: LayoutBuilder(
                                builder: (context, panelConstraints) {
                                  final panelHeight =
                                      panelConstraints.maxHeight;
                                  const headerRowHeight = 32.0;
                                  final tightPanel = panelHeight < 72;
                                  final preferredHeaderTop =
                                      tightPanel ? 8.0 : panelPadding;
                                  final preferredHeaderGap =
                                      tightPanel ? 4.0 : controlHeaderGap;

                                  final headerTop = (panelHeight -
                                          headerRowHeight)
                                      .clamp(0.0, preferredHeaderTop);
                                  final remainingAfterHeader =
                                      panelHeight - headerTop - headerRowHeight;
                                  final headerGap = remainingAfterHeader
                                      .clamp(0.0, preferredHeaderGap);
                                  final rowHeight = (panelHeight -
                                          headerTop -
                                          headerGap)
                                      .clamp(0.0, headerRowHeight);

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          16,
                                          headerTop,
                                          16,
                                          0,
                                        ),
                                        child: SizedBox(
                                          height: rowHeight,
                                          child: rowHeight > 0
                                              ? LayoutBuilder(
                                                  builder:
                                                      (context, constraints) {
                                                    const gap = 8.0;
                                                    final addWidth =
                                                        AppLayoutMetrics
                                                            .primaryButtonCompactWidth(
                                                      context,
                                                      l10n.addControl,
                                                    );
                                                    var extraWidth =
                                                        constraints.maxWidth -
                                                            addWidth -
                                                            AppLayoutMetrics
                                                                .headerMinTitleWidth;
                                                    final showChannel =
                                                        _hasAdmObjectControls &&
                                                            extraWidth >=
                                                                AppLayoutMetrics
                                                                        .admChannelPickerCompactWidth +
                                                                    gap;

                                                    return Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            l10n.controlPanel,
                                                            style: AppTypography
                                                                .sectionTitle,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            maxLines: 1,
                                                          ),
                                                        ),
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            if (showChannel) ...[
                                                              _AdmChannelPicker(
                                                                channel:
                                                                    _admObjectChannel,
                                                                label: l10n
                                                                    .admObjectChannel,
                                                                onChanged:
                                                                    _setAdmObjectChannel,
                                                                compact: true,
                                                                height:
                                                                    _commandControlHeight,
                                                              ),
                                                              const SizedBox(
                                                                width: gap,
                                                              ),
                                                            ],
                                                            PrimaryButton(
                                                              label: l10n
                                                                  .addControl,
                                                              icon: Icons.add,
                                                              compact: true,
                                                              height:
                                                                  _commandControlHeight,
                                                              borderRadius:
                                                                  _commandBorderRadius,
                                                              onPressed: () =>
                                                                  _openControlDialog(),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ),
                                      if (headerGap > 0)
                                        SizedBox(height: headerGap),
                                      Expanded(
                                        child: _controls.isEmpty
                                            ? Padding(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                child: Center(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.tune,
                                                        size: tightPanel
                                                            ? 32
                                                            : 48,
                                                        color: AppColors
                                                            .gray400
                                                            .withValues(
                                                          alpha: 0.3,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        height:
                                                            tightPanel ? 6 : 12,
                                                      ),
                                                      Text(
                                                        l10n.noControlsYet,
                                                        style: AppTypography
                                                            .bodySmall,
                                                        textAlign:
                                                            TextAlign.center,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 2,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : Scrollbar(
                                                controller:
                                                    _controlsScrollController,
                                                thumbVisibility: true,
                                                child: SingleChildScrollView(
                                                  controller:
                                                      _controlsScrollController,
                                                  padding: EdgeInsets.fromLTRB(
                                                    16,
                                                    0,
                                                    16,
                                                    panelPadding,
                                                  ),
                                                  child: Wrap(
                                                    spacing: ControlGridLayout
                                                        .spacing,
                                                    runSpacing:
                                                        ControlGridLayout
                                                            .spacing,
                                                    children: [
                                                      for (final control
                                                          in _controls)
                                                        ControlGridLayout.tile(
                                                          child: ControlCard(
                                                            control: control,
                                                            onChanged:
                                                                (updated) =>
                                                                    _updateControl(
                                                              control.id,
                                                              updated,
                                                            ),
                                                            onSend: () =>
                                                                _sendControl(
                                                              control,
                                                            ),
                                                            onEdit: () =>
                                                                _openControlDialog(
                                                              control: control,
                                                            ),
                                                            onDelete: () =>
                                                                _deleteControl(
                                                              control.id,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdmChannelPicker extends StatelessWidget {
  const _AdmChannelPicker({
    required this.channel,
    required this.label,
    required this.onChanged,
    this.compact = false,
    this.height = 32,
  });

  final int channel;
  final String label;
  final ValueChanged<int> onChanged;
  final bool compact;
  final double height;

  @override
  Widget build(BuildContext context) {
    final picker = SizedBox(
      height: height,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.blue100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.blue200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Text(
                label,
                style: AppTypography.caption,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(width: 4),
            ],
            _ChannelStepButton(
              icon: Icons.remove,
              onTap: channel > 1 ? () => onChanged(channel - 1) : null,
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$channel',
                textAlign: TextAlign.center,
                style: AppTypography.mono.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue600,
                ),
              ),
            ),
            _ChannelStepButton(
              icon: Icons.add,
              onTap: () => onChanged(channel + 1),
            ),
          ],
        ),
      ),
    );

    if (compact) {
      return Tooltip(message: label, child: picker);
    }
    return picker;
  }
}

class _ChannelStepButton extends StatefulWidget {
  const _ChannelStepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_ChannelStepButton> createState() => _ChannelStepButtonState();
}

class _ChannelStepButtonState extends State<_ChannelStepButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: enabled && _pressed ? 0.9 : (enabled && _hovered ? 1.08 : 1),
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered && enabled ? AppColors.blue100 : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: enabled ? AppColors.blue600 : AppColors.gray300,
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({
    super.key,
    required this.target,
    required this.enabledLabel,
    required this.disabledLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final OscTarget target;
  final String enabledLabel;
  final String disabledLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: target.enabled ? AppColors.emerald50 : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: target.enabled ? AppColors.emerald200 : AppColors.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${target.ip}:${target.port}',
                      style: AppTypography.mono,
                    ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                target.enabled ? enabledLabel : disabledLabel,
                style: AppTypography.caption,
              ),
              AppSwitch(
                value: target.enabled,
                onChanged: onToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log, required this.targetsLabel});

  final OscLogEntry log;
  final String targetsLabel;

  @override
  Widget build(BuildContext context) {
    final mono = AppTypography.mono.copyWith(fontSize: 11, height: 1.45);
    final argLines = log.arguments
        .map((arg) => OscCodec.formatArgument(arg))
        .join('  ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatTime(log.timestamp, withMs: true),
                  style: AppTypography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(targetsLabel, style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            log.address,
            style: mono.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.blue600,
            ),
          ),
          Text(
            log.typeTag,
            style: mono.copyWith(color: AppColors.gray600),
          ),
          if (argLines.isNotEmpty)
            Text(
              argLines,
              style: mono.copyWith(color: AppColors.orange500),
            ),
          if (log.targets.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                style: AppTypography.caption.copyWith(fontFamily: 'Consolas'),
                children: [
                  for (var i = 0; i < log.targets.length; i++) ...[
                    if (i > 0)
                      const TextSpan(
                        text: ', ',
                        style: TextStyle(color: AppColors.gray600),
                      ),
                    TextSpan(
                      text: log.targets[i],
                      style: TextStyle(
                        color: log.failedTargets.contains(log.targets[i])
                            ? AppColors.red600
                            : AppColors.gray600,
                      ),
                    ),
                  ],
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }
}
