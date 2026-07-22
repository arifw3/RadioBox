import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/song_history_repository.dart';
import '../state/song_history_providers.dart';
import '../theme/app_theme.dart';
import '../utils/external_search.dart';

class SongHistoryScreen extends ConsumerWidget {
  const SongHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final entries = ref.watch(songHistoryProvider);
    final timeFormat = DateFormat.Hm();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.songHistoryLabel)),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.songHistoryEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  title: Text(
                    entry.songLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${entry.stationName} · ${timeFormat.format(entry.playedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: l10n.songHistorySearchTooltip,
                    onPressed: () => _openSearchSheet(context, l10n, entry),
                  ),
                );
              },
            ),
    );
  }

  void _openSearchSheet(
    BuildContext context,
    AppLocalizations l10n,
    SongHistoryEntry entry,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.podcasts),
              title: Text(l10n.searchOnSpotify),
              onTap: () {
                Navigator.of(context).pop();
                openSpotifySearch(entry.songLabel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.smart_display_outlined),
              title: Text(l10n.searchOnYoutube),
              onTap: () {
                Navigator.of(context).pop();
                openYoutubeSearch(entry.songLabel);
              },
            ),
          ],
        ),
      ),
    );
  }
}
