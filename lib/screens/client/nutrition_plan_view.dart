import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';

class NutritionPlanViewScreen extends StatefulWidget {
  const NutritionPlanViewScreen({super.key});

  @override
  State<NutritionPlanViewScreen> createState() =>
      _NutritionPlanViewScreenState();
}

class _NutritionPlanViewScreenState extends State<NutritionPlanViewScreen> {
  List<Map<String, dynamic>> _nutritionPlans = [];
  List<Map<String, dynamic>> _meals = [];
  bool _isLoading = true;
  bool _hasPlan = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw Exception('No autenticado');

      // Obtener cliente
      final clientRes = await supabase
          .from('clients')
          .select('id')
          .eq('user_id', uid)
          .maybeSingle();

      if (clientRes != null) {
        // Cargar planes nutricionales activos
        final plansRes = await supabase
            .from('nutrition_plans')
            .select('*')
            .eq('client_id', clientRes['id'])
            .eq('status', 'active')
            .order('created_at', ascending: false)
            .limit(1);

        if (plansRes.isNotEmpty) {
          final plan = plansRes.first;
          _hasPlan = true;

          // Cargar comidas del plan
          final mealsRes = await supabase
              .from('nutrition_meals')
              .select('*')
              .eq('plan_id', plan['id'])
              .order('meal_type');

          setState(() {
            _nutritionPlans = List.from(plansRes);
            _meals = List.from(mealsRes);
          });
        } else {
          _hasPlan = false;
        }
      }
    } catch (e) {
      debugPrint('Error cargando plan nutricional: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar plan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupMealsByDay() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final meal in _meals) {
      final day = meal['day_of_week'] ?? 'general';
      if (!grouped.containsKey(day)) {
        grouped[day] = [];
      }
      grouped[day]!.add(meal);
    }

    // Ordenar días
    final dayOrder = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7
    };

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => (dayOrder[a] ?? 99).compareTo(dayOrder[b] ?? 99));

    final sortedMap = <String, List<Map<String, dynamic>>>{};
    for (final key in sortedKeys) {
      sortedMap[key] = grouped[key]!;
    }

    return sortedMap;
  }

  String _getDayName(String day) {
    final names = {
      'monday': 'Lunes',
      'tuesday': 'Martes',
      'wednesday': 'Miércoles',
      'thursday': 'Jueves',
      'friday': 'Viernes',
      'saturday': 'Sábado',
      'sunday': 'Domingo',
    };
    return names[day] ?? day;
  }

  String _getDayShortName(String day) {
    final names = {
      'monday': 'LUN',
      'tuesday': 'MAR',
      'wednesday': 'MIÉ',
      'thursday': 'JUE',
      'friday': 'VIE',
      'saturday': 'SÁB',
      'sunday': 'DOM',
    };
    return names[day] ?? day;
  }

  String _getMealTypeName(String type) {
    final names = {
      'breakfast': 'Desayuno',
      'lunch': 'Almuerzo',
      'dinner': 'Cena',
      'snack': 'Snack',
    };
    return names[type] ?? type;
  }

  String _getMealShortName(String type) {
    final names = {
      'breakfast': 'DESAY.',
      'lunch': 'ALM.',
      'dinner': 'CENA',
      'snack': 'SNACK',
    };
    return names[type] ?? type;
  }

  Widget _buildMealCard(Map<String, dynamic> meal, bool isMobile) {
    return Card(
      color: AppTheme.darkGrey,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con tipo de comida y calorías
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12,
                    vertical: isMobile ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getMealColor(meal['meal_type']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getMealIcon(meal['meal_type']),
                        size: isMobile ? 14 : 16,
                        color: _getMealColor(meal['meal_type']),
                      ),
                      SizedBox(width: isMobile ? 4 : 6),
                      Text(
                        isMobile
                            ? _getMealShortName(meal['meal_type'])
                            : _getMealTypeName(meal['meal_type']),
                        style: TextStyle(
                          color: _getMealColor(meal['meal_type']),
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 10 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 14,
                    vertical: isMobile ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${meal['calories']} kcal',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: isMobile ? 12 : 16),

            // Nombre de la comida
            Text(
              meal['name'] ?? 'Comida sin nombre',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 16 : 18,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            if (meal['description'] != null &&
                meal['description'].toString().isNotEmpty) ...[
              SizedBox(height: isMobile ? 6 : 8),
              Text(
                meal['description'],
                style: TextStyle(
                  color: AppTheme.lightGrey,
                  fontSize: isMobile ? 12 : 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            SizedBox(height: isMobile ? 12 : 16),

            // Macros con progreso visual
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMacroItem(
                  'Proteína',
                  '${meal['protein_grams']}g',
                  Colors.blue,
                  isMobile,
                ),
                _buildMacroItem(
                  'Carbos',
                  '${meal['carbs_grams']}g',
                  Colors.green,
                  isMobile,
                ),
                _buildMacroItem(
                  'Grasas',
                  '${meal['fat_grams']}g',
                  Colors.orange,
                  isMobile,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroItem(
      String label, String value, Color color, bool isMobile) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 6 : 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          isMobile ? label.substring(0, 3) : label,
          style: TextStyle(
            color: AppTheme.lightGrey,
            fontSize: isMobile ? 10 : 12,
          ),
        ),
      ],
    );
  }

  IconData _getMealIcon(String type) {
    switch (type) {
      case 'breakfast':
        return Icons.bakery_dining;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      default:
        return Icons.local_cafe;
    }
  }

  Color _getMealColor(String type) {
    switch (type) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final groupedMeals = _groupMealsByDay();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MI PLAN NUTRICIONAL'),
        backgroundColor: AppTheme.darkBlack,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryOrange),
                  SizedBox(height: 16),
                  Text(
                    'Cargando tu plan...',
                    style: TextStyle(
                      color: AppTheme.lightGrey,
                    ),
                  ),
                ],
              ),
            )
          : !_hasPlan
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 24 : 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: isMobile ? 80 : 100,
                          color: AppTheme.lightGrey.withOpacity(0.5),
                        ),
                        SizedBox(height: isMobile ? 20 : 24),
                        Text(
                          '📝 No tienes un plan nutricional asignado',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 18 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        Text(
                          'Para comenzar tu viaje nutricional, contacta a tu entrenador para que te asigne un plan personalizado.',
                          style: TextStyle(
                            color: AppTheme.lightGrey,
                            fontSize: isMobile ? 14 : 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isMobile ? 24 : 32),
                        ElevatedButton(
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryOrange,
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 24 : 32,
                              vertical: isMobile ? 12 : 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Reintentar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.primaryOrange,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TARJETA RESUMEN DEL PLAN
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.darkGrey,
                                AppTheme.darkBlack,
                              ],
                            ),
                            borderRadius:
                                BorderRadius.circular(isMobile ? 16 : 20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.assignment,
                                    color: AppTheme.primaryOrange,
                                    size: isMobile ? 20 : 24,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _nutritionPlans.first['name'] ??
                                          'Mi Plan Nutricional',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isMobile ? 18 : 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),

                              if (_nutritionPlans.first['description'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 28),
                                  child: Text(
                                    _nutritionPlans.first['description']!,
                                    style: TextStyle(
                                      color: AppTheme.lightGrey,
                                      fontSize: isMobile ? 13 : 15,
                                    ),
                                  ),
                                ),

                              SizedBox(height: isMobile ? 16 : 20),

                              // OBJETIVOS DIARIOS
                              Text(
                                '🎯 OBJETIVOS DIARIOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 14 : 16,
                                  letterSpacing: 1,
                                ),
                              ),
                              SizedBox(height: isMobile ? 12 : 16),

                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: isMobile ? 2 : 4,
                                childAspectRatio: isMobile ? 1.6 : 1.8,
                                mainAxisSpacing: isMobile ? 10 : 14,
                                crossAxisSpacing: isMobile ? 10 : 14,
                                children: [
                                  _buildDailyGoal(
                                    '🔥 Calorías',
                                    '${_nutritionPlans.first['daily_calories'] ?? 0}',
                                    'kcal',
                                    Icons.local_fire_department,
                                    Colors.orange,
                                    isMobile,
                                  ),
                                  _buildDailyGoal(
                                    'Proteína',
                                    '${_nutritionPlans.first['protein_grams'] ?? 0}',
                                    'gramos',
                                    Icons.fitness_center,
                                    Colors.blue,
                                    isMobile,
                                  ),
                                  _buildDailyGoal(
                                    'Carbohidratos',
                                    '${_nutritionPlans.first['carbs_grams'] ?? 0}',
                                    'gramos',
                                    Icons.grain,
                                    Colors.green,
                                    isMobile,
                                  ),
                                  _buildDailyGoal(
                                    '🥑 Grasas',
                                    '${_nutritionPlans.first['fat_grams'] ?? 0}',
                                    'gramos',
                                    Icons.opacity,
                                    Colors.yellow,
                                    isMobile,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: isMobile ? 24 : 32),

                        if (_meals.isNotEmpty) ...[
                          // COMIDAS POR DÍA
                          Text(
                            '🍽️ COMIDAS PROGRAMADAS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 16 : 18,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: isMobile ? 16 : 20),

                          ...groupedMeals.entries.map((entry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // CABECERA DEL DÍA
                                Container(
                                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkBlack,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.primaryOrange
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isMobile ? 10 : 14,
                                          vertical: isMobile ? 6 : 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryOrange
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppTheme.primaryOrange,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          isMobile
                                              ? _getDayShortName(entry.key)
                                              : _getDayName(entry.key),
                                          style: TextStyle(
                                            color: AppTheme.primaryOrange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isMobile ? 12 : 14,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        '${entry.value.length} ${entry.value.length == 1 ? 'comida' : 'comidas'}',
                                        style: TextStyle(
                                          color: AppTheme.lightGrey,
                                          fontSize: isMobile ? 12 : 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isMobile ? 12 : 16),

                                // LISTA DE COMIDAS
                                ...entry.value.asMap().entries.map((mealEntry) {
                                  final index = mealEntry.key;
                                  final meal = mealEntry.value;
                                  return Column(
                                    children: [
                                      Stack(
                                        children: [
                                          _buildMealCard(meal, isMobile),
                                          if (!isMobile)
                                            Positioned(
                                              left: -10,
                                              top: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 4,
                                                decoration: BoxDecoration(
                                                  color: _getMealColor(
                                                          meal['meal_type'])
                                                      .withOpacity(0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (index < entry.value.length - 1)
                                        SizedBox(height: isMobile ? 12 : 16),
                                    ],
                                  );
                                }).toList(),

                                SizedBox(height: isMobile ? 24 : 32),
                              ],
                            );
                          }).toList(),
                        ] else if (_hasPlan) ...[
                          // PLAN SIN COMIDAS
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.fastfood,
                                  size: isMobile ? 64 : 80,
                                  color: AppTheme.lightGrey.withOpacity(0.5),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No hay comidas programadas aún',
                                  style: TextStyle(
                                    color: AppTheme.lightGrey,
                                    fontSize: isMobile ? 16 : 18,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tu entrenador agregará comidas pronto',
                                  style: TextStyle(
                                    color: AppTheme.lightGrey,
                                    fontSize: isMobile ? 14 : 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: isMobile ? 32 : 48),

                        // PIE DE PÁGINA INFORMATIVO
                        Container(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          decoration: BoxDecoration(
                            color: AppTheme.darkBlack,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppTheme.primaryOrange,
                                    size: isMobile ? 16 : 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '💡 Consejo del día',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 14 : 16,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Mantén hidratación constante y distribuye tus comidas en 4-5 tiempos para mejor digestión.',
                                style: TextStyle(
                                  color: AppTheme.lightGrey,
                                  fontSize: isMobile ? 13 : 15,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: isMobile ? 20 : 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDailyGoal(String label, String value, String unit, IconData icon,
      Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: isMobile ? 20 : 24, color: color),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 18 : 22,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: isMobile ? 11 : 13,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2),
          Text(
            unit,
            style: TextStyle(
              color: AppTheme.lightGrey,
              fontSize: isMobile ? 10 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
