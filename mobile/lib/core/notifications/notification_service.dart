import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  NotificationService._init();

  static const String channelHighPriorityId = 'bus_alarm_high_priority';
  static const String channelHighPriorityName = 'Bus Arrival Alarms';
  
  static const String channelInfoId = 'bus_alarm_service_info';
  static const String channelInfoName = 'Tracking and Expiry Updates';

  Future<void> initialize({Function(String?)? onNotificationResponse}) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (onNotificationResponse != null) {
          onNotificationResponse(response.payload);
        }
      },
    );

    // Create High-Priority Alarm Channel
    const androidHighChannel = AndroidNotificationChannel(
      channelHighPriorityId,
      channelHighPriorityName,
      description: 'Persistent alarm notifications when your bus approaches a stop',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
    );

    // Create Info Channel
    const androidInfoChannel = AndroidNotificationChannel(
      channelInfoId,
      channelInfoName,
      description: 'Background status and pre-expiry alerts',
      importance: Importance.low,
    );

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(androidHighChannel);
      await androidImplementation.createNotificationChannel(androidInfoChannel);
      await androidImplementation.requestNotificationsPermission();
    }
  }

  Future<void> showAlarmNotification({
    required int id,
    required String stopName,
    required double distanceMeters,
    String? alertId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelHighPriorityId,
      channelHighPriorityName,
      channelDescription: 'Persistent alarm notifications when your bus approaches a stop',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      actions: const [
        AndroidNotificationAction('dismiss_action', 'Dismiss', cancelNotification: true),
        AndroidNotificationAction('snooze_action', 'Snooze 1 min', cancelNotification: true),
      ],
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id,
      'Approaching Stop: $stopName',
      'The college bus is ${distanceMeters.toStringAsFixed(0)} meters away.',
      notificationDetails,
      payload: alertId,
    );
  }

  Future<void> showExpiryWarning({
    required int id,
    required String linkNickname,
    required int hoursRemaining,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelInfoId,
      channelInfoName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id,
      'Link Expiring Soon',
      'Tracking link "$linkNickname" expires in approximately $hoursRemaining hours. Please update it.',
      notificationDetails,
    );
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }
}
