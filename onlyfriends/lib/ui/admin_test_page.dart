import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class AdminTestPage extends StatelessWidget {
  const AdminTestPage({super.key});

  static const String route = '/admin-test';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Admin Test Menu',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                    ? [const Color(0xFF2D2D2D), const Color(0xFF1A1A1A)]
                    : [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.blue.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 32,
                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade600,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Admin Test Menu',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Test various notification types and app features',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Notification Tests Section
            _buildSection(
              context,
              'Notification Tests',
              Icons.notifications,
              [
                _buildTestButton(
                  context,
                  'Test Notification',
                  'Send a basic test notification',
                  Icons.notifications,
                  Colors.orange,
                  () async {
                    await NotificationService().sendTestNotification();
                    _showSnackBar(context, 'Test notification sent!');
                  },
                ),
                _buildTestButton(
                  context,
                  'Quest Notification',
                  'Simulate a new quest notification',
                  Icons.flag,
                  Colors.green,
                  () async {
                    await NotificationService().sendQuestNotification();
                    _showSnackBar(context, 'Quest notification sent!');
                  },
                ),
                _buildTestButton(
                  context,
                  'Friend Quest Upload',
                  'Simulate a friend quest upload',
                  Icons.photo_camera,
                  Colors.blue,
                  () async {
                    await NotificationService().sendFriendQuestUploadNotification();
                    _showSnackBar(context, 'Friend quest upload notification sent!');
                  },
                ),
                _buildTestButton(
                  context,
                  'Friend Request Notification',
                  'Simulate a friend request',
                  Icons.person_add,
                  Colors.purple,
                  () async {
                    await NotificationService().sendFriendRequestNotification();
                    _showSnackBar(context, 'Friend request notification sent!');
                  },
                ),
                _buildTestButton(
                  context,
                  'Delayed Notification',
                  'Send notification in 5 seconds (test background)',
                  Icons.timer,
                  Colors.red,
                  () async {
                    await NotificationService().sendDelayedTestNotification();
                    _showSnackBar(context, 'Delayed notification scheduled for 5 seconds!');
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // App Features Section
            _buildSection(
              context,
              'App Features',
              Icons.settings,
              [
                _buildTestButton(
                  context,
                  'Clear All Notifications',
                  'Remove all pending notifications',
                  Icons.clear_all,
                  Colors.grey,
                  () async {
                    await NotificationService().clearAllNotifications();
                    _showSnackBar(context, 'All notifications cleared!');
                  },
                ),
                _buildTestButton(
                  context,
                  'Clear App Badge',
                  'Remove badge number and all notifications',
                  Icons.badge,
                  Colors.orange,
                  () async {
                    await NotificationService().clearAppBadge();
                    _showSnackBar(context, 'App badge cleared!');
                  },
                ),
                _buildTestButton(
                  context,
                  'Force Clear iOS Badge',
                  'Force clear iOS badge with multiple methods',
                  Icons.badge_outlined,
                  Colors.red,
                  () async {
                    await NotificationService().forceClearIOSBadge();
                    _showSnackBar(context, 'iOS badge force cleared!');
                  },
                ),
                _buildTestButton(
                  context,
                  'NUCLEAR Badge Clear',
                  'Ultimate badge clearing - use as last resort',
                  Icons.warning,
                  Colors.purple,
                  () async {
                    // Multiple nuclear methods
                    await NotificationService().clearAppBadge();
                    await NotificationService().forceClearIOSBadge();
                    await NotificationService().clearAllNotifications();
                    
                    // Additional nuclear option
                    for (int i = 0; i < 50; i++) {
                      await NotificationService().showNotification(
                        id: 5000 + i,
                        title: '',
                        body: '',
                      );
                      await Future.delayed(const Duration(milliseconds: 5));
                      await NotificationService().clearAllNotifications();
                    }
                    
                    _showSnackBar(context, 'NUCLEAR badge clear executed!');
                  },
                ),
                _buildTestButton(
                  context,
                  'Check Permissions',
                  'Verify notification permissions',
                  Icons.security,
                  Colors.amber,
                  () async {
                    await NotificationService().checkPermissions();
                    _showSnackBar(context, 'Permission check completed!');
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Info Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: isDark ? Colors.blue.shade300 : Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Test Instructions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Quest Notification: "Du hast eine neue Quest verfügbar!"\n'
                    '• Friend Quest Upload: "XY hat seine Quest hochgeladen! Schau es dir an."\n'
                    '• Friend Request: "XY hat dir eine Freundschaftsanfrage geschickt!"\n'
                    '• For background test: Tap "Delayed Notification" and close the app',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, IconData icon, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: isDark ? Colors.white : Colors.black87,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildTestButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDark ? Colors.white54 : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
