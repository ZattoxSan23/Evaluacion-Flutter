import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../core/theme.dart';

class WorkoutTimerScreen extends StatefulWidget {
  final String routineId;
  final Map<String, dynamic> routine;
  final List<Map<String, dynamic>> filteredExercises;

  const WorkoutTimerScreen({
    super.key,
    required this.routineId,
    required this.routine,
    required this.filteredExercises,
  });

  @override
  State<WorkoutTimerScreen> createState() => _WorkoutTimerScreenState();
}

enum WorkoutState { initial, working, rest, completed, setCompleted }

class _WorkoutTimerScreenState extends State<WorkoutTimerScreen> {
  List<Map<String, dynamic>> _exercises = [];
  int _currentExerciseIndex = 0;
  int _currentSet = 1;
  WorkoutState _workoutState = WorkoutState.initial;
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _keepScreenOn = true;
  final Map<String, YoutubePlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _initializeWorkout();
    _keepScreenAwake();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _allowScreenSleep();
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _keepScreenAwake() async {
    await WakelockPlus.enable();
    setState(() => _keepScreenOn = true);
  }

  Future<void> _allowScreenSleep() async {
    await WakelockPlus.disable();
    setState(() => _keepScreenOn = false);
  }

  void _initializeWorkout() {
    _exercises = widget.filteredExercises;
    if (_exercises.isNotEmpty) {
      _initializeVideoControllers();
      _loadCurrentExercise();
    }
  }

  void _initializeVideoControllers() {
    for (final exercise in _exercises) {
      final exerciseData = exercise['exercises'] ?? {};
      final videoUrl = exerciseData['video_url'];

      if (videoUrl != null && videoUrl.isNotEmpty) {
        try {
          final videoId = YoutubePlayer.convertUrlToId(videoUrl);
          if (videoId != null) {
            final controller = YoutubePlayerController(
              initialVideoId: videoId,
              flags: const YoutubePlayerFlags(
                autoPlay: false,
                mute: false,
                loop: false,
                enableCaption: false,
                hideControls: false,
                controlsVisibleAtStart: false,
              ),
            );
            final exerciseId =
                exerciseData['id']?.toString() ?? UniqueKey().toString();
            _videoControllers[exerciseId] = controller;
          }
        } catch (e) {
          debugPrint('Error inicializando video: $e');
        }
      }
    }
  }

  void _loadCurrentExercise() {
    if (_currentExerciseIndex >= _exercises.length) {
      _completeWorkout();
      return;
    }

    setState(() {
      _currentSet = 1;
      _workoutState = WorkoutState.initial;
      _remainingSeconds = 0;
    });
  }

  void _startExerciseWithTimer() {
    final exercise = _exercises[_currentExerciseIndex];
    final duration = exercise['duration_seconds'] ?? 30;

    setState(() {
      _workoutState = WorkoutState.working;
      _remainingSeconds = duration > 0 ? duration : 30;
      _startTimer();
    });
  }

  void _startExerciseNoTimer() {
    setState(() {
      _workoutState = WorkoutState.working;
      _remainingSeconds = 0;
    });
  }

  void _completeSet() {
    _timer?.cancel();

    final exercise = _exercises[_currentExerciseIndex];
    final sets = exercise['sets'] ?? 3;

    if (_currentSet < sets) {
      setState(() {
        _workoutState = WorkoutState.setCompleted;
        _remainingSeconds = 0;
      });
    } else {
      _nextExercise();
    }
  }

  void _startRest() {
    final exercise = _exercises[_currentExerciseIndex];
    final restTime = exercise['rest_time'] ?? 60;

    setState(() {
      _workoutState = WorkoutState.rest;
      _remainingSeconds = restTime;
      _startTimer();
    });
  }

