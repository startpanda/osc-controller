import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/osc_models.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

Future<OscTarget?> showTargetDialog(
  BuildContext context, {
  OscTarget? target,
}) {
  return showDialog<OscTarget>(
    context: context,
    builder: (context) => _TargetDialog(target: target),
  );
}

Future<OscControl?> showControlDialog(
  BuildContext context, {
  OscControl? control,
}) {
  return showDialog<OscControl>(
    context: context,
    builder: (context) => _ControlDialog(control: control),
  );
}

Future<ListenerPort?> showPortDialog(
  BuildContext context, {
  ListenerPort? port,
}) {
  return showDialog<ListenerPort>(
    context: context,
    builder: (context) => _PortDialog(port: port),
  );
}

class _TargetDialog extends StatefulWidget {
  const _TargetDialog({this.target});

  final OscTarget? target;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _ipController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.target?.label ?? '');
    _ipController = TextEditingController(text: widget.target?.ip ?? '');
    _portController = TextEditingController(text: widget.target?.port ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();
    if (ip.isEmpty || port.isEmpty) {
      _alert(l10n.enterIpAndPort);
      return;
    }
    final label = _labelController.text.trim().isEmpty
        ? '$ip:$port'
        : _labelController.text.trim();
    Navigator.pop(
      context,
      OscTarget(
        id: widget.target?.id ?? newOscEntityId(),
        ip: ip,
        port: port,
        enabled: widget.target?.enabled ?? true,
        label: label,
      ),
    );
  }

  void _alert(String message) {
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
    final editing = widget.target != null;
    return AlertDialog(
      title: Text(editing ? l10n.editSendTarget : l10n.addSendTarget),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              editing ? l10n.editSendTargetDesc : l10n.addSendTargetDesc,
              style: const TextStyle(fontSize: 14, color: AppColors.gray500),
            ),
            const SizedBox(height: 20),
            _Field(
              label: l10n.targetName,
              controller: _labelController,
              hint: l10n.targetNameHint,
            ),
            const SizedBox(height: 12),
            _Field(
              label: l10n.ipAddress,
              controller: _ipController,
              hint: '127.0.0.1',
            ),
            const SizedBox(height: 12),
            _Field(
              label: l10n.port,
              controller: _portController,
              hint: '8000',
            ),
          ],
        ),
      ),
      actions: [
        DialogCancelButton(
          label: l10n.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        DialogConfirmButton(
          label: editing ? l10n.saveChanges : l10n.confirmAdd,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _ControlDialog extends StatefulWidget {
  const _ControlDialog({this.control});

  final OscControl? control;

  @override
  State<_ControlDialog> createState() => _ControlDialogState();
}

class _ControlDialogState extends State<_ControlDialog> {
  late ControlType _type;
  late TextEditingController _labelController;
  late TextEditingController _addressController;
  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _stepController;
  late TextEditingController _defaultTextController;
  late TextEditingController _toggleOffController;
  late TextEditingController _toggleOnController;
  late OscDataType _dataType;

  static const _toggleDataTypes = [
    OscDataType.tTrue,
    OscDataType.i,
    OscDataType.f,
    OscDataType.d,
    OscDataType.s,
    OscDataType.h,
    OscDataType.c,
  ];

  static const _nonToggleDataTypes = [
    OscDataType.f,
    OscDataType.i,
    OscDataType.s,
    OscDataType.tTrue,
    OscDataType.fFalse,
    OscDataType.d,
    OscDataType.h,
    OscDataType.c,
    OscDataType.r,
    OscDataType.n,
    OscDataType.impulse,
  ];

  bool get _showToggleValueFields =>
      _type == ControlType.toggle && !_usesToggleTypeTags(_dataType);

  bool _usesToggleTypeTags(OscDataType type) => type == OscDataType.tTrue;

  OscDataType _resolvedToggleDataType(OscControl? control) {
    if (control == null || control.type != ControlType.toggle) {
      return OscDataType.tTrue;
    }
    if (control.usesToggleTypeTags) {
      return OscDataType.tTrue;
    }
    if (_toggleDataTypes.contains(control.dataType)) {
      return control.dataType;
    }
    if (control.dataType == OscDataType.fFalse ||
        control.dataType == OscDataType.tTrue) {
      return OscDataType.tTrue;
    }
    return OscDataType.tTrue;
  }

  @override
  void initState() {
    super.initState();
    final c = widget.control;
    _type = c?.type ?? ControlType.slider;
    final toggleType = _resolvedToggleDataType(c);
    _dataType = c?.type == ControlType.toggle
        ? toggleType
        : (c?.dataType ?? OscDataType.f);
    _labelController = TextEditingController(text: c?.label ?? 'New Control');
    _addressController = TextEditingController(text: c?.address ?? '/control');
    _minController = TextEditingController(text: '${c?.min ?? 0}');
    _maxController = TextEditingController(text: '${c?.max ?? 1}');
    _stepController = TextEditingController(text: '${c?.step ?? 0.01}');
    _defaultTextController =
        TextEditingController(text: c?.value?.toString() ?? '');
    _toggleOffController = TextEditingController(
      text: _formatToggleValue(
        c?.toggleOffValue ?? c?.value,
        toggleType,
        on: false,
      ),
    );
    _toggleOnController = TextEditingController(
      text: _formatToggleValue(
        c?.toggleOnValue,
        toggleType,
        on: true,
      ),
    );
  }

  String _formatToggleValue(
    dynamic value,
    OscDataType type, {
    required bool on,
  }) {
    if (value != null) {
      return value.toString();
    }
    return on ? _defaultToggleOnText(type) : _defaultToggleOffText(type);
  }

  String _defaultToggleOffText(OscDataType type) => switch (type) {
        OscDataType.i || OscDataType.h => '0',
        OscDataType.f || OscDataType.d => '0',
        OscDataType.s || OscDataType.c => 'false',
        _ => '0',
      };

  String _defaultToggleOnText(OscDataType type) => switch (type) {
        OscDataType.i || OscDataType.h => '1',
        OscDataType.f || OscDataType.d => '1',
        OscDataType.s || OscDataType.c => 'true',
        _ => '1',
      };

  void _applyToggleDefaultsForType(OscDataType type) {
    _toggleOffController.text = _defaultToggleOffText(type);
    _toggleOnController.text = _defaultToggleOnText(type);
  }

  dynamic _parseToggleValue(OscDataType type, String text) {
    final trimmed = text.trim();
    switch (type) {
      case OscDataType.i:
      case OscDataType.h:
        return int.tryParse(trimmed) ?? 0;
      case OscDataType.f:
      case OscDataType.d:
        return double.tryParse(trimmed) ?? 0.0;
      case OscDataType.s:
      case OscDataType.c:
        return trimmed;
      default:
        return trimmed;
    }
  }

  String _toggleDataTypeLabel(AppLocalizations l10n, OscDataType type) {
    if (type == OscDataType.tTrue) return l10n.toggleDataTypeTf;
    return type.label;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _stepController.dispose();
    _defaultTextController.dispose();
    _toggleOffController.dispose();
    _toggleOnController.dispose();
    super.dispose();
  }

  OscControl _defaultConfig(ControlType type) {
    final id = widget.control?.id ?? newOscEntityId();
    final label = _labelController.text;
    final address = _addressController.text;

    switch (type) {
      case ControlType.slider:
        return OscControl(
          id: id,
          type: type,
          label: label,
          address: address,
          min: 0,
          max: 1,
          step: 0.01,
          value: 0.5,
          dataType: OscDataType.f,
          args: [const OscArgument(type: OscDataType.f, value: 0.5)],
        );
      case ControlType.toggle:
        return OscControl(
          id: id,
          type: type,
          label: label,
          address: address,
          value: false,
          dataType: OscDataType.fFalse,
          args: const [OscArgument(type: OscDataType.fFalse, value: false)],
        );
      case ControlType.button:
        return OscControl(
          id: id,
          type: type,
          label: label,
          address: address,
          value: 1,
          dataType: OscDataType.impulse,
          args: [const OscArgument(type: OscDataType.impulse, value: null)],
        );
      case ControlType.xyPad:
        return OscControl(
          id: id,
          type: type,
          label: label,
          address: address,
          min: 0,
          max: 1,
          step: 0.01,
          value: {'x': 0.5, 'y': 0.5},
          dataType: OscDataType.f,
          args: [
            const OscArgument(type: OscDataType.f, value: 0.5),
            const OscArgument(type: OscDataType.f, value: 0.5),
          ],
        );
      case ControlType.input:
        return OscControl(
          id: id,
          type: type,
          label: label,
          address: address,
          value: '',
          dataType: OscDataType.s,
          args: [const OscArgument(type: OscDataType.s, value: '')],
        );
      case ControlType.color:
        return OscControl(
          id: id,
          type: type,
          label: label,
          address: address,
          value: '#ff0000',
          dataType: OscDataType.r,
          args: [
            OscArgument(
              type: OscDataType.r,
              value: {'r': 255, 'g': 0, 'b': 0, 'a': 255},
            ),
          ],
        );
      case ControlType.admXyz:
        return OscControl(
          id: id,
          type: type,
          label: label,
          address: address,
          min: -1,
          max: 1,
          step: 0.01,
          value: const {'x': 0.0, 'y': 0.0, 'z': 0.0},
          dataType: OscDataType.f,
          args: const [
            OscArgument(type: OscDataType.f, value: 0.0),
            OscArgument(type: OscDataType.f, value: 0.0),
            OscArgument(type: OscDataType.f, value: 0.0),
          ],
        );
      case ControlType.admYpr:
        return OscControl(
          id: id,
          type: type,
          label: label,
          address: address,
          min: -180,
          max: 180,
          step: 0.1,
          value: const {'yaw': 0.0, 'pitch': 0.0, 'roll': 0.0},
          dataType: OscDataType.f,
          args: const [
            OscArgument(type: OscDataType.f, value: 0.0),
            OscArgument(type: OscDataType.f, value: 0.0),
            OscArgument(type: OscDataType.f, value: 0.0),
          ],
        );
      case ControlType.admAed:
        return OscControl(
          id: id,
          type: type,
          label: label,
          address: address,
          dataType: OscDataType.f,
          value: const {'azim': 0.0, 'elev': 0.0, 'dist': 1.0},
          args: const [
            OscArgument(type: OscDataType.f, value: 0.0),
            OscArgument(type: OscDataType.f, value: 0.0),
            OscArgument(type: OscDataType.f, value: 1.0),
          ],
        );
    }
  }

  void _save() {
    final base = _defaultConfig(_type).copyWith(
      label: _labelController.text,
      address: _addressController.text,
      dataType: _dataType,
    );

    OscControl result;
    if (_type == ControlType.slider || _type == ControlType.xyPad) {
      result = base.copyWith(
        min: double.tryParse(_minController.text) ?? 0,
        max: double.tryParse(_maxController.text) ?? 1,
        step: double.tryParse(_stepController.text) ?? 0.01,
      );
    } else if (_type == ControlType.input) {
      final text = _defaultTextController.text;
      result = base.copyWith(
        value: text,
        args: [OscArgument(type: OscDataType.s, value: text)],
      );
    } else if (_type == ControlType.toggle) {
      if (_usesToggleTypeTags(_dataType)) {
        result = base.copyWith(
          value: false,
          dataType: OscDataType.fFalse,
          args: const [OscArgument(type: OscDataType.fFalse, value: false)],
          clearToggleOnValue: true,
          clearToggleOffValue: true,
        );
      } else {
        final offVal = _parseToggleValue(_dataType, _toggleOffController.text);
        final onVal = _parseToggleValue(_dataType, _toggleOnController.text);
        result = base.copyWith(
          value: offVal,
          dataType: _dataType,
          toggleOffValue: offVal,
          toggleOnValue: onVal,
          args: [OscArgument(type: _dataType, value: offVal)],
        );
      }
    } else {
      result = base;
    }

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.control != null;
    return AlertDialog(
      title: Text(editing ? l10n.editControl : l10n.addControlTitle),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing ? l10n.editControlDesc : l10n.addControlDesc,
                style: const TextStyle(fontSize: 14, color: AppColors.gray500),
              ),
              const SizedBox(height: 20),
              _DialogLabel(l10n.controlType),
              editing
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: Text(l10n.controlTypeLabel(_type)),
                    )
                  : _DialogDropdownField<ControlType>(
                      value: _type,
                      items: ControlType.values,
                      itemLabel: l10n.controlTypeLabel,
                      onChanged: (value) {
                        setState(() {
                          _type = value;
                          final config = _defaultConfig(value);
                          _dataType = value == ControlType.toggle
                              ? OscDataType.tTrue
                              : config.dataType;
                          _minController.text = '${config.min}';
                          _maxController.text = '${config.max}';
                          _stepController.text = '${config.step}';
                          if (value == ControlType.toggle &&
                              !_usesToggleTypeTags(_dataType)) {
                            _applyToggleDefaultsForType(_dataType);
                          }
                        });
                      },
                    ),
              const SizedBox(height: 12),
              _Field(
                label: l10n.labelName,
                controller: _labelController,
                hint: l10n.labelNameHint,
              ),
              const SizedBox(height: 12),
              _Field(
                label: l10n.oscAddress,
                controller: _addressController,
                hint: '/osc/address',
                mono: true,
              ),
              const SizedBox(height: 12),
              _DialogLabel(l10n.dataType),
              _DialogDropdownField<OscDataType>(
                value: _dataType,
                items: _type == ControlType.toggle
                    ? _toggleDataTypes
                    : _nonToggleDataTypes,
                itemLabel: (type) => _type == ControlType.toggle
                    ? _toggleDataTypeLabel(l10n, type)
                    : type.label,
                itemStyle: const TextStyle(fontFamily: 'Consolas'),
                onChanged: (value) {
                  setState(() {
                    _dataType = value;
                    if (_type == ControlType.toggle &&
                        !_usesToggleTypeTags(value)) {
                      _applyToggleDefaultsForType(value);
                    }
                  });
                },
              ),
              if (_showToggleValueFields) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: l10n.toggleOffValue,
                        controller: _toggleOffController,
                        hint: _defaultToggleOffText(_dataType),
                        mono: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        label: l10n.toggleOnValue,
                        controller: _toggleOnController,
                        hint: _defaultToggleOnText(_dataType),
                        mono: true,
                      ),
                    ),
                  ],
                ),
              ],
              if (_type == ControlType.slider || _type == ControlType.xyPad) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: l10n.minValue,
                        controller: _minController,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        label: l10n.maxValue,
                        controller: _maxController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Field(label: l10n.stepValue, controller: _stepController),
              ],
              if (_type == ControlType.input) ...[
                const SizedBox(height: 12),
                _Field(
                  label: l10n.defaultText,
                  controller: _defaultTextController,
                  hint: l10n.defaultTextHint,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        DialogCancelButton(
          label: l10n.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        DialogConfirmButton(
          label: editing ? l10n.saveChanges : l10n.confirmAdd,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _PortDialog extends StatefulWidget {
  const _PortDialog({this.port});

  final ListenerPort? port;

  @override
  State<_PortDialog> createState() => _PortDialogState();
}

class _PortDialogState extends State<_PortDialog> {
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(text: widget.port?.port ?? '');
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    final port = _portController.text.trim();
    if (port.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n.enterPortNumber),
          actions: [
            DialogConfirmButton(
              label: l10n.ok,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      ListenerPort(
        id: widget.port?.id ?? newOscEntityId(),
        port: port,
        active: widget.port?.active ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.port != null;
    return AlertDialog(
      title: Text(editing ? l10n.editListenPort : l10n.addListenPort),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              editing ? l10n.editListenPortDesc : l10n.addListenPortDesc,
              style: const TextStyle(fontSize: 14, color: AppColors.gray500),
            ),
            const SizedBox(height: 20),
            _Field(
              label: l10n.portNumber,
              controller: _portController,
              hint: l10n.portNumberHint,
            ),
          ],
        ),
      ),
      actions: [
        DialogCancelButton(
          label: l10n.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        DialogConfirmButton(
          label: editing ? l10n.saveChanges : l10n.confirmAdd,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _DialogDropdownField<T> extends StatelessWidget {
  const _DialogDropdownField({
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.itemStyle,
  });

  static const _menuRadius = 8.0;
  static const _itemRadius = 6.0;
  static const _menuPadding = 4.0;

  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;
  final TextStyle? itemStyle;

  ButtonStyle _itemButtonStyle(TextStyle textStyle) {
    return MenuItemButton.styleFrom(
      minimumSize: const Size(double.infinity, 36),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: textStyle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_itemRadius),
      ),
      overlayColor: Colors.transparent,
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return AppColors.blue100;
        }
        if (states.contains(WidgetState.hovered)) {
          return AppColors.gray50;
        }
        return Colors.transparent;
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth = constraints.maxWidth;
        final textStyle = itemStyle ?? Theme.of(context).textTheme.bodyMedium;
        final buttonStyle = _itemButtonStyle(textStyle!);
        final effectiveValue = items.contains(value) ? value : items.first;

        return DropdownMenu<T>(
          key: ValueKey(effectiveValue),
          width: menuWidth,
          expandedInsets: EdgeInsets.zero,
          initialSelection: effectiveValue,
          textStyle: textStyle,
          inputDecorationTheme: const InputDecorationTheme(isDense: true),
          menuStyle: MenuStyle(
            alignment: AlignmentDirectional.bottomStart,
            minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
            maximumSize: WidgetStatePropertyAll(Size(menuWidth, 320)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.all(_menuPadding),
            ),
            backgroundColor: const WidgetStatePropertyAll(AppColors.white),
            elevation: const WidgetStatePropertyAll(4),
            shadowColor: WidgetStatePropertyAll(
              AppColors.gray900.withValues(alpha: 0.12),
            ),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_menuRadius),
                side: const BorderSide(color: AppColors.gray200),
              ),
            ),
          ),
          onSelected: (selected) {
            if (selected != null) onChanged(selected);
          },
          dropdownMenuEntries: items
              .map(
                (item) => DropdownMenuEntry<T>(
                  value: item,
                  label: itemLabel(item),
                  style: buttonStyle,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.gray600,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.mono = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogLabel(label),
        TextField(
          controller: controller,
          style: mono ? const TextStyle(fontFamily: 'Consolas') : null,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
