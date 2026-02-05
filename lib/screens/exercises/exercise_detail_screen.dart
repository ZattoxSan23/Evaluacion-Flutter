import 'package:flutter/material.dart';
import 'package:front/screens/exercises/create_exercise_screen.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../widgets/gradient_button.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  YoutubePlayerController? _youtubeController;
  bool _loading = true;
  Map<String, dynamic>? _exerciseDetails;

  @override
  void initState() {
    super.initState();
    _loadExerciseDetails();
  }

  Future<void> _loadExerciseDetails() async {
    try {
      final response = await supabase
          .from('exercises')
          .select('*, profiles!exercises_created_by_fkey(full_name)')
          .eq('id', widget.exercise['id'])
          .single();

      setState(() {
        _exerciseDetails = response;
        _loading = false;
      });

      // Inicializar YouTube player si hay video
      final videoUrl = response['video_url'];
      if (videoUrl != null && videoUrl.isNotEmpty) {
        final videoId = YoutubePlayer.convertUrlToId(videoUrl);
        if (videoId != null) {
          setState(() {
            _youtubeController = YoutubePlayerController(
              initialVideoId: videoId,
              flags: const YoutubePlayerFlags(
                autoPlay: false,
                mute: false,
                disableDragSeek: true,
              ),
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando detalles: $e');
      setState(() => _loading = false);
    }
  }

  Widget _buildVideoSection() {
    if (_youtubeController == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.darkBlack,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_off,
                size: 48,
                color: AppTheme.lightGrey,
              ),
              SizedBox(height: 12),
              Text(
                'No hay video disponible',
                style: TextStyle(color: AppTheme.lightGrey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.black,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: YoutubePlayer(
              controller: _youtubeController!,
              showVideoProgressIndicator: true,
              progressColors: const ProgressBarColors(
                playedColor: AppTheme.primaryOrange,
                handleColor: AppTheme.primaryOrange,
              ),
              onReady: () {
                setState(() {});
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.play_circle_filled, size: 16, color: Colors.red),
                  SizedBox(width: 4),
                  Text(
                    'YouTube',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.fullscreen, color: AppTheme.primaryOrange),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        backgroundColor: Colors.black,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      body: Center(
                        child: YoutubePlayer(
                          controller: _youtubeController!,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon) {
    return Card(
      color: AppTheme.darkGrey,
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryOrange),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.lightGrey,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBlack,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryOrange),
        ),
      );
    }

    final exercise = _exerciseDetails ?? widget.exercise;
    final name = exercise['name'] ?? 'Sin nombre';
    final description = exercise['description'] ?? '';
    final muscleGroup = exercise['muscle_group'] ?? 'Sin categoría';
    final createdBy = exercise['profiles']?['full_name'] ?? 'Desconocido';
    final isPublic = exercise['is_public'] == true;
    final isMine = exercise['created_by'] == supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: AppTheme.darkBlack,
        actions: [
          if (isMine)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateExerciseScreen(
                      exercise: exercise,
                      onSaved: _loadExerciseDetails,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video
            _buildVideoSection(),

            const SizedBox(height: 24),

            // Nombre y descripción
            Card(
              color: AppTheme.darkGrey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (description.isNotEmpty) ...[
                      const Text(
                        'Descripción:',
                        style: TextStyle(
                          color: AppTheme.lightGrey,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Tags
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            muscleGroup.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isPublic
                                ? Colors.green.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPublic ? 'PÚBLICO' : 'PRIVADO',
                            style: TextStyle(
                              color: isPublic ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isMine)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'MI EJERCICIO',
                              style: TextStyle(
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Información adicional
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    'Creado por',
                    createdBy,
                    Icons.person,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    'Tipo',
                    isPublic ? 'Público' : 'Privado',
                    isPublic ? Icons.public : Icons.lock,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Botones de acción
            if (isMine)
              Column(
                children: [
                  GradientButton(
                    text: 'Editar Ejercicio',
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateExerciseScreen(
                            exercise: exercise,
                            onSaved: _loadExerciseDetails,
                          ),
                        ),
                      );
                    },
                    gradientColors: [
                      AppTheme.primaryOrange,
                      AppTheme.orangeAccent
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Eliminar Ejercicio',
                        style: TextStyle(color: Colors.red)),
                    onPressed: () async {
                      final confirmed = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Eliminar ejercicio'),
                          content: const Text(
                              '¿Estás seguro de eliminar este ejercicio?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Eliminar',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        try {
                          await supabase
                              .from('exercises')
                              .delete()
                              .eq('id', exercise['id']);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Ejercicio eliminado'),
                              backgroundColor: Colors.green,
                            ),
                          );

                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
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
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }
}
