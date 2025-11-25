import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration des variables d'environnement
/// Priorité 1: Variables de compilation --dart-define (pour production)
/// Priorité 2: Variables du fichier .env via flutter_dotenv (pour développement)
class EnvConfig {
  /// URL du projet Supabase
  static String get supabaseUrl {
    // Priorité 1: Variables de compilation --dart-define
    const String fromDefine = String.fromEnvironment('SUPABASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;

    // Priorité 2: Variables d'environnement .env (développement)
    return dotenv.env['SUPABASE_URL'] ?? '';
  }

  /// Clé anonyme Supabase
  static String get supabaseAnonKey {
    // Priorité 1: Variables de compilation --dart-define
    const String fromDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;

    // Priorité 2: Variables d'environnement .env (développement)
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }

  /// Vérifie que toutes les variables d'environnement nécessaires sont définies
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }

  /// Valide la configuration et lance une exception si elle est incomplète
  static void validateConfig() {
    if (!isConfigured) {
      throw Exception(
        'Configuration manquante! '
        'En production: utilisez --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... '
        'En développement: créez un fichier assets/.env avec SUPABASE_URL et SUPABASE_ANON_KEY',
      );
    }
  }
}
