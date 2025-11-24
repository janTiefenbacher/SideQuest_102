import 'package:flutter/material.dart';
import 'dart:async';
import '../services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _clearBadgeOnSplash();
    // Navigate to main app after 2 seconds
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    });
  }

  Future<void> _clearBadgeOnSplash() async {
    try {
      // Clear badge immediately on splash screen
      await NotificationService().clearAppBadge();
      print('Badge cleared on splash screen');
    } catch (e) {
      print('Error clearing badge on splash: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4), // Light gray background
      body: Center(
        child: Image.asset(
          'Logo_OnlyFriends.png',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
