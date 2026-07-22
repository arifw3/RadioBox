import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/locale_providers.dart';

const _supported = [
  (code: 'tr', label: 'Türkçe'),
  (code: 'en', label: 'English'),
];

/// Opens the language picker sheet — called from the AppBar overflow menu.
/// Coverage note: only the most visible screens are localized so far
/// (home, search); some deeper sheets still show Turkish text regardless
/// of the selected language.
Future<void> openLanguageSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(localeProvider)?.languageCode;
  await showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              AppLocalizations.of(context)!.languageLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          for (final option in _supported)
            ListTile(
              title: Text(option.label),
              trailing: current == option.code
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                ref
                    .read(localeProvider.notifier)
                    .setLocale(Locale(option.code));
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    ),
  );
}
