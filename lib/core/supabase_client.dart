// lib/core/supabase_client.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient? _client;

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception(
          'Supabase no inicializado. Llama a initialize() primero.');
    }
    return _client!;
  }

  static Future<void> initialize() async {
    const supabaseUrl = 'https://dctrecrwewsfjunvggkr.supabase.co';
    const supabaseAnonKey = 'sb_publishable_AZT8Q7PmH71JYXTDP_n2pw_RwvOMJhA';

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: kDebugMode,
      // authFlowType: AuthFlowType.pkce,   // recomendado en 2025 para mobile
    );

    _client = Supabase.instance.client;

    // Opcional: listener global
    _client!.auth.onAuthStateChange.listen((data) {
      debugPrint(
          'Auth change → ${data.event} → ${data.session?.user.email ?? "sin usuario"}');
    });
  }
}

// Acceso rápido en toda la app
SupabaseClient get supabase => SupabaseService.client;
