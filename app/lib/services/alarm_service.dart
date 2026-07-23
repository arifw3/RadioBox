import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Radio wake-up alarm (Section 7, CLAUDE.md).
///
/// True hands-free audio start from a fully-killed app isn't reliably
/// achievable in Flutter without fragile background-isolate native work
/// (audio_service/just_audio expect a live Flutter engine). Instead this
/// leans on the same mechanism Android's own Clock app uses: a
/// full-screen-intent notification that wakes the device and launches
/// the app, which then immediately starts playing the stored station.
class AlarmService {
  static const _notificationId = 7734;
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    // Without this, tz.local silently defaults to UTC and every alarm
    // fires 3 hours off in Turkey (confirmed on-device: a "07:00" alarm
    // actually registered in AlarmManager for 10:00).
    final deviceTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceTimezone));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String stationName,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _notificationId,
      'Radio Box Alarmı',
      '$stationName çalıyor olacak',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'com.dialwave.alarm',
          'Radyo Alarmı',
          channelDescription: 'Radyo ile uyanma alarmı',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          ongoing: true,
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel() => _plugin.cancel(_notificationId);

  /// True if the app was launched by tapping the alarm notification —
  /// checked once at startup to decide whether to autoplay.
  Future<bool> launchedFromAlarm() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }
}
