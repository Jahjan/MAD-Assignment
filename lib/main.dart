import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://spffsuxuhoyaavvkfrsl.supabase.co',
    anonKey: 'sb_publishable_WbvqjH5HReWFRJma1nQLdg_8pugskUb',
  );

  runApp(const VehicleManagementApp());
}

final supabase = Supabase.instance.client;

class VehicleManagementApp extends StatelessWidget {
  const VehicleManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FleetTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1F36),
          brightness: Brightness.dark,
        ),
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1117),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: supabase.auth.currentSession != null
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }
}
