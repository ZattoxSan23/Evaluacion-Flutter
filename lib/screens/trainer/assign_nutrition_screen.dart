// lib/screens/trainer/assign_nutrition_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../widgets/gradient_button.dart';

class AssignNutritionScreen extends StatefulWidget {
  final String clientId;
  final Map<String, dynamic>? existingNutritionPlan;
  final Function()? onAssigned;

  const AssignNutritionScreen({
    super.key,
    required this.clientId,
    this.existingNutritionPlan,
    this.onAssigned,
  });

  @override
  State<AssignNutritionScreen> createState() => _AssignNutritionScreenState();
}

class _AssignNutritionScreenState extends State<AssignNutritionScreen> {
  final _planNameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController(text: '2000');
  final _proteinCtrl = TextEditingController(text: '150');
  final _carbsCtrl = TextEditingController(text: '250');
  final _fatCtrl = TextEditingController(text: '70');
  final _mealsPerDayCtrl = TextEditingController(text: '3');

  // Lista de comidas
  List<Map<String, dynamic>> _meals = [];
  List<Map<String, dynamic>> _nutritionTemplates = [];

  // Controladores para comidas
  final List<TextEditingController> _mealNameCtrls = [];
  final List<TextEditingController> _mealCaloriesCtrls = [];
  final List<TextEditingController> _mealProteinCtrls = [];
  final List<TextEditingController> _mealCarbsCtrls = [];
  final List<TextEditingController> _mealFatCtrls = [];
  final List<String> _mealTypes = [];
  final List<String> _mealDays = [];

  String _selectedTemplate = '';
  String _planType = 'custom'; // 'custom' o 'template'

