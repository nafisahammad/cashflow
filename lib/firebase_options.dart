import 'dart:convert';

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

class DefaultFirebaseOptions {
  static const _secretsAssetPath = 'secrets/firebase.secrets.json';
  static Map<String, String>? _cachedSecrets;

  static Future<FirebaseOptions> get currentPlatform async {
    final values = await _loadSecrets();

    if (kIsWeb) return _web(values);

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _android(values);
      case TargetPlatform.iOS:
        return _ios(values);
      case TargetPlatform.macOS:
        return _macos(values);
      case TargetPlatform.windows:
        return _windows(values);
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase options are not configured for linux in this app.',
        );
      default:
        throw UnsupportedError('Firebase options are not supported for this platform.');
    }
  }

  static Future<Map<String, String>> _loadSecrets() async {
    if (_cachedSecrets != null) return _cachedSecrets!;

    final raw = await rootBundle.loadString(_secretsAssetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Firebase secrets file must be a JSON object.');
    }

    final mapped = <String, String>{};
    decoded.forEach((key, value) {
      mapped[key.toString()] = value?.toString() ?? '';
    });

    _cachedSecrets = mapped;
    return mapped;
  }

  static FirebaseOptions _web(Map<String, String> values) {
    _require(values, 'web', [
      'FIREBASE_WEB_API_KEY',
      'FIREBASE_WEB_APP_ID',
      'FIREBASE_WEB_MESSAGING_SENDER_ID',
      'FIREBASE_WEB_PROJECT_ID',
    ]);
    return FirebaseOptions(
      apiKey: values['FIREBASE_WEB_API_KEY']!,
      appId: values['FIREBASE_WEB_APP_ID']!,
      messagingSenderId: values['FIREBASE_WEB_MESSAGING_SENDER_ID']!,
      projectId: values['FIREBASE_WEB_PROJECT_ID']!,
      authDomain: _nullable(values['FIREBASE_WEB_AUTH_DOMAIN']),
      storageBucket: _nullable(values['FIREBASE_WEB_STORAGE_BUCKET']),
      measurementId: _nullable(values['FIREBASE_WEB_MEASUREMENT_ID']),
    );
  }

  static FirebaseOptions _android(Map<String, String> values) {
    _require(values, 'android', [
      'FIREBASE_ANDROID_API_KEY',
      'FIREBASE_ANDROID_APP_ID',
      'FIREBASE_ANDROID_MESSAGING_SENDER_ID',
      'FIREBASE_ANDROID_PROJECT_ID',
    ]);
    return FirebaseOptions(
      apiKey: values['FIREBASE_ANDROID_API_KEY']!,
      appId: values['FIREBASE_ANDROID_APP_ID']!,
      messagingSenderId: values['FIREBASE_ANDROID_MESSAGING_SENDER_ID']!,
      projectId: values['FIREBASE_ANDROID_PROJECT_ID']!,
      storageBucket: _nullable(values['FIREBASE_ANDROID_STORAGE_BUCKET']),
    );
  }

  static FirebaseOptions _ios(Map<String, String> values) {
    _require(values, 'ios', [
      'FIREBASE_IOS_API_KEY',
      'FIREBASE_IOS_APP_ID',
      'FIREBASE_IOS_MESSAGING_SENDER_ID',
      'FIREBASE_IOS_PROJECT_ID',
    ]);
    return FirebaseOptions(
      apiKey: values['FIREBASE_IOS_API_KEY']!,
      appId: values['FIREBASE_IOS_APP_ID']!,
      messagingSenderId: values['FIREBASE_IOS_MESSAGING_SENDER_ID']!,
      projectId: values['FIREBASE_IOS_PROJECT_ID']!,
      storageBucket: _nullable(values['FIREBASE_IOS_STORAGE_BUCKET']),
      iosBundleId: _nullable(values['FIREBASE_IOS_BUNDLE_ID']),
    );
  }

  static FirebaseOptions _macos(Map<String, String> values) {
    _require(values, 'macos', [
      'FIREBASE_MACOS_API_KEY',
      'FIREBASE_MACOS_APP_ID',
      'FIREBASE_MACOS_MESSAGING_SENDER_ID',
      'FIREBASE_MACOS_PROJECT_ID',
    ]);
    return FirebaseOptions(
      apiKey: values['FIREBASE_MACOS_API_KEY']!,
      appId: values['FIREBASE_MACOS_APP_ID']!,
      messagingSenderId: values['FIREBASE_MACOS_MESSAGING_SENDER_ID']!,
      projectId: values['FIREBASE_MACOS_PROJECT_ID']!,
      storageBucket: _nullable(values['FIREBASE_MACOS_STORAGE_BUCKET']),
      iosBundleId: _nullable(values['FIREBASE_MACOS_BUNDLE_ID']),
    );
  }

  static FirebaseOptions _windows(Map<String, String> values) {
    _require(values, 'windows', [
      'FIREBASE_WINDOWS_API_KEY',
      'FIREBASE_WINDOWS_APP_ID',
      'FIREBASE_WINDOWS_MESSAGING_SENDER_ID',
      'FIREBASE_WINDOWS_PROJECT_ID',
    ]);
    return FirebaseOptions(
      apiKey: values['FIREBASE_WINDOWS_API_KEY']!,
      appId: values['FIREBASE_WINDOWS_APP_ID']!,
      messagingSenderId: values['FIREBASE_WINDOWS_MESSAGING_SENDER_ID']!,
      projectId: values['FIREBASE_WINDOWS_PROJECT_ID']!,
      authDomain: _nullable(values['FIREBASE_WINDOWS_AUTH_DOMAIN']),
      storageBucket: _nullable(values['FIREBASE_WINDOWS_STORAGE_BUCKET']),
      measurementId: _nullable(values['FIREBASE_WINDOWS_MEASUREMENT_ID']),
    );
  }

  static void _require(Map<String, String> values, String platform, List<String> keys) {
    final missing = keys.where((key) => (values[key] ?? '').isEmpty).toList();
    if (missing.isEmpty) return;

    throw StateError(
      'Missing Firebase variables for $platform: ${missing.join(', ')}. '
      'Fill $_secretsAssetPath',
    );
  }

  static String? _nullable(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
