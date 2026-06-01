import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background processes
  await Firebase.initializeApp();
  debugPrint("Handling background push notification: ${message.messageId}");
  // OS automatically handles drawing the notification tray if it contains a `notification` block
}

class NotificationService extends ChangeNotifier {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Initialize Firebase stack and notification configurations
  Future<void> init(Function(String) onTokenRefresh) async {
    try {
      // 1. Request OS permission (especially vital on iOS & Android 13+)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      debugPrint('User granted notification permissions: ${settings.authorizationStatus}');

      // 2. Fetch unique FCM device registration token
      _fcmToken = await _fcm.getToken();
      debugPrint('FCM Registration Token retrieved: $_fcmToken');
      if (_fcmToken != null) {
        onTokenRefresh(_fcmToken!);
      }

      // 3. Register token refresh listener
      _fcm.onTokenRefresh.listen((token) {
        _fcmToken = token;
        onTokenRefresh(token);
        notifyListeners();
      });

      // 4. Configure local notifications for rich foreground alerts
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
          
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint('Notification clicked by user: ${details.payload}');
        },
      );

      // Create standard high-importance Android channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'water_plant_notifications', // id
        'Water Plant Alerts', // title
        description: 'Instant notification alerts for given and returned water cans.',
        importance: Importance.max,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 5. Register foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground message received: ${message.notification?.title}');
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                importance: Importance.max,
                priority: Priority.high,
                icon: android.smallIcon ?? '@mipmap/ic_launcher',
              ),
            ),
            payload: message.data.toString(),
          );
        }
      });

      // 6. Handle notification click when app launches from terminated state
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App launched via terminated notification click: ${initialMessage.data}');
      }

      // 7. Handle notification click when app is in background but active
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened via background notification click: ${message.data}');
      });

      // 8. Attach background push handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    } catch (e) {
      debugPrint('⚠️ Notification Service Initialization failed. Running in bypass mode: $e');
    }
  }
}
