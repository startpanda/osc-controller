import 'package:flutter/material.dart';



import '../theme/app_theme.dart';



/// Cursor / VS Code style custom title-bar menu (no Material [MenuAnchor]).

class AppMenuBar extends StatelessWidget {

  const AppMenuBar({

    super.key,

    required this.importLabel,

    required this.exportLabel,

    required this.onImportConfig,

    required this.onExportConfig,

    required this.onOpenAdmOsc,

  });



  final String importLabel;

  final String exportLabel;

  final VoidCallback onImportConfig;

  final VoidCallback onExportConfig;

  final VoidCallback onOpenAdmOsc;



  @override

  Widget build(BuildContext context) {

    return Row(

      mainAxisSize: MainAxisSize.min,

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        const _IdeLogo(),

        _IdeFileMenu(

          importLabel: importLabel,

          exportLabel: exportLabel,

          onImportConfig: onImportConfig,

          onExportConfig: onExportConfig,

          onOpenAdmOsc: onOpenAdmOsc,

        ),

      ],

    );

  }

}



class _IdeLogo extends StatelessWidget {

  const _IdeLogo();



  @override

  Widget build(BuildContext context) {

    return const Padding(

      padding: EdgeInsets.only(left: 8, right: 4),

      child: Icon(

        Icons.settings_input_antenna,

        size: 18,

        color: AppColors.blue500,

      ),

    );

  }

}



class _IdeFileMenu extends StatefulWidget {

  const _IdeFileMenu({

    required this.importLabel,

    required this.exportLabel,

    required this.onImportConfig,

    required this.onExportConfig,

    required this.onOpenAdmOsc,

  });



  final String importLabel;

  final String exportLabel;

  final VoidCallback onImportConfig;

  final VoidCallback onExportConfig;

  final VoidCallback onOpenAdmOsc;



  @override

  State<_IdeFileMenu> createState() => _IdeFileMenuState();

}



class _IdeFileMenuState extends State<_IdeFileMenu> {

  final _anchorLink = LayerLink();

  OverlayEntry? _overlayEntry;

  bool _open = false;

  bool _barHovered = false;



  void _toggleMenu() {

    if (_open) {

      _closeMenu();

    } else {

      _openMenu();

    }

  }



  void _openMenu() {

    _overlayEntry = OverlayEntry(

      builder: (context) => _IdeMenuOverlay(

        anchorLink: _anchorLink,

        importLabel: widget.importLabel,

        exportLabel: widget.exportLabel,

        onDismiss: _closeMenu,

        onImportConfig: () {

          _closeMenu();

          widget.onImportConfig();

        },

        onExportConfig: () {

          _closeMenu();

          widget.onExportConfig();

        },

        onOpenAdmOsc: () {

          _closeMenu();

          widget.onOpenAdmOsc();

        },

      ),

    );

    Overlay.of(context).insert(_overlayEntry!);

    setState(() => _open = true);

  }



  void _closeMenu() {

    _overlayEntry?.remove();

    _overlayEntry = null;

    if (mounted) setState(() => _open = false);

  }



  @override

  void dispose() {

    _closeMenu();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    final highlighted = _open || _barHovered;



    return CompositedTransformTarget(

      link: _anchorLink,

      child: MouseRegion(

        onEnter: (_) => setState(() => _barHovered = true),

        onExit: (_) => setState(() => _barHovered = false),

        child: GestureDetector(

          behavior: HitTestBehavior.opaque,

          onTap: _toggleMenu,

          child: Material(

            color: highlighted

                ? IdeMenuColors.barHighlight

                : Colors.transparent,

            borderRadius:

                BorderRadius.circular(IdeMenuMetrics.barItemRadius),

            child: Container(

              alignment: Alignment.center,

              padding: const EdgeInsets.symmetric(horizontal: 8),

              child: Text('File', style: IdeMenuTypography.barItem),

            ),

          ),

        ),

      ),

    );

  }

}



class _IdeMenuOverlay extends StatefulWidget {

  const _IdeMenuOverlay({

    required this.anchorLink,

    required this.importLabel,

    required this.exportLabel,

    required this.onDismiss,

    required this.onImportConfig,

    required this.onExportConfig,

    required this.onOpenAdmOsc,

  });



  final LayerLink anchorLink;

  final String importLabel;

  final String exportLabel;

  final VoidCallback onDismiss;

  final VoidCallback onImportConfig;

  final VoidCallback onExportConfig;

  final VoidCallback onOpenAdmOsc;



  @override

  State<_IdeMenuOverlay> createState() => _IdeMenuOverlayState();

}



