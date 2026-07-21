import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Above this speed the app assumes the user is driving (Section 6,
/// CLAUDE.md) — chosen to comfortably exclude walking/cycling.
const driveModeSpeedThresholdKmh = 20.0;

/// True once GPS speed crosses the driving threshold. Stays false (never
/// throws) if location permission/service isn't available — Drive Mode
/// then only activates via the manual toggle.
final autoDriveModeProvider = StreamProvider<bool>((ref) async* {
  if (!await _hasLocationAccess()) {
    yield false;
    return;
  }
  await for (final position in Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 5,
    ),
  )) {
    yield (position.speed * 3.6) >= driveModeSpeedThresholdKmh;
  }
});

Future<bool> _hasLocationAccess() async {
  if (!await Geolocator.isLocationServiceEnabled()) return false;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  return permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
}

/// null = follow GPS automatically; true/false = the user overrode it via
/// the manual toggle.
final driveModeManualOverrideProvider = StateProvider<bool?>((ref) => null);

/// The effective on/off state the UI should render.
final driveModeProvider = Provider<bool>((ref) {
  final override = ref.watch(driveModeManualOverrideProvider);
  if (override != null) return override;
  return ref.watch(autoDriveModeProvider).valueOrNull ?? false;
});
