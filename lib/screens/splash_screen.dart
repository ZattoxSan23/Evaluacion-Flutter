// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../core/theme.dart';
import 'login_screen.dart';
import 'admin/admin_dashboard.dart';
import 'trainer/trainer_dashboard.dart';
import 'client/client_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Esperar un poco para mostrar el splash
    await Future.delayed(const Duration(milliseconds: 500));

    // Verificar si hay sesión activa
    final session = supabase.auth.currentSession;

    if (session == null) {
      // No hay sesión, ir a login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    try {
      // Obtener perfil del usuario
      final profileRes = await supabase
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .single();

      final role = profileRes['role'] as String?;

      Widget nextScreen;
      switch (role?.toLowerCase()) {
        case 'admin':
          nextScreen = const AdminDashboard();
          break;
        case 'trainer':
          nextScreen = const TrainerDashboard();
          break;
        case 'client':
          nextScreen = const ClientDashboard();
          break;
        default:
          // Si no tiene rol, cerrar sesión
          await supabase.auth.signOut();
          nextScreen = const LoginScreen();
          break;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    } catch (e) {
      // Error al obtener perfil, ir a login
      debugPrint('Error obteniendo perfil: $e');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SPORT FITNESS CLUB',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryOrange,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: AppTheme.primaryOrange,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Cargando...',
              style: TextStyle(
                color: AppTheme.lightGrey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
