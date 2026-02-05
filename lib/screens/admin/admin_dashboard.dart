// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../screens/login_screen.dart'; // AÑADIR ESTA IMPORTACIÓN
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../widgets/gradient_button.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _clientCount = 0;
  int _trainerCount = 0;
  int _adminCount = 0;
  bool _isLoading = true;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _advertisements = [];
  bool _isLoadingUsers = false;
  bool _isLoadingAds = false;

  // Variables para nueva publicidad
  final _adTitleCtrl = TextEditingController();
  final _adContentCtrl = TextEditingController();
  final _adPriceCtrl = TextEditingController();

  // Variables para editar publicidad
  Map<String, dynamic>? _editingAd;
  final _editAdTitleCtrl = TextEditingController();
  final _editAdContentCtrl = TextEditingController();
  final _editAdPriceCtrl = TextEditingController();
  Uint8List? _editSelectedImageBytes;
  String? _editSelectedImageName;

  // Para multiplataforma: guardamos como bytes en lugar de File
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isUploadingAd = false;
  bool _isDraggingOver = false;

  // Cache para imágenes precargadas
  final Map<String, Uint8List> _imageCache = {};
  final Map<String, bool> _loadingImages = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadUsers();
    _loadAdvertisements();
  }

  Future<void> _logout() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Cerrar sesión?',
              style: TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.darkGrey,
          content: const Text('¿Estás seguro de que quieres salir?',
              style: TextStyle(color: AppTheme.lightGrey)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppTheme.lightGrey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);
      await supabase.auth.signOut();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final clientRes = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'client')
          .count();

      final trainerRes = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'trainer')
          .count();

      final adminRes = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin')
          .count();

      if (mounted) {
        setState(() {
          _clientCount = clientRes.count ?? 0;
          _trainerCount = trainerRes.count ?? 0;
          _adminCount = adminRes.count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar conteos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final response = await supabase
          .from('profiles')
          .select('id, email, full_name, role, created_at')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar usuarios: $e');
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _loadAdvertisements() async {
    setState(() => _isLoadingAds = true);
    try {
      final response = await supabase
          .from('advertisements')
          .select('*')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _advertisements = List<Map<String, dynamic>>.from(response);
          _isLoadingAds = false;
        });

        // Precargar imágenes después de cargar anuncios
        _precacheAdvertisementImages();
      }
    } catch (e) {
      debugPrint('Error al cargar publicidad: $e');
      if (mounted) {
        setState(() => _isLoadingAds = false);
      }
    }
  }

  // ========== SISTEMA DE PRE-CARGA DE IMÁGENES ==========

  Future<void> _precacheAdvertisementImages() async {
    for (final ad in _advertisements) {
      final imageUrl = ad['image_url'];
      if (imageUrl != null &&
          imageUrl.isNotEmpty &&
          !_imageCache.containsKey(imageUrl) &&
          !_loadingImages.containsKey(imageUrl)) {
        _loadingImages[imageUrl] = true;
        await _precacheImage(imageUrl);
        _loadingImages.remove(imageUrl);
      }
    }
  }

  Future<void> _precacheImage(String url) async {
    try {
      final response = await supabase.storage
          .from('advertisements')
          .download(url.split('/').last);

      if (response != null) {
        _imageCache[url] = response;
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error precargando imagen $url: $e');
    }
  }

  Widget _buildCachedImage(String url, double height, bool isMobile) {
    if (_imageCache.containsKey(url)) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: MemoryImage(_imageCache[url]!),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Precargada',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 10 : 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_loadingImages.containsKey(url)) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.darkGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryOrange),
              const SizedBox(height: 8),
              Text(
                'Cargando...',
                style: TextStyle(
                  color: AppTheme.lightGrey,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(url),
          fit: BoxFit.cover,
          onError: (exception, stackTrace) {
            // Intentar precargar si falla la red
            if (!_loadingImages.containsKey(url)) {
              _precacheImage(url);
            }
          },
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.downloading, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Cargando...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 10 : 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    try {
      // 1. Crear en auth.users
      final authRes = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': role},
      );

      if (authRes.user == null) throw Exception('No se creó usuario en auth');

      // 2. Insertar en profiles
      await supabase.from('profiles').insert({
        'id': authRes.user!.id,
        'email': email,
        'full_name': fullName,
        'role': role,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario $role creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDashboardData();
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteProfile(String userId) async {
    try {
      await supabase.from('profiles').delete().eq('id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil eliminado'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDashboardData();
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAdvertisement(String adId) async {
    try {
      await supabase.from('advertisements').delete().eq('id', adId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anuncio eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAdvertisements();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar anuncio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleAdvertisementStatus(
      String adId, bool currentStatus) async {
    try {
      await supabase
          .from('advertisements')
          .update({'is_active': !currentStatus}).eq('id', adId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                currentStatus ? 'Anuncio desactivado' : 'Anuncio activado'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAdvertisements();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar estado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateAdvertisement(String adId) async {
    try {
      if (_editAdTitleCtrl.text.isEmpty ||
          _editAdContentCtrl.text.isEmpty ||
          _editAdPriceCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor completa todos los campos'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      String? imageUrl = _editingAd?['image_url'];

      // Si se seleccionó una nueva imagen
      if (_editSelectedImageBytes != null) {
        final fileName =
            'ad_${DateTime.now().millisecondsSinceEpoch}_${_editSelectedImageName}';
        await supabase.storage.from('advertisements').uploadBinary(
              fileName,
              _editSelectedImageBytes!,
              fileOptions:
                  const FileOptions(cacheControl: '3600', upsert: false),
            );

        imageUrl =
            supabase.storage.from('advertisements').getPublicUrl(fileName);
      }

      await supabase.from('advertisements').update({
        'title': _editAdTitleCtrl.text,
        'content': _editAdContentCtrl.text,
        'price': double.parse(_editAdPriceCtrl.text),
        'image_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', adId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anuncio actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAdvertisements();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditAdvertisementDialog(Map<String, dynamic> ad) {
    _editingAd = ad;
    _editAdTitleCtrl.text = ad['title'] ?? '';
    _editAdContentCtrl.text = ad['content'] ?? '';
    _editAdPriceCtrl.text = ad['price']?.toString() ?? '';
    _editSelectedImageBytes = null;
    _editSelectedImageName = null;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.darkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'EDITAR ANUNCIO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _editAdTitleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Título',
                    labelStyle: TextStyle(color: Colors.blue[300]),
                    hintText: 'Título del anuncio',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: AppTheme.darkBlack.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.blue.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _editAdContentCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Descripción',
                    labelStyle: TextStyle(color: Colors.blue[300]),
                    hintText: 'Descripción detallada del anuncio',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: AppTheme.darkBlack.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.blue.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _editAdPriceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Precio',
                    labelStyle: TextStyle(color: Colors.blue[300]),
                    hintText: 'Ej: 29.99',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: AppTheme.darkBlack.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.blue.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickImageForEdit,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.image,
                          color: Colors.blue[300],
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _editSelectedImageBytes != null
                              ? 'Imagen seleccionada: $_editSelectedImageName'
                              : 'Toca para cambiar imagen',
                          style: TextStyle(
                            color: _editSelectedImageBytes != null
                                ? Colors.green
                                : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('CANCELAR'),
                    ),
                    ElevatedButton(
                      onPressed: () => _updateAdvertisement(ad['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('GUARDAR'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageForEdit() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _editSelectedImageBytes = bytes;
        _editSelectedImageName = pickedFile.name;
      });
    }
  }

  // ========== SISTEMA DE IMÁGENES MULTIPLATAFORMA ==========

  Future<void> _pickImageMobile() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = pickedFile.name;
      });
    }
  }

  Future<void> _pickImageWeb() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = false;

    input.click();

    input.onChange.listen((event) {
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();

        reader.onLoadEnd.listen((event) {
          if (reader.readyState == html.FileReader.DONE) {
            final bytes = reader.result as List<int>;
            setState(() {
              _selectedImageBytes = Uint8List.fromList(bytes);
              _selectedImageName = file.name;
            });
          }
        });

        reader.readAsArrayBuffer(file);
      }
    });
  }

  Future<void> _pickImage() async {
    if (isWeb()) {
      await _pickImageWeb();
    } else {
      await _pickImageMobile();
    }
  }

  bool isWeb() {
    return identical(0, 0.0);
  }

  Future<String?> _uploadImage() async {
    if (_selectedImageBytes == null) return null;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedImageName?.split('.').last ?? 'jpg';
      final fileName =
          'ad_${timestamp}_${_selectedImageName ?? 'image'}.$extension';

      // Subir imagen
      await supabase.storage
          .from('advertisements')
          .uploadBinary(fileName, _selectedImageBytes!);

      final imageUrl =
          supabase.storage.from('advertisements').getPublicUrl(fileName);

      // Agregar al cache inmediatamente
      _imageCache[imageUrl] = _selectedImageBytes!;

      return imageUrl;
    } catch (e) {
      debugPrint('Error subiendo imagen: $e');
      return null;
    }
  }

  Future<void> _createAdvertisement() async {
    if (_adTitleCtrl.text.isEmpty || _adContentCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Título y contenido son requeridos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploadingAd = true);

    try {
      final adminId = supabase.auth.currentUser!.id;

      // Subir imagen si existe
      String? imageUrl;
      if (_selectedImageBytes != null) {
        imageUrl = await _uploadImage();
      }

      final adData = {
        'admin_id': adminId,
        'title': _adTitleCtrl.text,
        'content': _adContentCtrl.text,
        'image_url': imageUrl,
        'price': _adPriceCtrl.text.isNotEmpty
            ? double.tryParse(_adPriceCtrl.text)
            : null,
        'is_active': true,
      };

      await supabase.from('advertisements').insert(adData);

      // Limpiar formulario
      _adTitleCtrl.clear();
      _adContentCtrl.clear();
      _adPriceCtrl.clear();
      setState(() {
        _selectedImageBytes = null;
        _selectedImageName = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anuncio creado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        await _loadAdvertisements();
      }
    } catch (e) {
      debugPrint('Error creando anuncio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isUploadingAd = false);
    }
  }

  Future<void> _showCreateUserDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedRole = 'client';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('CREAR NUEVO USUARIO',
                style: TextStyle(color: AppTheme.primaryOrange)),
            backgroundColor: AppTheme.darkGrey,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      labelStyle: const TextStyle(color: AppTheme.lightGrey),
                      filled: true,
                      fillColor: AppTheme.darkBlack,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.email, color: Colors.blue),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passCtrl,
                    decoration: InputDecoration(
                      labelText: 'Contraseña *',
                      labelStyle: const TextStyle(color: AppTheme.lightGrey),
                      filled: true,
                      fillColor: AppTheme.darkBlack,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.lock, color: Colors.orange),
                    ),
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre completo *',
                      labelStyle: const TextStyle(color: AppTheme.lightGrey),
                      filled: true,
                      fillColor: AppTheme.darkBlack,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.person, color: Colors.green),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBlack,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.lightGrey.withOpacity(0.3)),
                    ),
                    child: DropdownButton<String>(
                      value: selectedRole,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: AppTheme.darkGrey,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: ['client', 'trainer', 'admin'].map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Row(
                            children: [
                              Icon(
                                role == 'client'
                                    ? Icons.person
                                    : role == 'trainer'
                                        ? Icons.fitness_center
                                        : Icons.admin_panel_settings,
                                color: role == 'client'
                                    ? Colors.blue
                                    : role == 'trainer'
                                        ? Colors.orange
                                        : Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                role.toUpperCase(),
                                style: TextStyle(
                                  color: role == 'client'
                                      ? Colors.blue
                                      : role == 'trainer'
                                          ? Colors.orange
                                          : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedRole = val;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '* Campos requeridos',
                    style: TextStyle(
                      color: AppTheme.lightGrey,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar',
                    style: TextStyle(color: AppTheme.lightGrey)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (emailCtrl.text.trim().isEmpty ||
                      passCtrl.text.isEmpty ||
                      nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Completa todos los campos'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  _createUser(
                    email: emailCtrl.text.trim(),
                    password: passCtrl.text,
                    fullName: nameCtrl.text.trim(),
                    role: selectedRole,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Crear Usuario'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAdvertisementsSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ANUNCIOS Y OFERTAS',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  onPressed: () {
                    setState(() {
                      _imageCache.clear();
                      _loadingImages.clear();
                    });
                    _loadAdvertisements();
                  },
                  tooltip: 'Recargar y precargar imágenes',
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_circle, size: 18),
                  label: const Text('Nuevo Anuncio'),
                  onPressed: _showCreateAdDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingAds)
          Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: AppTheme.primaryOrange),
                const SizedBox(height: 16),
                const Text(
                  'Cargando anuncios...',
                  style: TextStyle(color: AppTheme.lightGrey),
                ),
              ],
            ),
          )
        else if (_advertisements.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.darkGrey,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.lightGrey.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(Icons.campaign, size: 64, color: AppTheme.lightGrey),
                const SizedBox(height: 16),
                Text(
                  '📭 No hay anuncios publicados aún',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Crea tu primer anuncio para que los clientes lo vean',
                  style: TextStyle(color: AppTheme.lightGrey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Crear Primer Anuncio'),
                  onPressed: _showCreateAdDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _advertisements.length,
            itemBuilder: (context, index) {
              final ad = _advertisements[index];
              return Container(
                margin: EdgeInsets.only(bottom: isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: AppTheme.darkGrey,
                  borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado con estado
                    Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      decoration: BoxDecoration(
                        color: ad['is_active']
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isMobile ? 16 : 20),
                          topRight: Radius.circular(isMobile ? 16 : 20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ad['title'],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 18 : 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: ad['is_active']
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.red.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            ad['is_active']
                                                ? Icons.check_circle
                                                : Icons.block,
                                            size: 12,
                                            color: ad['is_active']
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            ad['is_active']
                                                ? 'ACTIVO'
                                                : 'INACTIVO',
                                            style: TextStyle(
                                              color: ad['is_active']
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(
                                          DateTime.parse(ad['created_at'])),
                                      style: TextStyle(
                                        color: AppTheme.lightGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  ad['is_active']
                                      ? Icons.toggle_on
                                      : Icons.toggle_off,
                                  color: ad['is_active']
                                      ? Colors.green
                                      : Colors.red,
                                  size: isMobile ? 32 : 36,
                                ),
                                onPressed: () => _toggleAdvertisementStatus(
                                    ad['id'], ad['is_active']),
                                tooltip:
                                    ad['is_active'] ? 'Desactivar' : 'Activar',
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () =>
                                    _showEditAdvertisementDialog(ad),
                                tooltip: 'Editar anuncio',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever,
                                    color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: AppTheme.darkGrey,
                                      title: const Text('Eliminar anuncio',
                                          style:
                                              TextStyle(color: Colors.white)),
                                      content: const Text(
                                          '¿Estás seguro de eliminar este anuncio?\nEsta acción no se puede deshacer.',
                                          style: TextStyle(
                                              color: AppTheme.lightGrey)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancelar',
                                              style: TextStyle(
                                                  color: AppTheme.lightGrey)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            _deleteAdvertisement(ad['id']);
                                            Navigator.pop(ctx);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          child: const Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Contenido del anuncio
                    Padding(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (ad['image_url'] != null &&
                              ad['image_url'].isNotEmpty)
                            Column(
                              children: [
                                _buildCachedImage(ad['image_url'],
                                    isMobile ? 200 : 260, isMobile),
                                const SizedBox(height: 20),
                              ],
                            ),
                          Text(
                            ad['content'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: isMobile ? 15 : 17,
                              height: 1.6,
                            ),
                          ),
                          if (ad['price'] != null) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 20 : 24,
                                vertical: isMobile ? 14 : 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green.withOpacity(0.2),
                                    Colors.greenAccent.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius.circular(isMobile ? 14 : 18),
                                border: Border.all(
                                    color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PRECIO ESPECIAL',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 14 : 16,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Para todos los clientes',
                                        style: TextStyle(
                                          color: Colors.green.withOpacity(0.8),
                                          fontSize: isMobile ? 12 : 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'S/. ${ad['price'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 22 : 26,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildImageUploader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🖼️ Imagen del anuncio (opcional)',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 15 : 17,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Formato recomendado: JPG, PNG. Tamaño máximo: 5MB',
          style: TextStyle(
            color: AppTheme.lightGrey,
            fontSize: isMobile ? 12 : 13,
          ),
        ),
        const SizedBox(height: 12),

        if (_selectedImageBytes != null) ...[
          Container(
            height: isMobile ? 180 : 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              image: DecorationImage(
                image: MemoryImage(_selectedImageBytes!),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedImageName ?? 'imagen.jpg',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 13 : 14,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red),
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.red),
                ),
                onPressed: () {
                  setState(() {
                    _selectedImageBytes = null;
                    _selectedImageName = null;
                  });
                },
                tooltip: 'Eliminar imagen',
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // ÁREA DE UPLOAD
        if (isWeb())
          _buildWebImageUploader(isMobile)
        else
          _buildMobileImageUploader(isMobile),

        if (_selectedImageBytes != null) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(
                'Imagen cargada correctamente',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: isMobile ? 13 : 14,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMobileImageUploader(bool isMobile) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.image, size: 22),
      label: const Text('Seleccionar imagen'),
      onPressed: _pickImage,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, isMobile ? 56 : 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );
  }

  Widget _buildWebImageUploader(bool isMobile) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isDraggingOver = true),
      onExit: (_) => setState(() => _isDraggingOver = false),
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: isMobile ? 140 : 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _isDraggingOver
                ? Colors.blue.withOpacity(0.2)
                : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  _isDraggingOver ? Colors.blue : Colors.blue.withOpacity(0.3),
              width: 3,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isDraggingOver
                    ? Icons.cloud_upload
                    : Icons.cloud_upload_outlined,
                size: 48,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              Text(
                _isDraggingOver
                    ? 'Suelta la imagen aquí'
                    : 'Arrastra una imagen o haz clic',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 15 : 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'JPG, PNG, WebP • Máx. 5MB',
                style: TextStyle(
                  color: AppTheme.lightGrey,
                  fontSize: isMobile ? 13 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateAdDialog() async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isMobile = MediaQuery.of(context).size.width < 600;

          return AlertDialog(
            title: const Text('CREAR NUEVO ANUNCIO',
                style: TextStyle(color: AppTheme.primaryOrange)),
            backgroundColor: AppTheme.darkGrey,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _adTitleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Título del anuncio *',
                      labelStyle: const TextStyle(color: AppTheme.lightGrey),
                      filled: true,
                      fillColor: AppTheme.darkBlack,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.title, color: Colors.orange),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _adContentCtrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Contenido *',
                      labelStyle: const TextStyle(color: AppTheme.lightGrey),
                      filled: true,
                      fillColor: AppTheme.darkBlack,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon:
                          const Icon(Icons.description, color: Colors.blue),
                      alignLabelWithHint: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _adPriceCtrl,
                    decoration: InputDecoration(
                      labelText: 'Precio (opcional)',
                      labelStyle: const TextStyle(color: AppTheme.lightGrey),
                      filled: true,
                      fillColor: AppTheme.darkBlack,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixText: 'S/. ',
                      prefixStyle: const TextStyle(color: Colors.white),
                      prefixIcon:
                          const Icon(Icons.attach_money, color: Colors.green),
                    ),
                    style: const TextStyle(color: Colors.white),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 24),
                  _buildImageUploader(isMobile),
                  const SizedBox(height: 16),
                  Text(
                    '* Campos requeridos',
                    style: TextStyle(
                      color: AppTheme.lightGrey,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isUploadingAd
                    ? null
                    : () {
                        _adTitleCtrl.clear();
                        _adContentCtrl.clear();
                        _adPriceCtrl.clear();
                        setState(() {
                          _selectedImageBytes = null;
                          _selectedImageName = null;
                        });
                        Navigator.pop(context);
                      },
                child: const Text('Cancelar',
                    style: TextStyle(color: AppTheme.lightGrey)),
              ),
              ElevatedButton(
                onPressed: _isUploadingAd ? null : _createAdvertisement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  minimumSize: const Size(140, 52),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                child: _isUploadingAd
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text('🚀 Publicar Anuncio'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppTheme.darkBlack,
      appBar: AppBar(
        title: const Text('👨‍💼 PANEL DE ADMINISTRACIÓN'),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.darkBlack,
                AppTheme.darkBlack.withOpacity(0.9),
              ],
            ),
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: () {
              setState(() {
                _imageCache.clear();
                _loadingImages.clear();
              });
              _loadDashboardData();
              _loadUsers();
              _loadAdvertisements();
            },
            tooltip: 'Refrescar todo',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppTheme.primaryOrange,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Cargando panel de administración...',
                    style: TextStyle(color: AppTheme.lightGrey, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Precargando recursos...',
                    style: TextStyle(
                      color: AppTheme.lightGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _imageCache.clear();
                  _loadingImages.clear();
                });
                await _loadDashboardData();
                await _loadUsers();
                await _loadAdvertisements();
              },
              color: AppTheme.primaryOrange,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Estadísticas
                    Container(
                      padding: EdgeInsets.all(isMobile ? 24 : 32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.darkGrey,
                            AppTheme.darkBlack.withOpacity(0.9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(isMobile ? 20 : 28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.analytics,
                                  color: Colors.orange, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                '✓ RESUMEN GENERAL',
                                style: TextStyle(
                                  fontSize: isMobile ? 22 : 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatCard('Clientes', _clientCount,
                                  Icons.person, Colors.blue),
                              _buildStatCard('Entrenadores', _trainerCount,
                                  Icons.fitness_center, Colors.green),
                              _buildStatCard(
                                  'Administradores',
                                  _adminCount,
                                  Icons.admin_panel_settings,
                                  AppTheme.primaryOrange),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image, color: Colors.purple, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                '${_imageCache.length} imágenes precargadas',
                                style: TextStyle(
                                  color: AppTheme.lightGrey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Botones de acción
                    Container(
                      padding: EdgeInsets.all(isMobile ? 20 : 24),
                      decoration: BoxDecoration(
                        color: AppTheme.darkGrey,
                        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                      ),
                      child: Column(
                        children: [
                          GradientButton(
                            text: 'CREAR NUEVO USUARIO',
                            onPressed: _showCreateUserDialog,
                            gradientColors: [
                              AppTheme.primaryOrange,
                              AppTheme.orangeAccent
                            ],
                          ),
                          const SizedBox(height: 16),
                          GradientButton(
                            text: 'CREAR NUEVO ANUNCIO',
                            onPressed: _showCreateAdDialog,
                            gradientColors: [Colors.blue, Colors.blueAccent],
                          ),
                          const SizedBox(height: 16),
                          GradientButton(
                            text: 'PRECARGAR IMÁGENES',
                            onPressed: () {
                              setState(() {
                                _imageCache.clear();
                                _loadingImages.clear();
                              });
                              _precacheAdvertisementImages();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Precargando todas las imágenes...'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            },
                            gradientColors: [
                              Colors.purple,
                              Colors.purpleAccent
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Sección de publicidad
                    const SizedBox(height: 40),
                    _buildAdvertisementsSection(isMobile),

                    const SizedBox(height: 40),

                    // Lista de usuarios
                    Row(
                      children: [
                        const Icon(Icons.people, color: Colors.blue, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'USUARIOS REGISTRADOS',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _isLoadingUsers
                        ? Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                    color: AppTheme.primaryOrange),
                                const SizedBox(height: 16),
                                const Text(
                                  'Cargando usuarios...',
                                  style: TextStyle(color: AppTheme.lightGrey),
                                ),
                              ],
                            ),
                          )
                        : _users.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkGrey,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.people_outline,
                                          size: 64, color: AppTheme.lightGrey),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No hay usuarios registrados aún',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Usa el botón superior para crear usuarios',
                                        style: TextStyle(
                                            color: AppTheme.lightGrey),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _users.length,
                                itemBuilder: (context, index) {
                                  final user = _users[index];
                                  final role =
                                      user['role'] as String? ?? 'desconocido';
                                  final roleColor = role == 'admin'
                                      ? Colors.redAccent
                                      : role == 'trainer'
                                          ? Colors.orange
                                          : Colors.blueAccent;
                                  final createdAt = user['created_at'] != null
                                      ? DateFormat('dd/MM/yyyy').format(
                                          DateTime.parse(user['created_at'])
                                              .toLocal())
                                      : 'N/A';

                                  return Container(
                                    margin: EdgeInsets.only(
                                        bottom: isMobile ? 12 : 16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.darkGrey,
                                      borderRadius: BorderRadius.circular(
                                          isMobile ? 16 : 20),
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.1)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          EdgeInsets.all(isMobile ? 16 : 20),
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            roleColor.withOpacity(0.2),
                                        child: Icon(Icons.person,
                                            color: roleColor),
                                      ),
                                      title: Text(
                                        user['full_name'] ?? 'Sin nombre',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: isMobile ? 16 : 18,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user['email'] ?? 'Sin email',
                                            style: TextStyle(
                                              color: AppTheme.lightGrey,
                                              fontSize: isMobile ? 14 : 15,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      isMobile ? 10 : 12,
                                                  vertical: isMobile ? 6 : 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: roleColor
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                      color: roleColor
                                                          .withOpacity(0.3)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      role == 'client'
                                                          ? Icons.person
                                                          : role == 'trainer'
                                                              ? Icons
                                                                  .fitness_center
                                                              : Icons
                                                                  .admin_panel_settings,
                                                      size: 12,
                                                      color: roleColor,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      role.toUpperCase(),
                                                      style: TextStyle(
                                                        color: roleColor,
                                                        fontSize:
                                                            isMobile ? 11 : 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Creado: $createdAt',
                                                style: TextStyle(
                                                  color: AppTheme.lightGrey,
                                                  fontSize: isMobile ? 12 : 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_forever,
                                            color: Colors.redAccent),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              backgroundColor:
                                                  AppTheme.darkGrey,
                                              title: const Text(
                                                  'Eliminar usuario',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                              content: const Text(
                                                  '¿Estás seguro de eliminar este usuario?\nEsta acción no se puede deshacer.',
                                                  style: TextStyle(
                                                      color:
                                                          AppTheme.lightGrey)),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx),
                                                  child: const Text('Cancelar',
                                                      style: TextStyle(
                                                          color: AppTheme
                                                              .lightGrey)),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    _deleteProfile(
                                                        user['id'] as String);
                                                    Navigator.pop(ctx);
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                  ),
                                                  child: const Text('Eliminar'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.refresh),
        label: const Text('Refrescar todo'),
        backgroundColor: AppTheme.primaryOrange,
        onPressed: () {
          setState(() {
            _imageCache.clear();
            _loadingImages.clear();
          });
          _loadDashboardData();
          _loadUsers();
          _loadAdvertisements();
        },
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: AppTheme.lightGrey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _adTitleCtrl.dispose();
    _adContentCtrl.dispose();
    _adPriceCtrl.dispose();
    super.dispose();
  }
}
