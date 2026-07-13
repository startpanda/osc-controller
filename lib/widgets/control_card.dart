import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/osc_models.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

class ControlCard extends StatefulWidget {
  const ControlCard({
    super.key,
    required this.control,
    required this.onChanged,
    required this.onSend,
    required this.onEdit,
    required this.onDelete,
  });

  final OscControl control;
  final ValueChanged<OscControl> onChanged;
  final VoidCallback onSend;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<ControlCard> createState() => _ControlCardState();
}

class _ControlCardState extends State<ControlCard> {
  bool _hovered = false;

  OscControl get control => widget.control;

  void _updateValue(dynamic value, {OscDataType? dataType}) {
    final updatedType = dataType ?? control.dataType;
    List<OscArgument> args;
    if (control.type == ControlType.xyPad && value is Map) {
      args = [
        OscArgument(type: OscDataType.f, value: value['x']),
        OscArgument(type: OscDataType.f, value: value['y']),
      ];
    } else if (control.type == ControlType.admXyz && value is Map) {
      args = [
        OscArgument(type: OscDataType.f, value: value['x']),
        OscArgument(type: OscDataType.f, value: value['y']),
        OscArgument(type: OscDataType.f, value: value['z']),
      ];
    } else if (control.type == ControlType.admYpr && value is Map) {
      args = [
        OscArgument(type: OscDataType.f, value: value['yaw']),
        OscArgument(type: OscDataType.f, value: value['pitch']),
        OscArgument(type: OscDataType.f, value: value['roll']),
      ];
    } else if (control.type == ControlType.admAed && value is Map) {
      args = [
        OscArgument(type: OscDataType.f, value: value['azim']),
        OscArgument(type: OscDataType.f, value: value['elev']),
        OscArgument(type: OscDataType.f, value: value['dist']),
      ];
    } else {
      args = [OscArgument(type: updatedType, value: value)];
    }
    widget.onChanged(
      control.copyWith(value: value, dataType: updatedType, args: args),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.all(6),
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
                  padding: const EdgeInsets.only(right: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        control.label,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        control.address,
                        style: AppTypography.monoSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(child: _buildControlBody()),
              ],
            ),
            if (_hovered)
              Positioned(
                top: 0,
                right: 0,
                child: Row(
                  children: [
                    _IconAction(
                      icon: Icons.edit,
                      color: AppColors.blue500,
                      onTap: widget.onEdit,
                    ),
                    _IconAction(
                      icon: Icons.delete_outline,
                      color: AppColors.red500,
                      onTap: widget.onDelete,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBody() {
    return switch (control.type) {
      ControlType.slider => _SliderBody(
          control: control,
          onChanged: (v) => _updateValue(v),
          onCommit: widget.onSend,
        ),
      ControlType.toggle => _ToggleBody(
          control: control,
          onChanged: (checked) {
            if (control.usesToggleTypeTags) {
              _updateValue(
                checked,
                dataType: checked ? OscDataType.tTrue : OscDataType.fFalse,
              );
            } else {
              final onVal =
                  control.toggleOnValue ?? _ToggleDefaults.onFor(control.dataType);
              final offVal =
                  control.toggleOffValue ?? _ToggleDefaults.offFor(control.dataType);
              _updateValue(checked ? onVal : offVal);
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) widget.onSend();
            });
          },
        ),
      ControlType.button => Center(
          child: PressableButton(
            onPressed: widget.onSend,
            width: control.admIsQuery ? 72 : 44,
            height: 44,
            borderRadius: control.admIsQuery ? 8 : 22,
            backgroundColor: control.admIsQuery
                ? AppColors.blue500
                : AppColors.orange400,
            hoverBackgroundColor: control.admIsQuery
                ? AppColors.blue600
                : AppColors.orange500,
            pressedBackgroundColor: control.admIsQuery
                ? const Color(0xFF1D4ED8)
                : const Color(0xFFEA580C),
            padding: EdgeInsets.zero,
            child: Text(
              control.admIsQuery ? 'GET' : 'BANG',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: control.admIsQuery ? 11 : 10,
              ),
            ),
          ),
        ),
      ControlType.xyPad => _XyPadBody(
          control: control,
          onChanged: (v) => _updateValue(v),
          onCommit: widget.onSend,
        ),
      ControlType.input => _InputBody(
          value: control.value?.toString() ?? '',
          onChanged: (v) => _updateValue(v),
          onSend: widget.onSend,
        ),
      ControlType.color => _ColorBody(
          colorHex: control.value?.toString() ?? '#ff0000',
          onChanged: (hex, rgba) {
            widget.onChanged(
              control.copyWith(
                value: hex,
                args: [OscArgument(type: OscDataType.r, value: rgba)],
              ),
            );
            widget.onSend();
          },
        ),
      ControlType.admXyz => _AdmXyzBody(
          control: control,
          onChanged: (v) => _updateValue(v),
          onCommit: widget.onSend,
        ),
      ControlType.admYpr => _AdmYprBody(
          control: control,
          onChanged: (v) => _updateValue(v),
          onCommit: widget.onSend,
        ),
      ControlType.admAed => _AdmAedBody(
          control: control,
          onChanged: (v) => _updateValue(v),
          onCommit: widget.onSend,
        ),
    };
  }
}

class _IconAction extends StatefulWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
          scale: _pressed ? 0.9 : (_hovered ? 1.08 : 1),
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _hovered ? AppColors.gray100 : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(widget.icon, size: 12, color: widget.color),
          ),
        ),
      ),
    );
  }
}

