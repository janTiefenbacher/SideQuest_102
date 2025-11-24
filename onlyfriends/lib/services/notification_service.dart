import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    try {
      // Initialize local notifications only (Firebase disabled for now)
      await _initializeLocalNotifications();
      
      // Request permission for notifications
      await _requestPermission();
      
      print('Notification service initialized successfully (local notifications only)');
    } catch (e) {
      print('Notification service initialization failed: $e');
    }
  }

  Future<void> _requestPermission() async {
    // Request permission for local notifications
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      
      print('Local notification permissions requested');
    } catch (e) {
      print('Error requesting notification permissions: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Create notification channel for Android
    await _createNotificationChannel();
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'onlyfriends_channel',
      'SideQuest Notifications',
      description: 'Notifications for SideQuest app',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Handle notification tap - could navigate to specific screen
  }

  // Firebase methods removed - using local notifications only

  // Show local notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'onlyfriends_channel',
      'SideQuest Notifications',
      channelDescription: 'Notifications for SideQuest app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
      interruptionLevel: InterruptionLevel.active,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Send notification to specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // For now, just show local notification as fallback
      // In a real app, you would send this via FCM or Supabase Edge Function
      await showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        payload: data?.toString(),
      );
    } catch (e) {
      print('Error sending notification to user: $e');
    }
  }

  Future<void> _sendFCMMessage({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // This would typically be done via a Supabase Edge Function
    // For now, we'll use local notifications as a fallback
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      payload: data?.toString(),
    );
  }

  // Notification for new quest
  Future<void> notifyNewQuest(String questTitle) async {
    await showNotification(
      id: 1,
      title: '🎯 Du hast eine neue Quest verfügbar!',
      body: 'Eine neue Quest wartet auf dich: $questTitle',
      payload: 'quest',
    );
  }

  // Notification for friend quest upload
  Future<void> notifyFriendQuestUpload(String friendName) async {
    await showNotification(
      id: 2,
      title: '📸 $friendName hat seine Quest hochgeladen!',
      body: 'Schau es dir an.',
      payload: 'quest_upload',
    );
  }

  // Notification for friend request
  Future<void> notifyFriendRequest(String requesterName) async {
    await showNotification(
      id: 3,
      title: '👋 $requesterName hat dir eine Freundschaftsanfrage geschickt!',
      body: 'Antworte auf die Freundschaftsanfrage',
      payload: 'friend_request',
    );
  }

  // Test notification to verify the system works
  Future<void> sendTestNotification() async {
    await showNotification(
      id: 999,
      title: '🔔 Test-Benachrichtigung',
      body: 'Benachrichtigungen funktionieren! SideQuest ist bereit.',
      payload: 'test',
    );
  }

  // Send different types of test notifications
  Future<void> sendQuestNotification() async {
    await showNotification(
      id: 1001,
      title: '🎯 Du hast eine neue Quest verfügbar!',
      body: 'Eine neue Quest wartet auf dich: "Trinke 2 Liter Wasser heute"',
      payload: 'quest',
    );
  }

  Future<void> sendFriendQuestUploadNotification() async {
    await showNotification(
      id: 1002,
      title: '📸 Max hat seine Quest hochgeladen!',
      body: 'Schau es dir an.',
      payload: 'quest_upload',
    );
  }

  Future<void> sendFriendRequestNotification() async {
    await showNotification(
      id: 1003,
      title: '👋 Anna hat dir eine Freundschaftsanfrage geschickt!',
      body: 'Antworte auf die Freundschaftsanfrage',
      payload: 'friend_request',
    );
  }

  // Schedule a notification that will show even when app is in background
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'onlyfriends_channel',
      'SideQuest Notifications',
      channelDescription: 'Notifications for SideQuest app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
      interruptionLevel: InterruptionLevel.active,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Test notification that will show in 5 seconds (to test background notifications)
  Future<void> sendDelayedTestNotification() async {
    final scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    await scheduleNotification(
      id: 2000,
      title: '⏰ Verzögerte Test-Benachrichtigung',
      body: 'Diese Benachrichtigung wurde 5 Sekunden verzögert gesendet!',
      scheduledDate: scheduledDate,
      payload: 'delayed_test',
    );
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
    print('All notifications cleared');
  }

  // Clear app badge (iOS) and all notifications
  Future<void> clearAppBadge() async {
    try {
      print('Starting badge clear process...');
      
      // Step 1: Clear all existing notifications
      await _localNotifications.cancelAll();
      print('All notifications cancelled');
      
      // Step 2: Request badge permissions
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      print('Badge permissions requested');
      
      // Step 3: Multiple attempts to clear badge
      for (int i = 0; i < 3; i++) {
        print('Badge clear attempt ${i + 1}/3');
        
        // Create notification with badge 0
        const iosDetails = DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
          badgeNumber: 0,
        );
        
        const androidDetails = AndroidNotificationDetails(
          'onlyfriends_channel',
          'SideQuest Notifications',
          channelDescription: 'Notifications for SideQuest app',
          importance: Importance.low,
          priority: Priority.low,
          showWhen: false,
          enableVibration: false,
          playSound: false,
          silent: true,
        );
        
        const notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );
        
        // Show notification with badge 0
        await _localNotifications.show(
          9999 - i, // Use different IDs
          '',
          '',
          notificationDetails,
        );
        
        // Wait a bit
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Cancel the notification
        await _localNotifications.cancel(9999 - i);
        
        // Wait before next attempt
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Step 4: Final cleanup - cancel all again
      await _localNotifications.cancelAll();
      
      print('Badge clear process completed');
    } catch (e) {
      print('Error clearing app badge: $e');
    }
  }

  // Force clear iOS badge - alternative method
  Future<void> forceClearIOSBadge() async {
    try {
      print('Starting FORCE iOS badge clear...');
      
      // Method 1: Cancel everything first
      await _localNotifications.cancelAll();
      print('All notifications cancelled');
      
      // Method 2: Request permissions again
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      print('Permissions re-requested');
      
      // Method 3: Multiple badge 0 notifications with different approaches
      for (int attempt = 0; attempt < 5; attempt++) {
        print('Force clear attempt ${attempt + 1}/5');
        
        // Approach A: Silent notification with badge 0
        const iosDetailsA = DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
          badgeNumber: 0,
        );
        
        await _localNotifications.show(
          9000 + attempt,
          '',
          '',
          NotificationDetails(iOS: iosDetailsA),
        );
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Approach B: Notification with badge 0 and alert
        const iosDetailsB = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: false,
          badgeNumber: 0,
        );
        
        await _localNotifications.show(
          8000 + attempt,
          'Badge Clear',
          'Clearing badge...',
          NotificationDetails(iOS: iosDetailsB),
        );
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Cancel both
        await _localNotifications.cancel(9000 + attempt);
        await _localNotifications.cancel(8000 + attempt);
        
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      // Method 4: Final nuclear option - show and immediately cancel
      for (int i = 0; i < 10; i++) {
        const iosDetails = DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
          badgeNumber: 0,
        );
        
        await _localNotifications.show(
          7000 + i,
          '',
          '',
          NotificationDetails(iOS: iosDetails),
        );
        
        await Future.delayed(const Duration(milliseconds: 50));
        await _localNotifications.cancel(7000 + i);
      }
      
      // Method 5: Cancel everything one more time
      await _localNotifications.cancelAll();
      
      print('FORCE iOS badge clear completed');
    } catch (e) {
      print('Error force clearing iOS badge: $e');
    }
  }

  // Check notification permissions
  Future<void> checkPermissions() async {
    try {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final granted = await androidPlugin.areNotificationsEnabled();
        print('Android notifications enabled: $granted');
      }
      
      print('Permission check completed');
    } catch (e) {
      print('Error checking permissions: $e');
    }
  }
}

// Firebase handlers removed - using local notifications only
