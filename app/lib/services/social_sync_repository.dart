import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// The Realtime Database instance lives in europe-west1, created after
/// firebase_options.dart was generated, so FirebaseDatabase.instance (which
/// assumes the legacy us-central1 default URL) would point at the wrong
/// place. Pinning the URL explicitly avoids that mismatch.
const _databaseUrl =
    'https://dialwave-radio-2026-default-rtdb.europe-west1.firebasedatabase.app';

/// "Birlikte Dinle" (Section 8, CLAUDE.md) — a "room" is just a shared
/// pointer to a station ID plus a set of present listener IDs. Radio is
/// already a live broadcast, so listening to the same station *is* the
/// sync; there's no per-listener playback position to reconcile.
class SocialSyncRepository {
  SocialSyncRepository()
      : _db = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: _databaseUrl,
        );

  final FirebaseDatabase _db;

  DatabaseReference _room(String roomId) => _db.ref('rooms/$roomId');

  /// Creates a room and returns its short shareable code.
  Future<String> createRoom(String stationId) async {
    final roomId = _generateRoomCode();
    await _room(roomId).set({
      'stationId': stationId,
      'createdAt': ServerValue.timestamp,
    });
    return roomId;
  }

  Stream<String?> watchRoomStation(String roomId) {
    return _room(roomId)
        .child('stationId')
        .onValue
        .map((event) => event.snapshot.value as String?);
  }

  Future<void> joinRoom(String roomId, String listenerId) async {
    final ref = _room(roomId).child('listeners').child(listenerId);
    await ref.set(true);
    unawaited(ref.onDisconnect().remove());
  }

  Future<void> leaveRoom(String roomId, String listenerId) {
    return _room(roomId).child('listeners').child(listenerId).remove();
  }

  Stream<int> watchListenerCount(String roomId) {
    return _room(roomId)
        .child('listeners')
        .onValue
        .map((event) => event.snapshot.children.length);
  }

  Future<void> sendReaction(String roomId, String emoji) {
    return _room(roomId).child('reactions').push().set({
      'emoji': emoji,
      'at': ServerValue.timestamp,
    });
  }

  Stream<String> watchReactions(String roomId) {
    return _room(roomId).child('reactions').limitToLast(1).onChildAdded.map(
          (event) =>
              (event.snapshot.value as Map)['emoji'] as String? ?? '',
        );
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1 confusion
    final rand = Random.secure();
    return List.generate(5, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