/// Compact numeric field for editing a slider value directly.
class _SliderValueInput extends StatefulWidget {
  const _SliderValueInput({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.isInteger,
    required this.onSubmitted,
    this.width = 56,
    this.textColor = AppColors.blue600,
    this.compact = false,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final bool isInteger;
  final ValueChanged<double> onSubmitted;
  final double width;
  final Color textColor;
  final bool compact;

  @override
  State<_SliderValueInput> createState() => _SliderValueInputState();
}

class _SliderValueInputState extends State<_SliderValueInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _SliderValueInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitInput();
    }
  }

  int _decimalPlaces(double step) {
    if (widget.isInteger || step <= 0) return 0;
    final text = step.toString();
    final dot = text.indexOf('.');
    if (dot < 0) return 0;
    return text.length - dot - 1;
  }

  String _format(double value) {
    if (widget.isInteger) return value.round().toString();
    return value.toStringAsFixed(_decimalPlaces(widget.step));
  }

  double _quantize(double raw) {
    final clamped = raw.clamp(widget.min, widget.max);
    if (widget.isInteger) return clamped.roundToDouble();
    if (widget.step <= 0) return clamped;
    final steps = ((clamped - widget.min) / widget.step).round();
    return (widget.min + steps * widget.step).clamp(widget.min, widget.max);
  }

  void _commitInput() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null) {
      _controller.text = _format(widget.value);
      return;
    }
    final next = _quantize(parsed);
    _controller.text = _format(next);
    if (next != widget.value) {
      widget.onSubmitted(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldHeight = widget.compact ? 20.0 : 24.0;
    final fieldWidth = widget.compact ? 40.0 : widget.width;

    return SizedBox(
      width: fieldWidth,
      height: fieldHeight,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textAlign: TextAlign.center,
        style: AppTypography.monoSmall.copyWith(
          fontSize: widget.compact ? 10 : 12,
          fontWeight: FontWeight.w700,
          color: widget.textColor,
        ),
        keyboardType: TextInputType.numberWithOptions(
          decimal: !widget.isInteger,
          signed: widget.min < 0,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 2 : 4,
            vertical: widget.compact ? 4 : 6,
          ),
          filled: true,
          fillColor: AppColors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.gray300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.gray300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.blue500, width: 1.5),
          ),
        ),
        onSubmitted: (_) => _focusNode.unfocus(),
        onEditingComplete: () {
          if (_focusNode.hasFocus) _focusNode.unfocus();
        },
      ),
    );
  }
}

/// Slider constrained to a narrow vertical hit area (track + thumb only).
class _CompactSlider extends StatelessWidget {
  const _CompactSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.activeColor,
    required this.onChanged,
    required this.onChangeEnd,
    this.divisions,
    this.compact = false,
  });

  static const height = 24.0;

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final Color activeColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final trackHeight = compact ? 18.0 : height;
    final thumb = compact ? 2.5 : 4.0;

    return SizedBox(
      height: trackHeight,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          overlayShape: SliderComponentShape.noOverlay,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumb),
        ),
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: activeColor,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
    );
  }
}

