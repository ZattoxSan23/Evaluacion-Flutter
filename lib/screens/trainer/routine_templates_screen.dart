// lib/screens/trainer/routine_templates_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:front/core/supabase_client.dart';
import 'package:front/core/theme.dart';
import 'package:front/widgets/gradient_button.dart';
import 'package:front/screens/trainer/assign_routine_screen.dart';
import 'package:front/screens/trainer/create_routine_template_screen.dart'; // Añade este import

class RoutineTemplatesScreen extends StatefulWidget {
  const RoutineTemplatesScreen({super.key});

  @override
  State<RoutineTemplatesScreen> createState() => _RoutineTemplatesScreenState();
}

class _RoutineTemplatesScreenState extends State<RoutineTemplatesScreen> {
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _myTemplates = [];
  List<Map<String, dynamic>> _publicTemplates = [];

  final _searchCtrl = TextEditingController();
  String _selectedFilter = 'all'; // 'all', 'mine', 'public'

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);

    try {
      final trainerId = supabase.auth.currentUser?.id;
      if (trainerId == null) throw Exception('No autenticado');

      // Cargar todas las plantillas (propias y públicas)
      final templates = await supabase
          .from('routine_templates')
          .select('''
          *,
          template_exercises!inner(*),
          profiles:trainer_id(full_name)
        ''')
          .or('is_public.eq.true,trainer_id.eq.$trainerId')
          .order('created_at', ascending: false);

      // Ahora carga los ejercicios para cada template_exercise
      for (final template in templates) {
        final exercises = template['template_exercises'] as List;

        for (final exercise in exercises) {
          if (exercise['exercise_id'] != null) {
            final exerciseData = await supabase
                .from('exercises')
                .select('name, muscle_group, exercise_type')
                .eq('id', exercise['exercise_id'])
                .single()
                .catchError((e) {
              debugPrint('Error cargando ejercicio: $e');
              return null;
            });

            if (exerciseData != null) {
              exercise['exercises'] = exerciseData;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _templates = List.from(templates);
          _myTemplates =
              templates.where((t) => t['trainer_id'] == trainerId).toList();
          _publicTemplates =
              templates.where((t) => t['is_public'] == true).toList();
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

  Future<void> _deleteTemplate(String templateId) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Eliminar plantilla?'),
          content: const Text('Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      await supabase.from('routine_templates').delete().eq('id', templateId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Plantilla eliminada'),
          backgroundColor: Colors.green,
        ),
      );

      _loadTemplates();
    } catch (e) {
      debugPrint('Error eliminando plantilla: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _togglePublicStatus(
      String templateId, bool currentStatus) async {
    try {
      await supabase
          .from('routine_templates')
          .update({'is_public': !currentStatus}).eq('id', templateId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!currentStatus
              ? '✅ Plantilla ahora es pública'
              : '🔒 Plantilla ahora es privada'),
          backgroundColor: !currentStatus ? Colors.green : Colors.blue,
        ),
      );

      _loadTemplates();
    } catch (e) {
      debugPrint('Error cambiando estado: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredTemplates() {
    List<Map<String, dynamic>> source;

    switch (_selectedFilter) {
      case 'mine':
        source = _myTemplates;
        break;
      case 'public':
        source = _publicTemplates;
        break;
      default:
        source = _templates;
    }

    final query = _searchCtrl.text.toLowerCase().trim();
    if (query.isEmpty) return source;

    return source.where((template) {
      final name = (template['name'] as String? ?? '').toLowerCase();
      final description =
          (template['description'] as String? ?? '').toLowerCase();
      final trainerName =
          (template['profiles']?['full_name'] as String? ?? '').toLowerCase();

      return name.contains(query) ||
          description.contains(query) ||
          trainerName.contains(query);
    }).toList();
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final isMine = template['trainer_id'] == supabase.auth.currentUser?.id;
    final exercises = template['template_exercises'] as List;
    final exerciseCount = exercises.length;
    final trainerName = template['profiles']?['full_name'] ?? 'Desconocido';
    final isPublic = template['is_public'] == true;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      color: AppTheme.darkGrey,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isMobile ? 36 : 48,
                  height: isMobile ? 36 : 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.layers,
                    color: AppTheme.primaryOrange,
                    size: isMobile ? 18 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              template['name'] as String? ?? 'Sin nombre',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: isMobile ? 16 : 18,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPublic)
                            Icon(
                              Icons.public,
                              size: isMobile ? 14 : 16,
                              color: Colors.blue,
                              semanticLabel: 'Pública',
                            ),
                        ],
                      ),
                      if (template['description'] != null && !isMobile) ...[
                        const SizedBox(height: 4),
                        Text(
                          template['description'] as String,
                          style: const TextStyle(
                            color: AppTheme.lightGrey,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text(
                              '$exerciseCount ${exerciseCount == 1 ? 'ejercicio' : 'ejercicios'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.green.withOpacity(0.2),
                            labelStyle: const TextStyle(color: Colors.green),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (!isMine)
                            Chip(
                              label: Text(
                                'Por: $trainerName',
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Colors.blue.withOpacity(0.2),
                              labelStyle: const TextStyle(color: Colors.blue),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (isMine)
                            Chip(
                              label: const Text(
                                'Mi plantilla',
                                style: TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Colors.orange.withOpacity(0.2),
                              labelStyle: const TextStyle(color: Colors.orange),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isMobile && template['description'] != null) ...[
              Text(
                template['description'] as String,
                style: const TextStyle(
                  color: AppTheme.lightGrey,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isMine) ...[
                  IconButton(
                    icon: Icon(
                      isPublic ? Icons.lock : Icons.public,
                      size: isMobile ? 18 : 20,
                      color: isPublic ? Colors.blue : AppTheme.lightGrey,
                    ),
                    onPressed: () => _togglePublicStatus(
                      template['id'] as String,
                      isPublic,
                    ),
                    tooltip: isPublic ? 'Hacer privada' : 'Hacer pública',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      size: 18,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateRoutineTemplateScreen(
                            existingTemplate: template,
                            onSaved: _loadTemplates,
                          ),
                        ),
                      );
                    },
                    tooltip: 'Editar',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      size: 18,
                      color: Colors.red,
                    ),
                    onPressed: () => _deleteTemplate(template['id'] as String),
                    tooltip: 'Eliminar',
                  ),
                ],
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(isMobile ? 'Usar' : 'Usar Plantilla'),
                  onPressed: () {
                    Navigator.pop(context, template);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    final filteredTemplates = _getFilteredTemplates();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plantillas de Rutinas'),
        backgroundColor: AppTheme.darkBlack,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTemplates,
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            )
          : Column(
              children: [
                // Filtros y búsqueda
                Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Buscar plantillas...',
                                hintStyle:
                                    const TextStyle(color: AppTheme.lightGrey),
                                filled: true,
                                fillColor: AppTheme.darkGrey,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(Icons.search,
                                    color: AppTheme.primaryOrange),
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
                                value: _selectedFilter,
                                icon: const Icon(Icons.filter_list,
                                    color: AppTheme.primaryOrange),
                                dropdownColor: AppTheme.darkGrey,
                                style: const TextStyle(color: Colors.white),
                                items: [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.all_inclusive,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Text(isMobile
                                            ? 'Todas'
                                            : 'Todas las plantillas'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'mine',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person, size: 18),
                                        const SizedBox(width: 8),
                                        Text(isMobile
                                            ? 'Mías'
                                            : 'Mis plantillas'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'public',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.public, size: 18),
                                        const SizedBox(width: 8),
                                        Text(isMobile
                                            ? 'Públicas'
                                            : 'Plantillas públicas'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedFilter = value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filteredTemplates.length} plantilla${filteredTemplates.length != 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: AppTheme.lightGrey,
                              fontSize: 14,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.layers,
                                color: AppTheme.primaryOrange,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_myTemplates.length} mías, ${_publicTemplates.length} públicas',
                                style: const TextStyle(
                                  color: AppTheme.lightGrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Lista de plantillas
                Expanded(
                  child: filteredTemplates.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.layers_outlined,
                                size: isMobile ? 64 : 80,
                                color: AppTheme.lightGrey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedFilter == 'mine'
                                    ? 'Aún no has creado plantillas'
                                    : 'No hay plantillas disponibles',
                                style: const TextStyle(
                                  color: AppTheme.lightGrey,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              if (_selectedFilter == 'mine')
                                GradientButton(
                                  text: 'Crear Mi Primera Plantilla',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CreateRoutineTemplateScreen(
                                          onSaved: _loadTemplates,
                                        ),
                                      ),
                                    );
                                  },
                                  gradientColors: const [
                                    AppTheme.primaryOrange,
                                    AppTheme.orangeAccent
                                  ],
                                ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadTemplates,
                          child: ListView.builder(
                            padding: EdgeInsets.only(
                              left: isMobile ? 12 : 16,
                              right: isMobile ? 12 : 16,
                              bottom: isMobile ? 80 : 100,
                            ),
                            itemCount: filteredTemplates.length,
                            itemBuilder: (context, index) =>
                                _buildTemplateCard(filteredTemplates[index]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateRoutineTemplateScreen(
                onSaved: _loadTemplates,
              ),
            ),
          );
        },
        backgroundColor: AppTheme.primaryOrange,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Plantilla'),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
