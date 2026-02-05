// lib/screens/exercises/exercise_library_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../widgets/gradient_button.dart';
import 'create_exercise_screen.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> _filteredExercises = [];

  // Filtros
  String _searchQuery = '';
  String? _selectedMuscleGroup;
  bool _showMyExercisesOnly = false;

  // Paginación
  int _currentPage = 1;
  int _totalPages = 1;
  final int _itemsPerPage = 20;

  bool _isLoading = true;
  bool _loadingMore = false;

  // Estadísticas
  Map<String, dynamic> _stats = {};

  // Grupos musculares
  final List<String> _muscleGroups = [
    'pecho',
    'espalda',
    'hombros',
    'bíceps',
    'tríceps',
    'piernas',
    'glúteos',
    'abdominales',
    'cardiovascular',
    'full-body',
    'brazos',
    'core',
    'isquiotibiales',
    'cuádriceps'
  ];

  // Control para responsive
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_loadingMore &&
        _currentPage < _totalPages) {
      _loadExercises(loadMore: true);
    }
  }

  Future<void> _loadExercises({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() => _isLoading = true);
      _currentPage = 1;
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final trainerId = supabase.auth.currentUser?.id;
      if (trainerId == null) throw Exception('No autenticado');

      // Usamos consultas separadas para ejercicios públicos y del entrenador
      if (!_showMyExercisesOnly) {
        // Combinar ejercicios públicos Y ejercicios del entrenador
        final publicQuery = supabase
            .from('exercises')
            .select('*, profiles!exercises_created_by_fkey(full_name)')
            .eq('is_public', true);

        final myQuery = supabase
            .from('exercises')
            .select('*, profiles!exercises_created_by_fkey(full_name)')
            .eq('created_by', trainerId);

        // Aplicar búsqueda si existe
        if (_searchQuery.isNotEmpty) {
          publicQuery.ilike('name', '%$_searchQuery%');
          myQuery.ilike('name', '%$_searchQuery%');
        }

        // Aplicar filtro por grupo muscular si existe
        if (_selectedMuscleGroup != null && _selectedMuscleGroup!.isNotEmpty) {
          publicQuery.eq('muscle_group', _selectedMuscleGroup!);
          myQuery.eq('muscle_group', _selectedMuscleGroup!);
        }

        // Paginación
        final from = (_currentPage - 1) * _itemsPerPage;
        final to = from + _itemsPerPage - 1;

        // Ejecutar ambas queries
        final publicResponse = await publicQuery.range(from, to);
        final myResponse = await myQuery.range(from, to);

        // Combinar y eliminar duplicados
        final combinedList = [...publicResponse, ...myResponse];
        final uniqueExercises = <Map<String, dynamic>>[];
        final seenIds = <String>{};

        for (var exercise in combinedList) {
          final id = exercise['id'] as String;
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            uniqueExercises.add(exercise);
          }
        }

        // Obtener count total usando count() directamente
        final publicCountQuery =
            supabase.from('exercises').select().eq('is_public', true);

        final myCountQuery =
            supabase.from('exercises').select().eq('created_by', trainerId);

        // En versiones recientes, count() devuelve el número
        final publicResponseCount = await publicCountQuery;
        final myResponseCount = await myCountQuery;

        final publicCount = publicResponseCount.length;
        final myCount = myResponseCount.length;
        final totalCount = publicCount + myCount;

        if (mounted) {
          setState(() {
            if (loadMore) {
              _exercises.addAll(uniqueExercises);
            } else {
              _exercises = uniqueExercises;
            }

            _filteredExercises = List.from(_exercises);
            _totalPages = (totalCount + _itemsPerPage - 1) ~/ _itemsPerPage;
            _isLoading = false;
            _loadingMore = false;
          });
        }
      } else {
        // Solo mostrar ejercicios del entrenador
        var query = supabase
            .from('exercises')
            .select('*, profiles!exercises_created_by_fkey(full_name)')
            .eq('created_by', trainerId);

        // Aplicar búsqueda si existe
        if (_searchQuery.isNotEmpty) {
          query = query.ilike('name', '%$_searchQuery%');
        }

        // Aplicar filtro por grupo muscular si existe
        if (_selectedMuscleGroup != null && _selectedMuscleGroup!.isNotEmpty) {
          query = query.eq('muscle_group', _selectedMuscleGroup!);
        }

        // Paginación
        final from = (_currentPage - 1) * _itemsPerPage;
        final to = from + _itemsPerPage - 1;

        // Obtener count total primero
        var countQuery =
            supabase.from('exercises').select().eq('created_by', trainerId);

        if (_selectedMuscleGroup != null && _selectedMuscleGroup!.isNotEmpty) {
          countQuery = countQuery.eq('muscle_group', _selectedMuscleGroup!);
        }

        final countResponse = await countQuery;
        final totalCount = countResponse.length;

        // Obtener datos con paginación
        final response =
            await query.order('created_at', ascending: false).range(from, to);

        if (mounted) {
          setState(() {
            if (loadMore) {
              _exercises.addAll(List<Map<String, dynamic>>.from(response));
            } else {
              _exercises = List<Map<String, dynamic>>.from(response);
            }

            _filteredExercises = List.from(_exercises);
            _totalPages = (totalCount + _itemsPerPage - 1) ~/ _itemsPerPage;
            _isLoading = false;
            _loadingMore = false;
          });
        }
      }

      // Cargar estadísticas si es la primera página
      if (!loadMore) {
        _loadStats();
      }
    } catch (e) {
      debugPrint('Error cargando ejercicios: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final trainerId = supabase.auth.currentUser?.id;
      if (trainerId == null) return;

      // Obtener ejercicios públicos y del entrenador
      final publicResponse = await supabase
          .from('exercises')
          .select('muscle_group')
          .eq('is_public', true);

      final myResponse = await supabase
          .from('exercises')
          .select('muscle_group')
          .eq('created_by', trainerId);

      // Combinar resultados
      final allExercises = [...publicResponse, ...myResponse];

      final stats = <String, int>{};
      for (var ex in allExercises) {
        final group = ex['muscle_group'] ?? 'sin-categoria';
        stats[group] = (stats[group] ?? 0) + 1;
      }

      // Contar mis ejercicios
      final myExercisesResponse =
          await supabase.from('exercises').select().eq('created_by', trainerId);

      setState(() {
        _stats = {
          'muscleGroups': stats,
          'myExercises': myExercisesResponse.length,
          'totalExercises': allExercises.length,
        };
      });
    } catch (e) {
      debugPrint('Error cargando estadísticas: $e');
    }
  }

  Future<void> _deleteExercise(String exerciseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Eliminar ejercicio',
            style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de eliminar este ejercicio?',
            style: TextStyle(color: AppTheme.lightGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.lightGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.red, Colors.redAccent],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase.from('exercises').delete().eq('id', exerciseId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Ejercicio eliminado'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        );
      }

      _loadExercises();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredExercises = _exercises.where((exercise) {
        // Filtrar por grupo muscular
        if (_selectedMuscleGroup != null &&
            _selectedMuscleGroup!.isNotEmpty &&
            exercise['muscle_group'] != _selectedMuscleGroup) {
          return false;
        }

        // Filtrar por búsqueda
        if (_searchQuery.isNotEmpty) {
          final name = (exercise['name'] ?? '').toLowerCase();
          final description = (exercise['description'] ?? '').toLowerCase();
          if (!name.contains(_searchQuery.toLowerCase()) &&
              !description.contains(_searchQuery.toLowerCase())) {
            return false;
          }
        }

        // Filtrar mis ejercicios
        if (_showMyExercisesOnly) {
          final trainerId = supabase.auth.currentUser?.id;
          return exercise['created_by'] == trainerId;
        }

        return true;
      }).toList();
    });
  }

  Widget _buildStatsCard() {
    if (_stats.isEmpty) return const SizedBox();

    final muscleGroups = _stats['muscleGroups'] as Map<String, int>? ?? {};
    final myExercises = _stats['myExercises'] ?? 0;
    final totalExercises = _stats['totalExercises'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkGrey,
            AppTheme.darkGrey.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryOrange.withOpacity(0.2),
                      AppTheme.orangeAccent.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.analytics,
                    color: AppTheme.primaryOrange, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Estadísticas de Ejercicios',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              return isWide
                  ? Row(
                      children: [
                        _buildStatItem(
                          Icons.fitness_center,
                          'Total',
                          totalExercises.toString(),
                          Colors.blue,
                        ),
                        const SizedBox(width: 16),
                        _buildStatItem(
                          Icons.person,
                          'Mis Ejercicios',
                          myExercises.toString(),
                          AppTheme.primaryOrange,
                        ),
                        const SizedBox(width: 16),
                        _buildStatItem(
                          Icons.category,
                          'Grupos',
                          muscleGroups.length.toString(),
                          Colors.green,
                        ),
                      ],
                    )
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildStatItem(
                          Icons.fitness_center,
                          'Total',
                          totalExercises.toString(),
                          Colors.blue,
                        ),
                        _buildStatItem(
                          Icons.person,
                          'Mis Ejercicios',
                          myExercises.toString(),
                          AppTheme.primaryOrange,
                        ),
                        _buildStatItem(
                          Icons.category,
                          'Grupos',
                          muscleGroups.length.toString(),
                          Colors.green,
                        ),
                      ],
                    );
            },
          ),
          if (muscleGroups.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            const Text(
              'Distribución por Grupo Muscular',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: muscleGroups.entries.map((entry) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.3),
                        Colors.blue.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${entry.value})',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'RobotoMono',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.lightGrey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise) {
    final name = exercise['name'] ?? 'Sin nombre';
    final description = exercise['description'] ?? '';
    final muscleGroup = exercise['muscle_group'] ?? 'Sin categoría';
    final videoUrl = exercise['video_url'];
    final isMine = exercise['created_by'] == supabase.auth.currentUser?.id;
    final isPublic = exercise['is_public'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.darkGrey,
            AppTheme.darkGrey.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExerciseDetailScreen(exercise: exercise),
              ),
            );
          },
          splashColor: AppTheme.primaryOrange.withOpacity(0.2),
          highlightColor: AppTheme.primaryOrange.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail o icono de ejercicio
                    Container(
                      width: 100,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: videoUrl != null && videoUrl.isNotEmpty
                            ? LinearGradient(
                                colors: [
                                  Colors.black,
                                  Colors.black87,
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  AppTheme.darkBlack,
                                  AppTheme.darkBlack.withOpacity(0.8),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryOrange.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: videoUrl != null && videoUrl.isNotEmpty
                                ? const Icon(
                                    Icons.play_circle_filled,
                                    color: AppTheme.primaryOrange,
                                    size: 36,
                                  )
                                : const Icon(
                                    Icons.fitness_center,
                                    color: AppTheme.primaryOrange,
                                    size: 36,
                                  ),
                          ),
                          if (videoUrl != null && videoUrl.isNotEmpty)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.red,
                                      Colors.redAccent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'VIDEO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isMine)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primaryOrange.withOpacity(0.3),
                                        AppTheme.orangeAccent.withOpacity(0.2),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppTheme.primaryOrange,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'MÍO',
                                    style: const TextStyle(
                                      color: AppTheme.primaryOrange,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: const TextStyle(
                                color: AppTheme.lightGrey,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.withOpacity(0.3),
                                      Colors.blue.withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.category,
                                        size: 14, color: Colors.blue),
                                    const SizedBox(width: 6),
                                    Text(
                                      muscleGroup.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isPublic
                                        ? [
                                            Colors.green.withOpacity(0.3),
                                            Colors.green.withOpacity(0.1),
                                          ]
                                        : [
                                            Colors.orange.withOpacity(0.3),
                                            Colors.orange.withOpacity(0.1),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isPublic
                                          ? Icons.public
                                          : Icons.lock_outline,
                                      size: 14,
                                      color: isPublic
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isPublic ? 'PÚBLICO' : 'PRIVADO',
                                      style: TextStyle(
                                        color: isPublic
                                            ? Colors.green
                                            : Colors.orange,
                                        fontSize: 12,
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
                    ),
                  ],
                ),

                // Botones de acción
                if (isMine) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 400;
                      return isWide
                          ? Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    Icons.edit_outlined,
                                    'Editar',
                                    AppTheme.primaryOrange,
                                    () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CreateExerciseScreen(
                                            exercise: exercise,
                                            onSaved: _loadExercises,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildActionButton(
                                    Icons.delete_outline,
                                    'Eliminar',
                                    Colors.red,
                                    () => _deleteExercise(exercise['id']),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildActionButton(
                                  Icons.edit_outlined,
                                  'Editar Ejercicio',
                                  AppTheme.primaryOrange,
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CreateExerciseScreen(
                                          exercise: exercise,
                                          onSaved: _loadExercises,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildActionButton(
                                  Icons.delete_outline,
                                  'Eliminar Ejercicio',
                                  Colors.red,
                                  () => _deleteExercise(exercise['id']),
                                ),
                              ],
                            );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        title: const Text(
          'Biblioteca de Ejercicios',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: AppTheme.darkBlack,
        elevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.darkBlack,
                AppTheme.darkBlack.withOpacity(0.95),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryOrange, AppTheme.orangeAccent],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateExerciseScreen(onSaved: _loadExercises),
                ),
              );
            },
            tooltip: 'Crear ejercicio',
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 22),
            ),
            onPressed: () => _loadExercises(),
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = constraints.maxHeight;
            final isVerySmallScreen = screenHeight < 600;

            return Column(
              children: [
                // Barra de filtros - Fija en la parte superior
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: isVerySmallScreen ? 8 : 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.darkGrey.withOpacity(0.8),
                        AppTheme.darkGrey.withOpacity(0.6),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Barra de búsqueda
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar ejercicios...',
                            hintStyle:
                                const TextStyle(color: AppTheme.lightGrey),
                            filled: true,
                            fillColor: AppTheme.darkBlack,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.primaryOrange,
                                    AppTheme.orangeAccent,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.search,
                                  color: Colors.white, size: 20),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: isVerySmallScreen ? 12 : 16,
                              horizontal: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                      child: const Icon(Icons.clear,
                                          color: AppTheme.lightGrey, size: 20),
                                    ),
                                    onPressed: () {
                                      setState(() => _searchQuery = '');
                                      _loadExercises();
                                    },
                                  )
                                : null,
                          ),
                          style: const TextStyle(color: Colors.white),
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                            _applyFilters();
                          },
                        ),
                      ),

                      if (!isVerySmallScreen) const SizedBox(height: 16),

                      // Filtros rápidos - Solo mostrar si hay espacio
                      if (!isVerySmallScreen ||
                          (isVerySmallScreen && _stats.isEmpty))
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkBlack,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedMuscleGroup,
                                    isExpanded: true,
                                    icon: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.primaryOrange
                                            .withOpacity(0.2),
                                      ),
                                      child: const Icon(Icons.arrow_drop_down,
                                          color: AppTheme.primaryOrange),
                                    ),
                                    hint: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Text(
                                        'Grupo muscular',
                                        style: TextStyle(
                                          color: AppTheme.lightGrey,
                                          fontSize: isVerySmallScreen ? 12 : 14,
                                        ),
                                      ),
                                    ),
                                    dropdownColor: AppTheme.darkGrey,
                                    style: const TextStyle(color: Colors.white),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: '',
                                        child: Row(
                                          children: [
                                            Icon(Icons.all_inclusive,
                                                color: Colors.blue, size: 18),
                                            SizedBox(width: 8),
                                            Text('Todos'),
                                          ],
                                        ),
                                      ),
                                      ..._muscleGroups.map((group) {
                                        return DropdownMenuItem(
                                          value: group,
                                          child: Row(
                                            children: [
                                              Icon(
                                                _getMuscleGroupIcon(group),
                                                color: Colors.blue,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(group.toUpperCase()),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (value) {
                                      setState(
                                          () => _selectedMuscleGroup = value);
                                      _loadExercises();
                                    },
                                  ),
                                ),
                              ),
                            ),
                            if (!isVerySmallScreen) const SizedBox(width: 12),
                            if (!isVerySmallScreen)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _showMyExercisesOnly =
                                        !_showMyExercisesOnly);
                                    _loadExercises();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: _showMyExercisesOnly
                                          ? const LinearGradient(
                                              colors: [
                                                AppTheme.primaryOrange,
                                                AppTheme.orangeAccent,
                                              ],
                                            )
                                          : LinearGradient(
                                              colors: [
                                                Colors.white.withOpacity(0.1),
                                                Colors.white.withOpacity(0.05),
                                              ],
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _showMyExercisesOnly
                                            ? AppTheme.primaryOrange
                                            : Colors.white24,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          color: _showMyExercisesOnly
                                              ? Colors.white
                                              : AppTheme.lightGrey,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Mis ejercicios',
                                          style: TextStyle(
                                            color: _showMyExercisesOnly
                                                ? Colors.white
                                                : AppTheme.lightGrey,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Contenido principal con scroll
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryOrange.withOpacity(0.1),
                                      AppTheme.orangeAccent.withOpacity(0.05),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryOrange,
                                  ),
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Cargando ejercicios...',
                                style: TextStyle(
                                  color: AppTheme.lightGrey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _filteredExercises.isEmpty
                          ? SingleChildScrollView(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: isVerySmallScreen ? 20 : 40,
                                  horizontal: 20,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(40),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.darkGrey,
                                            AppTheme.darkGrey.withOpacity(0.7),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.fitness_center_outlined,
                                        size: 80,
                                        color: AppTheme.primaryOrange,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'No se encontraron ejercicios',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 40),
                                      child: Text(
                                        'Parece que no hay ejercicios que coincidan con tu búsqueda.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppTheme.lightGrey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    Container(
                                      width: 250,
                                      child: Material(
                                        borderRadius: BorderRadius.circular(15),
                                        elevation: 5,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    CreateExerciseScreen(
                                                        onSaved:
                                                            _loadExercises),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16, horizontal: 32),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  AppTheme.primaryOrange,
                                                  AppTheme.orangeAccent
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                'Crear Primer Ejercicio',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (scrollInfo) {
                                if (scrollInfo.metrics.pixels ==
                                        scrollInfo.metrics.maxScrollExtent &&
                                    !_loadingMore &&
                                    _currentPage < _totalPages) {
                                  _loadExercises(loadMore: true);
                                }
                                return false;
                              },
                              child: CustomScrollView(
                                controller: _scrollController,
                                slivers: [
                                  // Estadísticas (solo si hay espacio)
                                  if (!isVerySmallScreen && _stats.isNotEmpty)
                                    SliverToBoxAdapter(
                                      child: _buildStatsCard(),
                                    ),

                                  // Lista de ejercicios
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        if (index < _filteredExercises.length) {
                                          return _buildExerciseCard(
                                              _filteredExercises[index]);
                                        } else if (_currentPage < _totalPages) {
                                          return Container(
                                            padding: const EdgeInsets.all(32),
                                            child: Center(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(20),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      AppTheme.primaryOrange
                                                          .withOpacity(0.1),
                                                      AppTheme.orangeAccent
                                                          .withOpacity(0.05),
                                                    ],
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child:
                                                    const CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    AppTheme.primaryOrange,
                                                  ),
                                                  strokeWidth: 3,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                      childCount: _filteredExercises.length +
                                          (_loadingMore ? 1 : 0),
                                    ),
                                  ),

                                  // Espacio para el FAB
                                  SliverPadding(
                                    padding: EdgeInsets.only(
                                      bottom: isMobile ? 80 : 100,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Container(
        margin: EdgeInsets.only(
          bottom: isMobile ? 16 : 32,
          right: isMobile ? 16 : 32,
        ),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryOrange.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
          shape: BoxShape.circle,
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateExerciseScreen(onSaved: _loadExercises),
              ),
            );
          },
          backgroundColor: AppTheme.primaryOrange,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 25 : 30),
          ),
          icon: const Icon(Icons.add, size: 24),
          label: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
            ),
            child: Text(
              'Nuevo Ejercicio',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  IconData _getMuscleGroupIcon(String muscleGroup) {
    switch (muscleGroup.toLowerCase()) {
      case 'pecho':
        return Icons.self_improvement;
      case 'espalda':
        return Icons.line_weight;
      case 'hombros':
        return Icons.accessibility_new;
      case 'bíceps':
        return Icons.fitness_center;
      case 'tríceps':
        return Icons.anchor;
      case 'piernas':
        return Icons.directions_run;
      case 'glúteos':
        return Icons.self_improvement_outlined;
      case 'abdominales':
        return Icons.square;
      case 'cardiovascular':
        return Icons.favorite;
      case 'full-body':
        return Icons.accessibility;
      case 'brazos':
        return Icons.sports_martial_arts;
      case 'core':
        return Icons.center_focus_strong;
      default:
        return Icons.fitness_center;
    }
  }
}
