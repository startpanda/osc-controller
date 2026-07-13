import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.trailingMinWidth,
  });

  final String title;
  final Widget? trailing;
  final double? trailingMinWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.gray100)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showTrailing = trailing != null &&
              (trailingMinWidth == null ||
                  constraints.maxWidth >=
                      AppLayoutMetrics.headerMinTitleWidth +
                          trailingMinWidth!);

          return Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.sectionTitle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (showTrailing) trailing!,
            ],
          );
        },
      ),
    );
  }
}

class PressableButton extends StatefulWidget {
  const PressableButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.borderRadius = 6,
    this.backgroundColor = AppColors.blue500,
    this.hoverBackgroundColor = AppColors.blue600,
    this.pressedBackgroundColor,
    this.foregroundColor = AppColors.white,
    this.borderColor,
    this.hoverBorderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.width,
    this.height,
    this.enabled = true,
  });

  final VoidCallback onPressed;
  final Widget child;
  final double borderRadius;
  final Color backgroundColor;
  final Color hoverBackgroundColor;
  final Color? pressedBackgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final EdgeInsets padding;
  final double? width;
  final double? height;
  final bool enabled;

  @override
  State<PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<PressableButton> {
  bool _hovered = false;
  bool _pressed = false;

  Color get _backgroundColor {
    if (!widget.enabled) return AppColors.gray300;
    if (_pressed) {
      return widget.pressedBackgroundColor ?? widget.hoverBackgroundColor;
    }
    if (_hovered) return widget.hoverBackgroundColor;
    return widget.backgroundColor;
  }

  Color? get _borderColor {
    if (!widget.enabled) return AppColors.gray300;
    if (_hovered || _pressed) return widget.hoverBorderColor ?? widget.borderColor;
    return widget.borderColor;
  }

  double get _scale {
    if (!widget.enabled) return 1;
    if (_pressed) return 0.96;
    if (_hovered) return 1.02;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final hasBorder = _borderColor != null;

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (widget.enabled) setState(() => _hovered = true);
      },
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            width: widget.width,
            height: widget.height,
            padding: widget.padding,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: hasBorder ? Border.all(color: _borderColor!) : null,
              boxShadow: _hovered && widget.enabled
                  ? [
                      BoxShadow(
                        color: _backgroundColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: DefaultTextStyle(
              style: TextStyle(color: widget.foregroundColor),
              child: IconTheme(
                data: IconThemeData(color: widget.foregroundColor),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
    this.height,
    this.borderRadius = 6,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool compact;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return PressableButton(
      onPressed: onPressed,
      height: height,
      borderRadius: borderRadius,
      padding: height != null
          ? EdgeInsets.symmetric(horizontal: compact ? 10 : 12)
          : EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 6 : 8,
            ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.red500 : AppColors.gray600;
    final hoverBg = danger ? AppColors.red50 : AppColors.gray50;
    final pressedBg = danger ? AppColors.red200 : AppColors.gray100;
    final hoverBorder = danger ? AppColors.red200 : AppColors.gray300;

    return PressableButton(
      onPressed: onPressed,
      backgroundColor: AppColors.surface,
      hoverBackgroundColor: hoverBg,
      pressedBackgroundColor: pressedBg,
      foregroundColor: fg,
      borderColor: danger ? AppColors.red200 : AppColors.gray200,
      hoverBorderColor: hoverBorder,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14),
            const SizedBox(width: 4),
          ],
          Text(label, style: AppTypography.bodySmall.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Dialog cancel: white fill, blue border — standard dialog button size.
class DialogCancelButton extends StatelessWidget {
  const DialogCancelButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  static const _radius = 6.0;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue600,
        backgroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.blue500),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      child: Text(label),
    );
  }
}

/// Dialog confirm: blue fill — standard dialog button size.
class DialogConfirmButton extends StatelessWidget {
  const DialogConfirmButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  static const _radius = 6.0;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blue500,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      child: Text(label),
    );
  }
}

class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = AppColors.emerald500,
    this.width = 36,
    this.height = 20,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: value ? activeColor : AppColors.gray200,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 100),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: height - 4,
            height: height - 4,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CardPanel extends StatelessWidget {
  const CardPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray200),
      ),
      child: child,
    );
  }
}

abstract final class AppLayoutMetrics {
  static const sidebarWidth = 280.0;

  /// Minimum window client size enforced by the native Windows shell.
  static const minWindowWidth = 440.0;
  static const minWindowHeight = 280.0;

  static const headerMinTitleWidth = 24.0;
  static const admChannelPickerCompactWidth = 76.0;

  /// Sidebar width that shrinks on narrow windows so the main pane keeps room.
  static double sidebarWidthFor(double totalWidth) {
    const minSidebar = 160.0;
    const minMain = 240.0;
    return (totalWidth - minMain).clamp(minSidebar, sidebarWidth);
  }

  static double measureTextWidth(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width.ceilToDouble();
  }

  static double outlineButtonWidth(BuildContext context, String label) {
    return 20 +
        14 +
        4 +
        measureTextWidth(context, label, AppTypography.bodySmall);
  }

  static double primaryButtonCompactWidth(
    BuildContext context,
    String label, {
    bool withIcon = true,
  }) {
    const iconWidth = 12.0;
    const iconGap = 4.0;
    const horizontalPadding = 20.0;
    final textWidth = measureTextWidth(
      context,
      label,
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
    return horizontalPadding +
        (withIcon ? iconWidth + iconGap : 0) +
        textWidth;
  }
}

abstract final class ControlGridLayout {
  /// Fixed control card size — does not change when the window is resized.
  static const cardWidth = 156.0;
  static const cardHeight = 144.0;
  static const spacing = 8.0;

  /// How many fixed-width cards fit on one row (for grid delegates).
  static int crossAxisCount(double maxWidth) {
    if (maxWidth <= 0) return 1;
    final count =
        ((maxWidth + spacing) / (cardWidth + spacing)).floor();
    return count.clamp(1, 999);
  }

  static SliverGridDelegateWithFixedCrossAxisCount delegate(int count) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: count,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      mainAxisExtent: cardHeight,
    );
  }

  /// Fixed-size tile for sender/receiver control grids.
  static Widget tile({required Widget child}) {
    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: child,
    );
  }
}

String formatTime(DateTime time, {bool withMs = false}) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  final s = time.second.toString().padLeft(2, '0');
  if (!withMs) return '$h:$m:$s';
  final ms = time.millisecond.toString().padLeft(3, '0');
  return '$h:$m:$s.$ms';
}
