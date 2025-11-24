import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  static const String route = '/notification-settings';

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _questNotifications = true;
  bool _friendRequestNotifications = true;
  bool _friendQuestUploadNotifications = true;
  bool _allNotifications = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _questNotifications = prefs.getBool('quest_notifications') ?? true;
        _friendRequestNotifications = prefs.getBool('friend_request_notifications') ?? true;
        _friendQuestUploadNotifications = prefs.getBool('friend_quest_upload_notifications') ?? true;
        _allNotifications = prefs.getBool('all_notifications') ?? true;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notification settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('quest_notifications', _questNotifications);
      await prefs.setBool('friend_request_notifications', _friendRequestNotifications);
      await prefs.setBool('friend_quest_upload_notifications', _friendQuestUploadNotifications);
      await prefs.setBool('all_notifications', _allNotifications);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Benachrichtigungseinstellungen gespeichert'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      print('Error saving notification settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Fehler beim Speichern der Einstellungen'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleAllNotifications(bool value) {
    setState(() {
      _allNotifications = value;
      _questNotifications = value;
      _friendRequestNotifications = value;
      _friendQuestUploadNotifications = value;
    });
    _saveNotificationSettings();
  }

  void _toggleQuestNotifications(bool value) {
    setState(() {
      _questNotifications = value;
      _updateAllNotificationsState();
    });
    _saveNotificationSettings();
  }

  void _toggleFriendRequestNotifications(bool value) {
    setState(() {
      _friendRequestNotifications = value;
      _updateAllNotificationsState();
    });
    _saveNotificationSettings();
  }

  void _toggleFriendQuestUploadNotifications(bool value) {
    setState(() {
      _friendQuestUploadNotifications = value;
      _updateAllNotificationsState();
    });
    _saveNotificationSettings();
  }

  void _updateAllNotificationsState() {
    _allNotifications = _questNotifications && 
                      _friendRequestNotifications && 
                      _friendQuestUploadNotifications;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: Text(
            'Benachrichtigungen',
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
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Benachrichtigungen',
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
                    Icons.notifications,
                    size: 32,
                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade600,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Benachrichtigungseinstellungen',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wähle aus, welche Benachrichtigungen du erhalten möchtest',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // All Notifications Toggle
            _buildNotificationSection(
              context,
              'Alle Benachrichtigungen',
              'Alle Benachrichtigungen ein- oder ausschalten',
              Icons.notifications_active,
              _allNotifications,
              _toggleAllNotifications,
              isMainToggle: true,
            ),
            
            const SizedBox(height: 16),
            
            // Individual Notification Settings
            _buildNotificationSection(
              context,
              'Quest-Benachrichtigungen',
              'Du hast eine neue Quest verfügbar!',
              Icons.flag,
              _questNotifications,
              _toggleQuestNotifications,
            ),
            
            _buildNotificationSection(
              context,
              'Freundschaftsanfragen',
              'XY hat dir eine Freundschaftsanfrage geschickt!',
              Icons.person_add,
              _friendRequestNotifications,
              _toggleFriendRequestNotifications,
            ),
            
            _buildNotificationSection(
              context,
              'Freund Quest Uploads',
              'XY hat seine Quest hochgeladen! Schau es dir an.',
              Icons.photo_camera,
              _friendQuestUploadNotifications,
              _toggleFriendQuestUploadNotifications,
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
                        'Hinweise',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Einstellungen werden automatisch gespeichert\n'
                    '• Du kannst jederzeit Änderungen vornehmen\n'
                    '• Benachrichtigungen funktionieren auch im Hintergrund',
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

  Widget _buildNotificationSection(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged, {
    bool isMainToggle = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isMainToggle ? Colors.orange : Colors.blue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isMainToggle ? Colors.orange : Colors.blue,
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
                          fontSize: isMainToggle ? 18 : 16,
                          fontWeight: isMainToggle ? FontWeight.bold : FontWeight.w600,
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
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: isMainToggle ? Colors.orange : Colors.blue,
                  inactiveThumbColor: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
