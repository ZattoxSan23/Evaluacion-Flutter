import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../widgets/gradient_button.dart';

class AssignRoutineScreen extends StatefulWidget {
  final String clientId;
  final Map<String, dynamic>? existingRoutine; // Rutina existente para editar
  final Function()? onAssigned;

  const AssignRoutineScreen({
    super.key,
    required this.clientId,
    this.existingRoutine,
    this.onAssigned,
  });

  @override
  State<AssignRoutineScreen> createState() => _AssignRoutineScreenState();
}

class _AssignRoutineScreenState extends State<AssignRoutineScreen> {
  final _routineNameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  // Listas de ejercicios
  List<Map<String, dynamic>> _availableExercises = [];
  List<Map<String, dynamic>> _selectedExercises = [];
  List<Map<String, dynamic>> _routineTemplates = [];

  // Controladores para cada ejercicio
  final List<TextEditingController> _setsCtrls = [];
  final List<TextEditingController> _repsCtrls = [];
  final List<TextEditingController> _durationCtrls = [];
  final List<TextEditingController> _restTimeCtrls = [];
  final List<String> _selectedDays = [];
  final List<String> _selectedExerciseTypes = [];

  // Búsqueda y filtros
  final _searchCtrl = TextEditingController();
  String _selectedMuscleGroup = 'Todos';
  String _selectedTemplate = '';
  String _routineType = 'custom';

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Cargar ejercicios disponibles
      final exercises =
          await supabase.from('exercises').select('*').order('name');

      // Cargar plantillas de rutinas
      final templates = await supabase.from('routine_templates').select('''
            *,
            template_exercises(
              *,
              exercises(*)
            )
          ''').or('is_public.eq.true,trainer_id.eq.${supabase.auth.currentUser!.id}');

      // Si hay una rutina existente, cargarla
      if (widget.existingRoutine != null) {
        _loadExistingRoutine();
      }

      if (mounted) {
        setState(() {
          _availableExercises = List.from(exercises);
          _routineTemplates = List.from(templates);
          _isLoading = false;
        });
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

  void _loadExistingRoutine() {
    final routine = widget.existingRoutine;
    setState(() {
      _routineNameCtrl.text = routine!['name'] ?? '';
      _descriptionCtrl.text = routine['description'] ?? '';

      // Cargar ejercicios existentes
      final exercises = routine['routine_exercises'] as List;
      _selectedExercises.clear();
      _setsCtrls.clear();
      _repsCtrls.clear();
      _durationCtrls.clear();
      _restTimeCtrls.clear();
      _selectedDays.clear();
      _selectedExerciseTypes.clear();

      for (final ex in exercises) {
        final exerciseData = ex['exercises'];
        if (exerciseData != null) {
          final exerciseType = ex['exercise_type'] ?? 'reps';
          final isTimeBased = exerciseType == 'time';

          _selectedExercises.add({
            ...exerciseData,
            'temp_id': DateTime.now().millisecondsSinceEpoch.toString(),
          });
          _setsCtrls
              .add(TextEditingController(text: ex['sets']?.toString() ?? '3'));

          if (isTimeBased) {
            _repsCtrls.add(TextEditingController());
            _durationCtrls.add(TextEditingController(
                text: ex['duration_seconds']?.toString() ?? '30'));
          } else {
            _repsCtrls.add(TextEditingController(text: ex['reps'] ?? '10-12'));
            _durationCtrls.add(TextEditingController());
          }

          _restTimeCtrls.add(
              TextEditingController(text: ex['rest_time']?.toString() ?? '60'));
          _selectedDays.add(ex['day_of_week'] ?? 'monday');
          _selectedExerciseTypes.add(exerciseType);
        }
      }
    });
  }

  List<Map<String, dynamic>> _getFilteredExercises() {
    var filtered = _availableExercises;

    if (_selectedMuscleGroup != 'Todos') {
      filtered = filtered
          .where((ex) => ex['muscle_group'] == _selectedMuscleGroup)
          .toList();
    }

    final query = _searchCtrl.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      filtered = filtered
          .where((ex) => ex['name'].toLowerCase().contains(query))
          .toList();
    }

    return filtered;
  }

