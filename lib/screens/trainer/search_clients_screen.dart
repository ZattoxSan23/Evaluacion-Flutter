// lib/screens/trainer/clients/search_clients_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import 'client_detail_screen.dart';

class SearchClientsScreen extends StatefulWidget {
  final String trainerId;

  const SearchClientsScreen({super.key, required this.trainerId});

  @override
  State<SearchClientsScreen> createState() => _SearchClientsScreenState();
}

class _SearchClientsScreenState extends State<SearchClientsScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _allClients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllClients();
    _searchCtrl.addListener(_filterClients);
  }

  Future<void> _loadAllClients() async {
    setState(() => _isLoading = true);

    try {
      // Cargar todos los clientes del sistema - CORREGIDO
      final clients = await supabase.from('clients').select('''
            *,
            profiles!clients_user_id_fkey(
              full_name,
              email,
              phone,
              dni,
              age,
              gender
            )
          ''').order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allClients = List.from(clients);
          _filteredClients = List.from(clients);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando clientes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar clientes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterClients() {
    final query = _searchCtrl.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() => _filteredClients = List.from(_allClients));
      return;
    }

    setState(() {
      _filteredClients = _allClients.where((client) {
        final profile = client['profiles'] ?? {};

        final name = (profile['full_name'] ?? '').toLowerCase();
        final email = (profile['email'] ?? '').toLowerCase();
        final phone = (profile['phone'] ?? '').toLowerCase();
        final dni = (profile['dni'] ?? '').toLowerCase();

        return name.contains(query) ||
            email.contains(query) ||
            phone.contains(query) ||
            dni.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Clientes'),
        backgroundColor: AppTheme.darkBlack,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, email, teléfono, DNI...',
                hintStyle: const TextStyle(color: AppTheme.lightGrey),
                filled: true,
                fillColor: AppTheme.darkGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon:
                    const Icon(Icons.search, color: AppTheme.primaryOrange),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filterClients();
                        },
                      )
                    : null,
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),

          // Resultados
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryOrange),
                  )
                : _filteredClients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off,
                                size: 64, color: AppTheme.lightGrey),
                            const SizedBox(height: 16),
                            Text(
                              _searchCtrl.text.isEmpty
                                  ? 'No hay clientes registrados'
                                  : 'No se encontraron resultados',
                              style: const TextStyle(color: AppTheme.lightGrey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = _filteredClients[index];
                          final profile = client['profiles'] ?? {};

                          final name = profile['full_name'] ?? 'Sin nombre';
                          final email = profile['email'] ?? 'Sin email';
                          final status = client['status'] ?? 'active';
                          final isMyClient =
                              client['trainer_id'] == widget.trainerId;

                          return Card(
                            color: AppTheme.darkGrey,
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ClientDetailScreen(clientData: client),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isMyClient
                                          ? AppTheme.primaryOrange
                                              .withOpacity(0.2)
                                          : Colors.grey.withOpacity(0.2),
                                      radius: 24,
                                      child: Text(
                                        name.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          color: isMyClient
                                              ? AppTheme.primaryOrange
                                              : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              if (isMyClient)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme
                                                        .primaryOrange
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: const Text(
                                                    'MI CLIENTE',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppTheme
                                                          .primaryOrange,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            email,
                                            style: const TextStyle(
                                                color: AppTheme.lightGrey),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: status == 'active'
                                                      ? Colors.green
                                                          .withOpacity(0.2)
                                                      : Colors.red
                                                          .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  status.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: status == 'active'
                                                        ? Colors.green
                                                        : Colors.red,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'CLIENTE',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ),
                                              if (client['trainer_id'] != null)
                                                const SizedBox(width: 6),
                                              if (client['trainer_id'] != null)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.purple
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    'CON ENTRENADOR',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.purple,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: AppTheme.primaryOrange,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_filterClients);
    _searchCtrl.dispose();
    super.dispose();
  }
}
