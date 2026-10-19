import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String highRiskChannelId = 'high_risk_channel';
  static const String mediumRiskChannelId = 'medium_risk_channel';

  /// Value notifier that broadcasts clicked notification payloads to the UI (e.g., 'high_risk')
  static final ValueNotifier<String?> onNotificationPayload = ValueNotifier<String?>(null);

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
          onNotificationPayload.value = response.payload;
        },
      );

      // Create Android Notification Channels with Sound & Vibration
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // High Risk Channel (Max Importance, Sound, Urgent Vibration)
        final highRiskVibration = Int64List.fromList([0, 500, 250, 500, 250, 500]);
        await androidImplementation.createNotificationChannel(
          AndroidNotificationChannel(
            highRiskChannelId,
            'High-Risk Emergency Alerts',
            description: 'Urgent audible alerts when entering high crime or hazard zones.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            vibrationPattern: highRiskVibration,
          ),
        );

        // Medium Risk Channel (High Importance, Sound, Alert Vibration)
        final mediumRiskVibration = Int64List.fromList([0, 350, 200, 350]);
        await androidImplementation.createNotificationChannel(
          AndroidNotificationChannel(
            mediumRiskChannelId,
            'Caution & Advisory Alerts',
            description: 'Audible advisory notifications when entering moderate risk zones.',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            vibrationPattern: mediumRiskVibration,
          ),
        );
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Asks user for notification permission on Android 13+ & iOS.
  Future<bool?> requestPermissions() async {
    try {
      await initialize();
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pref_notification_permission_requested', true);
        return granted;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return null;
  }

  /// Plays urgent in-app audible system sound and triggers repeated heavy haptic pulses,
  /// then posts the high-risk notification with sound and vibration pattern.
  Future<void> triggerHighRiskSensoryFeedback({
    String? title,
    String? body,
    String? payload,
  }) async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 160), () => HapticFeedback.heavyImpact());
      Future.delayed(const Duration(milliseconds: 320), () => HapticFeedback.heavyImpact());
      Future.delayed(const Duration(milliseconds: 480), () => HapticFeedback.vibrate());
    } catch (e) {
      debugPrint('Error triggering sensory alert: $e');
    }

    if (title != null && body != null) {
      await showHighRiskNotification(
        title: title,
        body: body,
        payload: payload ?? 'high_risk',
      );
    }
  }

  /// Triggers a high-priority notification with loud sound and urgent vibration pattern.
  Future<void> showHighRiskNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await initialize();
      final highRiskVibration = Int64List.fromList([0, 500, 250, 500, 250, 500]);
      final androidDetails = AndroidNotificationDetails(
        highRiskChannelId,
        'High-Risk Emergency Alerts',
        channelDescription: 'Urgent audible alerts when entering high crime or hazard zones.',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: highRiskVibration,
        color: const Color(0xFFDC2626),
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _notificationsPlugin.show(
        id: 1001,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload ?? 'high_risk',
      );
    } catch (e) {
      debugPrint('Error triggering high risk notification: $e');
    }
  }

  /// Triggers a caution notification with sound and advisory vibration.
  Future<void> showMediumRiskNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await initialize();
      final mediumRiskVibration = Int64List.fromList([0, 350, 200, 350]);
      final androidDetails = AndroidNotificationDetails(
        mediumRiskChannelId,
        'Caution & Advisory Alerts',
        channelDescription: 'Audible advisory notifications when entering moderate risk zones.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: mediumRiskVibration,
        color: const Color(0xFFD97706),
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _notificationsPlugin.show(
        id: 1002,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload ?? 'medium_risk',
      );
    } catch (e) {
      debugPrint('Error triggering medium risk notification: $e');
    }
  }
}