  List<String> _getMuscleGroups() {
    final groups = _availableExercises
        .map((ex) => ex['muscle_group'] as String?)
        .where((group) => group != null && group.isNotEmpty)
        .toSet()
        .cast<String>()
        .toList()
      ..sort();

    return ['Todos', ...groups];
  }

  void _addExercise(Map<String, dynamic> exercise) {
    final exerciseType = exercise['exercise_type'] ?? 'reps';
    final isTimeBased = exerciseType == 'time';

    setState(() {
      _selectedExercises.add({
        ...exercise,
        'temp_id': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      _setsCtrls.add(TextEditingController(text: '3'));

      if (isTimeBased) {
        _repsCtrls.add(TextEditingController());
        _durationCtrls.add(TextEditingController(text: '30'));
      } else {
        _repsCtrls.add(TextEditingController(text: '10-12'));
        _durationCtrls.add(TextEditingController());
      }

      _restTimeCtrls.add(TextEditingController(text: '60'));
      _selectedDays.add('monday');
      _selectedExerciseTypes.add(exerciseType);
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _selectedExercises.removeAt(index);
      _setsCtrls.removeAt(index);
      _repsCtrls.removeAt(index);
      _durationCtrls.removeAt(index);
      _restTimeCtrls.removeAt(index);
      _selectedDays.removeAt(index);
      _selectedExerciseTypes.removeAt(index);
    });
  }

  void _toggleExerciseType(int index) {
    setState(() {
      final newType = _selectedExerciseTypes[index] == 'reps' ? 'time' : 'reps';
      _selectedExerciseTypes[index] = newType;

      if (newType == 'time') {
        _durationCtrls[index].text = '30';
        _repsCtrls[index].clear();
      } else {
        _repsCtrls[index].text = '10-12';
        _durationCtrls[index].clear();
      }
    });
  }

  void _loadTemplate(String templateId) {
    final template = _routineTemplates.firstWhere(
      (t) => t['id'] == templateId,
    );

    setState(() {
      _routineNameCtrl.text = template['name'];
      _descriptionCtrl.text = template['description'] ?? '';
      _selectedExercises.clear();
      _setsCtrls.clear();
      _repsCtrls.clear();
      _durationCtrls.clear();
      _restTimeCtrls.clear();
      _selectedDays.clear();
      _selectedExerciseTypes.clear();

      final templateExercises = template['template_exercises'] as List;
      for (final tempEx in templateExercises) {
        final exercise = tempEx['exercises'];
        if (exercise != null) {
          final exerciseType =
              tempEx['exercise_type'] ?? exercise['exercise_type'] ?? 'reps';
          final isTimeBased = exerciseType == 'time';

          _selectedExercises.add({
            ...exercise,
            'temp_id': DateTime.now().millisecondsSinceEpoch.toString(),
          });
          _setsCtrls.add(
              TextEditingController(text: tempEx['sets']?.toString() ?? '3'));

          if (isTimeBased) {
            _repsCtrls.add(TextEditingController());
            _durationCtrls.add(TextEditingController(
                text: tempEx['duration_seconds']?.toString() ?? '30'));
          } else {
            _repsCtrls
                .add(TextEditingController(text: tempEx['reps'] ?? '10-12'));
            _durationCtrls.add(TextEditingController());
          }

          _restTimeCtrls.add(TextEditingController(
              text: tempEx['rest_time']?.toString() ?? '60'));
          _selectedDays.add(tempEx['day_of_week'] ?? 'monday');
          _selectedExerciseTypes.add(exerciseType);
        }
      }
    });
  }

  Future<void> _saveRoutine() async {
    if (_routineNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre de la rutina es requerido')),
      );
      return;
    }

    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes agregar al menos un ejercicio')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final trainerId = supabase.auth.currentUser!.id;
      final now = DateTime.now();

      // Verificar si ya existe una rutina activa
      final existingRoutines = await supabase
          .from('routines')
          .select('id')
          .eq('client_id', widget.clientId)
          .eq('status', 'active');

      if (widget.existingRoutine != null) {
        // EDITAR RUTINA EXISTENTE
        final routineId = widget.existingRoutine!['id'];

        // 1. Actualizar la rutina
        await supabase.from('routines').update({
          'name': _routineNameCtrl.text,
          'description':
              _descriptionCtrl.text.isNotEmpty ? _descriptionCtrl.text : null,
          'last_updated_at': now.toIso8601String(),
        }).eq('id', routineId);

        // 2. Eliminar ejercicios existentes
        await supabase
            .from('routine_exercises')
            .delete()
            .eq('routine_id', routineId);

        // 3. Agregar los nuevos ejercicios
        for (int i = 0; i < _selectedExercises.length; i++) {
          final exercise = _selectedExercises[i];
          final isTimeBased = _selectedExerciseTypes[i] == 'time';

          await supabase.from('routine_exercises').insert({
            'routine_id': routineId,
            'exercise_id': exercise['id'],
            'sets': int.tryParse(_setsCtrls[i].text) ?? 3,
            'reps': isTimeBased ? null : _repsCtrls[i].text,
            'duration_seconds':
                isTimeBased ? int.tryParse(_durationCtrls[i].text) ?? 30 : null,
            'exercise_type': _selectedExerciseTypes[i],
            'rest_time': int.tryParse(_restTimeCtrls[i].text) ?? 60,
            'day_of_week': _selectedDays[i],
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Rutina "${_routineNameCtrl.text}" actualizada exitosamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // CREAR NUEVA RUTINA (sobreescribiendo si existe)
        if (existingRoutines.isNotEmpty) {
          final existingId = existingRoutines.first['id'];

          // 1. Eliminar ejercicios de la rutina existente
          await supabase
              .from('routine_exercises')
              .delete()
              .eq('routine_id', existingId);

          // 2. Actualizar la rutina existente
          await supabase.from('routines').update({
            'name': _routineNameCtrl.text,
            'description':
                _descriptionCtrl.text.isNotEmpty ? _descriptionCtrl.text : null,
            'trainer_id': trainerId,
            'last_updated_at': now.toIso8601String(),
          }).eq('id', existingId);

          // 3. Agregar los nuevos ejercicios
          for (int i = 0; i < _selectedExercises.length; i++) {
            final exercise = _selectedExercises[i];
            final isTimeBased = _selectedExerciseTypes[i] == 'time';

            await supabase.from('routine_exercises').insert({
              'routine_id': existingId,
              'exercise_id': exercise['id'],
              'sets': int.tryParse(_setsCtrls[i].text) ?? 3,
              'reps': isTimeBased ? null : _repsCtrls[i].text,
              'duration_seconds': isTimeBased
                  ? int.tryParse(_durationCtrls[i].text) ?? 30
                  : null,
              'exercise_type': _selectedExerciseTypes[i],
              'rest_time': int.tryParse(_restTimeCtrls[i].text) ?? 60,
              'day_of_week': _selectedDays[i],
            });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ Rutina "${_routineNameCtrl.text}" actualizada exitosamente'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // Crear nueva rutina si no existe ninguna
          final routineResponse = await supabase.from('routines').insert({
            'client_id': widget.clientId,
            'trainer_id': trainerId,
            'name': _routineNameCtrl.text,
            'description':
                _descriptionCtrl.text.isNotEmpty ? _descriptionCtrl.text : null,
            'start_date': now.toIso8601String().split('T')[0],
            'status': 'active',
            'last_updated_at': now.toIso8601String(),
          }).select();

          if (routineResponse.isEmpty) throw Exception('Error al crear rutina');

          final routineId = routineResponse.first['id'];

          // Agregar los ejercicios
          for (int i = 0; i < _selectedExercises.length; i++) {
            final exercise = _selectedExercises[i];
            final isTimeBased = _selectedExerciseTypes[i] == 'time';

            await supabase.from('routine_exercises').insert({
              'routine_id': routineId,
              'exercise_id': exercise['id'],
              'sets': int.tryParse(_setsCtrls[i].text) ?? 3,
              'reps': isTimeBased ? null : _repsCtrls[i].text,
              'duration_seconds': isTimeBased
                  ? int.tryParse(_durationCtrls[i].text) ?? 30
                  : null,
              'exercise_type': _selectedExerciseTypes[i],
              'rest_time': int.tryParse(_restTimeCtrls[i].text) ?? 60,
              'day_of_week': _selectedDays[i],
            });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ Rutina "${_routineNameCtrl.text}" creada exitosamente'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      if (widget.onAssigned != null) {
        widget.onAssigned!();
      }

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error detallado: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget _buildExerciseCard(int index) {
    final exercise = _selectedExercises[index];
    final isTimeBased = _selectedExerciseTypes[index] == 'time';
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      color: AppTheme.darkGrey,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isTimeBased ? Icons.timer : Icons.repeat,
                    color: AppTheme.primaryOrange,
                    size: 18,
                  ),
                  onPressed: () => _toggleExerciseType(index),
                  tooltip: isTimeBased
                      ? 'Cambiar a repeticiones (series × reps)'
                      : 'Cambiar a tiempo (series × segundos)',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  onPressed: () => _removeExercise(index),
                ),
              ],
            ),
            if (exercise['muscle_group'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Grupo: ${exercise['muscle_group']}',
                style: const TextStyle(color: AppTheme.lightGrey, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isTimeBased
                        ? Colors.purple.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isTimeBased ? Icons.timer : Icons.repeat,
                        size: 12,
                        color: isTimeBased ? Colors.purple : Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isTimeBased
                            ? 'SERIES × SEGUNDOS'
                            : 'SERIES × REPETICIONES',
                        style: TextStyle(
                          color: isTimeBased ? Colors.purple : Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            isMobile
                ? Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Series',
                                  style: TextStyle(
                                      fontSize: 12, color: AppTheme.lightGrey),
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _setsCtrls[index],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '3',
                                    hintStyle: const TextStyle(
                                        color: AppTheme.lightGrey),
                                    filled: true,
                                    fillColor: AppTheme.darkBlack,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.all(8),
                                  ),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isTimeBased ? 'Duración (s)' : 'Repeticiones',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.lightGrey),
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: isTimeBased
                                      ? _durationCtrls[index]
                                      : _repsCtrls[index],
                                  keyboardType: isTimeBased
                                      ? TextInputType.number
                                      : TextInputType.text,
                                  decoration: InputDecoration(
                                    hintText: isTimeBased ? '30' : '10-12',
                                    hintStyle: const TextStyle(
                                        color: AppTheme.lightGrey),
                                    filled: true,
                                    fillColor: AppTheme.darkBlack,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.all(8),
                                  ),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Descanso (s)',
                                  style: TextStyle(
                                      fontSize: 12, color: AppTheme.lightGrey),
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _restTimeCtrls[index],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '60',
                                    hintStyle: const TextStyle(
                                        color: AppTheme.lightGrey),
                                    filled: true,
                                    fillColor: AppTheme.darkBlack,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.all(8),
                                  ),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Series',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.lightGrey),
                            ),
                            TextField(
                              controller: _setsCtrls[index],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '3',
                                hintStyle:
                                    const TextStyle(color: AppTheme.lightGrey),
                                filled: true,
                                fillColor: AppTheme.darkBlack,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(8),
                              ),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTimeBased ? 'Duración (s)' : 'Repeticiones',
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.lightGrey),
                            ),
                            TextField(
                              controller: isTimeBased
                                  ? _durationCtrls[index]
                                  : _repsCtrls[index],
                              keyboardType: isTimeBased
                                  ? TextInputType.number
                                  : TextInputType.text,
                              decoration: InputDecoration(
                                hintText: isTimeBased ? '30' : '10-12',
                                hintStyle:
                                    const TextStyle(color: AppTheme.lightGrey),
                                filled: true,
                                fillColor: AppTheme.darkBlack,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(8),
                              ),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Descanso (s)',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.lightGrey),
                            ),
                            TextField(
                              controller: _restTimeCtrls[index],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '60',
                                hintStyle:
                                    const TextStyle(color: AppTheme.lightGrey),
                                filled: true,
                                fillColor: AppTheme.darkBlack,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(8),
                              ),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.darkBlack,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDays[index],
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down,
                      size: 20, color: AppTheme.primaryOrange),
                  dropdownColor: AppTheme.darkGrey,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  items: [
                    DropdownMenuItem(
                      value: 'monday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16,
                              color: isMobile ? Colors.blue : Colors.blue),
                          const SizedBox(width: 8),
                          Text(isMobile ? 'Lun' : 'Lunes'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'tuesday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16,
                              color: isMobile ? Colors.green : Colors.green),
                          const SizedBox(width: 8),
                          Text(isMobile ? 'Mar' : 'Martes'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'wednesday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16,
                              color: isMobile ? Colors.orange : Colors.orange),
                          const SizedBox(width: 8),
                          Text(isMobile ? 'Mié' : 'Miércoles'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'thursday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16,
                              color: isMobile ? Colors.purple : Colors.purple),
                          const SizedBox(width: 8),
                          Text(isMobile ? 'Jue' : 'Jueves'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'friday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16,
                              color: isMobile ? Colors.red : Colors.red),
                          const SizedBox(width: 8),
                          Text(isMobile ? 'Vie' : 'Viernes'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'saturday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16,
                              color: isMobile ? Colors.yellow : Colors.yellow),
                          const SizedBox(width: 8),
                          Text(isMobile ? 'Sáb' : 'Sábado'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'sunday',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16,
                              color: isMobile ? Colors.grey : Colors.grey),
                          const SizedBox(width: 8),
                          Text(isMobile ? 'Dom' : 'Domingo'),
                        ],
                      ),
                    ),
                  ].toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedDays[index] = value);
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

  Widget _buildExerciseList() {
    final filteredExercises = _getFilteredExercises();
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar ejercicio...',
                  hintStyle: const TextStyle(color: AppTheme.lightGrey),
                  filled: true,
                  fillColor: AppTheme.darkGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon:
                      const Icon(Icons.search, color: AppTheme.primaryOrange),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.darkGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMuscleGroup,
                  icon: const Icon(Icons.filter_list,
                      color: AppTheme.primaryOrange),
                  dropdownColor: AppTheme.darkGrey,
                  style: const TextStyle(color: Colors.white),
                  items: _getMuscleGroups().map((group) {
                    return DropdownMenuItem(
                      value: group,
                      child: Text(isMobile && group.length > 8
                          ? '${group.substring(0, 8)}...'
                          : group),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedMuscleGroup = value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (filteredExercises.isEmpty)
          const Center(
            child: Column(
              children: [
                Icon(Icons.fitness_center_outlined,
                    size: 48, color: AppTheme.lightGrey),
                SizedBox(height: 16),
                Text(
                  'No se encontraron ejercicios',
                  style: TextStyle(color: AppTheme.lightGrey),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 2 : 3,
              crossAxisSpacing: isMobile ? 8 : 12,
              mainAxisSpacing: isMobile ? 8 : 12,
              childAspectRatio: isMobile ? 1.2 : 1.5,
            ),
            itemCount: filteredExercises.length,
            itemBuilder: (context, index) {
              final exercise = filteredExercises[index];
              final isSelected =
                  _selectedExercises.any((ex) => ex['id'] == exercise['id']);
              final exerciseType = exercise['exercise_type'] ?? 'reps';
              final isTimeBased = exerciseType == 'time';

              return Card(
                color: isSelected
                    ? AppTheme.primaryOrange.withOpacity(0.2)
                    : AppTheme.darkGrey,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryOrange
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: isSelected ? null : () => _addExercise(exercise),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 8 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 14 : 16,
                                color: isSelected
                                    ? AppTheme.primaryOrange
                                    : Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (exercise['muscle_group'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                exercise['muscle_group'],
                                style: TextStyle(
                                  color: AppTheme.lightGrey,
                                  fontSize: isMobile ? 10 : 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isTimeBased
                                        ? Colors.purple.withOpacity(0.2)
                                        : Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isTimeBased
                                            ? Icons.timer
                                            : Icons.repeat,
                                        size: 10,
                                        color: isTimeBased
                                            ? Colors.purple
                                            : Colors.blue,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        isTimeBased ? 'TIEMPO' : 'REPS',
                                        style: TextStyle(
                                          color: isTimeBased
                                              ? Colors.purple
                                              : Colors.blue,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: AppTheme.primaryOrange,
                                size: isMobile ? 14 : 16,
                              )
                            else
                              Icon(
                                Icons.add_circle,
                                color: Colors.green,
                                size: isMobile ? 14 : 16,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTemplateSelector() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_routineTemplates.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.layers_outlined,
                size: isMobile ? 36 : 48, color: AppTheme.lightGrey),
            const SizedBox(height: 16),
            Text(
              'No hay plantillas disponibles',
              style: TextStyle(
                  color: AppTheme.lightGrey, fontSize: isMobile ? 14 : 16),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.darkGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTemplate.isEmpty ? null : _selectedTemplate,
              isExpanded: true,
              hint: Text(
                'Selecciona una plantilla',
                style: TextStyle(color: AppTheme.lightGrey),
              ),
              icon: Icon(Icons.arrow_drop_down, color: AppTheme.primaryOrange),
              dropdownColor: AppTheme.darkGrey,
              style: const TextStyle(color: Colors.white),
              items: _routineTemplates.map((template) {
                final templateId = template['id'] as String;

                return DropdownMenuItem<String>(
                  value: templateId,
                  child: Row(
                    children: [
                      const Icon(Icons.layers, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template['name'] as String,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (template['description'] != null && !isMobile)
                              Text(
                                template['description'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.lightGrey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (template['is_public'] == true && !isMobile)
                        const Icon(Icons.public, size: 16, color: Colors.blue),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedTemplate = value);
                  _loadTemplate(value);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedTemplate.isNotEmpty)
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text(isMobile ? 'Limpiar' : 'Limpiar plantilla'),
            onPressed: () {
              setState(() {
                _selectedTemplate = '';
                _routineNameCtrl.clear();
                _descriptionCtrl.clear();
                _selectedExercises.clear();
                _setsCtrls.clear();
                _repsCtrls.clear();
                _durationCtrls.clear();
                _restTimeCtrls.clear();
                _selectedDays.clear();
                _selectedExerciseTypes.clear();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.withOpacity(0.2),
              foregroundColor: Colors.orange,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isEditing = widget.existingRoutine != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Rutina' : 'Asignar Rutina'),
        backgroundColor: AppTheme.darkBlack,
        actions: [
          if (_selectedExercises.isNotEmpty && !isMobile)
            TextButton.icon(
              icon: const Icon(Icons.save),
              label: Text('${_selectedExercises.length} ejercicios'),
              onPressed: null,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryOrange,
              ),
            ),
          if (isMobile && _selectedExercises.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('${_selectedExercises.length}'),
                backgroundColor: AppTheme.primaryOrange,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título según si es edición o nueva
                  if (isEditing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(Icons.edit,
                              color: AppTheme.primaryOrange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Editando rutina existente',
                            style: TextStyle(
                              color: AppTheme.lightGrey,
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Selección de tipo
                  Card(
                    color: AppTheme.darkGrey,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tipo de Rutina',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          isMobile
                              ? Column(
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Crear Personalizada'),
                                      selected: _routineType == 'custom',
                                      selectedColor: AppTheme.primaryOrange,
                                      onSelected: (selected) {
                                        setState(() => _routineType = 'custom');
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    ChoiceChip(
                                      label: const Text('Usar Plantilla'),
                                      selected: _routineType == 'template',
                                      selectedColor: AppTheme.primaryOrange,
                                      onSelected: (selected) {
                                        setState(
                                            () => _routineType = 'template');
                                      },
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: ChoiceChip(
                                        label:
                                            const Text('Crear Personalizada'),
                                        selected: _routineType == 'custom',
                                        selectedColor: AppTheme.primaryOrange,
                                        onSelected: (selected) {
                                          setState(
                                              () => _routineType = 'custom');
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ChoiceChip(
                                        label: const Text('Usar Plantilla'),
                                        selected: _routineType == 'template',
                                        selectedColor: AppTheme.primaryOrange,
                                        onSelected: (selected) {
                                          setState(
                                              () => _routineType = 'template');
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: isMobile ? 16 : 24),

                  // Nombre y descripción
                  Card(
                    color: AppTheme.darkGrey,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Información de la Rutina',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _routineNameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Nombre de la rutina *',
                              labelStyle:
                                  const TextStyle(color: AppTheme.lightGrey),
                              filled: true,
                              fillColor: AppTheme.darkBlack,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.fitness_center,
                                  color: AppTheme.primaryOrange),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descriptionCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Descripción (opcional)',
                              labelStyle:
                                  const TextStyle(color: AppTheme.lightGrey),
                              filled: true,
                              fillColor: AppTheme.darkBlack,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.description,
                                  color: AppTheme.primaryOrange),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: isMobile ? 16 : 24),

                  // Plantillas (si se seleccionó)
                  if (_routineType == 'template') ...[
                    Card(
                      color: AppTheme.darkGrey,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.layers,
                                    color: AppTheme.primaryOrange,
                                    size: isMobile ? 18 : 24),
                                const SizedBox(width: 8),
                                Text(
                                  isMobile
                                      ? 'Plantilla'
                                      : 'Seleccionar Plantilla',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 14 : 16,
                                  ),
                                ),
                                const Spacer(),
                                if (!isMobile)
                                  Chip(
                                    label: Text(
                                        '${_routineTemplates.length} disponibles'),
                                    backgroundColor:
                                        Colors.blue.withOpacity(0.2),
                                    labelStyle:
                                        const TextStyle(color: Colors.blue),
                                  ),
                              ],
                            ),
                            if (isMobile && _routineTemplates.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Chip(
                                  label: Text(
                                      '${_routineTemplates.length} disponibles'),
                                  backgroundColor: Colors.blue.withOpacity(0.2),
                                  labelStyle:
                                      const TextStyle(color: Colors.blue),
                                ),
                              ),
                            const SizedBox(height: 16),
                            _buildTemplateSelector(),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 24),
                  ],

                  // Lista de ejercicios seleccionados
                  if (_selectedExercises.isNotEmpty) ...[
                    Card(
                      color: AppTheme.darkGrey,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.list,
                                    color: AppTheme.primaryOrange,
                                    size: isMobile ? 18 : 24),
                                const SizedBox(width: 8),
                                Text(
                                  isMobile
                                      ? 'Ejercicios'
                                      : 'Ejercicios Seleccionados',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 14 : 16,
                                  ),
                                ),
                                const Spacer(),
                                Chip(
                                  label: Text(
                                      '${_selectedExercises.length} ejercicios'),
                                  backgroundColor:
                                      Colors.green.withOpacity(0.2),
                                  labelStyle:
                                      const TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ...List.generate(
                              _selectedExercises.length,
                              (index) => Column(
                                children: [
                                  _buildExerciseCard(index),
                                  if (index < _selectedExercises.length - 1)
                                    SizedBox(height: isMobile ? 8 : 12),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 24),
                  ],

                  // Buscador de ejercicios
                  Card(
                    color: AppTheme.darkGrey,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.search,
                                  color: AppTheme.primaryOrange,
                                  size: isMobile ? 18 : 24),
                              const SizedBox(width: 8),
                              Text(
                                isMobile ? 'Ejercicios' : 'Agregar Ejercicios',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 14 : 16,
                                ),
                              ),
                              const Spacer(),
                              Chip(
                                label: Text(
                                    '${_availableExercises.length} disponibles'),
                                backgroundColor: Colors.orange.withOpacity(0.2),
                                labelStyle:
                                    const TextStyle(color: Colors.orange),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildExerciseList(),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: isMobile ? 24 : 32),

                  // Botón de guardar
                  GradientButton(
                    text: _isSubmitting
                        ? (isEditing ? 'Actualizando...' : 'Guardando...')
                        : (isEditing ? 'Actualizar Rutina' : 'Guardar Rutina'),
                    onPressed: _isSubmitting ? null : _saveRoutine,
                    isLoading: _isSubmitting,
                    gradientColors: [
                      AppTheme.primaryOrange,
                      AppTheme.orangeAccent
                    ],
                  ),

                  SizedBox(height: isMobile ? 20 : 32),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _routineNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _searchCtrl.dispose();
    for (final ctrl in _setsCtrls) ctrl.dispose();
    for (final ctrl in _repsCtrls) ctrl.dispose();
    for (final ctrl in _durationCtrls) ctrl.dispose();
    for (final ctrl in _restTimeCtrls) ctrl.dispose();
    super.dispose();
  }
}
