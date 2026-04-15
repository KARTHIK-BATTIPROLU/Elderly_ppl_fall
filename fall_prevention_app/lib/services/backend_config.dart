import 'package:flutter/foundation.dart';

String resolveBackendUrl(String? savedUrl) {
  const runtimeBackendUrl = String.fromEnvironment('BACKEND_URL');
  if (runtimeBackendUrl.isNotEmpty) {
    return runtimeBackendUrl;
  }

  if (savedUrl != null && savedUrl.trim().isNotEmpty) {
    return savedUrl.trim();
  }

  if (kIsWeb) {
    final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
    return 'http://$host:8002';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // Use local PC IP address for development
      return 'http://192.168.0.10:8002';
    default:
      return 'http://127.0.0.1:8002';
  }
}