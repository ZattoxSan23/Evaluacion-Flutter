// screens/trainer/create_template_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../widgets/gradient_button.dart';

class CreateTemplateScreen extends StatefulWidget {
  final Map<String, dynamic>? existingTemplate;
  final Function()? onSaved;

  const CreateTemplateScreen({
    super.key,
    this.existingTemplate,
    this.onSaved,
  });

  @override
  State<CreateTemplateScreen> createState() => _CreateTemplateScreenState();
}

class _CreateTemplateScreenState extends State<CreateTemplateScreen> {
  final _templateNameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController(text: '2000');
  final _proteinCtrl = TextEditingController(text: '150');
  final _carbsCtrl = TextEditingController(text: '250');
  final _fatCtrl = TextEditingController(text: '70');
  final _mealsPerDayCtrl = TextEditingController(text: '3');

  List<Map<String, dynamic>> _meals = [];
  final List<TextEditingController> _mealNameCtrls = [];
  final List<TextEditingController> _mealCaloriesCtrls = [];
  final List<TextEditingController> _mealProteinCtrls = [];
  final List<TextEditingController> _mealCarbsCtrls = [];
  final List<TextEditingController> _mealFatCtrls = [];
  final List<String> _mealTypes = [];
  final List<String> _mealDays = [];

