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

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MobileAds.instance.initialize();

  final alarmService = AlarmService();
  await alarmService.init();
  await alarmService.requestPermissions();

  final audioHandler = await AudioService.init(
    builder: DialWaveAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.dialwave.audio',
      androidNotificationChannelName: 'DialWave Playback',
      // Keep the foreground service (and stream) alive on pause — a real
      // radio doesn't stop just because the user swiped the app away.
      // (Must stay false: audio_service asserts androidNotificationOngoing
      // can't be true when this is false.)
      androidStopForegroundOnPause: false,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
        alarmServiceProvider.overrideWithValue(alarmService),
      ],
      child: const DialWaveApp(),
    ),
  );
}
