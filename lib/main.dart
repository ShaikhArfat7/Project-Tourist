import 'package:flutter/material.dart';
import 'core/services/firebase_user_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  await FirebaseUserService().initializeFirebase();
  runApp(const TouristSafetyApp());
}

// ── App Root ──────────────────────────────────────────────
class TouristSafetyApp extends StatelessWidget {
  const TouristSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tourist Safety Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const HomeScreen(),
    );
  }
}
