import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../locale/locale_service.dart';
import '../services/app_config_scope.dart';
import '../services/config_file_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/osc_receiver.dart';
import '../widgets/osc_sender.dart';
import '../widgets/about_dialog.dart';
import '../widgets/app_menu_bar.dart';
import '../widgets/settings_dialog.dart';

enum AppTab { sender, receiver }

abstract final class _AppShellMetrics {
  static const headerHeight = 32.0;
  static const tabBarHeight = 34.0;
  static const statusBarHeight = 24.0;
  static const minBodyHeight = 4.0;

  static bool showTabBar(double maxHeight) {
    return maxHeight >= headerHeight + tabBarHeight + minBodyHeight;
  }

  static bool showStatusBar(double maxHeight) {
    return maxHeight >=
        headerHeight + tabBarHeight + statusBarHeight + minBodyHeight;
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _activeTab = AppTab.sender;
  final _senderKey = GlobalKey<OscSenderState>();
  final _receiverKey = GlobalKey<OscReceiverState>();
  bool _tabHydrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabHydrated) return;
    _tabHydrated = true;
    final activeTab = AppConfigScope.of(context).config.activeTab;
    if (activeTab == 'receiver') {
      setState(() => _activeTab = AppTab.receiver);
    }
  }

  void _setActiveTab(AppTab tab) {
    setState(() => _activeTab = tab);
    AppConfigScope.of(context).updateActiveTab(
      tab == AppTab.receiver ? 'receiver' : 'sender',
    );
  }

  Future<void> _exportConfig() async {
    final l10n = AppLocalizations.of(context);
    _senderKey.currentState?.persistConfig();
    _receiverKey.currentState?.persistConfig();
    final store = AppConfigScope.of(context);
    await store.flush();

    try {
      final exported = await ConfigFileService.exportConfig(
        store.config,
        dialogTitle: l10n.exportConfig,
      );
      if (!mounted || !exported) return;
      _showNotice(l10n.exportConfigSuccess);
    } on Object {
      if (!mounted) return;
      _showNotice(l10n.exportConfigFailed);
    }
  }

  Future<void> _importConfig() async {
    final l10n = AppLocalizations.of(context);
    try {
      final config = await ConfigFileService.importConfig(
        dialogTitle: l10n.importConfig,
      );
      if (!mounted) return;

      final store = AppConfigScope.of(context);
      store.replaceConfig(config);
      LocaleScope.of(context).syncLocaleCode(config.localeCode);

      _senderKey.currentState?.applyConfig(config.sender);
      await _receiverKey.currentState?.applyConfig(config.receiver);

      if (!mounted) return;
      setState(() {
        _activeTab =
            config.activeTab == 'receiver' ? AppTab.receiver : AppTab.sender;
      });
      _showNotice(l10n.importConfigSuccess);
    } on ConfigImportException catch (error) {
      if (error.message == 'cancelled' || !mounted) return;
      _showNotice(l10n.importConfigInvalid);
    } on Object {
      if (!mounted) return;
      _showNotice(l10n.importConfigInvalid);
    }
  }

  void _showNotice(String message) {
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final showTabBar = _AppShellMetrics.showTabBar(height);
          final showStatusBar = _AppShellMetrics.showStatusBar(height);
          return Column(
            children: [
              SizedBox(
                height: _AppShellMetrics.headerHeight,
                child: _AppHeader(
                  importLabel: l10n.importConfig,
                  exportLabel: l10n.exportConfig,
                  onImportConfig: _importConfig,
                  onExportConfig: _exportConfig,
                  onOpenSettings: () => showSettingsDialog(context),
                  onOpenAbout: () => showAppAboutDialog(context),
                  onOpenAdmOsc: () {
                    _senderKey.currentState?.addAdmOscControls();
                    _setActiveTab(AppTab.sender);
                  },
                ),
              ),
              if (showTabBar)
                _TabBar(
                  activeTab: _activeTab,
                  senderLabel: l10n.sender,
                  receiverLabel: l10n.receiver,
                  onChanged: _setActiveTab,
                ),
              Expanded(
                child: IndexedStack(
                  index: _activeTab.index,
                  sizing: StackFit.expand,
                  children: [
                    OscSender(key: _senderKey),
                    OscReceiver(key: _receiverKey),
                  ],
                ),
              ),
              if (showStatusBar)
                _StatusBar(
                  readyLabel: l10n.ready,
                  subtitle: l10n.openSoundControl,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    required this.importLabel,
    required this.exportLabel,
    required this.onImportConfig,
    required this.onExportConfig,
    required this.onOpenSettings,
    required this.onOpenAbout,
    required this.onOpenAdmOsc,
  });

  final String importLabel;
  final String exportLabel;
  final VoidCallback onImportConfig;
  final VoidCallback onExportConfig;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenAdmOsc;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: IdeMenuColors.barBackground,
        border: Border(bottom: BorderSide(color: IdeMenuColors.barBorder)),
      ),
      padding: const EdgeInsets.only(left: 2, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppMenuBar(
            importLabel: importLabel,
            exportLabel: exportLabel,
            onImportConfig: onImportConfig,
            onExportConfig: onExportConfig,
            onOpenAdmOsc: onOpenAdmOsc,
          ),
          const Spacer(),
          _IdeHeaderIconButton(
            icon: Icons.info_outline,
            tooltip: l10n.about,
            onPressed: onOpenAbout,
          ),
          _IdeHeaderIconButton(
            icon: Icons.settings_outlined,
            tooltip: l10n.settings,
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class _IdeHeaderIconButton extends StatefulWidget {
  const _IdeHeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_IdeHeaderIconButton> createState() => _IdeHeaderIconButtonState();
}

class _IdeHeaderIconButtonState extends State<_IdeHeaderIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered ? IdeMenuColors.barHighlight : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: IdeMenuColors.itemText,
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.activeTab,
    required this.senderLabel,
    required this.receiverLabel,
    required this.onChanged,
  });

  final AppTab activeTab;
  final String senderLabel;
  final String receiverLabel;
  final ValueChanged<AppTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: _AppShellMetrics.tabBarHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.gray200)),
      ),
      padding: const EdgeInsets.only(left: 8, right: 8),
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.hardEdge,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TabItem(
              label: senderLabel,
              icon: Icons.settings_input_antenna,
              active: activeTab == AppTab.sender,
              onTap: () => onChanged(AppTab.sender),
            ),
            _TabItem(
              label: receiverLabel,
              icon: Icons.waves,
              active: activeTab == AppTab.receiver,
              onTap: () => onChanged(AppTab.receiver),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.blue500 : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? AppColors.blue600 : AppColors.gray500,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.blue600 : AppColors.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.readyLabel,
    required this.subtitle,
  });

  final String readyLabel;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      color: AppColors.blue500,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: AppColors.white),
                const SizedBox(width: 6),
                Text(
                  readyLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.blue200,
                      fontFamily: 'Consolas',
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _StatusBadge(label: 'UDP'),
                const SizedBox(width: 8),
                const _StatusBadge(label: 'WebSocket'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.blue400.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.white,
          fontFamily: 'Consolas',
        ),
      ),
    );
  }
}