  void _skipRest() {
    _timer?.cancel();
    _nextSet();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _handleTimerCompletion();
      }
    });
  }

  void _handleTimerCompletion() {
    if (_workoutState == WorkoutState.rest) {
      _nextSet();
    } else if (_workoutState == WorkoutState.working) {
      _completeSet();
    }
  }

  void _nextSet() {
    final exercise = _exercises[_currentExerciseIndex];
    final sets = exercise['sets'] ?? 3;

    if (_currentSet < sets) {
      setState(() {
        _currentSet++;
        _workoutState = WorkoutState.initial;
        _remainingSeconds = 0;
      });
    } else {
      _nextExercise();
    }
  }

  void _nextExercise() {
    if (_currentExerciseIndex + 1 < _exercises.length) {
      setState(() {
        _currentExerciseIndex++;
        _loadCurrentExercise();
      });
    } else {
      _completeWorkout();
    }
  }

  void _completeWorkout() {
    setState(() {
      _workoutState = WorkoutState.completed;
    });
    _timer?.cancel();
    _allowScreenSleep();
  }

  void _resetExercise() {
    _timer?.cancel();
    _loadCurrentExercise();
  }

  // ========== WIDGETS RESPONSIVOS ==========

  Widget _buildVideoPlayer(bool isMobile) {
    if (_currentExerciseIndex >= _exercises.length || _exercises.isEmpty) {
      return Container(
        height: isMobile ? 150 : 200,
        color: AppTheme.darkBlack,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center,
                  size: isMobile ? 40 : 48, color: AppTheme.lightGrey),
              SizedBox(height: isMobile ? 4 : 8),
              Text('Sin ejercicio activo',
                  style: TextStyle(
                      color: AppTheme.lightGrey, fontSize: isMobile ? 12 : 14)),
            ],
          ),
        ),
      );
    }

    final exerciseData = _exercises[_currentExerciseIndex]['exercises'] ?? {};
    final videoUrl = exerciseData['video_url'];
    final exerciseId = exerciseData['id']?.toString() ?? UniqueKey().toString();

    if (videoUrl == null || videoUrl.isEmpty) {
      return Container(
        height: isMobile ? 150 : 200,
        color: AppTheme.darkBlack,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off,
                  size: isMobile ? 36 : 48, color: AppTheme.lightGrey),
              SizedBox(height: isMobile ? 4 : 8),
              Text('Video no disponible',
                  style: TextStyle(
                      color: AppTheme.lightGrey, fontSize: isMobile ? 12 : 14)),
            ],
          ),
        ),
      );
    }

    final controller = _videoControllers[exerciseId];
    if (controller == null) {
      return Container(
        height: isMobile ? 150 : 200,
        color: AppTheme.darkBlack,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryOrange),
        ),
      );
    }

    return Container(
      height: isMobile ? 150 : 200,
      color: Colors.black,
      child: YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppTheme.primaryOrange,
        progressColors: const ProgressBarColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
        ),
      ),
    );
  }

  Widget _buildExerciseInfo(bool isMobile) {
    if (_currentExerciseIndex >= _exercises.length || _exercises.isEmpty) {
      return const SizedBox();
    }

    final exercise = _exercises[_currentExerciseIndex];
    final exerciseData = exercise['exercises'] ?? {};
    final exerciseName = exerciseData['name'] ?? 'Ejercicio';
    final muscleGroup = exerciseData['muscle_group'] ?? '';
    final exerciseType = exercise['exercise_type'] ?? 'reps';
    final sets = exercise['sets'] ?? 3;
    final reps = exercise['reps'] ?? '10-12';
    final duration = exercise['duration_seconds'] ?? 30;
    final restTime = exercise['rest_time'] ?? 60;

    return Card(
      color: AppTheme.darkGrey,
      margin: EdgeInsets.all(isMobile ? 10 : 16),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  exerciseType == 'time' ? Icons.timer : Icons.fitness_center,
                  color: Colors.blue,
                  size: isMobile ? 22 : 28,
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exerciseName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 16 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (muscleGroup.isNotEmpty)
                        Text(
                          muscleGroup.toUpperCase(),
                          style: TextStyle(
                            color: Colors.blue[200],
                            fontSize: isMobile ? 10 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12,
                    vertical: isMobile ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange,
                    borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                  ),
                  child: Text(
                    'Set $_currentSet/$sets',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  isMobile: isMobile,
                  icon: exerciseType == 'time' ? Icons.timer : Icons.repeat,
                  label: exerciseType == 'time' ? 'Duración' : 'Reps',
                  value: exerciseType == 'time' ? '${duration}s' : reps,
                  color: exerciseType == 'time' ? Colors.purple : Colors.green,
                ),
                _buildInfoItem(
                  isMobile: isMobile,
                  icon: Icons.bedtime,
                  label: 'Descanso',
                  value: '${restTime}s',
                  color: Colors.orange,
                ),
                _buildInfoItem(
                  isMobile: isMobile,
                  icon: Icons.format_list_numbered,
                  label: 'Series',
                  value: '$sets',
                  color: Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required bool isMobile,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: isMobile ? 18 : 24),
        SizedBox(height: isMobile ? 2 : 4),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.lightGrey,
            fontSize: isMobile ? 10 : 12,
          ),
        ),
        SizedBox(height: isMobile ? 2 : 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 14 : 16,
          ),
        ),
      ],
    );
  }

  Widget _buildTimer(bool isMobile) {
    Color color;
    String title;
    String subtitle;

    switch (_workoutState) {
      case WorkoutState.initial:
        color = Colors.blue;
        title = 'PREPARADO';
        subtitle = 'Listo para comenzar';
        break;
      case WorkoutState.working:
        color = Colors.green;
        title = 'EJERCICIO ACTIVO';
        subtitle = 'Set $_currentSet';
        break;
      case WorkoutState.setCompleted:
        color = Colors.green;
        title = 'SET COMPLETADO';
        subtitle = '¡Bien hecho!';
        break;
      case WorkoutState.rest:
        color = Colors.orange;
        title = 'DESCANSO';
        subtitle = 'Descanso Set $_currentSet';
        break;
      case WorkoutState.completed:
        color = Colors.green;
        title = 'COMPLETADO';
        subtitle = 'Entrenamiento terminado';
        break;
    }

    return Card(
      color: AppTheme.darkGrey,
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 16,
        vertical: isMobile ? 8 : 12,
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
              ),
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              subtitle,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: isMobile ? 12 : 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 16 : 20),
            Container(
              width: isMobile ? 120 : 150,
              height: isMobile ? 120 : 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.2),
                border: Border.all(color: color.withOpacity(0.4), width: 3),
              ),
              child: Center(
                child: Text(
                  _remainingSeconds > 0 ? '$_remainingSeconds' : '--',
                  style: TextStyle(
                    fontSize: isMobile ? 36 : 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: isMobile ? 8 : 10),
            Text(
              'segundos',
              style: TextStyle(
                color: color,
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(bool isMobile) {
    if (_workoutState == WorkoutState.completed) {
      return _buildCompletedControls(isMobile);
    }

    if (_exercises.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          children: [
            Icon(Icons.error_outline,
                size: isMobile ? 48 : 64, color: Colors.red),
            SizedBox(height: isMobile ? 12 : 16),
            Text(
              'No hay ejercicios disponibles',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 16 : 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 32,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              child: Text(
                'VOLVER',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final exercise = _exercises[_currentExerciseIndex];
    final exerciseType = exercise['exercise_type'] ?? 'reps';
    final sets = exercise['sets'] ?? 3;

    return Card(
      color: AppTheme.darkGrey,
      margin: EdgeInsets.all(isMobile ? 10 : 16),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: [
            if (_workoutState == WorkoutState.initial)
              _buildInitialControls(isMobile, exerciseType),
            if (_workoutState == WorkoutState.working)
              _buildWorkingControls(isMobile, exerciseType),
            if (_workoutState == WorkoutState.setCompleted)
              _buildSetCompletedControls(isMobile, sets),
            if (_workoutState == WorkoutState.rest)
              _buildRestControls(isMobile),
            SizedBox(height: isMobile ? 12 : 16),
            _buildSecondaryControls(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialControls(bool isMobile, String exerciseType) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(
              exerciseType == 'time' ? Icons.timer : Icons.fitness_center,
              size: isMobile ? 22 : 28,
            ),
            label: Text(
              exerciseType == 'time'
                  ? 'INICIAR EJERCICIO'
                  : 'INICIAR REPETICIONES',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: exerciseType == 'time'
                ? _startExerciseWithTimer
                : _startExerciseNoTimer,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 14 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
              ),
            ),
          ),
        ),
        SizedBox(height: isMobile ? 8 : 12),
        Text(
          exerciseType == 'time'
              ? 'El cronómetro empezará automáticamente'
              : 'Haz las repeticiones y marca cuando termines',
          style: TextStyle(
            color: AppTheme.lightGrey,
            fontSize: isMobile ? 12 : 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWorkingControls(bool isMobile, String exerciseType) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(Icons.check, size: isMobile ? 22 : 28),
            label: Text(
              exerciseType == 'time'
                  ? 'EJERCICIO COMPLETADO'
                  : 'REPETICIONES COMPLETADAS',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _completeSet,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
              ),
            ),
          ),
        ),
        SizedBox(height: isMobile ? 8 : 12),
        Text(
          exerciseType == 'time'
              ? 'Cronómetro activo'
              : 'Presiona cuando completes el set',
          style: TextStyle(
            color: Colors.green,
            fontSize: isMobile ? 12 : 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSetCompletedControls(bool isMobile, int sets) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle,
                  color: Colors.green, size: isMobile ? 20 : 24),
              SizedBox(width: isMobile ? 6 : 8),
              Flexible(
                child: Text(
                  '¡Set $_currentSet completado!',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 16 : 20),
        if (_currentSet < sets)
          Column(
            children: [
              Text(
                'Inicia el descanso',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: isMobile ? 14 : 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isMobile ? 12 : 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.timer, size: isMobile ? 22 : 28),
                  label: Text(
                    'DESCANSO SET $_currentSet',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _startRest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              Text(
                '¡Último set completado!',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isMobile ? 16 : 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.arrow_forward, size: isMobile ? 22 : 28),
                  label: Text(
                    'SIGUIENTE EJERCICIO',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _nextExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRestControls(bool isMobile) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(Icons.skip_next, size: isMobile ? 22 : 28),
            label: Text(
              'SALTAR DESCANSO',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _skipRest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
              ),
            ),
          ),
        ),
        SizedBox(height: isMobile ? 8 : 12),
        Text(
          'Descansando... $_remainingSeconds segundos',
          style: TextStyle(
            color: Colors.orange,
            fontSize: isMobile ? 12 : 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCompletedControls(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: isMobile ? 64 : 80,
            color: Colors.green,
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Text(
            '¡ENTRENAMIENTO\nCOMPLETADO!',
            style: TextStyle(
              color: Colors.green,
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            'Excelente trabajo',
            style: TextStyle(
              color: AppTheme.lightGrey,
              fontSize: isMobile ? 14 : 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 24 : 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 16 : 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
                ),
              ),
              child: Text(
                'VOLVER AL INICIO',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryControls(bool isMobile) {
    if (_workoutState == WorkoutState.completed) {
      return const SizedBox();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(Icons.refresh, size: isMobile ? 16 : 18),
            label: Text(
              'REINICIAR',
              style: TextStyle(fontSize: isMobile ? 12 : 14),
            ),
            onPressed: _resetExercise,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 10 : 12,
                horizontal: isMobile ? 8 : 12,
              ),
            ),
          ),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(Icons.close, size: isMobile ? 16 : 18),
            label: Text(
              'SALIR',
              style: TextStyle(fontSize: isMobile ? 12 : 14),
            ),
            onPressed: () {
              _timer?.cancel();
              _allowScreenSleep();
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 10 : 12,
                horizontal: isMobile ? 8 : 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgress(bool isMobile) {
    if (_exercises.isEmpty) {
      return const SizedBox();
    }

    final progress = (_currentExerciseIndex + 1) / _exercises.length;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 8 : 12,
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.darkBlack,
            color: AppTheme.primaryOrange,
            minHeight: isMobile ? 6 : 8,
            borderRadius: BorderRadius.circular(isMobile ? 3 : 4),
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ejercicio ${_currentExerciseIndex + 1}/${_exercises.length}',
                style: TextStyle(
                  color: AppTheme.lightGrey,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(bool isMobile) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.routine['name'] ?? 'Entrenamiento',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.routine['day_name'] != null)
            Text(
              widget.routine['day_name'] ?? '',
              style: TextStyle(
                fontSize: isMobile ? 11 : 13,
                color: AppTheme.lightGrey,
              ),
            ),
        ],
      ),
      backgroundColor: AppTheme.darkBlack,
      elevation: 2,
      actions: [
        IconButton(
          icon: Icon(
            _keepScreenOn ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            size: isMobile ? 20 : 24,
          ),
          onPressed: () {
            if (_keepScreenOn) {
              _allowScreenSleep();
            } else {
              _keepScreenAwake();
            }
          },
          tooltip: _keepScreenOn ? 'Pantalla activa' : 'Pantalla normal',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: _buildAppBar(isMobile),
      body: Column(
        children: [
          _buildProgress(isMobile),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildVideoPlayer(isMobile),
                  SizedBox(height: isMobile ? 12 : 16),
                  _buildExerciseInfo(isMobile),
                  _buildTimer(isMobile),
                  _buildControls(isMobile),
                  SizedBox(height: isMobile ? 20 : 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
