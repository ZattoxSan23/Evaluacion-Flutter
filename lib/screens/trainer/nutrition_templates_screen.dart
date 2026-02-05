// screens/trainer/nutrition_templates_screen.dart
import 'package:flutter/material.dart';
import 'package:front/screens/trainer/create_template_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../widgets/gradient_button.dart';

class NutritionTemplatesScreen extends StatefulWidget {
  const NutritionTemplatesScreen({super.key});

  @override
  State<NutritionTemplatesScreen> createState() =>
      _NutritionTemplatesScreenState();
}

class _NutritionTemplatesScreenState extends State<NutritionTemplatesScreen> {
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
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
          .eq('trainer_id', supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);

      setState(() {
        _templates = List<Map<String, dynamic>>.from(templates);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando plantillas: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTemplate(String templateId) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Plantilla'),
        content: const Text('¿Eliminar esta plantilla?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('nutrition_templates')
          .delete()
          .eq('id', templateId)
          .eq('trainer_id', supabase.auth.currentUser!.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plantilla eliminada'),
          backgroundColor: Colors.green,
        ),
      );
      _loadTemplates();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Plantillas Nutricionales'),
        backgroundColor: AppTheme.darkBlack,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTemplates,
            tooltip: 'Refrescar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryOrange,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateTemplateScreen(
                onSaved: _loadTemplates,
              ),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange))
          : _templates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.restaurant_menu,
                          size: 64, color: AppTheme.lightGrey),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay plantillas creadas',
                        style: TextStyle(color: AppTheme.lightGrey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crea tu primera plantilla nutricional',
                        style: TextStyle(color: AppTheme.lightGrey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    final meals = (template['template_meals'] as List).length;
                    final isPublic = template['is_public'] == true;

                    return Card(
                      color: AppTheme.darkGrey,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.restaurant_menu,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                        title: Text(
                          template['name'] ?? 'Sin nombre',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${template['daily_calories'] ?? 0} kcal • ${meals} comidas',
                              style: const TextStyle(color: AppTheme.lightGrey),
                            ),
                            if (template['description'] != null)
                              Text(
                                template['description']!,
                                style: const TextStyle(
                                    color: AppTheme.lightGrey, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPublic)
                              const Icon(Icons.public,
                                  size: 16, color: Colors.blue),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  size: 20, color: Colors.red),
                              onPressed: () => _deleteTemplate(template['id']),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateTemplateScreen(
                                existingTemplate: template,
                                onSaved: _loadTemplates,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
