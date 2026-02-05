// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart'; // ← Cambia esto

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase
  await SupabaseService.initialize();

  // Configurar UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.darkBlack,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sport Fitness Club',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(), // ← Usa SplashScreen en lugar de LoginScreen
    );
  }
}
