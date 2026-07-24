import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/dialwave_audio_handler.dart';
import 'state/player_providers.dart';

Future<void> main() async {
  // runZonedGuarded + the two error-handler wires below is Firebase's own
  // recommended pattern for catching *everything* — sync Flutter errors,
  // async errors outside the Flutter framework, and now they're actually
  // sent somewhere instead of being an invisible blind spot.
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // These were previously sequential awaits — Firebase and AdMob have no
    // dependency on each other, so running them concurrently (and
    // audio_service alongside them) is most of the real-device first-launch
    // latency fix.
    final audioHandlerFuture = AudioService.init(
      builder: DialWaveAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.dialwave.audio',
        androidNotificationChannelName: 'Radio Box Playback',
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
    ]);
    final audioHandler = await audioHandlerFuture;

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    runApp(
      ProviderScope(
        overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
        child: const RadioBoxApp(),
      ),
    );
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}
