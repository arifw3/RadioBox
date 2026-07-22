import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/alarm_service.dart';
import 'services/dialwave_audio_handler.dart';
import 'state/alarm_providers.dart';
import 'state/player_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final alarmService = AlarmService();

  // These were previously sequential awaits — Firebase, AdMob, and the
  // notification-permission timezone setup have no dependency on each
  // other, so running them concurrently (and audio_service alongside
  // them) is most of the real-device first-launch latency fix.
  final audioHandlerFuture = AudioService.init(
    builder: DialWaveAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.dialwave.audio',
      androidNotificationChannelName: 'RadioBox Playback',
      // Keep the foreground service (and stream) alive on pause — a real
      // radio doesn't stop just because the user swiped the app away.
      // (Must stay false: audio_service asserts androidNotificationOngoing
      // can't be true when this is false.)
      androidStopForegroundOnPause: false,
    ),
  );
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    MobileAds.instance.initialize(),
    alarmService.init(),
  ]);
  final audioHandler = await audioHandlerFuture;

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
        alarmServiceProvider.overrideWithValue(alarmService),
      ],
      child: const RadioBoxApp(),
    ),
  );

  // The notification-permission system dialog would otherwise block the
  // very first frame from ever showing — ask for it only once the UI is
  // already on screen.
  unawaited(alarmService.requestPermissions());
}
