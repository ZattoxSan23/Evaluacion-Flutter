import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:front/screens/client/client_dashboard.dart';
import 'package:front/screens/trainer/trainer_dashboard.dart';
import 'package:front/screens/admin/admin_dashboard.dart';
import '../core/supabase_client.dart';
import '../core/theme.dart';
import '../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _showPass = false;
  bool _forgotPass = false;

  Future<void> _login() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa email y contraseña')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null)
        throw Exception('No se obtuvo usuario después del login');

      final profileRes = await supabase
          .from('profiles')
          .select('role, full_name')
          .eq('id', user.id)
          .single();

      final role = profileRes['role'] as String?;
      final fullName = profileRes['full_name'] as String? ?? 'Usuario';

      if (role == null) throw Exception('No se encontró rol para este usuario');

      String welcomeMsg = '¡Bienvenido, $fullName!';
      Widget? nextScreen;

      switch (role.toLowerCase()) {
        case 'admin':
          welcomeMsg = '¡Bienvenido, Administrador!';
          nextScreen = const AdminDashboard();
          break;
        case 'trainer':
          welcomeMsg = '¡Bienvenido, Entrenador!';
          nextScreen = const TrainerDashboard();
          break;
        case 'client':
          welcomeMsg = '¡Bienvenido!';
          nextScreen = const ClientDashboard();
          break;
        default:
          throw Exception('Rol desconocido: $role');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(welcomeMsg),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => nextScreen!),
        );
      }
    } on AuthException catch (e) {
      String msg = e.message;
      if (e.message.contains('Invalid login credentials')) {
        msg = 'Credenciales inválidas (email o contraseña incorrectos)';
      } else if (e.message.contains('not confirmed')) {
        msg = 'Email no confirmado';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim().toLowerCase();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu correo')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.sportfitnessclub://reset-password',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enlace de recuperación enviado a tu correo'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _forgotPass = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al enviar enlace: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final isMediumScreen = size.width < 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkBlack,
              Color(0xFF111111),
              AppTheme.darkBlack,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 20 : 28,
              vertical: 30,
            ),
            child: Column(
              children: [
                // ESPACIO SUPERIOR
                SizedBox(height: isSmallScreen ? 20 : 40),

                // TÍTULO PRINCIPAL CON EFECTO DEGRADADO
                Container(
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 16 : 24),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [
                          AppTheme.primaryOrange,
                          AppTheme.orangeAccent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: Text(
                      'SPORT FITNESS CLUB',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 34 : 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: isSmallScreen ? 1.5 : 2.5,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // SUBTÍTULO
                Container(
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 24 : 32),
                  child: Text(
                    'Tu progreso, nuestro compromiso',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 15 : 19,
                      color: AppTheme.lightGrey.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // LOGO CON EFECTO DE BRILLO
                Container(
                  width: isSmallScreen ? 180 : 240,
                  height: isSmallScreen ? 180 : 240,
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 30 : 50),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Container(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBlack.withOpacity(0.7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryOrange.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Image.asset(
                        'icon/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryOrange.withOpacity(0.1),
                                  AppTheme.orangeAccent.withOpacity(0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.fitness_center,
                                size: isSmallScreen ? 80 : 100,
                                color: AppTheme.primaryOrange.withOpacity(0.5),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // FORMULARIO CON DISEÑO MODERNO
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 22 : 34),
                  decoration: BoxDecoration(
                    color: AppTheme.darkGrey.withAlpha(230),
                    borderRadius:
                        BorderRadius.circular(isSmallScreen ? 24 : 32),
                    border: Border.all(
                      color: AppTheme.primaryOrange.withAlpha(80),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(180),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: AppTheme.primaryOrange.withAlpha(40),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // TÍTULO DEL FORMULARIO
                      Container(
                        margin:
                            EdgeInsets.only(bottom: isSmallScreen ? 28 : 44),
                        child: Column(
                          children: [
                            Text(
                              _forgotPass
                                  ? 'RECUPERAR CONTRASEÑA'
                                  : 'INICIAR SESIÓN',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 24 : 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Container(
                              width: 80,
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryOrange,
                                    AppTheme.orangeAccent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // CAMPO EMAIL
                      Container(
                        margin:
                            EdgeInsets.only(bottom: isSmallScreen ? 20 : 24),
                        child: TextField(
                          controller: _emailCtrl,
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico',
                            labelStyle: TextStyle(
                              color: AppTheme.lightGrey.withOpacity(0.8),
                              fontSize: isSmallScreen ? 15 : 16,
                            ),
                            prefixIcon: Container(
                              margin: EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                              child: Icon(
                                Icons.email_outlined,
                                color: AppTheme.primaryOrange,
                                size: isSmallScreen ? 20 : 22,
                              ),
                            ),
                            filled: true,
                            fillColor: AppTheme.darkBlack.withOpacity(0.9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppTheme.darkGrey,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppTheme.primaryOrange,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: isSmallScreen ? 18 : 20,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 16 : 17,
                          ),
                        ),
                      ),

                      // CAMPO CONTRASEÑA (solo en login normal)
                      if (!_forgotPass) ...[
                        Container(
                          margin:
                              EdgeInsets.only(bottom: isSmallScreen ? 16 : 20),
                          child: TextField(
                            controller: _passwordCtrl,
                            obscureText: !_showPass,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              labelStyle: TextStyle(
                                color: AppTheme.lightGrey.withOpacity(0.8),
                                fontSize: isSmallScreen ? 15 : 16,
                              ),
                              prefixIcon: Container(
                                margin: EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primaryOrange.withOpacity(0.1),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                                child: Icon(
                                  Icons.lock_outline,
                                  color: AppTheme.primaryOrange,
                                  size: isSmallScreen ? 20 : 22,
                                ),
                              ),
                              suffixIcon: Container(
                                margin: EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _showPass
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppTheme.orangeAccent,
                                    size: isSmallScreen ? 20 : 22,
                                  ),
                                  onPressed: () =>
                                      setState(() => _showPass = !_showPass),
                                ),
                              ),
                              filled: true,
                              fillColor: AppTheme.darkBlack.withOpacity(0.9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppTheme.darkGrey,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppTheme.primaryOrange,
                                  width: 2,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: isSmallScreen ? 18 : 20,
                              ),
                            ),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 16 : 17,
                            ),
                          ),
                        ),

                        // OPCIÓN OLVIDÉ CONTRASEÑA
                        Container(
                          margin:
                              EdgeInsets.only(bottom: isSmallScreen ? 24 : 32),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => setState(() => _forgotPass = true),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: AppTheme.orangeAccent.withOpacity(0.1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.help_outline,
                                      size: isSmallScreen ? 16 : 18,
                                      color: AppTheme.orangeAccent,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      '¿Olvidaste tu contraseña?',
                                      style: TextStyle(
                                        color: AppTheme.orangeAccent,
                                        fontSize: isSmallScreen ? 14 : 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // BOTÓN PRINCIPAL
                      Container(
                        margin:
                            EdgeInsets.only(bottom: isSmallScreen ? 20 : 24),
                        height:
                            isSmallScreen ? 56 : 60, // Altura del contenedor
                        child: GradientButton(
                          text: _forgotPass
                              ? 'ENVIAR ENLACE DE RECUPERACIÓN'
                              : (_loading ? 'CARGANDO...' : 'INGRESAR'),
                          onPressed: _forgotPass ? _resetPassword : _login,
                          isLoading: _loading,
                          gradientColors: [
                            AppTheme.primaryOrange,
                            AppTheme.orangeAccent,
                            Color(0xFFFF8A00),
                          ],
                        ),
                      ),

                      // VOLVER AL LOGIN (solo en recuperación)
                      if (_forgotPass) ...[
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        Center(
                          child: GestureDetector(
                            onTap: () => setState(() => _forgotPass = false),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.lightGrey.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_back_rounded,
                                    size: isSmallScreen ? 16 : 18,
                                    color: AppTheme.lightGrey,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Volver al inicio de sesión',
                                    style: TextStyle(
                                      color: AppTheme.lightGrey,
                                      fontSize: isSmallScreen ? 14 : 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // PIE DE PÁGINA
                SizedBox(height: isSmallScreen ? 30 : 40),
                Text(
                  '© 2026 Sport Fitness Club. Todos los derechos reservados.',
                  style: TextStyle(
                    color: AppTheme.lightGrey.withOpacity(0.6),
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isSmallScreen ? 20 : 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
