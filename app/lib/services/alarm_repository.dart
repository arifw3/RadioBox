import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AlarmSettings {
  const AlarmSettings({
    required this.hour,
    required this.minute,
    required this.stationId,
    required this.stationName,
  });

  final int hour;
  final int minute;
  final String stationId;
  final String stationName;

  Map<String, dynamic> toJson() => {
        'hour': hour,
        'minute': minute,
        'stationId': stationId,
        'stationName': stationName,
      };

  factory AlarmSettings.fromJson(Map<String, dynamic> json) => AlarmSettings(
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        stationId: json['stationId'] as String,
        stationName: json['stationName'] as String,
      );
}

class AlarmRepository {
  static const _prefsKey = 'radio_alarm_settings';

  Future<AlarmSettings?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    return AlarmSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(AlarmSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(settings.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