  bool _isPublic = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingTemplate != null) {
      _loadExistingTemplate();
    } else {
      _addMeal(); // Agregar una comida por defecto
    }
  }

  void _loadExistingTemplate() {
    final template = widget.existingTemplate!;

    setState(() {
      _templateNameCtrl.text = template['name'];
      _descriptionCtrl.text = template['description'] ?? '';
      _caloriesCtrl.text = (template['daily_calories'] ?? '2000').toString();
      _proteinCtrl.text = (template['protein_grams'] ?? '150').toString();
      _carbsCtrl.text = (template['carbs_grams'] ?? '250').toString();
      _fatCtrl.text = (template['fat_grams'] ?? '70').toString();
      _mealsPerDayCtrl.text = (template['meals_per_day'] ?? '3').toString();
      _isPublic = template['is_public'] == true;

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
        _meals
            .add({'temp_id': DateTime.now().millisecondsSinceEpoch.toString()});
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

  Future<void> _saveTemplate() async {
    if (_templateNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre de la plantilla es requerido')),
      );
      return;
    }

    if (_meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes agregar al menos una comida')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final templateData = {
        'trainer_id': supabase.auth.currentUser!.id,
        'name': _templateNameCtrl.text,
        'description':
            _descriptionCtrl.text.isNotEmpty ? _descriptionCtrl.text : null,
        'daily_calories': int.tryParse(_caloriesCtrl.text) ?? 2000,
        'protein_grams': int.tryParse(_proteinCtrl.text) ?? 150,
        'carbs_grams': int.tryParse(_carbsCtrl.text) ?? 250,
        'fat_grams': int.tryParse(_fatCtrl.text) ?? 70,
        'meals_per_day': int.tryParse(_mealsPerDayCtrl.text) ?? 3,
        'is_public': _isPublic,
      };

      String templateId;

      if (widget.existingTemplate != null) {
        // Actualizar plantilla existente
        templateId = widget.existingTemplate!['id'];
        await supabase
            .from('nutrition_templates')
            .update(templateData)
            .eq('id', templateId)
            .eq('trainer_id', supabase.auth.currentUser!.id);

        // Eliminar comidas antiguas
        await supabase
            .from('template_meals')
            .delete()
            .eq('template_id', templateId);
      } else {
        // Crear nueva plantilla
        final response = await supabase
            .from('nutrition_templates')
            .insert(templateData)
            .select('id')
            .single();
        templateId = response['id'];
      }

      // Agregar comidas
      for (int i = 0; i < _meals.length; i++) {
        await supabase.from('template_meals').insert({
          'template_id': templateId,
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
          content: Text(
            widget.existingTemplate != null
                ? '✅ Plantilla actualizada'
                : '✅ Plantilla creada exitosamente',
          ),
          backgroundColor: Colors.green,
        ),
      );

      if (widget.onSaved != null) {
        widget.onSaved!();
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget _buildMealCard(int index) {
    return Card(
      color: AppTheme.darkGrey,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Comida', style: TextStyle(color: Colors.white)),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBlack,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _mealTypes[index],
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down,
                            size: 16, color: AppTheme.primaryOrange),
                        dropdownColor: AppTheme.darkGrey,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        items: const [
                          DropdownMenuItem(
                              value: 'breakfast', child: Text('Desayuno')),
                          DropdownMenuItem(
                              value: 'lunch', child: Text('Almuerzo')),
                          DropdownMenuItem(
                              value: 'dinner', child: Text('Cena')),
                          DropdownMenuItem(
                              value: 'snack', child: Text('Snack')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _mealTypes[index] = value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _removeMeal(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mealNameCtrls[index],
              decoration: InputDecoration(
                labelText: 'Nombre de la comida',
                labelStyle: const TextStyle(color: AppTheme.lightGrey),
                filled: true,
                fillColor: AppTheme.darkBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mealCaloriesCtrls[index],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Calorías',
                      labelStyle: const TextStyle(color: AppTheme.lightGrey),
                      filled: true,
                      fillColor: AppTheme.darkBlack,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _mealProteinCtrls[index],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Proteína (g)',
                      labelStyle: const TextStyle(color: AppTheme.lightGrey),
                      filled: true,
                      fillColor: AppTheme.darkBlack,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
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
        title: Text(widget.existingTemplate != null
            ? 'Editar Plantilla'
            : 'Crear Plantilla'),
        backgroundColor: AppTheme.darkBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: AppTheme.darkGrey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _templateNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la plantilla *',
                        labelStyle: const TextStyle(color: AppTheme.lightGrey),
                        filled: true,
                        fillColor: AppTheme.darkBlack,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        labelStyle: const TextStyle(color: AppTheme.lightGrey),
                        filled: true,
                        fillColor: AppTheme.darkBlack,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: AppTheme.darkGrey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Objetivos Diarios',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _caloriesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Calorías',
                              labelStyle:
                                  const TextStyle(color: AppTheme.lightGrey),
                              filled: true,
                              fillColor: AppTheme.darkBlack,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _mealsPerDayCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Comidas/día',
                              labelStyle:
                                  const TextStyle(color: AppTheme.lightGrey),
                              filled: true,
                              fillColor: AppTheme.darkBlack,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
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
                            controller: _proteinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Proteína (g)',
                              labelStyle:
                                  const TextStyle(color: AppTheme.lightGrey),
                              filled: true,
                              fillColor: AppTheme.darkBlack,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _carbsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Carbohidratos (g)',
                              labelStyle:
                                  const TextStyle(color: AppTheme.lightGrey),
                              filled: true,
                              fillColor: AppTheme.darkBlack,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fatCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Grasas (g)',
                        labelStyle: const TextStyle(color: AppTheme.lightGrey),
                        filled: true,
                        fillColor: AppTheme.darkBlack,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Plantilla pública',
                          style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Visible para otros entrenadores',
                          style: TextStyle(color: AppTheme.lightGrey)),
                      value: _isPublic,
                      onChanged: (value) => setState(() => _isPublic = value),
                      activeColor: AppTheme.primaryOrange,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: AppTheme.darkGrey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Comidas',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text('${_meals.length} comidas',
                            style: const TextStyle(color: AppTheme.lightGrey)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                        _meals.length,
                        (index) => Column(
                              children: [
                                _buildMealCard(index),
                                if (index < _meals.length - 1)
                                  const SizedBox(height: 12),
                              ],
                            )),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Comida'),
                      onPressed: _addMeal,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryOrange,
                        side: BorderSide(color: AppTheme.primaryOrange),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: _isSubmitting ? 'Guardando...' : 'Guardar Plantilla',
              onPressed: _isSubmitting ? null : _saveTemplate,
              isLoading: _isSubmitting,
              gradientColors: [AppTheme.primaryOrange, AppTheme.orangeAccent],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _templateNameCtrl.dispose();
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
