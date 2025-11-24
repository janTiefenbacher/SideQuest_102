import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'theme.dart';
import 'ui/app_theme.dart';
import 'ui/home_page.dart';
import 'ui/login_page.dart';
import 'ui/register_page.dart';
import 'ui/quest_selection_page.dart';
import 'ui/splash_screen.dart';
import 'ui/admin_test_page.dart';
import 'ui/admin_settings_page.dart';
import 'ui/notification_settings_page.dart';
import 'services/notification_service.dart';

const String supabaseUrl = 'https://adcutkrypgdtlaqaxvqo.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFkY3V0a3J5cGdkdGxhcWF4dnFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2ODY0NzAsImV4cCI6MjA3MzI2MjQ3MH0.rNZdeby6C4yScBE-_elUdBDcpSkAc-r7lsH3NSfs_HU';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Skip Firebase initialization for now - using local notifications only
  // Firebase can be enabled later with proper configuration
  print('Using local notifications only - Firebase disabled');
  
  // Initialize timezone for scheduled notifications
  tz.initializeTimeZones();
  
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await AppTheme.init();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Immediately clear any existing badges
  await NotificationService().clearAppBadge();
  
  // Request camera and location permissions on app start
  await _requestPermissions();
  
  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  try {
    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permission denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('Location permission permanently denied');
      return;
    }
    
    print('Location permission granted');
  } catch (e) {
    // Permission request failed, but app can still run
    print('Permission request failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'SideQuest',
          debugShowCheckedModeBanner: false,
          theme: buildSideQuestTheme(),
          darkTheme: buildSideQuestDarkTheme(),
          themeMode: mode,
          routes: {
            '/': (_) => const SplashScreen(),
            '/auth': (_) => const AuthGate(),
            LoginPage.route: (_) => const LoginPage(),
            RegisterPage.route: (_) => const RegisterPage(),
            HomePage.route: (_) => const HomePage(),
            QuestSelectionPage.route: (_) => const QuestSelectionPage(),
            AdminTestPage.route: (_) => const AdminTestPage(),
            AdminSettingsPage.route: (_) => const AdminSettingsPage(),
            NotificationSettingsPage.route: (_) => const NotificationSettingsPage(),
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}
