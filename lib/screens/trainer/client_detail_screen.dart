import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../widgets/gradient_button.dart';
import 'assign_routine_screen.dart';
import 'assign_nutrition_screen.dart';
import 'body_measurements_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final Map<String, dynamic> clientData;

  const ClientDetailScreen({super.key, required this.clientData});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late Map<String, dynamic> _client;

  // Datos cargados
  Map<String, dynamic>? _latestMeasurement;
  Map<String, dynamic>? _activeRoutine;
  Map<String, dynamic>? _activeNutritionPlan;
  List<Map<String, dynamic>> _measurementHistory = [];
  List<Map<String, dynamic>> _evaluationHistory = [];

  bool _isLoading = true;
  bool _updatingProfile = false;

  // Controladores para editar perfil
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _selectedGender = 'male';
  String _selectedStatus = 'active';

  @override
  void initState() {
    super.initState();
    _client = widget.clientData;
    _initializeForm();
    _loadClientData();
  }

  void _initializeForm() {
    final profile = _client['profiles'] ?? {};
    _nameCtrl.text = profile['full_name'] ?? '';
    _emailCtrl.text = profile['email'] ?? '';
    _phoneCtrl.text = profile['phone'] ?? '';
    _dniCtrl.text = profile['dni'] ?? '';
    _ageCtrl.text = (profile['age'] ?? '').toString();
    _selectedGender = profile['gender'] ?? 'male';
    _selectedStatus = _client['status'] ?? 'active';
  }

  Future<void> _loadClientData() async {
    setState(() => _isLoading = true);

    try {
      final clientId = _client['id'];

      // 1. Última medida corporal
      final latestMeasure = await supabase
          .from('body_measurements')
          .select('*')
          .eq('client_id', clientId)
          .order('measurement_date', ascending: false)
          .limit(1)
          .maybeSingle();

      // 2. Historial de medidas (últimas 5)
      final measuresRes = await supabase
          .from('body_measurements')
          .select('*')
          .eq('client_id', clientId)
          .order('measurement_date', ascending: false)
          .limit(5);

      // 3. Rutina activa
      final activeRoutine = await supabase.from('routines').select('''
            *,
            routine_exercises(
              *,
              exercises(name, description, video_url, muscle_group, exercise_type)
            )
          ''').eq('client_id', clientId).eq('status', 'active').maybeSingle();

      // 4. Plan nutricional activo
      final activeNutrition = await supabase.from('nutrition_plans').select('''
            *,
            nutrition_meals(*)
          ''').eq('client_id', clientId).eq('status', 'active').maybeSingle();

      // 5. Historial de evaluaciones
      final evaluationsRes = await supabase
          .from('evaluation_requests')
          .select('''
            *,
            profiles!evaluation_requests_current_trainer_id_fkey(full_name)
          ''')
          .eq('client_id', clientId)
          .order('request_date', ascending: false);

      if (mounted) {
        setState(() {
          _latestMeasurement = latestMeasure;
          _measurementHistory = List<Map<String, dynamic>>.from(measuresRes);
          _activeRoutine = activeRoutine;
          _activeNutritionPlan = activeNutrition;
          _evaluationHistory = List<Map<String, dynamic>>.from(evaluationsRes);
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

  Future<void> _updateClientProfile() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y email son requeridos')),
      );
      return;
    }

    setState(() => _updatingProfile = true);

    try {
      final userId = _client['user_id'];

      // Actualizar perfil en profiles
      await supabase.from('profiles').update({
        'full_name': name,
        'email': email,
        'phone':
            _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        'dni': _dniCtrl.text.trim().isNotEmpty ? _dniCtrl.text.trim() : null,
        'age': _ageCtrl.text.trim().isNotEmpty
            ? int.tryParse(_ageCtrl.text.trim())
            : null,
        'gender': _selectedGender,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      // Actualizar estado del cliente
      await supabase.from('clients').update({
        'status': _selectedStatus,
      }).eq('id', _client['id']);

      // Actualizar datos locales
      setState(() {
        _client['profiles']['full_name'] = name;
        _client['profiles']['email'] = email;
        _client['profiles']['phone'] = _phoneCtrl.text.trim();
        _client['profiles']['dni'] = _dniCtrl.text.trim();
        _client['profiles']['age'] = _ageCtrl.text.trim().isNotEmpty
            ? int.tryParse(_ageCtrl.text.trim())
            : null;
        _client['profiles']['gender'] = _selectedGender;
        _client['status'] = _selectedStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _updatingProfile = false);
    }
  }

  Future<void> _resetClientPassword() async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer contraseña'),
        content: const Text('¿Restablecer contraseña a "123456"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Restablecer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final email = _client['profiles']['email'];

      // Actualizar contraseña usando supabase
      await supabase.auth.admin.updateUserById(
        _client['user_id'],
        attributes: AdminUserAttributes(
          password: '123456',
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña restablecida a "123456"'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyCredentials() async {
    final email = _client['profiles']['email'] ?? '';
    await Clipboard.setData(ClipboardData(
      text: 'Email: $email\nContraseña: 123456',
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Credenciales copiadas al portapapeles'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteMeasurement(String measurementId) async {
    try {
      await supabase.from('body_measurements').delete().eq('id', measurementId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medida eliminada'),
          backgroundColor: Colors.green,
        ),
      );
      _loadClientData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteRoutine(String routineId) async {
    try {
      // Primero eliminar los ejercicios de la rutina
      await supabase
          .from('routine_exercises')
          .delete()
          .eq('routine_id', routineId);

      // Luego eliminar la rutina
      await supabase.from('routines').delete().eq('id', routineId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rutina eliminada'),
          backgroundColor: Colors.green,
        ),
      );
      _loadClientData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // NUEVO MÉTODO: Eliminar plan nutricional
  Future<void> _deleteNutritionPlan(String planId) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Plan Nutricional',
            style: TextStyle(color: Colors.red)),
        content: const Text(
            '¿Estás seguro de que deseas eliminar este plan nutricional y todas sus comidas? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Primero eliminar las comidas relacionadas
      await supabase.from('nutrition_meals').delete().eq('plan_id', planId);

      // Luego eliminar el plan nutricional
      await supabase.from('nutrition_plans').delete().eq('id', planId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan nutricional eliminado'),
            backgroundColor: Colors.green,
          ),
        );
        _loadClientData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // NUEVO MÉTODO: Mostrar detalles del plan nutricional
  void _showNutritionPlanDetails(Map<String, dynamic> nutritionPlan) {
    final meals = nutritionPlan['nutrition_meals'] as List<dynamic>;
    final dailyCalories = nutritionPlan['daily_calories'] ?? 0;
    final proteinGrams = nutritionPlan['protein_grams'] ?? 0;
    final carbsGrams = nutritionPlan['carbs_grams'] ?? 0;
    final fatGrams = nutritionPlan['fat_grams'] ?? 0;
    final mealsPerDay = nutritionPlan['meals_per_day'] ?? 3;

    // Calcular totales de las comidas
    int totalMealCalories = 0;
    int totalMealProtein = 0;
    int totalMealCarbs = 0;
    int totalMealFat = 0;

    for (final meal in meals) {
      totalMealCalories += (meal['calories'] ?? 0) as int;
      totalMealProtein += (meal['protein_grams'] ?? 0) as int;
      totalMealCarbs += (meal['carbs_grams'] ?? 0) as int;
      totalMealFat += (meal['fat_grams'] ?? 0) as int;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Título y acciones
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    nutritionPlan['name'] ?? 'Plan Nutricional',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AssignNutritionScreen(
                                clientId: _client['id'],
                                existingNutritionPlan: nutritionPlan,
                                onAssigned: _loadClientData,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteNutritionPlan(nutritionPlan['id']);
                        },
                      ),
                    ],
                  ),
                ],
              ),

              if (nutritionPlan['description'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    nutritionPlan['description']!,
                    style: TextStyle(color: AppTheme.lightGrey),
                  ),
                ),

              const SizedBox(height: 20),

              // Resumen de macros
              Card(
                color: AppTheme.darkBlack,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Objetivos Diarios',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Calorías
                      Row(
                        children: [
                          Expanded(
                            child: _buildNutritionMetricItem(
                              label: 'CALORÍAS OBJETIVO',
                              value: '$dailyCalories kcal',
                              color: Colors.orange,
                            ),
                          ),
                          Expanded(
                            child: _buildNutritionMetricItem(
                              label: 'CALORÍAS COMIDAS',
                              value: '$totalMealCalories kcal',
                              color: totalMealCalories <= dailyCalories
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Macros
                      Row(
                        children: [
                          Expanded(
                            child: _buildNutritionMetricItem(
                              label: 'PROTEÍNA',
                              value: '${proteinGrams}g',
                              color: Colors.blue,
                              subtitle: '${totalMealProtein}g en comidas',
                            ),
                          ),
                          Expanded(
                            child: _buildNutritionMetricItem(
                              label: 'CARBOHIDRATOS',
                              value: '${carbsGrams}g',
                              color: Colors.green,
                              subtitle: '${totalMealCarbs}g en comidas',
                            ),
                          ),
                          Expanded(
                            child: _buildNutritionMetricItem(
                              label: 'GRASAS',
                              value: '${fatGrams}g',
                              color: Colors.orange,
                              subtitle: '${totalMealFat}g en comidas',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Información del plan
              Card(
                color: AppTheme.darkBlack,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Información del Plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildNutritionInfoCard(
                            label: 'Comidas por día',
                            value: mealsPerDay.toString(),
                            icon: Icons.restaurant,
                            color: Colors.purple,
                          ),
                          _buildNutritionInfoCard(
                            label: 'Total de comidas',
                            value: meals.length.toString(),
                            icon: Icons.fastfood,
                            color: Colors.green,
                          ),
                          if (nutritionPlan['start_date'] != null)
                            _buildNutritionInfoCard(
                              label: 'Fecha inicio',
                              value: DateFormat('dd/MM/yyyy').format(
                                DateTime.parse(nutritionPlan['start_date']),
                              ),
                              icon: Icons.calendar_today,
                              color: Colors.blue,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Lista de comidas agrupadas por día
              Card(
                color: AppTheme.darkBlack,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Comidas del Plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Chip(
                            label: Text('${meals.length} comidas'),
                            backgroundColor: Colors.green.withOpacity(0.2),
                            labelStyle: const TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Agrupar comidas por día
                      if (meals.isNotEmpty)
                        ..._buildGroupedMeals(meals)
                      else
                        const Center(
                          child: Column(
                            children: [
                              Icon(Icons.restaurant_outlined,
                                  size: 48, color: AppTheme.lightGrey),
                              SizedBox(height: 16),
                              Text(
                                'No hay comidas registradas',
                                style: TextStyle(color: AppTheme.lightGrey),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AssignNutritionScreen(
                              clientId: _client['id'],
                              existingNutritionPlan: nutritionPlan,
                              onAssigned: _loadClientData,
                            ),
                          ),
                        );
                      },
                      child: const Text('Editar Plan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // Métodos auxiliares para la vista de plan nutricional
  Widget _buildNutritionMetricItem({
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.lightGrey,
              fontSize: 10,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNutritionInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.lightGrey,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedMeals(List<dynamic> meals) {
    final groupedMeals = <String, List<dynamic>>{};

    // Agrupar comidas por día
    for (final meal in meals) {
      final day = meal['day_of_week']?.toString() ?? 'monday';
      if (!groupedMeals.containsKey(day)) {
        groupedMeals[day] = [];
      }
      groupedMeals[day]!.add(meal);
    }

    // Ordenar días
    final dayOrder = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    final sortedDays = groupedMeals.keys.toList()
      ..sort((a, b) => dayOrder.indexOf(a).compareTo(dayOrder.indexOf(b)));

    return sortedDays.map((day) {
      final dayName = _getDayName(day);
      final dayMeals = groupedMeals[day]!;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              dayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          ...dayMeals.map<Widget>((meal) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: AppTheme.darkGrey,
              child: ListTile(
                leading: _getMealTypeIcon(meal['meal_type']),
                title: Text(
                  meal['name'] ?? 'Comida sin nombre',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${meal['calories']} kcal',
                      style: const TextStyle(color: AppTheme.lightGrey),
                    ),
                    Row(
                      children: [
                        Chip(
                          label: Text('P: ${meal['protein_grams']}g'),
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          labelStyle: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(width: 4),
                        Chip(
                          label: Text('C: ${meal['carbs_grams']}g'),
                          backgroundColor: Colors.green.withOpacity(0.1),
                          labelStyle: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(width: 4),
                        Chip(
                          label: Text('G: ${meal['fat_grams']}g'),
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          labelStyle: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Text(
                  _getMealTypeName(meal['meal_type']),
                  style: TextStyle(
                    color: _getMealTypeColor(meal['meal_type']),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
          if (day != sortedDays.last) const SizedBox(height: 16),
        ],
      );
    }).toList();
  }

  Icon _getMealTypeIcon(String? mealType) {
    switch (mealType) {
      case 'breakfast':
        return const Icon(Icons.wb_sunny, color: Colors.orange);
      case 'lunch':
        return const Icon(Icons.lunch_dining, color: Colors.green);
      case 'dinner':
        return const Icon(Icons.nightlight, color: Colors.blue);
      case 'snack':
        return const Icon(Icons.local_cafe, color: Colors.yellow);
      default:
        return const Icon(Icons.restaurant, color: Colors.grey);
    }
  }

  String _getMealTypeName(String? mealType) {
    switch (mealType) {
      case 'breakfast':
        return 'Desayuno';
      case 'lunch':
        return 'Almuerzo';
      case 'dinner':
        return 'Cena';
      case 'snack':
        return 'Snack';
      default:
        return 'Comida';
    }
  }

  Color _getMealTypeColor(String? mealType) {
    switch (mealType) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.blue;
      case 'snack':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  // Método auxiliar original para mostrar detalles completos de la medición
  void _showMeasurementDetails(Map<String, dynamic> measurement) {
    final height = measurement['height']?.toDouble() ?? 0;
    final weight = measurement['weight']?.toDouble() ?? 0;
    final bmi = measurement['bmi']?.toDouble() ?? 0;
    final bodyFat = measurement['body_fat']?.toDouble() ?? 0;
    final muscleMass = measurement['muscle_mass']?.toDouble() ?? 0;
    final waterPercentage = measurement['water_percentage']?.toDouble() ?? 0;
    final boneMass = measurement['bone_mass']?.toDouble() ?? 0;
    final visceralFat = measurement['visceral_fat'] ?? 0;
    final metabolicAge = measurement['metabolic_age'] ?? 0;

    final date = DateTime.parse(measurement['measurement_date']).toLocal();
    final formattedDate = DateFormat('dd/MM/yyyy').format(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Título
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detalles Completos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(color: AppTheme.lightGrey),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Métricas Principales
              Card(
                color: AppTheme.darkBlack,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildMetricItem(
                            label: 'PESO',
                            value: '${weight.toStringAsFixed(1)} kg',
                            color: Colors.orange,
                          ),
                          _buildMetricItem(
                            label: 'ALTURA',
                            value: '${height.toStringAsFixed(1)} cm',
                            color: Colors.blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildMetricItem(
                            label: 'IMC',
                            value: bmi.toStringAsFixed(1),
                            color: _getBMIColor(bmi),
                            subtitle: _getBMICategory(bmi),
                          ),
                          _buildMetricItem(
                            label: 'GRASA',
                            value: '${bodyFat.toStringAsFixed(1)}%',
                            color: _getBodyFatColor(bodyFat),
                            subtitle: _getBodyFatCategory(bodyFat),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Composición Corporal
              Card(
                color: AppTheme.darkBlack,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Composición Corporal',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildSmallMetricCard(
                            label: 'Masa Muscular',
                            value: '${muscleMass.toStringAsFixed(1)} kg',
                            color: Colors.green,
                          ),
                          _buildSmallMetricCard(
                            label: 'Agua Corporal',
                            value: '${waterPercentage.toStringAsFixed(1)}%',
                            color: Colors.blue,
                          ),
                          _buildSmallMetricCard(
                            label: 'Masa Ósea',
                            value: '${boneMass.toStringAsFixed(1)} kg',
                            color: Colors.brown,
                          ),
                          _buildSmallMetricCard(
                            label: 'Grasa Visceral',
                            value: visceralFat.toString(),
                            color: Colors.red,
                          ),
                          _buildSmallMetricCard(
                            label: 'Edad Metabólica',
                            value: '$metabolicAge años',
                            color: Colors.purple,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Medidas Corporales
              Card(
                color: AppTheme.darkBlack,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medidas Corporales (cm)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildMeasurementItem(
                            label: 'Cuello',
                            value: measurement['neck']?.toStringAsFixed(1) ??
                                'N/A',
                          ),
                          _buildMeasurementItem(
                            label: 'Hombros',
                            value:
                                measurement['shoulders']?.toStringAsFixed(1) ??
                                    'N/A',
                          ),
                          _buildMeasurementItem(
                            label: 'Pecho',
                            value: measurement['chest']?.toStringAsFixed(1) ??
                                'N/A',
                          ),
                          _buildMeasurementItem(
                            label: 'Brazos',
                            value: measurement['arms']?.toStringAsFixed(1) ??
                                'N/A',
                          ),
                          _buildMeasurementItem(
                            label: 'Cintura',
                            value: measurement['waist']?.toStringAsFixed(1) ??
                                'N/A',
                          ),
                          _buildMeasurementItem(
                            label: 'Glúteos',
                            value: measurement['glutes']?.toStringAsFixed(1) ??
                                'N/A',
                          ),
                          _buildMeasurementItem(
                            label: 'Piernas',
                            value: measurement['legs']?.toStringAsFixed(1) ??
                                'N/A',
                          ),
                          _buildMeasurementItem(
                            label: 'Pantorrillas',
                            value: measurement['calves']?.toStringAsFixed(1) ??
                                'N/A',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (measurement['injuries']?.toString().isNotEmpty == true)
                Column(
                  children: [
                    const SizedBox(height: 16),
                    Card(
                      color: AppTheme.darkBlack,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lesiones / Notas',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              measurement['injuries']?.toString() ?? '',
                              style: TextStyle(color: AppTheme.lightGrey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BodyMeasurementsScreen(
                              clientId: _client['id'],
                              existingMeasurement: measurement,
                              onSaved: _loadClientData,
                            ),
                          ),
                        );
                      },
                      child: const Text('Editar Medida'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.lightGrey,
                fontSize: 12,
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallMetricCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.lightGrey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementItem({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.lightGrey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientInfoCard() {
    final profile = _client['profiles'] ?? {};
    final name = profile['full_name'] ?? 'Cliente';
    final email = profile['email'] ?? 'Sin email';
    final phone = profile['phone'] ?? 'Sin teléfono';
    final status = _client['status'] ?? 'active';
    final dni = profile['dni'] ?? 'No registrado';
    final age = profile['age']?.toString() ?? 'No registrado';
    final gender = profile['gender'] == 'male' ? 'Masculino' : 'Femenino';

    return Card(
      color: AppTheme.darkGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryOrange.withOpacity(0.2),
                  radius: 32,
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(color: AppTheme.lightGrey),
                      ),
                      if (phone != null && phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '📱 $phone',
                          style: const TextStyle(color: AppTheme.lightGrey),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert,
                      color: AppTheme.primaryOrange),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'copy',
                      child: Row(
                        children: [
                          const Icon(Icons.copy, size: 20),
                          const SizedBox(width: 8),
                          const Text('Copiar credenciales'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'reset',
                      child: Row(
                        children: [
                          const Icon(Icons.lock_reset,
                              size: 20, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Text('Restablecer contraseña'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'copy') {
                      _copyCredentials();
                    } else if (value == 'reset') {
                      _resetClientPassword();
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: status == 'active'
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Estado: ${status.toUpperCase()}',
                style: TextStyle(
                  color: status == 'active' ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Información adicional
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (dni != null && dni.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'DNI: $dni',
                      style: const TextStyle(color: AppTheme.lightGrey),
                    ),
                  ),
                ],
                if (age != null && age.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Edad: $age años',
                      style: const TextStyle(color: AppTheme.lightGrey),
                    ),
                  ),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Género: $gender',
                    style: const TextStyle(color: AppTheme.lightGrey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditProfileCard() {
    return Card(
      color: AppTheme.darkGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit, color: AppTheme.primaryOrange),
                const SizedBox(width: 8),
                Text(
                  'Editar Perfil',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Nombre
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre completo *',
                labelStyle: const TextStyle(color: AppTheme.lightGrey),
                filled: true,
                fillColor: AppTheme.darkBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),

            const SizedBox(height: 12),

            // Email
            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email *',
                labelStyle: const TextStyle(color: AppTheme.lightGrey),
                filled: true,
                fillColor: AppTheme.darkBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'Teléfono',
                      labelStyle: const TextStyle(color: AppTheme.lightGrey),
                      filled: true,
                      fillColor: AppTheme.darkBlack,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _dniCtrl,
                    decoration: InputDecoration(
                      labelText: 'DNI',
                      labelStyle: const TextStyle(color: AppTheme.lightGrey),
                      filled: true,
                      fillColor: AppTheme.darkBlack,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageCtrl,
                    decoration: InputDecoration(
                      labelText: 'Edad',
                      labelStyle: const TextStyle(color: AppTheme.lightGrey),
                      filled: true,
                      fillColor: AppTheme.darkBlack,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBlack,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGender,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: AppTheme.primaryOrange),
                        dropdownColor: AppTheme.darkGrey,
                        style: const TextStyle(color: Colors.white),
                        items: [
                          DropdownMenuItem(
                            value: 'male',
                            child: Row(
                              children: [
                                const Icon(Icons.male, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text('Masculino'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'female',
                            child: Row(
                              children: [
                                const Icon(Icons.female, color: Colors.pink),
                                const SizedBox(width: 8),
                                const Text('Femenino'),
                              ],
                            ),
                          ),
                        ].toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedGender = value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.darkBlack,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down,
                      color: AppTheme.primaryOrange),
                  dropdownColor: AppTheme.darkGrey,
                  style: const TextStyle(color: Colors.white),
                  items: ['active', 'inactive'].map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(
                        status == 'active' ? 'ACTIVO' : 'INACTIVO',
                        style: TextStyle(
                          color: status == 'active' ? Colors.green : Colors.red,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStatus = value);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            GradientButton(
              text: _updatingProfile ? 'Actualizando...' : 'Guardar Cambios',
              onPressed: _updatingProfile ? null : _updateClientProfile,
              isLoading: _updatingProfile,
              gradientColors: [AppTheme.primaryOrange, AppTheme.orangeAccent],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementCard() {
    final hasMeasurement = _latestMeasurement != null;

    return Card(
      color: AppTheme.darkGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.scale, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Medidas Corporales',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                if (hasMeasurement)
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert,
                        color: AppTheme.primaryOrange),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'view_details',
                        child: Row(
                          children: [
                            const Icon(Icons.visibility, size: 20),
                            const SizedBox(width: 8),
                            const Text('Ver detalles'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit,
                                size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text('Editar'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete,
                                size: 20, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('Eliminar',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'view_details') {
                        _showMeasurementDetails(_latestMeasurement!);
                      } else if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BodyMeasurementsScreen(
                              clientId: _client['id'],
                              existingMeasurement: _latestMeasurement,
                              onSaved: _loadClientData,
                            ),
                          ),
                        );
                      } else if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eliminar medida',
                                style: TextStyle(color: Colors.red)),
                            content:
                                const Text('¿Eliminar esta medida corporal?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteMeasurement(_latestMeasurement!['id']);
                                },
                                child: const Text('Eliminar',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasMeasurement)
              Column(
                children: [
                  const Icon(Icons.scale_outlined,
                      size: 48, color: AppTheme.lightGrey),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay medidas registradas',
                    style: TextStyle(color: AppTheme.lightGrey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Registrar Primeras Medidas'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BodyMeasurementsScreen(
                            clientId: _client['id'],
                            onSaved: _loadClientData,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información básica
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _latestMeasurement!['weight']
                                      ?.toStringAsFixed(1) ??
                                  '0',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Peso (kg)',
                              style: TextStyle(color: AppTheme.lightGrey),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _latestMeasurement!['height']
                                      ?.toStringAsFixed(1) ??
                                  '0',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Altura (cm)',
                              style: TextStyle(color: AppTheme.lightGrey),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _latestMeasurement!['bmi']?.toStringAsFixed(1) ??
                                  '0',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _getBMIColor(
                                    _latestMeasurement!['bmi']?.toDouble()),
                              ),
                            ),
                            const Text(
                              'IMC',
                              style: TextStyle(color: AppTheme.lightGrey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Fecha
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: AppTheme.lightGrey),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd/MM/yyyy').format(
                          DateTime.parse(
                                  _latestMeasurement!['measurement_date'])
                              .toLocal(),
                        ),
                        style: const TextStyle(color: AppTheme.lightGrey),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.visibility,
                            color: AppTheme.primaryOrange),
                        onPressed: () =>
                            _showMeasurementDetails(_latestMeasurement!),
                        tooltip: 'Ver detalles',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Historial reciente (si hay)
                  if (_measurementHistory.length > 1)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Historial reciente:',
                          style: TextStyle(
                            color: AppTheme.lightGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._measurementHistory
                            .skip(1)
                            .take(2)
                            .map((measurement) {
                          final date = DateFormat('dd/MM/yyyy').format(
                            DateTime.parse(measurement['measurement_date'])
                                .toLocal(),
                          );
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.history,
                                size: 16, color: AppTheme.lightGrey),
                            title: Text(
                              '${measurement['weight']?.toStringAsFixed(1)} kg',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'IMC: ${measurement['bmi']?.toStringAsFixed(1)} - $date',
                              style: const TextStyle(color: AppTheme.lightGrey),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility,
                                      size: 16, color: Colors.blue),
                                  onPressed: () =>
                                      _showMeasurementDetails(measurement),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      size: 16, color: Colors.green),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BodyMeasurementsScreen(
                                          clientId: _client['id'],
                                          existingMeasurement: measurement,
                                          onSaved: _loadClientData,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Nueva Medida'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BodyMeasurementsScreen(
                                  clientId: _client['id'],
                                  onSaved: _loadClientData,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.history),
                          label: const Text('Ver Historial'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Historial de Medidas'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ..._measurementHistory.map((measurement) {
                                        final date =
                                            DateFormat('dd/MM/yyyy').format(
                                          DateTime.parse(measurement[
                                                  'measurement_date'])
                                              .toLocal(),
                                        );
                                        return ListTile(
                                          title: Text(
                                            '${measurement['weight']?.toStringAsFixed(1)} kg',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            'IMC: ${measurement['bmi']?.toStringAsFixed(1)} - $date',
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.visibility,
                                                    size: 16,
                                                    color: Colors.blue),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _showMeasurementDetails(
                                                      measurement);
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit,
                                                    size: 16,
                                                    color: Colors.green),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          BodyMeasurementsScreen(
                                                        clientId: _client['id'],
                                                        existingMeasurement:
                                                            measurement,
                                                        onSaved:
                                                            _loadClientData,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cerrar'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getBMIColor(double? bmi) {
    if (bmi == null) return Colors.white;
    if (bmi < 18.5) return Colors.blue; // Bajo peso
    if (bmi < 25) return Colors.green; // Normal
    if (bmi < 30) return Colors.orange; // Sobrepeso
    return Colors.red; // Obesidad
  }

  String _getBMICategory(double? bmi) {
    if (bmi == null) return '';
    if (bmi < 18.5) return 'Bajo peso';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Sobrepeso';
    return 'Obesidad';
  }

  Color _getBodyFatColor(double? bodyFat) {
    if (bodyFat == null) return Colors.white;
    final gender = _client['profiles']?['gender'] ?? 'male';
    if (gender == 'male') {
      if (bodyFat < 15) return Colors.green; // Atleta
      if (bodyFat < 20) return Colors.blue; // Fitness
      if (bodyFat < 25) return Colors.yellow; // Aceptable
      return Colors.red; // Obeso
    } else {
      if (bodyFat < 20) return Colors.green; // Atleta
      if (bodyFat < 25) return Colors.blue; // Fitness
      if (bodyFat < 30) return Colors.yellow; // Aceptable
      return Colors.red; // Obeso
    }
  }

  String _getBodyFatCategory(double? bodyFat) {
    if (bodyFat == null) return '';
    final gender = _client['profiles']?['gender'] ?? 'male';
    if (gender == 'male') {
      if (bodyFat < 15) return 'Atleta';
      if (bodyFat < 20) return 'Fitness';
      if (bodyFat < 25) return 'Normal';
      return 'Alto';
    } else {
      if (bodyFat < 20) return 'Atleta';
      if (bodyFat < 25) return 'Fitness';
      if (bodyFat < 30) return 'Normal';
      return 'Alto';
    }
  }

  // Método auxiliar para construir ejercicios agrupados por día
  List<Widget> _buildGroupedExercises() {
    if (_activeRoutine == null ||
        (_activeRoutine!['routine_exercises'] as List).isEmpty) {
      return [const Text('No hay ejercicios en esta rutina')];
    }

    final exercises = _activeRoutine!['routine_exercises'] as List<dynamic>;
    final groupedExercises = <String, List<dynamic>>{};

    // Agrupar ejercicios por día
    for (final exercise in exercises) {
      final day = exercise['day_of_week']?.toString() ?? 'monday';
      if (!groupedExercises.containsKey(day)) {
        groupedExercises[day] = [];
      }
      groupedExercises[day]!.add(exercise);
    }

    // Crear widgets para cada día
    return groupedExercises.entries.map((entry) {
      final dayName = _getDayName(entry.key);
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ExpansionTile(
          leading: const Icon(Icons.calendar_today),
          title: Text(
            dayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          children: entry.value.map<Widget>((exercise) {
            final exData = exercise['exercises'] ?? {};
            final isTimeBased = exercise['exercise_type'] == 'time';

            return ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(exData['name']?.toString() ?? 'Ejercicio'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${exercise['sets']}x${isTimeBased ? '${exercise['duration_seconds']}s' : exercise['reps']}',
                  ),
                  Text(
                    'Descanso: ${exercise['rest_time']}s',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (exData['muscle_group'] != null)
                    Chip(
                      label: Text(exData['muscle_group']?.toString() ?? ''),
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      labelStyle: const TextStyle(fontSize: 10),
                    ),
                ],
              ),
              trailing: Icon(
                isTimeBased ? Icons.timer : Icons.repeat,
                color: isTimeBased ? Colors.purple : Colors.blue,
              ),
            );
          }).toList(),
        ),
      );
    }).toList();
  }

  Widget _buildRoutineCard() {
    final hasRoutine = _activeRoutine != null;

    return Card(
      color: AppTheme.darkGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fitness_center, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Rutina de Entrenamiento',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                if (hasRoutine)
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert,
                        color: AppTheme.primaryOrange),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete,
                                size: 20, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('Eliminar',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eliminar rutina',
                                style: TextStyle(color: Colors.red)),
                            content: const Text(
                                '¿Eliminar esta rutina y todos sus ejercicios?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteRoutine(_activeRoutine!['id']);
                                },
                                child: const Text('Eliminar',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasRoutine)
              Column(
                children: [
                  const Icon(Icons.fitness_center_outlined,
                      size: 48, color: AppTheme.lightGrey),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay rutina asignada',
                    style: TextStyle(color: AppTheme.lightGrey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Crear Rutina'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssignRoutineScreen(
                            clientId: _client['id'],
                            onAssigned: _loadClientData,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre de la rutina
                  Text(
                    _activeRoutine!['name'] ?? 'Rutina sin nombre',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Descripción
                  if (_activeRoutine!['description'] != null)
                    Text(
                      _activeRoutine!['description']!,
                      style: const TextStyle(color: AppTheme.lightGrey),
                    ),

                  const SizedBox(height: 12),

                  // Ejercicios
                  Text(
                    'Ejercicios: ${(_activeRoutine!['routine_exercises'] as List).length}',
                    style: const TextStyle(color: AppTheme.lightGrey),
                  ),

                  // Fecha de última actualización
                  if (_activeRoutine!['last_updated_at'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.update,
                              size: 14, color: AppTheme.lightGrey),
                          const SizedBox(width: 4),
                          Text(
                            'Actualizada: ${DateFormat('dd/MM/yyyy').format(
                              DateTime.parse(_activeRoutine!['last_updated_at'])
                                  .toLocal(),
                            )}',
                            style: const TextStyle(
                              color: AppTheme.lightGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.visibility),
                          label: const Text('Ver Detalles'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title:
                                    Text(_activeRoutine!['name'] ?? 'Rutina'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_activeRoutine!['description'] !=
                                            null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 16),
                                            child: Text(_activeRoutine![
                                                'description']!),
                                          ),

                                        // Información de la rutina
                                        Card(
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              children: [
                                                ListTile(
                                                  leading:
                                                      const Icon(Icons.update),
                                                  title: const Text(
                                                      'Última actualización'),
                                                  subtitle: Text(
                                                    DateFormat('dd/MM/yyyy')
                                                        .format(
                                                      DateTime.parse(_activeRoutine![
                                                                  'last_updated_at'] ??
                                                              _activeRoutine![
                                                                  'created_at'])
                                                          .toLocal(),
                                                    ),
                                                  ),
                                                ),
                                                ListTile(
                                                  leading: const Icon(
                                                      Icons.fitness_center),
                                                  title: const Text(
                                                      'Total de ejercicios'),
                                                  subtitle: Text(
                                                    '${(_activeRoutine!['routine_exercises'] as List).length} ejercicios',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 16),
                                        const Text(
                                          'Ejercicios:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Usar el método auxiliar para construir ejercicios agrupados
                                        ..._buildGroupedExercises(),
                                      ],
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cerrar'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Editar Rutina'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AssignRoutineScreen(
                                  clientId: _client['id'],
                                  existingRoutine: _activeRoutine,
                                  onAssigned: _loadClientData,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _getDayName(String dayKey) {
    switch (dayKey.toLowerCase()) {
      case 'monday':
        return 'Lunes';
      case 'tuesday':
        return 'Martes';
      case 'wednesday':
        return 'Miércoles';
      case 'thursday':
        return 'Jueves';
      case 'friday':
        return 'Viernes';
      case 'saturday':
        return 'Sábado';
      case 'sunday':
        return 'Domingo';
      default:
        return 'Sin día';
    }
  }

  Widget _buildNutritionCard() {
    final hasPlan = _activeNutritionPlan != null;

    return Card(
      color: AppTheme.darkGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Plan Nutricional',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                if (hasPlan)
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert,
                        color: AppTheme.primaryOrange),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'view_details',
                        child: Row(
                          children: [
                            const Icon(Icons.visibility, size: 20),
                            const SizedBox(width: 8),
                            const Text('Ver detalles'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit,
                                size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text('Editar'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete,
                                size: 20, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('Eliminar',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'view_details') {
                        _showNutritionPlanDetails(_activeNutritionPlan!);
                      } else if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AssignNutritionScreen(
                              clientId: _client['id'],
                              existingNutritionPlan: _activeNutritionPlan,
                              onAssigned: _loadClientData,
                            ),
                          ),
                        );
                      } else if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eliminar Plan Nutricional',
                                style: TextStyle(color: Colors.red)),
                            content: const Text(
                                '¿Eliminar este plan nutricional y todas sus comidas?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteNutritionPlan(
                                      _activeNutritionPlan!['id']);
                                },
                                child: const Text('Eliminar',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasPlan)
              Column(
                children: [
                  const Icon(Icons.restaurant_outlined,
                      size: 48, color: AppTheme.lightGrey),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay plan nutricional asignado',
                    style: TextStyle(color: AppTheme.lightGrey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Asignar Plan'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssignNutritionScreen(
                            clientId: _client['id'],
                            onAssigned: _loadClientData,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del plan
                  Text(
                    _activeNutritionPlan!['name'] ?? 'Plan sin nombre',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Calorías diarias
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        '${_activeNutritionPlan!['daily_calories'] ?? '0'} kcal diarias',
                        style: const TextStyle(color: AppTheme.lightGrey),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Comidas
                  Row(
                    children: [
                      const Icon(Icons.fastfood, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        '${(_activeNutritionPlan!['nutrition_meals'] as List).length} comidas',
                        style: const TextStyle(color: AppTheme.lightGrey),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.visibility),
                          label: const Text('Ver Detalles'),
                          onPressed: () {
                            _showNutritionPlanDetails(_activeNutritionPlan!);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Editar Plan'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AssignNutritionScreen(
                                  clientId: _client['id'],
                                  existingNutritionPlan: _activeNutritionPlan,
                                  onAssigned: _loadClientData,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationHistory() {
    if (_evaluationHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: AppTheme.darkGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Historial de Evaluaciones',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._evaluationHistory.take(3).map((evaluation) {
              final trainerName =
                  evaluation['profiles']?['full_name'] ?? 'Entrenador';
              final date = DateFormat('dd/MM/yyyy').format(
                DateTime.parse(evaluation['request_date']).toLocal(),
              );
              final status = evaluation['status'] ?? 'pending';
              final purpose = evaluation['purpose'] ?? 'Evaluación';

              Color statusColor = Colors.orange;
              IconData statusIcon = Icons.pending;

              if (status == 'accepted') {
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
              } else if (status == 'rejected') {
                statusColor = Colors.red;
                statusIcon = Icons.cancel;
              } else if (status == 'completed') {
                statusColor = Colors.blue;
                statusIcon = Icons.done_all;
              }

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(statusIcon, color: statusColor),
                title: Text(
                  purpose,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Entrenador: $trainerName'),
                    Text('Fecha: $date'),
                  ],
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_client['profiles']?['full_name'] ?? 'Cliente'),
        backgroundColor: AppTheme.darkBlack,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClientData,
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : RefreshIndicator(
              onRefresh: _loadClientData,
              color: AppTheme.primaryOrange,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildClientInfoCard(),
                    const SizedBox(height: 24),
                    _buildEditProfileCard(),
                    const SizedBox(height: 24),
                    _buildMeasurementCard(),
                    const SizedBox(height: 24),
                    _buildRoutineCard(),
                    const SizedBox(height: 24),
                    _buildNutritionCard(),
                    const SizedBox(height: 24),
                    _buildEvaluationHistory(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
