// lib/screens/trainer/dashboard/trainer_dashboard.dart
import 'package:flutter/material.dart';
import 'package:front/screens/trainer/client_detail_screen.dart';
import 'package:front/screens/trainer/search_clients_screen.dart';
import 'package:front/screens/trainer/nutrition_templates_screen.dart';
import 'package:front/screens/trainer/routine_templates_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
// Agrega ESTA línea con las otras importaciones:
import '../../screens/login_screen.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../widgets/gradient_button.dart';
import '../exercises/exercise_library_screen.dart';

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({super.key});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _myClients = [];

  bool _isLoading = true;

  // Para registrar nuevo cliente
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(text: "123456");
  final _dniCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _selectedGender = 'male';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw Exception('No autenticado');

      // 1. TODAS las solicitudes pendientes SIN FILTRAR
      final pending = await supabase.from('evaluation_requests').select('''
      *,
      clients (
        id,
        user_id,
        trainer_id,
        status,
        profiles!clients_user_id_fkey(full_name, email, phone, dni)
      )
    ''').eq('status', 'pending').order('request_date', ascending: false);

      debugPrint('✅ Solicitudes encontradas: ${pending.length}');

      // 2. Mis clientes actuales
      final clients = await supabase
          .from('clients')
          .select('''
            id,
            user_id,
            status,
            trainer_id,
            created_at,
            profiles!clients_user_id_fkey(
              full_name, 
              email, 
              phone,
              dni,
              age,
              gender
            )
          ''')
          .eq('trainer_id', uid)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _pendingRequests = List.from(pending);
          _myClients = List.from(clients);
          _isLoading = false;
        });

        // DEBUG
        debugPrint('Datos cargados:');
        debugPrint('   - Solicitudes: ${_pendingRequests.length}');
        debugPrint('   - Mis clientes: ${_myClients.length}');
        for (var req in _pendingRequests) {
          debugPrint(
              '   - Solicitud ID: ${req['id']}, Cliente: ${req['clients']?['profiles']?['full_name']}');
        }
      }
    } catch (e) {
      debugPrint('Error cargando datos: $e');
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

  Future<void> _registerNewClient() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final dni = _dniCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final age = _ageCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nombre, email y contraseña son requeridos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final trainerId = supabase.auth.currentUser?.id;
      if (trainerId == null) throw Exception('No autenticado');

      // OBTENER EL TOKEN DE ACCESO ACTUAL
      final currentSession = supabase.auth.currentSession;
      if (currentSession == null) throw Exception('No hay sesión activa');
      final accessToken = currentSession.accessToken;

      // Preparar datos del cliente
      final clientData = {
        'email': email,
        'password': password,
        'full_name': name,
        'phone': phone.isNotEmpty ? phone : null,
        'dni': dni.isNotEmpty ? dni : null,
        'age': age.isNotEmpty ? age : null,
        'gender': _selectedGender,
      };

      debugPrint('Llamando a edge function: hyper-processor');
      debugPrint('Datos: trainerId=$trainerId, clientData=$clientData');

      // Llamar a la Edge Function PASANDO EL TOKEN MANUALMENTE
      final response = await supabase.functions.invoke(
        'hyper-processor',
        body: {
          'trainerId': trainerId,
          'clientData': clientData,
        },
        headers: {
          'Authorization': 'Bearer $accessToken', // IMPORTANTE: Agregar token
        },
      );

      debugPrint('Response status: ${response.status}');
      debugPrint('Response data: ${response.data}');

      if (response.status != 200) {
        final errorData = response.data;
        debugPrint('Error data: $errorData');
        throw Exception(errorData['error'] ??
            errorData['message'] ??
            'Error al crear cliente (status: ${response.status})');
      }

      final result = response.data;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Cliente registrado: $name\nEmail: $email\nContraseña: $password'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        // Limpiar formulario
        _nameCtrl.clear();
        _emailCtrl.clear();
        _passwordCtrl.text = "123456";
        _dniCtrl.clear();
        _phoneCtrl.clear();
        _ageCtrl.clear();

        _loadData();

        // Cambiar a la pestaña de Mis Clientes
        _tabController.animateTo(1);
      } else {
        throw Exception(result['error'] ?? 'Error desconocido');
      }
    } catch (e) {
      debugPrint('Error al registrar cliente: $e');

      // Verificar si es un error de CORS
      if (e.toString().contains('XMLHttpRequest') ||
          e.toString().contains('CORS')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Error de conexión. Verifica la configuración CORS de la función.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
// En TrainerDashboard, modifica _registerNewClientDirect():

  Future<void> _registerNewClientDirect() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final dni = _dniCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final age = _ageCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nombre, email y contraseña son requeridos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final trainerId = supabase.auth.currentUser?.id;
      if (trainerId == null) throw Exception('No autenticado');

      // 1. Crear usuario
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Error al crear usuario en auth');
      }

      final userId = authResponse.user!.id;

      // 2. Crear perfil
      await supabase.from('profiles').insert({
        'id': userId,
        'email': email,
        'full_name': name,
        'role': 'client',
        'phone': phone.isNotEmpty ? phone : null,
        'dni': dni.isNotEmpty ? dni : null,
        'age': age.isNotEmpty ? int.tryParse(age) : null,
        'gender': _selectedGender,
      });

      // 3. Crear registro en clients
      final clientInsert = await supabase
          .from('clients')
          .insert({
            'user_id': userId,
            'trainer_id': trainerId,
            'status': 'active',
          })
          .select()
          .single();

      final clientId = clientInsert['id'];

// En la línea ~202, cambiar:
      await supabase.from('evaluation_requests').insert({
        'client_id': clientId,
        'current_trainer_id': trainerId,
        'purpose': 'initial_evaluation',
        'status': 'accepted',
        'notes': 'Evaluación inicial del cliente',
        'scheduled_date': DateTime.now().toIso8601String(), // ← scheduled_date
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Cliente registrado: $name\nEmail: $email\nContraseña: $password\n\n✅ Evaluación inicial registrada automáticamente'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      // Limpiar formulario y recargar
      _nameCtrl.clear();
      _emailCtrl.clear();
      _passwordCtrl.text = "123456";
      _dniCtrl.clear();
      _phoneCtrl.clear();
      _ageCtrl.clear();

      await _loadData();
      _tabController.animateTo(1);
    } catch (e) {
      debugPrint('Error al registrar cliente: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      // Mostrar diálogo de confirmación
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Cerrar sesión?'),
          content: const Text('¿Estás seguro de que quieres salir?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Mostrar indicador de carga
      setState(() => _isLoading = true);

      // Cerrar sesión en Supabase
      await supabase.auth.signOut();

      // Opcional: Limpiar datos locales
      _pendingRequests.clear();
      _myClients.clear();

      // Navegar a pantalla de login USANDO MaterialPageRoute (NO pushNamed)
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

  Future<void> _acceptRequest(
      String requestId, Map<String, dynamic> request) async {
    try {
      final trainerId = supabase.auth.currentUser?.id;
      if (trainerId == null) throw Exception('No autenticado');

      // Primero, obtener el client_id de la solicitud
      final requestData = await supabase
          .from('evaluation_requests')
          .select('client_id, current_trainer_id')
          .eq('id', requestId)
          .single();

      // Actualizar la solicitud como aceptada (el trigger hará el resto)
      await supabase.from('evaluation_requests').update({
        'status': 'accepted',
        'current_trainer_id': trainerId,
      }).eq('id', requestId);

      // Mostrar diálogo para programar evaluación
      await _scheduleEvaluation(requestId, request);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '✅ Solicitud aceptada. Otras solicitudes fueron rechazadas automáticamente.'),
          backgroundColor: Colors.green,
        ),
      );

      _loadData();
    } catch (e) {
      debugPrint('Error al aceptar solicitud: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al aceptar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scheduleEvaluation(
      String requestId, Map<String, dynamic> request) async {
    final TextEditingController dateCtrl = TextEditingController();
    final TextEditingController timeCtrl = TextEditingController();
    final TextEditingController notesCtrl = TextEditingController();
    final TextEditingController locationCtrl =
        TextEditingController(text: 'Gimnasio Principal');

    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    final isMobile = MediaQuery.of(context).size.width < 600;

    // MOSTRAR UN SOLO DIÁLOGO QUE NO SE CIERRA
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Programar Evaluación'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fecha - CON SELECTOR DIRECTO
                    ListTile(
                      leading: Icon(Icons.calendar_today,
                          color: AppTheme.primaryOrange),
                      title: const Text('Fecha de evaluación'),
                      subtitle: Text(
                        selectedDate == null
                            ? 'Seleccionar fecha'
                            : DateFormat('dd/MM/yyyy').format(selectedDate!),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                            dateCtrl.text =
                                DateFormat('yyyy-MM-dd').format(date);
                          });
                        }
                      },
                    ),

                    // Hora - CON SELECTOR DIRECTO
                    ListTile(
                      leading: Icon(Icons.access_time,
                          color: AppTheme.primaryOrange),
                      title: const Text('Hora de evaluación'),
                      subtitle: Text(
                        selectedTime == null
                            ? 'Seleccionar hora'
                            : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: 9, minute: 0),
                        );
                        if (time != null) {
                          setState(() {
                            selectedTime = time;
                            timeCtrl.text =
                                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                    ),

                    // Ubicación
                    TextField(
                      controller: locationCtrl,
                      decoration: InputDecoration(
                        labelText: 'Ubicación',
                        labelStyle: TextStyle(color: AppTheme.lightGrey),
                        prefixIcon: Icon(Icons.location_on,
                            color: AppTheme.primaryOrange),
                      ),
                    ),

                    // Notas adicionales
                    SizedBox(height: isMobile ? 12 : 16),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notas para el cliente',
                        labelStyle: TextStyle(color: AppTheme.lightGrey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText:
                            'Ej: Traer ropa deportiva, ayunar 2 horas antes...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedDate == null || selectedTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor, selecciona fecha y hora'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    // Combinar fecha y hora
                    final scheduledDateTime = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    );

                    try {
                      // ACTUALIZAR LA SOLICITUD
                      await supabase.from('evaluation_requests').update({
                        'status': 'accepted',
                        'scheduled_date': scheduledDateTime.toIso8601String(),
                        'location': locationCtrl.text.trim(),
                        'trainer_notes': notesCtrl.text.trim(),
                        'current_trainer_id': supabase.auth.currentUser?.id,
                      }).eq('id', requestId);

                      // Mostrar mensaje de éxito
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ Evaluación programada para ${DateFormat('dd/MM/yyyy HH:mm').format(scheduledDateTime)}',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }

                      // Cerrar diálogo
                      if (context.mounted) {
                        Navigator.pop(context);
                      }

                      // Recargar datos
                      _loadData();
                    } catch (e) {
                      debugPrint('Error al programar: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al programar: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                  ),
                  child: const Text('Programar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await supabase.from('evaluation_requests').update({
        'status': 'rejected',
        'rejection_reason': 'Rechazada por entrenador',
      }).eq('id', requestId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud rechazada'),
          backgroundColor: Colors.orange,
        ),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al rechazar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildRequestsTab() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final currentTrainerId = supabase.auth.currentUser?.id;

    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none,
                size: isMobile ? 48 : 64, color: AppTheme.lightGrey),
            SizedBox(height: isMobile ? 12 : 16),
            Text(
              'No hay solicitudes pendientes',
              style: TextStyle(
                color: AppTheme.lightGrey,
                fontSize: isMobile ? 14 : 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        itemCount: _pendingRequests.length,
        itemBuilder: (context, index) {
          final req = _pendingRequests[index];

          // EXTRAER DATOS CON VALORES POR DEFECTO
          final requestId = req['id']?.toString() ?? '';
          final purpose = req['purpose']?.toString() ?? 'Evaluación';
          final notes = req['notes']?.toString() ?? '';
          final requestDate = req['request_date']?.toString();

          // Datos del cliente con manejo seguro de nulos
          final client = req['clients'] ?? {};
          final profile = client['profiles'] ?? {};
          final clientTrainerId = client['trainer_id'];

          final clientName = profile['full_name']?.toString() ?? 'Cliente';
          final clientEmail = profile['email']?.toString() ?? 'Sin email';
          final clientPhone = profile['phone']?.toString() ?? '';

          // Formatear fecha
          String dateStr = 'Fecha no disponible';
          if (requestDate != null) {
            try {
              dateStr = DateFormat('dd/MM/yyyy HH:mm').format(
                DateTime.parse(requestDate).toLocal(),
              );
            } catch (e) {
              dateStr = 'Fecha inválida';
            }
          }

          // Verificar si es mi cliente
          final isMyCurrentClient = clientTrainerId == currentTrainerId;

          return Card(
            color: AppTheme.darkGrey,
            margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
            ),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABECERA CON NOMBRE Y ETIQUETAS
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar/icono
                      Container(
                        width: isMobile ? 40 : 48,
                        height: isMobile ? 40 : 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.2),
                          borderRadius:
                              BorderRadius.circular(isMobile ? 8 : 10),
                        ),
                        child: Icon(
                          Icons.person,
                          color: AppTheme.primaryOrange,
                          size: isMobile ? 20 : 24,
                        ),
                      ),
                      SizedBox(width: isMobile ? 12 : 16),
                      // Información principal
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nombre y etiqueta de "Mi cliente"
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    clientName,
                                    style: TextStyle(
                                      fontSize: isMobile ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMyCurrentClient)
                                  Container(
                                    margin: EdgeInsets.only(left: 8),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 6 : 8,
                                      vertical: isMobile ? 2 : 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'MI CLIENTE',
                                      style: TextStyle(
                                        fontSize: isMobile ? 8 : 9,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: isMobile ? 4 : 6),
                            // Email
                            Row(
                              children: [
                                Icon(Icons.email,
                                    size: isMobile ? 12 : 14,
                                    color: AppTheme.lightGrey),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    clientEmail,
                                    style: TextStyle(
                                      color: AppTheme.lightGrey,
                                      fontSize: isMobile ? 12 : 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            // Teléfono si existe
                            if (clientPhone.isNotEmpty) ...[
                              SizedBox(height: isMobile ? 2 : 4),
                              Row(
                                children: [
                                  Icon(Icons.phone,
                                      size: isMobile ? 12 : 14,
                                      color: AppTheme.lightGrey),
                                  SizedBox(width: 4),
                                  Text(
                                    clientPhone,
                                    style: TextStyle(
                                      color: AppTheme.lightGrey,
                                      fontSize: isMobile ? 12 : 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Etiqueta de propósito
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 6 : 8,
                          vertical: isMobile ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                        ),
                        child: Text(
                          purpose.toUpperCase(),
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // FECHA DE SOLICITUD
                  SizedBox(height: isMobile ? 8 : 12),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 12,
                      vertical: isMobile ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBlack.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: isMobile ? 14 : 16,
                            color: AppTheme.lightGrey),
                        SizedBox(width: 8),
                        Text(
                          'Solicitado: $dateStr',
                          style: TextStyle(
                            color: AppTheme.lightGrey,
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // NOTAS SI EXISTEN
                  if (notes.isNotEmpty) ...[
                    SizedBox(height: isMobile ? 8 : 12),
                    Container(
                      padding: EdgeInsets.all(isMobile ? 8 : 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note,
                              size: isMobile ? 14 : 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              notes,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: isMobile ? 12 : 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // BOTONES DE ACCIÓN
                  SizedBox(height: isMobile ? 12 : 16),
                  if (isMobile)
                    // VERSIÓN MÓVIL
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon:
                                    Icon(Icons.close, size: isMobile ? 14 : 16),
                                label: Text('Rechazar',
                                    style: TextStyle(
                                        fontSize: isMobile ? 12 : 14)),
                                onPressed: requestId.isNotEmpty
                                    ? () => _rejectRequest(requestId)
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: EdgeInsets.symmetric(
                                    vertical: isMobile ? 10 : 12,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon:
                                    Icon(Icons.check, size: isMobile ? 14 : 16),
                                label: Text(
                                  isMyCurrentClient ? 'Programar' : 'Aceptar',
                                  style:
                                      TextStyle(fontSize: isMobile ? 12 : 14),
                                ),
                                onPressed: requestId.isNotEmpty
                                    ? () => _acceptRequest(requestId, req)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isMyCurrentClient
                                      ? Colors.blue
                                      : Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isMobile ? 10 : 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        if (isMyCurrentClient)
                          Text(
                            'Ya es tu cliente - Puedes reprogramar evaluación',
                            style: TextStyle(
                              color: Colors.blue.withOpacity(0.8),
                              fontSize: isMobile ? 10 : 11,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    )
                  else
                    // VERSIÓN WEB/ESCRITORIO
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Rechazar Solicitud'),
                                onPressed: requestId.isNotEmpty
                                    ? () => _rejectRequest(requestId)
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check, size: 16),
                                label: Text(
                                  isMyCurrentClient
                                      ? '📅 Programar Evaluación'
                                      : '✅ Aceptar Solicitud',
                                ),
                                onPressed: requestId.isNotEmpty
                                    ? () => _acceptRequest(requestId, req)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isMyCurrentClient
                                      ? Colors.blue
                                      : Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isMyCurrentClient)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '⚠️ Este cliente ya está bajo tu supervisión. Al aceptar, podrás programar una nueva evaluación para él.',
                              style: TextStyle(
                                color: Colors.blue.withOpacity(0.8),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _debugPendingRequests() {
    debugPrint('=== DEBUG PENDING REQUESTS ===');
    debugPrint('Total requests: ${_pendingRequests.length}');

    for (int i = 0; i < _pendingRequests.length; i++) {
      final req = _pendingRequests[i];
      debugPrint('Request $i:');
      debugPrint('  ID: ${req['id']}');
      debugPrint('  Purpose: ${req['purpose']}');
      debugPrint('  Client data exists: ${req['clients'] != null}');

      if (req['clients'] != null) {
        final client = req['clients'];
        debugPrint('  Client ID: ${client['id']}');
        debugPrint('  Client trainer ID: ${client['trainer_id']}');
        debugPrint('  Profile exists: ${client['profiles'] != null}');

        if (client['profiles'] != null) {
          final profile = client['profiles'];
          debugPrint('  Profile name: ${profile['full_name']}');
          debugPrint('  Profile email: ${profile['email']}');
        }
      }
    }
    debugPrint('=== END DEBUG ===');
  }

  Widget _buildMyClientsTab() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_myClients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: isMobile ? 48 : 64, color: AppTheme.lightGrey),
            SizedBox(height: isMobile ? 12 : 16),
            Text(
              'Aún no tienes clientes registrados',
              style: TextStyle(
                color: AppTheme.lightGrey,
                fontSize: isMobile ? 14 : 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 16 : 24),
            GradientButton(
              text: 'Registrar Primer Cliente',
              onPressed: () => _tabController.animateTo(2),
              gradientColors: const [
                AppTheme.primaryOrange,
                AppTheme.orangeAccent
              ],
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        itemCount: _myClients.length,
        itemBuilder: (context, index) {
          final client = _myClients[index];
          final profile = client['profiles'] ?? {};
          final name = profile['full_name'] ?? 'Sin nombre';
          final email = profile['email'] ?? 'Sin email';
          final status = client['status'] ?? 'active';
          final createdAt = DateTime.parse(client['created_at']);
          final joinedDate = DateFormat('dd/MM/yyyy').format(createdAt);

          return Card(
            color: AppTheme.darkGrey,
            margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClientDetailScreen(clientData: client),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryOrange.withOpacity(0.2),
                      radius: isMobile ? 24 : 28,
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 20,
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: isMobile ? 14 : 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(
                              color: AppTheme.lightGrey,
                              fontSize: isMobile ? 12 : 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isMobile ? 4 : 8),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 6 : 8,
                                    vertical: isMobile ? 2 : 3),
                                decoration: BoxDecoration(
                                  color: status == 'active'
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                                  borderRadius:
                                      BorderRadius.circular(isMobile ? 4 : 6),
                                ),
                                child: Text(
                                  status == 'active' ? 'ACTIVO' : 'INACTIVO',
                                  style: TextStyle(
                                    fontSize: isMobile ? 9 : 10,
                                    fontWeight: FontWeight.bold,
                                    color: status == 'active'
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Se unió: $joinedDate',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              color: AppTheme.lightGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppTheme.primaryOrange,
                      size: isMobile ? 14 : 18,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRegisterClientTab() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registrar Nuevo Cliente',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 18 : 24,
            ),
          ),

          SizedBox(height: isMobile ? 4 : 8),

          Text(
            'Completa los datos del nuevo cliente',
            style: TextStyle(
              color: AppTheme.lightGrey,
              fontSize: isMobile ? 12 : 14,
            ),
          ),

          SizedBox(height: isMobile ? 20 : 32),

          // Nombre completo
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Nombre completo *',
              labelStyle: TextStyle(color: AppTheme.lightGrey),
              filled: true,
              fillColor: AppTheme.darkBlack,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.person, color: AppTheme.primaryOrange),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 14 : 16,
              ),
            ),
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 16),
          ),

          SizedBox(height: isMobile ? 12 : 16),

          // Email
          TextField(
            controller: _emailCtrl,
            decoration: InputDecoration(
              labelText: 'Correo electrónico *',
              labelStyle: TextStyle(color: AppTheme.lightGrey),
              filled: true,
              fillColor: AppTheme.darkBlack,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.email, color: AppTheme.primaryOrange),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 14 : 16,
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 16),
          ),

          SizedBox(height: isMobile ? 12 : 16),

          // Contraseña
          TextField(
            controller: _passwordCtrl,
            decoration: InputDecoration(
              labelText: 'Contraseña *',
              labelStyle: TextStyle(color: AppTheme.lightGrey),
              filled: true,
              fillColor: AppTheme.darkBlack,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.lock, color: AppTheme.primaryOrange),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 14 : 16,
              ),
            ),
            obscureText: true,
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 16),
          ),

          SizedBox(height: isMobile ? 12 : 16),

          // DNI
          TextField(
            controller: _dniCtrl,
            decoration: InputDecoration(
              labelText: 'DNI (opcional)',
              labelStyle: TextStyle(color: AppTheme.lightGrey),
              filled: true,
              fillColor: AppTheme.darkBlack,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.badge, color: AppTheme.primaryOrange),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 14 : 16,
              ),
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 16),
          ),

          SizedBox(height: isMobile ? 12 : 16),

          // Teléfono
          TextField(
            controller: _phoneCtrl,
            decoration: InputDecoration(
              labelText: 'Teléfono (opcional)',
              labelStyle: TextStyle(color: AppTheme.lightGrey),
              filled: true,
              fillColor: AppTheme.darkBlack,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.phone, color: AppTheme.primaryOrange),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 14 : 16,
              ),
            ),
            keyboardType: TextInputType.phone,
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 16),
          ),

          SizedBox(height: isMobile ? 12 : 16),

          // Edad
          TextField(
            controller: _ageCtrl,
            decoration: InputDecoration(
              labelText: 'Edad (opcional)',
              labelStyle: TextStyle(color: AppTheme.lightGrey),
              filled: true,
              fillColor: AppTheme.darkBlack,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.cake, color: AppTheme.primaryOrange),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 14 : 16,
              ),
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 16),
          ),

          SizedBox(height: isMobile ? 12 : 16),

          // Género
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
            decoration: BoxDecoration(
              color: AppTheme.darkBlack,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedGender,
                isExpanded: true,
                icon:
                    Icon(Icons.arrow_drop_down, color: AppTheme.primaryOrange),
                dropdownColor: AppTheme.darkGrey,
                style: TextStyle(
                    color: Colors.white, fontSize: isMobile ? 14 : 16),
                items: [
                  DropdownMenuItem(
                    value: 'male',
                    child: Row(
                      children: [
                        Icon(Icons.male,
                            color: Colors.blue, size: isMobile ? 16 : 20),
                        SizedBox(width: isMobile ? 6 : 8),
                        Text('Masculino'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'female',
                    child: Row(
                      children: [
                        Icon(Icons.female,
                            color: Colors.pink, size: isMobile ? 16 : 20),
                        SizedBox(width: isMobile ? 6 : 8),
                        Text('Femenino'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedGender = value);
                  }
                },
              ),
            ),
          ),

          SizedBox(height: isMobile ? 4 : 8),
          Text(
            'Género (opcional)',
            style: TextStyle(
              color: AppTheme.lightGrey,
              fontSize: isMobile ? 11 : 12,
            ),
          ),

          SizedBox(height: isMobile ? 20 : 32),

          // Botón registrar - Usa _registerNewClient (Edge Function)
          GradientButton(
            text: 'Registrar Cliente',
            onPressed: _registerNewClient,
            isLoading: _isLoading,
            gradientColors: const [
              AppTheme.primaryOrange,
              AppTheme.orangeAccent
            ],
          ),

          SizedBox(height: isMobile ? 12 : 16),

          // Información adicional
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info,
                        size: isMobile ? 14 : 16, color: Colors.blue),
                    SizedBox(width: 6),
                    Text(
                      'Información importante',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Text(
                  '• El cliente será asignado automáticamente a tu lista\n'
                  '• Podrás tomar sus medidas corporales inmediatamente\n'
                  '• Contraseña por defecto: 123456\n'
                  '• El cliente puede cambiarla después',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseLibraryTab() {
    return const ExerciseLibraryScreen();
  }

  Widget _buildRoutineTemplatesTab() {
    return const RoutineTemplatesScreen();
  }

  Widget _buildNutritionTemplatesTab() {
    return const NutritionTemplatesScreen();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Panel de Entrenador',
          style: TextStyle(fontSize: isMobile ? 18 : 20),
        ),
        backgroundColor: AppTheme.darkBlack,
        actions: [
          IconButton(
            icon: Icon(Icons.search, size: isMobile ? 20 : 24),
            onPressed: () {
              final trainerId = supabase.auth.currentUser?.id;
              if (trainerId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchClientsScreen(trainerId: trainerId),
                  ),
                );
              }
            },
            tooltip: 'Buscar clientes',
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: isMobile ? 20 : 24),
            onPressed: _loadData,
            tooltip: 'Refrescar',
          ),
          // POPUP MENU CON MÁS OPCIONES
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: isMobile ? 20 : 24),
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'profile') {
                // Aquí puedes navegar al perfil si lo implementas
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Perfil - En desarrollo')),
                );
              } else if (value == 'settings') {
                // Aquí puedes navegar a configuraciones
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Configuración - En desarrollo')),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Mi Perfil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Configuración'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            color: AppTheme.darkGrey,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryOrange,
          labelColor: AppTheme.primaryOrange,
          unselectedLabelColor: AppTheme.lightGrey,
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 12 : 14,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: isMobile ? 12 : 14,
          ),
          isScrollable: true,
          tabs: [
            Tab(
              icon: Icon(Icons.notifications, size: isMobile ? 18 : 20),
              text: 'Solicitudes',
            ),
            Tab(
              icon: Icon(Icons.people, size: isMobile ? 18 : 20),
              text: 'Mis Clientes',
            ),
            Tab(
              icon: Icon(Icons.person_add, size: isMobile ? 18 : 20),
              text: 'Registrar',
            ),
            Tab(
              icon: Icon(Icons.fitness_center, size: isMobile ? 18 : 20),
              text: 'Ejercicios',
            ),
            Tab(
              icon: Icon(Icons.layers, size: isMobile ? 18 : 20),
              text: 'Plantillas Ejercicios',
            ),
            Tab(
              icon: Icon(Icons.restaurant_menu, size: isMobile ? 18 : 20),
              text: 'Plantillas Nutrición',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsTab(),
                _buildMyClientsTab(),
                _buildRegisterClientTab(),
                _buildExerciseLibraryTab(),
                _buildRoutineTemplatesTab(),
                _buildNutritionTemplatesTab(),
              ],
            ),
      floatingActionButton: _buildFloatingActionButton(isMobile),
    );
  }

  Widget? _buildFloatingActionButton(bool isMobile) {
    switch (_tabController.index) {
      case 1: // Mis Clientes
        return _myClients.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () {
                  _tabController.animateTo(2);
                },
                backgroundColor: AppTheme.primaryOrange,
                icon: Icon(Icons.person_add, size: isMobile ? 18 : 20),
                label: Text(
                  isMobile ? 'Nuevo' : 'Nuevo Cliente',
                  style: TextStyle(fontSize: isMobile ? 12 : 14),
                ),
              )
            : null;
      case 2: // Registrar Cliente
        return FloatingActionButton(
          onPressed: _registerNewClient,
          backgroundColor: AppTheme.primaryOrange,
          child: Icon(Icons.check, size: isMobile ? 20 : 24),
          tooltip: 'Registrar cliente',
        );
      case 4: // Plantillas Ejercicios
        return FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RoutineTemplatesScreen(),
              ),
            );
          },
          backgroundColor: Colors.orange,
          child: Icon(Icons.add, size: isMobile ? 20 : 24),
          tooltip: 'Crear nueva plantilla',
        );
      case 5: // Plantillas Nutrición
        return FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NutritionTemplatesScreen(),
              ),
            );
          },
          backgroundColor: Colors.green,
          child: Icon(Icons.add, size: isMobile ? 20 : 24),
          tooltip: 'Crear nueva plantilla nutrición',
        );
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _dniCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }
}
