import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../state/player_providers.dart';
import '../state/social_sync_providers.dart';

const _quickEmojis = ['🔥', '❤️', '🎶', '😂', '👏'];

/// "Birlikte Dinle" panel (Section 8, CLAUDE.md) — lives on the Now
/// Playing screen: create/join a room, see the live listener count, and
/// send quick emoji reactions.
class SocialSyncPanel extends ConsumerWidget {
  const SocialSyncPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final roomId = ref.watch(currentRoomIdProvider);
    ref.watch(roomStationSyncProvider); // side effect only, value unused

    if (roomId == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.group_add),
            label: const Text('Oda Oluştur'),
            onPressed: () => _createRoom(ref),
          ),
          TextButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Odaya Katıl'),
            onPressed: () => _joinRoomDialog(context, ref),
          ),
        ],
      );
    }

    final listenerCount = ref.watch(listenerCountProvider).valueOrNull ?? 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Şu an seninle birlikte $listenerCount kişi dinliyor',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Oda: $roomId',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: l10n.socialShareLabel,
              onPressed: () => Share.share(
                'RadioBox\'ta benimle dinle! Oda kodu: $roomId',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: l10n.socialLeaveLabel,
              onPressed: () => _leaveRoom(ref, roomId),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final emoji in _quickEmojis)
              IconButton(
                onPressed: () => ref
                    .read(socialSyncRepositoryProvider)
                    .sendReaction(roomId, emoji),
                icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                tooltip: emoji,
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _createRoom(WidgetRef ref) async {
    final station = ref.read(audioHandlerProvider).currentStation;
    if (station == null) return;

    final repo = ref.read(socialSyncRepositoryProvider);
    final roomId = await repo.createRoom(station.id);
    await repo.joinRoom(roomId, ref.read(listenerIdProvider));

    ref.read(isRoomHostProvider.notifier).state = true;
    ref.read(currentRoomIdProvider.notifier).state = roomId;
  }

  Future<void> _joinRoomDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odaya Katıl'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Oda kodu'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim().toUpperCase()),
            child: const Text('Katıl'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;

    await ref
        .read(socialSyncRepositoryProvider)
        .joinRoom(code, ref.read(listenerIdProvider));

    ref.read(isRoomHostProvider.notifier).state = false;
    ref.read(currentRoomIdProvider.notifier).state = code;
  }

  Future<void> _leaveRoom(WidgetRef ref, String roomId) async {
    await ref
        .read(socialSyncRepositoryProvider)
        .leaveRoom(roomId, ref.read(listenerIdProvider));
    ref.read(currentRoomIdProvider.notifier).state = null;
    ref.read(isRoomHostProvider.notifier).state = false;
  }
}
