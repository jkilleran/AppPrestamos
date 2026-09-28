import 'package:flutter/foundation.dart';

/// API endpoint selected at build time with
/// `--dart-define=API_BASE_URL=http://192.168.1.10:3000`.
abstract final class ApiConfig {
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    final configured = _definedBaseUrl.trim();
    return _normalize(configured.isEmpty ? _defaultBaseUrl : configured);
  }

  static String url([String path = '']) {
    final normalizedPath = path.trim().replaceFirst(RegExp(r'^/+'), '');
    return normalizedPath.isEmpty ? baseUrl : '$baseUrl/$normalizedPath';
  }

  static Uri uri([String path = '']) => Uri.parse(url(path));

  static bool isApiUri(Uri candidate) {
    if (!candidate.hasAuthority) return true;

    final base = Uri.parse(baseUrl);
    if (candidate.scheme != base.scheme ||
        candidate.host.toLowerCase() != base.host.toLowerCase() ||
        candidate.port != base.port) {
      return false;
    }

    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    return basePath.isEmpty ||
        candidate.path == basePath ||
        candidate.path.startsWith('$basePath/');
  }

  static String get _defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:3000';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:3000',
      TargetPlatform.iOS || TargetPlatform.macOS => 'http://localhost:3000',
      _ => 'http://localhost:3000',
    };
  }

  static String _normalize(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }
}