/// Label + trailing value field row that avoids horizontal overflow.
class _AxisValueRow extends StatelessWidget {
  const _AxisValueRow({
    required this.label,
    required this.input,
  });

  final String label;
  final Widget input;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          fit: FlexFit.loose,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: input,
          ),
        ),
      ],
    );
  }
}

/// Scales [child] down to fit without unbounded-width layout errors.
class _ScaleToFit extends StatelessWidget {
  const _ScaleToFit({
    required this.child,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}

/// Fits a fixed-height multi-axis column without scrolling or overflow.
class _TripleAxisColumn extends StatelessWidget {
  const _TripleAxisColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

class _SliderBody extends StatefulWidget {
  const _SliderBody({
    required this.control,
    required this.onChanged,
    required this.onCommit,
  });

  final OscControl control;
  final ValueChanged<double> onChanged;
  final VoidCallback onCommit;

  static const _sendInterval = Duration(milliseconds: 50);

  @override
  State<_SliderBody> createState() => _SliderBodyState();
}

class _SliderBodyState extends State<_SliderBody> {
  Timer? _sendTimer;
  DateTime? _lastSentAt;

  @override
  void dispose() {
    _sendTimer?.cancel();
    super.dispose();
  }

  void _handleChanged(double value) {
    widget.onChanged(value);
    _scheduleSend();
  }

  void _scheduleSend() {
    final now = DateTime.now();
    final elapsed = _lastSentAt != null
        ? now.difference(_lastSentAt!)
        : _SliderBody._sendInterval;

    if (_lastSentAt == null || elapsed >= _SliderBody._sendInterval) {
      _lastSentAt = now;
      widget.onCommit();
      _sendTimer?.cancel();
      _sendTimer = null;
      return;
    }

    _sendTimer ??= Timer(_SliderBody._sendInterval - elapsed, () {
      _sendTimer = null;
      _lastSentAt = DateTime.now();
      widget.onCommit();
    });
  }

  void _handleChangeEnd(double value) {
    _sendTimer?.cancel();
    _sendTimer = null;
    widget.onChanged(value);
    _lastSentAt = DateTime.now();
    widget.onCommit();
  }

  @override
  Widget build(BuildContext context) {
    final control = widget.control;
    final value = (control.value as num?)?.toDouble() ?? 0;
    final isInteger = control.dataType == OscDataType.i;

    return _ScaleToFit(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 20,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${control.min}',
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                _SliderValueInput(
                  value: value.clamp(control.min, control.max),
                  min: control.min,
                  max: control.max,
                  step: control.step,
                  isInteger: isInteger,
                  compact: true,
                  onSubmitted: (v) {
                    _handleChanged(v);
                    _handleChangeEnd(v);
                  },
                ),
                Expanded(
                  child: Text(
                    '${control.max}',
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          _CompactSlider(
            value: value.clamp(control.min, control.max),
            min: control.min,
            max: control.max,
            divisions: control.step > 0
                ? ((control.max - control.min) / control.step).round()
                : null,
            activeColor: AppColors.blue500,
            compact: true,
            onChanged: _handleChanged,
            onChangeEnd: _handleChangeEnd,
          ),
        ],
      ),
    );
  }
}

class _ToggleDefaults {
  static dynamic onFor(OscDataType type) => switch (type) {
        OscDataType.i || OscDataType.h => 1,
        OscDataType.f || OscDataType.d => 1.0,
        OscDataType.s || OscDataType.c => 'true',
        _ => true,
      };

  static dynamic offFor(OscDataType type) => switch (type) {
        OscDataType.i || OscDataType.h => 0,
        OscDataType.f || OscDataType.d => 0.0,
        OscDataType.s || OscDataType.c => 'false',
        _ => false,
      };

  static bool equals(dynamic a, dynamic b) {
    if (a is num && b is num) return a == b;
    return a == b;
  }
}

class _ToggleBody extends StatelessWidget {
  const _ToggleBody({required this.control, required this.onChanged});

  final OscControl control;
  final ValueChanged<bool> onChanged;

  bool get _value {
    if (control.usesToggleTypeTags) {
      return control.dataType == OscDataType.tTrue;
    }
    final onVal =
        control.toggleOnValue ?? _ToggleDefaults.onFor(control.dataType);
    return _ToggleDefaults.equals(control.value, onVal);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppSwitch(
        value: _value,
        onChanged: onChanged,
        activeColor: AppColors.blue500,
        width: 44,
        height: 24,
      ),
    );
  }
}

class _XyPadBody extends StatelessWidget {
  const _XyPadBody({
    required this.control,
    required this.onChanged,
    required this.onCommit,
  });

  final OscControl control;
  final ValueChanged<Map<String, double>> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final map = control.value as Map? ?? {'x': 0.5, 'y': 0.5};
    final x = (map['x'] as num?)?.toDouble() ?? 0.5;
    final y = (map['y'] as num?)?.toDouble() ?? 0.5;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanDown: (d) => _handle(d.localPosition, constraints),
                onPanUpdate: (d) => _handle(d.localPosition, constraints),
                onPanEnd: (_) => onCommit(),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _XyPadPainter(x: x, y: y),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'X: ${x.toStringAsFixed(2)}',
                style: AppTypography.monoSmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Expanded(
              child: Text(
                'Y: ${y.toStringAsFixed(2)}',
                style: AppTypography.monoSmall.copyWith(color: AppColors.purple600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handle(Offset pos, BoxConstraints constraints) {
    final x = (pos.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final y = (1 - pos.dy / constraints.maxHeight).clamp(0.0, 1.0);
    onChanged({'x': x, 'y': y});
  }
}

class _XyPadPainter extends CustomPainter {
  _XyPadPainter({required this.x, required this.y});

  final double x;
  final double y;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = AppColors.gray100;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(4),
      ),
      bg,
    );

    final gridPaint = Paint()
      ..color = AppColors.gray300.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final dx = size.width * i / 4;
      final dy = size.height * i / 4;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final border = Paint()
      ..color = AppColors.gray200
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(4),
      ),
      border,
    );

    final dotX = x * size.width;
    final dotY = (1 - y) * size.height;
    canvas.drawCircle(
      Offset(dotX, dotY),
      5,
      Paint()..color = AppColors.blue500,
    );
    canvas.drawCircle(
      Offset(dotX, dotY),
      3.5,
      Paint()..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _XyPadPainter oldDelegate) {
    return oldDelegate.x != x || oldDelegate.y != y;
  }
}

class _InputBody extends StatefulWidget {
  const _InputBody({
    required this.value,
    required this.onChanged,
    required this.onSend,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  State<_InputBody> createState() => _InputBodyState();
}

class _InputBodyState extends State<_InputBody> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _focused = false;

  static const _controlHeight = 32.0;
  static const _borderRadius = 6.0;
  static const _gap = 8.0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    final focused = _focusNode.hasFocus;
    if (_focused != focused) {
      setState(() => _focused = focused);
    }
  }

  @override
  void didUpdateWidget(covariant _InputBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _controlHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(_borderRadius),
              border: Border.all(
                color: _focused ? AppColors.blue500 : AppColors.gray200,
                width: _focused ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: 1,
                  style: AppTypography.bodySmall.copyWith(height: 1.0),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    hintText: l10n.inputPlaceholder,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => widget.onSend(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: _gap),
        PressableButton(
          onPressed: widget.onSend,
          borderRadius: _borderRadius,
          height: _controlHeight,
          width: double.infinity,
          padding: EdgeInsets.zero,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.send, size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l10n.send,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorBody extends StatelessWidget {
  const _ColorBody({required this.colorHex, required this.onChanged});

  final String colorHex;
  final void Function(String hex, Map<String, int> rgba) onChanged;

  Color _parseColor(String hex) {
    final value = hex.replaceFirst('#', '');
    if (value.length == 6) {
      return Color(int.parse('FF$value', radix: 16));
    }
    return Colors.red;
  }

  Map<String, int> _toRgba(Color color) {
    return {
      'r': (color.r * 255).round(),
      'g': (color.g * 255).round(),
      'b': (color.b * 255).round(),
      'a': 255,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(colorHex);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () async {
            final picked = await showDialog<Color>(
              context: context,
              builder: (context) => _SimpleColorPicker(initial: color),
            );
            if (picked != null) {
              final hex =
                  '#${(picked.r * 255).round().toRadixString(16).padLeft(2, '0')}'
                  '${(picked.g * 255).round().toRadixString(16).padLeft(2, '0')}'
                  '${(picked.b * 255).round().toRadixString(16).padLeft(2, '0')}';
              onChanged(hex, _toRgba(picked));
            }
          },
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.gray200),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(colorHex, style: AppTypography.monoSmall),
      ],
    );
  }
}

class _SimpleColorPicker extends StatefulWidget {
  const _SimpleColorPicker({required this.initial});

  final Color initial;

  @override
  State<_SimpleColorPicker> createState() => _SimpleColorPickerState();
}

class _SimpleColorPickerState extends State<_SimpleColorPicker> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = _hsv.toColor();
    return AlertDialog(
      title: Text(l10n.pickColor),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gray200),
              ),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _hsv.hue,
              min: 0,
              max: 360,
              activeColor: color,
              onChanged: (h) => setState(() => _hsv = _hsv.withHue(h)),
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
          label: l10n.ok,
          onPressed: () => Navigator.pop(context, color),
        ),
      ],
    );
  }
}

