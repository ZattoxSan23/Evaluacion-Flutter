// lib/screens/trainer/create_routine_template_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:front/core/supabase_client.dart';
import 'package:front/core/theme.dart';
import 'package:front/widgets/gradient_button.dart';

class CreateRoutineTemplateScreen extends StatefulWidget {
  final Map<String, dynamic>? existingTemplate;
  final Function()? onSaved;

  const CreateRoutineTemplateScreen({
    super.key,
    this.existingTemplate,
    this.onSaved,
  });

  @override
  State<CreateRoutineTemplateScreen> createState() =>
      _CreateRoutineTemplateScreenState();
}

class _CreateRoutineTemplateScreenState
    extends State<CreateRoutineTemplateScreen> {
  final _templateNameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  // Listas de ejercicios
  List<Map<String, dynamic>> _availableExercises = [];
  List<Map<String, dynamic>> _selectedExercises = [];

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

  bool _isPublic = false;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);

    try {
      // Cargar ejercicios disponibles
      final exercises =
          await supabase.from('exercises').select('*').order('name');

      if (widget.existingTemplate != null) {
        _loadExistingTemplate();
      }

      setState(() {
        _availableExercises = List.from(exercises);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando ejercicios: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar ejercicios: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadExistingTemplate() {
    final template = widget.existingTemplate!;

    setState(() {
      _templateNameCtrl.text = template['name'];
      _descriptionCtrl.text = template['description'] ?? '';
      _isPublic = template['is_public'] == true;

      // Cargar ejercicios existentes
      final exercises = template['template_exercises'] as List? ?? [];
      _selectedExercises.clear();
      _setsCtrls.clear();
      _repsCtrls.clear();
      _durationCtrls.clear();
      _restTimeCtrls.clear();
      _selectedDays.clear();
      _selectedExerciseTypes.clear();

      for (final ex in exercises) {
        // MEJOR VALIDACIÓN
        final exerciseData = ex['exercises'] ?? {};
        final exerciseId = ex['exercise_id'];
        final exerciseType = ex['exercise_type'] ?? 'reps';
        final isTimeBased = exerciseType == 'time';

        // VERIFICACIÓN MÁS COMPLETA
        if (exerciseId == null || exerciseId.toString().isEmpty) {
          debugPrint('⚠️ Ejercicio sin ID válido, saltando...');
          continue;
        }

        // USAR exercise_id DE LA TABLA template_exercises, NO exercises
        _selectedExercises.add({
          'id': exerciseId, // <-- ESTO ES CRÍTICO
          'name': exerciseData['name'] ?? 'Ejercicio sin nombre',
          'muscle_group': exerciseData['muscle_group'],
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

      debugPrint(
          '✅ Cargados ${_selectedExercises.length} ejercicios de la plantilla existente');
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
    // VALIDAR QUE EL EJERCICIO TIENE ID
    if (exercise['id'] == null || exercise['id']!.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: El ejercicio no tiene ID válido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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

// En _CreateRoutineTemplateScreenState, modifica el método _saveTemplate():
  Future<void> _saveTemplate() async {
    if (_templateNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre de la plantilla es requerido')),
      );
      return;
    }

    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes agregar al menos un ejercicio')),
      );
      return;
    }

    // VALIDAR QUE TODOS LOS EJERCICIOS TIENEN ID
    for (final exercise in _selectedExercises) {
      if (exercise['id'] == null || exercise['id']!.toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Algunos ejercicios no tienen ID válido'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final trainerId = supabase.auth.currentUser!.id;

      final templateData = {
        'trainer_id': trainerId,
        'name': _templateNameCtrl.text,
        'description':
            _descriptionCtrl.text.isNotEmpty ? _descriptionCtrl.text : null,
        'is_public': _isPublic,
      };

      String templateId;

      if (widget.existingTemplate != null) {
        // Actualizar plantilla existente
        templateId = widget.existingTemplate!['id'];
        await supabase
            .from('routine_templates')
            .update(templateData)
            .eq('id', templateId)
            .eq('trainer_id', trainerId);

        // Eliminar ejercicios antiguos
        await supabase
            .from('template_exercises')
            .delete()
            .eq('template_id', templateId);
      } else {
        // Crear nueva plantilla
        final response = await supabase
            .from('routine_templates')
            .insert(templateData)
            .select('id')
            .single();
        templateId = response['id'];
      }

      debugPrint('ID de la plantilla: $templateId');

      // Agregar ejercicios - CORREGIR AQUÍ
      for (int i = 0; i < _selectedExercises.length; i++) {
        final exercise = _selectedExercises[i];
        final isTimeBased = _selectedExerciseTypes[i] == 'time';

        // DEBUG
        debugPrint('Ejercicio ${i + 1}:');
        debugPrint('  ID: ${exercise['id']}');
        debugPrint('  Nombre: ${exercise['name']}');
        debugPrint('  Sets: ${_setsCtrls[i].text}');
        debugPrint('  Tipo: ${_selectedExerciseTypes[i]}');
        debugPrint('  Template ID: $templateId');

        final insertData = {
          'template_id': templateId,
          'exercise_id': exercise['id'], // ESTE ES EL CAMPO CRÍTICO
          'sets': int.tryParse(_setsCtrls[i].text) ?? 3,
          'rest_time': int.tryParse(_restTimeCtrls[i].text) ?? 60,
          'day_of_week': _selectedDays[i],
          'order_index': i,
        };

        // Agregar reps o duration según el tipo
        if (isTimeBased) {
          insertData['duration_seconds'] =
              int.tryParse(_durationCtrls[i].text) ?? 30;
        } else {
          insertData['reps'] =
              _repsCtrls[i].text.isNotEmpty ? _repsCtrls[i].text : '10-12';
        }

        insertData['exercise_type'] = _selectedExerciseTypes[i];

        debugPrint('Insertando ejercicio: $insertData');

        final result = await supabase
            .from('template_exercises')
            .insert(insertData)
            .select();

        if (result.isEmpty) {
          debugPrint('Error al insertar ejercicio ${i + 1}');
        } else {
          debugPrint('✅ Ejercicio ${i + 1} insertado exitosamente');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingTemplate != null
                ? '✅ Plantilla actualizada exitosamente'
                : '✅ Plantilla creada exitosamente',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      if (widget.onSaved != null) {
        widget.onSaved!();
      }

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error al guardar plantilla: $e');
      debugPrint('Stack trace: ${e.toString()}');

      String errorMessage = 'Error al guardar: $e';
      if (e.toString().contains('invalid input syntax for type uuid')) {
        errorMessage = 'Error: Algunos ejercicios no tienen ID válido. '
            'Asegúrate de que todos los ejercicios estén correctamente cargados.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isEditing = widget.existingTemplate != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Plantilla' : 'Crear Plantilla'),
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
                            'Editando plantilla existente',
                            style: TextStyle(
                              color: AppTheme.lightGrey,
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                        ],
                      ),
                    ),

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
                            'Información de la Plantilla',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _templateNameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Nombre de la plantilla *',
                              labelStyle:
                                  const TextStyle(color: AppTheme.lightGrey),
                              filled: true,
                              fillColor: AppTheme.darkBlack,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.layers,
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
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text(
                              'Hacer pública',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'Otros entrenadores podrán usar esta plantilla',
                              style: TextStyle(color: AppTheme.lightGrey),
                            ),
                            value: _isPublic,
                            onChanged: (value) =>
                                setState(() => _isPublic = value),
                            activeColor: AppTheme.primaryOrange,
                            tileColor: AppTheme.darkBlack,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: isMobile ? 16 : 24),

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
                        : (isEditing
                            ? 'Actualizar Plantilla'
                            : 'Guardar Plantilla'),
                    onPressed: _isSubmitting ? null : _saveTemplate,
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
    _templateNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _searchCtrl.dispose();
    for (final ctrl in _setsCtrls) ctrl.dispose();
    for (final ctrl in _repsCtrls) ctrl.dispose();
    for (final ctrl in _durationCtrls) ctrl.dispose();
    for (final ctrl in _restTimeCtrls) ctrl.dispose();
    super.dispose();
  }
}
