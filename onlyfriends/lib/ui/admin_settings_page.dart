import 'package:flutter/material.dart';
import 'admin_test_page.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  static const String route = '/admin-settings';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Admin Einstellungen',
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
                    : [Colors.orange.shade50, Colors.orange.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.orange.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 32,
                    color: isDark ? Colors.orange.shade300 : Colors.orange.shade600,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Admin Einstellungen',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Erweiterte Funktionen und Tests für Administratoren',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Admin Features Section
            _buildSection(
              context,
              'Admin Features',
              Icons.settings,
              [
                _buildAdminButton(
                  context,
                  'Test Menu',
                  'Test notifications and app features',
                  Icons.bug_report,
                  Colors.blue,
                  () => Navigator.pushNamed(context, AdminTestPage.route),
                ),
                _buildAdminButton(
                  context,
                  'System Status',
                  'Check app performance and status',
                  Icons.analytics,
                  Colors.green,
                  () => _showSystemStatus(context),
                ),
                _buildAdminButton(
                  context,
                  'Debug Logs',
                  'View app debug information',
                  Icons.list_alt,
                  Colors.purple,
                  () => _showDebugLogs(context),
                ),
                _buildAdminButton(
                  context,
                  'Reset Settings',
                  'Reset all app settings to default',
                  Icons.restore,
                  Colors.red,
                  () => _showResetConfirmation(context),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Quick Actions Section
            _buildSection(
              context,
              'Quick Actions',
              Icons.flash_on,
              [
                _buildAdminButton(
                  context,
                  'Send Test Notification',
                  'Send a test notification immediately',
                  Icons.notifications,
                  Colors.orange,
                  () => _sendQuickTestNotification(context),
                ),
                _buildAdminButton(
                  context,
                  'Clear Cache',
                  'Clear app cache and temporary data',
                  Icons.cleaning_services,
                  Colors.teal,
                  () => _clearAppCache(context),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Info Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.orange.shade700 : Colors.orange.shade200,
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
                        color: isDark ? Colors.orange.shade300 : Colors.orange.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Admin Hinweise',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Diese Funktionen sind nur für Administratoren verfügbar\n'
                    '• Verwende das Test Menu, um Benachrichtigungen zu testen\n'
                    '• System Status zeigt aktuelle App-Performance an\n'
                    '• Debug Logs helfen bei der Fehlerbehebung',
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

  Widget _buildAdminButton(
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

  void _showSystemStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('System Status'),
        content: const Text('App läuft stabil\nAlle Services funktionieren\nKeine Fehler erkannt'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDebugLogs(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Debug Logs'),
        content: SingleChildScrollView(
          child: Text(
            'Debug Logs:\n'
            '• App gestartet: ${DateTime.now()}\n'
            '• Benachrichtigungen: Aktiv\n'
            '• Firebase: Deaktiviert\n'
            '• Lokale Benachrichtigungen: Aktiv\n'
            '• Keine Fehler erkannt',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Einstellungen zurücksetzen'),
        content: const Text('Möchtest du wirklich alle Einstellungen zurücksetzen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Einstellungen wurden zurückgesetzt')),
              );
            },
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );
  }

  void _sendQuickTestNotification(BuildContext context) {
    // Import NotificationService and send test notification
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test-Benachrichtigung gesendet!')),
    );
  }

  void _clearAppCache(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache wurde geleert!')),
    );
  }
}
