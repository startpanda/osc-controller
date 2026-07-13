import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';
Future<void> showAppAboutDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.gray600),
          const SizedBox(width: 8),
          Text(l10n.about),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.appTitle,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.aboutAuthor,
              style: AppTypography.body.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.gray800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'v1.0.0',
              style: AppTypography.mono.copyWith(color: AppColors.gray500),
            ),
          ],
        ),
      ),
      actions: [
        DialogConfirmButton(
          label: l10n.ok,
          onPressed: () => Navigator.pop(context),
        ),
      ],    ),
  );
}