class _AdmXyzBody extends StatefulWidget {
  const _AdmXyzBody({
    required this.control,
    required this.onChanged,
    required this.onCommit,
  });

  final OscControl control;
  final ValueChanged<Map<String, double>> onChanged;
  final VoidCallback onCommit;

  @override
  State<_AdmXyzBody> createState() => _AdmXyzBodyState();
}

class _AdmXyzBodyState extends State<_AdmXyzBody> {
  Timer? _sendTimer;
  DateTime? _lastSentAt;
  static const _sendInterval = Duration(milliseconds: 50);

  @override
  void dispose() {
    _sendTimer?.cancel();
    super.dispose();
  }

  Map<String, double> get _values {
    final map = widget.control.value as Map? ?? const {'x': 0.0, 'y': 0.0, 'z': 0.0};
    return {
      'x': (map['x'] as num?)?.toDouble() ?? 0.0,
      'y': (map['y'] as num?)?.toDouble() ?? 0.0,
      'z': (map['z'] as num?)?.toDouble() ?? 0.0,
    };
  }

  void _emit(Map<String, double> values) {
    widget.onChanged(values);
    _scheduleSend();
  }

  void _scheduleSend() {
    final now = DateTime.now();
    final elapsed = _lastSentAt != null
        ? now.difference(_lastSentAt!)
        : _sendInterval;

    if (_lastSentAt == null || elapsed >= _sendInterval) {
      _lastSentAt = now;
      widget.onCommit();
      _sendTimer?.cancel();
      _sendTimer = null;
      return;
    }

    _sendTimer ??= Timer(_sendInterval - elapsed, () {
      _sendTimer = null;
      _lastSentAt = DateTime.now();
      widget.onCommit();
    });
  }

