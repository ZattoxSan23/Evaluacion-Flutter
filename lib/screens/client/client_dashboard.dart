// lib/screens/client/client_dashboard.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../screens/login_screen.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../widgets/gradient_button.dart';

// Importaciones de pantallas detalladas
import 'body_measurements_view.dart';
import 'nutrition_plan_view.dart';
import 'routine_detail_screen.dart';

// Añadir este import para el visor de imágenes
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _clientData;
  List<Map<String, dynamic>> _measurements = [];
  List<Map<String, dynamic>> _routines = [];
  List<Map<String, dynamic>> _nutritionPlans = [];
  List<Map<String, dynamic>> _evaluations = [];
  List<Map<String, dynamic>> _advertisements = [];

  bool _isLoading = true;
  bool _requestLoading = false;
  bool _isLoadingAds = false;

  @override
  void initState() {
    super.initState();
    _loadClientData();
    _loadAdvertisements();
  }

  Future<void> _loadClientData() async {
    setState(() => _isLoading = true);

    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw Exception('No autenticado');

      // 1. Datos del perfil
      final profileRes =
          await supabase.from('profiles').select().eq('id', uid).single();

      // 2. Datos del cliente
      final clientRes = await supabase
          .from('clients')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      // Obtener datos del entrenador
      Map<String, dynamic>? trainerData;
      if (clientRes != null && clientRes['trainer_id'] != null) {
        final trainerRes = await supabase
            .from('profiles')
            .select('full_name, email')
            .eq('id', clientRes['trainer_id'])
            .maybeSingle();

        if (trainerRes != null) {
          trainerData = trainerRes;
        }
      }

      // 3. Historial de medidas
      final measuresRes = clientRes != null
          ? await supabase
              .from('body_measurements')
              .select()
              .eq('client_id', clientRes['id'])
              .order('measurement_date', ascending: false)
              .limit(10)
          : [];

      // 4. Rutinas activas
      final routinesRes = clientRes != null
          ? await supabase
              .from('routines')
              .select('*')
              .eq('client_id', clientRes['id'])
              .eq('status', 'active')
              .order('created_at', ascending: false)
          : [];

      // 5. Planes nutricionales
      final nutritionRes = clientRes != null
          ? await supabase
              .from('nutrition_plans')
              .select('*')
              .eq('client_id', clientRes['id'])
              .eq('status', 'active')
              .order('created_at', ascending: false)
          : [];

      // 6. Evaluaciones recientes
      final evaluationsRes = clientRes != null
          ? await supabase
              .from('evaluation_requests')
              .select('''
          *,
          profiles!evaluation_requests_current_trainer_id_fkey(
            full_name,
            email
          ) as trainer_details
        ''')
              .eq('client_id', clientRes['id'])
              .order('request_date', ascending: false)
              .limit(5)
          : [];

      if (mounted) {
        setState(() {
          _profile = profileRes;
          _clientData = clientRes;

          // Añadir datos del entrenador si existen
          if (trainerData != null && _clientData != null) {
            _clientData = {..._clientData!, 'trainer': trainerData};
          }

          _measurements = List.from(measuresRes);
          _routines = List.from(routinesRes);
          _nutritionPlans = List.from(nutritionRes);
          _evaluations = List.from(evaluationsRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos cliente: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAdvertisements() async {
    setState(() => _isLoadingAds = true);
    try {
      final response = await supabase
          .from('advertisements')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(5);

      setState(() {
        _advertisements = List<Map<String, dynamic>>.from(response);
        _isLoadingAds = false;
      });
    } catch (e) {
      debugPrint('Error cargando publicidad: $e');
      setState(() => _isLoadingAds = false);
    }
  }

  // ========== FUNCIÓN PARA EXPANDIR IMAGEN ==========
  void _showImageZoom(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppTheme.darkBlack.withOpacity(0.95),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encabezado con título y botón de cerrar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkGrey,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Contenedor de la imagen con PhotoView
              Container(
                height: MediaQuery.of(context).size.height * 0.7,
                width: double.infinity,
                child: PhotoView(
                  imageProvider: NetworkImage(imageUrl),
                  backgroundDecoration: BoxDecoration(
                    color: Colors.transparent,
                  ),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3.0,
                  initialScale: PhotoViewComputedScale.contained,
                  heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
                  loadingBuilder: (context, event) => Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 50),
                        const SizedBox(height: 10),
                        const Text(
                          'Error al cargar la imagen',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Controles de zoom
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkGrey,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.zoom_in, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Pellizca para hacer zoom',
                      style: TextStyle(
                        color: AppTheme.lightGrey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== NAVEGACIONES ==========
  void _navigateToMeasurements() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientBodyMeasurementsScreen(),
      ),
    );
  }

  void _navigateToNutritionPlan() {
    if (_nutritionPlans.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NutritionPlanViewScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes un plan nutricional activo'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _navigateToRoutineDetail(Map<String, dynamic> routine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineDetailScreen(
          routineId: routine['id'],
          routine: routine,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getEvaluationStatus() async {
    try {
      final clientId = _clientData?['id'];
      if (clientId == null) {
        return {'can_request': false, 'days_left': 0, 'last_evaluation': null};
      }

      final response = await supabase.rpc(
        'can_request_evaluation',
        params: {'client_uuid': clientId},
      );

      return {
        'can_request': response['can_request'] ?? false,
        'days_left': response['days_left'] ?? 0,
        'last_evaluation': response['last_evaluation'] != null
            ? DateTime.parse(response['last_evaluation'])
            : null,
      };
    } catch (e) {
      debugPrint('Error obteniendo estado de evaluación: $e');
      return _calculateEvaluationStatusFallback();
    }
  }

  Future<Map<String, dynamic>> _calculateEvaluationStatusFallback() async {
    try {
      final clientId = _clientData?['id'];
      if (clientId == null) return {'can_request': false, 'days_left': 0};

      final recentEvaluation = await supabase
          .from('evaluation_requests')
          .select('request_date')
          .eq('client_id', clientId)
          .inFilter('status', ['accepted', 'pending'])
          .order('request_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (recentEvaluation == null) {
        return {'can_request': true, 'days_left': 0};
      }

      final lastDate = DateTime.parse(recentEvaluation['request_date']);
      final daysSince = DateTime.now().difference(lastDate).inDays;
      final daysLeft = 60 - daysSince;

      return {
        'can_request': daysLeft <= 0,
        'days_left': daysLeft > 0 ? daysLeft : 0,
        'last_evaluation': lastDate,
      };
    } catch (e) {
      return {'can_request': false, 'days_left': 0};
    }
  }

  Future<void> _requestEvaluation() async {
    setState(() => _requestLoading = true);

    try {
      final clientId = _clientData?['id'];
      if (clientId == null) throw Exception('Cliente no encontrado');

      final status = await _getEvaluationStatus();
      if (!status['can_request']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Debes esperar ${status['days_left']} días para solicitar una nueva evaluación.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      await supabase
          .from('evaluation_requests')
          .insert({
            'client_id': clientId,
            'current_trainer_id': _clientData?['trainer_id'],
            'purpose': 'evaluation',
            'status': 'pending',
            'notes': 'Solicitud de evaluación física',
            'request_date': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud de evaluación enviada correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadClientData();
    } catch (e) {
      debugPrint('Error al solicitar evaluación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al solicitar evaluación: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _requestLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Cerrar sesión?'),
          content: const Text('¿Estás seguro de que quieres salir?'),
          backgroundColor: AppTheme.darkGrey,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);
      await supabase.auth.signOut();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // ========== WIDGETS DE DISEÑO PRO ==========

  Widget _buildWelcomeCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado principal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        color: Colors.blue[300],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: isMobile ? 4 : 6),
                    Text(
                      _profile?['full_name'] ?? 'Cliente',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(isMobile ? 10 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.2),
                      Colors.blue.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.account_circle,
                  color: Colors.blue[400],
                  size: isMobile ? 32 : 40,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : 24),

          // Divisor
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
          SizedBox(height: isMobile ? 20 : 24),

          // Información principal
          Row(
            children: [
              Expanded(
                child: _buildWelcomeInfoItem(
                  icon: Icons.mail_outline,
                  label: 'Email',
                  value: _profile?['email'] ?? 'Sin email',
                  isMobile: isMobile,
                ),
              ),
              SizedBox(width: isMobile ? 16 : 20),
              Expanded(
                child: _buildWelcomeInfoItem(
                  icon: Icons.person_4_outlined,
                  label: 'Entrenador',
                  value: _clientData?['trainer']?['full_name'] ?? 'Sin asignar',
                  isMobile: isMobile,
                ),
              ),
            ],
          ),

          if (_clientData?['membership_type'] != null) ...[
            SizedBox(height: isMobile ? 16 : 20),
            _buildWelcomeInfoItem(
              icon: Icons.card_giftcard,
              label: 'Plan',
              value: (_clientData?['membership_type'] as String).toUpperCase(),
              isMobile: isMobile,
              isFullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWelcomeInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isMobile,
    bool isFullWidth = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: isMobile ? 16 : 18,
              color: Colors.blue[300],
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 6 : 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: isMobile ? 18 : 22),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.lightGrey,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                    SizedBox(height: isMobile ? 4 : 6),
                    Text(
                      value,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 18 : 22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationButton(bool isMobile) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getEvaluationStatus(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {'can_request': false, 'days_left': 0};
        final canRequest = data['can_request'];
        final daysLeft = data['days_left'];
        final lastEvaluation = data['last_evaluation'];

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: canRequest
                  ? [
                      Colors.deepOrange.withOpacity(0.3),
                      AppTheme.primaryOrange.withOpacity(0.2),
                    ]
                  : [
                      Colors.grey.withOpacity(0.3),
                      Colors.grey.withOpacity(0.2),
                    ],
            ),
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            border: Border.all(
              color: canRequest
                  ? AppTheme.primaryOrange.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // REMOVÍ LOS PARÁMETROS borderRadius y height QUE NO EXISTEN EN GradientButton
              GradientButton(
                text: _requestLoading
                    ? 'SOLICITANDO...'
                    : (canRequest
                        ? 'SOLICITAR EVALUACIÓN'
                        : 'EVALUACIÓN BLOQUEADA'),
                onPressed:
                    _requestLoading || !canRequest ? null : _requestEvaluation,
                isLoading: _requestLoading,
                gradientColors: canRequest
                    ? [AppTheme.primaryOrange, Colors.deepOrange]
                    : [Colors.grey, Colors.grey.shade700],
              ),
              if (daysLeft > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer,
                              color: Colors.orange, size: isMobile ? 14 : 16),
                          SizedBox(width: 6),
                          Text(
                            'Disponible en $daysLeft días',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (lastEvaluation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Última evaluación: ${DateFormat('dd/MM/yyyy').format(lastEvaluation)}',
                            style: TextStyle(
                              color: AppTheme.lightGrey,
                              fontSize: isMobile ? 11 : 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduledEvaluations(bool isMobile) {
    final scheduledEvaluations = _evaluations
        .where((e) => e['status'] == 'accepted' && e['scheduled_date'] != null)
        .toList();

    if (scheduledEvaluations.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
          child: Row(
            children: [
              Icon(Icons.event_available,
                  color: Colors.green, size: isMobile ? 20 : 24),
              SizedBox(width: isMobile ? 8 : 12),
              Text(
                'EVALUACIONES PROGRAMADAS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 16 : 18,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: scheduledEvaluations.length,
          itemBuilder: (context, index) {
            final evaluation = scheduledEvaluations[index];
            final scheduledDate = DateTime.parse(evaluation['scheduled_date']);
            final dateStr = DateFormat('dd/MM/yyyy').format(scheduledDate);
            final timeStr = DateFormat('HH:mm').format(scheduledDate);
            final location = evaluation['location'] ?? 'Gimnasio Principal';
            final trainerNotes = evaluation['trainer_notes'];

            return Container(
              margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.withOpacity(0.15),
                    Colors.green.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 14 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isMobile ? 8 : 10),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.calendar_today,
                              color: Colors.green, size: isMobile ? 18 : 20),
                        ),
                        SizedBox(width: isMobile ? 12 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Evaluación Programada',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 16 : 18,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time,
                                      color: Colors.green,
                                      size: isMobile ? 14 : 16),
                                  SizedBox(width: 4),
                                  Text(
                                    '$dateStr a las $timeStr',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: isMobile ? 12 : 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 10 : 12,
                            vertical: isMobile ? 4 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'CONFIRMADA',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: isMobile ? 10 : 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    if (location.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: isMobile ? 6 : 8),
                        child: Row(
                          children: [
                            Icon(Icons.location_on,
                                color: Colors.blue, size: isMobile ? 16 : 18),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(
                                  color: Colors.blue.withOpacity(0.9),
                                  fontSize: isMobile ? 13 : 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (trainerNotes != null && trainerNotes.isNotEmpty)
                      Container(
                        padding: EdgeInsets.all(isMobile ? 10 : 12),
                        decoration: BoxDecoration(
                          color: Colors.yellow.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.note,
                                color: Colors.yellow, size: isMobile ? 16 : 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                trainerNotes,
                                style: TextStyle(
                                  color: Colors.yellow.withOpacity(0.9),
                                  fontSize: isMobile ? 12 : 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        SizedBox(height: isMobile ? 20 : 24),
      ],
    );
  }

  Widget _buildAdvertisementsSection(bool isMobile) {
    if (_advertisements.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
          child: Row(
            children: [
              Icon(Icons.campaign,
                  color: Colors.purple, size: isMobile ? 20 : 24),
              SizedBox(width: isMobile ? 8 : 12),
              Text(
                'OFERTAS ESPECIALES',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 16 : 18,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _advertisements.length,
          itemBuilder: (context, index) {
            final ad = _advertisements[index];
            return Container(
              margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purple.withOpacity(0.15),
                    Colors.deepPurple.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.local_offer,
                              color: Colors.purple, size: isMobile ? 18 : 20),
                        ),
                        SizedBox(width: isMobile ? 12 : 16),
                        Expanded(
                          child: Text(
                            ad['title'],
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 17 : 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    if (ad['image_url'] != null) ...[
                      // Widget de imagen clickeable con zoom
                      GestureDetector(
                        onTap: () {
                          _showImageZoom(ad['image_url'], ad['title']);
                        },
                        child: Stack(
                          children: [
                            Container(
                              height: isMobile ? 160 : 220,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(isMobile ? 12 : 16),
                                image: DecorationImage(
                                  image: NetworkImage(ad['image_url']),
                                  fit: BoxFit.cover,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CachedNetworkImage(
                                imageUrl: ad['image_url'],
                                imageBuilder: (context, imageProvider) =>
                                    Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                        isMobile ? 12 : 16),
                                    image: DecorationImage(
                                      image: imageProvider,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryOrange,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                        isMobile ? 12 : 16),
                                    color: AppTheme.darkGrey,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error,
                                            color: Colors.red, size: 40),
                                        SizedBox(height: 8),
                                        Text(
                                          'Error al cargar imagen',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Overlay con indicador de zoom
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: isMobile ? 20 : 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isMobile ? 12 : 16),
                    ],
                    Text(
                      ad['content'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isMobile ? 14 : 16,
                        height: 1.5,
                      ),
                    ),
                    if (ad['price'] != null) ...[
                      SizedBox(height: isMobile ? 12 : 16),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 20,
                          vertical: isMobile ? 10 : 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withOpacity(0.2),
                              Colors.greenAccent.withOpacity(0.1),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(isMobile ? 12 : 16),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PRECIO ESPECIAL',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 13 : 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'S/. ${double.parse(ad['price'].toString()).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 18 : 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        SizedBox(height: isMobile ? 16 : 24),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    required bool isMobile,
    VoidCallback? onSeeAll,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 8 : 10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: isMobile ? 20 : 24),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 18 : 20,
                      ),
                    ),
                  ],
                ),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    child: Text(
                      'VER TODO',
                      style: TextStyle(
                        color: AppTheme.primaryOrange,
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 20),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        title: Text(
          'MI PANEL DE CONTROL',
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.darkBlack,
                AppTheme.darkBlack.withOpacity(0.9),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: isMobile ? 22 : 26),
            onPressed: () {
              _loadClientData();
              _loadAdvertisements();
            },
            tooltip: 'Refrescar',
          ),
          IconButton(
            icon: Icon(Icons.logout, size: isMobile ? 22 : 26),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppTheme.primaryOrange,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Cargando tu panel...',
                    style: TextStyle(
                      color: AppTheme.lightGrey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadClientData();
                await _loadAdvertisements();
              },
              color: AppTheme.primaryOrange,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 20,
                    vertical: isMobile ? 12 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tarjeta de bienvenida
                      _buildWelcomeCard(isMobile),
                      SizedBox(height: isMobile ? 20 : 28),

                      // Botón de evaluación
                      _buildEvaluationButton(isMobile),
                      SizedBox(height: isMobile ? 20 : 28),

                      // Evaluaciones programadas
                      if (_evaluations.isNotEmpty) ...[
                        _buildScheduledEvaluations(isMobile),
                      ],

                      // Métricas rápidas
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isMobile ? 2 : 4,
                        childAspectRatio: isMobile ? 1.6 : 1.9,
                        mainAxisSpacing: isMobile ? 12 : 16,
                        crossAxisSpacing: isMobile ? 12 : 16,
                        children: [
                          _buildMetricCard(
                            'Medidas registradas',
                            _measurements.length.toString(),
                            Icons.scale,
                            Colors.green,
                            isMobile,
                          ),
                          _buildMetricCard(
                            'Rutinas activas',
                            _routines.length.toString(),
                            Icons.fitness_center,
                            Colors.blue,
                            isMobile,
                          ),
                          _buildMetricCard(
                            'Planes nutricionales',
                            _nutritionPlans.length.toString(),
                            Icons.restaurant,
                            Colors.orange,
                            isMobile,
                          ),
                          _buildMetricCard(
                            'Evaluaciones',
                            _evaluations.length.toString(),
                            Icons.assignment,
                            Colors.purple,
                            isMobile,
                          ),
                        ],
                      ),
                      SizedBox(height: isMobile ? 24 : 32),

                      // Sección de anuncios
                      if (_advertisements.isNotEmpty) ...[
                        _buildAdvertisementsSection(isMobile),
                      ],

                      // Últimas medidas
                      if (_measurements.isNotEmpty)
                        _buildSectionCard(
                          title: 'ÚLTIMAS MEDIDAS',
                          icon: Icons.timeline,
                          color: Colors.green,
                          isMobile: isMobile,
                          onSeeAll: _navigateToMeasurements,
                          children: _measurements
                              .take(isMobile ? 2 : 3)
                              .map((measurement) {
                            final date = DateFormat('dd/MM/yyyy').format(
                              DateTime.parse(measurement['measurement_date'])
                                  .toLocal(),
                            );
                            return Container(
                              margin:
                                  EdgeInsets.only(bottom: isMobile ? 10 : 12),
                              padding: EdgeInsets.all(isMobile ? 12 : 16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(isMobile ? 12 : 16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(isMobile ? 8 : 10),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.scale,
                                        color: Colors.green,
                                        size: isMobile ? 18 : 20),
                                  ),
                                  SizedBox(width: isMobile ? 12 : 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${measurement['weight']?.toStringAsFixed(1)} kg',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isMobile ? 16 : 18,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Altura: ${measurement['height']?.toStringAsFixed(1)} cm | $date',
                                          style: TextStyle(
                                            color: AppTheme.lightGrey,
                                            fontSize: isMobile ? 12 : 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (measurement['body_fat_percentage'] !=
                                      null)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 10 : 12,
                                        vertical: isMobile ? 6 : 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${measurement['body_fat_percentage']}%',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 12 : 14,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                      // Rutinas activas
                      if (_routines.isNotEmpty)
                        _buildSectionCard(
                          title: 'MIS RUTINAS',
                          icon: Icons.fitness_center,
                          color: Colors.blue,
                          isMobile: isMobile,
                          onSeeAll: () {
                            if (_routines.isNotEmpty) {
                              _navigateToRoutineDetail(_routines.first);
                            }
                          },
                          children: _routines
                              .take(isMobile ? 2 : 3)
                              .map((routine) => Container(
                                    margin: EdgeInsets.only(
                                        bottom: isMobile ? 10 : 12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(
                                          isMobile ? 12 : 16),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          EdgeInsets.all(isMobile ? 12 : 16),
                                      leading: Container(
                                        padding:
                                            EdgeInsets.all(isMobile ? 8 : 10),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.fitness_center,
                                            color: Colors.blue,
                                            size: isMobile ? 18 : 20),
                                      ),
                                      title: Text(
                                        routine['name'] ?? 'Rutina',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 15 : 17,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (routine['description'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 4.0),
                                              child: Text(
                                                routine['description']!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: AppTheme.lightGrey,
                                                  fontSize: isMobile ? 12 : 13,
                                                ),
                                              ),
                                            ),
                                          Text(
                                            'Rutina activa • Toque para ver detalles',
                                            style: TextStyle(
                                              color:
                                                  Colors.blue.withOpacity(0.8),
                                              fontSize: isMobile ? 11 : 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.blue,
                                        size: isMobile ? 16 : 18,
                                      ),
                                      onTap: () =>
                                          _navigateToRoutineDetail(routine),
                                    ),
                                  ))
                              .toList(),
                        ),

                      // Planes nutricionales
                      if (_nutritionPlans.isNotEmpty)
                        _buildSectionCard(
                          title: 'PLAN NUTRICIONAL',
                          icon: Icons.restaurant,
                          color: Colors.orange,
                          isMobile: isMobile,
                          onSeeAll: _navigateToNutritionPlan,
                          children: _nutritionPlans
                              .take(isMobile ? 2 : 3)
                              .map((plan) => Container(
                                    margin: EdgeInsets.only(
                                        bottom: isMobile ? 10 : 12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(
                                          isMobile ? 12 : 16),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          EdgeInsets.all(isMobile ? 12 : 16),
                                      leading: Container(
                                        padding:
                                            EdgeInsets.all(isMobile ? 8 : 10),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.restaurant,
                                            color: Colors.orange,
                                            size: isMobile ? 18 : 20),
                                      ),
                                      title: Text(
                                        plan['name'] ?? 'Plan Nutricional',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 15 : 17,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (plan['daily_calories'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 4.0),
                                              child: Text(
                                                '${plan['daily_calories']} kcal diarias',
                                                style: TextStyle(
                                                  color: AppTheme.lightGrey,
                                                  fontSize: isMobile ? 12 : 13,
                                                ),
                                              ),
                                            ),
                                          Text(
                                            'Plan activo • Toque para ver detalles',
                                            style: TextStyle(
                                              color: Colors.orange
                                                  .withOpacity(0.8),
                                              fontSize: isMobile ? 11 : 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.orange,
                                        size: isMobile ? 16 : 18,
                                      ),
                                      onTap: _navigateToNutritionPlan,
                                    ),
                                  ))
                              .toList(),
                        ),

                      // Evaluaciones recientes
                      if (_evaluations.isNotEmpty)
                        _buildSectionCard(
                          title: 'EVALUACIONES RECIENTES',
                          icon: Icons.assignment,
                          color: Colors.purple,
                          isMobile: isMobile,
                          onSeeAll: null,
                          children: _evaluations
                              .take(isMobile ? 2 : 3)
                              .map((evaluation) {
                            final date = DateFormat('dd/MM/yyyy').format(
                              DateTime.parse(evaluation['request_date'])
                                  .toLocal(),
                            );
                            final status = evaluation['status'];
                            Color statusColor = Colors.orange;
                            String statusText = 'PENDIENTE';

                            if (status == 'accepted') {
                              statusColor = Colors.green;
                              statusText = 'ACEPTADA';
                            } else if (status == 'rejected') {
                              statusColor = Colors.red;
                              statusText = 'RECHAZADA';
                            }

                            return Container(
                              margin:
                                  EdgeInsets.only(bottom: isMobile ? 10 : 12),
                              padding: EdgeInsets.all(isMobile ? 12 : 16),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(isMobile ? 12 : 16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(isMobile ? 8 : 10),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      status == 'accepted'
                                          ? Icons.check_circle
                                          : status == 'rejected'
                                              ? Icons.cancel
                                              : Icons.pending,
                                      color: statusColor,
                                      size: isMobile ? 18 : 20,
                                    ),
                                  ),
                                  SizedBox(width: isMobile ? 12 : 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          evaluation['purpose'] ?? 'Evaluación',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isMobile ? 14 : 16,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '$date • ${statusText.toLowerCase()}',
                                          style: TextStyle(
                                            color: AppTheme.lightGrey,
                                            fontSize: isMobile ? 12 : 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 10 : 12,
                                      vertical: isMobile ? 6 : 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: isMobile ? 10 : 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                      SizedBox(height: isMobile ? 40 : 60),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
