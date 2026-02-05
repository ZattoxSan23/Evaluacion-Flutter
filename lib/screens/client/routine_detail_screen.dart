import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import 'workout_timer.dart';

class RoutineDetailScreen extends StatefulWidget {
  final String routineId;
  final Map<String, dynamic> routine;

  const RoutineDetailScreen({
    super.key,
    required this.routineId,
    required this.routine,
  });

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _exercises = [];
  bool _isLoading = true;
  String? _selectedDay;
  final List<String> _dayOptions = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDay = _getCurrentDayOfWeek();
    _loadExercises();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _getCurrentDayOfWeek() {
    final now = DateTime.now();
    final days = [
      'monday', // índice 0
      'tuesday', // índice 1
      'wednesday', // índice 2
      'thursday', // índice 3
      'friday', // índice 4
      'saturday', // índice 5
      'sunday', // índice 6
    ];
    return days[now.weekday - 1];
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);

    try {
      final exercisesRes = await supabase
          .from('routine_exercises')
          .select('''
            *,
            exercises (
              id,
              name,
              muscle_group,
              description,
              video_url,
              exercise_type
            )
          ''')
          .eq('routine_id', widget.routineId)
          .order('day_of_week', ascending: true)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _exercises = List.from(exercisesRes);
          _isLoading = false;
        });
      }
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

  List<Map<String, dynamic>> _getFilteredExercises() {
    if (_selectedDay == null || _selectedDay == 'all') {
      return _exercises;
    }
    return _exercises
        .where((exercise) => exercise['day_of_week'] == _selectedDay)
        .toList();
  }

  String _getDayName(String day) {
    switch (day) {
      case 'monday':
        return 'LUN';
      case 'tuesday':
        return 'MAR';
      case 'wednesday':
        return 'MIÉ';
      case 'thursday':
        return 'JUE';
      case 'friday':
        return 'VIE';
      case 'saturday':
        return 'SÁB';
      case 'sunday':
        return 'DOM';
      default:
        return day.toUpperCase().substring(0, 3);
    }
  }

  Widget _buildDayFilter(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtrar por día:',
            style: TextStyle(
              color: AppTheme.lightGrey,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
          SizedBox(height: isMobile ? 8 : 10),
          SizedBox(
            height: isMobile ? 40 : 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildDayChip(isMobile, 'all', 'TODOS', null),
                SizedBox(width: isMobile ? 6 : 8),
                ..._dayOptions.map((day) {
                  final isToday = day == _getCurrentDayOfWeek();
                  return Padding(
                    padding: EdgeInsets.only(right: isMobile ? 6 : 8),
                    child: _buildDayChip(
                      isMobile,
                      day,
                      _getDayName(day),
                      isToday ? Icons.today : null,
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(
      bool isMobile, String day, String label, IconData? icon) {
    final isToday = day == _getCurrentDayOfWeek();
    final isSelected = _selectedDay == day;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(
              icon,
              size: isMobile ? 14 : 16,
              color: isToday ? Colors.green : Colors.white,
            ),
          if (icon != null) SizedBox(width: isMobile ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) => setState(() => _selectedDay = day),
      selectedColor: isToday ? Colors.green : AppTheme.primaryOrange,
      backgroundColor: AppTheme.darkBlack.withOpacity(0.7),
      labelStyle: const TextStyle(color: Colors.white),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 4 : 6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
        side: BorderSide(
          color: isToday ? Colors.green : AppTheme.lightGrey.withOpacity(0.3),
          width: 1,
        ),
      ),
    );
  }

  void _startWorkoutWithSelectedDay(bool isMobile) {
    final filteredExercises = _getFilteredExercises();

    if (filteredExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay ejercicios programados para este día',
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutTimerScreen(
          routineId: widget.routineId,
          routine: widget.routine,
          filteredExercises: filteredExercises,
        ),
      ),
    );
  }

  Widget _buildExerciseCard(bool isMobile, Map<String, dynamic> exercise) {
    final exerciseData = exercise['exercises'] ?? {};
    final exerciseName = exerciseData['name'] ?? 'Ejercicio sin nombre';
    final muscleGroup = exerciseData['muscle_group'] ?? 'Sin grupo';
    final exerciseType = exercise['exercise_type'] ?? 'reps';
    final isTimeBased = exerciseType == 'time';

    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      color: AppTheme.darkGrey,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícono
            Container(
              padding: EdgeInsets.all(isMobile ? 8 : 10),
              decoration: BoxDecoration(
                color: isTimeBased
                    ? Colors.purple.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
              ),
              child: Icon(
                isTimeBased ? Icons.timer : Icons.fitness_center,
                color: isTimeBased ? Colors.purple : Colors.blue,
                size: isMobile ? 20 : 24,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 16),

            // Información del ejercicio
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del ejercicio
                  Text(
                    exerciseName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isMobile ? 4 : 6),

                  // Grupo muscular
                  Text(
                    muscleGroup.toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.lightGrey,
                      fontSize: isMobile ? 10 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),

                  // Detalles del ejercicio
                  Row(
                    children: [
                      // Sets
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                        ),
                        child: Text(
                          '${exercise['sets'] ?? 3} SETS',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: isMobile ? 10 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: isMobile ? 6 : 8),

                      // Reps/Duración
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: isTimeBased
                              ? Colors.purple.withOpacity(0.2)
                              : Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                        ),
                        child: Text(
                          isTimeBased
                              ? '${exercise['duration_seconds'] ?? 30}S'
                              : '${exercise['reps'] ?? '10-12'} REPS',
                          style: TextStyle(
                            color: isTimeBased ? Colors.purple : Colors.green,
                            fontSize: isMobile ? 10 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: isMobile ? 6 : 8),

                      // Descanso
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                        ),
                        child: Text(
                          '${exercise['rest_time'] ?? 60}S',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: isMobile ? 10 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Día de la semana
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 10,
                vertical: isMobile ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.darkBlack.withOpacity(0.5),
                borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
              ),
              child: Text(
                _getDayName(exercise['day_of_week'] ?? ''),
                style: TextStyle(
                  color: AppTheme.lightGrey,
                  fontSize: isMobile ? 10 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 8 : 12,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(
            Icons.play_arrow,
            size: isMobile ? 22 : 24,
          ),
          label: Text(
            _selectedDay == 'all'
                ? 'INICIAR ENTRENAMIENTO'
                : 'INICIAR ${_getDayName(_selectedDay ?? '').toUpperCase()}',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          onPressed: () => _startWorkoutWithSelectedDay(isMobile),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryOrange,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
            ),
            elevation: 3,
            shadowColor: AppTheme.primaryOrange.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildDayInfo(bool isMobile) {
    if (_selectedDay == null || _selectedDay == 'all') return const SizedBox();

    final filteredExercises = _getFilteredExercises();
    final isToday = _selectedDay == _getCurrentDayOfWeek();

    return Container(
      margin: EdgeInsets.fromLTRB(
        isMobile ? 12 : 16,
        0,
        isMobile ? 12 : 16,
        isMobile ? 12 : 16,
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: isToday
            ? Colors.green.withOpacity(0.15)
            : AppTheme.primaryOrange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: Border.all(
          color: isToday ? Colors.green : AppTheme.primaryOrange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isToday ? Icons.today : Icons.calendar_today,
            color: isToday ? Colors.green : AppTheme.primaryOrange,
            size: isMobile ? 20 : 22,
          ),
          SizedBox(width: isMobile ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'ENTRENAMIENTO DE HOY' : 'ENTRENAMIENTO PROGRAMADO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isMobile ? 2 : 4),
                Text(
                  _getDayName(_selectedDay!),
                  style: TextStyle(
                    color: isToday ? Colors.green : AppTheme.primaryOrange,
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
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
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
            ),
            child: Text(
              '${filteredExercises.length} EJERC.',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 24 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: isMobile ? 60 : 80,
              color: AppTheme.lightGrey,
            ),
            SizedBox(height: isMobile ? 16 : 20),
            Text(
              'No hay ejercicios para este día',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 8 : 12),
            Text(
              'Cambia el filtro o contacta a tu entrenador',
              style: TextStyle(
                color: AppTheme.lightGrey,
                fontSize: isMobile ? 14 : 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 24 : 32),
            OutlinedButton(
              onPressed: () => setState(() => _selectedDay = 'all'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryOrange,
                side: BorderSide(color: AppTheme.primaryOrange),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 32,
                  vertical: isMobile ? 12 : 14,
                ),
              ),
              child: Text(
                'VER TODOS LOS EJERCICIOS',
                style: TextStyle(fontSize: isMobile ? 13 : 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(bool isMobile) {
    return AppBar(
      title: Text(
        widget.routine['name'] ?? 'Detalles de Rutina',
        style: TextStyle(
          fontSize: isMobile ? 16 : 18,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: AppTheme.darkBlack,
      elevation: 1,
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh,
            size: isMobile ? 20 : 24,
          ),
          onPressed: _loadExercises,
          tooltip: 'Recargar ejercicios',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final filteredExercises = _getFilteredExercises();

    return Scaffold(
      appBar: _buildAppBar(isMobile),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : Column(
              children: [
                // Filtro por día
                _buildDayFilter(isMobile),

                // Información del día seleccionado
                _buildDayInfo(isMobile),

                // Botón de inicio
                _buildStartButton(isMobile),

                // Lista de ejercicios
                Expanded(
                  child: filteredExercises.isEmpty
                      ? _buildEmptyState(isMobile)
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16,
                            vertical: isMobile ? 8 : 12,
                          ),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredExercises.length,
                          itemBuilder: (context, index) => _buildExerciseCard(
                              isMobile, filteredExercises[index]),
                        ),
                ),
              ],
            ),
    );
  }
}