  String? _editingPlanId; // ID del plan que se está editando

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadTemplates();
  }

  void _initializeForm() {
    // Si hay un plan existente, cargar sus datos
    if (widget.existingNutritionPlan != null) {
      final plan = widget.existingNutritionPlan!;
      _editingPlanId = plan['id'];

      _planNameCtrl.text = plan['name'] ?? '';
      _descriptionCtrl.text = plan['description'] ?? '';
      _caloriesCtrl.text = (plan['daily_calories'] ?? 2000).toString();
      _proteinCtrl.text = (plan['protein_grams'] ?? 150).toString();
      _carbsCtrl.text = (plan['carbs_grams'] ?? 250).toString();
      _fatCtrl.text = (plan['fat_grams'] ?? 70).toString();
      _mealsPerDayCtrl.text = (plan['meals_per_day'] ?? 3).toString();

      // Cargar comidas existentes
      final existingMeals = plan['nutrition_meals'] as List<dynamic>? ?? [];
      for (final meal in existingMeals) {
        _meals.add({
          'id': meal['id'],
          'temp_id': DateTime.now().millisecondsSinceEpoch.toString(),
        });
        _mealNameCtrls.add(TextEditingController(text: meal['name'] ?? ''));
        _mealCaloriesCtrls.add(
            TextEditingController(text: (meal['calories'] ?? 500).toString()));
        _mealProteinCtrls.add(TextEditingController(
            text: (meal['protein_grams'] ?? 30).toString()));
        _mealCarbsCtrls.add(TextEditingController(
            text: (meal['carbs_grams'] ?? 40).toString()));
        _mealFatCtrls.add(
            TextEditingController(text: (meal['fat_grams'] ?? 20).toString()));
        _mealTypes.add(meal['meal_type'] ?? 'lunch');
        _mealDays.add(meal['day_of_week'] ?? 'monday');
      }
    }
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);

    try {
      final templates = await supabase
          .from('nutrition_templates')
          .select('''
          *,
          template_meals(*)
        ''')
          .or('is_public.eq.true,trainer_id.eq.${supabase.auth.currentUser!.id}')
          .order('name');

      if (mounted) {
        setState(() {
          _nutritionTemplates = List<Map<String, dynamic>>.from(templates);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando plantillas: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar plantillas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addMeal() {
    setState(() {
      _meals.add({
        'temp_id': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      _mealNameCtrls.add(TextEditingController());
      _mealCaloriesCtrls.add(TextEditingController(text: '500'));
      _mealProteinCtrls.add(TextEditingController(text: '30'));
      _mealCarbsCtrls.add(TextEditingController(text: '40'));
      _mealFatCtrls.add(TextEditingController(text: '20'));
      _mealTypes.add('lunch');
      _mealDays.add('monday');
    });
  }

  void _removeMeal(int index) {
    setState(() {
      _meals.removeAt(index);
      _mealNameCtrls.removeAt(index);
      _mealCaloriesCtrls.removeAt(index);
      _mealProteinCtrls.removeAt(index);
      _mealCarbsCtrls.removeAt(index);
      _mealFatCtrls.removeAt(index);
      _mealTypes.removeAt(index);
      _mealDays.removeAt(index);
    });
  }

  void _loadTemplate(String templateId) {
    final template = _nutritionTemplates.firstWhere(
      (t) => t['id'] == templateId,
    );

    setState(() {
      _planNameCtrl.text = template['name'];
      _descriptionCtrl.text = template['description'] ?? '';
      _caloriesCtrl.text = (template['daily_calories'] ?? '2000').toString();
      _proteinCtrl.text = (template['protein_grams'] ?? '150').toString();
      _carbsCtrl.text = (template['carbs_grams'] ?? '250').toString();
      _fatCtrl.text = (template['fat_grams'] ?? '70').toString();
      _mealsPerDayCtrl.text = (template['meals_per_day'] ?? '3').toString();

      _meals.clear();
      _mealNameCtrls.clear();
      _mealCaloriesCtrls.clear();
      _mealProteinCtrls.clear();
      _mealCarbsCtrls.clear();
      _mealFatCtrls.clear();
      _mealTypes.clear();
      _mealDays.clear();

      final templateMeals = template['template_meals'] as List;
      for (final tempMeal in templateMeals) {
        _meals.add({
          'temp_id': DateTime.now().millisecondsSinceEpoch.toString(),
        });
        _mealNameCtrls.add(TextEditingController(text: tempMeal['name'] ?? ''));
        _mealCaloriesCtrls.add(TextEditingController(
            text: (tempMeal['calories'] ?? '500').toString()));
        _mealProteinCtrls.add(TextEditingController(
            text: (tempMeal['protein_grams'] ?? '30').toString()));
        _mealCarbsCtrls.add(TextEditingController(
            text: (tempMeal['carbs_grams'] ?? '40').toString()));
        _mealFatCtrls.add(TextEditingController(
            text: (tempMeal['fat_grams'] ?? '20').toString()));
        _mealTypes.add(tempMeal['meal_type'] ?? 'lunch');
        _mealDays.add(tempMeal['day_of_week'] ?? 'monday');
      }
    });
  }

  int _calculateTotalCalories() {
    int total = 0;
    for (final ctrl in _mealCaloriesCtrls) {
      total += int.tryParse(ctrl.text) ?? 0;
    }
    return total;
  }

  Future<void> _saveNutritionPlan() async {
    if (_planNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del plan es requerido')),
      );
      return;
    }

    if (_meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes agregar al menos una comida')),
      );
      return;
    }

    final totalCalories = _calculateTotalCalories();
    final dailyCalories = int.tryParse(_caloriesCtrl.text) ?? 2000;

    if (totalCalories > dailyCalories * 1.1) {
      final confirmed = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Calorías excedidas'),
          content: Text(
            'El total de calorías de las comidas ($totalCalories kcal) '
            'excede el objetivo diario ($dailyCalories kcal). '
            '¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Revisar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final trainerId = supabase.auth.currentUser!.id;

      if (_editingPlanId == null) {
        // CREAR NUEVO PLAN
        // 1. Desactivar planes anteriores del cliente
        await supabase
            .from('nutrition_plans')
            .update({'status': 'completed'})
            .eq('client_id', widget.clientId)
            .eq('status', 'active');

        // 2. Crear el nuevo plan nutricional
        final planResponse = await supabase
            .from('nutrition_plans')
            .insert({
              'client_id': widget.clientId,
              'trainer_id': trainerId,
              'name': _planNameCtrl.text,
              'description': _descriptionCtrl.text.isNotEmpty
                  ? _descriptionCtrl.text
                  : null,
              'daily_calories': int.tryParse(_caloriesCtrl.text) ?? 2000,
              'protein_grams': int.tryParse(_proteinCtrl.text) ?? 150,
              'carbs_grams': int.tryParse(_carbsCtrl.text) ?? 250,
              'fat_grams': int.tryParse(_fatCtrl.text) ?? 70,
              'meals_per_day': int.tryParse(_mealsPerDayCtrl.text) ?? 3,
              'start_date': DateTime.now().toIso8601String().split('T')[0],
              'status': 'active',
            })
            .select('id')
            .single();

        final planId = planResponse['id'];

        // 3. Agregar las comidas al plan
        for (int i = 0; i < _meals.length; i++) {
          await supabase.from('nutrition_meals').insert({
            'plan_id': planId,
            'meal_type': _mealTypes[i],
            'name': _mealNameCtrls[i].text,
            'calories': int.tryParse(_mealCaloriesCtrls[i].text) ?? 500,
            'protein_grams': int.tryParse(_mealProteinCtrls[i].text) ?? 30,
            'carbs_grams': int.tryParse(_mealCarbsCtrls[i].text) ?? 40,
            'fat_grams': int.tryParse(_mealFatCtrls[i].text) ?? 20,
            'day_of_week': _mealDays[i],
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Plan "${_planNameCtrl.text}" creado exitosamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // EDITAR PLAN EXISTENTE
        // 1. Actualizar el plan nutricional
        await supabase.from('nutrition_plans').update({
          'name': _planNameCtrl.text,
          'description':
              _descriptionCtrl.text.isNotEmpty ? _descriptionCtrl.text : null,
          'daily_calories': int.tryParse(_caloriesCtrl.text) ?? 2000,
          'protein_grams': int.tryParse(_proteinCtrl.text) ?? 150,
          'carbs_grams': int.tryParse(_carbsCtrl.text) ?? 250,
          'fat_grams': int.tryParse(_fatCtrl.text) ?? 70,
          'meals_per_day': int.tryParse(_mealsPerDayCtrl.text) ?? 3,
          'last_updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _editingPlanId!);

        // 2. Eliminar comidas existentes
        await supabase
            .from('nutrition_meals')
            .delete()
            .eq('plan_id', _editingPlanId!);

        // 3. Agregar las comidas actualizadas
        for (int i = 0; i < _meals.length; i++) {
          await supabase.from('nutrition_meals').insert({
            'plan_id': _editingPlanId!,
            'meal_type': _mealTypes[i],
            'name': _mealNameCtrls[i].text,
            'calories': int.tryParse(_mealCaloriesCtrls[i].text) ?? 500,
            'protein_grams': int.tryParse(_mealProteinCtrls[i].text) ?? 30,
            'carbs_grams': int.tryParse(_mealCarbsCtrls[i].text) ?? 40,
            'fat_grams': int.tryParse(_mealFatCtrls[i].text) ?? 20,
            'day_of_week': _mealDays[i],
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ Plan "${_planNameCtrl.text}" actualizado exitosamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      if (widget.onAssigned != null) {
        widget.onAssigned!();
      }

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error al guardar plan nutricional: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget _buildMacroSummary() {
    final totalCalories = _calculateTotalCalories();
    final dailyCalories = int.tryParse(_caloriesCtrl.text) ?? 2000;
    final protein = int.tryParse(_proteinCtrl.text) ?? 150;
    final carbs = int.tryParse(_carbsCtrl.text) ?? 250;
    final fat = int.tryParse(_fatCtrl.text) ?? 70;

    return Card(
      color: AppTheme.darkGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de Macros',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            SizedBox(height: 16),

            // Calorías
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$dailyCalories',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Objetivo kcal',
                        style: TextStyle(color: AppTheme.lightGrey),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$totalCalories',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: totalCalories <= dailyCalories
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      Text(
                        'Comidas kcal',
                        style: TextStyle(color: AppTheme.lightGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Macros
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${protein}g',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        'Proteína',
                        style: TextStyle(color: AppTheme.lightGrey),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${carbs}g',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Carbohidratos',
                        style: TextStyle(color: AppTheme.lightGrey),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${fat}g',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        'Grasas',
                        style: TextStyle(color: AppTheme.lightGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(int index) {
    return Card(
      color: AppTheme.darkGrey,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Comida ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _removeMeal(index),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Tipo de comida
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.darkBlack,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _mealTypes[index],
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down,
                      size: 20, color: AppTheme.primaryOrange),
                  dropdownColor: AppTheme.darkGrey,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  items: [
                    DropdownMenuItem(
                      value: 'breakfast',
                      child: Row(
                        children: [
                          Icon(Icons.wb_sunny, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Desayuno'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'lunch',
                      child: Row(
                        children: [
                          Icon(Icons.lunch_dining,
                              size: 16, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Almuerzo'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'dinner',
                      child: Row(
                        children: [
                          Icon(Icons.nightlight, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Cena'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'snack',
                      child: Row(
                        children: [
                          Icon(Icons.local_cafe,
                              size: 16, color: Colors.yellow),
                          SizedBox(width: 8),
                          Text('Snack'),
                        ],
                      ),
                    ),
                  ].toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _mealTypes[index] = value);
                    }
                  },
                ),
              ),
            ),

            SizedBox(height: 8),

            // Nombre de la comida
            TextField(
              controller: _mealNameCtrls[index],
              decoration: InputDecoration(
                labelText: 'Nombre de la comida *',
                labelStyle: TextStyle(color: AppTheme.lightGrey),
                filled: true,
                fillColor: AppTheme.darkBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.all(12),
              ),
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),

            SizedBox(height: 8),

            // Macros de la comida
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calorías',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.lightGrey),
                      ),
                      TextField(
                        controller: _mealCaloriesCtrls[index],
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '500',
                          hintStyle: TextStyle(color: AppTheme.lightGrey),
                          filled: true,
                          fillColor: AppTheme.darkBlack,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.all(8),
                        ),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proteína (g)',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.lightGrey),
                      ),
                      TextField(
                        controller: _mealProteinCtrls[index],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '30',
                          hintStyle: TextStyle(color: AppTheme.lightGrey),
                          filled: true,
                          fillColor: AppTheme.darkBlack,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.all(8),
                        ),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carbos (g)',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.lightGrey),
                      ),
                      TextField(
                        controller: _mealCarbsCtrls[index],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '40',
                          hintStyle: TextStyle(color: AppTheme.lightGrey),
                          filled: true,
                          fillColor: AppTheme.darkBlack,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.all(8),
                        ),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grasas (g)',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.lightGrey),
                      ),
                      TextField(
                        controller: _mealFatCtrls[index],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '20',
                          hintStyle: TextStyle(color: AppTheme.lightGrey),
                          filled: true,
                          fillColor: AppTheme.darkBlack,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.all(8),
                        ),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 8),

            // Día de la semana
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.darkBlack,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _mealDays[index],
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down,
                      size: 20, color: AppTheme.primaryOrange),
                  dropdownColor: AppTheme.darkGrey,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  items: [
                    DropdownMenuItem(
                      value: 'monday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Lunes'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'tuesday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Martes'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'wednesday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Miércoles'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'thursday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.purple),
                          SizedBox(width: 8),
                          Text('Jueves'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'friday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Viernes'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'saturday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.yellow),
                          SizedBox(width: 8),
                          Text('Sábado'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'sunday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('Domingo'),
                        ],
                      ),
                    ),
                  ].toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _mealDays[index] = value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editingPlanId == null
            ? 'Asignar Plan Nutricional'
            : 'Editar Plan Nutricional'),
        backgroundColor: AppTheme.darkBlack,
        actions: [
          if (_meals.isNotEmpty)
            TextButton.icon(
              icon: Icon(Icons.restaurant),
              label: Text('${_meals.length} comidas'),
              onPressed: null,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryOrange,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selección de tipo
                  Card(
                    color: AppTheme.darkGrey,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tipo de Plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: Text('Crear Personalizado'),
                                  selected: _planType == 'custom',
                                  selectedColor: AppTheme.primaryOrange,
                                  onSelected: (selected) {
                                    setState(() => _planType = 'custom');
                                  },
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: ChoiceChip(
                                  label: Text('Usar Plantilla'),
                                  selected: _planType == 'template',
                                  selectedColor: AppTheme.primaryOrange,
                                  onSelected: (selected) {
                                    setState(() => _planType = 'template');
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Nombre y descripción
                  Card(
                    color: AppTheme.darkGrey,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Información del Plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 16),
                          TextField(
                            controller: _planNameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Nombre del plan *',
                              labelStyle: TextStyle(color: AppTheme.lightGrey),
                              filled: true,
                              fillColor: AppTheme.darkBlack,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(Icons.restaurant,
                                  color: AppTheme.primaryOrange),
                            ),
                            style: TextStyle(color: Colors.white),
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _descriptionCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Descripción (opcional)',
                              labelStyle: TextStyle(color: AppTheme.lightGrey),
                              filled: true,
                              fillColor: AppTheme.darkBlack,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(Icons.description,
                                  color: AppTheme.primaryOrange),
                            ),
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Macros diarios
                  Card(
                    color: AppTheme.darkGrey,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Objetivos Diarios',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Calorías',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.lightGrey),
                                    ),
                                    TextField(
                                      controller: _caloriesCtrl,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        hintText: '2000',
                                        hintStyle: TextStyle(
                                            color: AppTheme.lightGrey),
                                        filled: true,
                                        fillColor: AppTheme.darkBlack,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: EdgeInsets.all(12),
                                      ),
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Comidas/día',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.lightGrey),
                                    ),
                                    TextField(
                                      controller: _mealsPerDayCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: '3',
                                        hintStyle: TextStyle(
                                            color: AppTheme.lightGrey),
                                        filled: true,
                                        fillColor: AppTheme.darkBlack,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: EdgeInsets.all(12),
                                      ),
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Proteína (g)',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.lightGrey),
                                    ),
                                    TextField(
                                      controller: _proteinCtrl,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        hintText: '150',
                                        hintStyle: TextStyle(
                                            color: AppTheme.lightGrey),
                                        filled: true,
                                        fillColor: AppTheme.darkBlack,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: EdgeInsets.all(12),
                                      ),
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Carbohidratos (g)',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.lightGrey),
                                    ),
                                    TextField(
                                      controller: _carbsCtrl,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        hintText: '250',
                                        hintStyle: TextStyle(
                                            color: AppTheme.lightGrey),
                                        filled: true,
                                        fillColor: AppTheme.darkBlack,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: EdgeInsets.all(12),
                                      ),
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grasas (g)',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.lightGrey),
                              ),
                              TextField(
                                controller: _fatCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: '70',
                                  hintStyle:
                                      TextStyle(color: AppTheme.lightGrey),
                                  filled: true,
                                  fillColor: AppTheme.darkBlack,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.all(12),
                                ),
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Resumen de macros
                  _buildMacroSummary(),

                  SizedBox(height: 24),

                  // Plantillas (si se seleccionó)
                  if (_planType == 'template') ...[
                    Card(
                      color: AppTheme.darkGrey,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.layers,
                                    color: AppTheme.primaryOrange),
                                SizedBox(width: 8),
                                Text(
                                  'Seleccionar Plantilla',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Spacer(),
                                Chip(
                                  label: Text(
                                      '${_nutritionTemplates.length} disponibles'),
                                  backgroundColor: Colors.blue.withOpacity(0.2),
                                  labelStyle: TextStyle(color: Colors.blue),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            if (_nutritionTemplates.isEmpty)
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.layers_outlined,
                                        size: 48, color: AppTheme.lightGrey),
                                    SizedBox(height: 16),
                                    Text(
                                      'No hay plantillas disponibles',
                                      style:
                                          TextStyle(color: AppTheme.lightGrey),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkGrey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedTemplate.isEmpty
                                        ? null
                                        : _selectedTemplate,
                                    isExpanded: true,
                                    hint: Text(
                                      'Selecciona una plantilla',
                                      style:
                                          TextStyle(color: AppTheme.lightGrey),
                                    ),
                                    icon: Icon(Icons.arrow_drop_down,
                                        color: AppTheme.primaryOrange),
                                    dropdownColor: AppTheme.darkGrey,
                                    style: TextStyle(color: Colors.white),
                                    items: _nutritionTemplates
                                        .map<DropdownMenuItem<String>>(
                                            (template) {
                                      final String templateId =
                                          template['id'].toString();

                                      return DropdownMenuItem<String>(
                                        value: templateId,
                                        child: Row(
                                          children: [
                                            Icon(Icons.restaurant_menu,
                                                size: 20),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    template['name']
                                                            as String? ??
                                                        'Plantilla sin nombre',
                                                  ),
                                                  if (template['description'] !=
                                                      null)
                                                    Text(
                                                      template['description']
                                                          as String,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            AppTheme.lightGrey,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (template['is_public'] == true)
                                              Icon(Icons.public,
                                                  size: 16, color: Colors.blue),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(
                                            () => _selectedTemplate = value);
                                        _loadTemplate(value);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            if (_selectedTemplate.isNotEmpty) ...[
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: Icon(Icons.refresh),
                                label: Text('Limpiar plantilla'),
                                onPressed: () {
                                  setState(() {
                                    _selectedTemplate = '';
                                    _planNameCtrl.clear();
                                    _descriptionCtrl.clear();
                                    _meals.clear();
                                    _mealNameCtrls.clear();
                                    _mealCaloriesCtrls.clear();
                                    _mealProteinCtrls.clear();
                                    _mealCarbsCtrls.clear();
                                    _mealFatCtrls.clear();
                                    _mealTypes.clear();
                                    _mealDays.clear();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.orange.withOpacity(0.2),
                                  foregroundColor: Colors.orange,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Comidas seleccionadas
                  if (_meals.isNotEmpty) ...[
                    Card(
                      color: AppTheme.darkGrey,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.list, color: AppTheme.primaryOrange),
                                SizedBox(width: 8),
                                Text(
                                  'Comidas del Plan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Spacer(),
                                Chip(
                                  label: Text('${_meals.length} comidas'),
                                  backgroundColor:
                                      Colors.green.withOpacity(0.2),
                                  labelStyle: TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            ...List.generate(
                              _meals.length,
                              (index) => Column(
                                children: [
                                  _buildMealCard(index),
                                  if (index < _meals.length - 1)
                                    SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Botón para agregar comida
                  Card(
                    color: AppTheme.darkGrey,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agregar Comida',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.add_circle),
                              label: Text('Agregar Nueva Comida'),
                              onPressed: _addMeal,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryOrange,
                                side: BorderSide(color: AppTheme.primaryOrange),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 32),

                  // Botón de guardar
                  GradientButton(
                    text: _isSubmitting
                        ? 'Guardando...'
                        : (_editingPlanId == null
                            ? 'Guardar Plan Nutricional'
                            : 'Actualizar Plan'),
                    onPressed: _isSubmitting ? null : _saveNutritionPlan,
                    isLoading: _isSubmitting,
                    gradientColors: [
                      AppTheme.primaryOrange,
                      AppTheme.orangeAccent
                    ],
                  ),

                  SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _planNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _mealsPerDayCtrl.dispose();
    for (final ctrl in _mealNameCtrls) ctrl.dispose();
    for (final ctrl in _mealCaloriesCtrls) ctrl.dispose();
    for (final ctrl in _mealProteinCtrls) ctrl.dispose();
    for (final ctrl in _mealCarbsCtrls) ctrl.dispose();
    for (final ctrl in _mealFatCtrls) ctrl.dispose();
    super.dispose();
  }
}