class _IdeMenuOverlayState extends State<_IdeMenuOverlay> {
  bool _submenuOpen = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: widget.anchorLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 1),
          child: Material(
            color: Colors.transparent,
            child: MouseRegion(
              onExit: (_) => setState(() => _submenuOpen = false),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IdeMenuPanel(
                    width: IdeMenuMetrics.menuWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _IdeMenuRow(
                          label: widget.importLabel,
                          hasSubmenu: false,
                          onEnter: () => setState(() => _submenuOpen = false),
                          onTap: widget.onImportConfig,
                        ),
                        _IdeMenuRow(
                          label: widget.exportLabel,
                          hasSubmenu: false,
                          onEnter: () => setState(() => _submenuOpen = false),
                          onTap: widget.onExportConfig,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: IdeMenuMetrics.rowPaddingLeft,
                            vertical: 4,
                          ),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: IdeMenuColors.menuBorder,
                          ),
                        ),
                        _IdeMenuRow(
                          label: 'Modules',
                          hasSubmenu: true,
                          forceHighlight: _submenuOpen,
                          onEnter: () => setState(() => _submenuOpen = true),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  if (_submenuOpen)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: IdeMenuMetrics.submenuOverlap,
                        top: IdeMenuMetrics.modulesSubmenuTopOffset,
                      ),
                      child: _IdeMenuPanel(
                        width: IdeMenuMetrics.menuWidth,
                        child: _IdeMenuRow(
                          label: 'ADM OSC',
                          hasSubmenu: false,
                          onEnter: () => setState(() => _submenuOpen = true),
                          onTap: widget.onOpenAdmOsc,
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
  }
}



class _IdeMenuPanel extends StatelessWidget {

  const _IdeMenuPanel({required this.width, required this.child});



  final double width;

  final Widget child;



  @override

  Widget build(BuildContext context) {

    return Container(

      width: width,

      padding: const EdgeInsets.all(IdeMenuMetrics.panelPadding),

      decoration: BoxDecoration(

        color: IdeMenuColors.menuBackground,

        borderRadius: BorderRadius.circular(IdeMenuMetrics.menuRadius),

        border: Border.all(color: IdeMenuColors.menuBorder),

        boxShadow: const [

          BoxShadow(

            color: Color(0x33000000),

            blurRadius: 8,

            offset: Offset(0, 2),

          ),

        ],

      ),

      clipBehavior: Clip.antiAlias,

      child: child,

    );

  }

}



class _IdeMenuRow extends StatefulWidget {

  const _IdeMenuRow({

    required this.label,

    required this.hasSubmenu,

    required this.onEnter,

    required this.onTap,

    this.forceHighlight = false,

  });



  final String label;

  final bool hasSubmenu;

  final bool forceHighlight;

  final VoidCallback onEnter;

  final VoidCallback onTap;



  @override

  State<_IdeMenuRow> createState() => _IdeMenuRowState();

}



class _IdeMenuRowState extends State<_IdeMenuRow> {

  bool _hovered = false;



  bool get _highlighted => widget.forceHighlight || _hovered;



  @override

  Widget build(BuildContext context) {

    return MouseRegion(

      onEnter: (_) {

        setState(() => _hovered = true);

        widget.onEnter();

      },

      onExit: (_) => setState(() => _hovered = false),

      child: GestureDetector(

        behavior: HitTestBehavior.opaque,

        onTap: widget.onTap,

        child: Container(

          height: IdeMenuMetrics.rowHeight,

          padding: const EdgeInsets.only(

            left: IdeMenuMetrics.rowPaddingLeft,

            right: IdeMenuMetrics.rowPaddingRight,

          ),

          decoration: BoxDecoration(

            color: _highlighted

                ? IdeMenuColors.itemSelection

                : Colors.transparent,

            borderRadius:

                BorderRadius.circular(IdeMenuMetrics.itemRadius),

          ),

          child: Row(

            children: [

              Expanded(

                child: Text(

                  widget.label,

                  style: IdeMenuTypography.menuItem.copyWith(

                    color: _highlighted

                        ? IdeMenuColors.itemSelectionText

                        : IdeMenuColors.itemText,

                  ),

                ),

              ),

              if (widget.hasSubmenu)

                Icon(

                  Icons.keyboard_arrow_right,

                  size: 16,

                  color: _highlighted

                      ? IdeMenuColors.itemSelectionText

                      : IdeMenuColors.chevron,

                ),

            ],

          ),

        ),

      ),

    );

  }

}



abstract final class IdeMenuMetrics {
  static const menuWidth = 220.0;
  static const rowHeight = 26.0;
  static const rowPaddingLeft = 12.0;
  static const rowPaddingRight = 8.0;
  static const panelPadding = 4.0;
  static const menuRadius = 8.0;
  static const itemRadius = 6.0;
  static const barItemRadius = 4.0;
  static const dividerBlockHeight = 9.0;

  /// Vertical offset so the Modules submenu aligns with its parent row.
  static const modulesSubmenuTopOffset =
      panelPadding + rowHeight * 2 + dividerBlockHeight;

  /// Slight overlap so the pointer does not leave the menu hit area between panels.
  static const submenuOverlap = 2.0;
}



abstract final class IdeMenuColors {

  static const barBackground = Color(0xFFF3F3F3);

  static const barBorder = Color(0xFFE5E5E5);

  static const barHighlight = Color(0xFFE5E5E5);



  static const menuBackground = Color(0xFFFFFFFF);

  static const menuBorder = Color(0xFFD4D4D4);

  static const itemText = Color(0xFF616161);

  static const itemSelection = Color(0xFF0060C0);

  static const itemSelectionText = Color(0xFFFFFFFF);

  static const chevron = Color(0xFF616161);

}



abstract final class IdeMenuTypography {

  static const barItem = TextStyle(

    fontFamily: 'Segoe UI',

    fontFamilyFallback: ['system-ui', 'sans-serif'],

    fontSize: 13,

    fontWeight: FontWeight.w400,

    height: 1,

    color: Color(0xFF616161),

    letterSpacing: 0,

    decoration: TextDecoration.none,

  );



  static const menuItem = TextStyle(

    fontFamily: 'Segoe UI',

    fontFamilyFallback: ['system-ui', 'sans-serif'],

    fontSize: 13,

    fontWeight: FontWeight.w400,

    height: 1.2,

    letterSpacing: 0,

    decoration: TextDecoration.none,

  );

}

