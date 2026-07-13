import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../locale/locale_service.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

Future<void> showSettingsDialog(BuildContext context) {
  final localeService = LocaleScope.of(context);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return ListenableBuilder(
        listenable: localeService,
        builder: (context, _) {
          final current = AppLocalizations.of(dialogContext);
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.settings, size: 20, color: AppColors.gray600),
                const SizedBox(width: 8),
                Text(current.settings),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.language,
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<Locale>(
                    value: const Locale('zh'),
                    groupValue: localeService.locale,
                    title: Text(current.chinese),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      if (value != null) localeService.setLocale(value);
                    },
                  ),
                  RadioListTile<Locale>(
                    value: const Locale('en'),
                    groupValue: localeService.locale,
                    title: Text(current.english),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      if (value != null) localeService.setLocale(value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              DialogConfirmButton(
                label: current.ok,
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          );
        },
      );
    },
  );
}
