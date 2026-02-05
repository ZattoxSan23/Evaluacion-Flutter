import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:http/http.dart' as http;

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../widgets/gradient_button.dart';

class CreateExerciseScreen extends StatefulWidget {
  final Map<String, dynamic>? exercise;
  final VoidCallback? onSaved;

  const CreateExerciseScreen({
    super.key,
    this.exercise,
    this.onSaved,
  });

  @override
  State<CreateExerciseScreen> createState() => _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends State<CreateExerciseScreen> {
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  final _youtubeIdCtrl = TextEditingController();

  String? _selectedMuscleGroup;
  bool _isPublic = true;
  bool _isLoading = false;
  bool _isValidatingVideo = false;

  // Datos del video de YouTube
  Map<String, dynamic>? _videoInfo;
  YoutubePlayerController? _youtubeController;

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

  // Tipo de ejercicio
  String _exerciseType = 'reps'; // 'reps' o 'time'

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.exercise != null) {
      _nameCtrl.text = widget.exercise!['name'] ?? '';
      _descriptionCtrl.text = widget.exercise!['description'] ?? '';
      _videoUrlCtrl.text = widget.exercise!['video_url'] ?? '';
      _selectedMuscleGroup = widget.exercise!['muscle_group'];
      _isPublic = widget.exercise!['is_public'] ?? true;
      _exerciseType = widget.exercise!['exercise_type'] ?? 'reps';

      // Extraer ID de YouTube si existe
      if (_videoUrlCtrl.text.isNotEmpty) {
        _extractYouTubeId(_videoUrlCtrl.text);
      }
    }
  }

  void _extractYouTubeId(String url) {
    try {
      final youtubeId = YoutubePlayer.convertUrlToId(url);
      if (youtubeId != null) {
        _youtubeIdCtrl.text = youtubeId;
        _loadYouTubeInfo(youtubeId);
      }
    } catch (e) {
      debugPrint('Error extrayendo ID de YouTube: $e');
    }
  }

  Future<void> _loadYouTubeInfo(String videoId) async {
    setState(() => _isValidatingVideo = true);

    try {
      // Solo mostrar thumbnail básico sin API de YouTube
      setState(() {
        _videoInfo = {
          'title': 'Video de YouTube',
          'thumbnail': 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
          'channel': 'YouTube',
        };
      });

      // Inicializar controlador de YouTube
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          disableDragSeek: true,
          hideThumbnail: true,
        ),
      );
    } catch (e) {
      debugPrint('Error cargando info de YouTube: $e');
      // Fallback básico
      setState(() {
        _videoInfo = {
          'title': 'Video de YouTube',
          'thumbnail': 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
        };
      });
    } finally {
      setState(() => _isValidatingVideo = false);
    }
  }

  Future<void> _saveExercise() async {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del ejercicio es requerido')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final trainerId = supabase.auth.currentUser!.id;

      final exerciseData = {
        'name': name,
        'description': _descriptionCtrl.text.trim(),
        'video_url': _videoUrlCtrl.text.trim().isNotEmpty
            ? _videoUrlCtrl.text.trim()
            : null,
        'muscle_group': _selectedMuscleGroup,
        'exercise_type': _exerciseType,
        'created_by': trainerId,
        'is_public': _isPublic,
      };

      if (widget.exercise != null) {
        // Actualizar ejercicio existente
        await supabase
            .from('exercises')
            .update(exerciseData)
            .eq('id', widget.exercise!['id']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ejercicio actualizado'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Crear nuevo ejercicio
        await supabase.from('exercises').insert(exerciseData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ejercicio creado'),
            backgroundColor: Colors.green,
          ),
        );
      }

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
      setState(() => _isLoading = false);
    }
  }

  Widget _buildVideoPreview() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_isValidatingVideo) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
      );
    }

    if (_videoInfo != null && _youtubeIdCtrl.text.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: isMobile ? 150 : 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black,
            ),
            child: Stack(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _videoInfo!['thumbnail'],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                // Overlay con botón de play
                Center(
                  child: Container(
                    width: isMobile ? 50 : 60,
                    height: isMobile ? 50 : 60,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: isMobile ? 30 : 40,
                    ),
                  ),
                ),

                // Badge de YouTube
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_filled,
                            size: isMobile ? 10 : 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'YouTube',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 9 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Información del video
          Text(
            _videoInfo!['title'] ?? 'Video de YouTube',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 14 : 16,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          if (_videoInfo!['channel'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Canal: ${_videoInfo!['channel']}',
              style: TextStyle(
                  color: AppTheme.lightGrey, fontSize: isMobile ? 11 : 12),
            ),
          ],

          const SizedBox(height: 8),

          // Botón para previsualizar
          OutlinedButton.icon(
            icon: Icon(Icons.play_circle_filled, size: isMobile ? 16 : 20),
            label: Text(
              isMobile ? 'Ver preview' : 'Ver previsualización',
              style: TextStyle(fontSize: isMobile ? 13 : 14),
            ),
            onPressed: () {
              if (_youtubeController != null) {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: YoutubePlayer(
                        controller: _youtubeController!,
                        showVideoProgressIndicator: true,
                        progressColors: const ProgressBarColors(
                          playedColor: AppTheme.primaryOrange,
                          handleColor: AppTheme.primaryOrange,
                        ),
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      );
    }

    return Container(
      height: isMobile ? 100 : 120,
      decoration: BoxDecoration(
        color: AppTheme.darkBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_outlined,
              size: isMobile ? 32 : 40,
              color: AppTheme.primaryOrange,
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega un enlace de YouTube',
              style: TextStyle(
                  color: AppTheme.lightGrey, fontSize: isMobile ? 12 : 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseTypeSelector() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      color: AppTheme.darkGrey,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipo de Ejercicio',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 14 : 16,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.repeat,
                            size: isMobile ? 16 : 18, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          'Por Repeticiones',
                          style: TextStyle(fontSize: isMobile ? 12 : 14),
                        ),
                      ],
                    ),
                    selected: _exerciseType == 'reps',
                    selectedColor: Colors.blue.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color:
                          _exerciseType == 'reps' ? Colors.blue : Colors.white,
                    ),
                    onSelected: (selected) {
                      setState(() => _exerciseType = 'reps');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer,
                            size: isMobile ? 16 : 18, color: Colors.purple),
                        const SizedBox(width: 6),
                        Text(
                          'Por Tiempo',
                          style: TextStyle(fontSize: isMobile ? 12 : 14),
                        ),
                      ],
                    ),
                    selected: _exerciseType == 'time',
                    selectedColor: Colors.purple.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _exerciseType == 'time'
                          ? Colors.purple
                          : Colors.white,
                    ),
                    onSelected: (selected) {
                      setState(() => _exerciseType = 'time');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _exerciseType == 'reps'
                  ? 'Ejercicio que se mide por series y repeticiones (ej: press banca)'
                  : 'Ejercicio que se mide por tiempo (ej: saltos, cardio)',
              style: TextStyle(
                color: AppTheme.lightGrey,
                fontSize: isMobile ? 11 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.exercise != null ? 'Editar Ejercicio' : 'Crear Ejercicio',
          style: TextStyle(fontSize: isMobile ? 18 : 20),
        ),
        backgroundColor: AppTheme.darkBlack,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveExercise,
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre del ejercicio *',
                labelStyle: const TextStyle(color: AppTheme.lightGrey),
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
              maxLength: 100,
            ),

            const SizedBox(height: 16),

            // Tipo de ejercicio
            _buildExerciseTypeSelector(),

            const SizedBox(height: 16),

            // Descripción
            TextField(
              controller: _descriptionCtrl,
              decoration: InputDecoration(
                labelText: 'Descripción (opcional)',
                labelStyle: const TextStyle(color: AppTheme.lightGrey),
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
              maxLines: 3,
              maxLength: 500,
            ),

            const SizedBox(height: 16),

            // URL del video
            TextField(
              controller: _videoUrlCtrl,
              decoration: InputDecoration(
                labelText: 'URL de YouTube (opcional)',
                labelStyle: const TextStyle(color: AppTheme.lightGrey),
                filled: true,
                fillColor: AppTheme.darkBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon:
                    const Icon(Icons.link, color: AppTheme.primaryOrange),
                suffixIcon: _videoUrlCtrl.text.isNotEmpty
                    ? IconButton(
                        icon:
                            const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _extractYouTubeId(_videoUrlCtrl.text),
                      )
                    : null,
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.url,
              onChanged: (value) {
                if (value.contains('youtube.com') ||
                    value.contains('youtu.be')) {
                  _extractYouTubeId(value);
                }
              },
            ),

            const SizedBox(height: 8),
            Text(
              'Pega el enlace completo de YouTube',
              style: TextStyle(
                  color: AppTheme.lightGrey, fontSize: isMobile ? 11 : 12),
            ),

            const SizedBox(height: 16),

            // Vista previa del video
            _buildVideoPreview(),

            const SizedBox(height: 24),

            // Grupo muscular
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.darkBlack,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMuscleGroup,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down,
                      color: AppTheme.primaryOrange),
                  hint: Text(
                    'Selecciona grupo muscular (opcional)',
                    style: TextStyle(
                        color: AppTheme.lightGrey,
                        fontSize: isMobile ? 13 : 14),
                  ),
                  dropdownColor: AppTheme.darkGrey,
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Sin categoría'),
                    ),
                    ..._muscleGroups.map((group) {
                      return DropdownMenuItem(
                        value: group,
                        child: Text(
                          group.toUpperCase(),
                          style: TextStyle(fontSize: isMobile ? 13 : 14),
                        ),
                      );
                    }).toList(),
                  ].toList(),
                  onChanged: (value) {
                    setState(() => _selectedMuscleGroup = value);
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Visibilidad
            Card(
              color: AppTheme.darkGrey,
              child: SwitchListTile(
                title: Text(
                  'Ejercicio público',
                  style: TextStyle(
                      color: Colors.white, fontSize: isMobile ? 14 : 16),
                ),
                subtitle: Text(
                  'Otros entrenadores podrán ver y usar este ejercicio',
                  style: TextStyle(
                      color: AppTheme.lightGrey, fontSize: isMobile ? 12 : 14),
                ),
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
                activeColor: AppTheme.primaryOrange,
                secondary: Icon(
                  _isPublic ? Icons.public : Icons.lock,
                  color: _isPublic ? Colors.green : Colors.orange,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Botón guardar
            GradientButton(
              text: _isLoading
                  ? 'Guardando...'
                  : widget.exercise != null
                      ? 'Actualizar Ejercicio'
                      : 'Crear Ejercicio',
              onPressed: _isLoading ? null : _saveExercise,
              isLoading: _isLoading,
              gradientColors: [AppTheme.primaryOrange, AppTheme.orangeAccent],
            ),

            const SizedBox(height: 16),

            // Información adicional
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info,
                          size: isMobile ? 14 : 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Recomendaciones',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 13 : 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Usa nombres claros y descriptivos\n'
                    '• Agrega un video de YouTube para mejor explicación\n'
                    '• Selecciona el grupo muscular principal\n'
                    '• Los ejercicios públicos ayudan a la comunidad',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: isMobile ? 11 : 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _videoUrlCtrl.dispose();
    _youtubeIdCtrl.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }
}