  void _commit(Map<String, double> values) {
    _sendTimer?.cancel();
    _sendTimer = null;
    widget.onChanged(values);
    _lastSentAt = DateTime.now();
    widget.onCommit();
  }

  @override
  Widget build(BuildContext context) {
    final control = widget.control;
    final values = _values;
    final min = control.min;
    final max = control.max;
    final nx = max == min ? 0.5 : (values['x']! - min) / (max - min);
    final ny = max == min ? 0.5 : (values['y']! - min) / (max - min);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanDown: (d) => _handleXY(d.localPosition, constraints),
                onPanUpdate: (d) => _handleXY(d.localPosition, constraints),
                onPanEnd: (_) => _commit(_values),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _AdmXyPadPainter(
                    nx: nx.clamp(0.0, 1.0),
                    ny: ny.clamp(0.0, 1.0),
                  ),
                ),
              );
            },
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AxisValueRow(
              label: 'Z',
              input: _SliderValueInput(
                value: values['z']!.clamp(min, max),
                min: min,
                max: max,
                step: control.step,
                isInteger: false,
                compact: true,
                textColor: AppColors.purple600,
                onSubmitted: (z) => _commit({...values, 'z': z}),
              ),
            ),
            _CompactSlider(
              value: values['z']!.clamp(min, max),
              min: min,
              max: max,
              divisions: control.step > 0
                  ? ((max - min) / control.step).round()
                  : null,
              activeColor: AppColors.purple600,
              compact: true,
              onChanged: (z) => _emit({...values, 'z': z}),
              onChangeEnd: (z) => _commit({...values, 'z': z}),
            ),
            Row(
              children: [
                Expanded(
                  child: _AxisValueRow(
                    label: 'X',
                    input: _SliderValueInput(
                      value: values['x']!.clamp(min, max),
                      min: min,
                      max: max,
                      step: control.step,
                      isInteger: false,
                      compact: true,
                      textColor: AppColors.blue500,
                      onSubmitted: (x) => _commit({...values, 'x': x}),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _AxisValueRow(
                    label: 'Y',
                    input: _SliderValueInput(
                      value: values['y']!.clamp(min, max),
                      min: min,
                      max: max,
                      step: control.step,
                      isInteger: false,
                      compact: true,
                      textColor: AppColors.orange500,
                      onSubmitted: (y) => _commit({...values, 'y': y}),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _handleXY(Offset pos, BoxConstraints constraints) {
    final min = widget.control.min;
    final max = widget.control.max;
    final current = _values;
    final nx = (pos.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final ny = (1 - pos.dy / constraints.maxHeight).clamp(0.0, 1.0);
    final x = min + nx * (max - min);
    final y = min + ny * (max - min);
    _emit({...current, 'x': x, 'y': y});
  }
}

class _AdmXyPadPainter extends CustomPainter {
  _AdmXyPadPainter({required this.nx, required this.ny});

  final double nx;
  final double ny;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = AppColors.gray100;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(4),
      ),
      bg,
    );

    final gridPaint = Paint()
      ..color = AppColors.gray300.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      gridPaint,
    );

    final dotX = nx * size.width;
    final dotY = (1 - ny) * size.height;
    canvas.drawCircle(
      Offset(dotX, dotY),
      5,
      Paint()..color = AppColors.blue500,
    );
    canvas.drawCircle(
      Offset(dotX, dotY),
      3.5,
      Paint()..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _AdmXyPadPainter oldDelegate) {
    return oldDelegate.nx != nx || oldDelegate.ny != ny;
  }
}

class _AdmYprBody extends StatefulWidget {
  const _AdmYprBody({
    required this.control,
    required this.onChanged,
    required this.onCommit,
  });

  final OscControl control;
  final ValueChanged<Map<String, double>> onChanged;
  final VoidCallback onCommit;

  @override
  State<_AdmYprBody> createState() => _AdmYprBodyState();
}

class _AdmYprBodyState extends State<_AdmYprBody> {
  Timer? _sendTimer;
  DateTime? _lastSentAt;
  static const _sendInterval = Duration(milliseconds: 50);

  @override
  void dispose() {
    _sendTimer?.cancel();
    super.dispose();
  }

  Map<String, double> get _values {
    final map = widget.control.value as Map? ??
        const {'yaw': 0.0, 'pitch': 0.0, 'roll': 0.0};
    return {
      'yaw': (map['yaw'] as num?)?.toDouble() ?? 0.0,
      'pitch': (map['pitch'] as num?)?.toDouble() ?? 0.0,
      'roll': (map['roll'] as num?)?.toDouble() ?? 0.0,
    };
  }

  void _update(String key, double value, {required bool commit}) {
    final next = {..._values, key: value};
    widget.onChanged(next);
    if (commit) {
      _sendTimer?.cancel();
      _sendTimer = null;
      _lastSentAt = DateTime.now();
      widget.onCommit();
      return;
    }

    final now = DateTime.now();
    final elapsed =
        _lastSentAt != null ? now.difference(_lastSentAt!) : _sendInterval;
    if (_lastSentAt == null || elapsed >= _sendInterval) {
      _lastSentAt = now;
      widget.onCommit();
      _sendTimer?.cancel();
      _sendTimer = null;
      return;
    }

    _sendTimer ??= Timer(_sendInterval - elapsed, () {
      _sendTimer = null;
      _lastSentAt = DateTime.now();
      widget.onCommit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final control = widget.control;
    final values = _values;
    final min = control.min;
    final max = control.max;
    final divisions = control.step > 0
        ? ((max - min) / control.step).round()
        : null;

    Widget axis(String key, String label, Color color) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AxisValueRow(
            label: label,
            input: _SliderValueInput(
              value: values[key]!.clamp(min, max),
              min: min,
              max: max,
              step: control.step,
              isInteger: false,
              textColor: color,
              compact: true,
              onSubmitted: (v) => _update(key, v, commit: true),
            ),
          ),
          _CompactSlider(
            value: values[key]!.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: color,
            compact: true,
            onChanged: (v) => _update(key, v, commit: false),
            onChangeEnd: (v) => _update(key, v, commit: true),
          ),
        ],
      );
    }

    return _TripleAxisColumn(
      children: [
        axis('yaw', 'Yaw', AppColors.blue500),
        axis('pitch', 'Pitch', AppColors.orange500),
        axis('roll', 'Roll', AppColors.purple600),
      ],
    );
  }
}

class _AdmAedBody extends StatefulWidget {
  const _AdmAedBody({
    required this.control,
    required this.onChanged,
    required this.onCommit,
  });

  final OscControl control;
  final ValueChanged<Map<String, double>> onChanged;
  final VoidCallback onCommit;

  @override
  State<_AdmAedBody> createState() => _AdmAedBodyState();
}

class _AdmAedBodyState extends State<_AdmAedBody> {
  Timer? _sendTimer;
  DateTime? _lastSentAt;
  static const _sendInterval = Duration(milliseconds: 50);

  static const _axes = [
    _AdmAxisSpec(key: 'azim', label: 'Azim', min: -180, max: 180, step: 0.1),
    _AdmAxisSpec(key: 'elev', label: 'Elev', min: -90, max: 90, step: 0.1),
    _AdmAxisSpec(key: 'dist', label: 'Dist', min: 0, max: 1, step: 0.01),
  ];

  @override
  void dispose() {
    _sendTimer?.cancel();
    super.dispose();
  }

  Map<String, double> get _values {
    final map = widget.control.value as Map? ??
        const {'azim': 0.0, 'elev': 0.0, 'dist': 1.0};
    return {
      'azim': (map['azim'] as num?)?.toDouble() ?? 0.0,
      'elev': (map['elev'] as num?)?.toDouble() ?? 0.0,
      'dist': (map['dist'] as num?)?.toDouble() ?? 1.0,
    };
  }

  void _update(String key, double value, {required bool commit}) {
    final next = {..._values, key: value};
    widget.onChanged(next);
    if (commit) {
      _sendTimer?.cancel();
      _sendTimer = null;
      _lastSentAt = DateTime.now();
      widget.onCommit();
      return;
    }

    final now = DateTime.now();
    final elapsed =
        _lastSentAt != null ? now.difference(_lastSentAt!) : _sendInterval;
    if (_lastSentAt == null || elapsed >= _sendInterval) {
      _lastSentAt = now;
      widget.onCommit();
      _sendTimer?.cancel();
      _sendTimer = null;
      return;
    }

    _sendTimer ??= Timer(_sendInterval - elapsed, () {
      _sendTimer = null;
      _lastSentAt = DateTime.now();
      widget.onCommit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final values = _values;
    const colors = [AppColors.blue500, AppColors.orange500, AppColors.emerald500];

    return _TripleAxisColumn(
      children: [
        for (var i = 0; i < _axes.length; i++)
          _buildAxis(_axes[i], values[_axes[i].key]!, colors[i]),
      ],
    );
  }

  Widget _buildAxis(_AdmAxisSpec spec, double value, Color color) {
    final divisions = spec.step > 0
        ? ((spec.max - spec.min) / spec.step).round()
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AxisValueRow(
          label: spec.label,
          input: _SliderValueInput(
            value: value.clamp(spec.min, spec.max),
            min: spec.min,
            max: spec.max,
            step: spec.step,
            isInteger: false,
            textColor: color,
            compact: true,
            onSubmitted: (v) => _update(spec.key, v, commit: true),
          ),
        ),
        _CompactSlider(
          value: value.clamp(spec.min, spec.max),
          min: spec.min,
          max: spec.max,
          divisions: divisions,
          activeColor: color,
          compact: true,
          onChanged: (v) => _update(spec.key, v, commit: false),
          onChangeEnd: (v) => _update(spec.key, v, commit: true),
        ),
      ],
    );
  }
}

class _AdmAxisSpec {
  const _AdmAxisSpec({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
    required this.step,
  });

  final String key;
  final String label;
  final double min;
  final double max;
  final double step;
}

class StreamLineChart extends StatelessWidget {
  const StreamLineChart({
    super.key,
    required this.data,
    required this.color,
    required this.min,
    required this.max,
    required this.nowMs,
    this.windowMs = 30000,
  });

  /// Visible time span on the scrolling axis (default 30 seconds).
  static const defaultWindowMs = 30000;

  final List<StreamDataPoint> data;
  final Color color;
  final double min;
  final double max;
  final int nowMs;
  final int windowMs;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StreamTimeChartPainter(
        data: data,
        color: color,
        minY: min,
        maxY: max,
        nowMs: nowMs,
        windowMs: windowMs,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _StreamTimeChartPainter extends CustomPainter {
  _StreamTimeChartPainter({
    required this.data,
    required this.color,
    required this.minY,
    required this.maxY,
    required this.nowMs,
    required this.windowMs,
  });

  static const _tickIntervalMs = 5000;

  final List<StreamDataPoint> data;
  final Color color;
  final double minY;
  final double maxY;
  final int nowMs;
  final int windowMs;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final chartHeight = size.height;
    final windowStart = nowMs - windowMs;

    final visible = data
        .where(
          (point) =>
              point.timestamp >= windowStart && point.timestamp <= nowMs,
        )
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final values = visible.map((point) => point.value).toList();
    var plotMin = minY;
    var plotMax = maxY;
    if (values.isNotEmpty) {
      plotMin = values.reduce(math.min);
      plotMax = values.reduce(math.max);
    }
    if ((plotMax - plotMin).abs() < 0.001) {
      plotMin -= 1;
      plotMax += 1;
    } else {
      final padding = (plotMax - plotMin) * 0.1;
      plotMin -= padding;
      plotMax += padding;
    }

    _drawHorizontalGrid(canvas, size.width, chartHeight, plotMin, plotMax);
    _drawTimeAxis(canvas, size, chartHeight, windowStart);

    if (visible.isEmpty) return;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var i = 0; i < visible.length; i++) {
      final point = visible[i];
      final offset = Offset(
        _timeToX(point.timestamp, windowStart, size.width),
        _valueToY(point.value, chartHeight, plotMin, plotMax),
      );

      if (i > 0) {
        final previous = visible[i - 1];
        canvas.drawLine(
          Offset(
            _timeToX(previous.timestamp, windowStart, size.width),
            _valueToY(previous.value, chartHeight, plotMin, plotMax),
          ),
          offset,
          linePaint,
        );
      }

      canvas.drawCircle(offset, 2.5, dotPaint);
    }
  }

  void _drawHorizontalGrid(
    Canvas canvas,
    double width,
    double chartHeight,
    double plotMin,
    double plotMax,
  ) {
    const divisions = 4;
    final gridPaint = Paint()
      ..color = AppColors.gray200.withValues(alpha: 0.85)
      ..strokeWidth = 1;

    for (var i = 0; i <= divisions; i++) {
      final y = chartHeight * i / divisions;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }
  }

  void _drawTimeAxis(
    Canvas canvas,
    Size size,
    double chartHeight,
    int windowStart,
  ) {
    final gridPaint = Paint()
      ..color = AppColors.gray300.withValues(alpha: 0.9)
      ..strokeWidth = 1;

    final nowLinePaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      Paint()
        ..color = AppColors.gray300
        ..strokeWidth = 1,
    );

    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, chartHeight),
      nowLinePaint,
    );

    final firstTick =
        ((windowStart + _tickIntervalMs - 1) ~/ _tickIntervalMs) *
            _tickIntervalMs;

    for (var tick = firstTick; tick <= nowMs; tick += _tickIntervalMs) {
      final x = _timeToX(tick, windowStart, size.width);
      canvas.drawLine(Offset(x, 0), Offset(x, chartHeight), gridPaint);
    }
  }

  double _timeToX(int timestamp, int windowStart, double width) {
    return (timestamp - windowStart) / windowMs * width;
  }

  double _valueToY(
    double value,
    double chartHeight,
    double plotMin,
    double plotMax,
  ) {
    final normalized = (value - plotMin) / math.max(plotMax - plotMin, 0.001);
    return chartHeight * (1 - normalized.clamp(0.0, 1.0));
  }

  @override
  bool shouldRepaint(covariant _StreamTimeChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.nowMs != nowMs ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.windowMs != windowMs ||
        oldDelegate.color != color;
  }
}
